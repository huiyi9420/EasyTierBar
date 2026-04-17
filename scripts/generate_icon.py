#!/usr/bin/env python3
"""Generate EasyTierBar app icon using Pillow."""
import math
from pathlib import Path
from PIL import Image, ImageDraw

SIZE = 1024
OUT = Path("EasyTierBar/AppIcon.iconset")
OUT.mkdir(parents=True, exist_ok=True)


def rounded_rect(draw, bbox, radius, fill):
    x0, y0, x1, y1 = bbox
    draw.rounded_rectangle(bbox, radius=radius, fill=fill)


def gradient_bg(img):
    """Draw vertical gradient from dark blue to teal."""
    for y in range(SIZE):
        t = y / SIZE
        r = int(20 + t * 10)
        g = int(80 + t * 130)
        b = int(180 - t * 40)
        draw = ImageDraw.Draw(img)
        draw.line([(0, y), (SIZE, y)], fill=(r, g, b))


def draw_icon():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Rounded rectangle background (macOS squircle-ish)
    margin = 80
    radius = 200
    rounded_rect(draw, (margin, margin, SIZE - margin, SIZE - margin),
                 radius, fill=(0, 0, 0, 0))

    # Gradient fill
    for y in range(margin, SIZE - margin):
        t = (y - margin) / (SIZE - 2 * margin)
        r = int(15 + t * 15)
        g = int(70 + t * 140)
        b = int(190 - t * 50)
        draw.line([(margin + radius, y), (SIZE - margin - radius, y)], fill=(r, g, b))
        # left rounded edge
        for x in range(margin, margin + radius + 1):
            dy = abs(y - (margin + radius))
            if dy <= radius:
                dx = int(math.sqrt(radius * radius - dy * dy))
                draw.point((margin + radius - dx, y), fill=(r, g, b))
        # right rounded edge
        for x in range(SIZE - margin - radius, SIZE - margin):
            dy = abs(y - (margin + radius))
            if dy <= radius:
                dx = int(math.sqrt(radius * radius - dy * dy))
                draw.point((SIZE - margin - radius + dx, y), fill=(r, g, b))

    # Re-draw clean rounded rect mask
    mask = Image.new("L", (SIZE, SIZE), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle((margin, margin, SIZE - margin, SIZE - margin),
                            radius=radius, fill=255)

    # Apply gradient to rounded rect shape
    final = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    grad = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(grad)
    for y in range(SIZE):
        t = y / SIZE
        r = int(15 + t * 20)
        g = int(60 + t * 150)
        b = int(200 - t * 60)
        gdraw.line([(0, y), (SIZE, y)], fill=(r, g, b, 255))
    final.paste(grad, mask=mask)
    draw = ImageDraw.Draw(final)

    # --- Antenna tower ---
    cx, cy = SIZE // 2, SIZE // 2 - 40
    white = (255, 255, 255, 240)

    # Tower body (vertical line)
    tw, tb = cx, cy + 30
    tlen = 280
    draw.line([(tw, tb), (tw, tb - tlen)], fill=white, width=10)

    # Tower top point
    top_y = tb - tlen
    draw.ellipse([tw - 12, top_y - 12, tw + 12, top_y + 12], fill=white)

    # Cross bars on tower
    for i in range(3):
        yy = tb - 80 - i * 70
        hw = 60 - i * 12
        draw.line([(tw - hw, yy), (tw + hw, yy)], fill=white, width=6)
        # diagonal supports
        draw.line([(tw - hw, yy), (tw, yy + 40)], fill=white, width=4)
        draw.line([(tw + hw, yy), (tw, yy + 40)], fill=white, width=4)

    # Signal waves (3 arcs each side)
    wave_cx = tw
    wave_cy = top_y + 10
    for i in range(3):
        r = 50 + i * 45
        alpha = 220 - i * 50
        col = (255, 255, 255, alpha)
        # Left arc
        draw.arc([wave_cx - r, wave_cy - r, wave_cx + r, wave_cy + r],
                 200, 340, fill=col, width=8)
        # Right arc
        draw.arc([wave_cx - r, wave_cy - r, wave_cx + r, wave_cy + r],
                 20, 160, fill=col, width=8)

    # --- P2P nodes at bottom ---
    node_r = 16
    nodes = [
        (cx - 140, cy + 230),
        (cx, cy + 200),
        (cx + 140, cy + 230),
    ]
    line_col = (255, 255, 255, 140)
    # Connection lines
    for i in range(len(nodes)):
        for j in range(i + 1, len(nodes)):
            draw.line([nodes[i], nodes[j]], fill=line_col, width=5)
    # Node circles
    for nx, ny in nodes:
        draw.ellipse([nx - node_r, ny - node_r, nx + node_r, ny + node_r],
                     fill=white)

    # Save
    final.save(OUT / "icon_512x512@2x.png", "PNG")
    print(f"Icon saved to {OUT / 'icon_512x512@2x.png'}")


if __name__ == "__main__":
    draw_icon()
