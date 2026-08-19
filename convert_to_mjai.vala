using Engine;

namespace ConvertToMjai {

void main(string[] args)
{
    // Initialize environment to register types
    Environment.init(false);

    string input_path;
    if (args.length < 2)
    {
        string home = GLib.Environment.get_home_dir();
        input_path = Path.build_filename(home, ".config", "Northeast-Mahjong", "logs", "game");
        print("No input specified, using default: %s\n", input_path);
    }
    else
    {
        input_path = args[1];
    }
    string? output_dir = null;

    if (args.length >= 3)
    {
        output_dir = args[2];
    }

    File input_file = File.new_for_path(input_path);

    try {
        FileInfo info = input_file.query_info("standard::type", FileQueryInfoFlags.NONE);

        if (info.get_file_type() == FileType.DIRECTORY)
        {
            process_directory(input_path, output_dir);
        }
        else
        {
            process_file(input_path, output_dir);
        }
    } catch (Error e) {
        stderr.printf("Error: %s\n", e.message);
    }
}

void process_directory(string dir_path, string? output_dir)
{
    try {
        File dir = File.new_for_path(dir_path);
        FileEnumerator enumerator = dir.enumerate_children("standard::name,standard::type", FileQueryInfoFlags.NONE);

        int total = 0;
        int success = 0;
        int failed = 0;

        FileInfo file_info;
        while ((file_info = enumerator.next_file()) != null)
        {
            if (file_info.get_file_type() == FileType.REGULAR)
            {
                string filename = file_info.get_name();
                if (filename.has_suffix(".log"))
                {
                    total++;
                    string log_path = Path.build_filename(dir_path, filename);
                    print("\n[%d] Processing: %s\n", total, filename);

                    try {
                        process_file(log_path, output_dir);
                        success++;
                    } catch (Error e) {
                        stderr.printf("  Failed: %s\n", e.message);
                        failed++;
                    }
                }
            }
        }

        print("\n========================================\n");
        print("Summary: %d total, %d success, %d failed\n", total, success, failed);

    } catch (Error e) {
        stderr.printf("Error reading directory: %s\n", e.message);
    }
}

void process_file(string log_path, string? output_dir) throws Error
{
    uint8[] data;
    File file = File.new_for_path(log_path);
    file.load_contents(null, out data, null);

    GameLog log = (GameLog?)Serializable.deserialize(data);

    if (log == null) {
        throw new FileError.FAILED("Failed to deserialize log");
    }

    print("  Game Log Version: %s, Rounds: %d\n", log.version.to_string(), log.rounds.to_array().length);

    string out_dir;
    if (output_dir == null)
    {
        string parent_dir = Path.get_dirname(log_path);
        out_dir = Path.build_filename(parent_dir, "..", "mjai");
    }
    else
    {
        out_dir = output_dir;
    }

    File out_dir_file = File.new_for_path(out_dir);
    if (!out_dir_file.query_exists())
    {
        out_dir_file.make_directory_with_parents();
        print("  Created output directory: %s\n", out_dir);
    }

    string log_basename = Path.get_basename(log_path);
    string base_name = log_basename.replace(".log", "");

    string mjai_json = convert_to_mjai(log);

    // Original + 5 suit-permutation augmentations
    // Each entry: [suffix, m_to, p_to, s_to]
    string[,] augmentations = {
        { "",      "m", "p", "s" },  // original
        { "_aug1", "p", "m", "s" },  // MAN↔PIN
        { "_aug2", "s", "p", "m" },  // MAN↔SOU
        { "_aug3", "m", "s", "p" },  // PIN↔SOU
        { "_aug4", "p", "s", "m" },  // MAN→PIN→SOU→MAN
        { "_aug5", "s", "m", "p" },  // MAN→SOU→PIN→MAN
    };

    for (int a = 0; a < 6; a++)
    {
        string suffix  = augmentations[a, 0];
        string m_to    = augmentations[a, 1];
        string p_to    = augmentations[a, 2];
        string s_to    = augmentations[a, 3];

        string aug_json = a == 0 ? mjai_json : apply_suit_permutation(mjai_json, m_to, p_to, s_to);

        string output_name = base_name + suffix + ".json.gz";
        string output_path = Path.build_filename(out_dir, output_name);

        File out_file = File.new_for_path(output_path);
        OutputStream base_stream = out_file.replace(null, false, FileCreateFlags.NONE);
        ZlibCompressor compressor = new ZlibCompressor(ZlibCompressorFormat.GZIP);
        ConverterOutputStream gz_stream = new ConverterOutputStream(base_stream, compressor);
        gz_stream.write_all(aug_json.data, null);
        gz_stream.close();

        print("  Wrote: %s\n", output_path);
    }
}

// Apply suit permutation: replace tile suit suffixes inside quoted tile strings like "3m", "9p", "1s".
// m_to/p_to/s_to specify what 'm'/'p'/'s' maps to respectively.
string apply_suit_permutation(string json, string m_to, string p_to, string s_to)
{
    StringBuilder sb = new StringBuilder.sized(json.length);
    int len = json.length;
    int i = 0;
    while (i < len)
    {
        char c = json[i];
        // Look for pattern: digit followed by suit letter followed by '"'
        // i.e. the sequence  <digit> <m|p|s> "  inside a JSON string
        if (c >= '1' && c <= '9' && i + 2 < len)
        {
            char suit = json[i + 1];
            char after = json[i + 2];
            if (after == '"' && (suit == 'm' || suit == 'p' || suit == 's'))
            {
                sb.append_c(c);
                if (suit == 'm')      sb.append(m_to);
                else if (suit == 'p') sb.append(p_to);
                else                  sb.append(s_to);
                i += 2;
                continue;
            }
        }
        sb.append_c(c);
        i++;
    }
    return sb.str;
}

string convert_to_mjai(GameLog log)
{
    StringBuilder sb = new StringBuilder();

    GameLogRound[] rounds = log.rounds.to_array();
    GamePlayer[] players = log.start_info.get_players();
    int starting_score = log.start_info.starting_score;

    // Emit start_game
    sb.append("{\"type\":\"start_game\",\"id\":0,\"names\":[");
    for (int p = 0; p < 4; p++)
    {
        if (p > 0) sb.append(",");
        string name = (p < players.length) ? players[p].name : @"Player$p";
        sb.append_printf("\"%s\"", name.replace("\"", "\\\""));
    }
    sb.append("]}\n");

    // Reconstruct running scores (start at starting_score each)
    int[] scores = { starting_score, starting_score, starting_score, starting_score };

    // Reconstruct bakaze/kyoku by tracking dealer changes.
    // No renchan: dealer always advances after each hand.
    // Round wind advances every 4 hands (when all 4 players have been dealer once).
    string[] wind_names = { "E", "S", "W", "N" };

    for (int r = 0; r < rounds.length; r++)
    {
        GameLogRound round = rounds[r];
        Tile[] all_tiles = round.tiles.to_array();

        int bakaze_index = r / 4;   // 0=East, 1=South, 2=West, 3=North
        if (bakaze_index > 3) bakaze_index = 3;
        string bakaze = wind_names[bakaze_index];
        int kyoku = (r % 4) + 1;   // 1–4

        convert_round_to_mjai(sb, round, all_tiles, r, bakaze, kyoku, scores);

        // Update running scores
        scores[0] += round.transfer_p0;
        scores[1] += round.transfer_p1;
        scores[2] += round.transfer_p2;
        scores[3] += round.transfer_p3;
    }

    sb.append("{\"type\":\"end_game\"}\n");

    return sb.str;
}

void convert_round_to_mjai(StringBuilder sb, GameLogRound round, Tile[] all_tiles,
                            int round_index, string bakaze, int kyoku, int[] scores)
{
    RoundStartInfo start_info = round.start_info;
    int dealer = start_info.dealer;

    // Get dora marker tile
    int dead_wall_marker_id = start_info.dead_wall_mark_tile_id;
    Tile? dead_wall_marker_tile = find_tile(all_tiles, dead_wall_marker_id);
    string dead_wall_marker_str = dead_wall_marker_tile != null ? tile_to_mjai(dead_wall_marker_tile.tile_type) : "?";

    // Get initial hands
    SerializableList<Tile>[] hands = round.initial_hands.to_array();

    // Write start_kyoku
    sb.append("{\"type\":\"start_kyoku\"");
    sb.append_printf(",\"bakaze\":\"%s\"", bakaze);
    sb.append_printf(",\"kyoku\":%d", kyoku);
    sb.append(",\"honba\":0");
    sb.append(",\"kyotaku\":0");
    sb.append_printf(",\"oya\":%d", dealer);
    sb.append_printf(",\"dead_wall_marker\":\"%s\"", dead_wall_marker_str);
    sb.append_printf(",\"scores\":[%d,%d,%d,%d]", scores[0], scores[1], scores[2], scores[3]);
    sb.append(",\"tehais\":[");

    for (int p = 0; p < hands.length; p++)
    {
        if (p > 0) sb.append(",");
        sb.append("[");
        Tile[] player_tiles = hands[p].to_array();
        for (int t = 0; t < player_tiles.length; t++)
        {
            if (t > 0) sb.append(",");
            sb.append_printf("\"%s\"", tile_to_mjai(player_tiles[t].tile_type));
        }
        sb.append("]");
    }
    sb.append("]}\n");

    // Simulate hand state to reconstruct consumed tiles for pon/daiminkan.
    // hand_counts[player][tile_type_index] = count in hand
    int[,] hand_counts = new int[4, 34];
    for (int p = 0; p < hands.length; p++)
    {
        Tile[] player_tiles = hands[p].to_array();
        foreach (Tile t in player_tiles)
        {
            int idx = tile_type_index(t.tile_type);
            if (idx >= 0) hand_counts[p, idx]++;
        }
    }

    // Track last discard for context-dependent events
    int last_discard_player = -1;
    string last_discard_str = "?";
    int last_discard_idx = -1;   // tile type index 0–33

    bool round_ended = false;  // true if hora/ryukyoku already emitted

    // Process actions
    GameLogLine[] lines = round.lines.to_array();

    for (int i = 0; i < lines.length; i++)
    {
        GameLogLine line = lines[i];
        ServerAction action = line.action;

        if (action is TileDrawServerAction)
        {
            TileDrawServerAction draw = action as TileDrawServerAction;
            Tile? tile = find_tile(all_tiles, draw.tile_ID);
            string tile_str = tile != null ? tile_to_mjai(tile.tile_type) : "?";
            int tidx = tile != null ? tile_type_index(tile.tile_type) : -1;

            sb.append_printf("{\"type\":\"tsumo\",\"actor\":%d,\"pai\":\"%s\"}\n",
                             draw.player, tile_str);

            // Add drawn tile to hand
            if (tidx >= 0) hand_counts[draw.player, tidx]++;
        }
        else if (action is DeadWallDrawServerAction)
        {
            // Dead wall draw after a kan — emit as tsumo
            DeadWallDrawServerAction draw = action as DeadWallDrawServerAction;
            Tile? tile = find_tile(all_tiles, draw.tile_ID);
            string tile_str = tile != null ? tile_to_mjai(tile.tile_type) : "?";
            int tidx = tile != null ? tile_type_index(tile.tile_type) : -1;

            sb.append_printf("{\"type\":\"tsumo\",\"actor\":%d,\"pai\":\"%s\"}\n",
                             draw.player, tile_str);

            if (tidx >= 0) hand_counts[draw.player, tidx]++;
        }
        else if (action is ClientServerAction)
        {
            ClientServerAction csa = action as ClientServerAction;
            ClientAction ca = csa.action;
            int actor = csa.client;

            if (ca is TileDiscardClientAction)
            {
                TileDiscardClientAction discard = ca as TileDiscardClientAction;
                Tile? tile = find_tile(all_tiles, discard.tile);
                string tile_str = tile != null ? tile_to_mjai(tile.tile_type) : "?";
                int tidx = tile != null ? tile_type_index(tile.tile_type) : -1;

                sb.append_printf("{\"type\":\"dahai\",\"actor\":%d,\"pai\":\"%s\",\"tsumogiri\":false}\n",
                                 actor, tile_str);

                // Remove discarded tile from hand
                if (tidx >= 0 && hand_counts[actor, tidx] > 0)
                    hand_counts[actor, tidx]--;

                // Track last discard for calls
                last_discard_player = actor;
                last_discard_str = tile_str;
                last_discard_idx = tidx;
            }
            else if (ca is PonClientAction)
            {
                // Called tile = last discard. Consumed = two copies from actor's hand.
                string pai = last_discard_str;
                int pidx = last_discard_idx;

                // Build consumed list: two tiles of the same type from hand
                string c1 = pai;
                string c2 = pai;

                // Remove the two consumed tiles from hand
                if (pidx >= 0 && hand_counts[actor, pidx] >= 2)
                {
                    hand_counts[actor, pidx] -= 2;
                }

                sb.append_printf("{\"type\":\"pon\",\"actor\":%d,\"target\":%d,\"pai\":\"%s\",\"consumed\":[\"%s\",\"%s\"]}\n",
                                 actor, last_discard_player, pai, c1, c2);

                last_discard_player = -1;
                last_discard_str = "?";
                last_discard_idx = -1;
            }
            else if (ca is ChiiClientAction)
            {
                ChiiClientAction chii = ca as ChiiClientAction;
                Tile? tile1 = find_tile(all_tiles, chii.tile_1);
                Tile? tile2 = find_tile(all_tiles, chii.tile_2);

                string tile1_str = tile1 != null ? tile_to_mjai(tile1.tile_type) : "?";
                string tile2_str = tile2 != null ? tile_to_mjai(tile2.tile_type) : "?";
                int t1idx = tile1 != null ? tile_type_index(tile1.tile_type) : -1;
                int t2idx = tile2 != null ? tile_type_index(tile2.tile_type) : -1;

                // Remove chi tiles from hand
                if (t1idx >= 0 && hand_counts[actor, t1idx] > 0) hand_counts[actor, t1idx]--;
                if (t2idx >= 0 && hand_counts[actor, t2idx] > 0) hand_counts[actor, t2idx]--;

                sb.append_printf("{\"type\":\"chi\",\"actor\":%d,\"target\":%d,\"pai\":\"%s\",\"consumed\":[\"%s\",\"%s\"]}\n",
                                 actor, last_discard_player, last_discard_str, tile1_str, tile2_str);

                last_discard_player = -1;
                last_discard_str = "?";
                last_discard_idx = -1;
            }
            else if (ca is OpenKanClientAction)
            {
                // Called tile = last discard. Consumed = three copies from actor's hand.
                string pai = last_discard_str;
                int pidx = last_discard_idx;

                if (pidx >= 0 && hand_counts[actor, pidx] >= 3)
                    hand_counts[actor, pidx] -= 3;

                sb.append_printf("{\"type\":\"daiminkan\",\"actor\":%d,\"target\":%d,\"pai\":\"%s\",\"consumed\":[\"%s\",\"%s\",\"%s\"]}\n",
                                 actor, last_discard_player, pai, pai, pai, pai);

                last_discard_player = -1;
                last_discard_str = "?";
                last_discard_idx = -1;
            }
            else if (ca is LateKanClientAction)
            {
                LateKanClientAction kan = ca as LateKanClientAction;
                Tile? tile = find_tile(all_tiles, kan.tile);
                string tile_str = tile != null ? tile_to_mjai(tile.tile_type) : "?";
                int tidx = tile != null ? tile_type_index(tile.tile_type) : -1;

                if (tidx >= 0 && hand_counts[actor, tidx] > 0)
                    hand_counts[actor, tidx]--;

                sb.append_printf("{\"type\":\"kakan\",\"actor\":%d,\"pai\":\"%s\"}\n",
                                 actor, tile_str);
            }
            else if (ca is ClosedKanClientAction)
            {
                ClosedKanClientAction kan = ca as ClosedKanClientAction;
                string tile_str = tile_to_mjai(kan.tile_type);
                int tidx = tile_type_index(kan.tile_type);

                if (tidx >= 0 && hand_counts[actor, tidx] >= 4)
                    hand_counts[actor, tidx] -= 4;

                sb.append_printf("{\"type\":\"ankan\",\"actor\":%d,\"consumed\":[\"%s\",\"%s\",\"%s\",\"%s\"]}\n",
                                 actor, tile_str, tile_str, tile_str, tile_str);
            }
            else if (ca is RonClientAction)
            {
                int[] deltas = { round.transfer_p0, round.transfer_p1,
                                 round.transfer_p2, round.transfer_p3 };
                sb.append_printf("{\"type\":\"hora\",\"actor\":%d,\"target\":%d,\"pai\":\"%s\",\"deltas\":[%d,%d,%d,%d]}\n",
                                 actor, last_discard_player, last_discard_str,
                                 deltas[0], deltas[1], deltas[2], deltas[3]);
                round_ended = true;
            }
            else if (ca is TsumoClientAction)
            {
                int[] deltas = { round.transfer_p0, round.transfer_p1,
                                 round.transfer_p2, round.transfer_p3 };
                sb.append_printf("{\"type\":\"hora\",\"actor\":%d,\"target\":%d,\"pai\":\"%s\",\"deltas\":[%d,%d,%d,%d]}\n",
                                 actor, actor, last_discard_str,
                                 deltas[0], deltas[1], deltas[2], deltas[3]);
                round_ended = true;
            }
            else if (ca is VoidHandClientAction)
            {
                int[] deltas = { round.transfer_p0, round.transfer_p1,
                                 round.transfer_p2, round.transfer_p3 };
                sb.append_printf("{\"type\":\"ryukyoku\",\"deltas\":[%d,%d,%d,%d]}\n",
                                 deltas[0], deltas[1], deltas[2], deltas[3]);
                round_ended = true;
            }
        }
        else if (action is DefaultDiscardServerAction)
        {
            // Bot default discard — treat same as TileDiscardClientAction
            DefaultDiscardServerAction discard = action as DefaultDiscardServerAction;
            Tile? tile = find_tile(all_tiles, discard.tile);
            string tile_str = tile != null ? tile_to_mjai(tile.tile_type) : "?";
            int tidx = tile != null ? tile_type_index(tile.tile_type) : -1;

            sb.append_printf("{\"type\":\"dahai\",\"actor\":%d,\"pai\":\"%s\",\"tsumogiri\":false}\n",
                             discard.client, tile_str);

            if (tidx >= 0 && hand_counts[discard.client, tidx] > 0)
                hand_counts[discard.client, tidx]--;

            last_discard_player = discard.client;
            last_discard_str = tile_str;
            last_discard_idx = tidx;
        }
    }

    // If the round ended as a draw (wall exhausted) but no explicit action was logged,
    // emit ryukyoku now based on the stored result_type.
    if (!round_ended && round.result_type == RoundResultType.DRAW)
    {
        int[] deltas = { round.transfer_p0, round.transfer_p1,
                         round.transfer_p2, round.transfer_p3 };
        sb.append_printf("{\"type\":\"ryukyoku\",\"deltas\":[%d,%d,%d,%d]}\n",
                         deltas[0], deltas[1], deltas[2], deltas[3]);
    }

    sb.append("{\"type\":\"end_kyoku\"}\n");
}

Tile? find_tile(Tile[] tiles, int id)
{
    foreach (Tile t in tiles)
    {
        if (t.ID == id)
            return t;
    }
    return null;
}

// Returns tile type index 0–33 matching libne/libriichi convention:
// 0–8=man, 9–17=pin, 18–26=sou, 27=E,28=S,29=W,30=N,31=P,32=F,33=C
int tile_type_index(TileType tile_type)
{
    switch (tile_type)
    {
        case TileType.MAN1: return 0;
        case TileType.MAN2: return 1;
        case TileType.MAN3: return 2;
        case TileType.MAN4: return 3;
        case TileType.MAN5: return 4;
        case TileType.MAN6: return 5;
        case TileType.MAN7: return 6;
        case TileType.MAN8: return 7;
        case TileType.MAN9: return 8;
        case TileType.PIN1: return 9;
        case TileType.PIN2: return 10;
        case TileType.PIN3: return 11;
        case TileType.PIN4: return 12;
        case TileType.PIN5: return 13;
        case TileType.PIN6: return 14;
        case TileType.PIN7: return 15;
        case TileType.PIN8: return 16;
        case TileType.PIN9: return 17;
        case TileType.SOU1: return 18;
        case TileType.SOU2: return 19;
        case TileType.SOU3: return 20;
        case TileType.SOU4: return 21;
        case TileType.SOU5: return 22;
        case TileType.SOU6: return 23;
        case TileType.SOU7: return 24;
        case TileType.SOU8: return 25;
        case TileType.SOU9: return 26;
        case TileType.TON:  return 27;
        case TileType.NAN:  return 28;
        case TileType.SHAA: return 29;
        case TileType.PEI:  return 30;
        case TileType.HAKU: return 31;
        case TileType.HATSU:return 32;
        case TileType.CHUN: return 33;
        default: return -1;
    }
}

string tile_to_mjai(TileType tile_type)
{
    switch (tile_type)
    {
        case TileType.MAN1: return "1m";
        case TileType.MAN2: return "2m";
        case TileType.MAN3: return "3m";
        case TileType.MAN4: return "4m";
        case TileType.MAN5: return "5m";
        case TileType.MAN6: return "6m";
        case TileType.MAN7: return "7m";
        case TileType.MAN8: return "8m";
        case TileType.MAN9: return "9m";

        case TileType.PIN1: return "1p";
        case TileType.PIN2: return "2p";
        case TileType.PIN3: return "3p";
        case TileType.PIN4: return "4p";
        case TileType.PIN5: return "5p";
        case TileType.PIN6: return "6p";
        case TileType.PIN7: return "7p";
        case TileType.PIN8: return "8p";
        case TileType.PIN9: return "9p";

        case TileType.SOU1: return "1s";
        case TileType.SOU2: return "2s";
        case TileType.SOU3: return "3s";
        case TileType.SOU4: return "4s";
        case TileType.SOU5: return "5s";
        case TileType.SOU6: return "6s";
        case TileType.SOU7: return "7s";
        case TileType.SOU8: return "8s";
        case TileType.SOU9: return "9s";

        case TileType.TON:  return "E";
        case TileType.NAN:  return "S";
        case TileType.SHAA: return "W";
        case TileType.PEI:  return "N";
        case TileType.HAKU: return "P";
        case TileType.HATSU:return "F";
        case TileType.CHUN: return "C";

        default: return "?";
    }
}

} // namespace ConvertToMjai
