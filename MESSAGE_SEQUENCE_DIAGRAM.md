# Message Sequence Diagram: Simple Game Scenario

## Scenario: Initial dealing for 4 players → Player 0 draws → Player 0 discards → Player 1 pons

---

## Timeline: Complete Message & Signal Flow

```
═══════════════════════════════════════════════════════════════════════════════
TIME 0.0s: SERVER INITIALIZATION
═══════════════════════════════════════════════════════════════════════════════

[ServerMenu]
  └─> Creates: RegularServerGameRound(dealer=0, wall_index=3, rnd)
      ├─> Creates: RegularServerRoundState
      │   └─> Creates: ServerRoundStateValidator
      │       └─> Initializes wall with 112 shuffled tiles
      └─> Calculates: dead_wall_mark_tile_id
          ├─ start_wall = (4 - 0) % 4 = 0
          ├─ index = 0*28 + 3*2 = 6
          └─ mark_tile_id = (6 + 104) % 112 = 110

[ServerGameRound.start(time)]
  ├─> Sends: ServerMessageRoundStart(info) ────────────────────┐
  │                                                             │
  └─> Calls: round_starting()                                  │
      └─> Reveals dead wall mark:                              │
          └─> game_reveal_tile(tiles[110])                     │
              └─> Sends: ServerMessageTileAssignment(110) ─────┤
                                                                │
                                                                ▼
                                                    ┌───────────────────────┐
                                                    │ ALL CLIENTS (4)       │
                                                    └───────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
TIME 0.0s: CLIENT INITIALIZATION (Each client does this)
═══════════════════════════════════════════════════════════════════════════════

[GameController] receives ServerMessageRoundStart
  ├─> Creates: GameRenderView(player_index, dealer_index, info, ...)
  │   └─> GameRenderView.added()
  │       ├─> Creates: GameScene with 112 RenderTiles (all face-down)
  │       ├─> Creates: RenderWall(tiles[0..111])
  │       └─> BUFFERS ACTIONS (in order):
  │           ├─ [Action 0] RenderActionDelay(0.5s)
  │           ├─ [Action 1] RenderActionSplitDeadWall
  │           ├─ [Action 2] RenderActionInitialDraw(dealer+0, 4 tiles)
  │           ├─ [Action 3] RenderActionInitialDraw(dealer+1, 4 tiles)
  │           ├─ [Action 4] RenderActionInitialDraw(dealer+2, 4 tiles)
  │           ├─ [Action 5] RenderActionInitialDraw(dealer+3, 4 tiles)
  │           ├─ [Action 6] RenderActionInitialDraw(dealer+0, 4 tiles)
  │           ├─ [Action 7] RenderActionInitialDraw(dealer+1, 4 tiles)
  │           ├─ ... (16 iterations total: 12×4 tiles + 4×1 tile)
  │           └─ [Action 17] RenderActionFlipDeadWallMark(110)
  │
  └─> Creates: ClientRoundState(info, ...)
      └─> Creates: RoundState
          └─> Initializes tiles[0..111] (types unknown, all NONE)

═══════════════════════════════════════════════════════════════════════════════
TIME 0.0s: TILE ASSIGNMENT PHASE (52 messages)
═══════════════════════════════════════════════════════════════════════════════

[ServerRoundState.start(time)]
  ├─> Calls: validator.start()
  │   └─> Deals 13 tiles to each player's hand
  │
  ├─> Calls: initial_draw()
  │   └─> For each player (0, 1, 2, 3):
  │       └─> Emits: game_initial_draw(player_index, hand[13 tiles])
  │
  └─> [Signal received by ServerGameRound.game_initial_draw()]

─────────────────────────────────────────────────────────────────────────────
Player 0's tiles (13 tiles):
─────────────────────────────────────────────────────────────────────────────

[ServerGameRound.game_initial_draw(player=0, hand=[tiles 0,4,8,12,16,20,24,28,32,36,40,44,48])]
  └─> For each tile in hand:

      [Tile 0: MAN1]
      ├─> Sends: ServerMessageTileAssignment(tile_ID=0, type=MAN1)
      │
      ▼ Received by all clients
      [Client] ClientRoundState.server_tile_assignment(tile)
      ├─> state.tile_assign(Tile(ID=0, type=MAN1))
      │   └─> Updates: tiles[0].tile_type = MAN1
      │
      └─> Emits: game_tile_assignment(Tile(0, MAN1))
          │
          ▼ Signal received
          [Renderer] GameRenderView.tile_assignment(Tile(0, MAN1))
          ├─> Gets: RenderTile t = tiles[0]
          ├─> Sets: t.tile_type = Tile(0, MAN1)
          └─> Calls: t.reload() ──────> [Loads MAN1 texture, shows face]

      [Tile 4: MAN2]
      ├─> Sends: ServerMessageTileAssignment(tile_ID=4, type=MAN2)
      ▼ (same flow as above)

      [Tile 8: MAN3]
      ├─> Sends: ServerMessageTileAssignment(tile_ID=8, type=MAN3)
      ▼ (same flow)

      ... (continues for all 13 tiles in player 0's hand)

─────────────────────────────────────────────────────────────────────────────
Player 1's tiles (13 tiles):
─────────────────────────────────────────────────────────────────────────────

[ServerGameRound.game_initial_draw(player=1, hand=[tiles 1,5,9,13,17,21,25,29,33,37,41,45,49])]
  └─> For each tile in hand:

      [Tile 1: PIN1]
      ├─> Sends: ServerMessageTileAssignment(tile_ID=1, type=PIN1)
      ▼ (same client processing as player 0)

      [Tile 5: PIN2]
      ├─> Sends: ServerMessageTileAssignment(tile_ID=5, type=PIN2)
      ▼

      ... (continues for all 13 tiles)

─────────────────────────────────────────────────────────────────────────────
Player 2's tiles (13 tiles):
─────────────────────────────────────────────────────────────────────────────

[ServerGameRound.game_initial_draw(player=2, hand=[tiles 2,6,10,14,18,22,26,30,34,38,42,46,50])]
  └─> For each tile: (same pattern, 13 ServerMessageTileAssignment messages)

─────────────────────────────────────────────────────────────────────────────
Player 3's tiles (13 tiles):
─────────────────────────────────────────────────────────────────────────────

[ServerGameRound.game_initial_draw(player=3, hand=[tiles 3,7,11,15,19,23,27,31,35,39,43,47,51])]
  └─> For each tile: (same pattern, 13 ServerMessageTileAssignment messages)

─────────────────────────────────────────────────────────────────────────────
TOTAL MESSAGES SENT: 52 ServerMessageTileAssignment (+ 1 for dead wall mark = 53)
NO ServerMessageTileDraw messages sent during this phase!
─────────────────────────────────────────────────────────────────────────────

═══════════════════════════════════════════════════════════════════════════════
TIME 0.5s: ANIMATION PHASE BEGINS (Renderer processes buffered actions)
═══════════════════════════════════════════════════════════════════════════════

[GameScene.process(delta)]  ─ Executes action queue sequentially
  │
  ├─> [Action 0] RenderActionDelay(0.5s)
  │   └─> Waits 0.5s (no visual action)
  │
  ▼ TIME 0.5s
  │
  ├─> [Action 1] RenderActionSplitDeadWall
  │   └─> GameScene.action_split_dead_wall()
  │       ├─> Plays: slide_sound
  │       └─> wall.split_dead_wall(timings.split_wall)
  │           ├─> Calculates: start_wall = (4 - dealer) % 4 = 0
  │           ├─> Calculates split position from wall_index = 3
  │           ├─> Creates: draw_parts[0..3] (104 tiles for drawing)
  │           ├─> Creates: dead_parts[0] (8 tiles for dead wall)
  │           └─> Animates: gap between draw and dead sections
  │
  ▼ TIME 1.5s (after split_wall animation completes)
  │
  ├─> [Action 2] RenderActionInitialDraw(player=0, tiles=4)
  │   └─> GameScene.action_initial_draw(player=0, tiles=4)
  │       ├─> Plays: draw_sound
  │       └─> For i in 0..3:
  │           └─> player[0].draw_tile(wall.draw_wall())
  │               │
  │               ├─> wall.draw_wall() returns: tiles[0] ───┐
  │               │                                          │
  │               ├─> RenderPlayer.draw_tile(tiles[0])      │
  │               │   └─> hand.draw_tile(tiles[0])          │
  │               │       ├─> wrap.convert_object(tiles[0]) │ ← Physical tile moves from wall to hand
  │               │       ├─> drawn = 1                     │
  │               │       ├─> tiles.add(tiles[0])          │
  │               │       ├─> sort_hand()                   │ ← SORTING: sorts by tile_type
  │               │       │   └─> tiles = sort_tiles(tiles) │   (tiles[0] is MAN1, stays first)
  │               │       └─> order_hand(animate=true)      │ ← POSITIONING: arranges visually
  │               │           └─> For each tile in hand:    │
  │               │               └─> order_tile(tile, i, animate=true)
  │               │                   └─> tile.animate_towards(pos, rot, time)
  │               │
  │               ├─> wall.draw_wall() returns: tiles[4] ───┤
  │               │   [Same process: tile 4 (MAN2) added, sorted, positioned]
  │               │
  │               ├─> wall.draw_wall() returns: tiles[8] ───┤
  │               │   [Tile 8 (MAN3) added, sorted, positioned]
  │               │
  │               └─> wall.draw_wall() returns: tiles[12] ──┘
  │                   [Tile 12 (MAN4) added, sorted, positioned]
  │
  ▼ TIME 1.6s
  │
  ├─> [Action 3] RenderActionInitialDraw(player=1, tiles=4)
  │   └─> (Same process for player 1: draws tiles[1,5,9,13])
  │
  ▼ TIME 1.7s
  │
  ├─> [Action 4] RenderActionInitialDraw(player=2, tiles=4)
  │   └─> (Same process for player 2: draws tiles[2,6,10,14])
  │
  ▼ TIME 1.8s
  │
  ├─> [Action 5] RenderActionInitialDraw(player=3, tiles=4)
  │   └─> (Same process for player 3: draws tiles[3,7,11,15])
  │
  ▼ TIME 1.9s - 5.3s: Continue iterations 2-11 (each player draws 4 more tiles, twice)
  │   [After iteration 11: each player has 12 tiles]
  │
  ▼ TIME 5.4s
  │
  ├─> [Action 14] RenderActionInitialDraw(player=0, tiles=1)
  │   └─> Player 0 draws 13th tile (tiles[48])
  │       └─> hand.draw_tile(tiles[48])
  │           ├─> drawn = 13
  │           ├─> tiles.add(tiles[48])
  │           ├─> sort_hand()
  │           └─> order_hand(animate=true)
  │
  ▼ TIME 5.5s - 5.8s: Players 1-3 draw their 13th tiles
  │
  ▼ TIME 5.9s
  │
  └─> [Action 18] RenderActionFlipDeadWallMark(mark_tile_id=110)
      └─> GameScene.action_flip_dead_wall_mark(110)
          └─> wall.flip_dead_wall_mark(110)
              ├─> Finds tile 110 in dead_parts[0]
              ├─> Gets index in dead wall array
              └─> tile.animate_towards(pos, rot × Quat.euler(0,1,0), time)
                  └─> Rotates tile face-up, reveals tile type

═══════════════════════════════════════════════════════════════════════════════
TIME 6.0s: GAMEPLAY BEGINS - PLAYER 0's TURN
═══════════════════════════════════════════════════════════════════════════════

[ServerRoundState.next_turn()]
  ├─> Gets: current_player = validator.get_current_player() → player[0]
  ├─> Calls: tile = validator.draw_wall() → tile[52] (next in sequence)
  ├─> Logs: TileDrawServerAction(player=0, tile_ID=52)
  ├─> Emits: game_draw_tile(player_index=0, tile=52, open=false)
  │   │
  │   └─> [Signal received by ServerGameRound.game_draw_tile()]
  │
  ├─> Queues: turn_decision(player_index=0)
  └─> Adds delay: timings.tile_draw.total()

[ServerGameRound.game_draw_tile(player=0, tile=52, open=false)]
  └─> For each client:

      ┌─> IF (reveal_all_tiles OR player==0 OR spectator OR open):
      │   └─> Sends: ServerMessageTileAssignment(tile_ID=52, type=SOU1)
      │
      └─> Sends: ServerMessageTileDraw(tile_ID=52) ← EVERYONE gets this

─────────────────────────────────────────────────────────────────────────────
CLIENT PROCESSING: Tile Assignment (Player 0 and spectators only)
─────────────────────────────────────────────────────────────────────────────

[Client Player 0] receives ServerMessageTileAssignment(52, SOU1)
  ├─> state.tile_assign(Tile(52, SOU1))
  └─> Emits: game_tile_assignment(Tile(52, SOU1))
      └─> [Renderer] tiles[52].tile_type = Tile(52, SOU1)
          └─> tiles[52].reload() ──────> [Loads SOU1 texture]

[Client Player 1,2,3] NO assignment message (tile stays face-down for opponents)

─────────────────────────────────────────────────────────────────────────────
CLIENT PROCESSING: Tile Draw (ALL clients)
─────────────────────────────────────────────────────────────────────────────

[All Clients] receive ServerMessageTileDraw(tile_ID=52)
  │
  └─> ClientRoundState.server_tile_draw(message)
      ├─> Calls: decision_finished() ← Clears UI buttons
      ├─> Calls: tile = state.tile_draw()
      │   └─> Advances current player, updates game state
      │
      └─> Emits: game_tile_draw(player_index=0, tile_ID=52)
          │
          ▼ Signal received
          [Renderer] GameRenderView.tile_draw(player_index=0, tile_ID=52)
          ├─> Gets: player = players[0]
          ├─> Gets: tile = tiles[52] ← (already has type assigned)
          └─> Buffers: RenderActionDraw(timings.tile_draw, player)

[GameScene.process(delta)]
  └─> Executes: RenderActionDraw
      └─> GameScene.action_draw(player=0)
          ├─> Plays: draw_sound
          ├─> Calls: player[0].draw_tile(wall.draw_wall())
          │   └─> wall.draw_wall() returns tiles[52] ← Physical tile from wall
          │       └─> RenderHand.draw_tile(tiles[52])
          │           ├─> wrap.convert_object(tiles[52]) ← Moves to hand
          │           ├─> drawn = 14 ← 14th tile!
          │           ├─> sort_hand() ← Sorts 13 tiles in hand (NOT 14th)
          │           ├─> order_hand(animate=true) ← Positions 13 tiles
          │           ├─> order_draw_tile(tiles[52]) ← Positions 14th separately
          │           │   └─> pos = Vec3((...), 0, -(tile_size.z + tile_size.x)/2)
          │           │   └─> rot = Quat.from_euler(0.5, 0, 0) ← 90° tilt
          │           │   └─> tile.animate_towards(pos, rot, time)
          │           └─> tiles.add(tiles[52])
          │
          └─> IF player is observer:
              └─> active = true ← Enable tile selection UI

[Client Player 0] UI becomes active, can select tiles

═══════════════════════════════════════════════════════════════════════════════
TIME 6.5s: PLAYER 0 DISCARDS TILE
═══════════════════════════════════════════════════════════════════════════════

[Client Player 0] User clicks on tiles[52] (the drawn tile)
  └─> GameRenderView.mouse_event()
      └─> Emits: tile_selected(Tile(52, SOU1))
          └─> ClientRoundState.client_tile_selected(Tile(52, SOU1))
              ├─> Calls: do_select_discard_tile(tile)
              │   ├─> decision_finished() ← Clear UI
              │   └─> do_discard_tile(tile)
              │       └─> do_action(TileDiscardClientAction(tile_ID=52))
              │           └─> [Signal to GameController]
              │               └─> connection.send_message(ClientMessageGameAction(TileDiscardClientAction(52)))

─────────────────────────────────────────────────────────────────────────────
SERVER PROCESSING: Discard
─────────────────────────────────────────────────────────────────────────────

[Server] receives ClientMessageGameAction from Player 0
  └─> ClientMessageParser.execute()
      └─> ServerGameRound.client_action(player=0, action)
          └─> round.buffer_action(ClientServerAction(player=0, TileDiscardClientAction(52)))

[Server] RegularServerRoundState.next_player_action(time)
  └─> Processes buffered action:
      └─> ServerRoundState.client_tile_discard(action)
          ├─> Validates: is_players_turn(0) → true
          ├─> Validates: discard_tile(52) → true
          ├─> Logs: TileDiscardClientAction(player=0, tile_ID=52)
          └─> Calls: tile_discard(tiles[52])
              ├─> Adds delay: timings.tile_discard.total()
              ├─> Emits: game_discard_tile(tile=52)
              │   │
              │   └─> [Signal received by ServerGameRound.game_discard_tile()]
              │
              └─> Calls: queue_call_decisions()

[ServerGameRound.game_discard_tile(tile=52)]
  ├─> Calls: game_reveal_tile(tile=52) ← Reveal to ALL players
  │   └─> Sends: ServerMessageTileAssignment(52, SOU1) → ALL clients
  │
  └─> Sends: ServerMessageTileDiscard(tile_ID=52) → ALL clients

─────────────────────────────────────────────────────────────────────────────
CLIENT PROCESSING: Tile Assignment (for opponents who didn't see it)
─────────────────────────────────────────────────────────────────────────────

[Client Player 1,2,3] receive ServerMessageTileAssignment(52, SOU1)
  └─> state.tile_assign(Tile(52, SOU1))
      └─> Emits: game_tile_assignment(Tile(52, SOU1))
          └─> [Renderer] tiles[52].tile_type = Tile(52, SOU1)
              └─> tiles[52].reload() ──────> [NOW they see the face]

[Client Player 0] Already has assignment, skips

─────────────────────────────────────────────────────────────────────────────
CLIENT PROCESSING: Discard (ALL clients)
─────────────────────────────────────────────────────────────────────────────

[All Clients] receive ServerMessageTileDiscard(tile_ID=52)
  │
  └─> ClientRoundState.server_tile_discard(message)
      ├─> Calls: decision_finished()
      ├─> Calls: state.tile_discard(tile_ID=52)
      │   └─> Updates game state (current player discarded)
      │
      └─> Emits: game_tile_discard(player_index=0, tile_ID=52)
          │
          ▼ Signal received
          [Renderer] GameRenderView.tile_discard(player_index=0, tile_ID=52)
          ├─> Gets: player = players[0]
          ├─> Gets: tile = tiles[52]
          └─> Buffers: RenderActionDiscard(timings.tile_discard, player, tile)

[GameScene.process(delta)]
  └─> Executes: RenderActionDiscard
      └─> GameScene.action_discard(player=0, tile=52)
          ├─> Plays: discard_sound
          └─> Calls: player[0].discard(tiles[52])
              └─> RenderPlayer.discard(tiles[52])
                  ├─> hand.remove(tiles[52]) ← Remove from hand
                  │   ├─> tiles.remove(tiles[52])
                  │   ├─> sort_hand() ← Re-sort remaining 13 tiles
                  │   └─> order_hand(animate=true) ← Re-position
                  │
                  └─> pond.add_tile(tiles[52]) ← Add to discard pond
                      └─> RenderPond.add_tile(tiles[52])
                          ├─> convert_object(tiles[52]) ← Move to pond space
                          ├─> tiles.add(tiles[52])
                          └─> arrange_pond()
                              ├─> Calculates grid position:
                              │   ├─ i = 0 (first discard)
                              │   ├─ width = -3 * tile_size.x
                              │   ├─ height = 0
                              │   ├─ x = width + tile_size.x/2
                              │   └─ y = height + tile_size.z/2
                              ├─> pos = Vec3(x, 0, y)
                              ├─> rot = Quat.from_euler(0, 0, 0) ← Upright
                              └─> tile.animate_towards(pos, rot, time)

═══════════════════════════════════════════════════════════════════════════════
TIME 7.0s: CALL DECISIONS
═══════════════════════════════════════════════════════════════════════════════

[Server] ServerRoundState.call_decisions()
  ├─> Calls: validator.do_player_calls()
  │   └─> Checks each player for possible calls:
  │       ├─> Player 1: can_pon(SOU1) → TRUE (has 2× SOU1 in hand)
  │       ├─> Player 2: can_pon(SOU1) → FALSE
  │       └─> Player 3: can_pon(SOU1) → FALSE
  │
  └─> For each player who can call:
      └─> Emits: game_get_call_decision(player_index=1)
          │
          └─> [Signal received by ServerGameRound.game_get_call_decision()]
              └─> Sends: ServerMessageCallDecision → Player 1 ONLY

[Client Player 1] receives ServerMessageCallDecision
  └─> ClientRoundState.server_call_decision(message)
      └─> do_call_decision(tile=52, discard_player=0)
          ├─> action_state = State.CALL
          ├─> Checks: can_pon(player 1) → true
          └─> Emits UI signals:
              ├─> set_pon_state(true) ← Show PON button
              ├─> set_continue_state(true) ← Show CONTINUE button
              └─> set_timer_state(true) ← Start decision timer

[Client Player 1] UI shows PON and CONTINUE buttons

═══════════════════════════════════════════════════════════════════════════════
TIME 7.5s: PLAYER 1 CLICKS PON
═══════════════════════════════════════════════════════════════════════════════

[Client Player 1] User clicks PON button
  └─> GameMenuView.pon_pressed() signal
      └─> ClientRoundState.client_pon()
          ├─> Checks: action_state == State.CALL → true
          ├─> Calls: decision_finished() ← Clear UI
          └─> Calls: do_action(PonClientAction())
              └─> [Signal to GameController]
                  └─> connection.send_message(ClientMessageGameAction(PonClientAction()))

─────────────────────────────────────────────────────────────────────────────
SERVER PROCESSING: Pon Call
─────────────────────────────────────────────────────────────────────────────

[Server] receives ClientMessageGameAction from Player 1
  └─> round.buffer_action(ClientServerAction(player=1, PonClientAction()))

[Server] ServerRoundState.client_pon(action)
  ├─> Validates: can_call(player=1) → true
  ├─> Validates: decide_pon(player=1) → true
  │   └─> validator.decide_pon(1)
  │       └─> Marks player 1's call decision as PON
  ├─> Logs: PonClientAction(player=1)
  └─> Calls: check_calls_done()

[Server] ServerRoundState.check_calls_done()
  ├─> Checks: validator.calls_finished → true (all players responded)
  ├─> Gets: result = validator.get_call()
  │   └─> Returns: CallResult
  │       ├─ call_type: PON
  │       ├─ caller: player[1]
  │       ├─ discarder: player[0]
  │       ├─ discard_tile: tiles[52]
  │       └─ tiles: [tiles[10], tiles[11], tiles[52]]
  │           ├─ tiles[10]: SOU1 from player 1's hand (tile ID 10)
  │           ├─ tiles[11]: SOU1 from player 1's hand (tile ID 11)
  │           └─ tiles[52]: SOU1 from player 0's discard
  │
  └─> Emits: game_pon(caller.index=1, tiles=[10, 11, 52])
      │
      └─> [Signal received by ServerGameRound.game_pon()]

[ServerGameRound.game_pon(player_index=1, tiles=[10,11,52])]
  ├─> For each tile in tiles:
  │   └─> Calls: game_reveal_tile(tile) ← Reveal all 3 tiles
  │       ├─> Sends: ServerMessageTileAssignment(10, SOU1) → ALL
  │       ├─> Sends: ServerMessageTileAssignment(11, SOU1) → ALL
  │       └─> Sends: ServerMessageTileAssignment(52, SOU1) → ALL (redundant but ok)
  │
  └─> Sends: ServerMessagePon(player_index=1, tile_1_ID=10, tile_2_ID=11) → ALL

NOTE: tile[52] is NOT sent in ServerMessagePon because server knows it's the discard

─────────────────────────────────────────────────────────────────────────────
CLIENT PROCESSING: Tile Assignments
─────────────────────────────────────────────────────────────────────────────

[All Clients] receive tile assignments:
  ├─> ServerMessageTileAssignment(10, SOU1)
  ├─> ServerMessageTileAssignment(11, SOU1)
  └─> ServerMessageTileAssignment(52, SOU1)
      └─> (Same pattern: assign type, reload texture)

─────────────────────────────────────────────────────────────────────────────
CLIENT PROCESSING: Pon Action (ALL clients)
─────────────────────────────────────────────────────────────────────────────

[All Clients] receive ServerMessagePon(player=1, tile_1=10, tile_2=11)
  │
  └─> ClientRoundState.server_pon(message)
      ├─> Calls: decision_finished()
      ├─> Gets: discard_index = state.current_player.index → 0
      ├─> Calls: state.pon(player=1, tile_1=10, tile_2=11)
      │   └─> Updates game state (player 1 made pon call)
      │
      └─> Emits: game_pon(player_index=1, discard_player=0, tile_ID=52, tile_1=10, tile_2=11)
          │
          ▼ Signal received
          [Renderer] GameRenderView.pon(player=1, discarder=0, tile=52, t1=10, t2=11)
          ├─> Gets: player = players[1]
          ├─> Gets: discard_player = players[0]
          ├─> Gets: tile = tiles[52] ← Discarded tile
          ├─> Gets: tile_1 = tiles[10] ← From hand
          ├─> Gets: tile_2 = tiles[11] ← From hand
          └─> Buffers: RenderActionPon(timings.call, player=1, discarder=0, 
                                       tile=52, tile_1=10, tile_2=11)

[GameScene.process(delta)]
  └─> Executes: RenderActionPon
      └─> GameScene.action_pon(player=1, discarder=0, tile=52, t1=10, t2=11)
          ├─> Plays: pon_sound
          ├─> Calls: discarder.rob_tile(tiles[52])
          │   └─> RenderPlayer[0].rob_tile(tiles[52])
          │       └─> pond.remove(tiles[52]) ← Remove from pond
          │           ├─> tiles.remove(tiles[52])
          │           └─> arrange_pond() ← Re-arrange remaining tiles
          │
          ├─> Calls: player[1].pon(discarder, tile=52, tile_1=10, tile_2=11)
          │   └─> RenderPlayer[1].pon(discard_player=0, tile=52, t1=10, t2=11)
          │       ├─> hand.remove(tiles[10]) ← Remove from hand
          │       │   └─> (sort + order remaining tiles)
          │       ├─> hand.remove(tiles[11]) ← Remove from hand
          │       │   └─> (sort + order remaining tiles)
          │       ├─> Creates: ArrayList tiles = [tiles[10], tiles[11]]
          │       ├─> Calculates: alignment = players_to_alignment(p1, p0)
          │       │   ├─ diff = (0 - 1 + 4) % 4 = 3
          │       │   └─ Returns: Alignment.LEFT (discard from left player)
          │       │
          │       └─> calls.add_call(new RenderCallPon([10,11], 52, tile_size, LEFT))
          │           └─> RenderCallPon constructor:
          │               ├─ alignment = LEFT → n = 2
          │               └─ tiles.insert(2, tiles[52]) ← Insert discard at position 2
          │                   └─ tiles array: [10, 11, 52]
          │
          └─> IF player is observer:
              └─> active = true

[RenderCalls.add_call(pon_call)]
  └─> RenderCalls.add_call(pon_call)
      ├─> add_object(pon_call) ← Add to scene
      ├─> calls.add(pon_call)
      └─> arrange() ← Arrange all calls
          └─> For each call in calls:
              ├─> call.animate_to(-height, time)
              └─> call.arrange(time)

[RenderCallPon.arrange(time)]
  └─> For each tile (i = 0, 1, 2):
      
      ├─> [i=0, n=2] tiles[10]: Normal upright tile
      │   ├─ x = 0 + tile_size.x/2
      │   ├─ z = tile_size.z/2
      │   ├─ rotation = 0
      │   ├─ width = tile_size.x
      │   ├─ pos = Vec3(-x, 0, -z)
      │   ├─ rot = Quat.from_euler(0, 0, 0)
      │   └─ tile.animate_towards(pos, rot, time)
      │
      ├─> [i=1, n=2] tiles[11]: Normal upright tile
      │   ├─ x = tile_size.x + tile_size.x/2
      │   ├─ z = tile_size.z/2
      │   ├─ rotation = 0
      │   ├─ width = 2*tile_size.x
      │   ├─ pos = Vec3(-x, 0, -z)
      │   ├─ rot = Quat.from_euler(0, 0, 0)
      │   └─> tile.animate_towards(pos, rot, time)
      │
      └─> [i=2, n=2] tiles[52]: ROTATED tile (from discard)
          ├─ x = 2*tile_size.x + tile_size.z/2
          ├─ z = tile_size.x/2
          ├─ rotation = 0.5 (90°)
          ├─ width = 2*tile_size.x + tile_size.z
          ├─ pos = Vec3(-x, 0, -z)
          ├─ rot = Quat.from_euler(0.5, 0, 0)
          └─> tile.animate_towards(pos, rot, time)

═══════════════════════════════════════════════════════════════════════════════
VISUAL RESULT: Pon Call Layout (Player 1's calls area)
═══════════════════════════════════════════════════════════════════════════════

    ┌───────┐ ┌───────┐ ╔═══════╗
    │ SOU1  │ │ SOU1  │ ║ SOU1  ║
    │  [10] │ │  [11] │ ║  [52] ║ ← Rotated 90° (from player 0's discard)
    │       │ │       │ ║       ║
    └───────┘ └───────┘ ╚═══════╝

    Position determined by alignment (LEFT = discard came from player 0, 
    who sits to player 1's left)

═══════════════════════════════════════════════════════════════════════════════
COMPLETE. Player 1's turn begins next.
═══════════════════════════════════════════════════════════════════════════════
```

