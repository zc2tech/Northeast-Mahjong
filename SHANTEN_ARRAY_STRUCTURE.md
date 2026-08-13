# Understanding the 10-Byte Shanten Array Structure

## The Truth from the Source Code

Looking at `mkind.cpp` line 63:
```cpp
std::copy(table[N][0][0][0].cbegin(), table[N][0][0][1].cend(), sht.begin());
```

This copies data from the DP table into the 10-byte output array.

## What Does This Mean?

The DP table structure is:
```cpp
table[n][a][b][h][m]
```

Where:
- `n`: Tile types processed
- `a`: Previous group count (0-4)
- `b`: Current group count (0-4)
- `h`: Has pair? (0 or 1)
- `m`: Meld count (0-4)

The output array copies:
```
table[N][0][0][0][0..4]  → sht[0..4]   (h=0: no pair, m=0..4 melds)
table[N][0][0][1][0..4]  → sht[5..9]   (h=1: has pair, m=0..4 melds)
```

## So the Pattern IS Defined!

**The 10-byte array structure:**

**Indices [0-4]**: `table[N][0][0][0][m]` where m=0,1,2,3,4
- All tiles processed (N)
- No pending groups (a=0, b=0)
- **No pair (h=0)**
- m complete melds

**Indices [5-9]**: `table[N][0][0][1][m]` where m=0,1,2,3,4
- All tiles processed (N)
- No pending groups (a=0, b=0)
- **Has pair (h=1)**
- m complete melds

## Answer to Your Question

**Yes, this pattern IS defined in the shanten-number project!**

It comes directly from the DP table structure in `mkind.cpp`. The 10-byte array is literally:
- **sht[0-4]**: Final states with 0-4 melds and NO pair
- **sht[5-9]**: Final states with 0-4 melds and HAS pair

The values in each cell represent the **minimum extra tiles needed** to reach that state (which is the shanten number).

## Why ret[5] = 6?

For an empty hand, `ret[5]` = `table[N][0][0][1][0]` means:
- Processed all tiles (but hand is empty)
- No pending groups
- Has a pair (h=1)
- 0 complete melds (m=0)

To reach a winning hand (4 melds + pair) from this state, you need 4 more complete melds, which requires approximately 6 useful tiles (the DP algorithm calculated this precisely).

I was correct about the pattern, but I should have shown you WHERE it comes from in the source code!
