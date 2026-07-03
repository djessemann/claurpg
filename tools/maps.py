#!/usr/bin/env python3
"""EREBUS — area/map compiler.

Emits src/gen/mapdata.s: several scrolling decks (metatile grids), an area
table (map ptr, width, palette, music, encounter zone, npc/warp lists), NPC
placements, warps, and per-area encounter enemy pools. Maps are read directly
from ROM (data bank 0 at $8000), so they are static.
"""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CH = {
    ".":"MT_FLOOR","o":"MT_FLOOR2","g":"MT_GRATE","#":"MT_WALL","L":"MT_WALLLIT",
    "C":"MT_CONSOLE","D":"MT_DOOR","P":"MT_PIPES","V":"MT_VIEWPORT","*":"MT_STARFIELD",
    "b":"MT_BLOOM","B":"MT_BLOOMWALL","H":"MT_HAZARD","X":"MT_CRATE","T":"MT_TERMINAL",
    "v":"MT_VENT","p":"MT_BEDPOD",
}

class Area:
    def __init__(self, name, w, h=15):
        self.name = name
        self.w = w; self.h = h
        self.g = [["." for _ in range(w)] for _ in range(h)]
    def rect(self,x0,y0,x1,y1,c):
        for y in range(y0,y1+1):
            for x in range(x0,x1+1):
                if 0<=x<self.w and 0<=y<self.h: self.g[y][x]=c
    def border(self,c="#"):
        self.rect(0,0,self.w-1,0,c); self.rect(0,self.h-1,self.w-1,self.h-1,c)
        self.rect(0,0,0,self.h-1,c); self.rect(self.w-1,0,self.w-1,self.h-1,c)
    def put(self,x,y,c): self.g[y][x]=c
    def hwall(self,x0,x1,y,c="#"):
        for x in range(x0,x1+1): self.g[y][x]=c
    def bytes(self):
        out=[]
        for row in self.g:
            for c in row: out.append(CH[c])
        return out

areas=[]
NPCS={}     # area_index -> list of (x,y,sprite,pal,dlg)
WARPS={}    # area_index -> list of (x,y,dest,dx,dy)

# Areas are capped at 32 metatiles wide so the whole deck fits the 2-screen
# nametable torus (no column streaming -> rock-solid smooth scrolling).

# ---------------------------------------------------------------- AREA 0: CRYO
a=Area("CRYO",32); a.border()
a.rect(1,1,30,1,"L")
for x in range(3,30,3):
    a.put(x,3,"p"); a.put(x,4,"o")
    a.put(x,10,"p"); a.put(x,11,"o")
a.rect(2,7,29,7,"g")           # central grated aisle
a.put(5,7,"T"); a.put(26,7,"T")     # terminals
a.put(14,2,"C"); a.put(17,2,"C")
a.put(31,7,"D")                # exit east -> hub
a.put(0,7,"#")
areas.append(a)
NPCS[0]=[(9,6,"SP_NPC_D",1,"DLG_WAKE")]
WARPS[0]=[(31,7,1,1,7)]

# ---------------------------------------------------------------- AREA 1: HUB
a=Area("HUB",32); a.border()
a.rect(1,1,30,1,"L")
a.rect(11,3,20,3,"L")
a.put(5,4,"C"); a.put(6,4,"C")        # vendor console
a.put(5,5,"o"); a.put(6,5,"o")
a.put(25,4,"C"); a.put(26,4,"C")      # repair bay
a.rect(24,5,27,6,"o")
a.put(15,6,"T"); a.put(16,6,"T")      # captain's log terminal
a.rect(8,10,23,12,"o")
a.put(0,7,"D")                        # west -> cryo
a.put(31,7,"D")                       # east -> hydro
a.put(16,14,"D")                      # south -> reactor
areas.append(a)
NPCS[1]=[(5,6,"SP_NPC_D",3,"DLG_VENDOR"),
         (25,7,"SP_NPC_U",1,"DLG_REPAIR"),
         (13,8,"SP_NPC_D",2,"DLG_ENGINEER"),
         (19,9,"SP_NPC_U",1,"DLG_MEDIC")]
WARPS[1]=[(0,7,0,30,7),(31,7,2,1,7),(16,14,3,16,2)]

# ------------------------------------------------------------ AREA 2: HYDRO
a=Area("HYDRO",32); a.border("B")
a.rect(1,1,30,1,"L")
import random; rng=random.Random(3)
for _ in range(50):
    x=rng.randint(2,29); y=rng.randint(2,13)
    a.g[y][x]="b"
a.rect(6,4,7,10,"B"); a.rect(15,3,16,11,"B"); a.rect(24,5,25,12,"B")
for x in range(3,30,6): a.put(x,7,"P")
a.put(4,2,"T"); a.put(27,12,"T")
a.put(0,7,"D"); a.put(31,7,"D")
a.rect(28,3,29,4,"X")
areas.append(a)
NPCS[2]=[(20,4,"SP_NPC_U",2,"DLG_SURVIVOR")]
WARPS[2]=[(0,7,1,30,7),(31,7,4,1,7)]

# ------------------------------------------------------------ AREA 3: REACTOR
a=Area("REACTOR",32); a.border()
a.rect(1,1,30,1,"L")
a.rect(1,13,30,13,"L")
for x in range(4,29,5):
    a.rect(x,3,x+1,4,"P"); a.rect(x,10,x+1,11,"P")
