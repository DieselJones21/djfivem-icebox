#!/usr/bin/env python3
"""Generate ox_inventory + NUI icons for Icebox items."""
from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTS = [ROOT / "install" / "images", ROOT / "html" / "assets" / "items"]
SIZE = 128

GOLD = (232, 184, 74)
GOLD_HI = (255, 230, 160)
SILVER = (210, 218, 228)
PLAT = (226, 232, 240)
RED = (255, 75, 75)
RUBY = (200, 32, 48)
DARK = (18, 8, 10)


def png(rgb_rows: list[bytes]) -> bytes:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + row for row in rgb_rows)
    ihdr = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


class Canvas:
    def __init__(self) -> None:
        self.px = [[list(DARK) for _ in range(SIZE)] for _ in range(SIZE)]
        self._vignette()

    def _vignette(self) -> None:
        cx, cy = SIZE / 2, SIZE / 2
        for y in range(SIZE):
            for x in range(SIZE):
                d = math.hypot(x - cx, y - cy) / 90
                glow = max(0.0, 1.0 - d)
                self.px[y][x] = [
                    min(255, int(18 + 70 * glow)),
                    min(255, int(8 + 10 * glow)),
                    min(255, int(10 + 12 * glow)),
                ]

    def blend(self, x: int, y: int, color: tuple[int, int, int], a: float) -> None:
        if a <= 0 or x < 0 or y < 0 or x >= SIZE or y >= SIZE:
            return
        r, g, b = self.px[y][x]
        self.px[y][x] = [
            int(r * (1 - a) + color[0] * a),
            int(g * (1 - a) + color[1] * a),
            int(b * (1 - a) + color[2] * a),
        ]

    def disc(self, cx: float, cy: float, r: float, color: tuple[int, int, int], edge: float = 1.4) -> None:
        ir = int(r + edge + 1)
        for y in range(int(cy) - ir, int(cy) + ir + 1):
            for x in range(int(cx) - ir, int(cx) + ir + 1):
                d = math.hypot(x - cx, y - cy)
                if d <= r:
                    self.blend(x, y, color, 1.0)
                elif d < r + edge:
                    self.blend(x, y, color, 1.0 - (d - r) / edge)

    def ring(self, cx: float, cy: float, r: float, w: float, color: tuple[int, int, int]) -> None:
        ir = int(r + w + 2)
        for y in range(int(cy) - ir, int(cy) + ir + 1):
            for x in range(int(cx) - ir, int(cx) + ir + 1):
                d = abs(math.hypot(x - cx, y - cy) - r)
                if d <= w:
                    a = max(0.0, 1.0 - d / w)
                    self.blend(x, y, color, a)

    def ellipse_ring(self, cx: float, cy: float, rx: float, ry: float, w: float, color: tuple[int, int, int], rot: float = 0.0) -> None:
        ir = int(max(rx, ry) + w + 2)
        cr, sr = math.cos(rot), math.sin(rot)
        for y in range(int(cy) - ir, int(cy) + ir + 1):
            for x in range(int(cx) - ir, int(cx) + ir + 1):
                dx, dy = x - cx, y - cy
                u, v = dx * cr + dy * sr, -dx * sr + dy * cr
                if rx == 0 or ry == 0:
                    continue
                dist = math.hypot(u / rx, v / ry)
                d = abs(dist - 1.0) * min(rx, ry)
                if d <= w:
                    self.blend(x, y, color, max(0.0, 1.0 - d / w))

    def diamond(self, cx: float, cy: float, s: float, color: tuple[int, int, int]) -> None:
        ir = int(s + 2)
        for y in range(int(cy) - ir, int(cy) + ir + 1):
            for x in range(int(cx) - ir, int(cx) + ir + 1):
                if abs(x - cx) + abs(y - cy) <= s:
                    hi = 1.0 if (y - cy) < 0 else 0.72
                    c = (min(255, int(color[0] * hi + 40)), min(255, int(color[1] * hi + 40)), min(255, int(color[2] * hi + 50)))
                    self.blend(x, y, c, 1.0)

    def round_rect(self, x0: float, y0: float, x1: float, y1: float, r: float, color: tuple[int, int, int]) -> None:
        for y in range(int(y0 - 1), int(y1 + 2)):
            for x in range(int(x0 - 1), int(x1 + 2)):
                px = min(max(x, x0 + r), x1 - r)
                py = min(max(y, y0 + r), y1 - r)
                # corners
                if x < x0 + r and y < y0 + r and math.hypot(x - (x0 + r), y - (y0 + r)) > r:
                    continue
                if x > x1 - r and y < y0 + r and math.hypot(x - (x1 - r), y - (y0 + r)) > r:
                    continue
                if x < x0 + r and y > y1 - r and math.hypot(x - (x0 + r), y - (y1 - r)) > r:
                    continue
                if x > x1 - r and y > y1 - r and math.hypot(x - (x1 - r), y - (y1 - r)) > r:
                    continue
                if x0 <= x <= x1 and y0 <= y <= y1:
                    shine = 0.75 + 0.25 * ((y1 - y) / max(1.0, y1 - y0))
                    c = tuple(min(255, int(ch * shine)) for ch in color)
                    self.blend(x, y, c, 1.0)

    def chain(self, metal: tuple[int, int, int], thick: bool = False, pendant: str | None = None) -> None:
        links = 6 if thick else 7
        w = 6.5 if thick else 4.5
        rx, ry = (16, 10) if thick else (13, 8)
        for i in range(links):
            cx = 24 + i * 14
            cy = 58 + math.sin(i * 0.7) * 6
            self.ellipse_ring(cx, cy, rx, ry, w, metal, rot=0.5 if i % 2 else -0.2)
            self.ellipse_ring(cx, cy, rx, ry, max(2.0, w - 2.5), GOLD_HI if metal == GOLD else (255, 255, 255), rot=0.5 if i % 2 else -0.2)
        if pendant == "cross":
            self.round_rect(58, 70, 70, 102, 2, metal)
            self.round_rect(48, 78, 80, 88, 2, metal)
        elif pendant == "medallion":
            self.disc(64, 86, 16, metal)
            self.disc(64, 86, 10, GOLD_HI)
        elif pendant == "diamond":
            self.diamond(64, 84, 16, (180, 240, 255))
        elif pendant == "infinity":
            self.ellipse_ring(56, 86, 10, 7, 3.2, metal)
            self.ellipse_ring(72, 86, 10, 7, 3.2, metal)
        elif pendant == "boss":
            self.disc(64, 86, 18, metal)
            self.diamond(64, 86, 10, RED)

    def tennis(self) -> None:
        for i in range(8):
            cx = 22 + i * 12
            cy = 64 + math.sin(i) * 4
            self.diamond(cx, cy, 8, (170, 230, 255))
            self.ring(cx, cy, 9, 1.6, GOLD)

    def bar(self, metal: tuple[int, int, int]) -> None:
        self.round_rect(28, 48, 100, 84, 8, metal)
        self.round_rect(32, 52, 96, 62, 3, GOLD_HI)

    def watch(self, metal: tuple[int, int, int]) -> None:
        self.disc(64, 64, 28, metal)
        self.disc(64, 64, 22, (24, 14, 16))
        self.ring(64, 64, 22, 2, GOLD_HI)
        self.round_rect(62, 48, 66, 64, 1, metal)
        self.round_rect(64, 62, 78, 66, 1, metal)

    def polish(self) -> None:
        self.round_rect(40, 30, 88, 100, 14, (80, 40, 20))
        self.round_rect(46, 38, 82, 70, 10, (255, 230, 180))

    def tester(self) -> None:
        self.round_rect(44, 28, 84, 100, 8, SILVER)
        self.round_rect(50, 36, 78, 58, 4, (20, 20, 24))
        self.disc(64, 80, 8, RED)

    def stone(self, color: tuple[int, int, int]) -> None:
        self.diamond(64, 64, 28, color)
        self.diamond(64, 58, 12, (255, 255, 255))

    def to_png(self) -> bytes:
        rows = [bytes(ch for pixel in row for ch in pixel) for row in self.px]
        return png(rows)


