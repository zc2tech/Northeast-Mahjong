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

         
        }
    }

    class LogServer : Server
    {
        private GameLogRound[] rounds;
        private GameLogRound round;
        private int round_index = 0;
        private AnimationTimings replay_timings;

        public LogServer(ArrayList<ServerPlayer> spectators, RandomClass rnd, ServerSettings settings, GameLog log)
        {

            ArrayList<ServerPlayer> players = new ArrayList<ServerPlayer>();
            for (int i = 0; i < 4; i++)
                players.add(new ServerLogPlayer()); // Dummies


            // Call base constructor FIRST before anything else
            base(players, spectators, rnd, log.start_info, settings);


            // Create timings AFTER base constructor
            replay_timings = create_replay_timings();


            // Override spectator messages to send correct player_index from log
            int human_seat = log.human_player_index;
            for (int i = 0; i < this.spectators.size; i++)
            {
                // If this is the first spectator and we have a valid human seat, use it
                int player_idx = (i == 0 && human_seat >= 0 && human_seat < 4) ? human_seat : -1;
                ServerMessageGameStart start = new ServerMessageGameStart(log.start_info, settings, player_idx);
                this.spectators[i].send_message(start);

            }

            rounds = log.rounds.to_array();


            start();

        }

        private static AnimationTimings create_replay_timings()
        {
            // Create normal human-viewable timings for replay
            // These are the same as normal game timings from ServerMenu.vala
            float winning_draw_animation_time = 0.5f;
            float hand_reveal_animation_time = 0.5f;
            float round_over_delay = 1.0f;
            float round_end_delay = 3 + 1;
            float hanchan_end_delay = 30 + 1;
            float game_end_delay = 60 + 1;
            //  int decision_time = (settings != null ? settings.decision_time : 10) + 1;
            int decision_time =  360000; // should not be used during replay

            var finish_label_fade = new AnimationTime(1.0f, 0.5f, 0.0f);
            var menu_items_fade = new AnimationTime(1.0f, 0.5f, 1.0f);
            var han_fade = new AnimationTime(0.5f, 0.5f, 0.0f);
            var score_counting_fade = new AnimationTime(0.2f, 0.1f, 0.0f);
            var score_counting = new AnimationTime(0.2f, 0.6f, 0.4f);
            var players_points_counting = new AnimationTime(0.0f, 3.0f, 2.0f);
            var players_score_fade = new AnimationTime(0.0f, 0.1f, 0.0f);
            var players_score_counting = new AnimationTime(0.2f, 0.6f, 0.4f);

            var initial_draw = new AnimationTime(0.0f, 0.15f, 0.0f);
            var tile_draw = new AnimationTime(0.0f, 0.15f, 0.2f);
            var tile_discard = new AnimationTime(0.0f, 0.15f, 0.3f);
            var call = new AnimationTime(0.0f, 0.5f, 0.0f);
            var hand_reveal = new AnimationTime(0.0f, 0.15f, 0.8f);
            var split_wall = new AnimationTime(0.0f, 0.5f, 0.0f);
            var dead_wall_mark_flip = new AnimationTime(0.0f, 0.2f, 0.0f);
            var win = new AnimationTime(0.0f, 0.5f, 0.5f);
            var hand_order = new AnimationTime(0.0f, 0.15f, 0.0f);
            var hand_angle = new AnimationTime(0.0f, 0.2f, 0.0f);
            return new AnimationTimings(
                winning_draw_animation_time,
                hand_reveal_animation_time,
                round_over_delay,
                round_end_delay,
                hanchan_end_delay,
                game_end_delay,
                decision_time,
                finish_label_fade,
                menu_items_fade,
                han_fade,
                score_counting_fade,
                score_counting,
                players_points_counting,
                players_score_fade,
                players_score_counting,
                initial_draw,
                tile_draw,
                tile_discard,
                call,
                hand_reveal,
                split_wall,
                dead_wall_mark_flip,
                win,
                hand_order,
                hand_angle
            );
        }

        protected override RoundStartInfo get_round_start_info()
        {
            if (rounds.length <= round_index)
            {
                var info = new RoundStartInfo(rnd.int_range(2, 13), 0);
                round = new GameLogRound(info, null, null);
                return info;
            }

            round = rounds[round_index++];
            return round.start_info;
        }

        protected override ServerGameRound create_round(RoundStartInfo info)
        {
            // Use our replay_timings instead of start_info.timings (which might be zero from bot simulation)
            return new LogServerGameRound(settings, players, spectators, state.round_wind, state.dealer_index, rnd, replay_timings, round);
        }

        public class ServerLogPlayer : ServerPlayer
        {
            public ServerLogPlayer()
            {
                base("", false);

                ready = true;
                state = State.PLAYER;
            }

            public override void send_message(ServerMessage message)
            {
                // Do nothing - dummy player for replay doesn't need messages
            }

            public override void close()
            {
                // Nothing
            }

            public override bool ready
            {
                get { return true; }
                set {}
            }
        }
    }
}
