using Gee;

class JulianBot : Bot
{
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

        // 碰了之后什么状态? 刻子肯定是多了的
        HashMap<TileType, int> hCalled = called_tiles();
        hCalled.set(tile.tile_type,3); // 因为假设碰了，所以自己做数据去试一下
        HandStatistics newStats = analyze_hand(tile, newHand, newCalls, hCalled);
        if (newStats.singles.size - stats.singles.size >= 2)
        {
            // 散牌增多两张以上啊,不值得
            return false;
        }

        if( newStats.singles_ish.size - stats.singles_ish.size >= 2 ) {
            return false;
        }

        if (tripletCnt == 0 && singleCnt <= 3)
        {
            // 还是很有用的, 散牌也不算太多
            return true;
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
                                  int beforeBenefit,
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

        // Get cross/opposite player (对面 - toimen)
        int toimen_index = (round_state.self.index + 2) % 4;

        // Get (上家 - kamicha)
        int kamicha_index = (round_state.self.index + 3) % 4;

        if(kamicha_index == discarding_player.index) {
            // no reason the hand tiles can get better with kan, although it's possible with pon which checked before
            return false;
        }
        if(beforeBenefit > 0 && toimen_index == discarding_player.index ) {
            return false;
        }

        // start from here, it's must from shimocha

        // 杠掉试试
        ArrayList<Tile> newHand = new ArrayList<Tile>();
        ArrayList<RoundStateCall> newCalls = new ArrayList<RoundStateCall>();
        newCalls.add_all(calls);
        ArrayList<Tile> kan_tiles = new ArrayList<Tile>();
        kan_tiles.add(tile);

        foreach (Tile t in sortedhand)
        {
            if (t.tile_type == tile.tile_type)
            {
                kan_tiles.add(t);
            }
            else
            {
                newHand.add(t);
            }
        }
        RoundStateCall new_call = new RoundStateCall(RoundStateCall.CallType.OPEN_KAN, kan_tiles, tile, discarding_player.index);
        newCalls.add(new_call);

        // Even we already tenpai, it should be a chance to improve our hand tiles
        // But we need to make sure we still tenpai after kan
        int newBenefit = 0;
        if(beforeBenefit > 0) {
            HashMap<TileType, int> needed_tiles = new HashMap<TileType, int>();
            populate_needed_tiles(needed_tiles, newHand, newCalls);
            foreach (TileType type_needed in needed_tiles.keys) {
                int available_count = count_available_tiles(type_needed,round_state.self.index,false);
                newBenefit += available_count;
            }
            Environment.log(LogType.DEBUG, "JulianBot",
                @"should_call_kan, NewBenefit: $(newBenefit)");

            // usually, it will disrupt our tenpai
            if(newBenefit <= 0) {
                return false;
            }

            // even newBenefit still exist, it has no reason better the beforeBenefit.
            if( beforeBenefit <=2 ) {
                 return true;
            } else if (beforeBenefit <= 4 ) {
                return Random.boolean();
            } else {
                return false;
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

        BestDiscardResult bestChiiResut = new BestDiscardResult();
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
            // 幺九的话，你还是要给后续机会的，不能直接continue
            if(!tile.is_terminal_tile() && newStats.singles.size > stats.singles.size) {
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
            if(!tile.is_terminal_tile() && newStats.triplet_count < 1 && newStats.pair_count < 2) {
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
        //  Environment.log(LogType.DEBUG, "JulianBot", @"*** rinshan: $(round_state.self.wind.to_string()) $(round_state.rinshan)");

        // 没有九种九牌 就流局的概念
        //  else if (round_state.can_void_hand())
        //  {
        //      do_void_hand();
        //  }

        ArrayList<Tile> sorted_hand = Tile.sort_tiles_type(round_state.self.hand); 
        ArrayList<RoundStateCall> calls = round_state.self.calls;   

        HashMap<TileType, int> hcalled = called_tiles();
        HandStatistics stats = analyze_hand(null, sorted_hand, calls,hcalled);

        // win_necessary_condition 就当听牌, 所以条件不是特别严格
        // 已经尽力了
        if( TileRules.win_necessary_condition(sorted_hand, calls, true)) {
            HashMap<Tile, HashMap<TileType, int>> hDiscardForTenpai= new HashMap<Tile,HashMap<TileType, int>>();
            // 如果打掉某张可以听牌的话
            ArrayList<Tile> copy_for_tenpai = new ArrayList<Tile>();
            ArrayList<Tile> tiles_allowed = round_state.self.get_discard_tiles();

            Tile discard_for_tenpai = null;
            HashSet<TileType> checked = new HashSet<TileType>();
             Environment.log(LogType.DEBUG, "JulianBot", @"*-* $(round_state.self.wind.to_string()) passed win necessary, tiles_allowd: $(tiles_allowed.size)");
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
                    // 到时候会算舍去这张牌能听多少 <类型,张数>
                     Environment.log(LogType.DEBUG, "JulianBot", @"!!! Found tenpai discard ($(round_state.self.wind.to_string())): $(tile.tile_type.to_string())");
                    hDiscardForTenpai.set(discard_for_tenpai, new HashMap<TileType, int>());
                }
                copy_for_tenpai.clear();
            }
            if (hDiscardForTenpai.keys.size > 0) {
                populate_needed_tiles_for_discards(hDiscardForTenpai, sorted_hand, calls);
                HashMap<Tile, int> discard_benefit = calculate_discard_benefits(hDiscardForTenpai);
                ArrayList <BestDiscardResult> result_array = find_best_discards(discard_benefit);

                // 下面算法主要是为了收益相同的时候， 考虑怎么容易改听
                ArrayList<BestDiscardResult> backup = new ArrayList<BestDiscardResult>();
                for (int i = result_array.size -1 ; i >=0; i-- ) {
                    backup.clear();
                    backup.add_all(result_array);
                    Tile keep = result_array[i].tile;
                    if( has_neighbours(keep) || has_second_neighbours(keep)) {
                        result_array.remove_at(i); 
                    }
                    if(result_array.size == 0) {
                        do_discard(backup[0].tile);
                        return;
                    }
                }

                // 剩下的就是不需要保护的
                if(result_array.size > 0) {
                    do_discard(result_array[0].tile);
                    return; 
                }
            
            } // hDiscardForTenpai.keys.size > 0
        } // win_necessary_condition check end
    
        // 既然到了这里,说明你没有办法和牌或者听牌 
        if (round_state.can_late_kan()) // 后杠
        {
            ArrayList<Tile> tiles = TileRules.get_late_kan_tiles(round_state.self.hand, round_state.self.calls);
            assert(tiles.size > 0);
            foreach(Tile hand_tile in tiles) {
                if(hand_tile.is_dragon_tile()) {
                    do_late_kan(hand_tile);
                    return;
                }
                
                bool hasNeigh = has_neighbours(hand_tile);
                bool hasSecNeigh = has_second_neighbours(hand_tile);

                if(!hasNeigh && !hasSecNeigh) {
                    if(hand_tile.is_terminal_tile()) {
                        do_late_kan(hand_tile);
                        return; 
                    }

                    if( hand_tile.is_terminal_neighbour_tile() || hand_tile.is_terminal_second_neighbour_tile()) {
                        if(stats.dragon_count >= 2 || stats.hasTerminalSeq || stats.hasTerminalTriplet) {
                            do_late_kan(hand_tile);
                            return;  
                        }
                    }        
                }
            }
        }

        if (sorted_hand.size > 5 && round_state.can_closed_kan())
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
    private  HashMap<TileType, int> called_tiles() {
        HashMap<TileType,int> hCalled = new HashMap<TileType,int>(); // Other Player: OP
        for(int i= TileType.MAN1 ;  i < TileType.CHUN; i++ ) {
           hCalled.set((TileType)i,0); 
        }
        for(int i = 0 ; i < 4 ; i++ ) {
            if(i == round_state.self.index) {
                continue;
            }
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
    // 别人打牌之后，做个处理决定
    protected override void do_call_decision(RoundStatePlayer discarding_player, Tile tile)
    {

        ArrayList<Tile> sortedhand = Tile.sort_tiles_type(round_state.self.hand);
        ArrayList<RoundStateCall> calls = round_state.self.calls;
        if(sortedhand.size < 4) {
            // 手牌只剩两张的话,就没法胡了
            call_nothing();  // CRITICAL: Must notify server we're done deciding
            return;
        }

        // 如果听牌数特别多,未必就要立即去胡的,说不定想自摸呢
       
        if (round_state.can_ron(round_state.self))
        {
            call_ron();
            return;
        }
        // Analyze hand statistics
        HashMap<TileType, int> hOP = called_tiles();
        HandStatistics stats = analyze_hand(tile, sortedhand, calls, hOP);

        int beforeBenefit = 0;
        HashMap<TileType, int> needed_tiles = new HashMap<TileType, int>();
        populate_needed_tiles(needed_tiles,sortedhand,calls);
        foreach (TileType type_needed in needed_tiles.keys) {
            int available_count = count_available_tiles(type_needed,round_state.self.index,false);
            beforeBenefit += available_count;

            Tile for_log = new Tile(-1,type_needed);
            Environment.log(LogType.DEBUG, "JulianBot",
                @"do_call_decision Before_Need_Tile: $(for_log.to_string()) : $(available_count) ");
        }
        if (beforeBenefit > 0) {
            Environment.log(LogType.DEBUG, "JulianBot",
                @"do_call_decision BeforeBenefit: $(beforeBenefit) ");
        }

        // Evaluate chii decision
        Tile chii_tile1;
        Tile chii_tile2;
        if (should_call_chii(tile, sortedhand, calls, beforeBenefit, stats, discarding_player, out chii_tile1, out chii_tile2))
        {
            call_chii(chii_tile1, chii_tile2);
            return;
        }

        // Evaluate pon decision
        if (should_call_pon(tile, sortedhand, calls, beforeBenefit, stats, discarding_player))
        {
            call_pon();
            return;
        }

   

         // Evaluate kan decision
        if (should_call_kan(tile, sortedhand, calls, beforeBenefit, stats, discarding_player))
        {
            call_open_kan();
            return;
        }

        call_nothing();
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
        
        bool has_terminal_dragon_pair_seq = false; // just check hand tiles
        backup.clear();
        backup.add_all(tiles);
        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            //  if (tile.is_dragon_tile() || tile.is_wind(round_state.self.wind) || tile.is_wind(round_state.round_wind))
            //      tiles.remove_at(i--);
            // 到这里肯定不是单数了 就留着
            if (tile.is_dragon_tile())
            {
                has_terminal_dragon_pair_seq = true;
                tiles.remove_at(i--);
            }
        }
        if (tiles.size == 0)
            return RandomTileSmart(stats,backup);
        
        // 干净的幺九顺子必须留啊
        backup.clear();
        backup.add_all(tiles);
        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            if(!tile.is_terminal_tile()) {
                continue;
            }
            TileType tile_type = tile.tile_type;
            if (tile_type == TileType.MAN1 ||
                tile_type == TileType.PIN1 ||
                tile_type == TileType.SOU1) {
                ArrayList<Tile> me_list = filter_tile_type(tile_type);
                ArrayList<Tile> p1_list = filter_tile_type(tile_type + 1);
                ArrayList<Tile> p2_list = filter_tile_type(tile_type + 2);
                if(me_list.size == 1 && p1_list.size == 1 && p2_list.size == 1) {
                   has_terminal_dragon_pair_seq = true;
                   tiles.remove(me_list.get(0)); 
                   tiles.remove(p1_list.get(0)); 
                   tiles.remove(p2_list.get(0)); 
                }
                // 独苗幺九顺
                if(stats.terminal_count == 1 && p1_list.size >= 1 && p2_list.size >= 1) {
                    has_terminal_dragon_pair_seq = true;
                    tiles.remove(me_list.get(0)); 
                    tiles.remove(p1_list.get(0)); 
                    tiles.remove(p2_list.get(0));  
                }
            }
            if (tile_type == TileType.MAN9 ||
                tile_type == TileType.PIN9 ||
                tile_type == TileType.SOU9) {
                ArrayList<Tile> me_list = filter_tile_type(tile_type);
                ArrayList<Tile> m1_list = filter_tile_type(tile_type - 1);
                ArrayList<Tile> m2_list = filter_tile_type(tile_type - 2);
                if(me_list.size == 1 && m1_list.size == 1 && m2_list.size == 1) {
                   has_terminal_dragon_pair_seq = true;
                   tiles.remove(me_list.get(0)); 
                   tiles.remove(m1_list.get(0)); 
                   tiles.remove(m2_list.get(0)); 
                }
                // 独苗幺九顺
                if(stats.terminal_count == 1 && m1_list.size >= 1 && m2_list.size >= 1) {
                    has_terminal_dragon_pair_seq = true;
                    tiles.remove(me_list.get(0)); 
                    tiles.remove(m1_list.get(0)); 
                    tiles.remove(m2_list.get(0));  
                }
            }
        }
        if (tiles.size == 0)
            return RandomTileSmart(stats, backup);


        backup.clear();
        backup.add_all(tiles);
        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            if (has_neighbours(tile)) {
                // count if from self.hand, so don't worry the data consistency when removed one tile of pair
                if(count(tile) == 2) {
                    if(tile.is_terminal_tile()) {
                        has_terminal_dragon_pair_seq = true;
                    }
                    if(!stats.hasTerminalSeq && !stats.hasTerminalTriplet && tile.is_terminal_tile()) {
                        tiles.remove_at(i--); 
                    }
                }
            }             
        }
        if (tiles.size == 0)
            return RandomTileSmart(stats, backup);

        // 顺子里的独苗还是要留 1234 怎么办？
        backup.clear();
        backup.add_all(tiles);
        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            if( (stats.hasTerminalTriplet || stats.dragon_count >= 3)  
                && stats.hand_in_seq.contains(tile.tile_type)) {
                    // 已经有刻子了的情况下，顺子才珍贵， 要不随时可以打掉
                    tiles.remove_at(i--); 
                }     
        }
        if (tiles.size == 0)
            return RandomTileSmart(stats, backup);

        backup.clear();
        backup.add_all(tiles);

        // 到了这里不可能算刻子了，这些对子肯定是没近邻的
        int pair_cnt = 0;
        HashSet<TileType> pair_tile_type = new HashSet<TileType>();
        HashSet<TileType> pair_terminal_type = new HashSet<TileType>();
        
        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            // pair_cnt 是经过上一轮之后算出的，你需要加上当前的看看 记得别为一对算两遍 pair_cnt
            if (!pair_tile_type.contains(tile.tile_type) &&  count(tile) >= 2) 
            {
                pair_cnt++;
                pair_tile_type.add(tile.tile_type);
                if(tile.is_terminal_tile()) {
                    pair_terminal_type.add(tile.tile_type);
                    has_terminal_dragon_pair_seq = true;
                }
            }               
        }
        // 留一下 3对做个阈值吧，因为有可能对是被人两头用啊
        if(pair_cnt <= 3) {
             for (int i = 0; i < tiles.size; i++) {
                if(pair_tile_type.contains(tiles[i].tile_type)) {
                    tiles.remove_at(i--); // 对子还是很珍贵的，
                }
             }
        } else if (!stats.hasTerminalSeq || !stats.hasTerminalTriplet) {
             // 即使 对 很多， 幺九对仍然要留
             for (int i = 0; i < tiles.size; i++) {
                if(pair_terminal_type.contains(tiles[i].tile_type)) {
                    tiles.remove_at(i--);
                }
             } 
        } else {
            // 对子还是很多，就不珍贵了 中心牌的留一下
            for (int i = 0; i < tiles.size; i++) {
                TileType tt = tiles[i].tile_type;
                if(pair_tile_type.contains(tt)
                    && (tt >= TileType.MAN3 && tt <= TileType.MAN7
                        || tt >= TileType.PIN3 && tt <= TileType.PIN7
                        || tt >= TileType.SOU3 && tt <= TileType.SOU7)) {
                    tiles.remove_at(i--); // 对子还是很珍贵的，
                }
            }           
        }
        // 留完竟然空了，那就从有紧邻的里选吧 都是好牌啊，不知道可不可能
        if (tiles.size == 0)
            return RandomTileSmart(stats, backup);

        // 幺九也是很珍贵的
        backup.clear();
        backup.add_all(tiles);
        ArrayList<Tile> terminal_in_need = new ArrayList<Tile>();
        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            if (!(has_terminal_dragon_pair_seq || stats.hasTerminalSeq || stats.hasTerminalTriplet || stats.dragon_count >=2)  
                && tile.is_terminal_tile() && (has_neighbours(tile) || has_second_neighbours(tile))
                && !stats.singles_ish.contains(tile.tile_type) ) {
                terminal_in_need.add(tile);             
            }
        }
        // Remove tiles that are terminal or neighbors/second-neighbors of terminal_in_need
        // Do this in reverse order to avoid index shifting issues
        for (int i = tiles.size - 1; i >= 0; i--)
        {
            bool should_remove = false;
            Tile tile = tiles[i];
            foreach(Tile t in terminal_in_need) {
                if(t == tile|| t.is_neighbour(tile) || t.is_second_neighbour(tile)) {
                    should_remove = true;
                    break;
                }
            }
            if (should_remove) {
                tiles.remove_at(i);
            }
        }
        if (tiles.size == 0)
            return RandomTileSmart(stats, backup);

