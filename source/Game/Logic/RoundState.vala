using Gee;
using Engine;

public class RoundState : Object
{
    private ServerSettings settings;
    private int current_index;
    private int player_index;
    private int[] winner_indices;
    private RoundStatePlayer[] players = new RoundStatePlayer[4];
    private RoundStateWall wall;

    private bool flow_interrupted = false;
    private int turn_counter = 1;
    public bool rinshan = false;
    private int last_discard_player_index = -1;

    public RoundState(ServerSettings settings, int player_index, Wind round_wind, int dealer, int wall_index)
    {
        init(false, settings, player_index, round_wind, dealer, wall_index, null, false, null);
    }

    public RoundState.server(ServerSettings settings, Wind round_wind, int dealer, int wall_index, RandomClass rnd)
    {
        bool shuffled = (settings.shuffle_tiles == OnOffEnum.ON);
        init(shuffled, settings, -1, round_wind, dealer, wall_index, rnd, true, null);
    }

    public RoundState.custom(ServerSettings settings, Wind round_wind, int dealer, int wall_index, Tile[] tiles)
    {
        init(false, settings, -1, round_wind, dealer, wall_index, null,  true, tiles);
    }

    private void init(bool shuffled, ServerSettings settings, int player_index, Wind round_wind, int dealer, int wall_index, RandomClass? rnd,bool revealed, Tile[]? tiles)
    {
        this.settings = settings;
        this.player_index = player_index;
        this.round_wind = round_wind;
        this.dealer = current_index = dealer;

        if (shuffled)
        {
            //  wall = create_test_wall_open_kan(dealer, wall_index, rnd);
            //  wall = create_test_wall_closed_kan(dealer, wall_index, rnd);
            //  wall = create_test_wall_late_kan(dealer, wall_index, rnd);

            wall = new RoundStateWall.shuffled(dealer, wall_index, rnd);
        }
        else if (tiles != null)
            wall = new RoundStateWall.custom(dealer, wall_index, tiles);
        else
            wall = new RoundStateWall(dealer, wall_index);

        // Set wall owner context for logging: -1 = server, 0-3 = bot client
        wall.set_owner_context(player_index);
        discard_tile = null;

        for (int i = 0; i < players.length; i++)
            players[i] = new RoundStatePlayer(i, i == dealer, (Wind)((i - dealer + 4) % 4), i == player_index || revealed);

        game_draw_type = GameDrawType.NONE;
        last_kan_type = LastKanType.NONE;
    }

