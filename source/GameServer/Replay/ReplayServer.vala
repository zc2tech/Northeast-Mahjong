using Gee;
using Engine;

namespace GameServer
{
    // Completely separate replay server - no inheritance from Server
    public class ReplayServer : Object
    {
        private ArrayList<ServerPlayer> spectators;
        private ServerSettings settings;
        private GameLog game_log;
        private AnimationTimings timings;

        private ReplayGameRound? current_round;
        private int round_index = 0;

        public bool finished { get; private set; default = false; }

        public ReplayServer(ArrayList<ServerPlayer> spectators, ServerSettings settings, GameLog game_log)
        {
            this.spectators = spectators;
            this.settings = settings;
            this.game_log = game_log;

            // Create replay timings (normal human-viewable speeds)
            timings = create_replay_timings();


            // Debug: inspect initial_hands in the log
            for (int r = 0; r < game_log.rounds.items.length; r++)
            {
                GameLogRound round = game_log.rounds.items[r];
                for (int p = 0; p < round.initial_hands.items.length && p < 4; p++)
                {
                    SerializableList<Tile> hand = round.initial_hands.items[p];
                }
            }

            // Send game start to spectators
            int human_seat = game_log.human_player_index;
            for (int i = 0; i < spectators.size; i++)
            {
                int player_idx = (i == 0 && human_seat >= 0 && human_seat < 4) ? human_seat : -1;
                ServerMessageGameStart start = new ServerMessageGameStart(game_log.start_info, settings, player_idx);
                spectators[i].send_message(start);
            }
        }

        private AnimationTimings create_replay_timings()
        {
            float winning_draw_animation_time = 0.5f;
            float hand_reveal_animation_time = 0.5f;
            float round_over_delay = 1.0f;
            float round_end_delay = 3 + 1;
            float hanchan_end_delay = 30 + 1;
            float game_end_delay = 60 + 1;
            int decision_time = 360000;

            var finish_label_fade = new AnimationTime(1.0f, 0.5f, 0.0f);
            var menu_items_fade = new AnimationTime(1.0f, 0.5f, 1.0f);
            var han_fade = new AnimationTime(0.5f, 0.5f, 0.0f);
            var score_counting_fade = new AnimationTime(1.0f, 0.5f, 0.0f);
            var score_counting = new AnimationTime(1.0f, 3.0f, 2.0f);
            var players_points_counting = new AnimationTime(0.0f, 3.0f, 2.0f);
            var players_score_fade = new AnimationTime(0.0f, 0.5f, 0.0f);
            var players_score_counting = new AnimationTime(1.0f, 3.0f, 2.0f);

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

        public void process_in_worker_loop(float time)
        {
            if (finished)
                return;

            // Start first round if needed
            if (current_round == null)
            {
                start_next_round();
                return;
            }

            // Process current round
            current_round.process(time);

            // Check if round finished
            if (current_round.is_finished)
            {
                // Get the score transfers from the game log
                GameLogRound log_round = game_log.rounds.items[round_index - 1];

                // Log the result for debugging
                int[] transfers = {
                    log_round.transfer_p0,
                    log_round.transfer_p1,
                    log_round.transfer_p2,
                    log_round.transfer_p3
                };

                // TODO: Send a replay scoring message to spectators
                // For now, just clean up and check for next round
                current_round = null;

                // Check if more rounds available
                if (round_index >= game_log.rounds.items.length)
                {
                    finished = true;
                }
            }
        }

        private void start_next_round()
        {
            if (round_index >= game_log.rounds.items.length)
            {
                finished = true;
                return;
            }

            GameLogRound log_round = game_log.rounds.items[round_index];

            // Use dealer from saved RoundStartInfo (no more guessing!)
            int dealer = log_round.start_info.dealer;

            round_index++;


            // Send round start message
            ServerMessageRoundStart round_start = new ServerMessageRoundStart(log_round.start_info);
            foreach (ServerPlayer spectator in spectators)
                spectator.send_message(round_start);

            // Create replay round with dealer from log
            current_round = new ReplayGameRound(timings, log_round, dealer, spectators);
        }

        public void message_received(ServerPlayer player, ClientMessage message)
        {
            // Replay doesn't handle player messages
        }

        public void player_disconnected(ServerPlayer player)
        {
            // Replay doesn't care about disconnections
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

        public void replay_current_hand()
        {
            // Restart the current hand
            // After a hand finishes, round_index points to the NEXT hand
            // and current_round is null. Decrement to replay the same hand.
            if (round_index > 0)
            {
                round_index--;
                current_round = null;
                finished = false;  // Un-finish in case we were at the last hand
            }
        }
    }
}
