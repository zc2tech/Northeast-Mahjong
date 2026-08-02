# Complete Game Flow Trace: Normal Game Message & Rendering Sequence

This document traces the **EXACT** flow of messages, signals, and rendering actions in a normal game from start to finish. This is the ground truth that replay mode must replicate.

---

## Critical Discovery: Initial Dealing Flow

### Key Finding 1: NO ServerMessageTileDraw During Initial Dealing
**During initial dealing, ONLY `ServerMessageTileAssignment` messages are sent.**
- `ServerMessageTileDraw` is **ONLY** sent during gameplay tile draws (after initial dealing completes)
- Initial dealing uses a completely different message flow

### Key Finding 2: Wall Drawing Mechanism
The wall provides **physical RenderTile objects** at specific positions, NOT tile IDs:
- `wall.draw_wall()` returns the next `RenderTile` from the wall's sequential position
- The tile already has its type assigned via `ServerMessageTileAssignment`
- The renderer just moves the physical tile from wall → hand

---

## Part 1: Round Start & Initial Dealing

### 1.1 Server: Round Initialization
**Location:** `ServerGameRound.start()` (line 51-59)

```
[Server] ServerGameRound.start(time)
  ├─ Sends: ServerMessageRoundStart(info) → all players
  ├─ Calls: round_starting()  
  │   └─ Reveals dead wall mark tile via game_reveal_tile()
  └─ Calls: ServerRoundState.start(time)
```

**`ServerMessageRoundStart` contains:**
- `RoundStartInfo info` with:
  - `wall_index` (dice roll 0-5)
  - `dead_wall_mark_tile_id` (computed in RegularServerGameRound constructor, line 318-322)
  - Round metadata (wind, dealer, etc.)

---

### 1.2 Server: Initial Dealing Sequence
**Location:** `ServerRoundState.start()` → `initial_draw()` (line 573-578)

```
[Server] ServerRoundState.start(time)
  ├─ Calls: validator.start() [creates tiles, arranges wall]
  ├─ Adds animation delay: timings.split_wall.total()
  ├─ Calls: initial_draw()
  │   └─ For each player (0-3):
  │       └─ Emits: game_initial_draw(player_index, hand[13 tiles])
  └─ Calls: next_turn()
```

**`initial_draw()` implementation:**
```vala
private void initial_draw()
{
    foreach (ServerRoundStatePlayer player in validator.players)
        game_initial_draw(player.index, player.hand);  // hand has 13 tiles
    add_animation_delay(timings.initial_draw.total() * 16);
}
```

---

### 1.3 Server: Tile Assignment Messages
**Location:** `ServerGameRound.game_initial_draw()` (line 74-88)

```
[Server] game_initial_draw(player_index=0, hand=[13 tiles])
  └─ For each tile in hand:
      └─ Sends: ServerMessageTileAssignment(tile) 
          ├─ To: Player 0 (always)
          ├─ To: Spectators (always)
          └─ To: Other players (only if reveal_all_tiles == ON)

[Server] game_initial_draw(player_index=1, hand=[13 tiles])
  └─ [same pattern]

[Server] game_initial_draw(player_index=2, hand=[13 tiles])
  └─ [same pattern]

[Server] game_initial_draw(player_index=3, hand=[13 tiles])
  └─ [same pattern]
```

**Total messages sent during initial dealing:**
- 52 `ServerMessageTileAssignment` messages (13 tiles × 4 players)
- **0** `ServerMessageTileDraw` messages

**`ServerMessageTileAssignment` contains:**
- `Tile tile` with:
  - `int ID` (0-111, physical tile identifier)
  - `TileType tile_type` (MAN1, PIN5, etc.)

---

### 1.4 Client: Processing Tile Assignments
**Location:** `ClientRoundState.server_tile_assignment()` (line 380-389)

```
[Client] ClientRoundState receives ServerMessageTileAssignment(tile)
  ├─ Calls: state.tile_assign(tile)
  │   └─ Updates: tiles[tile.ID].tile_type = tile.tile_type
  └─ Emits: game_tile_assignment(tile)
```

**Connection:** `GameController.create_round_state()` (line 141)
```vala
round.game_tile_assignment.connect(renderer.tile_assignment);
```

---

