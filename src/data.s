; ============================================================================
; data.s — player state, stat curves, equipment/item/enemy/tech tables, text
; ============================================================================
.include "defs.inc"
.include "gen/tiles.inc"

.export init_player, apply_level, calc_atk, calc_def
.export lvl, xp, credits, hp, maxhp, en, maxen, weap, armr, chip
.export items, skills, sflags, pname
.export lvl_pow, lvl_def, lvl_hp, lvl_en, xp_next
.export weap_atk, armr_def, weap_name_l, weap_name_h, armr_name_l, armr_name_h
.export item_name_l, item_name_h, tech_name_l, tech_name_h, tech_en, tech_pow, tech_lvl
.export enemy_tbl, chip_name_l, chip_name_h
.export shop_wep_l, shop_wep_h
.import EN_NANITE_gfx, EN_DRONE_gfx, EN_CRAWLER_gfx, EN_HUSK_gfx
.import EN_TURRET_gfx, EN_NODE_gfx, EN_WARDEN_gfx

.segment "ZEROPAGE"
lvl:     .res 1
xp:      .res 2
credits: .res 2
hp:      .res 1
maxhp:   .res 1
en:      .res 1
maxen:   .res 1
weap:    .res 1
armr:    .res 1
chip:    .res 1
skills:  .res 1                 ; bitmask of known techs
sflags:  .res 2                 ; story flags

.segment "BSS"
items:   .res 6                 ; consumable counts
pname:   .res 6                 ; (unused reserve)

.segment "CODE"

init_player:
  lda #1
  sta lvl
  lda #0
  sta xp
  sta xp+1
  sta credits+1
  sta weap
  sta armr
  sta chip
  sta sflags
  sta sflags+1
  lda #40
  sta credits
  lda #%00000101                ; know PULSE(0) + SCAN(2)
  sta skills
  ; a couple starting items
  lda #2
  sta items+0                   ; 2 repair cells
  lda #1
  sta items+1                   ; 1 power cell
  lda #0
  sta items+2
  sta items+3
  jsr apply_level
  lda maxhp
  sta hp
  lda maxen
  sta en
  rts

; set maxhp/maxen from level curve
apply_level:
  ldx lvl
  dex
  lda lvl_hp,x
  sta maxhp
  lda lvl_en,x
  sta maxen
  rts

; A = attack power = lvl_pow + weapon atk
calc_atk:
  ldx lvl
  dex
  lda lvl_pow,x
  ldx weap
  clc
  adc weap_atk,x
  rts

; A = defense = lvl_def + armor def (+ ward chip)
calc_def:
  ldx lvl
  dex
  lda lvl_def,x
  ldx armr
  clc
  adc armr_def,x
  ldx chip
  cpx #2
  bne :+
  clc
  adc #6                        ; WARD chip
:
  rts

.segment "RODATA"
;                L1 L2 L3  L4  L5  L6  L7  L8  L9 L10 L11 L12 L13 L14 L15
lvl_pow: .byte  6, 8,11, 14, 18, 22, 27, 33, 40, 48, 57, 67, 78, 90,104
lvl_def: .byte  4, 5, 7,  9, 12, 15, 18, 22, 27, 32, 38, 45, 53, 62, 72
lvl_hp:  .byte 28,36,45, 56, 68, 82, 98,116,136,158,182,206,226,240,252
lvl_en:  .byte 10,14,18, 24, 30, 38, 46, 56, 68, 82, 98,116,136,158,182
; xp needed to REACH level 2,3,... (16-bit)
xp_next:
  .word 10, 28, 60, 115, 200, 330, 520, 780, 1120, 1560, 2120, 2820, 3680, 4720

weap_atk: .byte 0, 6, 14, 26
armr_def: .byte 0, 8, 18
; techs: en cost, power, min level
tech_en:  .byte 3, 5, 0, 10, 8
tech_pow: .byte 10, 30, 0, 26, 18
tech_lvl: .byte 1, 2, 1, 5, 7

