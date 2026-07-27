using Gee;

public void hands1()
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
    }

    stdout.printf("Test completed with %d readings\n", readings.size);
    stdout.flush();
}

// 断幺九，应该胡不了
public void hands2()
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
        true,
        new Tile(-1, TileType.PEI),
        false,
        false,
        false,
        true
    );

    ArrayList<Tile> tiles = new ArrayList<Tile>();
    tiles.add(new Tile(1, TileType.MAN6));
    tiles.add(new Tile(0, TileType.MAN5));
    tiles.add(new Tile(2, TileType.MAN7));
    tiles.add(new Tile(3, TileType.PIN8));
    tiles.add(new Tile(4, TileType.PIN7));
    tiles.add(new Tile(5, TileType.PIN6));
    tiles.add(new Tile(6, TileType.PIN4));
    tiles.add(new Tile(7, TileType.PIN4));
    tiles.add(new Tile(8, TileType.PIN3));
    tiles.add(new Tile(9, TileType.PIN3));
    tiles.add(new Tile(10, TileType.PIN3));

    ArrayList<RoundStateCall> calls = new ArrayList<RoundStateCall>();

    ArrayList<Tile> chii_tiles = new ArrayList<Tile>();
    chii_tiles.add(new Tile(11, TileType.SOU6));
    chii_tiles.add(new Tile(12, TileType.SOU7));
    chii_tiles.add(new Tile(13, TileType.SOU8));

    calls.add(new RoundStateCall(RoundStateCall.CallType.CHII, chii_tiles, new Tile(13, TileType.SOU6), 1));

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
    }

    stdout.printf("Test completed with %d readings\n", readings.size);
    stdout.flush();
}

// 清一色，应该胡不了
public void hands3()
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
        true,
        new Tile(-1, TileType.PEI),
        false,
        false,
        false,
        true
    );

    ArrayList<Tile> tiles = new ArrayList<Tile>();
    tiles.add(new Tile(1, TileType.MAN1));
    tiles.add(new Tile(0, TileType.MAN2));
    tiles.add(new Tile(2, TileType.MAN3));
    tiles.add(new Tile(3, TileType.MAN1));
    tiles.add(new Tile(4, TileType.MAN2));
    tiles.add(new Tile(5, TileType.MAN3));
    tiles.add(new Tile(6, TileType.MAN4));
    tiles.add(new Tile(7, TileType.MAN4));
    tiles.add(new Tile(8, TileType.MAN7));
    tiles.add(new Tile(9, TileType.MAN8));
    tiles.add(new Tile(10, TileType.MAN9));

    ArrayList<RoundStateCall> calls = new ArrayList<RoundStateCall>();

    ArrayList<Tile> chii_tiles = new ArrayList<Tile>();
    chii_tiles.add(new Tile(11, TileType.MAN5));
    chii_tiles.add(new Tile(12, TileType.MAN6));
    chii_tiles.add(new Tile(13, TileType.MAN7));

    calls.add(new RoundStateCall(RoundStateCall.CallType.CHII, chii_tiles, new Tile(13, TileType.MAN6), 1));

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
    }

    stdout.printf("Test completed with %d readings\n", readings.size);
    stdout.flush();
}
// 混一色，应该胡不了
public void hands4()
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
        true,
        new Tile(-1, TileType.PEI),
        false,
        false,
        false,
        true
    );

    ArrayList<Tile> tiles = new ArrayList<Tile>();
    tiles.add(new Tile(1, TileType.MAN1));
    tiles.add(new Tile(0, TileType.MAN2));
    tiles.add(new Tile(2, TileType.MAN3));
    tiles.add(new Tile(3, TileType.MAN1));
    tiles.add(new Tile(4, TileType.MAN2));
    tiles.add(new Tile(5, TileType.MAN3));
    tiles.add(new Tile(6, TileType.HATSU));
    tiles.add(new Tile(7, TileType.HATSU));
    tiles.add(new Tile(8, TileType.MAN9));
    tiles.add(new Tile(9, TileType.MAN9));
    tiles.add(new Tile(10, TileType.MAN9));

    ArrayList<RoundStateCall> calls = new ArrayList<RoundStateCall>();

    ArrayList<Tile> chii_tiles = new ArrayList<Tile>();
    chii_tiles.add(new Tile(11, TileType.MAN5));
    chii_tiles.add(new Tile(12, TileType.MAN6));
    chii_tiles.add(new Tile(13, TileType.MAN7));

    calls.add(new RoundStateCall(RoundStateCall.CallType.CHII, chii_tiles, new Tile(13, TileType.MAN6), 1));

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
    }

    stdout.printf("Test completed with %d readings\n", readings.size);
    stdout.flush();
}

