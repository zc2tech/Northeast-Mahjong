using Gee;
using Engine;

namespace GameServer
{
    // Clean, separate replay system - NO validation, NO decisions, just playback
    public class ReplayRoundState : Object
    {
        // Signals to notify the renderer what to display
        public signal void game_initial_draw(int player_index, ArrayList<Tile> hand);
        public signal void game_draw_tile(int player_index, Tile tile, bool open);
        public signal void game_draw_dead_tile(int player_index, Tile tile, bool open);
        public signal void game_discard_tile(Tile tile);
        public signal void game_calls_finished();  // Signal to advance turn after discard
        public signal void game_late_kan(Tile tile);
        public signal void game_closed_kan(ArrayList<Tile> tiles);
        public signal void game_open_kan(int player_index, ArrayList<Tile> tiles);
        public signal void game_pon(int player_index, ArrayList<Tile> tiles);
        public signal void game_chii(int player_index, ArrayList<Tile> tiles);
        public signal void game_ron(int[] player_indices, ArrayList<Tile>[] hands, int discard_player_index, Tile discard_tile, Scoring[] scores);
        public signal void game_tsumo(int player_index, ArrayList<Tile> hand, Scoring score);
        public signal void game_draw(int[] tenpai_indices, int[] nagashi_indices, GameDrawType draw_type, ArrayList<Tile> all_tiles);

        private ArrayList<GameLogLine> lines;
        private ReplayState state;
        private float move_start_time = 0;
        private bool is_paused = false;
        private float pause_start_time = 0;
        private float speed_multiplier = 1.0f;
        private float SLEEP_STRIDE = 0.1f; // seconds
        private AnimationTimings timings;

        private GameLogRound log_round;
        private int dealer;

        public bool finished { get; private set; default = false; }

        // Winner tracking for end-of-round
        private bool has_ron_winner = false;
        private int ron_winner_index = -1;
        private bool has_tsumo_winner = false;
        private int tsumo_winner_index = -1;

        public bool is_ron_win { get { return has_ron_winner; } }
        public bool is_tsumo_win { get { return has_tsumo_winner; } }
        public int winner_index {
            get {
                if (has_ron_winner) return ron_winner_index;
                if (has_tsumo_winner) return tsumo_winner_index;
                return -1;
            }
        }

        public void tidyActions() {
            ArrayList<GameLogLine>  newLines = new ArrayList<GameLogLine>();
            foreach(GameLogLine line in lines ) {
                if(line != null) {
                    if (line.action != null && line.action is ClientServerAction) {
                         ClientAction client_action = ((ClientServerAction)line.action).action;

                        if (client_action is NoCallClientAction)
                            // for replay, we always ignore this action 
                            continue;
                    }
                    newLines.add(line);
                } 
            }
            this.lines = newLines;
        }
        public ReplayRoundState(AnimationTimings timings, GameLogRound round, int dealer)
        {
            this.timings = timings;
            this.log_round = round;
            this.dealer = dealer;
            this.lines = new ArrayList<GameLogLine>.wrap(round.lines.to_array());
            this.state = new ReplayState(round.tiles.to_array());

            Environment.log(LogType.DEBUG, "ReplayRoundState", @"Created with $(lines.size) actions, dealer=$(dealer)");

            // Don't restore initial hands here - must be done after signals are connected!
        }

        public void start_initial_hands()
        {
            // Called from ReplayGameRound after signals are connected
            restore_initial_hands();
        }

        private void restore_initial_hands()
        {
            // Use the saved initial_hands from the game log
            SerializableList<Tile>[] hands = log_round.initial_hands.to_array();

            // Check if initial_hands is empty (old game log format)
            bool has_saved_hands = false;
            if (hands.length > 0)
            {
                Tile[] first_hand = hands[0].to_array();
                if (first_hand.length > 0)
                    has_saved_hands = true;
            }
            
            if (has_saved_hands)
            {
                Environment.log(LogType.DEBUG, "ReplayRoundState", "Using saved initial hands");

                // Send assignments for all tiles, then update state
                // This matches normal game: all assignments first, then animations play
                for (int player = 0; player < hands.length && player < 4; player++)
                {
                    Tile[] player_tiles = hands[player].to_array();
                    Environment.log(LogType.DEBUG, "ReplayRoundState",
                        @"Player $(player) initial hand: $(player_tiles.length) tiles");

                    // Add tiles to state so calls can find them later
                    ArrayList<Tile> hand_list = new ArrayList<Tile>();
                    foreach (Tile tile in player_tiles)
                    {
                        state.add_tile_to_player(player, tile);
                        state.wall_remove_tile(tile);
                        hand_list.add(tile);
                    }

                    // Send assignments for this player's hand
                    game_initial_draw(player, hand_list);
                }
            }
            else
            {
                // Old log format - simulate dealing pattern
                Environment.log(LogType.INFO, "ReplayRoundState", "Old log format - simulating deal");
                deal_initial_hands_simulation();
            }
        }

