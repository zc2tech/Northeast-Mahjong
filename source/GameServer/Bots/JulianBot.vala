using Gee;

// Hand analysis statistics
struct HandStatistics
{
    public int terminal_count;
    public int dragon_count;
    // 全局（hand + calls）来看，我就一张这样的幺九中发牌 打掉就基本废了，虽然你有 2 , 8 还是有希望吃到幺九的
    public TileType rare_dragon_terminal; 
    public ArrayList<Tile> two_player_carry; // 为测试二人抬轿做准备
    public ArrayList<TileType> singles;
    public ArrayList<TileType> singles_ish; // 不是对子刻子， 而且 12 但是 3 被碰  89 7 被碰， 不考虑其他太复杂的情况
    public int pair_count;

    public int triplet_count;
    public int half_sequence_count_by_tile; // Tile相关半顺子数量
    public bool hasTerminalSeq;
    public bool hasTerminalTriplet;
}

// Result of finding the best discard for tenpai
struct BestDiscardResult
{
    public Tile? tile;
    public int benefit;
}

class JulianBot : Bot
{
    private Engine.RandomClass rnd = new Engine.RandomClass();

    // Helper: Create and initialize a suit map
    private HashMap<TileType, int> create_suit_map(int start_tile, int end_tile)
    {
        HashMap<TileType, int> map = new HashMap<TileType, int>();
        for (int i = start_tile; i <= end_tile; i++)
        {
            map.set((TileType)i, 0);
        }
        return map;
    }

    // 先去掉 顺子 再 刻子吧， 总感觉安全点
    private void remove_melds(int start_tile, int end_tile, HashMap<TileType, int> map_sort, ref ArrayList<Tile> two_player_carry)
    {
        HashMap<TileType, int> copy_map = new HashMap<TileType, int>();
        copy_map.set_all( map_sort);
        // 拿掉所有顺子
        for (int i = start_tile; i <= end_tile - 2 ; i++)
        {
            while (copy_map[i] >=1 && copy_map[i+1] >=1 && copy_map[i+1] >=1 ) {
               bool done_i = false;
               bool done_p1 = false;
               bool done_p2 = false;
               // Iterate backwards to safely remove during iteration
               for (int idx = two_player_carry.size - 1; idx >= 0; idx--) {
                    Tile t = two_player_carry[idx];
                    if(!done_i && t.tile_type == copy_map[i]) {
                        two_player_carry.remove_at(idx);
                        done_i = true;
                        copy_map[i] = copy_map[i] -1;
                        continue;
                    }
                    if(!done_p1 && t.tile_type == copy_map[i+1]) {
                        two_player_carry.remove_at(idx);
                        done_p1 = true;
                        copy_map[i+1] = copy_map[i+1] -1;
                        continue;
                    }
                    if(!done_p2 && t.tile_type == copy_map[i+2]) {
                        two_player_carry.remove_at(idx);
                        done_p2 = true;
                        copy_map[i+2] = copy_map[i+2] -1;
                        continue;
                    }
               }
            }
        }

        // 拿掉所有刻子（不包括 dragon)
        for (int i = start_tile; i <= end_tile ; i++)
        {
            if (copy_map[i] >= 3 ) {
                int counter = 0;
                // Iterate backwards to safely remove during iteration
                for (int idx = two_player_carry.size - 1; idx >= 0 && counter < 3; idx--) {
                    Tile t = two_player_carry[idx];
                    // 只去掉3个，不许多去
                    if(t.tile_type == i) {
                        two_player_carry.remove_at(idx);
                        counter++;
                    }
                }
            } 
        }
    }