        backup.clear();
        backup.add_all(tiles);
        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            if (!tile.is_terminal_tile() && has_non_terminal_neighbours(tile)
                && !stats.singles_ish.contains(tile.tile_type) ) {
                tiles.remove_at(i--); // 到这里了，非幺九，基本就是两面顺子了，也可以留一下了
            }             
        }
        if (tiles.size == 0)
            return RandomTileSmart(stats, backup);

        backup.clear();
        backup.add_all(tiles);

        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            if ( (has_neighbours(tile) ||  has_second_neighbours(tile)) && !stats.singles_ish.contains(tile.tile_type))
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
                int available_count = count_available_tiles(type_needed,round_state.self.index,false);
                total_benefit += available_count;
            }

            discard_benefit.set(tDiscard, total_benefit);
        }

        return discard_benefit;
    }

    // Count how many tiles of a given type are still available (not visible)
    private int count_available_tiles(TileType tile_type, int me_index, bool cheating)
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
            // Usually, we can only see ourselves hand tiles unless you cheat
            // we don't count the tile which assumed discarding as otherwise we call tsumo
            // we assume that every player will keep the tiles we needed, although that may not be the truth
            if(cheating || me_index == i) {
                // Check hand
                foreach (Tile hand_tile in player.hand) {
                    if (hand_tile.tile_type == tile_type) {
                        available--;
                    } 
                }
            }

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

        return available;
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
    private ArrayList<Tile>  filter_tile_type(TileType tp)
    {
        ArrayList<Tile> list = new ArrayList<Tile>();
         foreach (Tile t in round_state.self.hand)
            if (t.tile_type == tp)
                list.add(t);
        return list;
    }



    public override string name { get { return "JulianBot"; } }
}
