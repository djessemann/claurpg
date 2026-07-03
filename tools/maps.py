#!/usr/bin/env python3
"""EMBERFALL — map compiler.

The 3x3-screen overworld is painted programmatically onto one 48x45 grid and
split into screens; interiors (village, caves, forge) are ASCII art.
Emits src/gen/mapdata.s (screen maps, NPC lists, warps, chests).
"""
import os, random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CHARS = {
    ".": "MT_GRASS",   "*": "MT_FLOWERS", "T": "MT_TREE",    "t": "MT_DEADTREE",
    "~": "MT_WATER",   "^": "MT_MOUNTAIN","=": "MT_PATH",    "a": "MT_ASH",
    "#": "MT_WALL",    "R": "MT_ROOF",    "D": "MT_DOOR",    "V": "MT_VILLAGE",
    "C": "MT_CAVEMOUTH",">": "MT_STAIRSD","<": "MT_STAIRSU", "f": "MT_CAVEFLOOR",
    "W": "MT_CAVEWALL","b": "MT_BRICKFLOOR","n": "MT_COUNTER","X": "MT_CHEST",
    "L": "MT_LOCKDOOR","H": "MT_THRONE",  "F": "MT_FORGE",   "B": "MT_BRIDGE",
    "s": "MT_SWALL",   "h": "MT_SHRINE",
}

# ------------------------------------------------------------- overworld paint
W, H = 48, 45
g = [["." for _ in range(W)] for _ in range(H)]
rng = random.Random(7)

