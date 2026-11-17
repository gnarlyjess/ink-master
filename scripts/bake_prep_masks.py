#!/usr/bin/env python3
"""Bake src/shared/PrepMasks.luau from transparent peach limb PNGs."""

from __future__ import annotations

import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGIONS = {
	"LeftForearm": "assets/limbs/_transparent/LeftForearm_peach.png",
	"LeftUpperArm": "assets/limbs/_transparent/LeftUpperArm_peach.png",
	"LeftThigh": "assets/limbs/_transparent/LeftThigh_peach.png",
	"LeftCalf": "assets/limbs/_transparent/LeftCalf_peach.png",
	"Chest": "assets/limbs/_transparent/Chest_peach.png",
	"Back": "assets/limbs/_transparent/Back_peach.png",
}
BOARD_ASPECTS = [1.35, 1.55, 1.75]
HAIR_COLS, HAIR_ROWS = 32, 40


def crop_window(img_w: int, img_h: int, board_aspect: float):
	img_aspect = img_w / img_h
	if img_aspect > board_aspect:
		vis_w = img_h * board_aspect
		return (img_w - vis_w) / 2, 0.0, vis_w, float(img_h)
	vis_h = img_w / board_aspect
	return 0.0, (img_h - vis_h) / 2, float(img_w), vis_h


def sample_alpha(im: Image.Image, u: float, v: float, board_aspect: float) -> int:
	w, h = im.size
	x0, y0, vw, vh = crop_window(w, h, board_aspect)
	x = int(max(0, min(w - 1, x0 + u * vw)))
	y = int(max(0, min(h - 1, y0 + v * vh)))
	return im.getpixel((x, y))[3]


def main() -> None:
	lines = [
		"--!strict",
		"-- Auto-generated: skin cells for prep hair/dirt under ScaleType.Crop.",
		"-- Regenerate with scripts/bake_prep_masks.py",
		"",
		f"local COLS = {HAIR_COLS}",
		f"local ROWS = {HAIR_ROWS}",
		"",
		"local MASKS: { [string]: string } = {",
	]
	for region, rel in REGIONS.items():
		im = Image.open(os.path.join(ROOT, rel)).convert("RGBA")
		bits: list[str] = []
		for row in range(HAIR_ROWS):
			for col in range(HAIR_COLS):
				u = (col + 0.5) / HAIR_COLS
				v = (row + 0.5) / HAIR_ROWS
				ok = any(sample_alpha(im, u, v, a) >= 128 for a in BOARD_ASPECTS)
				bits.append("1" if ok else "0")
		s = "".join(bits)
		print(region, s.count("1"))
		lines.append(f'\t{region} = "{s}",')
	lines += [
		"}",
		"",
		"local PrepMasks = {}",
		"PrepMasks.COLS = COLS",
		"PrepMasks.ROWS = ROWS",
		"",
		"local decoded: { [string]: { number } } = {}",
		"",
		"function PrepMasks.get(regionId: string): { number }?",
		"\tlocal cached = decoded[regionId]",
		"\tif cached ~= nil then",
		"\t\treturn cached",
		"\tend",
		"\tlocal bits = MASKS[regionId]",
		"\tif bits == nil then",
		"\t\treturn nil",
		"\tend",
		"\tlocal cells = table.create(COLS * ROWS, 0)",
		"\tfor i = 1, #bits do",
		'\t\tcells[i] = if string.sub(bits, i, i) == "1" then 1 else 0',
		"\tend",
		"\tdecoded[regionId] = cells",
		"\treturn cells",
		"end",
		"",
		"function PrepMasks.isSkin(regionId: string, col: number, row: number): boolean",
		"\tlocal cells = PrepMasks.get(regionId)",
		"\tif cells == nil then",
		"\t\treturn true",
		"\tend",
		"\tlocal index = (row - 1) * COLS + col",
		"\treturn cells[index] == 1",
		"end",
		"",
		"function PrepMasks.isSkinUv(regionId: string, x: number, y: number): boolean",
		"\tlocal col = math.clamp(math.floor(x * COLS) + 1, 1, COLS)",
		"\tlocal row = math.clamp(math.floor(y * ROWS) + 1, 1, ROWS)",
		"\treturn PrepMasks.isSkin(regionId, col, row)",
		"end",
		"",
		"return PrepMasks",
		"",
	]
	out = os.path.join(ROOT, "src/shared/PrepMasks.luau")
	with open(out, "w", encoding="utf-8") as f:
		f.write("\n".join(lines))
	print("wrote", out)


if __name__ == "__main__":
	main()
