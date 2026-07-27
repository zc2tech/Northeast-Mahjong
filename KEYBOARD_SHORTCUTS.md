# Keyboard Shortcuts

## Menu Navigation

### Main Menu
| Key | Action | Description |
|-----|--------|-------------|
| **S** | Singleplayer | Open singleplayer menu |
| **M** | Multiplayer | Open multiplayer menu |
| **O** | Options | Open options menu |
| **A** | About | Show about information |
| **E** | Exit | Exit the application |

### Singleplayer Menu
| Key | Action | Description |
|-----|--------|-------------|
| **C** | Create Game | Create a new singleplayer game |
| **L** | Load Log | Load a game from log file |
| **B** | Back | Return to main menu |

### Create Server Menu
| Key | Action | Description |
|-----|--------|-------------|
| **C** | Create | Create the server (only when player name is valid) |
| **B** | Back | Return to previous menu |

### Server Menu
| Key | Action | Description |
|-----|--------|-------------|
| **S** | Settings | Open server settings (only when settings are loaded) |
| **T** | Start | Start the game (only when all 4 players are ready) |
| **B** | Back | Close server and return to previous menu |

**Note**: Keyboard shortcuts are scene-specific and only work for buttons that exist in the current menu. 

**Important**: Parent menu shortcuts are automatically disabled when a child menu is shown. For example:
- When you're in the "Create Server" scene (child of Singleplayer menu), pressing 'B' will NOT go back to the Singleplayer menu
- Only the "Create Server" scene's own Back button (or 'B' shortcut if defined) will work
- Parent menu keyboard shortcuts only work when their buttons are visible

This prevents unintended navigation when you're in nested menus.

## Command-Line Options

Run `./Northeast-Mahjong --help` to see all available options:

```
Usage: Northeast-Mahjong [OPTIONS]

Options:
  -h, --help                    Show this help message
  -d, --debug                   Enable debug mode
  --no-debug                    Disable debug mode
  --test                        Run hand tests and exit
  --bot-simulation [N]          Bot simulation mode (config: bot_simulation.conf)
  --bots [N]                    Alias for --bot-simulation
  --multithread-rendering       Enable multithreaded rendering
  --no-multithread-rendering    Disable multithreaded rendering
  --search-directory <DIR>      Add custom search directory
```

### Bot Simulation Configuration

**Config File**: `bot_simulation.conf`

The bot simulation can be configured using a config file located in the executable directory. The config file specifies:
- Number of hands to simulate
- Bot type for each of 4 players (SimpleBot, JulianBot, NullBot)
- Player names

**Command-line override**: Using `--bot-simulation N` or `--bots N` will override the `hands` setting in the config file.

**Example config**:
```
hands=10
player1=JulianBot
player1_name=Julian
player2=SimpleBot
player2_name=Simple1
player3=JulianBot
player3_name=Julian2
player4=SimpleBot
player4_name=Simple2
```

**Bot Types**:
- **SimpleBot**: Medium intelligence, makes strategic decisions
- **JulianBot**: Advanced bot with hand analysis and half-sequence counting
- **NullBot**: Minimal bot, always discards default tile and never calls

**Note on Bot Simulation**: The `--bot-simulation` feature is planned but not yet fully implemented. It requires exposing more APIs from RoundState for automated play. For now, you can start a local server and manually add 4 bots to watch them play.

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
- **Menu navigation**: 
  - `source/MainMenu/MainMenuView.vala` (lines 47-71)
  - `source/MainMenu/SingleplayerMenuView.vala` (lines 29-50)
  - `source/MainMenu/CreateServerView.vala` (lines 17-37)
  - `source/MainMenu/ServerMenuView.vala` (lines 87-109)
- **Command-line parsing**: `source/main.vala` (lines 17-64)
- **Bot config loading**: `source/main.vala` (lines 84-154)
- **Game actions**: `source/Game/Rendering/Menu/GameMenuView.vala` (lines 178-210)
- **Camera controls**: `source/Game/Rendering/GameRenderView.vala` (lines 136-178)

Shortcuts follow button state - they are only active when the corresponding button is enabled and visible on screen. The key handling system uses `key.handled` flag to prevent event bubbling when a shortcut is processed.
