using Gee;
using Engine;

/**
 * ShantenCalculator - Calculates shanten numbers using pre-computed lookup tables
 *
 * Shanten number = minimum number of tile draws needed to reach tenpai (ready hand)
 * Returns shanten + 1, so: 0 = -1 shanten (winning hand), 1 = tenpai, 2 = 1-shanten, etc.
 *
 * Based on the algorithm from https://github.com/tomohxx/shanten-number
 */
class ShantenCalculator
{
    private static ShantenCalculator? instance = null;
    private uint8[]? index_h = null;  // Honor/pair lookup table (78125 entries, 10 bytes each)
    private uint8[]? index_s = null;  // Sequence lookup table (1953125 entries, 10 bytes each)

    private const int NUM_TILE_TYPES = 34;
    private const int LOOKUP_SIZE = 10;  // Each lookup entry is 10 bytes

    /**
     * The 10-byte lookup structure explained:
     *
     * The index tells you the CURRENT hand state:
     * - Indices [0-4]: How many complete melds you have, NO PAIR yet
     * - Indices [5-9]: How many complete melds you have, HAS PAIR
     *
     * The value tells you the SHANTEN NUMBER (distance to tenpai):
     * - How many more useful tiles you need to draw to reach tenpai
     *
     * SIMPLE ANALOGY:
     * Think of building a winning hand like filling 5 slots:
     *   [Meld 1] [Meld 2] [Meld 3] [Meld 4] [Pair]
     *
     * Index 5 means: You filled the [Pair] slot, but none of the meld slots
     * Value 6 means: You need 6 more "progress points" to fill the remaining slots
     *
     * Index 9 means: You filled all 5 slots = WINNING HAND
     * Value 0 means: Shanten = 0 (already at tenpai or winning)
     *
     * WHY the specific numbers?
     * - Each meld you complete reduces shanten by ~2
     * - Each "proto-meld" (like 45 waiting for 3 or 6) reduces by ~1
     * - Having a pair when you need one saves you ~2 shanten
     *
     * Indices [0-4]: Shanten values when you have 0-4 complete melds, NO PAIR
     *   - ret[0] = 8  (0 melds, no pair: need everything)
     *   - ret[1] = 6  (1 meld, no pair: need 3 more melds + pair)
     *   - ret[2] = 4  (2 melds, no pair: need 2 more melds + pair)
     *   - ret[3] = 2  (3 melds, no pair: need 1 more meld + pair)
     *   - ret[4] = 0  (4 melds, no pair: rare/invalid situation)
     *
     * Indices [5-9]: Shanten values when you have 0-4 complete melds, HAS PAIR
     *   - ret[5] = 6  (0 melds + pair: need 4 melds)
     *   - ret[6] = 4  (1 meld + pair: need 3 more melds)
     *   - ret[7] = 2  (2 melds + pair: need 2 more melds)
     *   - ret[8] = 0  (3 melds + pair: need 1 more meld to complete)
     *   - ret[9] = 0  (4 melds + pair: WINNING HAND)
     *
     * ===== CRITICAL: Understanding the 'm' parameter =====
     *
     * 'm' represents the TARGET number of melds we want to form from the tiles being analyzed.
     *
     * KEY INSIGHT: We hash ONLY the closed hand tiles (not open call tiles).
     *              The 'm' parameter tells the lookup table how many melds we want to form
     *              from those closed tiles.
     *
     * HOW 'm' IS CALCULATED:
     *   m = (number of closed hand tiles) / 3
     *
     * EXAMPLES:
     *
     * Example 1: No open calls, 14 tiles in hand
     *   - Closed hand: 14 tiles
     *   - m = 14 / 3 = 4 (we want to form 4 melds + pair from the 14 tiles)
     *   - We look up: ret[4 + 5] = ret[9]
     *   - Meaning: "Form 4 melds + pair from these 14 tiles" = winning structure
     *
     * Example 2: Called 1 pon (3 tiles revealed), 11 tiles in hand
     *   - Closed hand: 11 tiles (we DON'T count the pon tiles)
     *   - Open calls: 1 pon (already a complete meld)
     *   - m = 11 / 3 = 3 (we want to form 3 melds + pair from the 11 closed tiles)
     *   - We look up: ret[3 + 5] = ret[8]
     *   - Meaning: "Form 3 melds + pair from closed hand" + 1 open pon = 4 total melds + pair
     *
     * Example 3: Called 2 pon (6 tiles revealed), 8 tiles in hand
     *   - Closed hand: 8 tiles
     *   - Open calls: 2 pon (2 complete melds)
     *   - m = 8 / 3 = 2 (we want to form 2 melds + pair from the 8 closed tiles)
     *   - We look up: ret[2 + 5] = ret[7]
     *   - Meaning: "Form 2 melds + pair from closed hand" + 2 open pon = 4 total melds + pair
     *
     * WHY THIS WORKS:
     *   A winning hand needs: 4 melds + 1 pair
     *   If you have C open calls (each = 1 meld), you need (4 - C) more melds from closed hand
     *   Closed tiles = 14 - 3*C
     *   m = (14 - 3*C) / 3 = 4 - C
     *   Check ret[m + 5] = ret[(4-C) + 5] = ret[9 - C]
     *
     * ALTERNATIVE VIEW (equivalent formula):
     *   ret[m + 5] = ret[9 - number_of_open_calls]
     *   This is mathematically equivalent, but conceptually 'm' represents
     *   "target melds from the tiles we're querying", not "open calls we have".
     *
     * THE ALGORITHM:
     * 1. Count only closed hand tiles (exclude open call tiles)
     * 2. Hash those closed tiles to get a lookup index
     * 3. Calculate m = closed_tiles / 3 (target melds from closed hand)
     * 4. Look up ret[m + 5] (target m melds + has pair)
     * 5. The value tells us: "minimum tiles needed to form m melds + pair from closed hand"
     * 6. Total winning structure = m (from closed) + open_calls = 4 melds + pair
     */

