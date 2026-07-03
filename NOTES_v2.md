# EREBUS (v2) — build notes / architecture

Working design doc so progress survives across sessions.

## Concept
EREBUS — a 900-year-derelict generation starship. You are **AXIOM**, its
caretaker AI, booted by an unknown signal into a maintenance android. Descend
through decaying decks (cryo bay, hydroponics overgrowth, flooded deck, machine
decks, reactor, bridge), fight **the Bloom** (nanite-organic infestation) and
rogue subsystems, learn why the ship died, decide the sleepers' fate.
Sci-fi + gothic-derelict + AI protagonist. Boss: the rogue warden AI / the
signal's source. Currency = "cells" (power cells). Healing = repair/recharge.

## Tech target
- Mapper: **MMC1**, 128K PRG (8×16K: banks 0-6 switchable @ $8000, bank7 fixed
  code @ $C000), 128K CHR (4K banks, BG=CHR window0, sprites=CHR window1).
- Smooth **tile-stepped 4-directional scrolling** (hero centered). One axis
  streamed per step. Vertical mirroring → clean 2-screen horizontal torus;
  vertical torus is tight (test seam on jsnes, mitigate if ugly).
- Battle enemies drawn as **background tiles** (FF1/DW technique) → big,
  multi-palette, no sprite-scanline limit.
- Full menu (Items / Equip / Skills / Status) usable on field AND battle.
- Equipment + economy (buy/sell weapons/armor/accessories), deeper leveling.

## Art brief (from research)
- Field chars 16×16; Right = H-flip of Left; 2-pose ping-pong walk.
- Per-tile palette on metasprites for >3 colors (head vs body different palette).
- Palette indices: outline $0F; steel $00/$10/$20; cool-steel $0C/$1C/$2C;
  cyan glow $2C; skin/tan $17/$27/$37; foliage $0A/$1A/$2A; sickly $09/$19/$29;
  water/energy $01/$11/$21/$22; bloom purple $03/$13/$23, magenta $14/$24;
  amber glow $28/$38; hazard red $06/$16/$26.
- Light top-left, 3-tone hue-shifted ramp, selout outlines, tiny specular
  hotspot for metal/wet, glow = bright core + mid halo, reserve one saturated
  hue for glow, irregular silhouette for Bloom.

## Files (v2)
- rom.cfg          MMC1 128K/128K linker config
- src/defs.inc     constants, charmap, MMC1 write macro
- src/boot.s       reset, MMC1 init, NMI (DMA+queue+scroll), input, RNG, banking
- src/ppu.s        VRAM queue helpers, palette load, nametable fill  [TODO]
- src/scroll.s     map streaming + camera                            [TODO]
- ...              menu, battle, data, gfx/map/music generators      [TODO]

## Status
- [x] Concept, mapper config, defs, boot core, v1 archived (tag v1, archive/v1)
- [ ] ppu.s queue + scroll engine + scroll test
- [ ] sprites/hero + collision
- [ ] areas/warps, menus, battle, economy, story, boss, ending

v1 (EMBERFALL, NROM) is archived at archive/v1/ and git tag `v1`.
