#!/usr/bin/env python3
"""Generate simple ox_inventory icons for Icebox items."""
from __future__ import annotations

import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "install" / "images"
SIZE = 128

PALETTES = {
    "icebox_gold_bar": ((212, 175, 119), (90, 70, 32), "AU"),
    "icebox_silver_bar": ((200, 210, 220), (70, 80, 90), "AG"),
    "icebox_platinum_bar": ((226, 232, 240), (80, 90, 110), "PT"),
    "icebox_diamond": ((139, 231, 255), (30, 70, 90), "D"),
    "icebox_ruby": ((255, 110, 130), (80, 20, 30), "R"),
    "icebox_chain_links": ((180, 190, 200), (40, 45, 55), "O"),
    "icebox_polish": ((180, 255, 210), (30, 70, 50), "P"),
    "icebox_tester": ((240, 240, 240), (50, 50, 60), "T"),
    "icebox_rope_silver": ((200, 210, 220), (40, 50, 60), "SR"),
    "icebox_figaro_gold": ((212, 175, 119), (50, 40, 20), "FG"),
    "icebox_cuban_gold": ((230, 190, 90), (50, 35, 10), "CG"),
    "icebox_cuban_silver": ((210, 220, 230), (40, 50, 60), "CS"),
    "icebox_crossed_out": ((212, 175, 119), (40, 30, 15), "X"),
    "icebox_tennis_ice": ((180, 240, 255), (20, 50, 70), "TI"),
    "icebox_medallion": ((230, 200, 120), (50, 30, 10), "M"),
    "icebox_diamond_cuban": ((200, 240, 255), (30, 40, 70), "DC"),
    "icebox_infinity": ((230, 230, 255), (40, 40, 80), "8"),
    "icebox_boss": ((255, 215, 140), (60, 30, 10), "B"),
    "icebox_watch_steel": ((180, 190, 200), (30, 30, 40), "W"),
    "icebox_watch_gold": ((220, 180, 90), (50, 35, 10), "G"),
}


def png(rgb_rows: list[bytes]) -> bytes:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + row for row in rgb_rows)
    ihdr = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def letter_pixels(text: str) -> set[tuple[int, int]]:
    """Tiny 5x7 bitmap font for a few glyphs."""
    glyphs = {
        "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
        "B": ["11110", "10001", "11110", "10001", "10001", "10001", "11110"],
        "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
        "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
        "F": ["11111", "10000", "11110", "10000", "10000", "10000", "10000"],
        "G": ["01111", "10000", "10000", "10111", "10001", "10001", "01110"],
        "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
        "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
        "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
        "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
        "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
        "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
        "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
        "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
        "W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
        "X": ["10001", "01010", "00100", "00100", "00100", "01010", "10001"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
    }
    pixels: set[tuple[int, int]] = set()
    scale = 4
    total_w = len(text) * 6 * scale
    start_x = (SIZE - total_w) // 2
    start_y = (SIZE - 7 * scale) // 2 + 18
    for i, ch in enumerate(text):
        rows = glyphs.get(ch, glyphs["X"])
        for y, row in enumerate(rows):
            for x, bit in enumerate(row):
                if bit == "1":
                    for dy in range(scale):
                        for dx in range(scale):
                            pixels.add((start_x + i * 6 * scale + x * scale + dx, start_y + y * scale + dy))
    return pixels


def make_icon(fg: tuple[int, int, int], bg: tuple[int, int, int], text: str) -> bytes:
    letters = letter_pixels(text)
    rows = []
    cx, cy = SIZE // 2, SIZE // 2 - 8
    for y in range(SIZE):
        row = bytearray()
        for x in range(SIZE):
            dx, dy = x - cx, y - cy
            in_diamond = abs(dx) + abs(dy) < 42
            in_ring = 48 < (dx * dx + dy * dy) ** 0.5 < 54
            if (x, y) in letters:
                color = (250, 250, 250)
            elif in_diamond:
                color = fg
            elif in_ring:
                color = tuple(min(255, c + 40) for c in fg)
            else:
                mix = 1 if (x - 8) % 16 < 2 or (y - 8) % 16 < 2 else 0
                color = tuple(min(255, bg[i] + mix * 12) for i in range(3))
            row.extend(color)
        rows.append(bytes(row))
    return png(rows)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (fg, bg, text) in PALETTES.items():
        (OUT / f"{name}.png").write_bytes(make_icon(fg, bg, text))
    print(f"wrote {len(PALETTES)} icons to {OUT}")


if __name__ == "__main__":
    main()
