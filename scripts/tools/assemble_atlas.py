#!/usr/bin/env python3
"""Assemble per-action sprite strips into one exact-grid alpha atlas.

Usage (run from repo root), one `name:frames` per action; each reads
assets/sprites/<id>_<name>.png as a horizontal strip of <frames> frames:

    python3 scripts/tools/assemble_atlas.py ash_thrall idle:4 walk:8 attack:5 death:6

Produces assets/sprites/<id>_clean.png — a (max_frames*CELL) x (rows*CELL)
RGBA atlas, one action per row, frames left-to-right, background keyed to true
alpha, every cell exactly CELL x CELL. If a matching <id>_<name>_n.png strip
exists for every action, also writes <id>_clean_n.png (alpha-masked to match).
Finally prints a suggested <id>.json manifest in the contract shape.

Reuses the stdlib PNG io from repack_atlas.py (no third-party deps).
"""
import sys
import json
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import repack_atlas as R  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPRITES = ROOT / "assets" / "sprites"
CELL = 160


def resample_cell(px, sw, sh, ch, x0, cw, out, ax, ay, atlas_w, mask=None):
    """Nearest-resample one source sub-rect [x0, x0+cw) x [0,sh) into a
    CELL x CELL block at atlas pixel (ax, ay). Keys background to alpha unless
    a mask (from the diffuse pass) is supplied."""
    for dy in range(CELL):
        sy = min(sh - 1, dy * sh // CELL)
        for dx in range(CELL):
            sx = min(sw - 1, x0 + dx * cw // CELL)
            si = (sy * sw + sx) * ch
            r, g, b = px[si], px[si + 1], px[si + 2]
            di = ((ay + dy) * atlas_w + (ax + dx)) * 4
            out[di] = r; out[di + 1] = g; out[di + 2] = b
            if mask is not None:
                out[di + 3] = mask[(ay + dy) * atlas_w + (ax + dx)]
            elif ch == 4:
                out[di + 3] = px[si + 3]
            else:
                out[di + 3] = R.keyed_alpha(r, g, b)


def build(atlas_w, atlas_h, actions, suffix, mask=None):
    out = bytearray(atlas_w * atlas_h * 4)
    for row, (name, frames) in enumerate(actions):
        path = SPRITES / ("%s_%s%s.png" % (enemy_id, name, suffix))
        if not path.exists():
            return None
        sw, sh, ch, px = R.read_png(path)
        cw = sw // frames
        for f in range(frames):
            resample_cell(px, sw, sh, ch, f * cw, cw, out,
                          f * CELL, row * CELL, atlas_w, mask)
    return out


def main():
    global enemy_id
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    enemy_id = sys.argv[1]
    actions = []
    for a in sys.argv[2:]:
        name, _, fr = a.partition(":")
        actions.append((name, int(fr)))
    max_frames = max(f for _, f in actions)
    atlas_w = max_frames * CELL
    atlas_h = len(actions) * CELL

    diff = build(atlas_w, atlas_h, actions, "")
    if diff is None:
        print("Missing one or more diffuse strips for", enemy_id)
        return 1
    R.write_png(SPRITES / (enemy_id + "_clean.png"), atlas_w, atlas_h, diff)
    print("wrote %s_clean.png  (%dx%d, grid %dx%d)" % (enemy_id, atlas_w, atlas_h, max_frames, len(actions)))

    mask = bytes(diff[i * 4 + 3] for i in range(atlas_w * atlas_h))
    norm = build(atlas_w, atlas_h, actions, "_n", mask)
    if norm is not None:
        R.write_png(SPRITES / (enemy_id + "_clean_n.png"), atlas_w, atlas_h, norm)
        print("wrote %s_clean_n.png" % enemy_id)

    # Suggested manifest — coherent per-action strips animate as sequences.
    anims = {}
    for row, (name, frames) in enumerate(actions):
        loop = name in ("idle", "walk")
        anims[name] = {"row": row, "indices": list(range(frames)),
                       "mode": "sequence", "loop": loop}
    manifest = {
        "sheet": enemy_id + "_clean.png",
        "normal": enemy_id + "_clean_n.png",
        "frame_size": [CELL, CELL],
        "grid": {"cols": max_frames, "rows": len(actions)},
        "fps": 10, "offset": [0, -CELL // 2], "pivot": "bottom_center",
        "scale": 0.42, "animations": anims,
    }
    print("\nSuggested %s.json:\n%s" % (enemy_id, json.dumps(manifest, indent=2)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
