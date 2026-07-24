# Debugging Northeast-Mahjong in VSCode on macOS

## Prerequisites

1. **Install the CodeLLDB extension** in VSCode:
   - Open VSCode
   - Go to Extensions (Cmd+Shift+X)
   - Search for "CodeLLDB"
   - Install the extension by Vadim Chugunov

## Debug Configurations

Three debug configurations are available in the Debug panel (Run and Debug):

### 1. **Debug Northeast-Mahjong** (Recommended)
- Automatically rebuilds the project before debugging
- Runs with `--debug` flag for verbose logging
- Use this for most debugging sessions

### 2. **Debug Northeast-Mahjong (no rebuild)**
- Skips the build step
- Faster when you haven't changed any code
- Good for quick repeated debugging sessions

### 3. **Debug Northeast-Mahjong (clean build)**
- Does a full clean rebuild with debug symbols
- Use this if you're having issues with outdated build artifacts
- Slower but ensures everything is fresh

## How to Debug

### Quick Start:
1. Open Northeast-Mahjong project in VSCode
2. Press `F5` or click "Run" → "Start Debugging"
3. Select "Debug Northeast-Mahjong" configuration
4. The debugger will build and launch the game

### Setting Breakpoints:
1. Open a `.vala` source file (e.g., `source/main.vala`)
2. Click in the left margin next to a line number to set a breakpoint (red dot appears)
3. Start debugging (F5)
4. The program will pause when it hits your breakpoint

### Useful Debugging Features:

**Variables Panel:**
- Shows local variables, function arguments
- Hover over variables in the code to see their values

**Call Stack:**
- Shows the function call hierarchy
- Click on frames to navigate the call stack

**Debug Console:**
- Execute LLDB commands directly
- Example: `expr variable_name` to evaluate expressions

**Debug Toolbar:**
- Continue (F5) - Resume execution
- Step Over (F10) - Execute current line, skip into functions
- Step Into (F11) - Step into function calls
- Step Out (Shift+F11) - Step out of current function
- Restart (Cmd+Shift+F5) - Restart debugging session
- Stop (Shift+F5) - Stop debugging

## Building Manually

### Debug Build (with symbols):
```bash
rm -rf build
meson setup build -Dbuildtype=debug
ninja -C build
```

### Release Build (optimized):
```bash
rm -rf build
meson setup build -Dbuildtype=release
ninja -C build
```

## Common Debugging Scenarios

### Debug a Crash:
1. Set breakpoints in relevant code areas
2. Start debugging
3. When crash occurs, check the Call Stack panel
4. Examine variables in the Variables panel

### Debug Startup Issues:
1. Set breakpoint in `source/main.vala` at the `main()` function
2. Step through initialization code
3. Watch the Debug Console for log messages

### Debug Rendering Issues:
1. Set breakpoints in `Engine/Rendering/` files
2. Examine OpenGL state and shader variables
3. Check the debug output for OpenGL errors

## Build Tasks

Available via "Terminal" → "Run Task...":

- **build** - Incremental build (fast)
- **build-debug** - Full clean debug build
- **clean** - Remove build directory

## Notes

- The game runs from the `build/` directory where the `Data` folder is symlinked
- Debug builds are larger and slower but provide better debugging information
- LLDB is the native macOS debugger (superior to GDB on Mac)
- Vala code is compiled to C, so you'll see C variable names in the debugger
- Some optimizations may be disabled in debug mode for better debugging

## Troubleshooting

**"Cannot find executable" error:**
- Run the build task first: Cmd+Shift+B

**Breakpoints not working:**
- Make sure you're using a debug build (`-Dbuildtype=debug`)
- Try a clean rebuild

**CodeLLDB extension not found:**
- Install it from VSCode extensions marketplace
- Restart VSCode after installation