    // Table sizes for hash calculations
    private const int TABLE_S_SIZE = 1953125;  // 5^9 for suited tiles (9 types per suit)
    private const int TABLE_H_SIZE = 78125;    // 5^7 for honor tiles (7 types)

    private ShantenCalculator()
    {
        load_tables();
    }

    public static ShantenCalculator get_instance()
    {
        if (instance == null)
            instance = new ShantenCalculator();
        return instance;
    }

    private void load_tables()
    {
        // Load the binary lookup tables from Data/Shanten
        string index_h_path = GLib.Path.build_filename("Data", "Shanten", "index_h.bin");
        string index_s_path = GLib.Path.build_filename("Data", "Shanten", "index_s.bin");

        string? h_file = FileLoader.find_file(index_h_path);
        string? s_file = FileLoader.find_file(index_s_path);

        if (h_file != null)
        {
            index_h = FileLoader.load_data(index_h_path);
            if (index_h != null)
                Environment.log(LogType.DEBUG, "ShantenCalculator",
                    @"Loaded index_h.bin: $(index_h.length) bytes");
            else
                Environment.log(LogType.ERROR, "ShantenCalculator",
                    "Failed to load index_h.bin data");
        }
        else
        {
            Environment.log(LogType.ERROR, "ShantenCalculator",
                @"Could not find index_h.bin at: $index_h_path");
        }

        if (s_file != null)
        {
            index_s = FileLoader.load_data(index_s_path);
            if (index_s != null)
                Environment.log(LogType.DEBUG, "ShantenCalculator",
                    @"Loaded index_s.bin: $(index_s.length) bytes");
            else
                Environment.log(LogType.ERROR, "ShantenCalculator",
                    "Failed to load index_s.bin data");
        }
        else
        {
            Environment.log(LogType.ERROR, "ShantenCalculator",
                @"Could not find index_s.bin at: $index_s_path");
        }
    }

    /**
     * Calculate hash index for a 9-tile sequence (one suit)
     * Uses base-5 encoding: index = t[0] + 5*t[1] + 25*t[2] + ... + 5^8*t[8]
     */
    private int hash9(int[] tiles, int offset)
    {
        int hash = tiles[offset];
        int multiplier = 5;
        for (int i = 1; i < 9; i++)
        {
            hash += tiles[offset + i] * multiplier;
            multiplier *= 5;
        }
        return hash;
    }