### 1.5 Renderer: Tile Assignment Processing
**Location:** `GameRenderView.tile_assignment()` (line 312-317)

```
[Renderer] GameRenderView.tile_assignment(tile)
  ├─ Gets: RenderTile t = tiles[tile.ID]
  ├─ Sets: t.tile_type = tile
  └─ Calls: t.reload()  [loads correct texture, shows face]
```

**Critical:** This happens **BEFORE** any wall animation. All 112 tiles get their types assigned first.

---

### 1.6 Renderer: Initial Draw Actions (Buffered in added())
**Location:** `GameRenderView.added()` (line 96-112)

```
[Renderer] GameRenderView.added()
  ├─ Buffers: RenderActionDelay(0.5s)
  ├─ Buffers: RenderActionSplitDeadWall(timings.split_wall)
  ├─ Buffers: RenderActionInitialDraw × 16 iterations:
  │   ├─ Iteration 0-11: 4 tiles each (dealer+0, dealer+1, dealer+2, dealer+3)
  │   └─ Iteration 12-15: 1 tile each (dealer+0, dealer+1, dealer+2, dealer+3)
  └─ Buffers: RenderActionFlipDeadWallMark(info.dead_wall_mark_tile_id)
```

**Pattern:** Dealer draws first in each iteration (rotates through all 4 players 16 times).

---

### 1.7 Scene: Executing Initial Draw Actions
**Location:** `GameScene.action_initial_draw()` (line 157-162)

```
[Scene] RenderActionInitialDraw.execute(player, tiles=4)
  └─ For i in 0..3:
      └─ Calls: player.draw_tile(wall.draw_wall())
```

**`wall.draw_wall()` returns:** The next physical `RenderTile` from the wall (already has type assigned).

---

### 1.8 Hand: Drawing Tiles & Sorting
**Location:** `RenderHand.draw_tile()` (line 28-48)

```
[Hand] RenderHand.draw_tile(tile)
  ├─ Calls: wrap.convert_object(tile)  [moves tile to hand's coordinate space]
  ├─ Increments: drawn++
  │
  ├─ IF (tiles.size > 1 AND drawn >= 14):  [14th tile (first draw of turn)]
  │   ├─ Calls: sort_hand()
  │   ├─ Calls: order_hand(true)  [arranges 13 tiles]
  │   ├─ Calls: order_draw_tile(tile)  [14th tile separate, rotated]
  │   └─ Adds: tiles.add(tile)
  │
  └─ ELSE:  [tiles 1-13]
      ├─ Adds: tiles.add(tile)
      ├─ Calls: sort_hand()  [SORTING HAPPENS HERE]
      └─ Calls: order_hand(true)  [POSITIONING HAPPENS HERE]
```

**Critical Timing:**
- Tiles 1-13: Sort + position after each tile added
- Tile 14 (first turn draw): Sorted hand stays in place, new tile positioned separately

**`sort_hand()` implementation:**
```vala
public void sort_hand()
{
    tiles = RenderTile.sort_tiles(tiles);  // Sorts by tile_type
}
```

**`order_hand(animate=true)` implementation:**
```vala
public void order_hand(bool animate)
{
    for (int i = 0; i < tiles.size; i++)
        order_tile(tiles[i], i, animate);  // Positions tile i at position i
}
```

---

## Part 2: Normal Tile Draw (After Initial Dealing)

### 2.1 Server: Drawing a Tile
**Location:** `ServerRoundState.next_turn()` (line 504-529)

```
[Server] ServerRoundState.next_turn()
  ├─ Checks: validator.game_draw [game over?]
  ├─ Gets: player = validator.get_current_player()
  ├─ Calls: tile = validator.draw_wall()  [gets next tile from wall]
  ├─ Logs: TileDrawServerAction(player.index, tile.ID)
  ├─ Emits: game_draw_tile(player.index, tile, player.open)
  ├─ Queues: turn_decision(player.index)
  └─ Adds animation delay: timings.tile_draw.total()
```

---

### 2.2 Server: Draw Tile Messages
**Location:** `ServerGameRound.game_draw_tile()` (line 90-103)

