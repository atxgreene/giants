#!/usr/bin/env python3
"""Reframe a ragged/misaligned sprite sheet into a clean uniform-grid atlas.

AI sheets often have a different number of frames per row, and the figures
don't sit on any single uniform grid — so cropping uniform cells bleeds across
figures. This detects each frame (by alpha/background gaps), then re-packs every
frame centered + bottom-aligned into its own exact CELL x CELL cell. After this,
uniform cropping is correct and cannot bleed.

CLI (from repo root):
    python3 scripts/tools/reframe_atlas.py --id witness --rows 7 --cell 160

Reads assets/sprites/<id>.png (+ <id>_n.png), writes <id>_clean.png (+ _n) and
prints the detected frames-per-row. Pure stdlib (reuses repack_atlas io).
"""
import sys
import argparse
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import repack_atlas as R  # noqa: E402

SPRITES = pathlib.Path(__file__).resolve().parents[2] / "assets" / "sprites"


def opaque(px, ch, w, x, y):
    i = (y * w + x) * ch
    if ch == 4:
        return px[i + 3] > 40
    r, g, b = px[i], px[i + 1], px[i + 2]
    return R.keyed_alpha(r, g, b) > 0  # non-background


def detect_frames(px, ch, w, y0, y1):
    """Column clusters of non-background pixels in band [y0,y1) -> [(x0,x1)]."""
    cov = [0] * w
    for x in range(w):
        c = 0
        for y in range(y0, y1, 3):
            if opaque(px, ch, w, x, y):
                c += 1
        cov[x] = c
    mx = max(cov) or 1
    thr = mx * 0.10
    runs = []
    inrun = False
    s = 0
    gap = 0
    for x in range(w):
        if cov[x] > thr:
            if not inrun:
                inrun = True
                s = x
            gap = 0
        elif inrun:
            gap += 1
            if gap > w // 60:  # tolerate small internal gaps
                runs.append((s, x - gap))
                inrun = False
    if inrun:
        runs.append((s, w - 1))
    return [(a, b) for a, b in runs if (b - a) > w // 80]


def vbbox(px, ch, w, x0, x1, y0, y1):
    top, bot = y1, y0
    for y in range(y0, y1):
        for x in range(x0, x1):
            if opaque(px, ch, w, x, y):
                top = min(top, y)
                bot = max(bot, y)
                break
    if bot < top:
        return y0, y1
    return top, bot


def place(src, ch, sw, fx0, fx1, fy0, fy1, out, cell, ax, ay, atlas_w, mask_alpha):
    """Scale source frame bbox to fit a cell (height 0.9*cell), centered
    horizontally, bottom-aligned (feet near cell bottom)."""
    fw = max(1, fx1 - fx0)
    fh = max(1, fy1 - fy0)
    target_h = int(cell * 0.90)
    scale = target_h / fh
    dw = min(int(cell * 0.96), int(fw * scale))
    dh = int(fh * scale)
    ox = ax + (cell - dw) // 2
    oy = ay + cell - dh - int(cell * 0.04)  # small foot pad
    for dy in range(dh):
        sy = fy0 + min(fh - 1, dy * fh // dh)
        for dx in range(dw):
            sx = fx0 + min(fw - 1, dx * fw // dw)
            si = (sy * sw + sx) * ch
            r, g, b = src[si], src[si + 1], src[si + 2]
            a = src[si + 3] if ch == 4 else R.keyed_alpha(r, g, b)
            if mask_alpha is not None:
                a = mask_alpha((ox + dx), (oy + dy))
            if a == 0:
                continue
            di = ((oy + dy) * atlas_w + (ox + dx)) * 4
            out[di] = r; out[di + 1] = g; out[di + 2] = b; out[di + 3] = a


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", default="witness")
    ap.add_argument("--rows", type=int, default=7)
    ap.add_argument("--cell", type=int, default=160)
    a = ap.parse_args()

    sw, sh, sch, spx = R.read_png(SPRITES / (a.id + ".png"))
    rh = sh // a.rows
    # Detect each frame's full bbox (x0,x1,y0,y1) from the DIFFUSE once; the
    # normal map shares the same layout, so we reuse these boxes for it.
    rows_frames = []
    for r in range(a.rows):
        boxes = []
        for (x0, x1) in detect_frames(spx, sch, sw, r * rh, (r + 1) * rh):
            y0, y1 = vbbox(spx, sch, sw, x0, x1 + 1, r * rh, (r + 1) * rh)
            boxes.append((x0, x1 + 1, y0, y1 + 1))
        rows_frames.append(boxes)
    counts = [len(f) for f in rows_frames]
    cols = max(counts)
    print("%s: detected frames/row = %s -> grid %dx%d" % (a.id, counts, cols, a.rows))

    aw, ah = cols * a.cell, a.rows * a.cell

    def build(src, ch, mask_alpha=None):
        out = bytearray(aw * ah * 4)
        for r, boxes in enumerate(rows_frames):
            for c, (x0, x1, y0, y1) in enumerate(boxes):
                place(src, ch, sw, x0, x1, y0, y1, out, a.cell,
                      c * a.cell, r * a.cell, aw, mask_alpha)
        return out

    diff = build(spx, sch)
    R.write_png(SPRITES / (a.id + "_clean.png"), aw, ah, diff)
    print("wrote %s_clean.png (%dx%d)" % (a.id, aw, ah))

    npath = SPRITES / (a.id + "_n.png")
    if npath.exists():
        nw, nh, nch, npx = R.read_png(npath)
        def mask_alpha(x, y):
            if 0 <= x < aw and 0 <= y < ah:
                return diff[(y * aw + x) * 4 + 3]
            return 0
        norm = build(npx, nch, mask_alpha)
        R.write_png(SPRITES / (a.id + "_clean_n.png"), aw, ah, norm)
        print("wrote %s_clean_n.png" % a.id)
    return 0


if __name__ == "__main__":
    sys.exit(main())
