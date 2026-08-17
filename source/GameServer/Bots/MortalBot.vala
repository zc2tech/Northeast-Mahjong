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
        if (!connected) connect_to_server();
        if (!connected)
        {
            fallback_discard();
            return;
        }

        send_snapshot();
        send_line("{\"type\":\"turn_decision\"}");

        int action = read_action();
        if (action < 0) { fallback_discard(); return; }

        apply_turn_action(action);
    }

    protected override void do_call_decision(RoundStatePlayer discarding_player, Tile tile)
    {
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

    private void fallback_discard()
    {
        if (round_state != null && round_state.self.hand.size > 0)
            do_discard(round_state.self.hand[round_state.self.hand.size - 1]);
    }

    private Tile? find_tile_of_type(ArrayList<Tile> hand, TileType type)
    {
        foreach (Tile t in hand)
            if (t.tile_type == type)
                return t;
        return null;
    }

    private void apply_turn_action(int action)
    {
        // 0-33: discard tile by libne index
        if (action >= 0 && action <= 33)
        {
            TileType desired = libne_idx_to_tile_type(action);
            Tile? t = find_tile_of_type(round_state.self.hand, desired);
            if (t == null && round_state.self.hand.size > 0)
                t = round_state.self.hand[round_state.self.hand.size - 1];
            if (t != null)
                do_discard(t);
            return;
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
        fallback_discard();
    }

    private void apply_call_action(int action, Tile discard_tile)
    {
        if(round_state.self.hand.size <= 4) {
            call_nothing();
            return;
        }
        // 43: ron (agari on call)
        if (action == 43 && round_state.can_ron(round_state.self))
        {
            call_ron();
            return;
        }

        // 41: pon
        if (action == 41 && round_state.can_pon(round_state.self))
        {
            call_pon();
            return;
        }

        // 42: open kan
        if (action == 42)
        {
            call_open_kan();
            return;
        }

        // 38-40: chi
        if (action >= 38 && action <= 40 && round_state.can_chii(round_state.self))
        {
            ArrayList<ArrayList<Tile>> groups = round_state.self.get_chii_groups(discard_tile);
            if (groups.size > 0)
            {
                int gi = 0;
                if (action == 39 && groups.size > 1) gi = 1;
                if (action == 40 && groups.size > 2) gi = 2;
                if (gi >= groups.size) gi = 0;
                ArrayList<Tile> pair = groups[gi];
                if (pair.size >= 2) { call_chii(pair[0], pair[1]); return; }
            }
        }

        call_nothing();
    }
}