```
[Server] game_draw_tile(player_index, tile, open)
  └─ For each player/spectator:
      ├─ IF (reveal_all_tiles OR self OR spectator OR open):
      │   └─ Sends: ServerMessageTileAssignment(tile)
      └─ Sends: ServerMessageTileDraw(tile.ID)  [EVERYONE gets this]
```

**Messages sent per tile draw:**
- 1 `ServerMessageTileAssignment` (only to relevant viewers)
- 4 `ServerMessageTileDraw` (to all 4 players)

**Key Difference from Initial Dealing:**
- Initial dealing: ONLY `ServerMessageTileAssignment`
- Normal draw: BOTH `ServerMessageTileAssignment` + `ServerMessageTileDraw`

---

### 2.3 Client: Processing Tile Draw
**Location:** `ClientRoundState.server_tile_draw()` (line 391-402)

```
[Client] ClientRoundState receives ServerMessageTileDraw(tile_ID)
  ├─ Calls: decision_finished()  [clears UI buttons]
  ├─ Calls: tile = state.tile_draw()  [advances current player]
  └─ Emits: game_tile_draw(current_player.index, tile_ID)
```

**Connection:** `GameController.create_round_state()` (line 142)
```vala
round.game_tile_draw.connect(renderer.tile_draw);
```

---

### 2.4 Renderer: Drawing Tile Action
**Location:** `GameRenderView.tile_draw()` (line 319-328)

```
[Renderer] GameRenderView.tile_draw(player_index, tile_ID)
  ├─ Gets: player = players[player_index]
  ├─ Gets: tile = tiles[tile_ID]  [tile already has type from TileAssignment]
  └─ Buffers: RenderActionDraw(timings.tile_draw, player)
```

---

### 2.5 Scene: Executing Draw Action
**Location:** `GameScene.action_draw()` (line 164-172)

```
[Scene] RenderActionDraw.execute(player)
  ├─ Plays: draw_sound
  ├─ Calls: player.draw_tile(wall.draw_wall())
  └─ IF player is observer:
      └─ Sets: active = true  [enable tile selection]
```

**Same flow as initial draw:** `player.draw_tile()` → `RenderHand.draw_tile()` → sort + position.

---

## Part 3: Tile Discard & Pond

### 3.1 Server: Discarding a Tile
**Location:** `ServerRoundState.tile_discard()` (line 382-387)

```
[Server] tile_discard(tile)
  ├─ Adds animation delay: timings.tile_discard.total()
  ├─ Emits: game_discard_tile(tile)
  └─ Calls: queue_call_decisions()
```

---

### 3.2 Server: Discard Messages
**Location:** `ServerGameRound.game_discard_tile()` (line 113-120)

```
[Server] game_discard_tile(tile)
  ├─ Calls: game_reveal_tile(tile)  [sends TileAssignment to all]
  └─ Sends: ServerMessageTileDiscard(tile.ID) to all players
```

---

### 3.3 Client: Processing Discard
**Location:** `ClientRoundState.server_tile_discard()` (line 404-415)

```
[Client] ClientRoundState receives ServerMessageTileDiscard(tile_ID)
  ├─ Calls: decision_finished()
  ├─ Calls: state.tile_discard(tile_ID)
  └─ Emits: game_tile_discard(current_player.index, tile_ID)
```

---

### 3.4 Renderer: Discard Action
**Location:** `GameRenderView.tile_discard()` (line 342-347)

```
[Renderer] GameRenderView.tile_discard(player_index, tile_ID)
  ├─ Gets: player = players[player_index]
  ├─ Gets: tile = tiles[tile_ID]
  └─ Buffers: RenderActionDiscard(timings.tile_discard, player, tile)
```

---

### 3.5 Scene & Player: Executing Discard
**Location:** `GameScene.action_discard()` (line 186-190) → `RenderPlayer.discard()` (line 87-91)

```
[Scene] RenderActionDiscard.execute(player, tile)
  └─ Calls: player.discard(tile)

[Player] RenderPlayer.discard(tile)
  ├─ Calls: hand.remove(tile)
  └─ Calls: pond.add_tile(tile)
```

---

### 3.6 Pond: Adding Tile
**Location:** `RenderPond.add_tile()` (line 27-39) + `arrange_pond()` (line 55-101)

