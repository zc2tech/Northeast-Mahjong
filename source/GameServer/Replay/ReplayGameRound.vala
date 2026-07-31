using Gee;
using Engine;

namespace GameServer
{
    // Separate replay game round - doesn't inherit from ServerGameRound
    public class ReplayGameRound : Object
    {
        private ReplayRoundState round;
        private ArrayList<ServerPlayer> spectators;

        public bool finished { get { return round.finished; } }

        public ReplayGameRound(AnimationTimings timings, GameLogRound log_round, int dealer, ArrayList<ServerPlayer> spectators)
        {
            this.spectators = spectators;
            round = new ReplayRoundState(timings, log_round, dealer);

            // Connect signals to send messages to spectators
            round.game_initial_draw.connect(game_initial_draw);
            round.game_draw_tile.connect(game_draw_tile);
            round.game_discard_tile.connect(game_discard_tile);
            round.game_draw_dead_tile.connect(game_draw_dead_tile);
            round.game_late_kan.connect(game_late_kan);
            round.game_closed_kan.connect(game_closed_kan);
            round.game_open_kan.connect(game_open_kan);
            round.game_pon.connect(game_pon);
            round.game_chii.connect(game_chii);
            round.game_ron.connect(game_ron);
            round.game_tsumo.connect(game_tsumo);
            round.game_draw.connect(game_draw);

            // NOW restore initial hands after signals are connected
            round.start_initial_hands();

            Environment.log(LogType.INFO, "ReplayGameRound", "Constructor complete, initial hands should be sent");
        }

        public void process(float time)
        {
            round.process(time);
        }

        public void set_paused(bool paused, float time)
        {
            round.set_paused(paused, time);
        }

        public void set_speed(float multiplier)
        {
            round.set_speed(multiplier);
        }

        private void game_initial_draw(int player_index, ArrayList<Tile> hand)
        {
            // In replay, reveal ALL tiles to observers
            Environment.log(LogType.DEBUG, "ReplayGameRound",
                @"game_initial_draw: player $(player_index), $(hand.size) tiles, $(spectators.size) spectators");

            foreach (Tile tile in hand)
            {
                Environment.log(LogType.DEBUG, "ReplayGameRound",
                    @"  Sending TileAssignment: tile $(tile.ID) ($(tile.tile_type.to_string()))");
                foreach (ServerPlayer player in spectators)
                    player.send_message(new ServerMessageTileAssignment(tile));
            }
        }

        private void game_draw_tile(int player_index, Tile tile, bool open)
        {
            ServerMessageTileAssignment assignment = new ServerMessageTileAssignment(tile);
            ServerMessageTileDraw draw = new ServerMessageTileDraw(tile.ID);

            foreach (ServerPlayer player in spectators)
            {
                player.send_message(assignment);
                player.send_message(draw);
            }
        }

        private void game_draw_dead_tile(int player_index, Tile tile, bool open)
        {
            ServerMessageTileAssignment assignment = new ServerMessageTileAssignment(tile);
            ServerMessageTileDraw draw = new ServerMessageTileDraw(tile.ID);

            foreach (ServerPlayer player in spectators)
            {
                player.send_message(assignment);
                player.send_message(draw);
            }
        }

        private void game_discard_tile(Tile tile)
        {
            ServerMessageTileDiscard discard = new ServerMessageTileDiscard(tile.ID);

            foreach (ServerPlayer player in spectators)
                player.send_message(discard);
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

        private void game_ron(int[] player_indices, ArrayList<Tile>[] hands, int discard_player_index, Tile discard_tile, Scoring[] scores)
        {
            // TODO: Send ron message
        }

        private void game_tsumo(int player_index, ArrayList<Tile> hand, Scoring score)
        {
            // TODO: Send tsumo message
        }

        private void game_draw(int[] tenpai_indices, int[] nagashi_indices, GameDrawType draw_type, ArrayList<Tile> all_tiles)
        {
            // TODO: Send draw message
        }
    }
}