    /**
     * Calculate hash index for 7 honor tiles
     * Uses base-5 encoding: index = t[0] + 5*t[1] + 25*t[2] + ... + 5^6*t[6]
     */
    private int hash7(int[] tiles, int offset)
    {
        int hash = tiles[offset];
        int multiplier = 5;
        for (int i = 1; i < 7; i++)
        {
            hash += tiles[offset + i] * multiplier;
            multiplier *= 5;
        }
        return hash;
    }

    /**
     * Get lookup value from table
     * @param table The lookup table (index_s or index_h)
     * @param hash The hash index
     * @param idx The index within the 10-byte entry (0-9)
     */
    private uint8 get_table_value(uint8[] table, int hash, int idx)
    {
        int offset = hash * LOOKUP_SIZE + idx;
        if (offset >= table.length)
            return 14;  // Max shanten value
        return table[offset];
    }

    /**
     * Add operation for combining suit results
     * Implements the add1 function from calsht.cpp
     *
     * This is the core DP algorithm that combines shanten calculations from different suits.
     *
     * @param lhs Left-hand side: Accumulated shanten results so far (modified in-place)
     *            Each index represents: [0-4] = number of complete melds, [5-9] = melds + has pair
     *            Example: lhs[0] = shanten with 0 melds and no pair
     *                     lhs[5] = shanten with 0 melds but has a pair
     *                     lhs[6] = shanten with 1 meld and has a pair
     *
     * @param rhs Right-hand side: Shanten results for the current suit being added
     *            Same 10-byte structure as lhs
     *
     * @param m Target number of melds we want to form from closed hand
     *          This is calculated as: m = closed_tiles / 3
     *          Example: 11 closed tiles → m = 3 (we want 3 melds + pair from those 11 tiles)
     *
     * The algorithm combines results by trying all ways to distribute melds between
     * the accumulated results (lhs) and the new suit (rhs), keeping the minimum.
     *
     * WHY do we need 'm'?
     * Because we only compute up to index m+5 (not all 10 indices).
     * If we have open calls, we don't need to compute impossible states.
     * Example: 1 open call → 11 closed tiles → m=3
     *          We only care about ret[8] = "3 melds + pair from closed hand"
     *          Computing ret[9] would mean "4 melds + pair from 11 tiles" which is impossible!
     */
    private void add1(uint8[] lhs, uint8[] rhs, int m)
    {
        // Process indices from m+5 down to 5
        // These represent states with a pair (index >= 5 means "has pair")
        for (int j = m + 5; j >= 5; j--)
        {
            // Try combining: all melds from lhs + no melds from rhs, or vice versa
            // IMPORTANT: Use int for intermediate calculations to avoid uint8 overflow!
            int sht = int.min((int)lhs[j] + (int)rhs[0], (int)lhs[0] + (int)rhs[j]);

            // Try all ways to split melds between lhs and rhs
            // k melds from lhs, (j-k) melds from rhs
            for (int k = 5; k < j; k++)
            {
                int val1 = (int)lhs[k] + (int)rhs[j - k];
                int val2 = (int)lhs[j - k] + (int)rhs[k];
                sht = int.min(sht, int.min(val1, val2));
            }

            lhs[j] = (uint8)sht;  // Store the best result back into lhs
        }

        // Process indices from m down to 0
        // These represent states without a pair (index < 5)
        for (int j = m; j >= 0; j--)
        {
            // Start with: all melds from lhs, none from rhs
            // IMPORTANT: Use int for intermediate calculations to avoid uint8 overflow!
            int sht = (int)lhs[j] + (int)rhs[0];

            // Try all ways to distribute melds
            for (int k = 0; k < j; k++)
            {
                sht = int.min(sht, (int)lhs[k] + (int)rhs[j - k]);
            }

            lhs[j] = (uint8)sht;  // Store the best result back into lhs
        }
    }

