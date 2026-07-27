# Bot Simulation Configuration

This document explains how to configure bot players for automated game simulation in Northeast-Mahjong.

## Configuration File

The bot simulation is configured using `bot_simulation.conf`, which should be placed in the same directory as the executable.

### File Format

The config file uses a simple `key=value` format:

```conf
# Number of hands to simulate
hands=10

# Bot types for each player
player1=JulianBot
player2=SimpleBot
player3=JulianBot
player4=SimpleBot

# Custom player names (optional)
player1_name=Julian
player2_name=Simple1
player3_name=Julian2
player4_name=Simple2
```

### Configuration Options

#### hands
- **Type**: Integer
- **Default**: 1
- **Description**: Number of hands to simulate in the automated game
- **Override**: Can be overridden by command-line argument `--bot-simulation N`

#### playerN (where N is 1-4)
- **Type**: String (bot class name)
- **Default**: Varies by player
- **Values**: 
  - `SimpleBot` - Medium intelligence bot
  - `JulianBot` - Advanced bot with hand analysis
  - `NullBot` - Minimal bot that always discards and never calls

#### playerN_name (where N is 1-4)
- **Type**: String
- **Default**: Bot type name
- **Description**: Display name for the player

## Bot Types

### SimpleBot
**Intelligence Level**: Medium

**Strategy**:
- Always wins on tsumo if possible
- Declares void hand when available
- Performs late kan and closed kan when possible
- Calls pon for dragon tiles and seat/round wind tiles (when holding 2)
- Discards tiles to maintain tenpai when possible
- Avoids discarding triplets, valuable tiles, and neighbors
- Prefers discarding isolated tiles and terminal tiles

**Best For**: Balanced gameplay, testing standard game flow

### JulianBot
**Intelligence Level**: Advanced

**Strategy**:
- Uses hand statistics analysis (terminal count, dragon count, pairs, triplets)
- Counts half-sequences across all three suits (man, pin, sou)
- Makes decisions based on hand value potential
- Analyzes tile efficiency and waits
- Strategic calling decisions based on hand composition

**Best For**: Competitive gameplay, testing advanced strategies

### NullBot
**Intelligence Level**: Minimal

**Strategy**:
- Always discards the default tile (rightmost tile)
- Never calls chii, pon, kan, or ron
- Never declares tsumo or void hand

**Best For**: Testing basic game mechanics, debugging, performance testing

## Command-Line Usage

### Use config file defaults
```bash
./Northeast-Mahjong --bot-simulation
```

### Override number of hands
```bash
./Northeast-Mahjong --bot-simulation 50
# or
./Northeast-Mahjong --bots 50
```

The command-line argument takes precedence over the `hands` setting in the config file.

## Example Configurations

### All JulianBots (competitive)
```conf
hands=100
player1=JulianBot
player2=JulianBot
player3=JulianBot
player4=JulianBot
player1_name=Julian1
player2_name=Julian2
player3_name=Julian3
player4_name=Julian4
```

### Mixed difficulty
```conf
hands=20
player1=JulianBot
player2=SimpleBot
player3=SimpleBot
player4=NullBot
player1_name=Expert
player2_name=Medium1
player3_name=Medium2
player4_name=Beginner
```

### Performance testing (all NullBots)
```conf
hands=1000
player1=NullBot
player2=NullBot
player3=NullBot
player4=NullBot
```

## Current Status

**Note**: The bot simulation feature is currently in development. The configuration file and command-line parsing are fully implemented, but the actual automated gameplay loop is not yet complete. 

To test bots:
1. Start a local server through the main menu
2. Manually add 4 bots from the server interface
3. Watch them play

Full automated simulation (running multiple hands from command-line) will be available in a future update.

## Implementation Details

- **Config Parser**: `source/main.vala` lines 84-154
- **Bot Implementations**: 
  - `source/GameServer/Bots/SimpleBot.vala`
  - `source/GameServer/Bots/JulianBot.vala`
  - `source/GameServer/Bots/NullBot.vala`
- **Bot Base Class**: `source/GameServer/Bots/Bot.vala`
