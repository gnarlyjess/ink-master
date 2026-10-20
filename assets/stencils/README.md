# Outline stencil pack

- `raw/` — Figma Frame 15–74 exports (source)
- `white/` — white-on-transparent versions (for Decal upload if needed)
- Game uses embedded bitmasks in `src/shared/StencilPack.luau`

Rebuild masks after changing PNGs:

```bash
.venv-stencils/bin/python scripts/build_stencil_pack.py
```

Desktop copies also live in `~/Desktop/ink-stencils/` (same 60 files, tidied off the Desktop).
