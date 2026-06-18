#!/usr/bin/env python3
"""Repack the Witness sheets into a clean runtime atlas.

The generated source (witness.png / witness_n.png) is 1341x1173 RGB with no
alpha, so runtime cropping lands on fractional 167.6px cells and bleeds
neighbour-cell pixels during movement. This bakes a clean atlas:

  - resample to an exact 1280x1120 (8 cols x 7 rows -> exact 160px cells)
  - key the desaturated background to true alpha (sparing saturated
    gold/blue/fire pixels)
  - write witness_clean.png (RGBA) and witness_clean_n.png (RGBA, same mask)

Pure stdlib (zlib only) PNG reader/writer for 8-bit, non-interlaced,
colour type 2 (RGB) or 6 (RGBA). Run from the repo root:
    python3 scripts/tools/repack_atlas.py
"""
import struct
import zlib
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPRITES = ROOT / "assets" / "sprites"
DST_W, DST_H = 1280, 1120
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
            width, height, bit, ctype, _comp, _filt, interlace = struct.unpack(">IIBBBBB", chunk)
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
        if ft == 1:      # Sub
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 255
        elif ft == 2:    # Up
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif ft == 3:    # Average
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif ft == 4:    # Paeth
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
        raw.append(0)  # filter None
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


def resample_rgba(src_w, src_h, ch, px, alpha_from=None):
    out = bytearray(DST_W * DST_H * 4)
    for y in range(DST_H):
        sy = min(src_h - 1, y * src_h // DST_H)
        for x in range(DST_W):
            sx = min(src_w - 1, x * src_w // DST_W)
            si = (sy * src_w + sx) * ch
            r, g, b = px[si], px[si + 1], px[si + 2]
            di = (y * DST_W + x) * 4
            out[di] = r; out[di + 1] = g; out[di + 2] = b
            if alpha_from is not None:
                out[di + 3] = alpha_from[y * DST_W + x]
            else:
                out[di + 3] = keyed_alpha(r, g, b)
    return out


def main():
    sw, sh, sch, spx = read_png(SPRITES / "witness.png")
    print("diffuse %dx%d ch%d -> %dx%d" % (sw, sh, sch, DST_W, DST_H))
    diff = resample_rgba(sw, sh, sch, spx)
    # extract the alpha mask to reuse on the normal map
    mask = bytes(diff[i * 4 + 3] for i in range(DST_W * DST_H))
    write_png(SPRITES / "witness_clean.png", DST_W, DST_H, diff)
    print("wrote witness_clean.png")

    npath = SPRITES / "witness_n.png"
    if npath.exists():
        nw, nh, nch, npx = read_png(npath)
        norm = resample_rgba(nw, nh, nch, npx, alpha_from=mask)
        write_png(SPRITES / "witness_clean_n.png", DST_W, DST_H, norm)
        print("wrote witness_clean_n.png")
    print("done")


if __name__ == "__main__":
    sys.exit(main())
