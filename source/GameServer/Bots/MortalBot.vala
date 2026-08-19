using Gee;
using Engine;

/**
 * MortalBot — delegates decisions to the Mortal inference server via TCP.
 *
 * At each decision point, sends a full game-state snapshot so the server can
 * encode the observation and run Brain→DQN inference.
 *
 * Protocol (JSON lines over TCP):
 *   {"type":"hello","player_id":<int>}          — sent once on connect
 *   {"type":"snapshot",...}                      — sent before every decision
 *   {"type":"turn_decision"}                     — request discard/kan/tsumo
 *   {"type":"call_decision","pai":"<mjai>","target":<int>}  — request call
 *   ← {"type":"action","action":<int>}           — server response
 *
 * Start server: cd Northeast-Mortal && python server/inference_server.py
 */
class MortalBot : Bot
{
    public static string server_host = "127.0.0.1";
    public static uint16 server_port = 11617;

    private SocketConnection? conn = null;
    private DataOutputStream? out_stream = null;
    private DataInputStream?  in_stream  = null;
    private bool connected = false;

    // Track last discard for call context
    private int    last_discard_player = -1;
    private Tile?  last_discard_tile   = null;

    // -----------------------------------------------------------------------
    // TCP helpers
    // -----------------------------------------------------------------------

    private void connect_to_server()
    {
        if (connected)
            return;
        try
        {
            var resolver  = Resolver.get_default();
            var addresses = resolver.lookup_by_name(server_host);
            var address   = new InetSocketAddress(addresses.nth_data(0), server_port);
            conn       = new SocketClient().connect(address);
            out_stream = new DataOutputStream(conn.output_stream);
            in_stream  = new DataInputStream(conn.input_stream);
            connected  = true;

            // Register seat
            string hello = "{\"type\":\"hello\",\"player_id\":%d}\n".printf(game_state != null ? get_my_index() : 0);
            out_stream.put_string(hello);
            out_stream.flush();
            string? ack = in_stream.read_line();
            Environment.log(LogType.INFO, "MortalBot",
                "connected to inference server, ack: " + (ack ?? "(none)"));
        }
        catch (Error e)
        {
            Environment.log(LogType.ERROR, "MortalBot",
                "cannot connect to inference server: " + e.message);
            connected = false;
        }
    }

    private int get_my_index()
    {
        if (round_state != null)
            return round_state.self.index;
        return 0;
    }

    private void send_line(string json)
    {
        if (!connected) return;
        try
        {
            out_stream.put_string(json + "\n");
            out_stream.flush();
        }
        catch (Error e)
        {
            Environment.log(LogType.ERROR, "MortalBot", "send_line: " + e.message);
            connected = false;
        }
    }

    private int read_action()
    {
        if (!connected) return -1;
        try
        {
            string? line = in_stream.read_line();
            if (line == null) return -1;
            return parse_action(line);
        }
        catch (Error e)
        {
            Environment.log(LogType.ERROR, "MortalBot", "read_action: " + e.message);
            return -1;
        }
    }

    private int parse_action(string line)
    {
        int idx = line.index_of("\"action\":");
        if (idx < 0) return -1;
        idx += 9;
        while (idx < line.length && (line[idx] == ' ' || line[idx] == '\t'))
            idx++;
        int start = idx;
        while (idx < line.length && line[idx].isdigit())
            idx++;
        if (idx == start) return -1;
        return int.parse(line.substring(start, idx - start));
    }

    // -----------------------------------------------------------------------
    // TileType ↔ mjai string / libne index
    // -----------------------------------------------------------------------

    private string tile_to_mjai(TileType t)
    {
        int v = (int)t;
        if (v >= (int)TileType.MAN1 && v <= (int)TileType.MAN9)
            return "%dm".printf(v - (int)TileType.MAN1 + 1);
        if (v >= (int)TileType.PIN1 && v <= (int)TileType.PIN9)
            return "%dp".printf(v - (int)TileType.PIN1 + 1);
        if (v >= (int)TileType.SOU1 && v <= (int)TileType.SOU9)
            return "%ds".printf(v - (int)TileType.SOU1 + 1);
        switch (t)
        {
            case TileType.TON:   return "E";
            case TileType.NAN:   return "S";
            case TileType.SHAA:  return "W";
            case TileType.PEI:   return "N";
            case TileType.HAKU:  return "P";
            case TileType.HATSU: return "F";
            case TileType.CHUN:  return "C";
            default:             return "?";
        }
    }