// 手中只剩两张牌，废掉了
public void hands5()
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
        true,
        new Tile(-1, TileType.PEI),
        false,
        false,
        false,
        true
    );

    ArrayList<Tile> tiles = new ArrayList<Tile>();
  
    tiles.add(new Tile(6, TileType.SOU1));
    tiles.add(new Tile(7, TileType.SOU1));
   

    ArrayList<RoundStateCall> calls = new ArrayList<RoundStateCall>();

    ArrayList<Tile> chii_tiles1 = new ArrayList<Tile>();
    chii_tiles1.add(new Tile(11, TileType.MAN5));
    chii_tiles1.add(new Tile(12, TileType.MAN6));
    chii_tiles1.add(new Tile(13, TileType.MAN7));
    calls.add(new RoundStateCall(RoundStateCall.CallType.CHII, chii_tiles1, new Tile(13, TileType.MAN6), 1));
    ArrayList<Tile> chii_tiles2 = new ArrayList<Tile>();
    chii_tiles2.add(new Tile(1, TileType.MAN1));
    chii_tiles2.add(new Tile(0, TileType.MAN2));
    chii_tiles2.add(new Tile(2, TileType.MAN3));
    calls.add(new RoundStateCall(RoundStateCall.CallType.CHII, chii_tiles2, new Tile(0, TileType.MAN2), 1));
    ArrayList<Tile> chii_tiles3 = new ArrayList<Tile>();
    chii_tiles3.add(new Tile(3, TileType.MAN1));
    chii_tiles3.add(new Tile(4, TileType.MAN2));
    chii_tiles3.add(new Tile(5, TileType.MAN3));
    calls.add(new RoundStateCall(RoundStateCall.CallType.CHII, chii_tiles3, new Tile(4, TileType.MAN2), 1));
    ArrayList<Tile> pon1 = new ArrayList<Tile>();
    pon1.add(new Tile(8, TileType.MAN9));
    pon1.add(new Tile(9, TileType.MAN9));
    pon1.add(new Tile(10, TileType.MAN9));
    calls.add(new RoundStateCall(RoundStateCall.CallType.PON, pon1, new Tile(8, TileType.MAN9), 1));

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
    }

    stdout.printf("Test completed with %d readings\n", readings.size);
    stdout.flush();
}

// 杠出来一张好牌，注意这种情况 readings 是有的， 我们必须在别的地方补充判断，而不是修改 hand_readings
public void hands6()
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
        true,
        new Tile(-1, TileType.PEI),
        false,
        true, // 刚杠完
        false,
        true
    );

    ArrayList<Tile> tiles = new ArrayList<Tile>();
  
    tiles.add(new Tile(6, TileType.SOU1));
    tiles.add(new Tile(7, TileType.SOU1));
    tiles.add(new Tile(3, TileType.MAN1));
    tiles.add(new Tile(4, TileType.MAN2));
    tiles.add(new Tile(5, TileType.MAN3));

    ArrayList<RoundStateCall> calls = new ArrayList<RoundStateCall>();

    ArrayList<Tile> chii_tiles1 = new ArrayList<Tile>();
    chii_tiles1.add(new Tile(11, TileType.MAN5));
    chii_tiles1.add(new Tile(12, TileType.MAN6));
    chii_tiles1.add(new Tile(13, TileType.MAN7));
    calls.add(new RoundStateCall(RoundStateCall.CallType.CHII, chii_tiles1, new Tile(13, TileType.MAN6), 1));
    ArrayList<Tile> chii_tiles2 = new ArrayList<Tile>();
    chii_tiles2.add(new Tile(1, TileType.MAN1));
    chii_tiles2.add(new Tile(0, TileType.MAN2));
    chii_tiles2.add(new Tile(2, TileType.MAN3));
    calls.add(new RoundStateCall(RoundStateCall.CallType.CHII, chii_tiles2, new Tile(0, TileType.MAN2), 1));
   
    ArrayList<Tile> kan= new ArrayList<Tile>();
    kan.add(new Tile(8, TileType.MAN9));
    kan.add(new Tile(9, TileType.MAN9));
    kan.add(new Tile(10, TileType.MAN9));
    kan.add(new Tile(15, TileType.MAN9));
    calls.add(new RoundStateCall(RoundStateCall.CallType.LATE_KAN, kan, new Tile(8, TileType.MAN9), 1));

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
    }

    stdout.printf("Test completed with %d readings\n", readings.size);
    stdout.flush();
}
public void test_hands()
{
    //  hands1(); // has readings
    //  hands2(); // no terminal or honor
    //  hands3(); // 清一色，应该胡不了
    //  hands4(); // 混一色，应该胡不了
    //  hands5(); // 手中只剩两张牌，废掉了
    hands6(); // 杠出来一张好牌，注意这种情况 readings 是有的， 我们必须在别的地方补充判断，而不是修改 hand_readings 
}