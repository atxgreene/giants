#!/usr/bin/env python3
"""Repack a (possibly fractional / no-alpha) sprite sheet into a clean
exact-grid alpha atlas.

CLI (run from repo root):
    python3 scripts/tools/repack_atlas.py --id witness --cols 8 --rows 7 --cell 160
    python3 scripts/tools/repack_atlas.py --id ash_thrall \
        --src assets/sprites/ash_thrall.png --cols 6 --rows 4 --cell 160

Resamples --src to (cols*cell) x (rows*cell), keys the desaturated background to
true alpha (sparing saturated gold/blue/fire), and writes <id>_clean.png. If a
normal map exists it writes <id>_clean_n.png with the same alpha mask. Prints a
suggested <id>.json manifest (does not overwrite a hand-tuned one).

Pure stdlib (zlib) PNG io for 8-bit non-interlaced colour type 2 (RGB) / 6 (RGBA).
"""
import struct
import zlib
import sys
import json
import argparse
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPRITES = ROOT / "assets" / "sprites"
LUMA_MIN, SAT_MAX = 0.80, 0.13


def read_png(path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG: " + str(path)
    pos = 8
    width = height = bit = ctype = interlace = None
    idat = b""
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        ctag = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        if ctag == b"IHDR":
            width, height, bit, ctype, _c, _f, interlace = struct.unpack(">IIBBBBB", chunk)
        elif ctag == b"IDAT":
            idat += chunk
        elif ctag == b"IEND":
            break
        pos += 12 + length
    assert bit == 8 and interlace == 0 and ctype in (2, 6), \
        "unsupported PNG (bit=%s ctype=%s interlace=%s)" % (bit, ctype, interlace)
    channels = 3 if ctype == 2 else 4
    raw = zlib.decompress(idat)
    stride = width * channels
    out = bytearray(width * height * channels)
    prev = bytearray(stride)
    rp = 0
    for y in range(height):
        ft = raw[rp]; rp += 1
        line = bytearray(raw[rp:rp + stride]); rp += stride
        if ft == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 255
        elif ft == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif ft == 3:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif ft == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return width, height, channels, bytes(out)


def write_png(path, width, height, rgba):
    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw += rgba[y * stride:(y + 1) * stride]
    comp = zlib.compress(bytes(raw), 9)

    def chunk(tag, payload):
        return struct.pack(">I", len(payload)) + tag + payload + \
            struct.pack(">I", zlib.crc32(tag + payload) & 0xffffffff)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) +
                     chunk(b"IDAT", comp) + chunk(b"IEND", b""))


def keyed_alpha(r, g, b):
    mx = max(r, g, b) / 255.0
    mn = min(r, g, b) / 255.0
    return 0 if (mx > LUMA_MIN and (mx - mn) < SAT_MAX) else 255


def resample_rgba(src_w, src_h, ch, px, dst_w, dst_h, alpha_from=None):
    out = bytearray(dst_w * dst_h * 4)
    for y in range(dst_h):
        sy = min(src_h - 1, y * src_h // dst_h)
        for x in range(dst_w):
            sx = min(src_w - 1, x * src_w // dst_w)
            si = (sy * src_w + sx) * ch
            r, g, b = px[si], px[si + 1], px[si + 2]
            di = (y * dst_w + x) * 4
            out[di] = r; out[di + 1] = g; out[di + 2] = b
            if alpha_from is not None:
                out[di + 3] = alpha_from[y * dst_w + x]
            elif ch == 4:
                out[di + 3] = px[si + 3]
            else:
                out[di + 3] = keyed_alpha(r, g, b)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", default="witness")
    ap.add_argument("--src", default=None)
    ap.add_argument("--normal", default=None)
    ap.add_argument("--cols", type=int, default=8)
    ap.add_argument("--rows", type=int, default=7)
    ap.add_argument("--cell", type=int, default=160)
    a = ap.parse_args()

    src = pathlib.Path(a.src) if a.src else SPRITES / (a.id + ".png")
    norm = pathlib.Path(a.normal) if a.normal else SPRITES / (a.id + "_n.png")
    dst_w, dst_h = a.cols * a.cell, a.rows * a.cell

    sw, sh, sch, spx = read_png(src)
    print("%s %dx%d ch%d -> %dx%d (%dx%d cells of %d)" % (src.name, sw, sh, sch, dst_w, dst_h, a.cols, a.rows, a.cell))
    diff = resample_rgba(sw, sh, sch, spx, dst_w, dst_h)
    write_png(SPRITES / (a.id + "_clean.png"), dst_w, dst_h, diff)
    print("wrote %s_clean.png" % a.id)

    if norm.exists():
        mask = bytes(diff[i * 4 + 3] for i in range(dst_w * dst_h))
        nw, nh, nch, npx = read_png(norm)
        nout = resample_rgba(nw, nh, nch, npx, dst_w, dst_h, alpha_from=mask)
        write_png(SPRITES / (a.id + "_clean_n.png"), dst_w, dst_h, nout)
        print("wrote %s_clean_n.png" % a.id)

    manifest = {
        "sheet": a.id + "_clean.png",
        "normal": a.id + "_clean_n.png",
        "frame_size": [a.cell, a.cell],
        "grid": {"cols": a.cols, "rows": a.rows},
        "fps": 12, "offset": [0, -a.cell // 2], "pivot": "bottom_center",
        "scale": 0.42, "animations": {"idle": {"row": 0, "indices": [0], "mode": "pose", "loop": True}},
    }
    print("\nSuggested %s.json (edit rows/indices/modes):\n%s" % (a.id, json.dumps(manifest, indent=2)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
