using Gee;
using Engine;

namespace GameServer
{
    // Pure state tracker for replay - NO validation logic
    public class ReplayState
    {
        private ArrayList<Tile> wall_tiles;
        private ArrayList<Tile> dead_wall_tiles;
        private HashMap<int, Tile> tile_map;
        private ArrayList<Tile>[] player_hands;
        private Tile? _last_discard;

        public Tile? last_discard { get { return _last_discard; } }
        public ArrayList<Tile> wall { get { return wall_tiles; } }

        public ReplayState(Tile[] tiles, int dealer, int wall_index)
        {
            wall_tiles = new ArrayList<Tile>();
            dead_wall_tiles = new ArrayList<Tile>();
            tile_map = new HashMap<int, Tile>();
            player_hands = new ArrayList<Tile>[4];

            for (int i = 0; i < 4; i++)
                player_hands[i] = new ArrayList<Tile>();

            // Apply the same rotation as gameplay
            // This matches RoundStateWall logic at lines 1033-1050
            int start_wall = (4 - dealer) % 4;
            int index = start_wall * 28 + wall_index * 2;

            // Create tile map from original tiles
            foreach (Tile tile in tiles)
                tile_map.set(tile.ID, tile);

            // Add tiles in rotated order (same as gameplay)
            ArrayList<Tile> rotated_tiles = new ArrayList<Tile>();
            for (int i = 0; i < tiles.length; i++)
            {
                int t = (index + i) % 112;
                rotated_tiles.add(tiles[t]);
            }

            // Split rotated tiles: 0-103 to wall, 104-111 to dead wall
            ArrayList<Tile> temp_dead_wall = new ArrayList<Tile>();
            for (int i = 0; i < rotated_tiles.size; i++)
            {
                if (i < 104)
                    wall_tiles.add(rotated_tiles[i]);
                else
                    temp_dead_wall.add(rotated_tiles[i]);
            }

            // Apply pair-swapping reversal to dead wall (same as RoundState)
            // This ensures: index 0 = far end (draw from here), index 6-7 = near end (mark here)
            // Reverse by pairs, keeping upper before lower within each pair
            for (int i = temp_dead_wall.size - 2; i >= 0; i -= 2)
            {
                dead_wall_tiles.add(temp_dead_wall[i]);     // Add upper tile of this stack
                dead_wall_tiles.add(temp_dead_wall[i + 1]); // Add lower tile of this stack
            }
        }

        public Tile get_tile(int tile_ID)
        {
            Tile? tile = tile_map.get(tile_ID);
            if (tile == null)
            {
                Environment.log(LogType.ERROR, "ReplayState", @"Tile $(tile_ID) not found!");
                return new Tile(0, TileType.MAN1); // Dummy tile
            }
            return tile;
        }

        public Tile draw_from_wall()
        {
            if (wall_tiles.size == 0)
            {
                Environment.log(LogType.ERROR, "ReplayState", "Wall is empty!");
                return new Tile(0, TileType.MAN1);
            }
            return wall_tiles.remove_at(0);
        }

        public void wall_remove_tile(Tile tile)
        {
            // Remove a specific tile from wall (used when log specifies exact tile)
            for (int i = 0; i < wall_tiles.size; i++)
            {
                if (wall_tiles[i].ID == tile.ID)
                {
                    wall_tiles.remove_at(i);
                    return;
                }
            }
            Environment.log(LogType.ERROR, "ReplayState", @"Tile $(tile.ID) not found in wall!");
        }

        public Tile draw_from_dead_wall()
        {
            if (dead_wall_tiles.size == 0)
            {
                Environment.log(LogType.ERROR, "ReplayState", "Dead wall is empty!");
                return new Tile(0, TileType.MAN1);
            }
            return dead_wall_tiles.remove_at(0);
        }

        public void add_tile_to_player(int player, Tile tile)
        {
            player_hands[player].add(tile);
        }

        public void remove_tile_from_player(int player, Tile tile)
        {
            for (int i = 0; i < player_hands[player].size; i++)
            {
                if (player_hands[player][i].ID == tile.ID)
                {
                    player_hands[player].remove_at(i);
                    return;
                }
            }
        }

        public ArrayList<Tile> find_tiles_in_hand(int player, TileType type, int count)
        {
            ArrayList<Tile> result = new ArrayList<Tile>();

            foreach (Tile tile in player_hands[player])
            {
                if (tile.tile_type == type)
                {
                    result.add(tile);
                    if (result.size == count)
                        break;
                }
            }

            if (result.size < count)
            {
                Environment.log(LogType.ERROR, "ReplayState",
                    @"Could not find $(count) tiles of type $(type) for player $(player), only found $(result.size)");
            }

            return result;
        }

        public void set_last_discard(Tile tile)
        {
            _last_discard = tile;
        }

        public ArrayList<Tile> get_player_hand(int player)
        {
            if (player < 0 || player >= 4)
            {
                Environment.log(LogType.ERROR, "ReplayState", @"Invalid player index $(player)");
                return new ArrayList<Tile>();
            }
            return player_hands[player];
        }
    }
}
