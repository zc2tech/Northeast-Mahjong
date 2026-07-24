# Building Northeast-Mahjong on macOS (Updated 2026)

This project has been updated to build and run on modern macOS systems.

## Prerequisites

1. Install [Homebrew](https://brew.sh) if you haven't already
2. Install Xcode Command Line Tools: `xcode-select --install`

## Quick Setup

Install all required dependencies with Homebrew:

```bash
brew install vala meson pkg-config libgee gtk+3 sdl2 sdl2_image sdl2_mixer glew pango ninja
```

## Building

1. Clone the repository with submodules:
```bash
git clone --recurse-submodules https://github.com/zc2tech/Northeast-Mahjong.git
cd Northeast-Mahjong
```

2. Configure the build:
```bash
meson setup build -Dbuildtype=release
```

3. Build the project:
```bash
ninja -C build
```

## Running

Use the convenient launch script:
```bash
./run.sh
```

Or run directly:
```bash
./build/Northeast-Mahjong --working-directory bin
```

## Changes Made for macOS Compatibility

The following fix was applied to `Engine/meson.build` to ensure proper OpenGL bindings on macOS:

- Added macOS-specific handling for the GL VAPI library (similar to Windows)
- macOS now uses the custom `gl.vapi` file from `Engine/vapi/` directory
- This resolves "The namespace name 'GL' could not be found" compilation errors

## Troubleshooting

If you encounter any issues:

1. Make sure all dependencies are installed: `brew list vala meson libgee gtk+3 sdl2 sdl2_image sdl2_mixer glew pango`
2. Clean the build directory: `rm -rf build`
3. Reconfigure and rebuild

## Notes

- The project builds as a 64-bit ARM binary on Apple Silicon Macs
- The project builds as a 64-bit x86_64 binary on Intel Macs
- Northeast-Mahjong requires the `bin/Data` folder to run, which is automatically located when using `run.sh`