    private RoundStateWall create_test_wall_open_kan(int dealer, int wall_index, RandomClass? rnd)
    {
        //  For testing purposes - Testing open_kan with mostly number tiles + HATSU
        //  Scenario: P1 draws MAN1, discards it → P2 calls open_kan (has 3×MAN1)
        TileType[] p1 = new TileType[]
        {
            TileType.MAN2,
            TileType.MAN2,
            TileType.MAN2,
            TileType.SOU9,
            TileType.SOU1,
            TileType.SOU1,
            TileType.SOU1,
            TileType.SOU2,
            TileType.SOU2,
            TileType.SOU2,
            TileType.SOU3,
            TileType.MAN9,
            TileType.HATSU,
        };

        TileType[] p2 = new TileType[]
        {
            TileType.MAN1,
            TileType.MAN1,
            TileType.MAN1,  // 3 MAN1 - ready for open_kan
            TileType.MAN1,
            TileType.SOU4,
            TileType.SOU4,
            TileType.SOU4,
            TileType.SOU5,  // 3 PIN5 - ready for open_kan
            TileType.SOU5,
            TileType.SOU5,
            TileType.SOU7,
            TileType.PIN6,
            TileType.MAN9,
        };

        TileType[] p3 = new TileType[]
        {
            TileType.PIN1,
            TileType.PIN1,
            TileType.PIN1,  // 3 PIN1 - ready for open_kan
            TileType.SOU9,
            TileType.SOU4,
            TileType.SOU5,  // 3 SOU1 - ready for open_kan
            TileType.SOU8,
            TileType.SOU8,
            TileType.SOU8,
            TileType.PIN7,
            TileType.PIN4,
            TileType.PIN8,
            TileType.SOU9,
        };

        TileType[] p4 = new TileType[]
        {
            TileType.PIN2,
            TileType.PIN2,
            TileType.PIN2,
            TileType.PIN3,
            TileType.SOU9,
            TileType.PIN7,
            TileType.PIN7,
            TileType.PIN8,
            TileType.PIN8,
            TileType.MAN7,
            TileType.PIN8,
            TileType.PIN5,
            TileType.PIN5,
        };

        TileType[] draw_wall = new TileType[]
        {
            TileType.PIN2,
            TileType.PIN1,
            // Removed MAN1 (already have 4 in P2)
            TileType.SOU8,
            TileType.SOU1,
            TileType.PIN7,
            // Removed SOU9 (already have 4: P1×1, P3×2, P4×1)
            // Add remaining tiles to complete the wall
            TileType.MAN2, // P1 has 3, this is the 4th
            TileType.MAN3, TileType.MAN3, TileType.MAN3, TileType.MAN3,
            TileType.MAN4, TileType.MAN4, TileType.MAN4, TileType.MAN4,
            TileType.MAN5, TileType.MAN5, TileType.MAN5, TileType.MAN5,
            TileType.MAN6, TileType.MAN6, TileType.MAN6, TileType.MAN6,
            TileType.MAN7, TileType.MAN7, TileType.MAN7, // P4 has 1
            TileType.MAN8, TileType.MAN8, TileType.MAN8, TileType.MAN8,
            TileType.MAN9, TileType.MAN9, // P1 and P2 have 1 each
            TileType.SOU2, // P1 has 3, this completes the set
            TileType.SOU3, TileType.SOU3, TileType.SOU3, // P1 has 1
            TileType.SOU6, TileType.SOU6, TileType.SOU6, TileType.SOU6,
            TileType.SOU7, TileType.SOU7, TileType.SOU7, // P2 has 1
            TileType.PIN9, TileType.PIN9, TileType.PIN9, TileType.PIN9,
            TileType.HATSU, TileType.HATSU, TileType.HATSU, // P1 has 1
        };

        TileType[] dead_wall = new TileType[]
        {
            // 8 tiles for dead wall - only PIN3, PIN4, PIN5, PIN6 have room
            TileType.PIN3, TileType.PIN3,  // PIN3: was 2, +2 = 4
            TileType.PIN4, TileType.PIN4,  // PIN4: was 2, +2 = 4
            TileType.PIN5, TileType.PIN5,  // PIN5: was 2, +2 = 4
            TileType.PIN6, TileType.PIN6,  // PIN6: was 1, +2 = 3 (still room for 1 more)
        };

        return new RoundStateWall.seeded(dealer, wall_index, false, rnd, p1, p2, p3, p4, draw_wall, dead_wall);
        
    }
    private RoundStateWall create_test_wall_late_kan(int dealer, int wall_index, RandomClass? rnd)
    {
        //  For testing late_kan: Players have 2× tiles that can pon from others,
        //  then draw the 4th tile from draw_wall to complete late_kan
        //  Scenario: P1 discards MAN5 → P2 pons (has 2×MAN5) → P2 later draws 4th MAN5 → late_kan
        TileType[] p1 = new TileType[]
        {
            TileType.MAN5,  // Will discard this for P2 to pon
            TileType.MAN6,
            TileType.MAN6,  // Can pon if someone discards MAN6
            TileType.SOU3,
            TileType.SOU3,  // Can pon if someone discards SOU3
            TileType.SOU7,
            TileType.SOU7,  // Can pon if someone discards SOU7
            TileType.PIN4,
            TileType.PIN4,  // Can pon if someone discards PIN4
            TileType.MAN1,
            TileType.SOU1,
            TileType.PIN1,
            TileType.HATSU,
        };

        TileType[] p2 = new TileType[]
        {
            TileType.MAN5,
            TileType.MAN5,  // 2×MAN5 - ready to pon from P1's discard
            TileType.SOU4,
            TileType.SOU4,  // Can pon if someone discards SOU4
            TileType.PIN2,
            TileType.PIN2,  // Can pon if someone discards PIN2
            TileType.PIN9,
            TileType.PIN9,  // Can pon if someone discards PIN9
            TileType.MAN3,
            TileType.SOU2,
            TileType.MAN8,
            TileType.SOU5,
            TileType.PIN5,
        };

        TileType[] p3 = new TileType[]
        {
            TileType.MAN6,  // Only 1 more (not 2) to avoid maxing out
            TileType.SOU3,  // Only 1 more (not 2) to avoid maxing out
            TileType.SOU4,  // Available for P2 to pon
            TileType.PIN2,  // Available for P2 to pon
            TileType.PIN7,
            TileType.PIN7,  // Can pon if someone discards PIN7
            TileType.MAN2,
            TileType.MAN9,
            TileType.SOU6,
            TileType.SOU8,
            TileType.PIN8,
            TileType.MAN7,  // Extra filler
            TileType.SOU9,  // Extra filler
        };

        TileType[] p4 = new TileType[]
        {
            TileType.SOU7,  // Only 1 more (not 2) to avoid maxing out
            TileType.PIN4,  // Only 1 more (not 2) to avoid maxing out
            TileType.PIN9,  // Available for P2 to pon
            TileType.MAN7,
            TileType.MAN7,  // Can pon if someone discards MAN7
            TileType.SOU9,
            TileType.SOU9,  // Can pon if someone discards SOU9
            TileType.PIN3,
            TileType.PIN6,
            TileType.MAN4,
            TileType.PIN8,
            TileType.MAN2,  // Extra filler
            TileType.PIN3,  // Extra filler
        };

        TileType[] draw_wall = new TileType[]
        {
            TileType.MAN1, TileType.MAN1,  // P1 has 1, +1 in dead = 4 total
            TileType.MAN2, TileType.MAN2,  // P3+P4 have 2, total 4
            TileType.MAN3, TileType.MAN3,  // P2 has 1, +1 in dead = 4 total
            TileType.MAN4, TileType.MAN4,  // P4 has 1, +1 in dead = 4 total
            TileType.MAN8, TileType.MAN8,  // P2 has 1, +1 in dead = 4 total
            // Critical: 4th tiles for late_kan placed early in draw_wall
            TileType.MAN6,  // 4th MAN6 for P1/P3 late_kan
            TileType.MAN5,  // 4th MAN5 for P2's late_kan after ponning
            TileType.SOU4,  // 4th SOU4 for P2 late_kan
            TileType.SOU3,  // 4th SOU3 for P1/P3 late_kan
            TileType.SOU7,  // 4th SOU7 for P1/P4 late_kan
            TileType.PIN2,  // 4th PIN2 for P2 late_kan
            TileType.PIN4,  // 4th PIN4 for P1/P4 late_kan
            TileType.PIN7,  // 4th PIN7 for P3 late_kan
            TileType.PIN9,  // 4th PIN9 for P2 late_kan
            TileType.MAN7,  // 4th MAN7 for P4 late_kan
            TileType.SOU9,  // 4th SOU9 for P4 late_kan
            TileType.PIN8,  // 4th PIN8
            // Fill remaining tiles to reach 52 total (112 total - 52 in hands - 8 in dead_wall)
            TileType.MAN9, TileType.MAN9,  // P3 has 1, +1 in dead = 4 total
            TileType.SOU1, TileType.SOU1,  // P1 has 1, +1 in dead = 4 total
            TileType.SOU2, TileType.SOU2,  // P2 has 1, +1 in dead = 4 total
            TileType.SOU5, TileType.SOU5,  // P2 has 1, +1 in dead = 4 total
            TileType.SOU6, TileType.SOU6,  // P3 has 1, +1 in dead = 4 total
            TileType.SOU8, TileType.SOU8,  // P3 has 1, +1 in dead = 4 total
            TileType.PIN1, TileType.PIN1,  // P1 has 1, +1 in dead = 4 total
            TileType.PIN3,  // P4 has 2, +1 in dead = 4 total
            TileType.PIN5, TileType.PIN5,  // P2 has 1, +1 in dead = 4 total
            TileType.PIN6, TileType.PIN6, TileType.PIN6,  // P4 has 1, total 4
            TileType.HATSU, TileType.HATSU, TileType.HATSU,  // P1 has 1, total 4
        };

        TileType[] dead_wall = new TileType[]
        {
            // 8 tiles for dead_wall
            TileType.MAN1, TileType.MAN3,
            TileType.MAN4, TileType.MAN8,
            TileType.MAN9, TileType.SOU1,
            TileType.SOU2, TileType.SOU5,
        };

        return new RoundStateWall.seeded(dealer, wall_index, false, rnd, p1, p2, p3, p4, draw_wall, dead_wall);
    }

    private RoundStateWall create_test_wall_closed_kan(int dealer, int wall_index, RandomClass? rnd)
    {
        //  For testing purposes - Testing open_kan with mostly number tiles + HATSU
        //  Scenario: P1 draws MAN1, discards it → P2 calls open_kan (has 3×MAN1)
        TileType[] p1 = new TileType[]
        {
            TileType.MAN2,
            TileType.MAN2,
            TileType.MAN2,
            TileType.MAN2,
            TileType.SOU1,
            TileType.SOU1,
            TileType.SOU1,
            TileType.SOU1,
            TileType.PIN1,
            TileType.PIN5,
            TileType.PIN7,
            TileType.MAN9,
            TileType.HATSU,
        };

        TileType[] p2 = new TileType[]
        {
            TileType.MAN1,
            TileType.MAN1,
            TileType.MAN1,  // 3 MAN1 - ready for open_kan
            TileType.MAN1,
            TileType.SOU2,
            TileType.SOU2,
            TileType.SOU2,
            TileType.SOU2,  // 3 PIN5 - ready for open_kan
            TileType.PIN1,
            TileType.PIN5,
            TileType.PIN7,
            TileType.PIN6,
            TileType.MAN9,
        };

        TileType[] p3 = new TileType[]
        {
            TileType.MAN4,
            TileType.MAN4,
            TileType.MAN4,  // 3 PIN1 - ready for open_kan
            TileType.MAN4,
            TileType.MAN5,
            TileType.MAN5,  // 3 SOU1 - ready for open_kan
            TileType.MAN5,
            TileType.MAN5,
            TileType.PIN1,
            TileType.PIN7,
            TileType.PIN5,
            TileType.PIN8,
            TileType.SOU9,
        };

        TileType[] p4 = new TileType[]
        {
            TileType.MAN3,
            TileType.MAN3,
            TileType.MAN3,
            TileType.MAN3,
            TileType.SOU3,
            TileType.SOU3,
            TileType.SOU3,
            TileType.SOU3,
            TileType.MAN8,
            TileType.PIN7,
            TileType.PIN8,
            TileType.PIN5, 
            TileType.MAN9,
        };

        TileType[] draw_wall = new TileType[]
        {
            // 52 tiles for draw_wall
            TileType.MAN6, TileType.MAN6, TileType.MAN6, TileType.MAN6,
            TileType.MAN7, TileType.MAN7, TileType.MAN7, TileType.MAN7,
            TileType.MAN8, TileType.MAN8,  // Only 2 here (P4 has 1, dead has 1 = 4 total)
            TileType.PIN2, TileType.PIN2, TileType.PIN2, TileType.PIN2,
            TileType.PIN3, TileType.PIN3, TileType.PIN3, TileType.PIN3,
            TileType.PIN4, TileType.PIN4, TileType.PIN4, TileType.PIN4,
            TileType.PIN6, TileType.PIN6, TileType.PIN6,
            TileType.PIN9, TileType.PIN9, TileType.PIN9, TileType.PIN9,
            TileType.SOU4, TileType.SOU4, TileType.SOU4, TileType.SOU4,
            TileType.SOU5, TileType.SOU5, TileType.SOU5, TileType.SOU5,
            TileType.SOU6, TileType.SOU6, TileType.SOU6, TileType.SOU6,
            TileType.SOU7, TileType.SOU7, TileType.SOU7, TileType.SOU7,
            TileType.SOU8, TileType.SOU8, TileType.SOU8, TileType.SOU8,
            TileType.SOU9, TileType.SOU9,  // P3 has 1, dead has 1, draw has 2 = 4 total
            TileType.HATSU,  // P1 has 1, dead has 2, draw has 1 = 4 total
        };

        TileType[] dead_wall = new TileType[]
        {
            // 8 tiles for dead_wall (4 stacks of 2)
            TileType.MAN9, TileType.PIN1,
            TileType.PIN8, TileType.PIN8,
            TileType.HATSU, TileType.HATSU,  // P1 has 1, dead has 2, draw has 1 = 4 total
            TileType.MAN8, TileType.SOU9,  // MAN8: P4+dead+draw×2=4, SOU9: P3+dead+draw×2=4
        };

        return new RoundStateWall.seeded(dealer, wall_index, false, rnd, p1, p2, p3, p4, draw_wall, dead_wall);
        //  return new RoundStateWall.shuffled(dealer, wall_index, rnd);
    }