```
[Pond] RenderPond.add_tile(tile)
  ├─ Calls: convert_object(tile)  [moves to pond's coordinate space]
  ├─ Adds: tiles.add(tile)
  └─ Calls: arrange_pond()

[Pond] arrange_pond()
  └─ For each tile (i = 0..tiles.size-1):
      ├─ Calculates grid position:
      │   ├─ Row 0: tiles 0-5  (width starts at -3*tile_size.x)
      │   ├─ Row 1: tiles 6-11 (height = tile_size.z)
      │   └─ Row 2: tiles 12+  (height = 2*tile_size.z)
      ├─ Calculates: pos = Vec3(x, 0, y)
      ├─ Calculates: rot = Quat.from_euler(r, 0, 0)  [r=0 normal, 0.5 for riichi]
      └─ Calls: tile.animate_towards(pos, rot, timings.tile_discard)
```

**Pond layout:** 6 tiles per row, 3 rows maximum (18 tiles).

---

## Part 4: Calls (Pon Example)

### 4.1 Server: Pon Call
**Location:** `ServerRoundState.check_calls_done()` (line 389-447) → `ServerGameRound.game_pon()` (line 215-224)

```
[Server] check_calls_done()  [after all players respond]
  ├─ Gets: result = validator.get_call()
  └─ IF result.call_type == PON:
      ├─ Emits: game_pon(caller.index, result.tiles)
      └─ Adds animation delay: timings.call.total()
```

---

### 4.2 Server: Pon Messages
**Location:** `ServerGameRound.game_pon()` (line 215-224)

```
[Server] game_pon(player_index, tiles[3])
  ├─ For each tile in tiles:
  │   └─ Calls: game_reveal_tile(tile)  [TileAssignment to all]
  └─ Sends: ServerMessagePon(player_index, tiles[0].ID, tiles[1].ID)
```

**`tiles` array contains:**
- `tiles[0]`: First tile from hand
- `tiles[1]`: Second tile from hand  
- `tiles[2]`: Discarded tile (from pond)

Only tiles[0] and tiles[1] IDs are sent (server knows tiles[2] is the discard).

---

### 4.3 Client: Processing Pon
**Location:** `ClientRoundState.server_pon()` (line 488-497)

```
[Client] ClientRoundState receives ServerMessagePon(player_index, tile_1_ID, tile_2_ID)
  ├─ Calls: decision_finished()
  ├─ Gets: discard_index = state.current_player.index
  ├─ Calls: state.pon(player_index, tile_1_ID, tile_2_ID)
  └─ Emits: game_pon(player_index, discard_index, discard_tile.ID, tile_1_ID, tile_2_ID)
```

---

### 4.4 Renderer: Pon Action
**Location:** `GameRenderView.pon()` (line 388-398)

```
[Renderer] GameRenderView.pon(player_index, discard_player_index, tile_ID, tile_1_ID, tile_2_ID)
  ├─ Gets: player = players[player_index]
  ├─ Gets: discard_player = players[discard_player_index]
  ├─ Gets: tile = tiles[tile_ID]  [discarded tile]
  ├─ Gets: tile_1 = tiles[tile_1_ID]  [from hand]
  ├─ Gets: tile_2 = tiles[tile_2_ID]  [from hand]
  └─ Buffers: RenderActionPon(timings.call, player, discard_player, tile, tile_1, tile_2)
```

---

### 4.5 Scene & Player: Executing Pon
**Location:** `GameScene.action_pon()` (line 261-269) → `RenderPlayer.pon()` (line 193-204)

```
[Scene] RenderActionPon.execute(player, discarder, tile, tile_1, tile_2)
  ├─ Plays: pon_sound
  ├─ Calls: discarder.rob_tile(tile)  [removes from pond]
  ├─ Calls: player.pon(discarder, tile, tile_1, tile_2)
  └─ IF player is observer:
      └─ Sets: active = true

[Player] RenderPlayer.pon(discard_player, discard_tile, tile_1, tile_2)
  ├─ Calls: hand.remove(tile_1)
  ├─ Calls: hand.remove(tile_2)
  ├─ Creates: tiles = [tile_1, tile_2]
  ├─ Calculates: alignment = RenderCalls.players_to_alignment(this, discard_player)
  └─ Calls: calls.add_call(new RenderCallPon(tiles, discard_tile, tile_size, alignment))
```

