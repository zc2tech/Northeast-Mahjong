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
            state.mark_as_server_state();  // Mark as authoritative server state

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
                if (timer.active(time))
                    done = true;
                else
                {
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

        public virtual void handle_replay_pause(bool paused, float time)
        {
            // Base implementation does nothing - only LogServer handles this
        }

        public virtual void handle_replay_speed(float multiplier, float time)
        {
            // Base implementation does nothing - only LogServer handles this
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
            game_log = Environment.open_game_log(info, settings);

            start();
        }

        private void log(GameLogLine line)
        {
            if (game_log != null)
                game_log.log(line);
        }

        private void log_round(RoundStartInfo info, Tile[] tiles)
        {
            if (game_log != null)
                game_log.log_round(info, tiles);
        }

        protected override RoundStartInfo get_round_start_info()
        {
            // why not range 1,6 to emulate the real world dice ?
            // and we confirmed it's a stack index like real world
            // a stack should contain upper and lower layers
            int wall_index = rnd.int_range(1, 7) + rnd.int_range(1, 7); // Emulate dual die roll probability
            //  int wall_index = 0; 
            return new RoundStartInfo(wall_index);
        }

        protected override ServerGameRound create_round(RoundStartInfo info)
        {
            RegularServerGameRound round = new RegularServerGameRound(info, settings, players, spectators, state.round_wind, state.dealer_index, rnd, start_info.timings);
            log_round(info, round.tiles);
            round.log.connect(log);

            return round;
        }
    }

    class LogServer : Server
    {
        private GameLogRound[] rounds;
        private GameLogRound round;
        private int round_index = 0;
        private LogServerGameRound? current_round = null;

        public LogServer(ArrayList<ServerPlayer> spectators, RandomClass rnd, ServerSettings settings, GameLog log)
        {
            ArrayList<ServerPlayer> players = new ArrayList<ServerPlayer>();
            for (int i = 0; i < 4; i++)
                players.add(new ServerLogPlayer()); // Dummies

            // Replace log timings with normal replay timings
            // Bot simulation uses zero timings which makes replay extremely fast
            Environment.log(LogType.DEBUG, "LogServer", "Replacing log timings with normal replay timings");

            AnimationTimings replay_timings = new AnimationTimings(
                0.5f,  // winning_draw_animation_time
                0.5f,  // hand_reveal_animation_time
                1.0f,  // round_over_delay
                11.0f, // round_end_delay
                31.0f, // hanchan_end_delay
                61.0f, // game_end_delay
                11.0f, // decision_time
                new AnimationTime(1, 0.5f, 0),    // finish_label_fade
                new AnimationTime(1, 0.5f, 1),    // menu_items_fade
                new AnimationTime(0.5f, 0.5f, 0), // han_fade
                new AnimationTime(1, 0.5f, 0),    // score_counting_fade
                new AnimationTime(1, 3, 2),       // score_counting
                new AnimationTime(0, 3, 2),       // players_points_counting
                new AnimationTime(0, 0.5f, 0),    // players_score_fade
                new AnimationTime(1, 3, 2),       // players_score_counting
                new AnimationTime(0, 0.15f, 0),   // initial_draw
                new AnimationTime(0, 0.15f, 0.2f), // tile_draw
                new AnimationTime(0, 0.15f, 0.3f), // tile_discard
                new AnimationTime(0, 0.5f, 0),    // call
                new AnimationTime(0, 0.5f, 0),    // win
                new AnimationTime(0, 0.5f, 0),    // hand_reveal
                new AnimationTime(0, 0.5f, 0),    // riichi
                new AnimationTime(0, 0.3f, 0),    // riichi_stick
                new AnimationTime(0, 0.5f, 0),    // flip_dora
                new AnimationTime(0, 0.5f, 0),    // return_riichi_stick
                new AnimationTime(0, 0.5f, 0)     // split_wall
            );

            GameStartInfo replay_start_info = new GameStartInfo(
                log.start_info.get_players(),
                replay_timings,
                log.start_info.starting_dealer,
                log.start_info.starting_score,
                log.start_info.round_count,
                log.start_info.hanchan_count
            );

            base(players, spectators, rnd, replay_start_info, settings);
            rounds = log.rounds.to_array();

            start();
        }

        protected override RoundStartInfo get_round_start_info()
        {
            if (rounds.length <= round_index)
            {
                var info = new RoundStartInfo(rnd.int_range(2, 13));
                round = new GameLogRound(info, null);
                return info;
            }

            round = rounds[round_index++];
            return round.start_info;
        }

        protected override ServerGameRound create_round(RoundStartInfo info)
        {
            current_round = new LogServerGameRound(settings, players, spectators, state.round_wind, state.dealer_index, rnd,start_info.timings, round);
            return current_round;
        }

        public void set_paused(bool paused, float time)
        {
            if (current_round != null)
                current_round.set_paused(paused, time);
        }

        public void set_speed(float multiplier)
        {
            if (current_round != null)
                current_round.set_speed(multiplier);
        }

        public override void handle_replay_pause(bool paused, float time)
        {
            set_paused(paused, time);
        }

        public override void handle_replay_speed(float multiplier, float time)
        {
            set_speed(multiplier);
        }

        public class ServerLogPlayer : ServerPlayer
        {
            public ServerLogPlayer()
            {
                base("", false);

                ready = true;
                state = State.PLAYER;
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