    public void start()
    {
        for (int i = 0; i < 3; i++)  // first 3 draw round , 3 (i) * 4 (t)= 12 for every players
        {
            for (int p = 0; p < 4; p++)  // four players
            {
                RoundStatePlayer player = current_player;

                for (int t = 0; t < 4; t++) // for tiles one draw
                {
                    Tile tile = wall.draw_wall(); // always draw a tile from 0 position of wall(shuffled)
                    player.draw_initial(tile);
                }

                current_index = (current_index + 1) % players.length;
            }
        }

        for (int p = 0; p < 4; p++) // four players, 收尾
        {
            RoundStatePlayer player = current_player;
            Tile tile = wall.draw_wall();
            player.draw_initial(tile);
            current_index = (current_index + 1) % players.length;
        }

        //  stdout.printf("wall size: %d\n", wall.tiles_size);
        //  for (int p = 0; p < 4; p++) {
        //      stdout.printf("player %d , hand: %d \n", p, players[p].hand.size); 
        //  }
         
    }

    public void tile_assign(Tile tile)
    {
        Tile t = get_tile(tile.ID);
        t.tile_type = tile.tile_type;

        // Removed excessive debug logging
    }

    public void calls_finished()
    {
        if (last_kan_type == LastKanType.NONE)
        {
            if (wall.empty)
            {
                Environment.log(LogType.DEBUG, "RoundState",
                    "Wall is empty! Setting game_draw_type to EMPTY_WALL, game_over = true");
                game_over = true;
                game_draw_type = GameDrawType.EMPTY_WALL;
                return;
            }

            bool diff = false;
            int count = 0;

            foreach (RoundStatePlayer player in players)
            {
                if ((count += player.get_kan_count()) != 4)
                    diff = true;
            }

            if (count == 4 && diff) // Four kans game draw
            {
                game_over = true;
                game_draw_type = GameDrawType.FOUR_KANS;
                return;
            }

            // Six kans total (dead wall exhausted except mark stack) - game draw
            if (count >= 6)
            {
                game_over = true;
                game_draw_type = GameDrawType.EMPTY_WALL;
                return;
            }

            if (turn_counter == 4 && !flow_interrupted)
            {
                bool four_winds = true;
                for (int i = 0; i < players.length; i++)
                {
                    if (players[i].pond.size != 1 ||
                       !players[i].pond[0].is_wind_tile() ||
                        players[i].pond[0].tile_type != players[0].pond[0].tile_type)
                    {
                        four_winds = false;
                        break;
                    }
                }

                if (four_winds) // Four winds game draw
                {
                    game_over = true;
                    game_draw_type = GameDrawType.FOUR_WINDS;
                    return;
                }
            }

            // After a regular call (not kan), move to next player
            // For kan, the turn stays with the same player
            if (last_kan_type == LastKanType.NONE)
                current_index = (current_index + 1) % players.length;
        }
        // Note: We don't call kan() here anymore because the server handles it
        // and sends DeadWallDraw message. Calling kan() here would duplicate
        // the dead wall draw and corrupt the client/bot state.

        turn_counter++;
        // Don't reset last_kan_type here - it should persist until the next discard
        // tile_discard() will reset it to NONE after the player discards
    }

    public void void_hand()
    {
        game_over = true;
        game_draw_type = GameDrawType.VOID_HAND;
        return;
    }

    public void triple_ron()
    {
        game_over = true;
        game_draw_type = GameDrawType.TRIPLE_RON;
        return;
    }

    public Tile tile_draw()
    {
        Tile tile = wall.draw_wall();
        current_player.draw(tile);

        return tile;
    }

    public Tile tile_draw_dead_wall()
    {
        Tile tile = wall.draw_dead_wall();
        current_player.draw(tile);

        // Set rinshan flag when drawing from dead wall after kan
        // This prevents tsumo (self-draw win) - player must discard first
        rinshan = true;

        return tile;
    }

    public bool tile_discard(int tile_ID)
    {
        Tile tile = get_tile(tile_ID);
        RoundStatePlayer player = current_player;
        if (!player.discard(tile))
            return false;

        discard_tile = tile;
        last_discard_player_index = current_player.index;
        rinshan = false;
        last_kan_type = LastKanType.NONE;

        return true;
    }

    public int get_last_discard_player_index()
    {
        return last_discard_player_index;
    }

    public void ron(int[] player_indices)
    {
        game_over = true;
        winner_indices = player_indices;
    }

    public void tsumo()
    {
        game_over = true;
    }

    // 杠牌 吃牌之后又摸了一张
     public ArrayList<Tile>? late_kan(int tile_ID)
    {
        if (!can_late_kan_with(tile_ID))
            return null;

        Tile tile = get_tile(tile_ID);

        var kan_tiles = current_player.do_late_kan(tile);
        last_kan_type = LastKanType.LATE;
        discard_tile = tile;

        return kan_tiles;
    }

    public ArrayList<Tile>? closed_kan(TileType tile_type)
    {
        if (!can_closed_kan_with(tile_type))
            return null;

        var tiles = current_player.do_closed_kan(tile_type);
        assert(tiles.size == 4);

        last_kan_type = LastKanType.CLOSED;
        discard_tile = tiles[0];
        //interrupt_flow(); // TODO: Find out whether this is correct

        return tiles;
    }

