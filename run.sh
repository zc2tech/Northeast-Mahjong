#!/bin/bash
# Launch script for OpenRiichi on macOS
# This ensures the Data directory is found

cd "$(dirname "$0")"
./build/OpenRiichi --working-directory "$(pwd)/bin" "$@"
