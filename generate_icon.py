#!/usr/bin/env python3

from __future__ import annotations

import math
import os
import struct
import zlib
from pathlib import Path


SIZE = 1024


def clamp(value: float) -> int:
    return max(0, min(255, int(round(value))))


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


def write_png(path: Path, width: int, height: int, rgba: list[tuple[int, int, int, int]]) -> None:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack("!I", len(data))
            + tag
            + data
            + struct.pack("!I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

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


def generate_pixels() -> list[tuple[int, int, int, int]]:
    pixels: list[tuple[int, int, int, int]] = [(0, 0, 0, 0)] * (SIZE * SIZE)
    center_x = SIZE / 2
    center_y = SIZE / 2
    handle_half_width = 46

    for y in range(SIZE):
        for x in range(SIZE):
            idx = y * SIZE + x

            top_mix = y / SIZE
            base_r = clamp(228 - 14 * top_mix)
            base_g = clamp(236 - 10 * top_mix)
            base_b = clamp(247 - 4 * top_mix)
            color = (base_r, base_g, base_b, 255)

            # Rounded background corners.
            margin = 70
            corner_radius = 190
            dx = max(abs(x - SIZE / 2) - (SIZE / 2 - margin - corner_radius), 0)
            dy = max(abs(y - SIZE / 2) - (SIZE / 2 - margin - corner_radius), 0)
            if dx * dx + dy * dy > corner_radius * corner_radius:
                color = (0, 0, 0, 0)
                pixels[idx] = color
                continue

            # Soft vignette.
            dist = math.hypot(x - center_x, y - center_y)
            vignette = max(0.0, min(1.0, dist / 760))
            color = (
                clamp(color[0] * (1 - 0.08 * vignette)),
                clamp(color[1] * (1 - 0.07 * vignette)),
                clamp(color[2] * (1 - 0.06 * vignette)),
                255,
            )

            # Soft top sheen.
            if y < 360:
                alpha = clamp(48 * (1 - y / 360))
                color = blend((255, 255, 255, alpha), color)

            # Inner glass panel.
            glass_dx = abs(x - center_x)
            glass_dy = abs(y - center_y)
            if glass_dx <= 330 and glass_dy <= 330:
                panel_alpha = clamp(max(0, 72 - int((glass_dx + glass_dy) / 12)))
                color = blend((255, 255, 255, panel_alpha), color)

            # Magnifier ring.
            ring_center_x = 426
            ring_center_y = 406
            ring_dist = math.hypot(x - ring_center_x, y - ring_center_y)
            if 158 <= ring_dist <= 212:
                color = blend((90, 132, 201, 210), color)

            # Glass fill.
            if ring_dist < 158:
                sheen = max(0.0, 1.0 - ring_dist / 160)
                glass = (
                    clamp(255 - 12 * sheen),
                    clamp(255 - 8 * sheen),
                    255,
                    120,
                )
                color = blend(glass, color)

            # Handle.
            handle_dx = x - 620
            handle_dy = y - 610
            rotated_x = (handle_dx + handle_dy) / math.sqrt(2)
            rotated_y = (handle_dy - handle_dx) / math.sqrt(2)
            if -170 <= rotated_x <= 170 and -handle_half_width <= rotated_y <= handle_half_width:
                color = blend((81, 118, 180, 235), color)

            # Trash can body.
            if 350 <= x <= 675 and 420 <= y <= 730:
                inset = abs((x - 512) / 180)
                shade = 1.0 - 0.07 * inset
                body = (
                    clamp(247 * shade),
                    clamp(249 * shade),
                    clamp(252 * shade),
                    242,
                )
                color = blend(body, color)

            # Lid.
            if 320 <= x <= 705 and 365 <= y <= 430:
                color = blend((236, 239, 244, 245), color)

            # Handle on lid.
            if 455 <= x <= 570 and 320 <= y <= 365:
                color = blend((232, 236, 242, 245), color)

            # Vertical slots.
            for slot_x in (430, 512, 594):
                if slot_x - 18 <= x <= slot_x + 18 and 470 <= y <= 680:
                    color = blend((197, 206, 218, 188), color)

            # Sparkle.
            sparkle_points = [
                (760, 280, 42),
                (808, 360, 26),
                (292, 278, 24),
            ]
            for sx, sy, sr in sparkle_points:
                d = abs(x - sx) + abs(y - sy)
                if d < sr:
                    alpha = clamp(255 * (1 - d / sr))
                    color = blend((255, 255, 255, alpha), color)

            # Bottom shadow for can.
            shadow_dx = abs(x - 512)
            shadow_dy = abs(y - 768)
            if shadow_dx <= 240 and shadow_dy <= 34:
                alpha = clamp(max(0, 52 - int((shadow_dx / 8) + shadow_dy)))
                color = blend((117, 135, 166, alpha), color)

            pixels[idx] = color

    return pixels


def main() -> None:
    root = Path(__file__).resolve().parent
    assets_dir = root / "Assets"
    iconset_dir = assets_dir / "AppIcon.iconset"
    iconset_dir.mkdir(parents=True, exist_ok=True)

    base_png = assets_dir / "AppIcon-1024.png"
    write_png(base_png, SIZE, SIZE, generate_pixels())

    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }

    for filename, size in sizes.items():
        target = iconset_dir / filename
        os.system(f'sips -z {size} {size} "{base_png}" --out "{target}" >/dev/null')

if __name__ == "__main__":
    main()
