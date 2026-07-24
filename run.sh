#!/bin/bash
# Launch script for Northeast-Mahjong on macOS
# This ensures the Data directory is found

cd "$(dirname "$0")"
./build/Northeast-Mahjong --working-directory "$(pwd)/bin" "$@"
