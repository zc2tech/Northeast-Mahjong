using Gee;
using Engine;

namespace GameServer
{
    abstract class Server : Object
    {
        protected GameState state;
        protected GameStartInfo start_info;
        protected ServerSettings settings;
        protected RandomClass rnd;
        private State action_state;
        private ServerGameRound? round;
        private DelayTimer timer = new DelayTimer();

        protected ArrayList<ServerPlayer> players = new ArrayList<ServerPlayer>();
        protected ArrayList<ServerPlayer> spectators = new ArrayList<ServerPlayer>();

        protected Server(ArrayList<ServerPlayer> players, ArrayList<ServerPlayer> spectators, RandomClass rnd, GameStartInfo start_info, ServerSettings settings)
        {
            this.rnd = rnd;
            this.start_info = start_info;
            this.settings = settings;

            state = new GameState(start_info, settings);
            state.mark_as_server_state();  // Mark this as the authoritative server GameState

            for (int i = 0; i < players.size; i++)
            {
                ServerPlayer player = players[i];
                this.players.add(player);

                ServerMessageGameStart start = new ServerMessageGameStart(start_info, settings, i);
                player.send_message(start);
            }

            for (int i = 0; i < spectators.size; i++)
            {
                ServerPlayer spectator = spectators[i];
                this.spectators.add(spectator);

                ServerMessageGameStart start = new ServerMessageGameStart(start_info, settings, -1);
                spectator.send_message(start);
            }
        }

        protected void start()
        {
            start_round(0);
        }

        public void process(float time)
        {
            if (finished)
                return;

            if (action_state == State.ACTIVE)
            {
                round.process(time);

                if (round.finished)
                {
                    RoundFinishResult result = round.result;
                    var score = state.round_finished(result);

                    // Notify subclass that round finished (for logging)
                    round_finished(score);
                    on_round_finished();

                    timer.set_time(start_info.timings.get_animation_round_end_delay(score));

                    if (state.game_is_finished)
                        action_state = State.GAME_FINISHED;
                    else if (state.hanchan_is_finished)
                        action_state = State.HANCHAN_FINISHED;
                    else if (state.round_is_finished)
                        action_state = State.ROUND_FINISHED;
                }
            }
            else
            {
                bool done = false;
                // In bot simulation mode, skip ready checks and use zero-delay timer
                if (settings.bot_simulation)
                {
                    done = timer.active(time);
                }
                else
                {
                    // Normal mode: wait for all players to be ready
                    done = true;
                    foreach (var player in players)
                        if (!player.ready)
                            done = false;
                    foreach (var player in spectators)
                        if (!player.ready)
                            done = false;
                }

                if (done)
                {
                    if (action_state == State.ROUND_FINISHED || action_state == State.HANCHAN_FINISHED)
                        start_round(time);
                    else if (action_state == State.GAME_FINISHED)
                        finished = true;
                }
            }
        }

        public void message_received(ServerPlayer player, ClientMessage message)
        {
            if (action_state == State.ACTIVE && players.contains(player))
                round.message_received(player, message);
            else if (message is ClientMessageMenuReady)
                player.ready = true;
        }

        public void player_disconnected(ServerPlayer player)
        {
            player.is_disconnected = true;

            if (finished || action_state == State.GAME_FINISHED)
                return;

            for (int i = 0; i < players.size; i++)
            {
                if (players[i] == player)
                {
                    ServerMessagePlayerLeft message = new ServerMessagePlayerLeft(i);

                    foreach (ServerPlayer p in players)
                        p.send_message(message);

                    foreach (ServerPlayer p in spectators)
                        p.send_message(message);

                    if (round != null)
                        round.player_disconnected(i);

                    break;
                }
            }
        }

