using Gee;

public void test_hands()
{
    PlayerStateContext player = new PlayerStateContext(
        3,
        new ArrayList<Tile>(), // Without the winning tile
        new ArrayList<Tile>(),
        new ArrayList<RoundStateCall>(), // calls
        Wind.NORTH,
        false,
        true,
        false,
        false,
        false,
        -1
    );

    RoundStateContext round = new RoundStateContext(
        Wind.EAST,
        new ArrayList<Tile>(),// dora
        new ArrayList<Tile>(),// ura_dora,
        true,
        new Tile(-1, TileType.PEI),
        false,
        false,
        false,
        true
    );

    ArrayList<Tile> tiles = new ArrayList<Tile>();
    tiles.add(new Tile(0, TileType.MAN9));
    tiles.add(new Tile(1, TileType.MAN8));
    tiles.add(new Tile(2, TileType.MAN7));
    tiles.add(new Tile(3, TileType.PIN8));
    tiles.add(new Tile(4, TileType.PIN7));
    tiles.add(new Tile(5, TileType.PIN9));
    tiles.add(new Tile(6, TileType.TON));
    tiles.add(new Tile(7, TileType.TON));
    tiles.add(new Tile(8, TileType.NAN));
    tiles.add(new Tile(9, TileType.NAN));
    tiles.add(new Tile(10, TileType.NAN));

    ArrayList<RoundStateCall> calls = new ArrayList<RoundStateCall>();

    ArrayList<Tile> chii_tiles = new ArrayList<Tile>();
    chii_tiles.add(new Tile(11, TileType.SOU9));
    chii_tiles.add(new Tile(12, TileType.SOU7));
    chii_tiles.add(new Tile(13, TileType.SOU8));

    calls.add(new RoundStateCall(RoundStateCall.CallType.CHII, chii_tiles, new Tile(13, TileType.SOU9), 1));

    stdout.printf("Calling TileRules.hand_readings with %d tiles and %d calls\n", tiles.size, calls.size);
    stdout.flush();

    // Changed from (true, true) to (false, false) to test a complete winning hand
    ArrayList<HandReading> readings = TileRules.hand_readings(tiles, calls, false, false);

    stdout.printf("Got %d readings\n", readings.size);
    stdout.flush();

    foreach (var reading in readings)
    {
        print(reading.to_string() + "\n");
        print("-----------------\n");

        foreach (Yaku yaku in Yaku.get_yaku(player, round, reading))
        {
            print(yaku.to_string() + "\n");
        }
    }

    stdout.printf("Test completed with %d readings\n", readings.size);
    stdout.flush();
}