a.rect(12,6,19,8,"H")          # reactor hazard core
a.put(15,5,"C"); a.put(16,5,"C")
a.put(6,7,"C"); a.put(25,7,"C")
a.put(0,7,"D")
a.put(16,2,"D")                # north -> warden chamber
areas.append(a)
NPCS[3]=[]
WARPS[3]=[(0,7,1,16,13),(16,2,5,8,12)]

# ------------------------------------------------------ AREA 4: EAST CORRIDOR
a=Area("CORRIDOR",32); a.border()
a.rect(1,1,30,1,"L")
for x in range(4,29,6): a.put(x,3,"V"); a.put(x,4,"*")
a.rect(2,11,29,11,"g")
for x in range(6,28,7): a.put(x,7,"X")
a.put(0,7,"D"); a.put(31,7,"D")
areas.append(a)
NPCS[4]=[(16,8,"SP_NPC_D",1,"DLG_LOST")]
WARPS[4]=[(0,7,2,30,7),(31,7,2,1,7)]

# -------------------------------------------------- AREA 5: WARDEN CHAMBER
a=Area("WARDEN",32); a.border("L")
a.rect(1,1,30,1,"L")
a.rect(12,3,19,3,"L")
a.put(15,4,"C"); a.put(16,4,"C")
a.rect(2,7,29,7,"g")
a.put(16,12,"D")
a.put(15,6,"T"); a.put(16,6,"T")
areas.append(a)
NPCS[5]=[]
WARPS[5]=[(16,12,3,16,2)]

# encounter zones per area (0=safe): index into enc pools
ZONE = [1,0,2,3,2,0]
# music per area
MUSIC = ["MUS_SHIP","MUS_SAFE","MUS_BLOOM","MUS_HOLD","MUS_SHIP","MUS_BOSS"]
# palette per area (index into pal set in game.s)
PAL = [0,1,2,3,0,3]
# encounter pools: 4 enemy ids per zone
POOLS = {
  1:[0,0,3,0],     # cryo: nanites, a husk
  2:[2,3,2,1],     # hydro: crawlers, husks, drone
  3:[1,4,5,4],     # reactor: drones, turrets, nodes
}

os.makedirs(os.path.join(ROOT,"src","gen"),exist_ok=True)
f=open(os.path.join(ROOT,"src","gen","mapdata.s"),"w")
f.write("; generated by tools/maps.py\n")
f.write('.include "gen/tiles.inc"\n.include "defs.inc"\n')
f.write('.segment "BANK0"\n')
for i,a in enumerate(areas):
    f.write(f".export area{i}_map\narea{i}_map:\n")
    b=a.bytes()
    for r in range(0,len(b),16):
        f.write("  .byte "+",".join(b[r:r+16])+"\n")

# tables in fixed bank
f.write('.segment "RODATA"\n')
f.write(".export area_map_lo, area_map_hi, area_wid, area_zone, area_music, area_pal\n")
f.write("area_map_lo:\n  .byte "+",".join(f"<area{i}_map" for i in range(len(areas)))+"\n")
f.write("area_map_hi:\n  .byte "+",".join(f">area{i}_map" for i in range(len(areas)))+"\n")
f.write("area_wid:\n  .byte "+",".join(str(a.w) for a in areas)+"\n")
f.write("area_zone:\n  .byte "+",".join(str(z) for z in ZONE)+"\n")
f.write("area_music:\n  .byte "+",".join(MUSIC)+"\n")
f.write("area_pal:\n  .byte "+",".join(str(p) for p in PAL)+"\n")

# NPC lists
f.write(".export area_npc_lo, area_npc_hi\n")
for i in range(len(areas)):
    lst=NPCS.get(i,[])
    f.write(f"npc{i}:\n  .byte {len(lst)}\n")
    for (x,y,spr,pal,dlg) in lst:
        f.write(f"  .byte {x},{y},{spr},{pal},{dlg}\n")
f.write("area_npc_lo:\n  .byte "+",".join(f"<npc{i}" for i in range(len(areas)))+"\n")
f.write("area_npc_hi:\n  .byte "+",".join(f">npc{i}" for i in range(len(areas)))+"\n")

# warp lists
f.write(".export area_warp_lo, area_warp_hi\n")
for i in range(len(areas)):
    lst=WARPS.get(i,[])
    f.write(f"warp{i}:\n  .byte {len(lst)}\n")
    for (x,y,dest,dx,dy) in lst:
        f.write(f"  .byte {x},{y},{dest},{dx},{dy}\n")
f.write("area_warp_lo:\n  .byte "+",".join(f"<warp{i}" for i in range(len(areas)))+"\n")
f.write("area_warp_hi:\n  .byte "+",".join(f">warp{i}" for i in range(len(areas)))+"\n")

# encounter pools. The game indexes enc_pools by (zone-1)*4 (see on_step in
# game.s), so row i holds the pool for zone i+1. POOLS is keyed by zone number.
f.write(".export enc_pools\nenc_pools:\n")
for z in range(4):
    pool=POOLS.get(z+1,[0,0,0,0])
    f.write("  .byte "+",".join(str(e) for e in pool)+"\n")
f.close()
print(f"{len(areas)} areas emitted")
