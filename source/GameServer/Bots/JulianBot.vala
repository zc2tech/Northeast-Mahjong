using Gee;

// Hand analysis statistics
struct HandStatistics
{
    public int terminal_count;
    public int dragon_count;
    public int single_count;
    public int pair_count;
    public int triplet_count;
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

    // Helper: Count patterns (singles, pairs, triplets) in a suit
    private void count_suit_patterns(HashMap<TileType, int> suit_map,
                                     int start_tile,
                                     int end_tile,
                                     ref int single_count,
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
                        single_count++;
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

    // Analyze hand and return statistics
    private HandStatistics analyze_hand(ArrayList<Tile> sorted_hand, ArrayList<RoundStateCall> calls)
    {
        HandStatistics stats = HandStatistics();

        // Create suit maps
        HashMap<TileType, int> map_man = create_suit_map(TileType.MAN1, TileType.MAN9);
        HashMap<TileType, int> map_pin = create_suit_map(TileType.PIN1, TileType.PIN9);
        HashMap<TileType, int> map_sou = create_suit_map(TileType.SOU1, TileType.SOU9);

        stats.terminal_count = 0;
        stats.dragon_count = 0;
        stats.single_count = 0;
        stats.pair_count = 0;
        stats.triplet_count = 0;

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

        // Analyze patterns for each suit
        count_suit_patterns(map_man, TileType.MAN1, TileType.MAN9,
                           ref stats.single_count, ref stats.pair_count, ref stats.triplet_count);
        count_suit_patterns(map_pin, TileType.PIN1, TileType.PIN9,
                           ref stats.single_count, ref stats.pair_count, ref stats.triplet_count);
        count_suit_patterns(map_sou, TileType.SOU1, TileType.SOU9,
                           ref stats.single_count, ref stats.pair_count, ref stats.triplet_count);

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
                                  ArrayList<HandReading> beforeCallReading,
                                  HandStatistics stats,
                                  RoundStatePlayer discarding_player)
    {
        if (!round_state.can_pon(round_state.self) || count(tile) != 2)
        {
            return false;
        }

        int pairCnt = stats.pair_count;
        int tripletCnt = stats.triplet_count;
        int singleCnt = stats.single_count;
        int terminalCnt = stats.terminal_count;

        // 牌好吗 其实如果那一对子正好是 幺九 对的话,其实还行
        if ((pairCnt <= 1 && tripletCnt < 1) || singleCnt >= 3 || terminalCnt <= 2)
        {
            // 等着摸牌吧
            return false;
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
        int bestReadingCnt = beforeCallReading.size;
        foreach (Tile t in newHand)
        {
            ArrayList<Tile> tmpHand = new ArrayList<Tile>();
            tmpHand.add_all(newHand);
            tmpHand.remove(t);
            ArrayList<HandReading> tmpReading = TileRules.hand_readings(tmpHand, newCalls, true, false);
            if (tmpReading.size > bestReadingCnt)
            {
                // 没考虑湖里啥情况,有可能看起来很多,真正机会并不大
                // 真要算好的话, 还得跟tmpHand做个差值看听什么,再看看湖里剩几张
                // 当前算法会不倾向 夹 或着 边牌 ?
                bestDiscard = t;
                bestReadingCnt = tmpReading.size;
            }
        }

        if (bestReadingCnt > beforeCallReading.size)
        {
            // 既然值得碰,那就碰吧.
            return true;
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
        HandStatistics newStats = analyze_hand(newHand, newCalls);
        if (newStats.single_count - stats.single_count >= 2)
        {
            // 散牌增多两张以上啊,不值得
            return false;
        } else {
            return true;
        }

        // 默认就不碰啦
        return false;
    }

    // Evaluate whether to call chii (吃) on a tile
    // Returns true if should call chii, false otherwise
    // If true, sets the out parameters tiles1 and tiles2 to the tiles to use
    private bool should_call_chii(Tile tile,
                                   ArrayList<Tile> sortedhand,
                                   ArrayList<RoundStateCall> calls,
                                   ArrayList<HandReading> beforeCallReading,
                                   HandStatistics stats,
                                   RoundStatePlayer discarding_player,
                                   out Tile tiles1,
                                   out Tile tiles2)
    {
        tiles1 = null;
        tiles2 = null;

        if (!round_state.can_chii(round_state.self))
        {
            return false;
        }

        // 牌好吗 其实如果那一对子正好是 幺九 对的话,其实还行
        if ((stats.pair_count <= 1 && stats.triplet_count < 1) || stats.single_count >= 3 || stats.terminal_count <= 2)
        {
            // 等着摸牌吧
            return false;
        }

        ArrayList<ArrayList<Tile>> groups = TileRules.get_chii_groups(round_state.self.hand, tile);

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

            // 找一下该打什么牌
            Tile bestDiscard = null;
            int bestReadingCnt = beforeCallReading.size;
            foreach (Tile t in newHand)
            {
                ArrayList<Tile> tmpHand = new ArrayList<Tile>();
                tmpHand.add_all(newHand);
                tmpHand.remove(t);
                ArrayList<HandReading> tmpReading = TileRules.hand_readings(tmpHand, newCalls, true, false);
                if (tmpReading.size > bestReadingCnt)
                {
                    // 没考虑湖里啥情况,有可能看起来很多,真正机会并不大
                    // 真要算好的话, 还得跟tmpHand做个差值看听什么,再看看湖里剩几张
                    // 当前算法会不倾向 夹 或着 边牌 ?
                    bestDiscard = t;
                    bestReadingCnt = tmpReading.size;
                }
            }

            if (bestReadingCnt > beforeCallReading.size)
            {
                // 既然值得吃,那就吃吧.
                tiles1 = g[0];
                tiles2 = g[1];
                return true;
            }

            HandStatistics newStats = analyze_hand(newHand, newCalls);
            if (stats.terminal_count == 0 && stats.dragon_count < 2)
            {
                // 我没幺九牌, 看吃完之后能不能好一点
                if(newStats.terminal_count > 0 ) {
                    tiles1 = g[0];
                    tiles2 = g[1];
                    return true;
                }
            }

            if(stats.terminal_count >=1 && newStats.triplet_count == 0) {
                // 把刻子吃没了
                return false;
            }

            // 上面的检查既然没要求吃,说明吃了也不能听牌,但如果孤张没变多的话,也还行啊
            if (newStats.single_count == stats.single_count) {
                tiles1 = g[0];
                tiles2 = g[1];
                return true; 
            } else if(newStats.single_count -1 == stats.single_count) {
                // 吃的时候,多了一张孤张也很正常
                bool random_bool = Random.boolean();
                if(random_bool) {
                    tiles1 = g[0];
                    tiles2 = g[1];
                    return true;
                }
            }
        }

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

   
        // 如果打掉某张可以听牌的话
        ArrayList<Tile> copy_for_tenpai = new ArrayList<Tile>();
        ArrayList<Tile> tiles_allowed = round_state.self.get_discard_tiles();
        Tile discard_for_tenpai = null;
        foreach (Tile tile in tiles_allowed)
        {
            copy_for_tenpai.add_all(tiles_allowed);
            copy_for_tenpai.remove(tile);
            // 能听牌当然就打你了
            if (TileRules.in_tenpai(copy_for_tenpai, round_state.self.calls)) {
                discard_for_tenpai = tile;
                copy_for_tenpai.clear();
                break;
            }
            copy_for_tenpai.clear();
        }
        if (discard_for_tenpai != null) {
           do_discard(discard_for_tenpai); 
           return;
        }
             
        //  Tile t4 = null; // has four same tile_type
        //  ArrayList<Tile> copy = new ArrayList<Tile>();
        //  ArrayList<RoundStateCall> calls = round_state.self.calls;
        //  copy.add_all(round_state.self.hand);
        //  foreach(RoundStateCall c in calls) {
        //     if(c.call_type == RoundStateCall.CallType.PON) {
        //          // 碰过的是有机会再杠的
        //          copy.add_all(c.tiles);
        //     }
        //  }
        //  ArrayList<Tile> sortedhand = Tile.sort_tiles_type(copy);
        //  for(int i=0; i < sortedhand.size - 3 ; i++) {
        //      if(sortedhand[i].tile_type == sortedhand[i+1].tile_type == sortedhand[i+2].tile_type == sortedhand[i+3].tile_type) {
        //          t4 = sortedhand[i];
        //      }
        //  }

        // 既然到了这里,说明你没有办法和牌或者听牌
        if (round_state.can_late_kan()) // 后杠
        {

            ArrayList<Tile> tiles = TileRules.get_late_kan_tiles(round_state.self.hand, round_state.self.calls);
            assert(tiles.size > 0);
            //  assert(t4 != null);
            if (is_tile_safe(tiles[0], false, 4)) {
                do_discard(tiles[0]);
            } else {
                //  assert(t4.tile_type == tiles[0].tile_type);
                do_late_kan(tiles[0]);
            }
           
        }
        else if (round_state.can_closed_kan())
        {
            ArrayList<ArrayList<Tile>> groups = round_state.self.get_closed_kan_groups();
            assert(groups.size > 0);
            Tile tile = groups[0][0];
            if(is_tile_safe(tile, false, 4)) {
                do_discard(tile);
            } else {
                 do_closed_kan(tile.tile_type);
            }
        }
        else
        {
            Tile  tile = get_discard_tile();
            do_discard(tile);
        }
    }

    // 别人打牌之后，做个处理决定
    protected override void do_call_decision(RoundStatePlayer discarding_player, Tile tile)
    {
        ArrayList<Tile> sortedhand = Tile.sort_tiles_type(round_state.self.hand);
        ArrayList<RoundStateCall> calls = round_state.self.calls;
        if(sortedhand.size <= 4) {
            // 手牌只剩两张的话,就没法胡了
            return;
        }

        // 如果听牌数特别多,未必就要立即去胡的,说不定想自摸呢
        if (round_state.can_ron(round_state.self))
        {
            call_ron();
            return;
        }

        // Get s (下家 - shimocha)
        int shimocha_index = (round_state.self.index + 1) % 4;
        //  RoundStatePlayer left_player = round_state.get_player(left_index);
        //  ArrayList<Tile> left_discards = left_player.pond;

        // Get cross/opposite player (对面 - toimen)
        int toimen_index = (round_state.self.index + 2) % 4;
        //    RoundStatePlayer cross_player = round_state.get_player(cross_index);
        //    ArrayList<Tile> cross_discards = cross_player.pond;

        // Get (上家 - kamicha)
        int kamicha_index = (round_state.self.index + 3) % 4;

        // Analyze hand statistics
        HandStatistics stats = analyze_hand(sortedhand,calls);
        ArrayList<HandReading> beforeCallReading = TileRules.hand_readings(sortedhand,calls,true,false);

        // Evaluate pon decision
        if (should_call_pon(tile, sortedhand, calls, beforeCallReading, stats, discarding_player))
        {
            call_pon();
            return;
        }

        // Evaluate chii decision
        Tile chii_tile1;
        Tile chii_tile2;
        if (should_call_chii(tile, sortedhand, calls, beforeCallReading, stats, discarding_player, out chii_tile1, out chii_tile2))
        {
            call_chii(chii_tile1, chii_tile2);
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
    private Tile get_discard_tile()
    {
    //      ArrayList<Tile> sortedhand = Tile.sort_tiles_type(round_state.self.hand);
    //      ArrayList<RoundStateCall> calls = round_state.self.calls;

        ArrayList<Tile> tiles = round_state.self.get_discard_tiles();
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
            return RandomTile(backup);

        foreach (Tile tile in tiles)
        {
            if (tile.is_wind_tile())
            {
                if (!tile.is_wind(round_state.self.wind) && !tile.is_wind(round_state.round_wind))
                    return tile;
                else if (count(tile) <= 1)
                    return tile;
            }
            if (tile.is_dragon_tile())
            {
                if(count(tile) <= 1)
                    return tile;
            }
        }

        backup.clear();
        backup.add_all(tiles);

        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            if (tile.is_dragon_tile() || tile.is_wind(round_state.self.wind) || tile.is_wind(round_state.round_wind))
                tiles.remove_at(i--);
        }

        if (tiles.size == 0)
            return RandomTile(backup);

        backup.clear();
        backup.add_all(tiles);

        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            if (has_neighbours(tile))
                tiles.remove_at(i--);
        }

        if (tiles.size == 0)
            return RandomTile(backup);

        backup.clear();
        backup.add_all(tiles);

        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            if (count(tile) >= 2)
                tiles.remove_at(i--);
        }

        if (tiles.size == 0)
            return RandomTile(backup);

        backup.clear();
        backup.add_all(tiles);

        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            if (has_second_neighbours(tile))
                tiles.remove_at(i--);
        }

        if (tiles.size == 0)
            return RandomTile(backup);

        backup.clear();
        backup.add_all(tiles);

        for (int i = 0; i < tiles.size; i++)
        {
            Tile tile = tiles[i];
            if (!tile.is_terminal_tile())
                tiles.remove_at(i--);
        }

        if (tiles.size == 0)
            return RandomTile(backup);

        return RandomTile(tiles);
    }

    private Tile RandomTile(ArrayList<Tile> tiles)
    {
        return tiles[rnd.int_range(0, tiles.size)];
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