    public void open_kan(int player_index, int tile_1_ID, int tile_2_ID, int tile_3_ID)
    {
        RoundStatePlayer player = get_player(player_index);
        RoundStatePlayer discarder = current_player;

        Tile tile = discard_tile;
        Tile tile_1 = get_tile(tile_1_ID);
        Tile tile_2 = get_tile(tile_2_ID);
        Tile tile_3 = get_tile(tile_3_ID);
        discarder.rob_tile(tile);

        player.do_open_kan(discarder.index, tile, tile_1, tile_2, tile_3);

        current_index = player_index;
        last_kan_type = LastKanType.OPEN;
        // Note: We don't call kan() here anymore because the server handles it
        // and sends DeadWallDraw message. Calling kan() here would duplicate
        // the dead wall draw and corrupt the client/bot state.
    }

    public void pon(int player_index, int tile_1_ID, int tile_2_ID)
    {
        RoundStatePlayer player = get_player(player_index);
        RoundStatePlayer discarder = current_player;

        Tile tile = discard_tile;
        Tile tile_1 = get_tile(tile_1_ID);
        Tile tile_2 = get_tile(tile_2_ID);
        discarder.rob_tile(tile);

        player.do_pon(discarder.index, tile, tile_1, tile_2);

        interrupt_flow();
        current_index = player_index;

    }

    public void chii(int player_index, int tile_1_ID, int tile_2_ID)
    {
        RoundStatePlayer player = get_player(player_index);
        RoundStatePlayer discarder = current_player;

        Tile tile = discard_tile;
        Tile tile_1 = get_tile(tile_1_ID);
        Tile tile_2 = get_tile(tile_2_ID);
        discarder.rob_tile(tile);

        player.do_chii(discarder.index, tile, tile_1, tile_2);

        interrupt_flow();
        current_index = player_index;
    }

    public Scoring[]? get_ron_score()
    {
        if (winner_indices == null)
            return null;

        Scoring[] scores = new Scoring[winner_indices.length];
        RoundStateContext context = create_context(true, discard_tile);

        for (int i = 0; i < scores.length; i++)
            scores[i] = get_player(winner_indices[i]).get_ron_score(context);

        return scores;
    }

    public Scoring get_tsumo_score()
    {
        RoundStatePlayer player = current_player;
        return player.get_tsumo_score(create_context(false, player.newest_tile));
    }

    public bool can_void_hand()
    {
        return !flow_interrupted && turn_counter <= 4 && TileRules.can_void_hand(current_player.hand);
    }

    public bool can_ron(RoundStatePlayer player)
    {
        if (player == current_player)
            return false;

        if (!player.can_ron(create_context(true, discard_tile)))
            return false;

        // 抢杠应该在东北麻将里不允许吧？
        //  if (chankan_call == ChankanCall.CLOSED)
        //      return player.can_closed_chankan(discard_tile);

        return true;
    }

    // 自摸
    public bool can_tsumo()
    {
        RoundStatePlayer player = current_player;
        //  Environment.log(LogType.DEBUG, "RoundState", @"*** rinshan: $(player.wind.to_string()) $(rinshan)");
        return player.can_tsumo(create_context(false, player.newest_tile));
    }

    public bool can_late_kan_with(int tile_ID)
    {
        return wall.can_call && wall.can_kan && current_player.can_late_kan_with(get_tile(tile_ID));
    }

    public bool can_closed_kan_with(TileType type)
    {
        return wall.can_call && wall.can_kan && current_player.can_closed_kan_with(type);
    }

    public bool can_late_kan()
    {
        return wall.can_call && wall.can_kan && current_player.can_late_kan();
    }

    public bool can_closed_kan()
    {
        return wall.can_call && wall.can_kan && current_player.can_closed_kan();
    }

    public bool can_open_kan(RoundStatePlayer player)
    {
        return
            wall.can_call &&
            wall.can_kan &&
            player != current_player &&
            last_kan_type == LastKanType.NONE && // 抢杠
            TileRules.can_open_kan(player.hand, discard_tile);
    }

    public bool can_pon(RoundStatePlayer player)
    {
        return
            wall.can_call &&
            player != current_player &&
            last_kan_type == LastKanType.NONE &&
            TileRules.can_pon(player.hand, discard_tile);
    }

    public bool can_chii(RoundStatePlayer player)
    {
        return
            wall.can_call &&
            ((current_player.index + 1) % 4 == player.index) &&
            last_kan_type == LastKanType.NONE &&
            player.can_chii(discard_tile);
    }

    public bool can_chii_with(RoundStatePlayer player, Tile tile_1, Tile tile_2)
    {
        return can_chii(player) && player.can_chii_with(tile_1, tile_2, discard_tile);
    }

    public ArrayList<ArrayList<Tile>> get_chii_groups(RoundStatePlayer player)
    {
        return player.get_chii_groups(discard_tile);
    }

    public ArrayList<Tile> get_tenpai_tiles(RoundStatePlayer player)
    {
        return TileRules.tenpai_tiles(player.hand, player.calls);
    }

    public RoundStatePlayer get_player(int player_index)
    {
        assert(player_index >= 0 && player_index < players.length);
        return players[player_index];
    }

    public Tile get_tile(int tile_ID)
    {
        return wall.get_tile(tile_ID);
    }

    public int[] get_nagashi_indices()
    {
        ArrayList<int> indices = new ArrayList<int>();

        if (game_over && game_draw_type == GameDrawType.EMPTY_WALL)
        {
            foreach (RoundStatePlayer player in players)
                if (player.has_nagashi_mangan())
                    indices.add(player.index);
        }

        return indices.to_array();
    }

    // 找到听牌的玩家
    public ArrayList<RoundStatePlayer> get_tenpai_players()
    {
        ArrayList<RoundStatePlayer> players = new ArrayList<RoundStatePlayer>();

        foreach (RoundStatePlayer player in this.players)
            if (player.in_tenpai())
                players.add(player);

        return players;
    }

    private void interrupt_flow()
    {
        foreach (RoundStatePlayer player in players)
            player.flow_interrupted();
        flow_interrupted = true;
    }

    private RoundStateContext create_context(bool ron, Tile win_tile)
    {
        bool last_tile = wall.empty;
        bool chankan = last_kan_type != LastKanType.NONE && ron;

        return new RoundStateContext
        (
            round_wind,
            ron,
            win_tile,
            last_tile,
            rinshan,
            chankan,
            flow_interrupted
        );
    }

    public Tile[] get_tiles()
    {
        return wall.tiles;
    }

    public Tile[] get_rotated_tiles()
    {
        return wall.rotated_tiles;
    }

    public RoundStatePlayer self { get { return players[player_index]; } }
    public Tile? discard_tile { get; private set; }
    public RoundStatePlayer current_player { get { return players[current_index]; } }
    public int dealer { get; private set; }
    public Wind round_wind { get; private set; }
    public bool game_over { get; private set; }
    public GameDrawType game_draw_type { get; private set; }
    public bool tiles_empty { get { return wall.empty; } }
    public Tile? dead_wall_mark { owned get { return wall.dead_wall_mark; } }
    public ArrayList<Tile> dead_wall_tiles { get { return wall.dead_wall_tiles; } }
    public LastKanType last_kan_type { get; private set; }
    public Tile? last_dead_wall_draw { get; private set; }
}

public class RoundStatePlayer
{
    private bool revealed;
    private bool do_chii_discard = false;
    private bool do_pon_discard = false;
    private bool ippatsu = false;
    private bool dealer;
    private bool tiles_called_on = false;