; ---- enemies: 16 bytes ----
; name(2) hp atk def xp cred ai% special gfx(2) w h c1 c2 c3
enemy_tbl:
  .word en_nanite
  .byte 12, 7, 3, 4, 5, 0, 0
  .word EN_NANITE_gfx
  .byte EN_NANITE_W, EN_NANITE_H, $0F, $1C, $2C
  .word en_drone
  .byte 20, 11, 6, 8, 10, 40, 6
  .word EN_DRONE_gfx
  .byte EN_DRONE_W, EN_DRONE_H, $0F, $10, $16
  .word en_crawler
  .byte 26, 14, 5, 12, 8, 0, 0
  .word EN_CRAWLER_gfx
  .byte EN_CRAWLER_W, EN_CRAWLER_H, $0F, $23, $19
  .word en_husk
  .byte 34, 18, 9, 18, 14, 30, 10
  .word EN_HUSK_gfx
  .byte EN_HUSK_W, EN_HUSK_H, $0F, $13, $27
  .word en_turret
  .byte 44, 22, 16, 24, 20, 55, 12
  .word EN_TURRET_gfx
  .byte EN_TURRET_W, EN_TURRET_H, $0F, $10, $16
  .word en_node
  .byte 40, 20, 10, 30, 26, 66, 14
  .word EN_NODE_gfx
  .byte EN_NODE_W, EN_NODE_H, $0F, $28, $16
  .word en_warden
  .byte 180, 30, 18, 200, 0, 70, 20
  .word EN_WARDEN_gfx
  .byte EN_WARDEN_W, EN_WARDEN_H, $0F, $23, $2C

en_nanite:  .byte "NANITE SWARM", TXT_END
en_drone:   .byte "SEC-DRONE", TXT_END
en_crawler: .byte "BLOOM CRAWLER", TXT_END
en_husk:    .byte "CRYO HUSK", TXT_END
en_turret:  .byte "SENTRY TURRET", TXT_END
en_node:    .byte "WARDEN NODE", TXT_END
en_warden:  .byte "THE WARDEN", TXT_END

weap_name_l: .byte <wn0,<wn1,<wn2,<wn3
weap_name_h: .byte >wn0,>wn1,>wn2,>wn3
wn0: .byte "SERVO FISTS", TXT_END
wn1: .byte "SHOCK PROD", TXT_END
wn2: .byte "ARC CUTTER", TXT_END
wn3: .byte "RAIL LANCE", TXT_END
armr_name_l: .byte <an0,<an1,<an2
armr_name_h: .byte >an0,>an1,>an2
an0: .byte "BARE CHASSIS", TXT_END
an1: .byte "PLATE WEAVE", TXT_END
an2: .byte "AEGIS SHELL", TXT_END
chip_name_l: .byte <cn0,<cn1,<cn2
chip_name_h: .byte >cn0,>cn1,>cn2
cn0: .byte "NO CHIP", TXT_END
cn1: .byte "FOCUS CHIP", TXT_END
cn2: .byte "WARD CHIP", TXT_END
item_name_l: .byte <in0,<in1,<in2,<in3
item_name_h: .byte >in0,>in1,>in2,>in3
in0: .byte "REPAIR CELL", TXT_END
in1: .byte "POWER CELL", TXT_END
in2: .byte "NANO PATCH", TXT_END
in3: .byte "PURGE CHARGE", TXT_END
tech_name_l: .byte <tn0,<tn1,<tn2,<tn3,<tn4
tech_name_h: .byte >tn0,>tn1,>tn2,>tn3,>tn4
tn0: .byte "PULSE", TXT_END
tn1: .byte "REPAIR", TXT_END
tn2: .byte "SCAN", TXT_END
tn3: .byte "OVERLOAD", TXT_END
tn4: .byte "PURGE WAVE", TXT_END

; vendor stock pointers (unused placeholder)
shop_wep_l: .byte <wn1,<wn2,<wn3
shop_wep_h: .byte >wn1,>wn2,>wn3
.segment "CODE"