    /**
     * Add operation for the final suit (simplified version)
     * Implements the add2 function from calsht.cpp
     *
     * This is used only for the last suit (Man tiles) because we know exactly
     * how many melds we need (m), so we only compute one specific index (m+5).
     *
     * @param lhs Accumulated shanten results (modified in-place)
     * @param rhs Shanten results for the final suit (Man tiles)
     * @param m Target number of melds from closed hand (m = closed_tiles / 3)
     *          Example: 11 closed tiles → m = 3
     *
     * We only care about index [m+5] which represents:
     * "m complete melds + 1 pair from closed hand"
     *
     * Total winning structure: m (closed) + open_calls = 4 melds + 1 pair
     * Example: m=3 with 1 open call → 3 + 1 = 4 melds + pair ✓
     */
    private void add2(uint8[] lhs, uint8[] rhs, int m)
    {
        int j = m + 5;  // Target index: m melds + has pair (index 5 offset)

        // Try: all melds from lhs + none from rhs, or vice versa
        // IMPORTANT: Use int for intermediate calculations to avoid uint8 overflow!
        int sht = int.min((int)lhs[j] + (int)rhs[0], (int)lhs[0] + (int)rhs[j]);

        // Try all ways to distribute the m melds between lhs and rhs
        for (int k = 5; k < j; k++)
        {
            int val1 = (int)lhs[k] + (int)rhs[j - k];
            int val2 = (int)lhs[j - k] + (int)rhs[k];
            sht = int.min(sht, int.min(val1, val2));
        }

        lhs[j] = (uint8)sht;  // Store the final result
    }

    /**
     * Calculate shanten number for a hand
     * @param hand Array of tiles (can be unsorted)
     * @param calls Open melds (pon/chii/kan)
     * @return Shanten number + 1 (0 = winning, 1 = tenpai, 2 = 1-shanten, etc.)
     *         Returns -1 if tables not loaded
     */
    public int calculate_shanten(ArrayList<Tile> hand, ArrayList<RoundStateCall> calls)
    {
        if (index_h == null || index_s == null)
        {
            Environment.log(LogType.ERROR, "ShantenCalculator",
                "Lookup tables not loaded, cannot calculate shanten");
            return -1;
        }

        // Convert hand to tile count array (standard format for shanten calculation)
        int[] tile_counts = new int[NUM_TILE_TYPES];
        for (int i = 0; i < NUM_TILE_TYPES; i++)
            tile_counts[i] = 0;

        // Count tiles in hand
        foreach (Tile tile in hand)
        {
            // TileType starts at BLANK=0, MAN1=1, so we subtract 1
            int index = (int)tile.tile_type - 1;
            if (index >= 0 && index < NUM_TILE_TYPES)
                tile_counts[index]++;
        }

        // ===== CRITICAL: We do NOT count tiles in calls here! =====
        // The open call tiles (from pon/chii/kan) are NOT included in tile_counts.
        // We only hash and calculate shanten for the CLOSED HAND tiles.
        //
        // WHY? Because:
        // 1. The lookup tables are pre-computed for any tile combination
        // 2. We tell the table "form m melds from these closed tiles"
        // 3. Then we account for open calls: total = m (closed) + open_calls = 4 melds + pair

        // Calculate total closed tiles to determine target meld count
        int total_tiles = 0;
        for (int i = 0; i < NUM_TILE_TYPES; i++)
            total_tiles += tile_counts[i];

        // ===== Understanding 'm' =====
        // m = target number of melds we want to form from the CLOSED hand tiles
        //
        // Formula: m = total_closed_tiles / 3
        //
        // Examples:
        //   No open calls: 14 tiles → m = 14/3 = 4 (need 4 melds + pair from 14 tiles)
        //   1 open call:   11 tiles → m = 11/3 = 3 (need 3 melds + pair from 11 tiles)
        //   2 open calls:   8 tiles → m =  8/3 = 2 (need 2 melds + pair from 8 tiles)
        //   3 open calls:   5 tiles → m =  5/3 = 1 (need 1 meld + pair from 5 tiles)
        //
        // The lookup table will return ret[m+5], which means:
        //   "Shanten for forming m melds + pair from the closed tiles"
        //
        // Total winning structure: m (closed) + open_calls = 4 melds + pair
        int m = total_tiles / 3;

        // Calculate shanten for standard form (4 melds + 1 pair)
        int shanten_lh = calc_lh(tile_counts, m);

        // Calculate shanten for seven pairs (only if no open melds)
        //  int shanten_sp = (num_melds == 0) ? calc_sp(tile_counts) : 100;

        // Calculate shanten for thirteen orphans (only if no open melds)
        //  int shanten_to = (num_melds == 0) ? calc_to(tile_counts) : 100;

        // Return minimum shanten
        //  int min_shanten = shanten_lh;
        //  if (shanten_sp < min_shanten)
        //      min_shanten = shanten_sp;
        //  if (shanten_to < min_shanten)
        //      min_shanten = shanten_to;

        return shanten_lh;
    }