    private int sekinin_rinshan_index = -1;
    private int sekinin_index = -1;
    public RoundStatePlayer(int index, bool dealer, Wind wind,bool revealed)
    {
        this.index = index;
        this.dealer = dealer;
        this.wind = wind;
        this.revealed = revealed;

        hand = new ArrayList<Tile>();
        pond = new ArrayList<Tile>();
        calls = new ArrayList<RoundStateCall>();
        chii_candi = new HashSet<TileType>();
        pon_candi = new HashSet<TileType>();
        win_candi = new HashSet<TileType>();
        first_turn = true;
    }

    public bool has_tile(Tile tile)
    {
        foreach (Tile t in hand)
            if (t.ID == tile.ID)
                return true;
        return false;
    }

    public void draw_initial(Tile tile)
    {
        hand.add(tile);
    }

    public void draw(Tile tile)
    {
        hand.add(tile);
    }

    public bool discard(Tile tile)
    {
        if (!can_discard(tile))
            return false;

        hand.remove(tile);
        pond.add(tile);

        first_turn = false;
        do_chii_discard = false;
        do_pon_discard = false;
        sekinin_rinshan_index = -1;

        return true;
    }

    public void rob_tile(Tile tile)
    {
        pond.remove(tile);
        tiles_called_on = true;
    }

    public void flow_interrupted()
    {
        ippatsu = false;
        first_turn = false;
    }

    public ArrayList<Tile>? do_late_kan(Tile tile)
    {
        if (!can_late_kan_with(tile))
            return null;

        hand.remove(tile);

        ArrayList<Tile> tiles = new ArrayList<Tile>();
        tiles.add(tile);
        int discarder_index = index;

        foreach (RoundStateCall call in calls)
        {
            if (call.call_type == RoundStateCall.CallType.PON)
                if (call.tiles[0].tile_type == tile.tile_type)
                {
                    calls.remove(call);
                    tiles.add_all(call.tiles);
                    discarder_index = call.discarder_index;
                    break;
                }
        }

        calls.add(new RoundStateCall(RoundStateCall.CallType.LATE_KAN, tiles, tile, discarder_index));
        return tiles;
    }

    public ArrayList<Tile>? do_closed_kan(TileType type)
    {
        Environment.log(LogType.DEBUG, "RoundStatePlayer",
            "do_closed_kan called: player=%d, tile_type=%s".printf(index, type.to_string()));

        if (!can_closed_kan_with(type))
            return null;

        ArrayList<Tile> tiles = get_closed_kan_tiles(type);

        foreach (Tile tile in tiles)
            hand.remove(tile);

        calls.add(new RoundStateCall(RoundStateCall.CallType.CLOSED_KAN, tiles, null, index));
        return tiles;
    }

    public void do_open_kan(int discarder_index, Tile discard_tile, Tile tile_1, Tile tile_2, Tile tile_3)
    {
        hand.remove(tile_1);
        hand.remove(tile_2);
        hand.remove(tile_3);

        ArrayList<Tile> tiles = new ArrayList<Tile>();
        tiles.add(discard_tile);
        tiles.add(tile_1);
        tiles.add(tile_2);
        tiles.add(tile_3);

        RoundStateCall new_call = new RoundStateCall(RoundStateCall.CallType.OPEN_KAN, tiles, discard_tile, discarder_index);
        if (TileRules.is_sekinin(calls, new_call, discard_tile))
            sekinin_index = discarder_index;
        sekinin_rinshan_index = discarder_index;

        calls.add(new_call);
    }

    public void do_pon(int discarder_index, Tile discard_tile, Tile tile_1, Tile tile_2)
    {
        hand.remove(tile_1);
        hand.remove(tile_2);

        ArrayList<Tile> tiles = new ArrayList<Tile>();
        tiles.add(discard_tile);
        tiles.add(tile_1);
        tiles.add(tile_2);

        RoundStateCall new_call = new RoundStateCall(RoundStateCall.CallType.PON, tiles, discard_tile, discarder_index);
        if (TileRules.is_sekinin(calls, new_call, discard_tile))
            sekinin_index = discarder_index;

        calls.add(new_call);
        do_pon_discard = true;
    }

    public void do_chii(int discarder_index, Tile discard_tile, Tile tile_1, Tile tile_2)
    {
        hand.remove(tile_1);
        hand.remove(tile_2);

        ArrayList<Tile> tiles = new ArrayList<Tile>();
        tiles.add(discard_tile);
        tiles.add(tile_1);
        tiles.add(tile_2);

        RoundStateCall new_call = new RoundStateCall(RoundStateCall.CallType.CHII, tiles, discard_tile, discarder_index);
        if (TileRules.is_sekinin(calls, new_call, discard_tile))
            sekinin_index = discarder_index;

        calls.add(new_call);
        do_chii_discard = true;

    }

    public ArrayList<Tile> get_discard_tiles()
    {
        ArrayList<Tile> tiles = new ArrayList<Tile>();
       
        foreach (Tile tile in hand)
            if (can_discard(tile))
                tiles.add(tile);

        return tiles;
    }

    public ArrayList<Tile> get_late_kan_tiles(Tile tile)
    {
        ArrayList<Tile> tiles = new ArrayList<Tile>();

        for (int i = 0; i < calls.size; i++)
        {
            RoundStateCall call = calls[i];

            if (call.call_type == RoundStateCall.CallType.PON)
            {
                if (call.tiles[0].tile_type == tile.tile_type)
                {
                    tiles.add_all(call.tiles);
                    break;
                }
            }
        }

        return tiles;
    }

    public ArrayList<Tile>? get_closed_kan_tiles(TileType type)
    {
        ArrayList<Tile> tiles = new ArrayList<Tile>();
        foreach (Tile tile in hand)
            if (tile.tile_type == type)
                tiles.add(tile);

        if (tiles.size != 4)
            tiles.clear();
        return tiles;
    }

    public Scoring get_ron_score(RoundStateContext context)
    {
        return TileRules.get_score(create_context(false), context);
    }

    public Scoring get_tsumo_score(RoundStateContext context)
    {
        return TileRules.get_score(create_context(true), context);
    }

    public bool can_discard(Tile tile)
    {
        // Julian: don't understand this logic, original logic also contains riichi info
        //  if (!has_tile(tile))
        //      return false;

        // Kuikae (喰い替え) is a Riichi Mahjong rule that prevents a player from calling a tile (Chi/Pon) and then immediately discarding a tile that makes the call effectively pointless or abusive.
        // Kuikae check
        if (do_chii_discard)
        {
            //  ArrayList<Tile> open_tiles = new ArrayList<Tile>();
            //  open_tiles.add_all(newest_call.tiles);
            //  open_tiles.remove(newest_call.call_tile);

            //  if (TileRules.can_chii(open_tiles, tile))
            //      return false;

            // we only forbid discarding the chii'd tile type
            if(tile.tile_type == newest_call.call_tile.tile_type) {
                return false;
            }
        }
        else if (do_pon_discard)
        {
            if (tile.tile_type == newest_call.tiles[0].tile_type)
                return false;
        }

        return true;
    }

    public bool can_ron(RoundStateContext context)
    {
        return TileRules.can_ron(create_context(false), context);
    }

    public bool can_closed_chankan(Tile tile)
    {
        ArrayList<Tile> tiles = new ArrayList<Tile>();
        tiles.add_all(hand);
        tiles.add(tile);

        return TileRules.can_closed_chankan(tiles, calls);
    }

    public bool can_tsumo(RoundStateContext context)
    {
        //  return !do_chii_discard && !do_pon_discard && TileRules.can_tsumo(create_context(true), context);
        return TileRules.can_tsumo(create_context(true), context);
    }

    public bool can_late_kan()
    {
        //  if (do_chii_discard || do_pon_discard )
        //      return false;

        return TileRules.can_late_kan(hand, calls);
    }