        private void start_round(float time)
        {      
            foreach (var player in players)
                player.ready = false;
            foreach (var player in spectators)
                player.ready = false;

            action_state = State.ACTIVE;

            // Log hand_readings cache hit rate for the round that just ended
            int ch_hits, ch_misses;
            TileRules.get_cache_stats(out ch_hits, out ch_misses);
            int ch_total = ch_hits + ch_misses;
            double ch_rate = ch_total > 0 ? (ch_hits * 100.0 / ch_total) : 0.0;
            Environment.log(LogType.DEBUG, "Server",
                @"hand_readings cache: hits=$(ch_hits) misses=$(ch_misses) total=$(ch_total) rate=$("%.1f".printf(ch_rate))%%");

            // Clear hand_readings cache at the start of each round
            TileRules.clear_hand_readings_cache();

            var info = get_round_start_info();
            state.start_round(info);
            round = create_round(info);

            round.start(time);
        }

        protected abstract ServerGameRound create_round(RoundStartInfo info);
        protected abstract RoundStartInfo get_round_start_info();
        protected virtual void round_finished(RoundScoreState score) {}

        public signal void on_round_finished();

        public bool finished { get; private set; }

        private enum State
        {
            ACTIVE,
            GAME_FINISHED,
            HANCHAN_FINISHED,
            ROUND_FINISHED
        }
    }

    class RegularServer : Server
    {
        private GameLogger? game_log;

        public RegularServer(ArrayList<ServerPlayer> players, ArrayList<ServerPlayer> spectators, RandomClass rnd, GameStartInfo info, ServerSettings settings)
        {
            base(players, spectators, rnd, info, settings);

            // Detect human player index (human players are not bots)
            int human_index = -1;
            for (int i = 0; i < players.size; i++)
            {
                if (!players[i].bot)
                {
                    human_index = i;
                    break;  // Take the first human player
                }
            }

            game_log = Environment.open_game_log(info, settings, human_index);

            start();
        }

        private void log(GameLogLine line)
        {
            if (game_log != null)
                game_log.log(line);
        }

        private void log_round(RoundStartInfo info, Tile[] tiles, SerializableList<SerializableList<Tile>>? initial_hands)
        {
            if (game_log != null)
                game_log.log_round(info, tiles, initial_hands);
        }

        protected override RoundStartInfo get_round_start_info()
        {
            // why not range 1,6 to emulate the real world dice ?
            // and we confirmed it's a stack index like real world
            // a stack should contain upper and lower layers
            int wall_index = rnd.int_range(1, 7) + rnd.int_range(1, 7); // Emulate dual die roll probability
            //  int wall_index = 0;
            return new RoundStartInfo(wall_index, state.dealer_index);
        }

        protected override ServerGameRound create_round(RoundStartInfo info)
        {
            RegularServerGameRound round = new RegularServerGameRound(info, settings, players, spectators, state.round_wind, state.dealer_index, rnd, start_info.timings);

            // Log the round with empty hands initially (will be updated when dealt)
            log_round(info, round.tiles, null);

            // Connect to get initial hands once they're actually dealt
            round.initial_hands_dealt.connect((hands) => {
                if (game_log != null)
                    game_log.update_initial_hands(hands);
            });

            round.log.connect(log);

            return round;
        }

        protected override void round_finished(RoundScoreState score)
        {
            if (game_log == null)
                return;

        
            // Extract score transfers from the score state
            int[] transfers = new int[4];

            if (score == null || score.players == null)
            {
                Environment.log(LogType.ERROR, "RegularServer", "round_finished: score or score.players is null");
                return;
            }

            for (int i = 0; i < 4 && i < score.players.length; i++)
            {
                if (score.players[i] != null)
                    transfers[i] = score.players[i].transfer;
                else
                    transfers[i] = 0;
            }

            // Determine result type
            RoundResultType result_type = RoundResultType.NONE;
            if (score.result != null)
            {
                if (score.result.result == RoundFinishResult.RoundResultEnum.RON)
                    result_type = RoundResultType.RON;
                else if (score.result.result == RoundFinishResult.RoundResultEnum.TSUMO)
                    result_type = RoundResultType.TSUMO;
                else if (score.result.result == RoundFinishResult.RoundResultEnum.DRAW)
                    result_type = RoundResultType.DRAW;
            }

            game_log.set_round_result(transfers, result_type);

            // In bot simulation: write only once at game end (maximum speed).
            // In regular play: write after every round so a mid-game quit doesn't lose data.
            if (state.game_is_finished || !settings.bot_simulation)
                game_log.save();

        }
    }

}
