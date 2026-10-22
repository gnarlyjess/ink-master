# Limb stills

Design-canvas backgrounds: photoreal limb photos (arms/calf) plus improved thigh / chest / back stills.

## Naming

`{RegionId}_{tone}.png` (or `.jpg` masters)

Regions: `LeftForearm`, `LeftUpperArm`, `LeftThigh`, `LeftCalf`, `Chest`, `Back`  
Tones: `fair`, `light`, `peach`, `warm`, `tan`, `olive`, `brown`, `deep`

Aspect ~4:3. Soft studio light, dark backdrop, bare drawable surface.

## Wiring

Upload to Roblox as Image assets, then set ids in `src/shared/LimbPhotos.luau`.

- `_original_peach/` — backups of the earlier placeholder masters  
- `_gen_*_peach.jpg` — improved thigh / chest / back peach masters  
- `blender-out/limbs/` — tone variants used for upload  