def rect(x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = ch

def scatter(x0, y0, x1, y1, ch, density, keep="."):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if g[y][x] == keep and rng.random() < density:
                g[y][x] = ch

def hline(x0, x1, y, ch):
    for x in range(x0, x1 + 1):
        g[y][x] = ch

def vline(x, y0, y1, ch):
    for y in range(y0, y1 + 1):
        g[y][x] = ch

# world border: mountains N/W/E, sea S
rect(0, 0, W - 1, 1, "^")
rect(0, 0, 1, H - 1, "^")
rect(W - 2, 0, W - 1, H - 1, "^")
rect(0, H - 2, W - 1, H - 1, "~")

# NW frostwood: mountains + forest
rect(0, 0, 14, 3, "^")
scatter(2, 4, 14, 13, "T", 0.55)
# Mount Cinder (NE): big range with the cave mouth
rect(28, 0, W - 1, 8, "^")
rect(42, 9, W - 1, 20, "^")
# ashlands around the mountain (SE quadrant of the north + east)
rect(33, 12, 45, 30, "a")
scatter(33, 12, 45, 30, "t", 0.10, keep="a")
# western wood
scatter(2, 15, 13, 29, "T", 0.5)
rect(2, 20, 5, 24, "T")
# south meadow flowers
scatter(17, 31, 31, 41, "*", 0.12)
scatter(17, 31, 31, 41, "T", 0.08)
# ember lake (SW) with shrine island
rect(3, 32, 12, 42, "~")
rect(6, 36, 8, 38, ".")
g[37][7] = "h"
hline(9, 12, 37, "B")
# cinder shore (SE): sea creeping in
rect(36, 34, 45, 42, "~")
scatter(32, 31, 40, 40, "t", 0.12, keep="a")
# a few decorative peaks
rect(20, 26, 23, 28, "^")
rect(6, 30, 9, 31, "^")

# roads (carved last so nothing blocks them)
vline(24, 10, 21, "=")        # village -> north
hline(24, 40, 10, "=")        # north road -> east to Mount Cinder
vline(40, 9, 10, "=")         # up to the cave mouth
vline(24, 23, 37, "=")        # village -> south
hline(13, 23, 37, "=")        # west to the lake bridge
hline(25, 38, 22, "=")        # village -> east into the ashlands
g[8][40] = "C"                # cave mouth in the mountain face
g[22][24] = "V"               # Tinderholm

overworld = ["".join(row) for row in g]

def ow_screen(sx, sy):
    return [overworld[sy * 15 + r][sx * 16:sx * 16 + 16] for r in range(15)]

# ------------------------------------------------------------------ interiors
VILLAGE = """
TTTTTTTTTTTTTTTT
T..ssssssssss..T
T..sbbbbbbbbs..T
T..sbbbbbbbbs..T
T..ssssbbssss..T
T..............T
T.RRRR....RRRR.T
T.bbbb....bbbb.T
T.nnnn....nnnn.T
T..............T
T...*......*...T
T..............T
TT....X.......TT
TTTTTTT==TTTTTTT
TTTTTTT==TTTTTTT
""".split()

CAVE1 = """
WWWWWWWWWWWWWWWW
WffffWWWWWWWf>WW
WfffffffWWWWfWWW
WWWWWffffWWWLWWW
WXfffffffWWWfWWW
WffffWWffWWWfWWW
WffffWWfffffffWW
WWfffWWffWWWWWWW
WWWffffffWWWWWWW
WWWWWfffffffWWWW
WWWffffWWWffffWW
WWfffffWWWWffffW
WWfffffffffffffW
WWWWWWWf<WWWWWWW
WWWWWWWWWWWWWWWW
""".split()

CAVE2 = """
WWWWWWWWWWWWWWWW
W<ffffWWWWffffXW
WWWWWfWWWWfWWWWW
WWWWWfWWWWfWWWWW
WffffffWWWffffWW
WfWWWWfWWWWWWfWW
WfWWWWffffWWWfWW
WfWWWWWWWfWWWfWW
WffffWWWWfffffWW
WWWWfWWWWWWWWWWW
WWWWffffffff>WWW
WWWWWWWWWWWWWWWW
WWWWWWWWWWWWWWWW
WWWWWWWWWWWWWWWW
WWWWWWWWWWWWWWWW
""".split()

FORGE = """
ssssssssssssssss
sbbbbbbbbbbbbbbs
sbFbbbbHbbbbbFbs
sbbbbbbbbbbbbbbs
sbbbbbbbbbbbbbbs
sbbbbbbbbbbbbbbs
sbbFbbbbbbbbFbbs
sbbbbbbbbbbbbbbs
sbbbbbbbbbbbbbbs
sbbbbbbbbbbbbbbs
sbbbbbbbbbbbbbbs
sbbbbbbbbbbbbbbs
sbbbbbbbbbbbbbbs
sssssss<ssssssss
ssssssssssssssss
""".split()

# screens 0-8: overworld, 9 village, 10/11 caves, 12 forge
screens = [ow_screen(x, y) for y in range(3) for x in range(3)]
screens += [VILLAGE, CAVE1, CAVE2, FORGE]
for i, s in enumerate(screens):
    assert len(s) == 15, f"screen {i}: {len(s)} rows"
    for r in s:
        assert len(r) == 16, f"screen {i}: bad row width {len(r)}: {r!r}"

# music: MUS_FIELD on overworld, MUS_TOWN village, MUS_CAVE caves+forge
music = ["MUS_FIELD"] * 9 + ["MUS_TOWN", "MUS_CAVE", "MUS_CAVE", "MUS_CAVE"]
# encounter zone per screen (0 = safe)
zones = [2, 2, 3,
         1, 1, 3,
         2, 1, 3,
         0, 4, 4, 0]
flags = [1] * 9 + [0] * 4     # bit0 = overworld edge-transitions

# NPCs: (screen, x, y, sprite, palette, dialog)
NPCS = [
    (9,  7,  2, "SPR_NELDER", 2, "DLG_ELDER"),
    (9,  8,  5, "SPR_NGUARD", 3, "DLG_GUARD"),
    (9,  2,  7, "SPR_NKEEP",  1, "DLG_SHOP"),
    (9, 12,  7, "SPR_NKEEP",  2, "DLG_INN"),
    (9,  4, 10, "SPR_NWOMAN", 1, "DLG_WOMAN"),
    (9, 11, 10, "SPR_NMAN",   3, "DLG_MAN"),
    (6,  7,  8, "SPR_NSAGE",  2, "DLG_SAGE"),
]

# warps: (screen, x, y) -> (dest screen, x, y)
WARPS = [
    (4, 8, 7,   9, 7, 13),    # village icon -> Tinderholm
    (9, 7, 14,  4, 8, 8),     # village exit
    (9, 8, 14,  4, 8, 8),
    (2, 8, 8,  10, 8, 12),    # cave mouth -> cave 1
    (10, 8, 13, 2, 8, 9),     # cave 1 exit
    (10, 13, 1, 11, 2, 1),    # cave 1 stairs down -> cave 2
    (11, 1, 1, 10, 12, 1),    # cave 2 stairs up
    (11, 12, 10, 12, 7, 12),  # cave 2 stairs down -> forge
    (12, 7, 13, 11, 11, 10),  # forge exit
]

# chests: (screen, x, y, flagbit, gold, replacement tile)
CHESTS = [
    (9,  6, 12, 0,  30, "MT_GRASS"),
    (10, 1,  4, 1, 120, "MT_CAVEFLOOR"),
    (11, 14, 1, 2, 200, "MT_CAVEFLOOR"),
]

# --------------------------------------------------------------------- emit
os.makedirs(os.path.join(ROOT, "src", "gen"), exist_ok=True)
out = open(os.path.join(ROOT, "src", "gen", "mapdata.s"), "w")
out.write('; generated by tools/maps.py — do not edit\n')
out.write('.include "gen/tileids.inc"\n.include "defs.inc"\n.segment "RODATA"\n')

for i, s in enumerate(screens):
    out.write(f"map_{i}:\n")
    for row in s:
        out.write("  .byte " + ",".join(CHARS[c] for c in row) + "\n")

out.write(".export _screen_map_lo, _screen_map_hi\n_screen_map_lo:\n")
out.write("  .byte " + ",".join(f"<map_{i}" for i in range(len(screens))) + "\n")
out.write("_screen_map_hi:\n")
out.write("  .byte " + ",".join(f">map_{i}" for i in range(len(screens))) + "\n")

out.write(".export _screen_music\n_screen_music:\n  .byte " + ",".join(music) + "\n")
out.write(".export _screen_zone\n_screen_zone:\n  .byte " + ",".join(map(str, zones)) + "\n")
out.write(".export _screen_flags\n_screen_flags:\n  .byte " + ",".join(map(str, flags)) + "\n")

out.write(".export _screen_npcs_lo, _screen_npcs_hi\n")
for i in range(len(screens)):
    lst = [n for n in NPCS if n[0] == i]
    out.write(f"npcs_{i}:\n  .byte {len(lst)}\n")
    for (_, x, y, spr, pal, dlg) in lst:
        out.write(f"  .byte {x},{y},{spr},{pal},{dlg}\n")
out.write("_screen_npcs_lo:\n  .byte " + ",".join(f"<npcs_{i}" for i in range(len(screens))) + "\n")
out.write("_screen_npcs_hi:\n  .byte " + ",".join(f">npcs_{i}" for i in range(len(screens))) + "\n")

out.write(".export _warp_table\n_warp_table:\n")
for (s, x, y, d, dx, dy) in WARPS:
    out.write(f"  .byte {s},{x},{y},{d},{dx},{dy}\n")
out.write("  .byte $FF\n")

out.write(".export _chest_table\n_chest_table:\n")
for (s, x, y, bit, gold, repl) in CHESTS:
    out.write(f"  .byte {s},{x},{y},{1 << bit},{gold},{repl}\n")
out.write("  .byte $FF\n")
out.close()

print(f"{len(screens)} screens emitted")
