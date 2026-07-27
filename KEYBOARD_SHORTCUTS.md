# Keyboard Shortcuts

## Game Actions

During gameplay, the following keyboard shortcuts are available for quick actions:

| Key | Action | Description |
|-----|--------|-------------|
| **C** | Chii | Call a sequence (順子) from the previous player's discard |
| **P** | Pon | Call a triplet (刻子) from any player's discard |
| **K** | Kan | Call/declare a quad (槓子) |
| **T** | Tsumo | Declare self-draw win (自摸) |
| **R** | Ron | Declare win on another player's discard (栄和) |
| **Space** | Continue | Continue to next action/screen |
| **V** | Void Hand | Declare void hand (流局) |

**Notes:**
- Shortcuts only work when the corresponding button is visible and enabled
- All shortcuts are case-insensitive
- Shortcuts activate on key press (not on key repeat)

## Other Controls

| Key | Action | Description |
|-----|--------|-------------|
| **Tab** (hold) | Show Scores | Display the current score board |
| **1** | Camera Up | Move camera height up |
| **2** | Camera Down | Move camera height down |
| **3** | Target Up | Move camera target height up |
| **4** | Target Down | Move camera target height down |
| **5** | FOV Increase | Increase field of view |
| **6** | FOV Decrease | Decrease field of view |

**Notes:**
- Camera and target adjustments are saved automatically after 5 seconds
- Hold Tab to keep the score board visible; release to hide it

## Implementation Details

Keyboard shortcuts are implemented in:
- **Game actions**: `source/Game/Rendering/Menu/GameMenuView.vala` (lines 178-210)
- **Camera controls**: `source/Game/Rendering/GameRenderView.vala` (lines 136-178)

Shortcuts follow button state - they are only active when the corresponding button is enabled and visible on screen.