---

### 4.6 Calls: Arranging Pon
**Location:** `RenderCallPon.arrange()` (line 345-396)

```
[CallPon] RenderCallPon constructor
  ├─ Determines: n = alignment-based index (0=right, 1=center, 2=left)
  └─ Inserts: tiles.insert(n, discard_tile)  [puts discard at correct position]

[CallPon] arrange()
  └─ For i in 0..2:
      ├─ IF i == n:  [the rotated tile]
      │   ├─ x = width + tile_size.z / 2
      │   ├─ z = tile_size.x / 2
      │   ├─ rotation = 0.5f (90°)
      │   └─ width += tile_size.z + tile_gap
      └─ ELSE:  [normal upright tiles]
          ├─ x = width + tile_size.x / 2
          ├─ z = tile_size.z / 2
          ├─ rotation = 0
          └─ width += tile_size.x + tile_gap
```

**Alignment determines which tile is rotated:**
- `RIGHT` (discard from right player): tiles[0] rotated
- `CENTER` (discard from across): tiles[1] rotated
- `LEFT` (discard from left player): tiles[2] rotated

---

## Part 5: Complete Message Sequence Example

### Scenario: Initial dealing → Player 0 draws → Player 0 discards → Player 1 pons

```
TIME 0.0s: ROUND START
======================
[Server] ServerMessageRoundStart(info) → all players
[Client] Creates ClientRoundState, GameRenderView
[Renderer] Buffers: RenderActionDelay(0.5s)
[Renderer] Buffers: RenderActionSplitDeadWall
[Renderer] Buffers: RenderActionInitialDraw × 16
[Renderer] Buffers: RenderActionFlipDeadWallMark

TIME 0.0s: TILE ASSIGNMENTS (52 messages)
==========================================
[Server] ServerMessageTileAssignment(tile_ID=0, type=MAN1) → Player 0, spectators
[Client] state.tile_assign(tile_ID=0, type=MAN1)
[Renderer] tiles[0].tile_type = Tile(0, MAN1)
[Renderer] tiles[0].reload()

[... repeat for all 52 tiles ...]

[Server] ServerMessageTileAssignment(tile_ID=51, type=SOU9) → Player 3, spectators
[Client] state.tile_assign(tile_ID=51, type=SOU9)
[Renderer] tiles[51].tile_type = Tile(51, SOU9)
[Renderer] tiles[51].reload()

TIME 0.5s: SPLIT DEAD WALL ANIMATION
=====================================
[Scene] RenderActionSplitDeadWall.execute()
[Scene] wall.split_dead_wall(timings.split_wall)
[Wall] Calculates start_wall = (4 - dealer) % 4
[Wall] Splits wall at position wall_index
[Wall] Animates gap between draw wall and dead wall

TIME 1.0s: INITIAL DRAW ITERATION 0 (4 tiles)
==============================================
[Scene] RenderActionInitialDraw.execute(player=dealer, tiles=4)
[Scene] For i in 0..3:
    [Scene] player[dealer].draw_tile(wall.draw_wall())
    [Hand] Gets tile from wall position X
    [Hand] wrap.convert_object(tile)
    [Hand] tiles.add(tile)
    [Hand] sort_hand()  [sorts by tile_type]
    [Hand] order_hand(true)  [positions all tiles]

[... repeat for iterations 1-11, rotating through players ...]

TIME 5.0s: INITIAL DRAW ITERATION 12 (1 tile, player 0)
========================================================
[Scene] RenderActionInitialDraw.execute(player=0, tiles=1)
[Scene] player[0].draw_tile(wall.draw_wall())
[Hand] tiles.add(tile)  [13th tile]
[Hand] sort_hand()
[Hand] order_hand(true)

[... repeat for iterations 13-15, players 1-3 get their 13th tiles ...]

TIME 6.0s: FLIP DEAD WALL MARK
===============================
[Scene] RenderActionFlipDeadWallMark.execute(mark_tile_id=104)
[Wall] Finds tile 104 in dead_parts
[Wall] tile.animate_towards(pos, rot * Quat.euler(0,1,0), time)  [flips face-up]

TIME 7.0s: PLAYER 0 FIRST DRAW
===============================
[Server] validator.draw_wall() → tile_ID=52
[Server] ServerMessageTileAssignment(tile_ID=52, type=MAN2) → Player 0, spectators
[Server] ServerMessageTileDraw(tile_ID=52) → all players

[Client Player 0] state.tile_assign(tile_ID=52, type=MAN2)
[Renderer] tiles[52].tile_type = Tile(52, MAN2)
[Renderer] tiles[52].reload()

[Client All] state.tile_draw() → advances to player 0
[Client All] Emits game_tile_draw(player_index=0, tile_ID=52)
[Renderer] Buffers RenderActionDraw(player=0)

[Scene] RenderActionDraw.execute(player=0)
[Scene] player[0].draw_tile(wall.draw_wall())
[Hand] drawn++ (now 14)
[Hand] sort_hand()  [sorts 13 tiles in hand]
[Hand] order_hand(true)  [positions 13 tiles]
[Hand] order_draw_tile(tile)  [positions 14th tile separately, rotated]
[Hand] tiles.add(tile)
[Scene] active = true  [Player 0 can now select tile]

TIME 7.5s: PLAYER 0 DISCARDS
=============================
[Client Player 0] User clicks tile_ID=52
[Client Player 0] TileDiscardClientAction(tile_ID=52) → Server

[Server] validator.discard_tile(52)
[Server] ServerMessageTileAssignment(tile_ID=52, type=MAN2) → all players [reveal]
[Server] ServerMessageTileDiscard(tile_ID=52) → all players

[Client All] state.tile_discard(tile_ID=52)
[Client All] Emits game_tile_discard(player_index=0, tile_ID=52)
[Renderer] Buffers RenderActionDiscard(player=0, tile=52)

[Scene] RenderActionDiscard.execute(player=0, tile=52)
[Player] hand.remove(tile[52])
[Player] pond.add_tile(tile[52])
[Pond] convert_object(tile[52])
[Pond] tiles.add(tile[52])
[Pond] arrange_pond()
[Pond] tile[52].animate_towards(Vec3(x=..., z=0), Quat(), time)

TIME 8.0s: CALL DECISIONS
==========================
[Server] ServerMessageCallDecision → Player 1, 2, 3
[Client Player 1] UI shows Pon button (has 2× MAN2)
[Client Player 2,3] UI shows Continue button

TIME 8.5s: PLAYER 1 PONS
=========================
[Client Player 1] User clicks Pon button
[Client Player 1] PonClientAction() → Server

[Server] validator.decide_pon(player_index=1)
[Server] validator.get_call() → CallResult(PON, tiles=[10,11,52])
[Server] ServerMessageTileAssignment(tile_ID=10, type=MAN2) → all players
[Server] ServerMessageTileAssignment(tile_ID=11, type=MAN2) → all players
[Server] ServerMessagePon(player_index=1, tile_1_ID=10, tile_2_ID=11) → all players

[Client All] state.pon(player_index=1, tile_1_ID=10, tile_2_ID=11)
[Client All] Emits game_pon(player=1, discarder=0, tile_ID=52, tile_1=10, tile_2=11)
[Renderer] Buffers RenderActionPon(player=1, discarder=0, tile=52, tile_1=10, tile_2=11)

[Scene] RenderActionPon.execute(...)
[Player 0] pond.remove(tile[52])
[Player 1] hand.remove(tile[10])
[Player 1] hand.remove(tile[11])
[Player 1] alignment = players_to_alignment(p1, p0) → RIGHT
[Player 1] calls.add_call(RenderCallPon([10,11], 52, alignment=RIGHT))
[CallPon] Inserts tile[52] at position 0 (right-most)
[CallPon] arrange()
    ├─ tile[52]: x=0, z=tile_size.x/2, rotation=0.5 (90°)
    ├─ tile[10]: x=tile_size.z, z=tile_size.z/2, rotation=0
    └─ tile[11]: x=tile_size.z+tile_size.x, z=tile_size.z/2, rotation=0
```

