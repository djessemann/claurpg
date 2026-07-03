; ============================================================================
; EMBERFALL — a Dragon Quest style RPG for the NES
;
; The sun is dying. A hundred years ago the Ash King stole the Sunheart from
; the Great Forge beneath Mount Cinder, and ever since, embers fall from the
; sky like grey snow. You are the last Sparkkeeper of Tinderholm, sent by the
; Elder to bring the light home.
;
; Mapper 0 (NROM-256), 32KB PRG + 8KB CHR, no save RAM.
; ============================================================================
.include "defs.inc"
.include "gen/tileids.inc"

.segment "HEADER"
  .byte "NES", $1A
  .byte 2                       ; 2x 16KB PRG
  .byte 1                       ; 1x 8KB CHR
  .byte $01                     ; mapper 0, vertical mirroring
  .byte 0, 0, 0, 0, 0, 0, 0, 0, 0

; ----------------------------------------------------------------- zero page
.segment "ZEROPAGE"
nmi_ready:  .res 1              ; main finished a frame; NMI may present it
ppu_on:     .res 1              ; rendering active (NMI presents) or forced blank
frame_cnt:  .res 1
buf_end:    .res 1              ; index of terminator in ppubuf
pad:        .res 1
pad_prev:   .res 1
pad_new:    .res 1
rng0:       .res 1
rng1:       .res 1
p0:         .res 2              ; scratch pointer
p1:         .res 2              ; scratch pointer
t0:         .res 1
t1:         .res 1
t2:         .res 1
t3:         .res 1
t4:         .res 1
t5:         .res 1
shake:      .res 1              ; screen shake timer (battle hits)

; field state
screen:     .res 1
px:         .res 1              ; grid position (16px tiles)
py:         .res 1
pdir:       .res 1              ; 0 down 1 up 2 right 3 left
moving:     .res 1
mstep:      .res 1              ; pixels left in current step
hx:         .res 1              ; hero pixel position
hy:         .res 1
nx:         .res 1              ; step target tile
ny:         .res 1
walkanim:   .res 1

; hero
lvl:        .res 1
xp:         .res 2
gold:       .res 2
hp:         .res 1
maxhp:      .res 1
mp:         .res 1
maxmp:      .res 1
pstr:       .res 1
pagi:       .res 1
weap:       .res 1
armr:       .res 1
herbs:      .res 1
haskey:     .res 1
sflags:     .res 1              ; story flags
chests:     .res 1              ; opened-chest bits

; dialog / text
dptr:       .res 2
dcol:       .res 1
drow:       .res 1

; battle
eid:        .res 1
ehp:        .res 1
cur:        .res 1              ; menu cursor
curmax:     .res 1
cnt:        .res 1

; sound
mus:        .res 1
m1ptr:      .res 2
m2ptr:      .res 2
m1dly:      .res 1
m2dly:      .res 1
sfx_lo:     .res 1              ; frames left of noise sfx
sfx_hi:     .res 1              ; frames left of pulse2 sfx
sfx_step:   .res 1

; --------------------------------------------------------------------- BSS
.segment "BSS"
ppubuf:     .res 128            ; vblank update queue: len,hi,lo,data... 0=end
rowbuf:     .res 40             ; staging area for queue_row
maprm:      .res 240            ; current screen metatiles (mutable)
npc_n:      .res 1
npcs:       .res 40             ; 8 x (x,y,tile,pal,dlg)
OAMBUF      = $0200

; --------------------------------------------------------------------- code
.segment "CODE"
.include "engine.s"
.include "sound.s"
.include "dialog.s"
.include "field.s"
.include "battle.s"
.include "data.s"
.include "gen/gfxdata.s"
.include "gen/mapdata.s"
.include "gen/songs.s"

.segment "VECTORS"
  .word nmi_handler
  .word reset
  .word irq_handler

.segment "CHARS"
  .incbin "../build/chr.bin"
