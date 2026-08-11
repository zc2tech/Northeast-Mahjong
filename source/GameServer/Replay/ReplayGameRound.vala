using Gee;
using Engine;

namespace GameServer
{
    // Separate replay game round - doesn't inherit from ServerGameRound
    public class ReplayGameRound : Object
    {
        private ReplayRoundState round_state;
        private ArrayList<ServerPlayer> spectators;
        private int last_draw_player = -1;  // Track who last drew a tile
        private bool finished = false;  // Track if we've sent winner messages

        public bool is_finished { get { return round_state.finished; } }

        public ReplayGameRound(AnimationTimings timings, GameLogRound log_round, int dealer, ArrayList<ServerPlayer> spectators)
        {
            this.spectators = spectators;
            round_state = new ReplayRoundState(timings, log_round, dealer);

            // CRITICAL: Reveal ALL tiles at the start, just like normal games do in round_starting()
            // This ensures the client knows all tile types before animations play
            foreach (Tile tile in log_round.tiles.to_array())
            {
                ServerMessageTileAssignment assignment = new ServerMessageTileAssignment(tile);
                foreach (ServerPlayer player in spectators)
                    player.send_message(assignment);
            }
            // 估计个时间让渲染那边把消息都处理完，要不等处理 draw/discard 时，前期的时候会赶紧把积压的渲染处理完，看起来就回特别赶，而且感觉服务器这边的控制容易失效
            Thread.usleep(4 * 1000000); 

            // Connect signals to send messages to spectators
            round_state.game_initial_draw.connect(game_initial_draw);
            round_state.game_draw_tile.connect(game_draw_tile);
            round_state.game_discard_tile.connect(game_discard_tile);
            round_state.game_calls_finished.connect(game_calls_finished);
            round_state.game_draw_dead_tile.connect(game_draw_dead_tile);
            round_state.game_late_kan.connect(game_late_kan);
            round_state.game_closed_kan.connect(game_closed_kan);
            round_state.game_open_kan.connect(game_open_kan);
            round_state.game_pon.connect(game_pon);
            round_state.game_chii.connect(game_chii);
            // Note: game_ron, game_tsumo, game_draw signals not used - we detect winners in process() instead

            // NOW restore initial hands after all tiles are revealed
            round_state.start_initial_hands();
            round_state.tidyActions();

        }

        public void process(float time)
        {
            round_state.process(time);

            // Check if round just finished with a winner
            if (round_state.finished && !finished)
            {
                // round_state.handle_ron or round_state_handle_tsumo called, that's why we are here

                // Send winner messages to spectators
                if (round_state.is_ron_win)
                {
                    int[] winner_indices = { round_state.winner_index };
                    ServerMessageRon ron = new ServerMessageRon(winner_indices);

                    foreach (ServerPlayer player in spectators)
                        player.send_message(ron);

                    
                    finished = true;
                }
                else if (round_state.is_tsumo_win)
                {
                    ServerMessageTsumo tsumo = new ServerMessageTsumo();

                    foreach (ServerPlayer player in spectators)
                        player.send_message(tsumo);

                    
                    finished = true;
                }
            }
        }

        public void set_paused(bool paused, float time)
        {
            round_state.set_paused(paused, time);
        }

        public void set_speed(float multiplier)
        {
            round_state.set_speed(multiplier);
        }

        private void game_initial_draw(int player_index, ArrayList<Tile> hand)
        {
            // Initial dealing: ALL tile assignments were already sent in constructor
            // Just like normal games, we don't send anything here
            // The buffered RenderActionInitialDraw will handle the animations

            //      @"game_initial_draw: player $(player_index), $(hand.size) tiles (assignments already sent)");
        }

        private void game_draw_tile(int player_index, Tile tile, bool open)
        {
            // Track who drew so we know whose turn it is
            last_draw_player = player_index;

            // All tiles were assigned at start, just send draw message
            ServerMessageTileDraw draw = new ServerMessageTileDraw(tile.ID);

            foreach (ServerPlayer player in spectators)
                player.send_message(draw);
        }

        private void game_draw_dead_tile(int player_index, Tile tile, bool open)
        {
            // Send DeadWallDraw message to trigger the dead wall draw animation
            ServerMessageDeadWallDraw dead_draw = new ServerMessageDeadWallDraw(tile);
            foreach (ServerPlayer player in spectators)
                player.send_message(dead_draw);
        }

        private void game_discard_tile(Tile tile)
        {
            // Tiles already assigned, just send discard

            ServerMessageTileDiscard discard = new ServerMessageTileDiscard(tile.ID);

            foreach (ServerPlayer player in spectators)
                player.send_message(discard);
        }

        private void game_calls_finished()
        {

            ServerMessageCallsFinished message = new ServerMessageCallsFinished();

            foreach (ServerPlayer player in spectators)
                player.send_message(message);
        }

        private void game_late_kan(Tile tile)
        {
            ServerMessageLateKan kan = new ServerMessageLateKan(tile.ID);

            foreach (ServerPlayer player in spectators)
                player.send_message(kan);
        }

        private void game_closed_kan(ArrayList<Tile> tiles)
        {
            // ClosedKan needs: TileType, tile_1_ID, tile_2_ID, tile_3_ID, tile_4_ID
            ServerMessageClosedKan kan = new ServerMessageClosedKan(
                tiles[0].tile_type,
                tiles[0].ID,
                tiles[1].ID,
                tiles[2].ID,
                tiles[3].ID
            );

            foreach (ServerPlayer player in spectators)
                player.send_message(kan);
        }

        private void game_open_kan(int player_index, ArrayList<Tile> tiles)
        {
            // OpenKan needs: player_index, tile_1_ID, tile_2_ID, tile_3_ID
            ServerMessageOpenKan kan = new ServerMessageOpenKan(
                player_index,
                tiles[1].ID,  // First tile from hand
                tiles[2].ID,  // Second tile from hand
                tiles[3].ID   // Third tile from hand
            );

            foreach (ServerPlayer player in spectators)
                player.send_message(kan);
        }

        private void game_pon(int player_index, ArrayList<Tile> tiles)
        {
            // Pon needs: player_index, tile_1_ID, tile_2_ID

            ServerMessagePon pon = new ServerMessagePon(
                player_index,
                tiles[1].ID,  // First tile from hand
                tiles[2].ID   // Second tile from hand
            );

            foreach (ServerPlayer player in spectators)
                player.send_message(pon);
        }

        private void game_chii(int player_index, ArrayList<Tile> tiles)
        {
            // Chii needs: player_index, tile_1_ID, tile_2_ID

            ServerMessageChii chii = new ServerMessageChii(
                player_index,
                tiles[1].ID,  // First tile from hand
                tiles[2].ID   // Second tile from hand
            );

            foreach (ServerPlayer player in spectators)
                player.send_message(chii);
        }
    }
}
