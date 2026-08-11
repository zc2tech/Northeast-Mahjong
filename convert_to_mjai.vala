using Engine;

namespace ConvertToMjai {

void main(string[] args)
{
    if (args.length < 2)
    {
        print("Usage: convert_to_mjai <log_file> [output_dir]\n");
        print("  If output_dir is not specified, uses ../mjai relative to log file location\n");
        return;
    }

    // Initialize environment to register types
    Environment.init(false);

    string log_path = args[1];
    string? output_dir = null;

    if (args.length >= 3)
    {
        output_dir = args[2];
    }

    // Read the log file
    try {
        uint8[] data;
        File file = File.new_for_path(log_path);
        file.load_contents(null, out data, null);

        print("Loaded %d bytes from %s\n", data.length, log_path);

        // Deserialize the log
        GameLog log = (GameLog?)Serializable.deserialize(data);

        if (log == null) {
            stderr.printf("Failed to deserialize log\n");
            return;
        }

        print("Game Log Version: %s\n", log.version.to_string());
        print("Rounds: %d\n", log.rounds.to_array().length);

        // Determine output directory
        if (output_dir == null)
        {
            // Get parent directory of log file
            string parent_dir = Path.get_dirname(log_path);
            // Create ../mjai relative to log directory
            output_dir = Path.build_filename(parent_dir, "..", "mjai");
        }

        // Create output directory if it doesn't exist
        File out_dir = File.new_for_path(output_dir);
        if (!out_dir.query_exists())
        {
            out_dir.make_directory_with_parents();
            print("Created output directory: %s\n", output_dir);
        }

        // Generate output filename based on input filename
        string log_basename = Path.get_basename(log_path);
        string output_name = log_basename.replace(".log", ".json");
        string output_path = Path.build_filename(output_dir, output_name);

        // Convert to mjai format
        string mjai_json = convert_to_mjai(log);

        // Write output file
        File out_file = File.new_for_path(output_path);
        out_file.replace_contents(mjai_json.data, null, false, FileCreateFlags.NONE, null, null);

        print("Wrote mjai format to: %s\n", output_path);

    } catch (Error e) {
        stderr.printf("Error: %s\n", e.message);
    }
}

string convert_to_mjai(GameLog log)
{
    StringBuilder sb = new StringBuilder();

    GameLogRound[] rounds = log.rounds.to_array();

    for (int r = 0; r < rounds.length; r++)
    {
        GameLogRound round = rounds[r];
        Tile[] all_tiles = round.tiles.to_array();

        // Convert round to mjai messages
        convert_round_to_mjai(sb, round, all_tiles, r);
    }

    return sb.str;
}

void convert_round_to_mjai(StringBuilder sb, GameLogRound round, Tile[] all_tiles, int round_index)
{
    RoundStartInfo start_info = round.start_info;

    // Determine wind and kyoku
    int dealer = start_info.dealer;
    int kyoku = (round_index % 4) + 1;  // 1-4
    string bakaze = "E";  // Default to East round for now

    // Get dora marker tile
    int dora_marker_id = start_info.dead_wall_mark_tile_id;
    Tile? dora_marker_tile = null;
    foreach (Tile t in all_tiles)
    {
        if (t.ID == dora_marker_id)
        {
            dora_marker_tile = t;
            break;
        }
    }
    string dora_marker_str = dora_marker_tile != null ? tile_to_mjai(dora_marker_tile.tile_type) : "?";

    // Get initial hands
    SerializableList<Tile>[] hands = round.initial_hands.to_array();

    // Write start_kyoku message
    sb.append("{\"type\":\"start_kyoku\"");
    sb.append_printf(",\"bakaze\":\"%s\"", bakaze);
    sb.append_printf(",\"kyoku\":%d", kyoku);
    sb.append(",\"honba\":0");
    sb.append(",\"kyotaku\":0");
    sb.append_printf(",\"oya\":%d", dealer);
    sb.append_printf(",\"dora_marker\":\"%s\"", dora_marker_str);
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

            sb.append_printf("{\"type\":\"tsumo\",\"actor\":%d,\"pai\":\"%s\"}\n",
                           draw.player, tile_str);
        }
        else if (action is ClientServerAction)
        {
            ClientServerAction csa = action as ClientServerAction;
            ClientAction ca = csa.action;

            if (ca is TileDiscardClientAction)
            {
                TileDiscardClientAction discard = ca as TileDiscardClientAction;
                Tile? tile = find_tile(all_tiles, discard.tile);
                string tile_str = tile != null ? tile_to_mjai(tile.tile_type) : "?";

                sb.append_printf("{\"type\":\"dahai\",\"actor\":%d,\"pai\":\"%s\",\"tsumogiri\":false}\n",
                               csa.client, tile_str);
            }
            else if (ca is PonClientAction)
            {
                // Need to get the called tile and consumed tiles
                // This requires tracking the last discard
                sb.append_printf("{\"type\":\"pon\",\"actor\":%d}\n", csa.client);
            }
            else if (ca is ChiiClientAction)
            {
                ChiiClientAction chii = ca as ChiiClientAction;
                Tile? tile1 = find_tile(all_tiles, chii.tile_1);
                Tile? tile2 = find_tile(all_tiles, chii.tile_2);

                string tile1_str = tile1 != null ? tile_to_mjai(tile1.tile_type) : "?";
                string tile2_str = tile2 != null ? tile_to_mjai(tile2.tile_type) : "?";

                sb.append_printf("{\"type\":\"chi\",\"actor\":%d,\"consumed\":[\"%s\",\"%s\"]}\n",
                               csa.client, tile1_str, tile2_str);
            }
            else if (ca is OpenKanClientAction)
            {
                sb.append_printf("{\"type\":\"daiminkan\",\"actor\":%d}\n", csa.client);
            }
            else if (ca is LateKanClientAction)
            {
                LateKanClientAction kan = ca as LateKanClientAction;
                Tile? tile = find_tile(all_tiles, kan.tile);
                string tile_str = tile != null ? tile_to_mjai(tile.tile_type) : "?";

                sb.append_printf("{\"type\":\"kakan\",\"actor\":%d,\"pai\":\"%s\"}\n",
                               csa.client, tile_str);
            }
            else if (ca is ClosedKanClientAction)
            {
                ClosedKanClientAction kan = ca as ClosedKanClientAction;
                string tile_str = tile_to_mjai(kan.tile_type);

                sb.append_printf("{\"type\":\"ankan\",\"actor\":%d,\"consumed\":[\"%s\",\"%s\",\"%s\",\"%s\"]}\n",
                               csa.client, tile_str, tile_str, tile_str, tile_str);
            }
            else if (ca is RonClientAction)
            {
                sb.append_printf("{\"type\":\"hora\",\"actor\":%d}\n", csa.client);
            }
            else if (ca is TsumoClientAction)
            {
                sb.append_printf("{\"type\":\"hora\",\"actor\":%d}\n", csa.client);
            }
        }
    }

    // End kyoku
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

        case TileType.TON: return "E";
        case TileType.NAN: return "S";
        case TileType.SHAA: return "W";
        case TileType.PEI: return "N";
        case TileType.HAKU: return "P";
        case TileType.HATSU: return "F";
        case TileType.CHUN: return "C";

        default: return "?";
    }
}

} // namespace ConvertToMjai