    public bool can_late_kan_with(Tile tile)
    {
        return can_late_kan() && get_late_kan_tiles(tile).size > 0;
    }

    public bool can_closed_kan()
    {
        //  if (do_chii_discard || do_pon_discard)
        //      return false;

        return !revealed || TileRules.can_closed_kan(hand, calls);
    }

    public bool can_closed_kan_with(TileType type)
    {
        return can_closed_kan() && get_closed_kan_tiles(type).size > 0;
    }

    public bool can_chii(Tile discard_tile)
    {
        return get_chii_groups(discard_tile).size > 0;
    }

    public bool can_chii_with(Tile tile_1, Tile tile_2, Tile discard_tile)
    {
        ArrayList<Tile> tiles = new ArrayList<Tile>();
        tiles.add(tile_1);
        tiles.add(tile_2);

        if (!TileRules.can_chii(tiles, discard_tile))
            return false;

        foreach (Tile tile in hand)
        {
            if (tile == tile_1 || tile == tile_2)
                continue;

            if (!TileRules.can_chii(tiles, tile))
                return true;
        }

        return false;
    }

    public ArrayList<ArrayList<Tile>> get_chii_groups(Tile discard_tile)
    {
        ArrayList<ArrayList<Tile>> groups = TileRules.get_chii_groups(hand, discard_tile);

        for (int i = 0; i < groups.size; i++)
        {
            ArrayList<Tile> group = groups[i];
            if (!can_chii_with(group[0], group[1], discard_tile))
                groups.remove_at(i--);
        }

        return groups;
    }

    public ArrayList<ArrayList<Tile>> get_closed_kan_groups()
    {
        return TileRules.get_closed_kan_groups(hand, calls);
    }

    public int get_kan_count()
    {
        int count = 0;
        foreach (RoundStateCall call in calls)
            if (call.call_type == RoundStateCall.CallType.OPEN_KAN ||
                call.call_type == RoundStateCall.CallType.CLOSED_KAN ||
                call.call_type == RoundStateCall.CallType.LATE_KAN)
                count++;

        return count;
    }

    public Tile get_default_discard_tile()
    {
        ArrayList<Tile> tiles = get_discard_tiles();
        return tiles[tiles.size - 1];
    }

    //  Nagashi Mangan (流し満貫) is a special winning condition in Riichi Mahjong. It's not a normal yaku-based win. Instead, you can be awarded a Mangan if the hand ends in an exhaustive draw under specific conditions.
    public bool has_nagashi_mangan()
    {
        return !tiles_called_on && calls.size == 0 && TileRules.is_nagashi_mangan(pond);
    }

    // 玩家是否听牌
    public bool in_tenpai()
    {
        return TileRules.in_tenpai(hand, calls);
    }

    private PlayerStateContext create_context(bool tsumo)
    {
        ArrayList<Tile> hand = new ArrayList<Tile>();
        hand.add_all(this.hand);
        if (tsumo)
            hand.remove(newest_tile);

        int sekinin = sekinin_rinshan_index;
        if (sekinin_index != -1)
            sekinin = sekinin_index;

        return new PlayerStateContext
        (
            index,
            hand,
            pond,
            calls,
            wind,
            dealer,
            open,
            ippatsu,
            tiles_called_on,
            first_turn,
            sekinin
        );
    }

    // The tile that the play wants to chii
    // cal_map should already be called outside 
    public void cal_chii_candi()
    {
        // 有碰一般不会去吃， 先根据pon打薄
        chii_candi.clear();
        if(!dangerous) {
            // 不危险的话，就当他啥都不会吃吧
            return;
        }
        // type_category: 0: MAN 1:PIN 2:SOU 
        add_chii_candi(0);
        add_chii_candi(1);
        add_chii_candi(2);
    }

    // cal_map should already be called outside  
    public void cal_pon_candi()
    {
        pon_candi.clear();
        if(!dangerous) {
            return;
        }
        add_pon_candi(0);
        add_pon_candi(1);
        add_pon_candi(2);
        if(dragon_cnt >= 2 && dragon_cnt != 4) {
            pon_candi.add(TileType.CHUN);
            pon_candi.add(TileType.HATSU);
            pon_candi.add(TileType.HAKU);
        }
    }
    public void cal_win_candi()
    {
        win_candi.clear();
        // Find all tiles that would complete this hand (tenpai)
        ArrayList<HandReading> readings = TileRules.hand_readings(hand, calls, true, false);
        //  Environment.log(LogType.DEBUG, "RoundState", @"Player $(index): hand_readings returned $(readings.size) readings (hand size: $(hand.size), calls: $(calls.size))");
        foreach (HandReading hr in readings) {
            foreach (Tile tHR in hr.tiles) {
                if (tHR.ID == -1) {  // ID == -1 means this is the needed tile
                    win_candi.add(tHR.tile_type);
                }
            }
        }
        Environment.log(LogType.DEBUG, "RoundState", @"Player $(index) $(wind.to_string()) handsize: $(hand.size)");
        if (win_candi.size > 0) {
            StringBuilder sb = new StringBuilder();
            foreach (TileType tt in win_candi) {
                sb.append(new Tile(-1, tt).to_string() + " ");
            }
            Environment.log(LogType.DEBUG, "RoundState", @" |- calculated win_candi: $(sb.str)");
        }
    }
   
    // 打薄: reduce count by removing a pon (3) or pair (2) if present
    private int thin_pon(int cnt) {
        if (cnt >= 3) return cnt - 3;
        if (cnt >= 2) return cnt - 2;
        return cnt;
    }

    // type_category: 0: MAN 1:PIN 2:SOU
    // 有碰一般不会去吃， 先根据pon打薄
    private void add_chii_candi(int type_category) {
        TileType start_tile;
        TileType end_tile;
        HashMap<TileType, int> the_map;

        switch (type_category) {
            case 0:
                start_tile = TileType.MAN1;
                end_tile = TileType.MAN7;
                the_map = map_man;
                break;
            case 1:
                start_tile = TileType.PIN1;
                end_tile = TileType.PIN7;
                the_map = map_pin;
                break;
            case 2:
                start_tile = TileType.SOU1;
                end_tile = TileType.SOU7;
                the_map = map_sou;
                break;
            default:
                return;
        }

        for(int i = start_tile ; i <= end_tile ; i++ ) {
            int i_cnt = the_map.get( (TileType) i);
            int p1_cnt = the_map.get( (TileType) (i + 1));
            int p2_cnt = the_map.get( (TileType) (i + 2));
            i_cnt = thin_pon(i_cnt);
            p1_cnt = thin_pon(p1_cnt);
            p2_cnt = thin_pon(p2_cnt);

            int smallest = int.min(i_cnt, int.min(p1_cnt, p2_cnt));
            i_cnt -= smallest;
            p1_cnt -= smallest;
            p2_cnt -= smallest;
            if(i_cnt > 1 && p1_cnt > 1) {
                chii_candi.add(i + 2);
            } else if(i_cnt > 1 && p2_cnt > 1) {
                chii_candi.add(i + 1); 
            } else if(p1_cnt > 1 && p2_cnt > 1) {
                chii_candi.add(i); 
            }
        } 
    }

