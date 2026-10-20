#!/usr/bin/env python3
"""Build src/shared/StencilPack.luau bitmasks from assets/stencils/raw."""

from __future__ import annotations

import base64
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SIZE = 160
RAW = ROOT / "assets" / "stencils" / "raw"
OUT = ROOT / "src" / "shared" / "StencilPack.luau"

NAMES = {
	15: ("circle", "Circle"),
	16: ("tri", "Triangle"),
	17: ("frame", "Square"),
	18: ("star", "Star"),
	19: ("rect", "Rectangle"),
	20: ("pointer", "Arrow"),
	21: ("bar", "Line"),
	22: ("gem", "Diamond"),
	23: ("pentagon", "Pentagon"),
	24: ("hex", "Hex"),
	25: ("octagon", "Octagon"),
	26: ("ovalline", "Oval"),
	27: ("half", "Half"),
	28: ("trapezoid", "Trapezoid"),
	29: ("parallelogram", "Parallelogram"),
	30: ("plus", "Plus"),
	31: ("saltire", "X"),
	32: ("pill", "Pill"),
	33: ("heartline", "Heart"),
	34: ("spade", "Spade"),
	35: ("club", "Club"),
	36: ("card_diamond", "Card diamond"),
	37: ("sparkline", "Spark"),
	38: ("moon", "Moon"),
	39: ("dropline", "Drop"),
	40: ("boltline", "Bolt"),
	41: ("cloud", "Cloud"),
	42: ("sun", "Sun"),
	43: ("arch", "Arch"),
	44: ("shield", "Shield"),
	45: ("bubble", "Bubble"),
	46: ("bookmark", "Bookmark"),
	47: ("flag", "Flag"),
	48: ("leaf", "Leaf"),
	49: ("infinity", "Infinity"),
	50: ("hourglass", "Hourglass"),
	51: ("round_square", "Round square"),
	52: ("tri_down", "Down triangle"),
	53: ("star6", "Hex star"),
	54: ("burstline", "Burst"),
	55: ("crossline", "Cross"),
	56: ("asterisk", "Asterisk"),
	57: ("bowtie", "Bowtie"),
	58: ("pacman", "Pac"),
	59: ("quarter", "Quarter"),
	60: ("u_shape", "U"),
	61: ("wave", "Wave"),
	62: ("zigzag", "Zigzag"),
	63: ("spiral", "Spiral"),
	64: ("target", "Target"),
	65: ("peace", "Peace"),
	66: ("forbidden", "Forbidden"),
	67: ("check", "Check"),
	68: ("chevronline", "Chevron"),
	69: ("arrow", "Down arrow"),
	70: ("pin", "Pin"),
	71: ("eye", "Eye"),
	72: ("bell", "Bell"),
	73: ("crown", "Crown"),
	74: ("note", "Note"),
}


def mask_bits(path: Path) -> bytes:
	im = Image.open(path).convert("RGBA").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
	px = im.load()
	assert px is not None
	bits = bytearray((SIZE * SIZE + 7) // 8)
	for y in range(SIZE):
		for x in range(SIZE):
			r, g, b, a = px[x, y]
			on = a > 40 and (r + g + b) / 3 < 160
			if on:
				i = y * SIZE + x
				bits[i >> 3] |= 1 << (i & 7)
	return bytes(bits)


def main() -> None:
	entries: list[tuple[str, str, int, str]] = []
	for n in range(15, 75):
		path = RAW / f"frame_{n}.png"
		if not path.exists():
			raise SystemExit(f"missing {path}")
		sid, name = NAMES[n]
		blob = base64.b64encode(mask_bits(path)).decode("ascii")
		entries.append((sid, name, n, blob))

	lines = [
		"--!strict",
		"-- Auto-generated outline pack from Figma Frame 15–74. Rebuild: scripts/build_stencil_pack.py",
		f"local SIZE = {SIZE}",
		"",
		"export type PackEntry = {",
		"\tid: string,",
		"\tname: string,",
		"\tframe: number,",
		"\tmask: string,",
		"}",
		"",
		"local pack: { PackEntry } = {",
	]
	for sid, name, n, blob in entries:
		chunks = [blob[i : i + 100] for i in range(0, len(blob), 100)]
		joined = " ..\n\t\t".join(f'"{c}"' for c in chunks)
		lines.append(f'\t{{ id = "{sid}", name = "{name}", frame = {n}, mask = {joined} }},')
	lines += [
		"}",
		"",
		"local byId: { [string]: PackEntry } = {}",
		"for _, entry in pack do",
		"\tbyId[entry.id] = entry",
		"end",
		"",
		"local StencilPack = {",
		"\tsize = SIZE,",
		"\tentries = pack,",
		"\tbyId = byId,",
		"}",
		"",
		"return StencilPack",
		"",
	]
	OUT.write_text("\n".join(lines))
	print(f"wrote {OUT} ({OUT.stat().st_size} bytes, {len(entries)} shapes)")


if __name__ == "__main__":
	main()