    private TileType libne_idx_to_tile_type(int idx)
    {
        if (idx >= 0 && idx <= 8)  return (TileType)((int)TileType.MAN1 + idx);
        if (idx >= 9 && idx <= 17) return (TileType)((int)TileType.PIN1 + (idx - 9));
        if (idx >= 18 && idx <= 26) return (TileType)((int)TileType.SOU1 + (idx - 18));
        switch (idx)
        {
            case 27: return TileType.TON;
            case 28: return TileType.NAN;
            case 29: return TileType.SHAA;
            case 30: return TileType.PEI;
            case 31: return TileType.HAKU;
            case 32: return TileType.HATSU;
            case 33: return TileType.CHUN;
            default: return TileType.BLANK;
        }
    }

    private string wind_to_mjai(Wind w)
    {
        switch (w)
        {
            case Wind.EAST:  return "E";
            case Wind.SOUTH: return "S";
            case Wind.WEST:  return "W";
            case Wind.NORTH: return "N";
            default:         return "E";
        }
    }

    // -----------------------------------------------------------------------
    // State snapshot
    // -----------------------------------------------------------------------

    // Build and send a full game-state snapshot so the server can encode obs.
    private void send_snapshot()
    {
        if (round_state == null) return;

        int me = round_state.self.index;

        var sb = new StringBuilder();
        sb.append("{\"type\":\"snapshot\"");
        sb.append(",\"player_id\":"); sb.append(me.to_string());
        sb.append(",\"dealer\":"); sb.append(round_state.dealer.to_string());
        sb.append(",\"round_wind\":\""); sb.append(wind_to_mjai(round_state.round_wind)); sb.append("\"");

        // kyoku = hand number within current wind (0-indexed)
        // We use game_state.current_round mod 4 as approximation
        int kyoku = (game_state != null) ? (game_state.current_round % 4) : 0;
        sb.append(",\"kyoku\":"); sb.append((kyoku + 1).to_string());

        // Scores (4 players)
        sb.append(",\"scores\":[");
        for (int i = 0; i < 4; i++)
        {
            if (i > 0) sb.append(",");
            if (game_state != null)
                sb.append(game_state.get_player(i).points.to_string());
            else
                sb.append("0");
        }
        sb.append("]");

        // hands[player] — only self hand is known; others are empty
        sb.append(",\"hands\":[");
        for (int p = 0; p < 4; p++)
        {
            if (p > 0) sb.append(",");
            sb.append("[");
            if (p == me)
            {
                bool first = true;
                foreach (Tile t in round_state.self.hand)
                {
                    if (!first) sb.append(",");
                    sb.append("\""); sb.append(tile_to_mjai(t.tile_type)); sb.append("\"");
                    first = false;
                }
            }
            sb.append("]");
        }
        sb.append("]");

        // ponds[player]
        sb.append(",\"ponds\":[");
        for (int p = 0; p < 4; p++)
        {
            if (p > 0) sb.append(",");
            sb.append("[");
            RoundStatePlayer rsp = round_state.get_player(p);
            bool first = true;
            foreach (Tile t in rsp.pond)
            {
                if (!first) sb.append(",");
                sb.append("\""); sb.append(tile_to_mjai(t.tile_type)); sb.append("\"");
                first = false;
            }
            sb.append("]");
        }
        sb.append("]");

        // calls[player]: list of melds, each meld is list of tile strings + type
        sb.append(",\"calls\":[");
        for (int p = 0; p < 4; p++)
        {
            if (p > 0) sb.append(",");
            sb.append("[");
            RoundStatePlayer rsp = round_state.get_player(p);
            bool first_call = true;
            foreach (RoundStateCall c in rsp.calls)
            {
                if (!first_call) sb.append(",");
                sb.append("{\"call_type\":\"");
                switch (c.call_type)
                {
                    case RoundStateCall.CallType.CHII:       sb.append("chi"); break;
                    case RoundStateCall.CallType.PON:        sb.append("pon"); break;
                    case RoundStateCall.CallType.OPEN_KAN:   sb.append("open_kan"); break;
                    case RoundStateCall.CallType.CLOSED_KAN: sb.append("closed_kan"); break;
                    case RoundStateCall.CallType.LATE_KAN:   sb.append("late_kan"); break;
                    default:                                 sb.append("unknown"); break;
                }
                sb.append("\",\"tiles\":[");
                bool first_tile = true;
                foreach (Tile t in c.tiles)
                {
                    if (!first_tile) sb.append(",");
                    sb.append("\""); sb.append(tile_to_mjai(t.tile_type)); sb.append("\"");
                    first_tile = false;
                }
                sb.append("]}");
                first_call = false;
            }
            sb.append("]");
        }
        sb.append("]");

        // last_discard: the tile that was just discarded (for call_decision context)
        if (last_discard_tile != null)
        {
            sb.append(",\"last_discard\":\"");
            sb.append(tile_to_mjai(last_discard_tile.tile_type));
            sb.append("\"");
            sb.append(",\"last_discard_player\":");
            sb.append(last_discard_player.to_string());
        }

        sb.append("}");
        send_line(sb.str);
    }