    private void count_singles_ish(HashMap<TileType, int> suit_map,
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
                }
                // 97 no 8
                if(i== end_tile && m2 == 1 && m1 == 0 && mo1 >= 3) {
                    singles_ish.add(i);
                }
                // 12 no 3
                if(i== start_tile && p1 == 1 && p2 == 0 && po2 >= 3) {
                    singles_ish.add(i);
                }
                // 13 no 2
                if(i== start_tile && p2 == 1 && p1 == 0 && po1 >= 3) {
                    singles_ish.add(i);
                } 

            }
           
        }
    }
    // Helper: Count patterns (singles, pairs, triplets) in a suit
    private void count_suit_patterns(HashMap<TileType, int> suit_map,
                                     int start_tile,
                                     int end_tile,
                                     ref ArrayList<TileType> singles,
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
    private void count_half_sequences(HashMap<TileType, int> suit_map,
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

    // Analyze hand and return statistics
    // param tile, 吃碰杠 对象, 可以为 null 表示这是 turn decision
    // param hOP (Other Player all tiles) 有可能 null, 那时候 singles_ish 之类的可能就不准了 
    private HandStatistics analyze_hand(Tile? tile, ArrayList<Tile> sorted_hand, ArrayList<RoundStateCall> calls, HashMap<TileType, int>? hOP)
    {
        HandStatistics stats = HandStatistics();
        stats.two_player_carry = new ArrayList<Tile>();
        stats.two_player_carry.add_all(sorted_hand); // 二人抬轿 只是把刻子，对子移除。后续还要设牌时判断
        // Create suit maps
        HashMap<TileType, int> map_man = create_suit_map(TileType.MAN1, TileType.MAN9);
        HashMap<TileType, int> map_pin = create_suit_map(TileType.PIN1, TileType.PIN9);
        HashMap<TileType, int> map_sou = create_suit_map(TileType.SOU1, TileType.SOU9);

        remove_melds(TileType.MAN1, TileType.MAN9,map_man, ref stats.two_player_carry);
        remove_melds(TileType.PIN1, TileType.PIN9,map_pin, ref stats.two_player_carry);
        remove_melds(TileType.SOU1, TileType.SOU9,map_sou, ref stats.two_player_carry);


        stats.terminal_count = 0;
        stats.dragon_count = 0;
        stats.singles = new ArrayList<TileType>();
        stats.singles_ish = new ArrayList<TileType>();
        stats.pair_count = 0;
        stats.triplet_count = 0;
        stats.hasTerminalSeq = false; // 这个指标实在太关键了
        stats.hasTerminalTriplet= false; // 这个指标实在太关键了
        stats.rare_dragon_terminal = TileType.BLANK;

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
                stats.dragon_count++;
            }
        }

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
                           ref stats.singles, ref stats.pair_count, ref stats.triplet_count);
        count_suit_patterns(map_pin, TileType.PIN1, TileType.PIN9,
                           ref stats.singles, ref stats.pair_count, ref stats.triplet_count);
        count_suit_patterns(map_sou, TileType.SOU1, TileType.SOU9,
                           ref stats.singles, ref stats.pair_count, ref stats.triplet_count);

        count_singles_ish(map_man, TileType.MAN1, TileType.MAN9, ref stats.singles_ish, hOP);  
        count_singles_ish(map_man, TileType.PIN1, TileType.PIN9, ref stats.singles_ish, hOP);  
        count_singles_ish(map_man, TileType.SOU1, TileType.SOU9, ref stats.singles_ish, hOP);  
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

        return stats;
    }

    // 只分析幺九牌状态,其他的不想看
    private HandStatistics analyze_only_terminal_honor(ArrayList<Tile> hand, ArrayList<RoundStateCall> calls)
    {
        HandStatistics stats = HandStatistics();

        stats.terminal_count = 0;
        stats.dragon_count = 0;
        stats.singles = new ArrayList<TileType>();
        stats.pair_count = 0;
        stats.triplet_count = 0;

        // Count tiles by suit
        foreach (Tile t in hand)
        {
            if (t.is_terminal_tile())
            {
                stats.terminal_count++;
            }

            if (t.is_dragon_tile())
            {
                stats.dragon_count++;
            }
        }

        foreach (RoundStateCall c in calls)
        {
            foreach(Tile t in c.tiles) {
                if (t.is_terminal_tile())
                {
                    stats.terminal_count++;
                }
                if (t.is_dragon_tile())
                {
                    stats.dragon_count++;
                }
            }
        }

        return stats;
    }

    // Evaluate whether to call pon (碰) on a tile
    // Returns true if should call pon, false otherwise
    private bool should_call_pon(Tile tile,
                                  ArrayList<Tile> sortedhand,
                                  ArrayList<RoundStateCall> calls,
                                  int beforeBenefit,
                                  HandStatistics stats,
                                  RoundStatePlayer discarding_player)
    {
        if(sortedhand.size <= 4 ) {
            return false;
        }
        if (!round_state.can_pon(round_state.self) || count(tile) != 2)
        {
            return false;
        }

        int pairCnt = stats.pair_count;
        int tripletCnt = stats.triplet_count;
        int singleCnt = stats.singles.size;
        int terminalCnt = stats.terminal_count;
        int dragonCnt = stats.dragon_count;

         // Get s (下家 - shimocha)
        int shimocha_index = (round_state.self.index + 1) % 4;

        // Get cross/opposite player (对面 - toimen)
        int toimen_index = (round_state.self.index + 2) % 4;

        // Get (上家 - kamicha)
        int kamicha_index = (round_state.self.index + 3) % 4;

        int discarder_index = discarding_player.index;

        if( dragonCnt < 2 && terminalCnt == 0 ) {
            // 牌太烂了
            return false;
        }

        // 没听牌，你又没幺九刻子时，赶紧碰
        if( stats.dragon_count < 3 && !stats.hasTerminalTriplet
             && (tile.is_dragon_tile() || tile.is_terminal_tile())
            && beforeBenefit == 0) {
            // 必碰
            return true;
        }
        
        // 下家打的 没听牌的话 基本都碰, 将牌没了的话，不正好二人抬轿吗
        if(beforeBenefit == 0 && shimocha_index == discarder_index && tripletCnt <= 2) {
            return true;
        }

        // 牌好吗 其实如果那一对子正好是 幺九 对的话,其实还行
        if (beforeBenefit == 0 && 
            ((pairCnt <= 1 && tripletCnt < 1) || singleCnt >= 3 || terminalCnt <= 1))
        {
            if(shimocha_index == discarder_index) {
                return true;
            } else if(toimen_index == discarder_index) {
                if(tripletCnt < 1) {
                    return true;
                } else {
                    return Random.boolean();
                }
            } else {
                // 上家打过来的
                if(singleCnt <= 1 && tripletCnt < 1) {
                    return true;
                }
                // 等着摸牌吧
                return false;
            }
        }

        // 碰掉试试 , 外围逻辑已经确认我们手中只有两个同种牌
        ArrayList<Tile> newHand = new ArrayList<Tile>();
        ArrayList<RoundStateCall> newCalls = new ArrayList<RoundStateCall>();
        newCalls.add_all(calls);
        ArrayList<Tile> pon = new ArrayList<Tile>();
        pon.add(tile);

        foreach (Tile t in sortedhand)
        {
            if (t.tile_type == tile.tile_type)
            {
                pon.add(t);
            }
            else
            {
                newHand.add(t);
            }
        }

        newCalls.add(new RoundStateCall(RoundStateCall.CallType.PON, pon, tile, 1));

        // 找一下该打什么牌
        Tile bestDiscard = null;
        HashMap<Tile, HashMap<TileType, int>> hDiscardForTenpai= new HashMap<Tile,HashMap<TileType, int>>();
        HashSet<TileType> checked = new HashSet<TileType>();
        foreach (Tile t in newHand)
        {
            if(checked.contains(t.tile_type)) {
                continue;
            } else {
                checked.add(t.tile_type);
            }
            ArrayList<Tile> tmpHand = new ArrayList<Tile>();
            tmpHand.add_all(newHand);
            tmpHand.remove(t);

            // 至少得能听牌吧
            if( TileRules.in_tenpai(tmpHand,newCalls)) {
                hDiscardForTenpai.set(t,new HashMap<TileType,int>());
            }
        }
        if(hDiscardForTenpai.keys.size > 0 ) {
            populate_needed_tiles_for_discards(hDiscardForTenpai,newHand,newCalls);
            HashMap<Tile, int> discard_benefit = calculate_discard_benefits(hDiscardForTenpai);
            BestDiscardResult result = find_best_discard(discard_benefit);

            if (result.tile != null && result.benefit > beforeBenefit) {
                 Environment.log(LogType.DEBUG, "JulianBot",
                    @"should_call_pon ($(round_state.self.wind.to_string())) discard $(result.tile.to_string()) for $(result.benefit) win tiles");
                // 既然值得碰,那就碰吧.
                return true;
            }
        }

        // 以前是有听的话，就不碰了
        if(beforeBenefit > 0) {
            return false;
        }

        // 根本没机会和牌时,要不要碰? 继续看:
        if (tile.is_dragon_tile() || tile.is_wind(round_state.self.wind) || tile.is_wind(round_state.round_wind))
        {
            return true;
        }

        if (tripletCnt == 0 && singleCnt <= 3)
        {
            // 还是很有用的, 散牌也不算太多
            return true;
        }

        // 碰了之后什么状态? 刻子肯定是多了的
        HashMap<TileType, int> hOP = other_player_tiles();
        HandStatistics newStats = analyze_hand(null, newHand, newCalls, hOP);
        if (newStats.singles.size - stats.singles.size >= 2)
        {
            // 散牌增多两张以上啊,不值得
            return false;
        }

        if( kamicha_index == discarder_index) {
            // 上家的牌,一般不想碰
            if(tripletCnt < 1 || singleCnt <=1 ) {
                return true;
            }
        }

        // 默认就不碰啦
        return false;
    }

    private bool should_call_kan(Tile tile,
                                  ArrayList<Tile> sortedhand,
                                  ArrayList<RoundStateCall> calls,
                                  ArrayList<HandReading> beforeCallReading,
                                  HandStatistics stats,
                                  RoundStatePlayer discarding_player)
    {
        if(sortedhand.size <= 4) {
            return false;
        }
        if (!round_state.can_open_kan(round_state.self))
        {
            return false;
        }

        //  int pairCnt = stats.pair_count;
        //  int tripletCnt = stats.triplet_count;
        //  int singleCnt = stats.singles.size;
        //  int terminalCnt = stats.terminal_count;

        //   // Get s (下家 - shimocha)
        //  int shimocha_index = (round_state.self.index + 1) % 4;

        //  // Get cross/opposite player (对面 - toimen)
        //  int toimen_index = (round_state.self.index + 2) % 4;

        //  // Get (上家 - kamicha)
        //  int kamicha_index = (round_state.self.index + 3) % 4;

        int discarder_index = discarding_player.index;

        // 杠掉试试
        ArrayList<Tile> newHand = new ArrayList<Tile>();
        ArrayList<RoundStateCall> newCalls = new ArrayList<RoundStateCall>();
        newCalls.add_all(calls);
        ArrayList<Tile> kan = new ArrayList<Tile>();
        kan.add(tile);

        foreach (Tile t in sortedhand)
        {
            if (t.tile_type == tile.tile_type)
            {
                kan.add(t);
            }
            else
            {
                newHand.add(t);
            }
        }

        //  newCalls.add(new RoundStateCall(RoundStateCall.CallType.OPEN_KAN, kan, tile, discarder_index));
        //  HashMap<TileType, int> hOP = other_player_tiles();
        HandStatistics newStats = analyze_hand(tile, newHand, newCalls,null);
        if (newStats.half_sequence_count_by_tile <  stats.half_sequence_count_by_tile)
        {
            // 牌变差了
            return false;
        }

        // 默认就不杠吧
        return true;
    }

    // Evaluate whether to call chii (吃) on a tile
    // Returns true if should call chii, false otherwise
    // If true, sets the out parameters tiles1 and tiles2 to the tiles to use
    private bool should_call_chii(Tile tile,
                                   ArrayList<Tile> sortedhand,
                                   ArrayList<RoundStateCall> calls,
                                   int beforeBenefit,
                                   HandStatistics stats,
                                   RoundStatePlayer discarding_player,
                                   out Tile tiles1,
                                   out Tile tiles2)
    {
        tiles1 = null;
        tiles2 = null;
        bool alreadyHave = false;

        if(sortedhand.size <= 4) {
            return false;
        }

        if (!round_state.can_chii(round_state.self))
        {
            return false;
        }

        foreach( Tile t in sortedhand ) {
            if(t.tile_type == tile.tile_type) {
                alreadyHave = true;
                break;
            }
        }
 
        ArrayList<ArrayList<Tile>> groups = TileRules.get_chii_groups(round_state.self.hand, tile);

        // 能填补 幺九牌 空白的话, 或者把 幺九 吃定型的 , 必须吃
        // 但我如果已经是顺子牌型呢?
        //  if(stats.dragon_count < 2 && !stats.hasTerminalSeq && !stats.hasTerminalTriplet 
        //      && (stats.terminal_count <=1 || stats.dragon_count <=1 )) {
                
        //      }
        foreach(ArrayList<Tile> g in groups) {
            // alreadyHave 确保 没法吃啥吐啥的
            if(!alreadyHave && (g[0].is_terminal_tile() || g[1].is_terminal_tile() || tile.is_terminal_tile())) {
                // 998 我 吃 7 ， 889 未必就吃  9998 也会去吃，但没办法，判断太难
                if(stats.dragon_count < 2 && !stats.hasTerminalSeq && !stats.hasTerminalTriplet) {
                    // 定型再说吧， 以后AI能判断好一点
                    tiles1 = g[0];
                    tiles2 = g[1];
                    return true;
                }
            }
        }

        // 到这里就算有 幺九刻子或者对子了
        if (stats.singles.size >= 3)
        {
            return false;
        }

        BestDiscardResult bestChiiResut = BestDiscardResult();
        bestChiiResut.benefit = beforeBenefit;
        
        ArrayList<Tile> bestGroup = null;
        ArrayList<Tile> plan_b = null;
        foreach (ArrayList<Tile> g in groups)
        {
            // 吃掉试试
            ArrayList<Tile> newHand = new ArrayList<Tile>();
            newHand.add_all(sortedhand);
            ArrayList<RoundStateCall> newCalls = new ArrayList<RoundStateCall>();
            newCalls.add_all(calls);
            ArrayList<Tile> chii = new ArrayList<Tile>();
            chii.add(tile);
            chii.add(g[0]);
            chii.add(g[1]);
            newHand.remove(g[0]);
            newHand.remove(g[1]);

            newCalls.add(new RoundStateCall(RoundStateCall.CallType.CHII, chii, tile, discarding_player.index));

            HandStatistics newStats = analyze_hand(null, newHand, newCalls,null);

            // 再分析 hand_readings 之前,先简单分析一下
            bool shouldContNow = false;
            if(newStats.singles.size > stats.singles.size) {
                // 单张竟然多了, 估计是吃啥吐啥类型的 继续分析
                foreach(TileType iType in newStats.singles) {
                    if(iType == tile.tile_type) {
                        // 多出来的正好是吃进去的 试试下一个
                        shouldContNow = true;
                        break;
                    }
                }
                // 多出来的单张是另一头的， 比如说 789 吃 6    123 吃 4    
                foreach(TileType iType in newStats.singles) {
                    if( ((int)iType - (int)tile.tile_type).abs() == 3 ) {
                        shouldContNow = true;
                        break;
                    }             
                } 
                
            }
            if(shouldContNow) {
                continue;
            }

            // 不能保证两个 对子 是很危险的
            if(newStats.triplet_count < 1 && newStats.pair_count < 2) {
                continue;
            }

            if(stats.hasTerminalTriplet && !newStats.hasTerminalTriplet) {
                // 把 “唯一的” 幺九刻给吃没了
                continue;
            }
           
            // 找一下该打什么牌
            HashMap<Tile, HashMap<TileType, int>> hDiscardForTenpai= new HashMap<Tile,HashMap<TileType, int>>();
            HashSet<TileType> checked = new HashSet<TileType>();
            foreach (Tile t in newHand)
            {
                if(checked.contains(t.tile_type)) {
                    continue;
                } else {
                    checked.add(t.tile_type);
                }
                ArrayList<Tile> tmpHand = new ArrayList<Tile>();
                tmpHand.add_all(newHand);
                tmpHand.remove(t);

                // 至少得能听牌吧
                if( TileRules.in_tenpai(tmpHand,newCalls)) {
                    hDiscardForTenpai.set(t,new HashMap<TileType,int>());
                }
            }

            if( hDiscardForTenpai.keys.size > 0 ) {
                populate_needed_tiles_for_discards(hDiscardForTenpai,newHand,newCalls);
                HashMap<Tile, int> discard_benefit = calculate_discard_benefits(hDiscardForTenpai);
                BestDiscardResult result = find_best_discard(discard_benefit);

                if (result.tile != null && result.benefit >  bestChiiResut.benefit) {
                    bestChiiResut.benefit = result.benefit;
                    bestChiiResut.tile = result.tile;
                    bestGroup = g;
                    // 有起色就立即　continue 看下一个 group 是不是更出色, 不需要plan_b 了
                    Environment.log(LogType.DEBUG, "JulianBot",
                    @"should_call_chii ($(round_state.self.wind.to_string())) chii $(tile.to_string()) discard $(result.tile.to_string()) for $(result.benefit) win tiles");
                    continue;
                }
            }

            // 注意你是在一个group 的 loop 里
            if (stats.terminal_count == 0 && stats.dragon_count < 2)
            {
                // 我没幺九牌, 看吃完之后能不能好一点
                if(newStats.terminal_count > 0 ) {
                    plan_b = g;
                    break;
                }
            }

            if(stats.triplet_count >=1 && newStats.triplet_count == 0) {
                // 把刻子吃没了 这回不是看幺九刻了 看看下一个group 是不是好点
                continue;
            }

            if (g[0].is_terminal_tile() || g[1].is_terminal_tile()) {
                // 到这里了 肯定都是没法听牌的，不过自己幺九牌用出去了总是好事
                plan_b = g;
                break;
            }
            // 上面的检查既然没要求吃,说明吃了也不能听牌,但如果孤张没变多的话,也还行啊
            // 吃的时候,多了一张孤张也很正常, 吃啥吐啥已经在上面判断过了
            if (!alreadyHave && (stats.triplet_count >= 1 || stats.pair_count >= 2)) {
                if (newStats.singles.size <= stats.singles.size + 1) {
                    plan_b = g;
                    break;
                } else if(newStats.singles.size == stats.singles.size + 2) {
                    // 多出来两张孤张啊， 实在不知道该不该吃
                    bool random_bool = Random.boolean();
                    if(random_bool) {
                        plan_b = g;
                        continue; // 再试试？
                    }
                }
            } else {
                // 已经有的话，吃了还不损对子 56778 吃 7  3445 吃 4
                //  if(newStats.pair_count >= stats.pair_count && newStats.singles.size <= stats.singles.size) {
                //      tiles1 = g[0];
                //      tiles2 = g[1];
                //      return true;
                //  }              
            }

            
        } // groups loop

        if(bestGroup != null) {
            // 比没吃前听的好
            tiles1 = bestGroup[0];
            tiles2 = bestGroup[1];
            return true;
        }

        if( beforeBenefit > 0) {
            // 都已经听牌的，不吃了
            return false;
        }

        // 有 plan B 就用上吧，也不知道啥情况
        if(plan_b != null) {
            tiles1 = plan_b[0];
            tiles2 = plan_b[1];
            return true;
        }        
        
        // 最后肯定觉得吃的不好，要吃上面早吃了
        return false;
    }

    // 摸到牌之后，做个处理决定
    protected override void do_turn_decision()
    {
        if (round_state.can_tsumo())
        {
            do_tsumo();
            return;
        }

        // 没有九种九牌 就流局的概念
        //  else if (round_state.can_void_hand())
        //  {
        //      do_void_hand();
        //  }

        ArrayList<Tile> sorted_hand = Tile.sort_tiles_type(round_state.self.hand); 
        ArrayList<RoundStateCall> calls = round_state.self.calls;   

        HashMap<TileType, int> hOP = other_player_tiles();
        HandStatistics stats = analyze_hand(null, sorted_hand, calls,hOP);

        // win_necessary_condition 就当听牌, 所以条件不是特别严格
        // 已经尽力了
        if( TileRules.win_necessary_condition(sorted_hand, calls, true)
            && stats.triplet_count >= 1
        ){
            HashMap<Tile, HashMap<TileType, int>> hDiscardForTenpai= new HashMap<Tile,HashMap<TileType, int>>();
            // 如果打掉某张可以听牌的话
            ArrayList<Tile> copy_for_tenpai = new ArrayList<Tile>();
            ArrayList<Tile> tiles_allowed = round_state.self.get_discard_tiles();

            //  Environment.log(LogType.DEBUG, "JulianBot", @"Checking tenpai for $(tiles_allowed.size) tiles");

            Tile discard_for_tenpai = null;
            HashSet<TileType> checked = new HashSet<TileType>();
            foreach (Tile tile in tiles_allowed)
            {
                if(checked.contains(tile.tile_type)) {
                    continue;
                } else {
                    checked.add(tile.tile_type);
                }
                //  Environment.log(LogType.DEBUG, "JulianBot", @"Checking if discarding $(tile.tile_type.to_string()) leads to tenpai...");
                copy_for_tenpai.add_all(round_state.self.hand);
                copy_for_tenpai.remove(tile);
                // 能听牌当然就打你了
                if (TileRules.in_tenpai(copy_for_tenpai, round_state.self.calls)) {
                    discard_for_tenpai = tile;
                    copy_for_tenpai.clear();
                    // 到时候会算舍去这张牌能听多少 <类型,张数>
                     Environment.log(LogType.DEBUG, "JulianBot", @"Found tenpai discard ($(round_state.self.wind.to_string())): $(tile.tile_type.to_string())");
                    hDiscardForTenpai.set(discard_for_tenpai, new HashMap<TileType, int>());
                }
                copy_for_tenpai.clear();
            }
            if (hDiscardForTenpai.keys.size > 0) {
                populate_needed_tiles_for_discards(hDiscardForTenpai, sorted_hand, calls);
                HashMap<Tile, int> discard_benefit = calculate_discard_benefits(hDiscardForTenpai);
                BestDiscardResult result = find_best_discard(discard_benefit);

                if (result.tile != null) {
                        do_discard(result.tile);
                        return;
                }
            }
        }
    
        // 既然到了这里,说明你没有办法和牌或者听牌 

        
        if (round_state.can_late_kan()) // 后杠
        {

            ArrayList<Tile> tiles = TileRules.get_late_kan_tiles(round_state.self.hand, round_state.self.calls);
            assert(tiles.size > 0);
            if(tiles[0].is_dragon_tile()) {
                     do_late_kan(tiles[0]);
                    return;
            }
            
            bool hasNeigh = has_neighbours(tiles[0]);
            bool hasSecNeigh = has_second_neighbours(tiles[0]);

            if(!hasNeigh && !hasSecNeigh) {
                if(tiles[0].is_terminal_tile()) {
                    do_late_kan(tiles[0]);
                    return; 
                }

                if(tiles[0].is_terminal_neighbour_tile() || tiles[0].is_terminal_second_neighbour_tile()) {
                    if(stats.dragon_count < 1 && stats.singles.size <= 1) {
                        do_late_kan(tiles[0]);
                        return;
                    }
                }      
            }
        }

        if (round_state.can_closed_kan())
        {
            ArrayList<ArrayList<Tile>> groups = round_state.self.get_closed_kan_groups();
            assert(groups.size > 0);
            foreach(ArrayList<Tile> g in groups) {
                if(g[0].is_dragon_tile()) {
                    do_closed_kan(g[0].tile_type);
                    return;
                }
            
                bool hasNeigh = has_neighbours(g[0]);
                bool hasSecNeigh = has_second_neighbours(g[0]);

                if(!hasNeigh && !hasSecNeigh) {
                    if(g[0].is_terminal_tile()) {
                        do_closed_kan(g[0].tile_type);
                        return; 
                    }

                    if(g[0].is_terminal_neighbour_tile() || g[0].is_terminal_second_neighbour_tile()) {
                        if(stats.dragon_count < 1 && stats.singles.size <= 1) {
                            do_closed_kan(g[0].tile_type);
                            return;
                        }
                    }      
                }
               
            }
        }
        
        // 没杠 没听 没胡
        Tile  tile = get_discard_tile(stats);
        do_discard(tile);
    }

    // 其他人已经吃碰或者打出的所有 还有墙上翻开的
    private  HashMap<TileType, int> other_player_tiles() {
        HashMap<TileType,int> hOP = new HashMap<TileType,int>(); // Other Player: OP
        for(int i= TileType.MAN1 ;  i < TileType.CHUN; i++ ) {
           hOP.set((TileType)i,0); 
        }
        for(int i = 0 ; i < 4 ; i++ ) {
            if(i == round_state.self.index) {
                continue;
            }
            RoundStatePlayer p =  round_state.get_player(i);
            foreach(Tile t in p.pond) {
                    hOP.set(t.tile_type, hOP.get(t.tile_type) + 1 );
            }
            foreach( RoundStateCall c in  p.calls ) {
                    foreach(Tile t in c.tiles) {
                    hOP.set(t.tile_type, hOP.get(t.tile_type) + 1 ); 
                    }
            }
            Tile? mark = round_state.dead_wall_mark;
            if(mark != null) {
                Tile t = mark;
                hOP.set(t.tile_type, hOP.get(t.tile_type) + 1 ); 
            }
        }
        return hOP;

    } 
    // 别人打牌之后，做个处理决定
    protected override void do_call_decision(RoundStatePlayer discarding_player, Tile tile)
    {
        int64 start_time = get_monotonic_time();

        ArrayList<Tile> sortedhand = Tile.sort_tiles_type(round_state.self.hand);
        ArrayList<RoundStateCall> calls = round_state.self.calls;
        if(sortedhand.size < 4) {
            // 手牌只剩两张的话,就没法胡了
            call_nothing();  // CRITICAL: Must notify server we're done deciding
            //  int64 elapsed = get_monotonic_time() - start_time;
            //  Environment.log(LogType.DEBUG, "JulianBot",
            //      @"do_call_decision ($(round_state.self.wind.to_string())) completed in $(elapsed / 1000) microseconds - skip (hand too small)");
            return;
        }

        // 如果听牌数特别多,未必就要立即去胡的,说不定想自摸呢
       
        if (round_state.can_ron(round_state.self))
        {
            call_ron();
            return;
        }
        // Analyze hand statistics
        HashMap<TileType, int> hOP = other_player_tiles();
        HandStatistics stats = analyze_hand(tile, sortedhand, calls, hOP);
        ArrayList<HandReading> beforeCallReading = TileRules.hand_readings(sortedhand, calls, true, false);

        int beforeBenefit = 0;
        HashMap<TileType, int> needed_tiles = new HashMap<TileType, int>();
        populate_needed_tiles(needed_tiles,sortedhand,calls);
        foreach (TileType type_needed in needed_tiles.keys) {
            int available_count = count_available_tiles(type_needed);
            beforeBenefit += available_count;

            Tile for_log = new Tile(-1,type_needed);
            Environment.log(LogType.DEBUG, "JulianBot",
                @"do_call_decision Beofre_Need_Tile: $(for_log.to_string()) : $(available_count) ");
        }
        if (beforeBenefit > 0) {
            Environment.log(LogType.DEBUG, "JulianBot",
                @"do_call_decision BeforeBenefit: $(beforeBenefit) ");
        }

        // Evaluate pon decision
        if (should_call_pon(tile, sortedhand, calls, beforeBenefit, stats, discarding_player))
        {
            call_pon();
              Environment.log(LogType.DEBUG, "JulianBot",
                @"do_call_decision ($(round_state.self.wind.to_string())) call_pon");
            return;
        }

        // Evaluate chii decision
        Tile chii_tile1;
        Tile chii_tile2;
        if (should_call_chii(tile, sortedhand, calls, beforeBenefit, stats, discarding_player, out chii_tile1, out chii_tile2))
        {
            call_chii(chii_tile1, chii_tile2);
              Environment.log(LogType.DEBUG, "JulianBot",
                @"do_call_decision ($(round_state.self.wind.to_string())) call_chii");
            return;
        }

         // Evaluate kan decision
        if (should_call_kan(tile, sortedhand, calls, beforeCallReading, stats, discarding_player))
        {
            call_open_kan();
            return;
        }

        call_nothing();
    }

    // Toimen (opposite) Kamicha(left)  Shimocha (right) 
    // Add this helper method to JulianBot class
    // onlyShimocha: 只看下家 , 不然的话就看所有其他玩家
    // peepLimit: 在池中看几张牌, 0 表示所有牌
    private bool is_tile_safe(Tile tile, bool onlyShimocha, int peepLimit )
    {
        // Check if this tile has been discarded by other players
        for (int i = 1; i < 4; i++)  // Check all other players
        {
            if(onlyShimocha && i != 1 ) {
                continue;
            }
            int player_index = (round_state.self.index + i) % 4;
            RoundStatePlayer player = round_state.get_player(player_index);
            int peeped = 0;
            foreach (Tile discarded in player.pond)
            {
                if(peepLimit !=0 && peeped >= peepLimit) {
                    break;
                }
                if (discarded.tile_type == tile.tile_type)
                    return true;  // Safe - someone already discarded this tile type
                
                peeped ++;
            }
        }
        return false;
    }

    // 找出需要舍弃的牌 能听牌的我都不进这里
    private Tile get_discard_tile( HandStatistics stats )
    {
        ArrayList<Tile> tiles = round_state.self.get_discard_tiles(); // basically hand tiles
        assert(tiles.size > 0);

        ArrayList<Tile> backup = new ArrayList<Tile>();
        backup.add_all(tiles);

        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            if (count(tile) >= 3)
                tiles.remove_at(i--);
        }

        if (tiles.size == 0)
            return RandomTileSmart(stats,backup);

        foreach (Tile tile in tiles)
        {
            //  if (tile.is_wind_tile())
            //  {
            //      if (!tile.is_wind(round_state.self.wind) && !tile.is_wind(round_state.round_wind))
            //          return tile;
            //      else if (count(tile) <= 1)
            //          return tile;
            //  }
            if (tile.is_dragon_tile())
            {
                if(count(tile) <= 1)
                    return tile;
            }
        }

        // 二人抬轿检测 检测时别看手牌了
        ArrayList<Tile> tpc = stats.two_player_carry; // 应该是排完序的
        TileType discard_for_two_players_carry  = TileType.BLANK;
        if(tpc.size == 5) {
            // 找出来打哪张能形成二人抬轿

            // 先确保没对子
            bool hasPair = false;
            for(int i=0; i <= 3; i++) {
                if(tpc[i].tile_type == tpc[i+1].tile_type) {
                    hasPair = true;
                    break;
                }              
            } 
            
            if(!hasPair) {
                HashMap<TileType,int>  hDiscardCandi = new HashMap<TileType,int>(); // 需要在里面选distance 和最小的
                for(int iRemove = 0 ; iRemove < tpc.size; iRemove++) {
                    int index0 = 0 , index1 = 1, index2 = 2, index3 = 3; // 预定是先看这几个位置的
                    // 1234 0234 0134 0124 0124
                    if(index0 == iRemove) {
                        index0++;
                        index1++;
                        index2++;
                        index3++;
                    } else if(index1 == iRemove) {
                        index1++;
                        index2++;
                        index3++;
                    } else if(index2 == iRemove) {
                        index2++;
                        index3++;
                    } else if(index3 == iRemove) {
                        index3++;
                    } else {
                        // 不用动了
                    }
                    int distance1 = tpc[index1].tile_type - tpc[index0].tile_type;
                    int distance2 = tpc[index3].tile_type - tpc[index2].tile_type;
                    if( (distance1 == 1 || distance1 == 2) 
                    && (distance2 == 1 || distance2 == 2)) 
                    {
                        // 二人抬轿了 但未必最优
                        hDiscardCandi.set(tpc[iRemove].tile_type, distance1 + distance2);
                        //  discard_for_two_players_carry = tpc[iRemove].tile_type;
                        break;
                    }
                } // end loop for iRemove

                // 找个distance 和 最小的
                int discard_for_distance = int.MAX ; // big enough to be impossible;
                foreach(TileType  tileType in hDiscardCandi.keys ) {
                    if(stats.rare_dragon_terminal != TileType.BLANK) {
                        // 我们有一张幺九或者中发白的独苗
                        if(tileType == stats.rare_dragon_terminal) {
                            continue;
                        }
                    }
                    if(hDiscardCandi.get(tileType) < discard_for_distance) {
                        // 找到小一点了
                        discard_for_distance = hDiscardCandi.get(tileType);
                        discard_for_two_players_carry = tileType; 
                    }
                }
            }
        }

        if(discard_for_two_players_carry != TileType.BLANK) {
            // 既然有这个牌型，直接就打了，后面的判断全忽略 缺幺九的话，以后再调整，毕竟吃个幺九或者单砸也挺容易的
            for (int i = 0; i < tiles.size; i++)
            {
                if(tiles[i].tile_type == discard_for_two_players_carry) {
                    return tiles[i];
                }
            } 
        }
        

        backup.clear();
        backup.add_all(tiles);
        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            //  if (tile.is_dragon_tile() || tile.is_wind(round_state.self.wind) || tile.is_wind(round_state.round_wind))
            //      tiles.remove_at(i--);
            // 到这里肯定不是单数了 就留着
            if (tile.is_dragon_tile())
                tiles.remove_at(i--);
        }
        if (tiles.size == 0)
            return RandomTileSmart(stats,backup);

        backup.clear();
        backup.add_all(tiles);

        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            if (has_neighbours(tile)) {
                // count if from self.hand, so don't worry the data consistency when removed one tile of pair
                if(count(tile) == 2) {
                    tiles.remove_at(i--); // 不但是对子，还有邻居，当然得留一下了
                }
            }             
        }
        if (tiles.size == 0)
            return RandomTileSmart(stats, backup);

        backup.clear();
        backup.add_all(tiles);

        // 到了这里不可能算刻子了，这些对子肯定是没近邻的
        int pair_cnt = 0;
        HashSet<TileType> pair_tile_type = new HashSet<TileType>();
        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            // pair_cnt 是经过上一轮之后算出的，你需要加上当前的看看 记得别为一对算两遍 pair_cnt
            if (!pair_tile_type.contains(tile.tile_type) &&  count(tile) >= 2) 
            {
                pair_cnt++;
                pair_tile_type.add(tile.tile_type);
            }               
        }
        // 留一下
        if(pair_cnt <= 2) {
             for (int i = 0; i < tiles.size; i++) {
                if(pair_tile_type.contains(tiles[i].tile_type)) {
                    tiles.remove_at(i--); // 对子还是很珍贵的，
                }
             }
        }

        // 留完竟然空了，那就从有紧邻的里选吧 都是好牌啊，不知道可不可能
        if (tiles.size == 0)
            return RandomTileSmart(stats, backup);

        backup.clear();
        backup.add_all(tiles);

        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            if (has_neighbours(tile) && !stats.singles_ish.contains(tile.tile_type) ) {
                tiles.remove_at(i--); // 到这里了，就只是两面顺子了，也可以留一下了
            }             
        }
        if (tiles.size == 0)
            return RandomTileSmart(stats, backup);

        backup.clear();
        backup.add_all(tiles);

        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            if (has_second_neighbours(tile) && !stats.singles_ish.contains(tile.tile_type))
                tiles.remove_at(i--);
        }

        if (tiles.size == 0)
            return RandomTileSmart(stats, backup);

        backup.clear();
        backup.add_all(tiles);

        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            if (!stats.singles_ish.contains(tile.tile_type)) // 不是垃圾牌，保护一下
                tiles.remove_at(i--);
        }

        if (tiles.size == 0)
            return RandomTileSmart(stats,backup);

        backup.clear();
        backup.add_all(tiles);

        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            if (!tile.is_terminal_tile() && stats.terminal_count >= 2) // 幺九牌如果太多也没用， 所以不需要保护 非幺九牌
                tiles.remove_at(i--);
        }

        if (tiles.size == 0) // 竟然全是非幺九牌的单张, 所以回退到 backup, backup 还是可能有幺九牌的,所以还是 RandomTileSmart函数 
            return RandomTileSmart(stats,backup);

        return RandomTileSmart(stats, tiles);
    }

    private Tile RandomTile(ArrayList<Tile> tiles)
    {
        return tiles[rnd.int_range(0, tiles.size)];
    }

    private Tile RandomTileSmart(HandStatistics stats, ArrayList<Tile> tiles)
    {
        if(stats.terminal_count + stats.dragon_count <= 2) {
            return RandomNonTerminalHonor(tiles);
        } else {
            return RandomTile(tiles);
        }
    }

    // Populate needed tiles for each potential discard that leads to tenpai
    private void populate_needed_tiles_for_discards(HashMap<Tile, HashMap<TileType, int>> discard_map,
                                                     ArrayList<Tile> sorted_hand,
                                                     ArrayList<RoundStateCall> calls)
    {
        //  int64 start_time = get_monotonic_time();

        // Collect keys first to avoid concurrent modification during iteration
        ArrayList<Tile> keys = new ArrayList<Tile>();
        keys.add_all(discard_map.keys);

        //  Environment.log(LogType.DEBUG, "JulianBot", @"populate_needed_tiles_for_discards: processing $(keys.size) discards");
        HashSet<TileType> checked = new HashSet<TileType>();
        foreach (Tile tDiscard in keys) {
            if(checked.contains(tDiscard.tile_type)) {
                continue;
            } else {
                checked.add(tDiscard.tile_type);
            }
            HashMap<TileType, int> needed_tiles = new HashMap<TileType, int>();

            // Create hand without this discard
            ArrayList<Tile> hand_after_discard = new ArrayList<Tile>();
            hand_after_discard.add_all(sorted_hand);
            hand_after_discard.remove(tDiscard);
            populate_needed_tiles(needed_tiles, hand_after_discard, calls);
            discard_map.set(tDiscard, needed_tiles);
            StringBuilder sb_for_log = new StringBuilder();
            foreach(TileType t in needed_tiles.keys) {
                sb_for_log.append(new Tile(-1,t).to_string() + " ");
            }
            Environment.log(LogType.DEBUG, "JulianBot", @"assume discard: $(tDiscard.to_string()), tenpai: $(sb_for_log.str)");
        }

        //  int64 elapsed = get_monotonic_time() - start_time;
        //  Environment.log(LogType.DEBUG, "JulianBot", @"populate_needed_tiles_for_discards completed in $(elapsed) microseconds");
    }

    private void populate_needed_tiles(HashMap<TileType, int> needed_tiles,
                                                     ArrayList<Tile> sorted_hand,
                                                     ArrayList<RoundStateCall> calls)
    {

        // Find all tiles that would complete this hand (tenpai)
        ArrayList<HandReading> readings = TileRules.hand_readings(sorted_hand, calls, true, false);
        foreach (HandReading hr in readings) {
            foreach (Tile tHR in hr.tiles) {
                if (tHR.ID == -1) {  // ID == -1 means this is the needed tile
                    needed_tiles.set(tHR.tile_type, 4);  // Start with max 4 tiles of this type
                }
            }
        }

        
    }

    // Calculate benefit (available tile count) for each potential discard
    private HashMap<Tile, int> calculate_discard_benefits(HashMap<Tile, HashMap<TileType, int>> discard_map)
    {
        HashMap<Tile, int> discard_benefit = new HashMap<Tile, int>();

        foreach (Tile tDiscard in discard_map.keys) {
            HashMap<TileType, int> needed_tiles = discard_map.get(tDiscard);
            int total_benefit = 0;

            foreach (TileType type_needed in needed_tiles.keys) {
                int available_count = count_available_tiles(type_needed);
                total_benefit += available_count;
            }

            discard_benefit.set(tDiscard, total_benefit);
        }

        return discard_benefit;
    }

    // Count how many tiles of a given type are still available (not visible)
    private int count_available_tiles(TileType tile_type)
    {
        int available = 4;  // Start with max count

        // Subtract dead wall mark tile
        Tile? mark = round_state.dead_wall_mark;
        if (mark != null && mark.tile_type == tile_type) {
            available--;
        }

        // Subtract tiles visible in all players' ponds and calls
        for (int i = 0; i < 4; i++) {
            RoundStatePlayer player = round_state.get_player(i);

            // Check pond
            foreach (Tile pond_tile in player.pond) {
                if (pond_tile.tile_type == tile_type) {
                    available--;
                }
            }

            // Check calls (open melds)
            foreach (RoundStateCall call in player.calls) {
                foreach (Tile call_tile in call.tiles) {
                    if (call_tile.tile_type == tile_type) {
                        available--;
                    }
                }
            }

         
        }

        // hand tiles of myself
        foreach(Tile my_hand_tile in round_state.self.hand) {
            if(my_hand_tile.tile_type == tile_type) {
                available--;
            }
        }
        return available;
    }

    // Find the discard with the highest benefit
    private BestDiscardResult find_best_discard(HashMap<Tile, int> discard_benefit)
    {
        BestDiscardResult result = BestDiscardResult();
        result.tile = null;
        result.benefit = 0;

        foreach (Tile tDiscard in discard_benefit.keys) {
            int benefit = discard_benefit.get(tDiscard);
            Environment.log(LogType.DEBUG, "JulianBot",
                        @"find_best_discard $(tDiscard) for $(benefit)"); 
            if (benefit > result.benefit) {
                result.benefit = benefit;
                result.tile = tDiscard;
            }
        }

        return result;
    }

    // 也就是听章数量
    private int find_best_benefit(HashMap<Tile, int> discard_benefit)
    {
        Tile? best_discard = null;
        int best_benefit = 0;

        foreach (Tile tDiscard in discard_benefit.keys) {
            int benefit = discard_benefit.get(tDiscard);
            if (benefit > best_benefit) {
                best_benefit = benefit;
                best_discard = tDiscard;
            }
        }

        return best_benefit;
    }

    private Tile RandomNonTerminalHonor(ArrayList<Tile> tiles)
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

    // 我手牌里有多少这样的牌
    private int count(Tile tile)
    {
        int count = 0;
        foreach (Tile t in round_state.self.hand)
            if (t.tile_type == tile.tile_type)
                count++;
        return count;
    }

    private bool has_neighbours(Tile tile)
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

    private bool has_second_neighbours(Tile tile)
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

    public override string name { get { return "JulianBot"; } }
}
