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
        private bool waiting_for_next_hand = false;  // Flag to wait for user to click "Next Hand"

        public bool finished { get; private set; default = false; }

        public ReplayServer(ArrayList<ServerPlayer> spectators, ServerSettings settings, GameLog game_log)
        {
            this.spectators = spectators;
            this.settings = settings;
            this.game_log = game_log;

            // Create replay timings (normal human-viewable speeds)
            timings = create_replay_timings();

            // Send game start to spectators with replay timings (not log's zero timings)
            GameStartInfo replay_start_info = new GameStartInfo(
                game_log.start_info.get_players(),
                timings,  // Use replay_timings instead of log's zero timings from bot simulation
                game_log.start_info.starting_dealer,
                game_log.start_info.starting_score,
                game_log.start_info.round_count,
                game_log.start_info.hanchan_count
            );

            int human_seat = game_log.human_player_index;
            for (int i = 0; i < spectators.size; i++)
            {
                int player_idx = (i == 0 && human_seat >= 0 && human_seat < 4) ? human_seat : -1;
                ServerMessageGameStart start = new ServerMessageGameStart(replay_start_info, settings, player_idx);
                spectators[i].send_message(start);
            }
        }

        private AnimationTimings create_replay_timings()
        {
            // Use default animation timings for replay
            return AnimationTimings.create_default(360000);
        }

        public void process_in_worker_loop(float time)
        {
            if (finished)
                return;

            // Start first round if needed
            if (current_round == null && !waiting_for_next_hand)
            {
                start_next_round();
                return;
            }

            // If waiting for user to click "Next Hand", don't process anything
            if (waiting_for_next_hand)
                return;

            // Process current round
            current_round.process(time);

            // Check if round finished
            if (current_round.is_finished)
            {

                // TODO: Send a replay scoring message to spectators
                // Clean up and wait for user to click "Next Hand"
                current_round = null;
                waiting_for_next_hand = true;

                // Check if more rounds available
                if (round_index >= game_log.rounds.items.length)
                {
                    finished = true;
                    waiting_for_next_hand = false;
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
                waiting_for_next_hand = false;
                finished = false;  // Un-finish in case we were at the last hand
            }
        }

        public void advance_to_next_hand()
        {
            // User clicked "Next Hand" button - resume replay
            if (waiting_for_next_hand)
            {
                waiting_for_next_hand = false;
            }
        }
    }
}