    // Even when you have 3 of TileType, it's still possible that you want to pon to optimize your hand
    private void add_pon_candi(int type_category) {
        TileType start_tile;
        TileType end_tile;
        HashMap<TileType, int> the_map;

        switch (type_category) {
            case 0:
                start_tile = TileType.MAN1;
                end_tile = TileType.MAN7;
                the_map = map_man;
                break;
            case 1:
                start_tile = TileType.PIN1;
                end_tile = TileType.PIN7;
                the_map = map_pin;
                break;
            case 2:
                start_tile = TileType.SOU1;
                end_tile = TileType.SOU7;
                the_map = map_sou;
                break;
            default:
                return;
        }

        for(int i = start_tile ; i <= end_tile ; i++ ) {
            int i_cnt = the_map.get( (TileType) i);
            if(i_cnt >= 2 && i_cnt != 4) {
                pon_candi.add(i);
            }
        } 
    }

    public void assess_risk() {
        dangerous = false;
        map_man = create_suit_map(TileType.MAN1, TileType.MAN9);
        map_pin = create_suit_map(TileType.PIN1, TileType.PIN9);
        map_sou = create_suit_map(TileType.SOU1, TileType.SOU9);
        dragon_cnt = 0;
        int single_cnt = 0;
        foreach (Tile t in this.hand)
        {
            if (t.tile_type >= TileType.MAN1 && t.tile_type <= TileType.MAN9)
            {
                map_man.set(t.tile_type, map_man.get(t.tile_type) + 1);
            }
            else if (t.tile_type >= TileType.PIN1 && t.tile_type <= TileType.PIN9)
            {
                map_pin.set(t.tile_type, map_pin.get(t.tile_type) + 1);
            }
            else if (t.tile_type >= TileType.SOU1 && t.tile_type <= TileType.SOU9)
            {
                map_sou.set(t.tile_type, map_sou.get(t.tile_type) + 1);
            }

            if (t.is_dragon_tile())
            {
                dragon_cnt++;
            }
        }
        if(dragon_cnt == 1) {
            single_cnt++;
        }
        for(int tt = TileType.MAN1; tt <= TileType.MAN7; tt++) {
            int p2_cnt = map_man.get(tt + 2);
            int p1_cnt = map_man.get(tt + 1);
            if(p2_cnt == 0 && p1_cnt == 0) {
               single_cnt ++; 
            }
        }
        for(int tt = TileType.PIN1; tt <= TileType.PIN7; tt++) {
            int p2_cnt = map_pin.get(tt + 2);
            int p1_cnt = map_pin.get(tt + 1);
            if(p2_cnt == 0 && p1_cnt == 0) {
               single_cnt ++; 
            }
        }
        for(int tt = TileType.SOU1; tt <= TileType.SOU7; tt++) {
            int p2_cnt = map_sou.get(tt + 2);
            int p1_cnt = map_sou.get(tt + 1);
            if(p2_cnt == 0 && p1_cnt == 0) {
               single_cnt ++; 
            }
        }
        if(single_cnt <= 2) {
            dangerous = true;
        }
    }

    private static HashMap<TileType, int> create_suit_map(int start_tile, int end_tile)
    {
        HashMap<TileType, int> map = new HashMap<TileType, int>();
        for (int i = start_tile; i <= end_tile; i++)
        {
            map.set((TileType)i, 0);
        }
        return map;
    }
    public int index { get; private set; }
    public Wind wind { get; private set; }
    public ArrayList<Tile> hand { get; private set; }
    public ArrayList<Tile> pond { get; private set; }
    public ArrayList<RoundStateCall> calls { get; private set; }

    // reserved to use for OracleBot who can always see through other players hand tiles 
    public HashSet<TileType> chii_candi { get; private set; }
    public HashSet<TileType> pon_candi { get; private set; }
    public HashSet<TileType> win_candi { get; private set; }
    public HashMap<TileType, int> map_man { get; private set; }
    public HashMap<TileType, int> map_pin { get; private set; }
    public HashMap<TileType, int> map_sou { get; private set; }
    public bool dangerous = false; // 是否需要防范
    public int dragon_cnt { get; private set; }

    public bool open { get; private set; } // Open riichi
    public bool first_turn { get; private set; }
    public Tile newest_tile { owned get { return hand[hand.size - 1]; } }
    public RoundStateCall newest_call { owned get { return calls[calls.size - 1]; } }
}

class RoundStateWall
{
    // Northeast Mahjong tile count: 9*3 (MAN/SOU/PIN) * 4 + 4 (HATSU only) = 112
    private const int TOTAL_TILES = 112;

    private ArrayList<Tile> wall_tiles = new ArrayList<Tile>();
    public ArrayList<Tile> dead_wall_tiles = new ArrayList<Tile>();
    private int owner_player_index = -1;  // -1 = server, 0-3 = bot player index

    public void set_owner_context(int player_index)
    {
        owner_player_index = player_index;
    }

    public RoundStateWall(int dealer, int wall_index)
    {
        init(dealer, wall_index, TileType.HATSU, null, false, false, null, null, null, null, null, null, null);
    }

    public RoundStateWall.shuffled(int dealer, int wall_index, RandomClass rnd)
    {
        init(dealer, wall_index, TileType.HATSU, rnd, true, false, null, null, null, null, null, null, null);
    }

    public RoundStateWall.seeded(int dealer, int wall_index, bool shuffle, RandomClass? rnd, TileType[] p1_tiles, TileType[] p2_tiles, TileType[] p3_tiles, TileType[] p4_tiles, TileType[] draw_tiles, TileType[] dead_wall)
    {
        init(dealer, wall_index, TileType.HATSU, rnd, shuffle, true, null, p1_tiles, p2_tiles, p3_tiles, p4_tiles, draw_tiles, dead_wall);
    }

    public RoundStateWall.custom(int dealer, int wall_index, Tile[] tiles)
    {
        init(dealer, wall_index, TileType.HATSU, null, false, false, tiles, null, null, null, null, null, null);
    }

