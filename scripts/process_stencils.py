#!/usr/bin/env python3
"""Convert Figma outline PNGs to white-on-transparent for Roblox ImageColor3 tinting."""

from __future__ import annotations

import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "assets" / "stencils" / "raw"
OUT = ROOT / "assets" / "stencils" / "white"


def frame_number(path: Path) -> int | None:
	match = re.search(r"(?:frame[_\s-]*)?(\d+)", path.stem, re.I)
	if match is None:
		return None
	return int(match.group(1))


def to_white_silhouette(src: Path, dest: Path) -> None:
	img = Image.open(src).convert("RGBA")
	pixels = img.load()
	assert pixels is not None
	w, h = img.size
	for y in range(h):
		for x in range(w):
			r, g, b, a = pixels[x, y]
			# Gray Figma canvas / near-white → transparent
			if a < 16 or (r > 200 and g > 200 and b > 200):
				pixels[x, y] = (0, 0, 0, 0)
				continue
			# Dark stroke → white (keeps alpha for soft edges)
			luma = (r + g + b) / 3
			strength = max(0, min(255, int(255 - luma)))
			alpha = min(255, int(a * strength / 255)) if a < 255 else strength
			pixels[x, y] = (255, 255, 255, alpha)
	dest.parent.mkdir(parents=True, exist_ok=True)
	img.save(dest)


def main() -> int:
	if not RAW.exists():
		print(f"Missing {RAW} — export Frame 15–74 PNGs there first.")
		return 1
	files = sorted(
		[p for p in RAW.iterdir() if p.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}],
		key=lambda p: (frame_number(p) is None, frame_number(p) or 0, p.name.lower()),
	)
	if not files:
		print(f"No images in {RAW}")
		return 1
	OUT.mkdir(parents=True, exist_ok=True)
	written: list[Path] = []
	for path in files:
		num = frame_number(path)
		name = f"frame_{num:02d}.png" if num is not None else f"{path.stem}.png"
		dest = OUT / name
		to_white_silhouette(path, dest)
		written.append(dest)
		print(f"ok {path.name} -> {dest.name}")
	print(f"Processed {len(written)} stencils into {OUT}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