    /**
     * Calculate shanten for regular hand (4 melds + 1 pair)
     * Implements calc_lh from calsht.cpp
     *
     * The algorithm works by:
     * 1. Starting with honor tiles lookup (7 tiles: East/South/West/North/White/Green/Red)
     * 2. Adding Sou (索子/bamboo) results (9 tiles: 1s-9s)
     * 3. Adding Pin (筒子/dots) results (9 tiles: 1p-9p)
     * 4. Adding Man (万子/characters) results (9 tiles: 1m-9m)
     *
     * Each "add" operation uses DP to find the best way to combine melds
     * from different suits to achieve the target of 4 melds + 1 pair.
     *
     * CONCRETE EXAMPLES of what ret[] looks like:
     *
     * EXAMPLE 1: Empty hand (no tiles at all)
     * After honor lookup: ret = [8, 6, 4, 2, 0, 6, 4, 2, 0, 0]
     *
     *   INDEX 5 EXPLAINED: ret[5] = 6
     *   - Index 5 means: 0 complete melds + HAS a pair
     *   - Value 6 means: shanten = 6 (need 6 tile changes to reach tenpai)
     *
     *   Why 6? To win you need 4 melds + 1 pair.
     *   If you have a pair but 0 melds:
     *   - Need to form 4 melds (12 tiles worth of combinations)
     *   - But shanten counts "tile efficiency" not raw tiles
     *   - Forming 1 meld reduces shanten by ~2 (because you're making progress on 2 fronts)
     *   - So: 4 melds needed × ~1.5 efficiency = 6 shanten
     *
     *   Full breakdown of ret array for empty hand:
     *   ret[0] = 8  (0 melds, no pair: need everything = 8-shanten)
     *   ret[1] = 6  (1 meld, no pair: need 3 melds + pair)
     *   ret[2] = 4  (2 melds, no pair: need 2 melds + pair)
     *   ret[3] = 2  (3 melds, no pair: need 1 meld + pair)
     *   ret[4] = 0  (4 melds, no pair: technically complete but invalid)
     *   ret[5] = 6  (0 melds + pair: need 4 melds = 6-shanten)
     *   ret[6] = 4  (1 meld + pair: need 3 melds = 4-shanten)
     *   ret[7] = 2  (2 melds + pair: need 2 melds = 2-shanten)
     *   ret[8] = 0  (3 melds + pair: need 1 meld = 0-shanten, but wait...?)
     *   ret[9] = 0  (4 melds + pair: WINNING HAND, 0-shanten)
     *
     *   Note: ret[8] = 0 seems wrong (should be tenpai = 1), but the algorithm
     *   actually uses ret[m+5] where m=number of complete melds, so we never
     *   directly read ret[8] for a hand with exactly 3 melds.
     *
     * EXAMPLE 2: One complete sequence (e.g., 123m only)
     * After combining Man suit:
     *   ret[0] = 6  (the 123m can become 1 meld, need 3 more + pair = 6 tiles)
     *   ret[1] = 4  (have 1 meld from 123m, need 2 more + pair = 4 tiles)
     *   ret[5] = 4  (the 123m forms 1 meld, need 3 more melds = 6 tiles... with pair = 4)
     *   ret[6] = 2  (1 meld from 123m + has pair, need 2 more melds = 4 tiles)
     *
     * EXAMPLE 3: Perfect tenpai hand (123m 456m 789m 11p 33p, waiting for 3p)
     * After combining all suits:
     *   ret[5] = 1  (shanten = 1, because we're 1 tile away from 4 melds + pair)
     *   Return ret[m+5] = ret[0+5] = ret[5] = 1 (tenpai = 1 shanten)
     *
     * EXAMPLE 4: Winning hand (123m 456m 789m 11p 333p)
     * After combining all suits:
     *   ret[5] = 0  (shanten = 0, we already have 4 melds + pair)
     *   Return ret[m+5] = ret[0+5] = ret[5] = 0 (winning = 0 shanten)
     *
     * EXAMPLE 5: 2-shanten hand (123m 45m 11p 33p 5s 7s)
     * After combining:
     *   ret[5] = 2  (need 2 more tiles to reach tenpai)
     *   Have: 1 sequence (123m), 1 proto-sequence (45m), 2 pairs
     *   Need: complete 45m -> 456m, and form one more meld
     *
     * The key insight: ret[m+5] gives the minimum tiles needed to reach tenpai
     * when you already have m complete melds from open calls.
     *
     * @param tiles Tile count array [0-33]
     * @param m Target number of melds to form from the closed hand tiles
     *          Calculated as: m = (number of closed tiles) / 3
     *
     *          Examples with concrete numbers:
     *          - No open calls: 14 closed tiles → m = 14/3 = 4
     *            We need 4 melds + pair from closed hand = winning structure
     *            Look up ret[4+5] = ret[9]
     *
     *          - 1 open call: 11 closed tiles → m = 11/3 = 3
     *            We need 3 melds + pair from closed hand
     *            Plus 1 open meld = 4 total melds + pair
     *            Look up ret[3+5] = ret[8]
     *
     *          - 2 open calls: 8 closed tiles → m = 8/3 = 2
     *            We need 2 melds + pair from closed hand
     *            Plus 2 open melds = 4 total melds + pair
     *            Look up ret[2+5] = ret[7]
     *
     * @return Shanten number (distance to tenpai, 0 = tenpai)
     */
    private int calc_lh(int[] tiles, int m)
    {
        // Debug: Log input tiles
        //  StringBuilder tile_log = new StringBuilder();
        //  for (int i = 0; i < NUM_TILE_TYPES; i++)
        //  {
        //      if (tiles[i] > 0)
        //          tile_log.append(@"[$(i):$(tiles[i])] ");
        //  }
        //  Environment.log(LogType.DEBUG, "ShantenCalculator",
        //      @"calc_lh input (m=$(m)): $(tile_log.str)");

        // Step 1: Start with honor tiles (indices 27-33: TON,NAN,SHAA,PEI,HAKU,HATSU,CHUN)
        // The lookup table gives us shanten values for all possible honor tile combinations
        int hash_honors = hash7(tiles, 27);
        uint8[] ret = new uint8[LOOKUP_SIZE];

        //  Environment.log(LogType.DEBUG, "ShantenCalculator",
        //      @"hash_honors = $(hash_honors)");

        // Copy the lookup result - this is our starting point
        // ret[0-4] = shanten with 0-4 melds and no pair
        // ret[5-9] = shanten with 0-4 melds and has a pair
        for (int i = 0; i < LOOKUP_SIZE; i++)
            ret[i] = get_table_value(index_h, hash_honors, i);

        // Debug: Log honor tiles result
        //  StringBuilder ret_log = new StringBuilder();
        //  for (int i = 0; i < LOOKUP_SIZE; i++)
        //      ret_log.append(@"$(ret[i]) ");
        //  Environment.log(LogType.DEBUG, "ShantenCalculator",
        //      @"After honors: [$(ret_log.str)]");

        // Step 2: Add Sou tiles (索子, indices 18-26: 1s-9s)
        // Look up shanten for this suit, then combine with existing results
        int hash_sou = hash9(tiles, 18);
        uint8[] sou_result = new uint8[LOOKUP_SIZE];
        for (int i = 0; i < LOOKUP_SIZE; i++)
            sou_result[i] = get_table_value(index_s, hash_sou, i);

        //  Environment.log(LogType.DEBUG, "ShantenCalculator",
        //      @"hash_sou = $(hash_sou)");

        // Debug: Log sou_result before adding
        StringBuilder sou_log = new StringBuilder();
        for (int i = 0; i < LOOKUP_SIZE; i++)
            sou_log.append(@"$(sou_result[i]) ");
        //  Environment.log(LogType.DEBUG, "ShantenCalculator",
        //      @"sou_result: [$(sou_log.str)]");

        add1(ret, sou_result, m);  // ret now contains combined honor+sou results

        //  ret_log = new StringBuilder();
        //  for (int i = 0; i < LOOKUP_SIZE; i++)
        //      ret_log.append(@"$(ret[i]) ");
        //  Environment.log(LogType.DEBUG, "ShantenCalculator",
        //      @"After sou: [$(ret_log.str)]");

        // Step 3: Add Pin tiles (筒子, indices 9-17: 1p-9p)
        // Look up shanten for this suit, then combine with honor+sou results
        int hash_pin = hash9(tiles, 9);
        uint8[] pin_result = new uint8[LOOKUP_SIZE];
        for (int i = 0; i < LOOKUP_SIZE; i++)
            pin_result[i] = get_table_value(index_s, hash_pin, i);

        //  Environment.log(LogType.DEBUG, "ShantenCalculator",
        //      @"hash_pin = $(hash_pin)");

        // Debug: Log pin_result before adding
        //  StringBuilder pin_log = new StringBuilder();
        //  for (int i = 0; i < LOOKUP_SIZE; i++)
        //      pin_log.append(@"$(pin_result[i]) ");
        //  Environment.log(LogType.DEBUG, "ShantenCalculator",
        //      @"pin_result: [$(pin_log.str)]");

        add1(ret, pin_result, m);  // ret now contains honor+sou+pin results

        //  ret_log = new StringBuilder();
        //  for (int i = 0; i < LOOKUP_SIZE; i++)
        //      ret_log.append(@"$(ret[i]) ");
        //  Environment.log(LogType.DEBUG, "ShantenCalculator",
        //      @"After pin: [$(ret_log.str)]");

        // Step 4: Add Man tiles (万子, indices 0-8: 1m-9m) - final suit uses add2
        // For the last suit, we know exactly what we need (m melds + pair),
        // so we use the optimized add2 function
        int hash_man = hash9(tiles, 0);
        uint8[] man_result = new uint8[LOOKUP_SIZE];
        for (int i = 0; i < LOOKUP_SIZE; i++)
            man_result[i] = get_table_value(index_s, hash_man, i);

        //  Environment.log(LogType.DEBUG, "ShantenCalculator",
        //      @"hash_man = $(hash_man)");

        add2(ret, man_result, m);  // Final combination: all 4 suits

        //  ret_log = new StringBuilder();
        //  for (int i = 0; i < LOOKUP_SIZE; i++)
        //      ret_log.append(@"$(ret[i]) ");
        //  Environment.log(LogType.DEBUG, "ShantenCalculator",
        //      @"After man: [$(ret_log.str)]");

        // Return the result at index m+5
        // ===== WHY ret[m+5]? =====
        // m+5 means: "m melds + has pair" (index 5 is the offset for "has pair")
        //
        // The lookup table returns: "Shanten for forming m melds + pair from closed tiles"
        // Total winning structure: m (from closed) + open_calls = 4 melds + 1 pair
        //
        // Mathematical equivalence:
        //   m = closed_tiles / 3 = (14 - 3*open_calls) / 3 = 4 - open_calls
        //   ret[m + 5] = ret[(4 - open_calls) + 5] = ret[9 - open_calls]
        //
        // So ret[m+5] is equivalent to ret[9 - open_calls]:
        //   0 open calls → ret[9]  (4 melds + pair from 14 tiles)
        //   1 open call  → ret[8]  (3 melds + pair from 11 tiles)
        //   2 open calls → ret[7]  (2 melds + pair from 8 tiles)
        //   3 open calls → ret[6]  (1 meld + pair from 5 tiles)
        int result = ret[m + 5];
        //  Environment.log(LogType.DEBUG, "ShantenCalculator",
        //      @"Final result ret[$(m+5)] = $(result)");

        return result;
    }
}