ITEMS = {
    "icebox_gold_bar": ("bar", GOLD),
    "icebox_silver_bar": ("bar", SILVER),
    "icebox_platinum_bar": ("bar", PLAT),
    "icebox_diamond": ("stone", (170, 230, 255)),
    "icebox_ruby": ("stone", RUBY),
    "icebox_chain_links": ("chain", SILVER),
    "icebox_polish": ("polish", GOLD),
    "icebox_tester": ("tester", SILVER),
    "icebox_rope_silver": ("chain", SILVER),
    "icebox_figaro_gold": ("chain", GOLD),
    "icebox_cuban_gold": ("thick", GOLD),
    "icebox_cuban_silver": ("thick", SILVER),
    "icebox_crossed_out": ("cross", GOLD),
    "icebox_tennis_ice": ("tennis", GOLD),
    "icebox_medallion": ("medallion", GOLD),
    "icebox_diamond_cuban": ("diamond", GOLD),
    "icebox_infinity": ("infinity", PLAT),
    "icebox_boss": ("boss", GOLD),
    "icebox_watch_steel": ("watch", SILVER),
    "icebox_watch_gold": ("watch", GOLD),
}


def draw(kind: str, metal: tuple[int, int, int]) -> Canvas:
    c = Canvas()
    if kind == "bar":
        c.bar(metal)
    elif kind == "stone":
        c.stone(metal)
    elif kind == "polish":
        c.polish()
    elif kind == "tester":
        c.tester()
    elif kind == "watch":
        c.watch(metal)
    elif kind == "tennis":
        c.tennis()
    elif kind == "thick":
        c.chain(metal, thick=True)
    elif kind == "cross":
        c.chain(metal, pendant="cross")
    elif kind == "medallion":
        c.chain(metal, pendant="medallion")
    elif kind == "diamond":
        c.chain(metal, thick=True, pendant="diamond")
    elif kind == "infinity":
        c.chain(metal, pendant="infinity")
    elif kind == "boss":
        c.chain(metal, thick=True, pendant="boss")
    else:
        c.chain(metal)
    return c


def main() -> None:
    for out in OUTS:
        out.mkdir(parents=True, exist_ok=True)
    for name, (kind, metal) in ITEMS.items():
        data = draw(kind, metal).to_png()
        for out in OUTS:
            (out / f"{name}.png").write_bytes(data)
    print(f"wrote {len(ITEMS)} icons to {', '.join(str(p) for p in OUTS)}")


if __name__ == "__main__":
    main()