---

## Summary: Critical Observations

### 1. Initial Dealing Messages
- **52 `ServerMessageTileAssignment`** (one per tile in each player's hand)
- **0 `ServerMessageTileDraw`** (none during initial dealing!)

### 2. Tile Draw During Gameplay
- **1 `ServerMessageTileAssignment`** (only to viewers who should see it)
- **1 `ServerMessageTileDraw`** (to everyone, triggers animation)

### 3. Wall Drawing Mechanism
- `wall.draw_wall()` returns **physical RenderTile objects**
- Tiles already have their types assigned via `ServerMessageTileAssignment`
- The renderer just **moves** tiles from wall → hand/calls

### 4. Sorting & Positioning
- **Sorting**: Uses `tile_type` comparison
- **Positioning**: Uses array index (tile position in sorted array)
- Happens **every time** a tile is added/removed from hand

### 5. Action Buffering
- All actions buffer via `GameScene.add_action()`
- Execute **sequentially** (one at a time)
- Each action has a **duration** before next starts

### 6. Call Tile Order
- Server sends: `(player_index, tile_1_ID, tile_2_ID)` (from hand only)
- Server knows discard tile implicitly (it's `state.discard_tile`)
- Client reconstructs: `(player, discarder, discard_tile, tile_1, tile_2)`
- Renderer inserts discard at position based on **alignment**

---

## Key Takeaway for Replay

Replay MUST:
1. Send ALL 112 tile assignments upfront (before any animations)
2. Let renderer's buffered `RenderActionInitialDraw` handle initial dealing
3. Send `TileDraw` messages ONLY for gameplay draws (not initial dealing)
4. Respect the wall's physical tile order
