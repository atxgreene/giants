#!/usr/bin/env python3
"""Fail CI if Game.VERSION, the CHANGELOG, and the README disagree.

The single source of truth is `const VERSION := "x.y.z"` in
scripts/core/game_manager.gd. The latest CHANGELOG heading must name that
version, and the README must mention it somewhere. This keeps shipped builds
from drifting away from their own documentation.
"""
import re
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]


def fail(msg: str) -> None:
    print("VERSION CHECK FAILED: " + msg)
    sys.exit(1)


def read(path: str) -> str:
    p = ROOT / path
    if not p.exists():
        fail(f"missing file: {path}")
    return p.read_text(encoding="utf-8")


def main() -> None:
    gm = read("scripts/core/game_manager.gd")
    m = re.search(r'const\s+VERSION\s*:=\s*"([^"]+)"', gm)
    if not m:
        fail("could not find Game.VERSION in game_manager.gd")
    version = m.group(1)
    print(f"Game.VERSION = {version}")

    changelog = read("CHANGELOG.md")
    # The latest version heading should mention this version.
    headings = re.findall(r"^#+\s*\[?v?([0-9]+\.[0-9]+\.[0-9]+)", changelog, re.M)
    if not headings:
        fail("no version headings found in CHANGELOG.md")
    if version not in headings:
        fail(f"CHANGELOG.md has no entry for version {version} (found: {headings[:5]})")
    if headings[0] != version:
        fail(
            f"CHANGELOG.md top entry is {headings[0]}, expected {version} "
            "(the newest version must be listed first)"
        )

    readme = read("README.md")
    if version not in readme:
        fail(f"README.md does not mention version {version}")

    print("Version consistency OK")


if __name__ == "__main__":
    main()
