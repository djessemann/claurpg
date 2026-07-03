; EMBERFALL — shared constants
.ifndef DEFS_INC
DEFS_INC = 1

PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014
JOY1      = $4016
JOY2      = $4017

BTN_A      = $80
BTN_B      = $40
BTN_SELECT = $20
BTN_START  = $10
BTN_UP     = $08
BTN_DOWN   = $04
BTN_LEFT   = $02
BTN_RIGHT  = $01

; text encoding: font tiles start at $01 (A) — see tools/gfx.py
.charmap $20, $00              ; space
.repeat 26, I
  .charmap $41 + I, $01 + I    ; A-Z
.endrepeat
.repeat 10, I
  .charmap $30 + I, $1B + I    ; 0-9
.endrepeat
.charmap $2E, $25              ; .
.charmap $2C, $26              ; ,
.charmap $21, $27              ; !
.charmap $3F, $28              ; ?
.charmap $27, $29              ; '
.charmap $2D, $2A              ; -
.charmap $3A, $2B              ; :
.charmap $3E, $2C              ; >
.charmap $2F, $2D              ; /

TXT_END  = $F0
TXT_PAGE = $F1
TXT_NL   = $F2

; metatile attribute flags (low 2 bits = palette)
MTF_SOLID = $04
MTF_ENC   = $08
MTF_WARP  = $10

; dialog handlers
DLG_ELDER = 0
DLG_GUARD = 1
DLG_SHOP  = 2
DLG_INN   = 3
DLG_WOMAN = 4
DLG_MAN   = 5
DLG_SAGE  = 6

; music ids
MUS_NONE   = 0
MUS_FIELD  = 1
MUS_TOWN   = 2
MUS_CAVE   = 3
MUS_TITLE  = 4
MUS_BATTLE = 5
MUS_END    = 6

; sfx ids
SFX_BLIP  = 1
SFX_HIT   = 2
SFX_HURT  = 3
SFX_SPELL = 4
SFX_STAIR = 5
SFX_GOLD  = 6
SFX_FANFARE = 7

; enemies
EN_SLIME  = 0
EN_RAT    = 1
EN_WOLF   = 2
EN_BAT    = 3
EN_WISP   = 4
EN_GOLEM  = 5
EN_KNIGHT = 6
EN_KING   = 7

; screens
SCR_VILLAGE = 9
SCR_CAVE1   = 10
SCR_CAVE2   = 11
SCR_FORGE   = 12

; story flags (sflags)
SF_DOOR = $01
SF_BOSS = $02

MAX_HERBS = 6
MAX_LEVEL = 12

.endif
