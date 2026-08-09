using Gee;
using Engine;

public abstract class Bot : Object
{
    private bool active = false;
    private Mutex mutex = Mutex();
    private int player_index;
    private ServerSettings settings;

    protected GameState game_state;
    protected RoundState? round_state;

    public void init_game(GameStartInfo info, ServerSettings settings, int player_index)
    {
        game_state = new GameState(info, settings);
        this.player_index = player_index;
        this.settings = settings;
        active = true;
        Threading.start0(logic);
    }

    public void start_round(bool use_lock, RoundStartInfo info)
    {
        if (use_lock)
            mutex.lock();

        game_state.start_round(info);
        round_state = new RoundState(settings, player_index, game_state.round_wind, game_state.dealer_index, info.wall_index);
        round_state.start();

        if (use_lock)
            mutex.unlock();
    }

    public void stop(bool use_lock)
    {
        if (use_lock)
            mutex.lock();

        active = false;
        round_state = null;

        if (use_lock)
            mutex.unlock();
    }

    private void logic()
    {
        ref();

        while (true)
        {
            mutex.lock();
            if (!active)
                break;

            poll();

            if (round_state != null)
                do_logic();

            if (!active)
                break;
            mutex.unlock();

            sleep();
        }

        mutex.unlock();

        unref();
    }

    protected virtual void sleep()
    {
        // In bot simulation mode, use minimal sleep for fast execution
        // In normal gameplay, use 100ms to avoid excessive CPU usage
        Thread.usleep(settings.bot_simulation ? 100 : 100000);
    }

    /////////////

    public void tile_assign(Tile tile)
    {
        round_state.tile_assign(tile);
    }

    public void tile_draw()
    {
        round_state.tile_draw();
    }

    public void tile_discard(int tile_ID)
    {
        round_state.tile_discard(tile_ID);
    }

    public void ron(int[] player_indices)
    {
        int discarder_index = round_state.current_player.index;
        round_state.ron(player_indices);
        Scoring[] scores = round_state.get_ron_score();
        RoundFinishResult result = new RoundFinishResult.ron(scores, player_indices, discarder_index, round_state.discard_tile.ID);
        game_state.round_finished(result);
    }

    public void tsumo()
    {
        round_state.tsumo();
        Scoring score = round_state.get_tsumo_score();
        RoundFinishResult result = new RoundFinishResult.tsumo(score, round_state.current_player.index);
        game_state.round_finished(result);
    }

    public void turn_decision()
    {
        do_turn_decision();
    }

    public void call_decision()
    {
        do_call_decision(round_state.current_player, round_state.discard_tile);
    }

    public void late_kan(int tile_ID)
    {
        round_state.late_kan(tile_ID);
    }

    public void closed_kan(TileType type)
    {
        round_state.closed_kan(type);
    }

    public void open_kan(int player_index, int tile_1_ID, int tile_2_ID, int tile_3_ID)
    {
        round_state.open_kan(player_index, tile_1_ID, tile_2_ID, tile_3_ID);
    }

    public void pon(int player_index, int tile_1_ID, int tile_2_ID)
    {
        round_state.pon(player_index, tile_1_ID, tile_2_ID);
    }

    public void chii(int player_index, int tile_1_ID, int tile_2_ID)
    {
        round_state.chii(player_index, tile_1_ID, tile_2_ID);
    }

    public void calls_finished()
    {
        round_state.calls_finished();
    }

    public void draw(int[] tenpai_indices, bool void_hand, bool triple_ron)
    {
        if (void_hand)
            round_state.void_hand();
        else if (triple_ron)
            round_state.triple_ron();

        RoundFinishResult result = new RoundFinishResult.draw(tenpai_indices, round_state.get_nagashi_indices(), round_state.game_draw_type);
        game_state.round_finished(result);
    }
    protected bool has_neighbours(Tile tile)
    {
        if (!tile.is_suit_tile())
            return false;

        foreach (Tile t in round_state.self.hand)
        {
            if (tile == t)
                continue;

            if (tile.is_neighbour(t))
                return true;
        }

        return false;
    }
    protected bool has_non_terminal_neighbours(Tile tile)
    {
        if (!tile.is_suit_tile())
            return false;

        foreach (Tile t in round_state.self.hand)
        {
            if (tile == t)
                continue;

            if (!t.is_terminal_tile() &&  t.is_neighbour(tile))
                return true;
        }

        return false;
    }

    public bool has_second_neighbours(Tile tile)
    {
        if (!tile.is_suit_tile())
            return false;

        foreach (Tile t in round_state.self.hand)
        {
            if (tile == t)
                continue;

            if (tile.is_second_neighbour(t))
                return true;
        }

        return false;
    }

    public void count_singles_ish(HashMap<TileType, int> suit_map,
                                     int start_tile,
                                     int end_tile,
                                     ref ArrayList<TileType> singles_ish,
                                     HashMap<TileType,int>? hOP)
    {
        if(hOP == null) {
            return;
        }
        for (int i = start_tile; i <= end_tile; i++) {
            int i_count = suit_map.get((TileType)i);
            int m1 = i - 1 >= start_tile ? suit_map.get((TileType)(i - 1)) : 0;
            int mo1 = i - 1 >= start_tile ? hOP.get((TileType)(i - 1)) : 0;
            int m2 = i - 2 >= start_tile ? suit_map.get((TileType)(i - 2)) : 0;
            int mo2 = i - 2 >= start_tile ? hOP.get((TileType)(i - 2)) : 0; // in other player
            int p1 = i + 1 <= end_tile ? suit_map.get((TileType)(i + 1)) : 0;
            int po1 = i + 1 <= end_tile ? hOP.get((TileType)(i + 1)) : 0;
            int p2 = i + 2 <= end_tile ? suit_map.get((TileType)(i + 2)) : 0;
            int po2 = i + 2 <= end_tile ? hOP.get((TileType)(i + 2)) : 0;
            if( i_count == 1) { 
                // 98 no 7 
                if(i== end_tile && m1 == 1 && m2 == 0 && mo2 >= 3) {
                    singles_ish.add(i);
                    singles_ish.add(i-1);
                }
                // 97 no 8
                if(i== end_tile && m2 == 1 && m1 == 0 && mo1 >= 3) {
                    singles_ish.add(i);
                }
                // 12 no 3
                if(i== start_tile && p1 == 1 && p2 == 0 && po2 >= 3) {
                    singles_ish.add(i);
                    singles_ish.add(i+1);
                }
                // 13 no 2
                if(i== start_tile && p2 == 1 && p1 == 0 && po1 >= 3) {
                    singles_ish.add(i);
                } 

            }
           
        }
    }

    ////////////

    public signal void poll();

    public signal void do_discard(Tile tile);
    public signal void do_tsumo();
    public signal void do_void_hand();
    public signal void do_riichi(bool open);
    public signal void do_late_kan(Tile tile);
    public signal void do_closed_kan(TileType type);
    public signal void call_nothing();
    public signal void call_ron();
    public signal void call_open_kan();
    public signal void call_pon();
    public signal void call_chii(Tile tile_1, Tile tile_2);

    protected abstract void do_turn_decision();
    protected abstract void do_call_decision(RoundStatePlayer discarding_player, Tile tile);
    protected virtual void do_logic() {}
    public abstract string name { get; }
}