        private void deal_initial_hands_simulation()
        {
            // Simulate the dealing pattern for old logs
            // Deal 4 tiles at a time, 3 rounds (12 tiles), then 1 tile each (13 tiles total)
            int wall_tile_index = 0;

            // 3 rounds of 4 tiles
            for (int round = 0; round < 3; round++)
            {
                for (int player = 0; player < 4; player++)
                {
                    for (int tile_count = 0; tile_count < 4; tile_count++)
                    {
                        if (wall_tile_index < state.wall.size)
                        {
                            Tile tile = state.wall[wall_tile_index];
                            wall_tile_index++;

                            state.add_tile_to_player(player, tile);

                            ArrayList<Tile> single_tile = new ArrayList<Tile>();
                            single_tile.add(tile);
                            game_initial_draw(player, single_tile);
                        }
                    }
                }
            }

            // Final round - 1 tile each
            for (int player = 0; player < 4; player++)
            {
                if (wall_tile_index < state.wall.size)
                {
                    Tile tile = state.wall[wall_tile_index];
                    wall_tile_index++;

                    state.add_tile_to_player(player, tile);

                    ArrayList<Tile> single_tile = new ArrayList<Tile>();
                    single_tile.add(tile);
                    game_initial_draw(player, single_tile);
                }
            }
           
            Environment.log(LogType.DEBUG, "ReplayRoundState", @"Simulated dealing complete, dealt $(wall_tile_index) tiles");
        }

        public void process(float time)
        {
            if (finished || is_paused)
                return;

            if (lines.size == 0)
            {
                Environment.log(LogType.INFO, "ReplayRoundState", "Replay complete");
                finished = true;
                return;
            }

            // Process actions with standard timing (ignore recorded delta)
            GameLogLine line = lines[0];
            if (line == null || line.action == null)
            {
                Environment.log(LogType.ERROR, "ReplayRoundState", "Null action in log");
                lines.remove_at(0);
                return;
            }

            // Use fixed animation delay instead of recorded delta
            float standard_delay = get_standard_delay_for_action(line.action);
            float adjusted_delay = standard_delay / speed_multiplier;
            play_action(line.action);
            lines.remove_at(0);
            while(adjusted_delay > 0 ) {
                // Sleep for the adjusted delay (in microseconds)
                Thread.usleep((ulong)(SLEEP_STRIDE * 1000000)); // sleep slice
                adjusted_delay = adjusted_delay - SLEEP_STRIDE;
            }
        }

        private float get_standard_delay_for_action(ServerAction action)
        {
            // Return standard animation times for each action type
            if (action is TileDrawServerAction)
                return 0.5f;
            else if (action is ClientServerAction)
            {
                ClientAction client_action = ((ClientServerAction)action).action;

                // NoCall should process immediately (no delay) so CallsFinished is sent right after discard
                if (client_action is NoCallClientAction)
                    return 0.0f;

                return 0.5f;  // All other client actions
            }

            return 0.5f;  // Default delay for unknown actions
        }

        private void play_action(ServerAction action)
        {
            Environment.log(LogType.DEBUG, "ReplayRoundState", @"Playing: $(action.get_type().name())");

            if (action is TileDrawServerAction)
            {
                handle_draw(action as TileDrawServerAction);
            }
            else if (action is ClientServerAction)
            {
                ClientServerAction csa = action as ClientServerAction;
                ClientAction ca = csa.action;
                string action_type = ca.get_type().name();
                Environment.log(LogType.DEBUG, "ReplayRoundState",
                    @"  ClientServerAction: player=$(csa.client), action=$(action_type)");

                handle_client_action(csa);
            }
        }

        private void handle_draw(TileDrawServerAction action)
        {
            Tile tile = state.get_tile(action.tile_ID);

            // Remove from wall
            state.wall_remove_tile(tile);

            state.add_tile_to_player(action.player, tile);

            Environment.log(LogType.DEBUG, "ReplayRoundState",
                @"Draw: Player $(action.player) draws tile $(tile.ID) ($(tile.tile_type.to_string()))");

            // Regular draw
            game_draw_tile(action.player, tile, false);
        }

        private void handle_client_action(ClientServerAction client_action)
        {
            ClientAction action = client_action.action;
            int player = client_action.client;

            if (action is TileDiscardClientAction)
            {
                handle_discard(player, action as TileDiscardClientAction);
            }
            else if (action is ChiiClientAction)
            {
                handle_chii(player, action as ChiiClientAction);
            }
            else if (action is PonClientAction)
            {
                handle_pon(player);
            }
            else if (action is LateKanClientAction)
            {
                handle_late_kan(player, action as LateKanClientAction);
            }
            else if (action is ClosedKanClientAction)
            {
                handle_closed_kan(player, action as ClosedKanClientAction);
            }
            else if (action is OpenKanClientAction)
            {
                handle_open_kan(player);
            }
            else if (action is NoCallClientAction)
            {
                // No call was made - send CallsFinished to advance turn to next player
                // game_calls_finished();
            }
            else if (action is RonClientAction)
            {
                handle_ron(player);
            }
            else if (action is TsumoClientAction)
            {
                handle_tsumo(player);
            }
        }