    private void init(int dealer, int wall_index, TileType dragon, RandomClass? rnd, bool shuffled, bool seeded, Tile[]? custom_tiles, TileType[]? p1_tiles, TileType[]? p2_tiles, TileType[]? p3_tiles, TileType[]? p4_tiles, TileType[]? draw_tiles, TileType[]? dead_wall)
    {
        // 东北麻将张数应该是 9*3（万筒索）* 4 + 4 （中/发/白） = 112
        // 按四面墙来算的话：14 * 2 * 4 = 112
        if (custom_tiles != null)
            tiles = custom_tiles;
        else
            tiles = new Tile[TOTAL_TILES];


        //  stdout.printf("shuffled : %d  seeded: %d \n", (int)shuffled, (int)seeded);
        if (custom_tiles == null)
        {
            int iTile = 0;
            for (int i = TileType.MAN1; i < TileType.TON; i++)
            {
                // Always initialize with real tile types, whether shuffled or not
                TileType type = !seeded ? (TileType)(i) : TileType.BLANK;
                tiles[iTile++] = new Tile(-1, type);
                tiles[iTile++] = new Tile(-1, type);
                tiles[iTile++] = new Tile(-1, type);
                tiles[iTile++] = new Tile(-1, type);
            }
            // 中 发 白 中 选一个
            tiles[iTile++] = new Tile(-1, dragon);
            tiles[iTile++] = new Tile(-1, dragon);
            tiles[iTile++] = new Tile(-1, dragon);
            tiles[iTile++] = new Tile(-1, dragon);
        }

        int start_wall = (4 - dealer) % 4;
        int index = start_wall * 28 + wall_index * 2;

        if (seeded)
            seed(index, rnd, tiles, p1_tiles, p2_tiles, p3_tiles, p4_tiles, draw_tiles, dead_wall);
        else if (shuffled)
            shuffle(tiles, rnd);

        for (int i = 0; i < tiles.length; i++)
        {
            tiles[i].ID = i;
        }

        for (int i = 0; i < tiles.length; i++)
        {
            int t = (index + i) % 112;
            wall_tiles.add(tiles[t]);
        }

        // Initialize the dead wall: move the last 8 tiles from wall_tiles to dead_wall_tiles
        // In Northeast Mahjong, the dead wall consists of 8 tiles (4 stacks)
        // Physical positions 104-111 after reordering
        // wall_tiles currently has positions [0...111], so we remove [104...111]
        int dead_wall_start_pos = 104;

        for (int i = 0; i < 8; i++)
        {
            // Remove position (104+i) from wall_tiles
            // Since wall_tiles.size is shrinking, position 104 is always at index 104
            Tile tile = wall_tiles.remove_at(dead_wall_start_pos);
            dead_wall_tiles.add(tile);
        }
        // Now wall_tiles has 104 tiles (0-103), and dead_wall_tiles has 8 tiles (104-111)

        // Save rotated tiles BEFORE dead wall reversal - this is what should be saved to game log
        rotated_tiles = new Tile[TOTAL_TILES];
        int rt_idx = 0;
        foreach (Tile tile in wall_tiles)
            rotated_tiles[rt_idx++] = tile;
        foreach (Tile tile in dead_wall_tiles)
            rotated_tiles[rt_idx++] = tile;

        // REVERSE the dead_wall_tiles array so drawing from index 0 draws from the far end
        // But swap pairs so upper tiles come before lower tiles in each stack
        // Original: [104=upper, 105=lower, 106=upper, 107=lower, 108=upper, 109=lower, 110=upper, 111=lower]
        // Want: [110=upper, 111=lower, 108=upper, 109=lower, 106=upper, 107=lower, 104=upper, 105=lower]
        // This draws: 110(upper) first, then 111(lower), then 108(upper), etc.
        ArrayList<Tile> reversed = new ArrayList<Tile>();
        for (int i = dead_wall_tiles.size - 2; i >= 0; i -= 2)
        {
            reversed.add(dead_wall_tiles[i]);     // Add upper tile of this stack
            reversed.add(dead_wall_tiles[i + 1]); // Add lower tile of this stack
        }
        dead_wall_tiles = reversed;

    }

    public Tile draw_wall()
    {
        assert(wall_tiles.size > 0);

        Tile tile = wall_tiles.remove_at(0);
        return tile;
    }

    public Tile draw_dead_wall()
    {
        assert(dead_wall_tiles.size > 0);

        int idx = 0;
        Tile tile = dead_wall_tiles.remove_at(idx);
        return tile;
    }

    public Tile? get_tile(int tile_ID)
    {
        assert(tile_ID >= 0 && tile_ID < tiles.length);

        foreach (Tile tile in tiles)
            if (tile.ID == tile_ID)
                return tile;
        return null;
    }

    private static void shuffle(Tile[] tiles, RandomClass rnd)
    {
        for (int i = 0; i < tiles.length; i++)
        {
            int tmp = rnd.int_range(0, tiles.length);
            Tile t = tiles[i];
            tiles[i] = tiles[tmp];
            tiles[tmp] = t;
        }
    }

    private static void seed(int index, RandomClass? rnd, Tile[] tiles, TileType[] p1_tiles, TileType[] p2_tiles, TileType[] p3_tiles, TileType[] p4_tiles, TileType[] draw_tiles, TileType[] dead_wall)
    {
        assert( tiles.length == TOTAL_TILES );
        ArrayList<TileType> unassigned = new ArrayList<TileType>();
        for (int i = 0; i < TOTAL_TILES - 4 ; i++) {
            unassigned.add((TileType)((i / 4) + 1)); // start from MAN1 to SOU9 
        }
        // Northeast Mahjong uses HATSU as the only dragon tile
        for (int i = 0; i < 4; i++) {
            //  unassigned.add(TileType.CHUN);
            //  unassigned.add(TileType.HAKU);
            unassigned.add(TileType.HATSU);
        }

        int length = tiles.length;

        for (int i = 0; i < 4; i++)
        {
            for (int j = 0; j < 4; j++)
            {
                int a = i * 4 + j;

                if (p1_tiles.length > a)
                    replace(tiles, p1_tiles[a], unassigned, index);
                index++;
                length--;

                if (a >= 12)
                    break;
            }

            for (int j = 0; j < 4; j++)
            {
                int a = i * 4 + j;
                if (p2_tiles.length > a)
                    replace(tiles, p2_tiles[a], unassigned, index);
                index++;
                length--;

                if (a >= 12)
                    break;
            }

            for (int j = 0; j < 4; j++)
            {
                int a = i * 4 + j;
                if (p3_tiles.length > a)
                    replace(tiles, p3_tiles[a], unassigned, index);
                index++;
                length--;

                if (a >= 12)
                    break;
            }

            for (int j = 0; j < 4; j++)
            {
                int a = i * 4 + j;
                if (p4_tiles.length > a)
                    replace(tiles, p4_tiles[a], unassigned, index);
                index++;
                length--;

                if (a >= 12)
                    break;
            }
        }

        for (int i = 0; i < draw_tiles.length; i++)
        {
            replace(tiles, draw_tiles[i], unassigned, index++);
            length--;
        }

        index += length - 8;  // Skip to dead wall position (8 tiles for dead wall)

        for (int i = 0; i < dead_wall.length; i++)
            replace(tiles, dead_wall[i], unassigned, index++);

        foreach (Tile t in tiles)
            if (t.tile_type == TileType.BLANK)
            {
                assert(unassigned.size > 0);
                t.tile_type = unassigned.remove_at(rnd.int_range(0, unassigned.size));
            }
    }

    private static void replace(Tile[] tiles, TileType tile_type, ArrayList<TileType> unassigned, int index)
    {
        if (tile_type == TileType.BLANK)
            return;

        index = index % tiles.length;

        for (int i = 0; i < unassigned.size; i++)
            if (unassigned[i] == tile_type)
            {
                tiles[index].tile_type = unassigned.remove_at(i);
                return;
            }

        Environment.log(LogType.GAME, "RoundStateWall", "RoundState seed, did not find " + tile_type.to_string());
    }

    public int tiles_size { get { return wall_tiles.size; } }
    public bool empty { get { return wall_tiles.size == 0; } }
    public bool can_kan { get { return dead_wall_tiles.size > 2; } }  // Must keep at least 2 tiles (the mark stack)
    public bool can_call { get { return wall_tiles.size > 0; } }
    public bool can_riichi { get { return wall_tiles.size >= 4; } }
    public Tile[] tiles { get; private set; }
    public Tile[] rotated_tiles { get; private set; }

    // Get the dead wall mark tile (the tile near the draw wall that gets revealed)
    // In Northeast Mahjong, the mark is tile 104 (the first dead wall tile logically, upper layer)
    // After reversal with pair swapping: [110, 111, 108, 109, 106, 107, 104, 105]
    // Tile 104 is at index 6 (second to last), tile 105 is at index 7 (last)
    public Tile? dead_wall_mark
    {
        owned get
        {
            int size = dead_wall_tiles.size;
            if (size >= 2)
            {
                int mark_idx = size - 2;
                Tile mark = dead_wall_tiles[mark_idx];
                return mark;
            }
            return null;
        }
    }
}

public enum GameDrawType
{
    NONE,
    EMPTY_WALL,
    FOUR_WINDS,
    FOUR_KANS,
    FOUR_RIICHI,
    VOID_HAND,
    TRIPLE_RON
}

public enum LastKanType
{
    NONE,
    OPEN,
    LATE,
    CLOSED
}
