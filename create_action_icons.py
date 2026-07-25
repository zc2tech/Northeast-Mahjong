#!/usr/bin/env python3
"""Generate action button icons for Northeast Mahjong"""

from PIL import Image, ImageDraw, ImageFont
import os

# Icon size
ICON_WIDTH = 120
ICON_HEIGHT = 60
BG_COLOR = (40, 40, 40, 180)  # Semi-transparent dark background
TEXT_COLOR = (255, 255, 255, 255)  # White text

output_dir = "bin/Data/Textures/Actions"
os.makedirs(output_dir, exist_ok=True)

def create_text_icon(text, filename):
    """Create a simple text-based icon"""
    img = Image.new('RGBA', (ICON_WIDTH, ICON_HEIGHT), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # Try to use a bold font, fallback to default
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 32)
    except:
        font = ImageFont.load_default()

    # Center the text
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = (ICON_WIDTH - text_width) // 2
    y = (ICON_HEIGHT - text_height) // 2 - 5

    draw.text((x, y), text, fill=TEXT_COLOR, font=font)

    # Save
    img.save(os.path.join(output_dir, filename))
    print(f"Created {filename}")

def create_tile_icon(tile_names, filename):
    """Create an icon showing small tile representations"""
    img = Image.new('RGBA', (ICON_WIDTH, ICON_HEIGHT), BG_COLOR)

    # Load tile images
    tile_dir = "bin/Data/Textures/Tiles/Regular"
    tiles = []
    for tile_name in tile_names:
        tile_path = os.path.join(tile_dir, f"{tile_name}.png")
        if os.path.exists(tile_path):
            tile_img = Image.open(tile_path).convert('RGBA')
            tiles.append(tile_img)

    if not tiles:
        # Fallback to text if tiles not found
        return create_text_icon(filename.replace('.png', ''), filename)

    # Calculate tile display size
    tile_width = ICON_WIDTH // len(tiles) - 5

    # Paste tiles
    x_offset = 5
    for tile in tiles:
        # Resize tile to fit
        aspect = tile.height / tile.width
        resized_tile = tile.resize((tile_width, int(tile_width * aspect)), Image.Resampling.LANCZOS)

        # Center vertically
        y_offset = (ICON_HEIGHT - resized_tile.height) // 2
        img.paste(resized_tile, (x_offset, y_offset), resized_tile)
        x_offset += tile_width + 2

    # Save
    img.save(os.path.join(output_dir, filename))
    print(f"Created {filename}")

# Create icons
print("Creating action icons...")

# Chii - 3 consecutive tiles (e.g., Man4-5-6)
create_tile_icon(['Man4', 'Man5', 'Man6'], 'Chii.png')

# Pon - 3 identical tiles (e.g., Hatsu x3)
create_tile_icon(['Hatsu', 'Hatsu', 'Hatsu'], 'Pon.png')

# Kan - 4 identical tiles (e.g., Chun x4)
create_tile_icon(['Chun', 'Chun', 'Chun', 'Chun'], 'Kan.png')

# Ron - winning tile (show Haku as winning tile)
create_tile_icon(['Haku'], 'Ron.png')

# Tsumo - self-draw win (show a tile with glow effect)
create_tile_icon(['Hatsu'], 'Tsumo.png')

# Continue - use text
create_text_icon('Continue', 'Continue.png')

# Void Hand - use text or empty tile
create_text_icon('Void', 'VoidHand.png')

print("All action icons created successfully!")
