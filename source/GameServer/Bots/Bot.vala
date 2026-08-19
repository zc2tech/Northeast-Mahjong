using Gee;
using Engine;

public abstract class Bot : Object
{
    private bool active = false;
    private Mutex mutex = Mutex();
    private int player_index;
    private ServerSettings settings;
    public Engine.RandomClass rnd = new Engine.RandomClass();

    protected GameState game_state;
    protected RoundState? round_state;
    private ShantenCalculator shanten_calc;

    construct
    {
        shanten_calc = ShantenCalculator.get_instance();
    }

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

    public void dead_wall_draw(Tile tile)
    {
        round_state.tile_assign(tile);
        // Set rinshan flag - prevents tsumo on this draw
        round_state.rinshan = true;
    }

    public void tile_draw()
    {
        round_state.tile_draw();
    }

    public void tile_discard(int tile_ID)
    {
        //  Tile tile = round_state.get_tile(tile_ID);
        //  int discard_player_index = round_state.current_player.index;
        //  int hand_size_before = round_state.current_player.hand.size;

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
        //  Environment.log(LogType.DEBUG, this.name, @"turn_decision: current_player=$(round_state.current_player.index)");
        //  for (int i = 0; i < 4; i++)
        //  {
        //      RoundStatePlayer p = round_state.get_player(i);
            //  Environment.log(LogType.DEBUG, this.name, @"  Player $i: hand=$(p.hand.size), pond=$(p.pond.size), calls=$(p.calls.size)");
        //  }
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
        //  int discard_player_index = round_state.get_last_discard_player_index();

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

    public ArrayList<Tile> second_neighbours(Tile tile)
    {
        ArrayList<Tile> rtn = new ArrayList<Tile>();
        if (!tile.is_suit_tile()) {
            return rtn;
        }

        foreach (Tile t in round_state.self.hand)
        {
            if (tile == t)
                continue;

            if (tile.is_second_neighbour(t))
                rtn.add(t);
        }

        return rtn;
    }
    
    public ArrayList<Tile> neighbours(Tile tile)
    {
        ArrayList<Tile> rtn = new ArrayList<Tile>();
        if (!tile.is_suit_tile()) {
            return rtn;
        }

        foreach (Tile t in round_state.self.hand)
        {
            if (tile == t)
                continue;

            if (tile.is_neighbour(t))
                rtn.add(t);
        }

        return rtn;
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

    // Analyze hand and return statistics
    // param tile, 吃碰杠 对象, 可以为 null 表示这是 turn decision
    // param hOP (Other Player all tiles) 有可能 null, 那时候 singles_ish 之类的可能就不准了 
    public HandStatistics analyze_hand(Tile? tile, ArrayList<Tile> sorted_hand, ArrayList<RoundStateCall> calls, HashMap<TileType, int>? hCalled)
    {
        HandStatistics stats = HandStatistics();
        stats.two_player_carry = new ArrayList<Tile>();
        stats.two_player_carry.add_all(sorted_hand); // 二人抬轿 只是把刻子，对子移除。后续还要设牌时判断
        stats.terminal_count = 0;
        stats.dragon_count = 0;
        stats.hand_in_seq = new HashSet<TileType>(); // 手牌里 在顺子中的单个牌
        stats.singles = new ArrayList<TileType>();
        stats.singles_ish = new ArrayList<TileType>();
        stats.pair_count = 0; // triplet not count in
        stats.triplet_count = 0;
        stats.hasTerminalSeq = false; // 这个指标实在太关键了
        stats.hasTerminalTriplet= false; // 这个指标实在太关键了
        stats.rare_dragon_terminal = TileType.BLANK;

         // Initiate suit maps
        HashMap<TileType, int> map_man = create_suit_map(TileType.MAN1, TileType.MAN9);
        HashMap<TileType, int> map_pin = create_suit_map(TileType.PIN1, TileType.PIN9);
        HashMap<TileType, int> map_sou = create_suit_map(TileType.SOU1, TileType.SOU9);
        HashSet<TileType> suit_categories = new HashSet<TileType>(); // 不去管中发白, 用来判断清一色
        // Count tiles by suit
        foreach (Tile t in sorted_hand)
        {
            if (t.is_terminal_tile())
            {
                stats.terminal_count++;
            }
            // Fixed bug: was using mapMan for all suits
            if (t.tile_type >= TileType.MAN1 && t.tile_type <= TileType.MAN9)
            {
                map_man.set(t.tile_type, map_man.get(t.tile_type) + 1);
                suit_categories.add(TileType.MAN1);
            }
            else if (t.tile_type >= TileType.PIN1 && t.tile_type <= TileType.PIN9)
            {
                map_pin.set(t.tile_type, map_pin.get(t.tile_type) + 1);
                suit_categories.add(TileType.PIN1);
            }
            else if (t.tile_type >= TileType.SOU1 && t.tile_type <= TileType.SOU9)
            {
                map_sou.set(t.tile_type, map_sou.get(t.tile_type) + 1);
                suit_categories.add(TileType.SOU1);
            }

            if (t.is_dragon_tile())
            {
                stats.dragon_count++;
            }
        }

        // prepare data for two_player_carry check
        remove_melds(TileType.MAN1, TileType.MAN9,map_man, ref stats.two_player_carry);
        remove_melds(TileType.PIN1, TileType.PIN9,map_pin, ref stats.two_player_carry);
        remove_melds(TileType.SOU1, TileType.SOU9,map_sou, ref stats.two_player_carry);

        // 这时候还只是算手牌的中发白，二人抬轿预备队里 所以有刻子把它去了
        if(stats.dragon_count >=3 ) {
            int counter = 0;
            for (int i = stats.two_player_carry.size - 1; i >= 0 && counter < 3; i--) {
                if (stats.two_player_carry[i].is_dragon_tile()) {
                    stats.two_player_carry.remove_at(i);
                    counter++;
                }
            }
        }

        // 找到含幺九的顺子就走
        if( map_man[TileType.MAN1] > 0  && map_man[TileType.MAN2] > 0 && map_man[TileType.MAN3] > 0) {
            stats.hasTerminalSeq = true;
        }
        if( map_man[TileType.MAN9] > 0  && map_man[TileType.MAN8] > 0 && map_man[TileType.MAN7] > 0) {
            stats.hasTerminalSeq = true;
        }
        if( map_pin[TileType.PIN1] > 0  && map_pin[TileType.PIN2] > 0 && map_pin[TileType.PIN3] > 0) {
            stats.hasTerminalSeq = true;
        }
        if( map_pin[TileType.PIN9] > 0 && map_pin[TileType.PIN8] > 0 && map_pin[TileType.PIN7] > 0) {
            stats.hasTerminalSeq = true;
        }
        if( map_sou[TileType.SOU1] > 0 && map_sou[TileType.SOU2] > 0 && map_sou[TileType.SOU3] > 0) {
            stats.hasTerminalSeq = true;
        }
        if( map_sou[TileType.SOU9] > 0 && map_sou[TileType.SOU8] > 0 && map_sou[TileType.SOU7] > 0) {
            stats.hasTerminalSeq = true;
        }
        if( map_man[TileType.MAN1] >= 3 || map_man[TileType.MAN9] >= 3
             || map_pin[TileType.PIN1] >=3 || map_pin[TileType.PIN9] >= 3
             || map_sou[TileType.SOU1] >=3 || map_sou[TileType.SOU9] >= 3
            ) 
        {
            stats.hasTerminalTriplet = true;
        }

        // Analyze patterns for each suit
        count_suit_patterns(map_man, TileType.MAN1, TileType.MAN9,
                           ref stats.singles, ref stats.hand_in_seq, ref stats.pair_count, ref stats.triplet_count);
        count_suit_patterns(map_pin, TileType.PIN1, TileType.PIN9,
                           ref stats.singles, ref stats.hand_in_seq, ref stats.pair_count, ref stats.triplet_count);
        count_suit_patterns(map_sou, TileType.SOU1, TileType.SOU9,
                           ref stats.singles, ref stats.hand_in_seq,  ref stats.pair_count, ref stats.triplet_count);

         // help you to find out neighbours(two) that has no hope to formulate sequence
        count_singles_ish(map_man, TileType.MAN1, TileType.MAN9, ref stats.singles_ish, hCalled);  
        count_singles_ish(map_man, TileType.PIN1, TileType.PIN9, ref stats.singles_ish, hCalled);  
        count_singles_ish(map_man, TileType.SOU1, TileType.SOU9, ref stats.singles_ish, hCalled);  
        // Count half-sequences involving the given tile (for pon/kan decisions)
        // A half-sequence is two tiles that can form a sequence with one more tile
        if (tile != null)
        {
            if (tile.is_same_sort(new Tile(-1, TileType.MAN1)))
            {
                count_half_sequences(map_man, tile.tile_type, TileType.MAN1, TileType.MAN9, ref stats.half_sequence_count_by_tile);
            }
            else if (tile.is_same_sort(new Tile(-1, TileType.PIN1)))
            {
                count_half_sequences(map_pin, tile.tile_type, TileType.PIN1, TileType.PIN9, ref stats.half_sequence_count_by_tile);
            }
            else if (tile.is_same_sort(new Tile(-1, TileType.SOU1)))
            {
                count_half_sequences(map_sou, tile.tile_type, TileType.SOU1, TileType.SOU9, ref stats.half_sequence_count_by_tile);
            }
        }

        // Handle dragon tiles
        if (stats.dragon_count == 2)
        {
            stats.pair_count++;
        }
        if (stats.dragon_count >= 3)
        {
            stats.triplet_count++;
        }

        // 已经碰完的牌了, 也给反映到数据上
       
        foreach( RoundStateCall c in calls) {
           
            if(c.call_type == RoundStateCall.CallType.CLOSED_KAN 
                || c.call_type ==  RoundStateCall.CallType.LATE_KAN
                || c.call_type ==  RoundStateCall.CallType.OPEN_KAN
                || c.call_type ==  RoundStateCall.CallType.PON
            ) {
                stats.triplet_count++;
                if(c.tiles[0].is_terminal_tile()) {
                    stats.hasTerminalTriplet = true;
                    stats.terminal_count += 3;
                }
                if(c.tiles[0].is_dragon_tile()) {
                   stats.dragon_count = c.call_type ==  RoundStateCall.CallType.PON ? 3: 4;
                }
            }

            if(c.call_type == RoundStateCall.CallType.CHII) {
                if(c.tiles[0].is_terminal_tile() || c.tiles[1].is_terminal_tile() || c.tiles[2].is_terminal_tile()) {
                    stats.hasTerminalSeq = true;
                    stats.terminal_count++;
                }
            }

            Tile t_in_c = c.tiles[0];
            if (t_in_c.tile_type >= TileType.MAN1 && t_in_c.tile_type <= TileType.MAN9)
            {
                suit_categories.add(TileType.MAN1);
            }
            else if (t_in_c.tile_type >= TileType.PIN1 && t_in_c.tile_type <= TileType.PIN9)
            {
                suit_categories.add(TileType.PIN1);
            }
            else if (t_in_c.tile_type >= TileType.SOU1 && t_in_c.tile_type <= TileType.SOU9)
            {
                suit_categories.add(TileType.SOU1);
            }
            
        }

        if(stats.terminal_count > 0 || stats.dragon_count > 0) {
            ArrayList<Tile> copy_for_rare_search = new ArrayList<Tile>();
            copy_for_rare_search.add_all(sorted_hand);
            foreach( RoundStateCall c in calls) {
                copy_for_rare_search.add_all(c.tiles);
            }

            TileType theOne = TileType.BLANK;
            int cnt = 0;
            for (int i=0 ; i < copy_for_rare_search.size && cnt < 2; i++ ) { // 是否有两张是个分水岭
                if(copy_for_rare_search[i].is_dragon_tile() || copy_for_rare_search[i].is_terminal_tile()) {
                    cnt++;
                    theOne = copy_for_rare_search[i].tile_type;
                }
            }
            
            if(cnt == 1) {
                // 必须严格等于 1 的时候
                stats.rare_dragon_terminal = theOne;
            }
        }

        // 0: win , 1: tenpai
        int shanten_num = get_shanten_for_hand(sorted_hand,calls);
        if((stats.dragon_count == 0 && stats.terminal_count == 0)
            || suit_categories.size  <= 1  // 清一色或者混一色
            || stats.triplet_count <= 0 ) { 
            // just from experience, not know really how to calculation
            if( shanten_num >= 3) {
                // not too much cost if we are far from tenpai
                stats.weighted_shanten = shanten_num + 1;
            } else {
                stats.weighted_shanten = shanten_num + 2; 
            }
        } else {
           stats.weighted_shanten = shanten_num; 
        } 

        return stats;
    }

    /**
     * Get the shanten number for a hypothetical hand
     * @param hand The hand tiles to evaluate
     * @param calls The calls/melds
     * @return Shanten number + 1 (0 = winning, 1 = tenpai, 2 = 1-shanten, etc.)
     */
    private int get_shanten_for_hand(ArrayList<Tile> hand, ArrayList<RoundStateCall> calls)
    {
        return shanten_calc.calculate_shanten(hand, calls);
    }

    // 暂时是为二人抬轿测试服务
    // 先去掉 顺子 再 刻子吧， 总感觉安全点
    private void remove_melds(int start_tile, int end_tile, HashMap<TileType, int> map_sort, ref ArrayList<Tile> two_player_carry)
    {
        HashMap<TileType, int> copy_map = new HashMap<TileType, int>();
        copy_map.set_all( map_sort);
        // 拿掉所有顺子
        for (int i = start_tile; i <= end_tile - 2 ; i++)
        {
            //  // just for debug
            //  int i0 = copy_map[(TileType)i]; 
            //  int i1 = copy_map[(TileType)(i + 1)]; 
            //  int i2 = copy_map[(TileType)(i + 2)]; 
            //  // just for debug
            //  int j0 = map_sort[(TileType)i]; 
            //  int j1 = map_sort[(TileType)(i + 1)]; 
            //  int j2 = map_sort[(TileType)(i + 2)]; 

            while (copy_map[(TileType)i] >=1 && copy_map[(TileType)(i+1)] >=1 && copy_map[(TileType)(i+2)] >=1 ) {
            

                bool done_i = false;
                bool done_p1 = false;
                bool done_p2 = false;
                // Iterate backwards to safely remove during iteration
                for (int idx = two_player_carry.size - 1; idx >= 0; idx--) {
                        Tile t = two_player_carry[idx];
                        if(!done_i && t.tile_type == (TileType)i) {
                            two_player_carry.remove_at(idx);
                            done_i = true;
                            copy_map[(TileType)i] = copy_map[(TileType)i] - 1;
                            continue;
                        }
                        if(!done_p1 && t.tile_type == (TileType)(i+1)) {
                            two_player_carry.remove_at(idx);
                            done_p1 = true;
                            copy_map[(TileType)(i+1)] = copy_map[(TileType)(i+1)] - 1;
                            continue;
                        }
                        if(!done_p2 && t.tile_type == (TileType)(i+2)) {
                            two_player_carry.remove_at(idx);
                            done_p2 = true;
                            copy_map[(TileType)(i+2)] = copy_map[(TileType)(i+2)] - 1;
                            continue;
                        }
                }
            }
        }

        // 拿掉所有刻子（不包括 dragon)
        for (int i = start_tile; i <= end_tile ; i++)
        {
            //  int i0 = copy_map[(TileType)i]; 

            if (copy_map[(TileType)i] >= 3 ) {
                int counter = 0;
                // Iterate backwards to safely remove during iteration
                for (int idx = two_player_carry.size - 1; idx >= 0 && counter < 3; idx--) {
                    Tile t = two_player_carry[idx];
                    // 只去掉3个，不许多去
                    if(t.tile_type == (TileType)i) {
                        two_player_carry.remove_at(idx);
                        counter++;
                    }
                }
            }
        }
    }

    // Helper: Count patterns (singles, pairs, triplets) in a suit
    public void count_suit_patterns(HashMap<TileType, int> suit_map,
                                     int start_tile,
                                     int end_tile,
                                     ref ArrayList<TileType> singles,
                                     ref HashSet<TileType> hand_in_seq,
                                     ref int pair_count,
                                     ref int triplet_count)
    {
        for (int i = start_tile; i <= end_tile; i++)
        {
            int i_count = suit_map.get((TileType)i);
            int m1 = i - 1 >= start_tile ? suit_map.get((TileType)(i - 1)) : 0;
            int m2 = i - 2 >= start_tile ? suit_map.get((TileType)(i - 2)) : 0;
            int p1 = i + 1 <= end_tile ? suit_map.get((TileType)(i + 1)) : 0;
            int p2 = i + 2 <= end_tile ? suit_map.get((TileType)(i + 2)) : 0;

            switch (i_count)
            {
                case 1:
                    if( (m1 > 0 && m2 > 0)
                    || (m1 > 0 && p1 > 0)
                    || (p1 >0 && p2 > 0) ) {
                       hand_in_seq.add(i); // 我只有一个，我还在一个顺子里
                    }
                    if (m1 == 0 && m2 == 0 && p1 == 0 && p2 == 0)
                    {
                        singles.add(i);
                    }
                    break;
                case 2:
                    pair_count++;
                    break;
                case 3:
                case 4:
                    triplet_count++;
                    break;
            }
        }
    }

    // Helper: Count half-sequences involving a specific tile
    // A half-sequence is two tiles that need one more to form a sequence (e.g., 3-5 needs 4, or 4-5 needs 3 or 6)
    public void count_half_sequences(HashMap<TileType, int> suit_map,
                                      int target_tile,
                                      int start_tile,
                                      int end_tile,
                                      ref int half_sequence_count)
    {
        // Check all tiles in this suit
        for (int i = start_tile; i <= end_tile; i++)
        {
            if (i == target_tile)
                continue;

            int tile_count = suit_map.get((TileType)i);
            int target_count = suit_map.get((TileType)target_tile);
            int distance = (i - target_tile).abs();

            // Check if this tile forms a half-sequence with the target tile
            // Case 1: i and target are 2 apart (e.g., 3 and 5 need 4)
            if (distance == 2)
            {
                half_sequence_count += int.min(tile_count, target_count);
            }
            // Case 2: i and target are 1 apart (e.g., 4 and 5 need 3 or 6)
            else if (distance == 1)
            {
                half_sequence_count += int.min(tile_count, target_count);
            }
        }
    }
    // Helper: Create and initialize a suit map
    public HashMap<TileType, int> create_suit_map(int start_tile, int end_tile)
    {
        HashMap<TileType, int> map = new HashMap<TileType, int>();
        for (int i = start_tile; i <= end_tile; i++)
        {
            map.set((TileType)i, 0);
        }
        return map;
    }

    public Tile RandomNonTerminalHonor(ArrayList<Tile> tiles)
    {
        ArrayList<Tile> tmpTiles = new ArrayList<Tile>();
        foreach(Tile t in tiles) {
            if(!(t.is_terminal_tile() || t.is_honor_tile())) {
                tmpTiles.add(t);
            }
        }
        if(tmpTiles.size > 0) {
            return tmpTiles[rnd.int_range(0, tmpTiles.size)];
        } else {
            return tiles[rnd.int_range(0, tiles.size)];
        }
    }
    public Tile RandomTerminalHonor(ArrayList<Tile> tiles)
    {
        ArrayList<Tile> tmpTiles = new ArrayList<Tile>();
        foreach(Tile t in tiles) {
            if((t.is_terminal_tile() || t.is_honor_tile())) {
                tmpTiles.add(t);
            }
        }
        if(tmpTiles.size > 0) {
            return tmpTiles[rnd.int_range(0, tmpTiles.size)];
        } else {
            return tiles[rnd.int_range(0, tiles.size)];
        }
    }

    public Tile RandomTileSmart(HandStatistics stats, ArrayList<Tile> tiles)
    {
        if(stats.terminal_count + stats.dragon_count <= 2 && !stats.hasTerminalSeq && !stats.hasTerminalTriplet) {
            return RandomNonTerminalHonor(tiles);
        } else {
            return RandomTerminalHonor(tiles);
        }
    }
    // Find the discard with the highest benefit
    // could be array whose elements have same high benefit
    protected ArrayList<BestDiscardResult> find_best_discards(HashMap<Tile, int> discard_benefit)
    {
        ArrayList<BestDiscardResult> rtn = new ArrayList<BestDiscardResult>();
        int best_benefit = 0;
        foreach (Tile tDiscard in discard_benefit.keys) {
            int benefit = discard_benefit.get(tDiscard);
            Environment.log(LogType.DEBUG, "Bot",
                        @"find_best_discards $(tDiscard) for $(benefit)");
            if (benefit > best_benefit) {
                rtn.clear(); // found a new high, so clear others
                BestDiscardResult tmp = new BestDiscardResult(tDiscard, benefit);
                best_benefit = benefit;
                rtn.add(tmp);
            } else if( benefit == best_benefit ) {
                BestDiscardResult tmp = new BestDiscardResult(tDiscard, benefit);
                rtn.add(tmp);
            }
        }

        return rtn;
    }
    // Find the discard with the highest benefit / singular for backward compatible
    protected BestDiscardResult find_best_discard(HashMap<Tile, int> discard_benefit)
    {
        BestDiscardResult result = new BestDiscardResult();
        result.tile = null;
        result.benefit = 0;

        foreach (Tile tDiscard in discard_benefit.keys) {
            int benefit = discard_benefit.get(tDiscard);
            Environment.log(LogType.DEBUG, "Bot",
                        @"find_best_discard $(tDiscard) for $(benefit)"); 
            if (benefit > result.benefit) {
                result.benefit = benefit;
                result.tile = tDiscard;
            }
        }

        return result;
    }

    // 已经吃碰或者打出的所有 还有墙上翻开的
    protected  HashMap<TileType, int> called_tiles() {
        HashMap<TileType,int> hCalled = new HashMap<TileType,int>(); // Other Player: OP
        for(int i= TileType.MAN1 ;  i < TileType.CHUN; i++ ) {
           hCalled.set((TileType)i,0); 
        }
        for(int i = 0 ; i < 4 ; i++ ) {
            //  if(i == round_state.self.index) {
            //      continue;
            //  }
            RoundStatePlayer p =  round_state.get_player(i);
            foreach(Tile t in p.pond) {
                hCalled.set(t.tile_type, hCalled.get(t.tile_type) + 1 );
            }
            foreach( RoundStateCall c in  p.calls ) {
                foreach(Tile t in c.tiles) {
                hCalled.set(t.tile_type, hCalled.get(t.tile_type) + 1 ); 
                }
            }
            Tile? mark = round_state.dead_wall_mark;
            if(mark != null) {
                Tile t = mark;
                hCalled.set(t.tile_type, hCalled.get(t.tile_type) + 1 ); 
            }
        }
        return hCalled;

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
