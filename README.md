# Northeast-Mahjong

This mahjong follows rules of Northeast China.
Currently, it only works under Mac

Use 112 tiles, every wall has 28 tiles. For Dragons, we only choose ONE into walls

## Acknowledgments

This project is based on [OpenRiichi](https://github.com/FluffyStuff/OpenRiichi), an open source [Japanese Mahjong](https://en.wikipedia.org/wiki/Japanese_Mahjong)
client written in the [Vala](https://wiki.gnome.org/Projects/Vala) programming language.
The client is cross platform, with official builds for Windows, Linux, and MacOS. It supports singleplayer and multiplayer, with or without bots.
It features all the standard riichi rules, as well as some optional ones. It also supports game logging, so games can be viewed again.

For more information about the original OpenRiichi project, visit their [GitHub repository](https://github.com/FluffyStuff/OpenRiichi).

# Building

## Setup

### MacOS

On MacOS the client can be built using [Command Line Tools for macOS](https://developer.apple.com/download/more) and [Homebrew](https://brew.sh).

Start by installing Homebrew and the developer tools.

Then run the following commands:
```
brew update
brew install \
git \
vala \
pkg-config \
meson \
ninja \
libgee \
gtk+3 \
sdl2 \
sdl2_image \
sdl2_mixer \
glew \
pango
```

### Linux (Debian based)

Run the following commands:
```
sudo aptitude install -y \
git \
valac \
gcc \
meson \
libgee-0.8-dev \
libgtk-3-dev \
libglew-dev \
libpango1.0-dev \
libsdl2-image-dev \
libsdl2-mixer-dev \
libsdl2-dev
```

## Build

Start by cloning the Northeast-Mahjong repository with: ```git clone --recurse-submodules https://github.com/zc2tech/Northeast-Mahjong.git```

Next, generate a build target with meson using `meson build -Dbuildtype=release` or `meson build -Dbuildtype=debug` depending on whether you want a release or debug build.

Build the target with ninja using: `ninja -C build`

You can also install the target by running: `ninja -C build install`

You can remove the installed target by running: `ninja -C build uninstall`

If the installation build succeeded, you should be able to launch the application by running `OpenRiichi`.

Northeast-Mahjong requires the `Data` folder (found inside the `bin` folder) to be in the one of the search directories. OpenRiichi will add the `Northeast-Mahjong` subdirectory of the default data directory of the OS (usually `/usr/share/Northeast-Mahjong`) to the search path, along with the the current working directory and the executable directory.
An additional search path can be added during runtime by running OpenRiichi with the `--search-directory some_custom_directory` flag.

## IDE

The preferred editor to use is [Visual Studio Code](https://code.visualstudio.com).
It works on all operating systems which are supported for Northeast-Mahjong, and has several extensions for Vala in the Visual Studio Marketplace.

Your `launch.json` should look like the following:
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Debug OpenRiichi",
            "type": "lldb",
            "request": "launch",
            "program": "${workspaceFolder}/build/OpenRiichi",
            "args": [
                "--debug"
            ],
            "cwd": "${workspaceFolder}/bin",
            "stopOnEntry": false,
            "preLaunchTask": "build"
        },
        {
            "name": "Debug OpenRiichi (no rebuild)",
            "type": "lldb",
            "request": "launch",
            "program": "${workspaceFolder}/build/OpenRiichi",
            "args": [
                "--debug"
            ],
            "cwd": "${workspaceFolder}/bin",
            "stopOnEntry": false,
            "environment": [],
            "externalConsole": false
        },
        {
            "name": "Debug OpenRiichi (clean build)",
            "type": "lldb",
            "request": "launch",
            "program": "${workspaceFolder}/build/OpenRiichi",
            "args": [
                "--debug"
            ],
            "cwd": "${workspaceFolder}/bin",
            "stopOnEntry": false,
            "environment": [],
            "externalConsole": false,
            "preLaunchTask": "build-debug"
        }
    ]
}
```


# License

Northeast-Mahjong is licensed under [GPLv3](https://www.gnu.org/licenses/quick-guide-gplv3.en.html), 
the same as the original OpenRiichi project it's based on.
Feel free to make any changes and submit a pull request.
