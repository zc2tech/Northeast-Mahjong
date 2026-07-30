#!/usr/bin/env python3
"""
Analyze game log to check if bots are just discarding what they draw.
This is a simple heuristic analysis looking at the binary log structure.
"""

import sys
import struct
from pathlib import Path

def analyze_log(log_path):
    """Read the binary log and try to identify draw/discard patterns."""

    with open(log_path, 'rb') as f:
        data = f.read()

    print(f"Log file: {log_path}")
    print(f"Size: {len(data)} bytes")
    print()

    # Look for patterns of tile draws and discards
    # In the game log, these should be sequential messages
    # We'll look for repeating byte patterns that might indicate
    # immediate discard-after-draw

    # Try to find tile IDs (0-135 range) in sequences
    tile_sequences = []
    for i in range(len(data) - 1):
        b1 = data[i]
        b2 = data[i + 1]
        # Tile IDs are typically in range 0-135
        if b1 < 136 and b2 < 136:
            tile_sequences.append((i, b1, b2))

    print(f"Found {len(tile_sequences)} potential tile ID pairs")

    # Look for immediate repetitions (draw same as discard)
    immediate_repeats = 0
    for i, (pos, t1, t2) in enumerate(tile_sequences[:-1]):
        next_pos, next_t1, next_t2 = tile_sequences[i + 1]
        # If tile IDs are very close in the file and identical
        if next_pos - pos < 10 and t1 == next_t1:
            immediate_repeats += 1

    print(f"Potential immediate draw-discard patterns: {immediate_repeats}")
    print()

    # Show some sample byte sequences
    print("Sample byte sequences (first 200 bytes):")
    for i in range(0, min(200, len(data)), 20):
        chunk = data[i:i+20]
        hex_str = ' '.join(f'{b:02x}' for b in chunk)
        ascii_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
        print(f"{i:04x}: {hex_str:<60} {ascii_str}")

if __name__ == '__main__':
    if len(sys.argv) > 1:
        log_path = sys.argv[1]
    else:
        # Use the most recent log
        log_dir = Path.home() / '.config/Northeast-Mahjong/logs/game'
        logs = sorted(log_dir.glob('*.log'), key=lambda p: p.stat().st_mtime, reverse=True)
        if not logs:
            print("No log files found")
            sys.exit(1)
        log_path = logs[0]

    analyze_log(log_path)