        private void handle_discard(int player, TileDiscardClientAction action)
        {
            Tile tile = state.get_tile(action.tile);
            state.remove_tile_from_player(player, tile);
            state.set_last_discard(tile);
            game_discard_tile(tile);

            // Check if we need to send CallsFinished
            // If next action is not a call response (NoCall/Pon/Chii/Kan), send CallsFinished now
            if (lines.size > 0)
            {
                GameLogLine next_line = lines[0];

                if (next_line != null && next_line.action != null) 
                {
                    if (next_line.action is ClientServerAction)
                    {
                        ClientAction next_action = ((ClientServerAction)next_line.action).action;

                        // tidyActions already filtered ALL NoCallClientAction 
                        bool is_call_response =(next_action is PonClientAction) ||
                                               (next_action is ChiiClientAction) ||
                                               (next_action is OpenKanClientAction);

                        // If it's a call, let the call action now current player and then do the player advance
                        if (!is_call_response)
                        {
                            // Next action is not a call response (e.g., it's a draw or discard)
                            // This means no one called, so we need to send CallsFinished
                            game_calls_finished();
                        }
                    }
                    else
                    {
                        // Next action is not a ClientServerAction (e.g., TileDrawServerAction)
                        // This means no calls happened, send CallsFinished
                        game_calls_finished();
                    }
                }
            }
        }

        private void handle_chii(int player, ChiiClientAction action)
        {
            // Chii: player calls the last discarded tile + 2 tiles from their hand
            Tile discard = state.last_discard;
            Tile tile1 = state.get_tile(action.tile_1);
            Tile tile2 = state.get_tile(action.tile_2);

            state.remove_tile_from_player(player, tile1);
            state.remove_tile_from_player(player, tile2);

            // Add the called tile to player's hand
            state.add_tile_to_player(player, discard);

            ArrayList<Tile> tiles = new ArrayList<Tile>();
            tiles.add(discard);
            tiles.add(tile1);
            tiles.add(tile2);

            game_chii(player, tiles);
        }

        private void handle_pon(int player)
        {
            // Pon: player calls the last discarded tile + 2 matching tiles from hand
            Tile discard = state.last_discard;

            // Find 2 matching tiles in player's hand
            ArrayList<Tile> matching = state.find_tiles_in_hand(player, discard.tile_type, 2);

            foreach (Tile t in matching)
                state.remove_tile_from_player(player, t);

            state.add_tile_to_player(player, discard);

            ArrayList<Tile> tiles = new ArrayList<Tile>();
            tiles.add(discard);
            tiles.add_all(matching);

            game_pon(player, tiles);
        }

        private void handle_late_kan(int player, LateKanClientAction action)
        {
            Tile tile = state.get_tile(action.tile);
            state.remove_tile_from_player(player, tile);

            game_late_kan(tile);

            // Draw from dead wall
            Tile dead_tile = state.draw_from_dead_wall();
            state.add_tile_to_player(player, dead_tile);
            game_draw_dead_tile(player, dead_tile, true);
        }

        private void handle_closed_kan(int player, ClosedKanClientAction action)
        {
            // Find 4 matching tiles
            ArrayList<Tile> tiles = state.find_tiles_in_hand(player, action.tile_type, 4);

            foreach (Tile t in tiles)
                state.remove_tile_from_player(player, t);

            game_closed_kan(tiles);

            // Draw from dead wall
            Tile dead_tile = state.draw_from_dead_wall();
            state.add_tile_to_player(player, dead_tile);
            game_draw_dead_tile(player, dead_tile, true);
        }

        private void handle_open_kan(int player)
        {
            Tile discard = state.last_discard;

            // Find 3 matching tiles
            ArrayList<Tile> matching = state.find_tiles_in_hand(player, discard.tile_type, 3);

            foreach (Tile t in matching)
                state.remove_tile_from_player(player, t);

            state.add_tile_to_player(player, discard);

            ArrayList<Tile> tiles = new ArrayList<Tile>();
            tiles.add(discard);
            tiles.add_all(matching);

            game_open_kan(player, tiles);

            // Draw from dead wall
            Tile dead_tile = state.draw_from_dead_wall();
            state.add_tile_to_player(player, dead_tile);
            game_draw_dead_tile(player, dead_tile, true);
        }

        private void handle_ron(int player)
        {
            // Ron detected - store winner info
            Environment.log(LogType.INFO, "ReplayRoundState", @"Ron by player $(player) - finishing round");
            has_ron_winner = true;
            ron_winner_index = player;
            finished = true;
        }

        private void handle_tsumo(int player)
        {
            // Tsumo detected - store winner info
            Environment.log(LogType.INFO, "ReplayRoundState", @"Tsumo by player $(player) - finishing round");
            has_tsumo_winner = true;
            tsumo_winner_index = player;
            finished = true;
        }

        public void set_paused(bool paused, float time)
        {
            if (paused && !is_paused)
            {
                pause_start_time = time;
                is_paused = true;
            }
            else if (!paused && is_paused)
            {
                float pause_duration = time - pause_start_time;
                move_start_time += pause_duration;
                is_paused = false;
            }
        }

        public void set_speed(float multiplier)
        {
            speed_multiplier = multiplier;
        }
    }
}
