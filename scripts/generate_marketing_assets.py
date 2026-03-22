#!/usr/bin/env python3

from __future__ import annotations

import struct
import zlib
from pathlib import Path


WIDTH = 1600
HEIGHT = 1000


def clamp(value: float) -> int:
    return max(0, min(255, int(round(value))))


def chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack("!I", len(data))
        + tag
        + data
        + struct.pack("!I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def write_png(path: Path, width: int, height: int, rgba: list[tuple[int, int, int, int]]) -> None:
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            r, g, b, a = rgba[y * width + x]
            raw.extend((r, g, b, a))

    ihdr = struct.pack("!IIBBBBB", width, height, 8, 6, 0, 0, 0)
    data = b"".join(
        [
            b"\x89PNG\r\n\x1a\n",
            chunk(b"IHDR", ihdr),
            chunk(b"IDAT", zlib.compress(bytes(raw), 9)),
            chunk(b"IEND", b""),
        ]
    )
    path.write_bytes(data)


def blend(src: tuple[int, int, int, int], dst: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    sr, sg, sb, sa = src
    dr, dg, db, da = dst
    src_a = sa / 255.0
    dst_a = da / 255.0
    out_a = src_a + dst_a * (1.0 - src_a)
    if out_a == 0:
        return 0, 0, 0, 0
    out_r = (sr * src_a + dr * dst_a * (1.0 - src_a)) / out_a
    out_g = (sg * src_a + dg * dst_a * (1.0 - src_a)) / out_a
    out_b = (sb * src_a + db * dst_a * (1.0 - src_a)) / out_a
    return clamp(out_r), clamp(out_g), clamp(out_b), clamp(out_a * 255.0)


def rect(canvas, x0, y0, x1, y1, color):
    for y in range(max(0, y0), min(HEIGHT, y1)):
        offset = y * WIDTH
        for x in range(max(0, x0), min(WIDTH, x1)):
            canvas[offset + x] = blend(color, canvas[offset + x])


def rounded_rect(canvas, x0, y0, x1, y1, radius, color):
    for y in range(max(0, y0), min(HEIGHT, y1)):
        offset = y * WIDTH
        for x in range(max(0, x0), min(WIDTH, x1)):
            inside = True
            if x < x0 + radius and y < y0 + radius:
                inside = (x - (x0 + radius)) ** 2 + (y - (y0 + radius)) ** 2 <= radius ** 2
            elif x > x1 - radius - 1 and y < y0 + radius:
                inside = (x - (x1 - radius - 1)) ** 2 + (y - (y0 + radius)) ** 2 <= radius ** 2
            elif x < x0 + radius and y > y1 - radius - 1:
                inside = (x - (x0 + radius)) ** 2 + (y - (y1 - radius - 1)) ** 2 <= radius ** 2
            elif x > x1 - radius - 1 and y > y1 - radius - 1:
                inside = (x - (x1 - radius - 1)) ** 2 + (y - (y1 - radius - 1)) ** 2 <= radius ** 2
            if inside:
                canvas[offset + x] = blend(color, canvas[offset + x])


def generate_preview() -> list[tuple[int, int, int, int]]:
    canvas = [(244, 247, 252, 255)] * (WIDTH * HEIGHT)

    for y in range(HEIGHT):
        for x in range(WIDTH):
            idx = y * WIDTH + x
            top_mix = y / HEIGHT
            left_mix = x / WIDTH
            canvas[idx] = (
                clamp(242 - 10 * top_mix),
                clamp(246 - 7 * left_mix),
                clamp(252 - 4 * top_mix),
                255,
            )

    rounded_rect(canvas, 60, 60, 1540, 940, 34, (255, 255, 255, 210))
    rounded_rect(canvas, 90, 120, 420, 900, 28, (225, 235, 248, 235))
    rounded_rect(canvas, 450, 120, 1510, 900, 28, (248, 250, 253, 245))

    rounded_rect(canvas, 110, 170, 400, 225, 18, (255, 255, 255, 215))
    rounded_rect(canvas, 110, 270, 400, 325, 18, (255, 255, 255, 215))

    for top in (430, 560, 690):
        rounded_rect(canvas, 500, top, 1460, top + 100, 22, (255, 255, 255, 235))
        rounded_rect(canvas, 530, top + 24, 590, top + 84, 18, (215, 228, 248, 255))
        rounded_rect(canvas, 760, top + 28, 850, top + 62, 16, (255, 236, 213, 255))
        rounded_rect(canvas, 870, top + 28, 965, top + 62, 16, (213, 228, 255, 255))

    rounded_rect(canvas, 110, 520, 400, 592, 18, (49, 108, 221, 235))

    return canvas


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    branding = root / "Assets" / "Branding"
    branding.mkdir(parents=True, exist_ok=True)
    write_png(branding / "release-preview.png", WIDTH, HEIGHT, generate_preview())


if __name__ == "__main__":
    main()