---

## Part 6: Critical Differences Between Normal Game & Replay

### What Replay Currently Does WRONG:

1. **Sends `ServerMessageTileDraw` during initial dealing**
   - Normal game: ONLY `ServerMessageTileAssignment` during initial dealing
   - Replay: Sends BOTH, causing double-processing

2. **Wall drawing order mismatch**
   - Normal: Wall draws sequentially from physical positions
   - Replay: Tries to match tile IDs but order is wrong

3. **Missing tile assignments**
   - Normal: Every tile gets `ServerMessageTileAssignment` before visual animation
   - Replay: May not send all assignments, causing face-down tiles

4. **Timing/order issues**
   - Normal: Assignments → Wall split → Initial draws → Mark flip
   - Replay: May send draw messages too early

### What Replay Must Do:

1. **During `round_starting()`:**
   - Send ALL 112 `ServerMessageTileAssignment` messages (from log.tiles)
   - Send in wall order (0-111)
   - Do this BEFORE any animations start

2. **Do NOT send `ServerMessageTileDraw` during initial dealing**
   - The `TileDrawServerAction` in the log is for normal draws ONLY
   - Initial dealing animations are triggered by `RenderActionInitialDraw` (buffered in added())

3. **Respect the wall structure:**
   - The renderer expects `wall.draw_wall()` to return tiles in order
   - Don't try to match tile IDs, just ensure wall has correct sequence

