; EREBUS — shared constants, MMC1 helpers
.ifndef DEFS_INC
DEFS_INC = 1

PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
OAMDATA   = $2004
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014
APUSTATUS = $4015
JOY1      = $4016
JOY2      = $4017

; MMC1 registers
MMC1_CTRL = $8000
MMC1_CHR0 = $A000
MMC1_CHR1 = $C000
MMC1_PRG  = $E000

BTN_A      = $80
BTN_B      = $40
BTN_SELECT = $20
BTN_START  = $10
BTN_UP     = $08
BTN_DOWN   = $04
BTN_LEFT   = $02
BTN_RIGHT  = $01

; --- text encoding: font tiles start at $01 (A) in every BG bank ---
.charmap $20, $00              ; space
.repeat 26, I
  .charmap $41 + I, $01 + I    ; A-Z -> $01..$1A
.endrepeat
.repeat 10, I
  .charmap $30 + I, $1B + I    ; 0-9 -> $1B..$24
.endrepeat
.charmap $2E, $25              ; .
.charmap $2C, $26              ; ,
.charmap $21, $27              ; !
.charmap $3F, $28              ; ?
.charmap $27, $29              ; '
.charmap $2D, $2A              ; -
.charmap $3A, $2B              ; :
.charmap $3E, $2C              ; > (cursor)
.charmap $2F, $2D              ; /
.charmap $25, $2E              ; %
.charmap $2B, $2F              ; +
.charmap $28, $30              ; (
.charmap $29, $31              ; )
.charmap $D7, $32              ; multiply sign (x) via 0xD7 source
.charmap $23, $33              ; #

CURSOR    = $2C                ; '>' glyph tile

; dialog handler ids
DLG_WAKE=0
DLG_VENDOR=1
DLG_REPAIR=2
DLG_ENGINEER=3
DLG_MEDIC=4
DLG_SURVIVOR=5
DLG_LOST=6
DLG_TERMINAL=$FF

; story flags (sflags bit positions)
SF_KEYCARD=$01
SF_BOSS=$02
SF_WOKE=$04

; text control codes (never collide with glyph tiles $00-$3F)
TXT_END  = $F0
TXT_PAGE = $F1
TXT_NL   = $F2
TXT_NUM  = $F3                 ; followed by 1 byte: which number slot to print
TXT_STR  = $F4                 ; followed by 2 bytes: pointer to sub-string
TXT_WAIT = $F5

; metatile attribute flags (low 2 bits = palette)
MTF_SOLID = $04
MTF_ENC   = $08
MTF_WARP  = $10
MTF_SIGN  = $20                ; examine text
MTF_DAMAGE= $40                ; hazard floor

; music / sfx ids
MUS_NONE=0
MUS_TITLE=1
MUS_SHIP=2
MUS_HOLD=3
MUS_BLOOM=4
MUS_BATTLE=5
MUS_BOSS=6
MUS_END=7
MUS_SAFE=8

SFX_BLIP=1
SFX_HIT=2
SFX_HURT=3
SFX_TECH=4
SFX_DOOR=5
SFX_ITEM=6
SFX_FANFARE=7
SFX_DENY=8
SFX_HEAL=9

; ---- MMC1 write macro (5 serial writes; value must be 5-bit) ----
.macro MMC1W reg
  sta reg
  lsr a
  sta reg
  lsr a
  sta reg
  lsr a
  sta reg
  lsr a
  sta reg
.endmacro

.endif
