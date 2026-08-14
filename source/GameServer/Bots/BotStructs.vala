using Gee;

// Hand analysis statistics
public struct HandStatistics
{
    public int terminal_count;
    public int dragon_count;
    // 全局（hand + calls）来看，我就一张这样的幺九中发牌 打掉就基本废了，虽然你有 2 , 8 还是有希望吃到幺九的
    public TileType rare_dragon_terminal; // 幺九或者中发白的独苗
    public ArrayList<Tile> two_player_carry; // 为测试二人抬轿做准备
    public HashSet<TileType> hand_in_seq; // 手牌里 在顺子中的单个牌
    public ArrayList<TileType> singles;
    public ArrayList<TileType> singles_ish; // 不是对子刻子， 而且 12 但是 3 被碰  89 7 被碰， 不考虑其他太复杂的情况
    public int pair_count; // triplet not count in

    public int triplet_count;
    public int half_sequence_count_by_tile; // Tile相关半顺子数量
    public bool hasTerminalSeq;
    public bool hasTerminalTriplet;
    public int weighted_shanten; // 象那种没有幺九的， 我们得增加值表明难度加了
}

// Result of finding the best discard for tenpai
struct BestDiscardResult
{
    public Tile? tile;
    public int benefit;
}