4. **Match exact message timing:**
   - Assignments at T=0
   - Let renderer buffer its initial draw actions
   - Actions execute in order via `GameScene.process()`

---

## Part 7: Wall Structure & Tile ID Mapping

### Physical Wall Layout (28 tiles per side = 112 total)

```
Wall Side 0 (28 tiles):  IDs 0-27
Wall Side 1 (28 tiles):  IDs 28-55
Wall Side 2 (28 tiles):  IDs 56-83
Wall Side 3 (28 tiles):  IDs 84-111

Each side: 14 stacks of 2 tiles (upper + lower)
Stack i on side j:
  Upper tile: j*28 + i*2
  Lower tile: j*28 + i*2 + 1
```

### Dead Wall Split Calculation

```
start_wall = (4 - dealer) % 4
index = start_wall * 28 + wall_index * 2
mark_tile_id = (index + 104) % 112

Dead wall: 4 stacks (8 tiles) from wall end
Draw wall: Remaining 104 tiles
```

### Example (dealer=0, wall_index=3):
```
start_wall = 4 % 4 = 0
index = 0*28 + 3*2 = 6
mark_tile_id = (6 + 104) % 112 = 110

Split point: Stack 3 on side 0 (tiles 6-7)
Dead wall mark: Tile 110 (stack 13 upper, side 3)
```

---

## Summary: Key Message Types & When They're Sent

| Message Type | During Initial Dealing | During Gameplay |
|--------------|------------------------|-----------------|
| `ServerMessageTileAssignment` | ✅ YES (52 times, one per tile) | ✅ YES (when revealing tile) |
| `ServerMessageTileDraw` | ❌ NO | ✅ YES (every normal draw) |
| `ServerMessageTileDiscard` | ❌ NO | ✅ YES (every discard) |
| `ServerMessagePon/Chii/Kan` | ❌ NO | ✅ YES (when call succeeds) |

---

## Renderer Action Buffering & Execution Order

All actions are buffered via `GameScene.add_action()` and execute sequentially:

1. Actions buffer instantly (no delay)
2. `GameScene.process()` executes one action per frame
3. Each action has a duration (`time.total()`)
4. Next action starts when previous completes

**Example timeline:**
```
T=0.0: Buffer action A (duration 1s)
T=0.0: Buffer action B (duration 2s)
T=0.0: action A starts executing
T=1.0: action A completes
T=1.0: action B starts executing
T=3.0: action B completes
```

This ensures animations play in order without overlap.

---

## Conclusion

The normal game flow is:

1. **Tile Assignment Phase**: All 52 hand tiles get their types assigned via `ServerMessageTileAssignment`
2. **Animation Phase**: Renderer plays buffered actions (split wall, initial draws, mark flip)
3. **Gameplay Phase**: Each action sends BOTH `TileAssignment` + action-specific message

**Replay must replicate this EXACTLY:**
- Send all 112 tile assignments upfront (from `log.tiles`)
- Let renderer's buffered actions handle initial dealing animations
- Send gameplay messages (draw/discard/call) from `log.lines` at correct times
- Never send `ServerMessageTileDraw` during initial dealing