    // -----------------------------------------------------------------------
    // Bot overrides
    // -----------------------------------------------------------------------

    public override string name { get { return "MortalBot"; } }

    protected override void do_logic()
    {
        if (!connected)
            connect_to_server();
    }

    protected override void do_turn_decision()
    {
        if (round_state.can_tsumo())
        {
            do_tsumo();
            return;
        }
        ArrayList<Tile> tiles_allowed = round_state.self.get_discard_tiles();
        if (!connected) connect_to_server();
        if (!connected)
        {
            fallback_discard(tiles_allowed);
            return;
        }

        ArrayList<Tile> sorted_hand = Tile.sort_tiles_type(round_state.self.hand);
        ArrayList<RoundStateCall> calls = round_state.self.calls;

        //  HashMap<TileType, int> hcalled = called_tiles();
        if( TileRules.win_necessary_condition(sorted_hand, calls, true)) {
            HashMap<Tile, HashMap<TileType, int>> hDiscardForTenpai= new HashMap<Tile,HashMap<TileType, int>>();
            // 如果打掉某张可以听牌的话
            ArrayList<Tile> copy_for_tenpai = new ArrayList<Tile>();
         

            Tile discard_for_tenpai = null;
            HashSet<TileType> checked = new HashSet<TileType>();
             Environment.log(LogType.DEBUG, "MortalBot", @"*-* $(round_state.self.wind.to_string()) passed win necessary, tiles_allowd: $(tiles_allowed.size)");
            foreach (Tile tile in tiles_allowed)
            {
                if(checked.contains(tile.tile_type)) {
                    continue;
                } else {
                    checked.add(tile.tile_type);
                }
                copy_for_tenpai.add_all(round_state.self.hand);
                copy_for_tenpai.remove(tile);
                // 能听牌当然就打你了
                if (TileRules.in_tenpai(copy_for_tenpai, round_state.self.calls)) {
                    discard_for_tenpai = tile;
                     Environment.log(LogType.DEBUG, "MortalBot", @"!!! Found tenpai discard ($(round_state.self.wind.to_string())): $(tile.tile_type.to_string())");
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
        send_snapshot();
        send_line("{\"type\":\"turn_decision\"}");

        // Always read the server response first to keep the socket in sync.
        int action = read_action();

        // Fall back to the model's action
        if (action < 0) { fallback_discard(tiles_allowed); return; }
        apply_turn_action(action,tiles_allowed);
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

      // Populate needed tiles for each potential discard that leads to tenpai
    private void populate_needed_tiles_for_discards(HashMap<Tile, HashMap<TileType, int>> discard_map,
                                                     ArrayList<Tile> sorted_hand,
                                                     ArrayList<RoundStateCall> calls)
    {
        //  int64 start_time = get_monotonic_time();

        // Collect keys first to avoid concurrent modification during iteration
        ArrayList<Tile> keys = new ArrayList<Tile>();
        keys.add_all(discard_map.keys);

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
            Environment.log(LogType.DEBUG, "MortalBot", @"assume discard: $(tDiscard.to_string()), tenpai: $(sb_for_log.str)");
        }

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

    protected override void do_call_decision(RoundStatePlayer discarding_player, Tile tile)
    {
        if (round_state.can_ron(round_state.self))
        {
            call_ron();
            return;
        }
        if(round_state.self.hand.size <= 4) {
            // 手牌只剩两张的话,就没法胡了
            call_nothing();  // CRITICAL: Must notify server we're done deciding
            return;
        }
        last_discard_player = discarding_player.index;
        last_discard_tile   = tile;

        if (!connected) connect_to_server();
        if (!connected) { call_nothing(); return; }

        send_snapshot();
        string call_evt = "{\"type\":\"call_decision\",\"pai\":\"%s\",\"target\":%d}".printf(
            tile_to_mjai(tile.tile_type), discarding_player.index);
        send_line(call_evt);

        int action = read_action();
        if (action < 0) { call_nothing(); return; }

        apply_call_action(action, tile);
    }

    // -----------------------------------------------------------------------
    // Action dispatch
    // -----------------------------------------------------------------------

    private void fallback_discard(ArrayList<Tile> tiles_allowed)
    {
        if (tiles_allowed.size > 0 ) {
            do_discard(tiles_allowed[0]);
        } else {
            Environment.log(LogType.DEBUG, "MortalBot",
                @"fallback_discard, no available tile to discard");
        }
    }

    private Tile? find_tile_of_type(ArrayList<Tile> hand, TileType type)
    {
        foreach (Tile t in hand)
            if (t.tile_type == type)
                return t;
        return null;
    }

    private void apply_turn_action(int action, ArrayList<Tile> tiles_allowed)
    {
        // 0-33: discard tile by libne index
        if (action >= 0 && action <= 33)
        {
            TileType desired = libne_idx_to_tile_type(action);
            Tile? t = find_tile_of_type(round_state.self.hand, desired);
            if( t!= null) {
                foreach(Tile t_allow in tiles_allowed) {
                    if(t_allow.tile_type == t.tile_type) {
                        do_discard(t);
                        return;
                    }
                }
            }
        }
        // 42: kan
        if (action == 42)
        {
            // Try late kan first
            foreach (RoundStateCall call in round_state.self.calls)
            {
                if (call.call_type == RoundStateCall.CallType.PON)
                {
                    Tile? t = find_tile_of_type(round_state.self.hand, call.tiles[0].tile_type);
                    if (t != null) { do_late_kan(t); return; }
                }
            }
            // Try closed kan
            foreach (Tile t in round_state.self.hand)
            {
                int cnt = 0;
                foreach (Tile t2 in round_state.self.hand)
                    if (t2.tile_type == t.tile_type) cnt++;
                if (cnt >= 4 && round_state.self.hand.size > 5) { do_closed_kan(t.tile_type); return; }
            }
        }
        // 43: tsumo
        if (action == 43 && round_state.can_tsumo())
        {
            do_tsumo();
            return;
        }
        // 44: void hand
        if (action == 44 && round_state.can_void_hand())
        {
            do_void_hand();
            return;
        }
        // Fallback
        fallback_discard(tiles_allowed);
    }

    private void apply_call_action(int action, Tile discard_tile)
    {
        Environment.log(LogType.DEBUG, "MortalBot",
            @"apply_call_action: action=$(action), discard=$(tile_to_mjai(discard_tile.tile_type)), hand_size=$(round_state.self.hand.size), calls=$(round_state.self.calls.size)");

        // 43: ron (agari on call)
        if (action == 43 && round_state.can_ron(round_state.self))
        {
            Environment.log(LogType.DEBUG, "MortalBot", "calling ron");
            call_ron();
            return;
        }

        // 41: pon
        if (action == 41 && round_state.can_pon(round_state.self))
        {
            Environment.log(LogType.DEBUG, "MortalBot", "calling pon");
            call_pon();
            return;
        }
        if (action == 41)
            Environment.log(LogType.DEBUG, "MortalBot", @"model wants pon but can_pon=false");

        // 42: open kan
        if (action == 42)
        {
            Environment.log(LogType.DEBUG, "MortalBot", "calling open kan");
            call_open_kan();
            return;
        }

        // 38-40: chi
        if (action >= 38 && action <= 40)
        {
            bool can = round_state.can_chii(round_state.self);
            ArrayList<ArrayList<Tile>> groups = can ? round_state.self.get_chii_groups(discard_tile) : new ArrayList<ArrayList<Tile>>();
            Environment.log(LogType.DEBUG, "MortalBot",
                @"model wants chi $(action), can_chii=$(can), groups=$(groups.size)");
            if (can && groups.size > 0)
            {
                int gi = 0;
                if (action == 39 && groups.size > 1) gi = 1;
                if (action == 40 && groups.size > 2) gi = 2;
                if (gi >= groups.size) gi = 0;
                ArrayList<Tile> pair = groups[gi];
                if (pair.size >= 2) { call_chii(pair[0], pair[1]); return; }
            }
        }

        // 45 or anything else: pass
        Environment.log(LogType.DEBUG, "MortalBot", @"passing (action=$(action))");
        call_nothing();
    }
}
