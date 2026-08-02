using Engine;

public class GameLog : Serializable
{
    private GameLogRound? round;

    public GameLog(VersionInfo version, GameStartInfo start_info, ServerSettings settings)
    {
        this.version = version;
        this.start_info = start_info;
        this.settings = settings;
        this.human_player_index = -1;  // Default: no human player (all bots)
        rounds = new SerializableList<GameLogRound>.empty();
    }

    public static GameLog from_log(string log)
    {
        return (GameLog)Serializable.deserialize_string(log);
    }

    private void add_round(GameLogRound round)
    {
        GameLogRound[] r = rounds.to_array();

        GameLogRound[] rounds = new GameLogRound[r.length + 1];
        for (int i = 0; i < r.length; i++)
            rounds[i] = r[i];

        rounds[r.length] = round;

        this.rounds = new SerializableList<GameLogRound>(rounds);
    }

    public void start_round(RoundStartInfo info, Tile[] tiles, SerializableList<SerializableList<Tile>>? initial_hands)
    {
        if (round != null)
            end_round();

        round = new GameLogRound(info, tiles, initial_hands);
        add_round(round);
    }

    public void update_current_round_initial_hands(SerializableList<SerializableList<Tile>> initial_hands)
    {
        if (round != null)
            round.initial_hands = initial_hands;
    }

    public void set_round_result(int[] transfers, RoundResultType result_type)
    {
        if (round != null)
            round.set_result(transfers, result_type);
    }

    public void end_round()
    {
        if (round == null)
            return;

        round = null;
    }

    public void add_line(GameLogLine line)
    {
        if (round == null)
            return;

        round.add_line(line);
    }

    public VersionInfo version { get; protected set; }
    public GameStartInfo start_info { get; protected set; }
    public ServerSettings settings { get; protected set; }
    public SerializableList<GameLogRound> rounds { get; protected set; }
    public int human_player_index { get; set; }  // -1 = no human (all bots), 0-3 = seat of human player
}

public class GameLogRound : Serializable
{
    public GameLogRound(RoundStartInfo info, Tile[]? tiles, SerializableList<SerializableList<Tile>>? initial_hands)
    {
        start_info = info;
        this.tiles = new SerializableList<Tile>(tiles);
        lines = new SerializableList<GameLogLine>.empty();

        // Save initial hands (13 tiles per player)
        if (initial_hands != null)
        {
            this.initial_hands = initial_hands;
        }
        else
        {
            // Empty hands for backwards compatibility
            SerializableList<Tile>[] empty_hands = new SerializableList<Tile>[4];
            for (int i = 0; i < 4; i++)
            {
                empty_hands[i] = new SerializableList<Tile>.empty();
            }
            this.initial_hands = new SerializableList<SerializableList<Tile>>(empty_hands);
        }

        // Initialize with zero transfers (will be set when round finishes)
        transfer_p0 = 0;
        transfer_p1 = 0;
        transfer_p2 = 0;
        transfer_p3 = 0;
        result_type = RoundResultType.NONE;
    }

    public void add_line(GameLogLine line)
    {
        GameLogLine[] l = lines.to_array();

        GameLogLine[] lines = new GameLogLine[l.length + 1];
        for (int i = 0; i < l.length; i++)
            lines[i] = l[i];

        lines[l.length] = line;

        this.lines = new SerializableList<GameLogLine>(lines);
    }

    public void set_result(int[] transfers, RoundResultType result_type)
    {
        this.transfer_p0 = transfers.length > 0 ? transfers[0] : 0;
        this.transfer_p1 = transfers.length > 1 ? transfers[1] : 0;
        this.transfer_p2 = transfers.length > 2 ? transfers[2] : 0;
        this.transfer_p3 = transfers.length > 3 ? transfers[3] : 0;
        this.result_type = result_type;
    }

    public RoundStartInfo start_info { get; protected set; }
    public SerializableList<Tile> tiles { get; protected set; }
    public SerializableList<SerializableList<Tile>> initial_hands { get; set; }
    public SerializableList<GameLogLine> lines { get; protected set; }

    // Store score transfers as individual fields to avoid SerializableList<int> serialization issues
    public int transfer_p0 { get; set; }
    public int transfer_p1 { get; set; }
    public int transfer_p2 { get; set; }
    public int transfer_p3 { get; set; }
    public RoundResultType result_type { get; set; }
}

public enum RoundResultType
{
    NONE,
    RON,
    TSUMO,
    DRAW
}

public class GameLogLine : Serializable
{
    public GameLogLine(float delta, ServerAction action)
    {
        this.delta = delta;
        this.action = action;
    }

    public float delta { get; protected set; }
    public ServerAction action { get; protected set; }
}