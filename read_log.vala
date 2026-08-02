using Engine;

namespace ReadLog {

void main(string[] args)
{
    if (args.length < 2)
    {
        print("Usage: read_log <log_file>\n");
        return;
    }

    // Initialize environment to register types
    Environment.init(false);

    string log_path = args[1];

    // Read the log file
    try {
        uint8[] data;
        File file = File.new_for_path(log_path);
        file.load_contents(null, out data, null);

        print("Loaded %d bytes\n", data.length);

        // First try to uncompress manually
        uint8[]? uncompressed = FileLoader.uncompress(data);
        if (uncompressed == null) {
            print("Failed to uncompress data\n");
            return;
        }
        print("Uncompressed to %d bytes\n", uncompressed.length);

        // Print first bytes as string to see type name
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 100 && i < uncompressed.length; i++) {
            if (uncompressed[i] >= 32 && uncompressed[i] < 127) {
                sb.append_c((char)uncompressed[i]);
            } else {
                sb.append_printf("[%02X]", uncompressed[i]);
            }
        }
        print("First bytes: %s\n", sb.str);

        // Deserialize directly from bytes (handles decompression internally)
        GameLog log = (GameLog?)Serializable.deserialize(data);

        if (log == null) {
            print("Failed to deserialize log\n");
            return;
        }

    print("Game Log:\n");
    print("  Version: %s\n", log.version.to_string());
    print("  Rounds: %d\n", log.rounds.to_array().length);
    print("  Human player: %d\n", log.human_player_index);
    print("\n");

    GameLogRound[] rounds = log.rounds.to_array();
    for (int r = 0; r < rounds.length; r++)
    {
        GameLogRound round = rounds[r];
        print("Round %d:\n", r + 1);
        print("  Tiles: %d\n", round.tiles.to_array().length);
        print("  Actions: %d\n", round.lines.to_array().length);

        // Print initial hands with tile types
        print("\n  Initial Hands:\n");
        SerializableList<Tile>[] hands = round.initial_hands.to_array();
        for (int p = 0; p < hands.length; p++)
        {
            Tile[] player_tiles = hands[p].to_array();
            print("    Player %d (%d tiles): ", p, player_tiles.length);
            for (int t = 0; t < player_tiles.length; t++)
            {
                if (t > 0) print(", ");
                print("%s", TILE_TYPE_TO_STRING(player_tiles[t].tile_type));
            }
            print("\n");
        }

        print("\n  Actions (Detailed):\n");
        GameLogLine[] lines = round.lines.to_array();

        // Helper function to get tile from ID
        Tile[] all_tiles = round.tiles.to_array();

        for (int i = 0; i < lines.length; i++)
        {
            GameLogLine line = lines[i];
            ServerAction action = line.action;

            if (action is TileDrawServerAction)
            {
                TileDrawServerAction draw = action as TileDrawServerAction;
                Tile? tile = null;
                foreach (Tile t in all_tiles)
                {
                    if (t.ID == draw.tile_ID) {
                        tile = t;
                        break;
                    }
                }
                string tile_str = tile != null ? TILE_TYPE_TO_STRING(tile.tile_type) : @"ID=$(draw.tile_ID)";
                print("    [%3d] TileDrawServerAction:\n", i);
                print("          Player %d draws tile %s (ID=%d) from the wall\n", draw.player, tile_str, draw.tile_ID);
            }
            else if (action is ClientServerAction)
            {
                ClientServerAction csa = action as ClientServerAction;
                ClientAction ca = csa.action;

                if (ca is TileDiscardClientAction)
                {
                    TileDiscardClientAction discard = ca as TileDiscardClientAction;
                    Tile? tile = null;
                    foreach (Tile t in all_tiles)
                    {
                        if (t.ID == discard.tile) {
                            tile = t;
                            break;
                        }
                    }
                    string tile_str = tile != null ? TILE_TYPE_TO_STRING(tile.tile_type) : @"ID=$(discard.tile)";
                    print("    [%3d] TileDiscardClientAction:\n", i);
                    print("          Player %d discards %s (ID=%d) to the pond\n", csa.client, tile_str, discard.tile);
                }
                else if (ca is NoCallClientAction)
                {
                    print("    [%3d] NoCallClientAction:\n", i);
                    print("          Player %d explicitly declines to call chi/pon/kan on the discarded tile\n", csa.client);
                }
                else if (ca is PonClientAction)
                {
                    print("    [%3d] PonClientAction:\n", i);
                    print("          Player %d calls PON - takes the last discarded tile + 2 matching tiles from hand\n", csa.client);
                    print("          Forms an open triplet (3 identical tiles)\n");
                }
                else if (ca is ChiiClientAction)
                {
                    ChiiClientAction chii = ca as ChiiClientAction;
                    Tile? tile1 = null;
                    Tile? tile2 = null;
                    foreach (Tile t in all_tiles)
                    {
                        if (t.ID == chii.tile_1) tile1 = t;
                        if (t.ID == chii.tile_2) tile2 = t;
                    }
                    string tile1_str = tile1 != null ? TILE_TYPE_TO_STRING(tile1.tile_type) : @"ID=$(chii.tile_1)";
                    string tile2_str = tile2 != null ? TILE_TYPE_TO_STRING(tile2.tile_type) : @"ID=$(chii.tile_2)";
                    print("    [%3d] ChiiClientAction:\n", i);
                    print("          Player %d calls CHI - takes the last discarded tile\n", csa.client);
                    print("          Uses %s (ID=%d) and %s (ID=%d) from hand\n", tile1_str, chii.tile_1, tile2_str, chii.tile_2);
                    print("          Forms an open sequence (3 consecutive tiles of same suit)\n");
                }
                else if (ca is OpenKanClientAction)
                {
                    print("    [%3d] OpenKanClientAction:\n", i);
                    print("          Player %d calls open KAN - takes the last discarded tile + 3 matching tiles from hand\n", csa.client);
                    print("          Forms an open quad (4 identical tiles), then draws from dead wall\n");
                }
                else if (ca is LateKanClientAction)
                {
                    LateKanClientAction kan = ca as LateKanClientAction;
                    Tile? tile = null;
                    foreach (Tile t in all_tiles)
                    {
                        if (t.ID == kan.tile) {
                            tile = t;
                            break;
                        }
                    }
                    string tile_str = tile != null ? TILE_TYPE_TO_STRING(tile.tile_type) : @"ID=$(kan.tile)";
                    print("    [%3d] LateKanClientAction:\n", i);
                    print("          Player %d calls late KAN on %s (ID=%d)\n", csa.client, tile_str, kan.tile);
                    print("          Adds 4th tile to an existing PON, then draws from dead wall\n");
                }
                else if (ca is ClosedKanClientAction)
                {
                    ClosedKanClientAction kan = ca as ClosedKanClientAction;
                    print("    [%3d] ClosedKanClientAction:\n", i);
                    print("          Player %d calls closed KAN on %s\n", csa.client, TILE_TYPE_TO_STRING(kan.tile_type));
                    print("          Declares 4 identical tiles from concealed hand, then draws from dead wall\n");
                }
                else if (ca is RonClientAction)
                {
                    print("    [%3d] RonClientAction:\n", i);
                    print("          Player %d declares RON - wins by calling the last discarded tile\n", csa.client);
                    print("          ROUND ENDS - winning hand completed\n");
                }
                else if (ca is TsumoClientAction)
                {
                    print("    [%3d] TsumoClientAction:\n", i);
                    print("          Player %d declares TSUMO - wins by self-draw\n", csa.client);
                    print("          ROUND ENDS - winning hand completed from own draw\n");
                }
                else
                {
                    string action_type = ca.get_type().name();
                    print("    [%3d] %s:\n", i, action_type);
                    print("          Player %d performs %s\n", csa.client, action_type);
                }
            }
            else
            {
                print("    [%3d] %s\n", i, action.get_type().name());
            }
        }
        print("\n");
    }
    } catch (Error e) {
        print("Error: %s\n", e.message);
    }
}

} // namespace ReadLog
