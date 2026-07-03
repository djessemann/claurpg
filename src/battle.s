; ============================================================================
; battle.s — screen-swap battles (enemy as BG art), techs, items, leveling
; ============================================================================
.include "defs.inc"
.include "gen/tiles.inc"

.importzp p0, p1, p2, pad, pad_new, frame_cnt
.importzp scrollX, scrollXhi, scrollY
.import wait_nmi, ppu_off, ppu_on, read_pad, rand_mod, rng_step
.importzp rng
.import load_palette, clear_nt
.import win_box, win_print, win_clearline, print_num, win_putc
.importzp num_lo, num_hi, uarg
.import menu_run
.importzp mn_col, mn_row, mn_step, mn_count, mn_cur
.importzp lvl, xp, credits, hp, maxhp, en, maxen, weap, armr, chip, skills
.import items, apply_level, calc_atk, calc_def
.import lvl_pow, xp_next, enemy_tbl
.import tech_en, tech_pow, tech_lvl, tech_name_l, tech_name_h
.import item_name_l, item_name_h
.import music_play, sfx_play, redraw_field
.export battle, battle_result

.segment "ZEROPAGE"
eid:    .res 1
ehp:    .res 1
ehp_max:.res 1
e_atk:  .res 1
e_def:  .res 1
e_xp:   .res 1
e_cr:   .res 1
e_ai:   .res 1
e_spec: .res 1
e_w:    .res 1
e_h:    .res 1
egfx:   .res 2
ename:  .res 2
scanned:.res 1
dmg:    .res 1
bcol:   .res 1
brow:   .res 1
btmp:   .res 1
battle_result: .res 1           ; 0 fled/won, 1 died

.segment "CODE"

; A = enemy id
battle:
  sta eid
  asl
  asl
  asl
  asl
  tax                           ; *16
  lda enemy_tbl+0,x
  sta ename
  lda enemy_tbl+1,x
  sta ename+1
  lda enemy_tbl+2,x
  sta ehp
  sta ehp_max
  lda enemy_tbl+3,x
  sta e_atk
  lda enemy_tbl+4,x
  sta e_def
  lda enemy_tbl+5,x
  sta e_xp
  lda enemy_tbl+6,x
  sta e_cr
  lda enemy_tbl+7,x
  sta e_ai
  lda enemy_tbl+8,x
  sta e_spec
  lda enemy_tbl+9,x
  sta egfx
  lda enemy_tbl+10,x
  sta egfx+1
  lda enemy_tbl+11,x
  sta e_w
  lda enemy_tbl+12,x
  sta e_h
  stx eidx                      ; save *16 index for palette bytes
  lda #0
  sta scanned
  sta battle_result
  ; ---- set up battle screen ----
  jsr ppu_off
  lda #0
  sta scrollX
  sta scrollXhi
  sta scrollY
  lda #$20
  jsr clear_nt
  lda #$24
  jsr clear_nt
  jsr draw_enemy_bg
  ; palette: copy template to RAM, patch enemy colors into P1
  ldx #0
@cp:
  lda bpal,x
  sta palbuf,x
  inx
  cpx #32
  bne @cp
  ldx eidx
  lda enemy_tbl+13,x
  sta palbuf+5
  lda enemy_tbl+14,x
  sta palbuf+6
  lda enemy_tbl+15,x
  sta palbuf+7
  lda #<palbuf
  sta p0
  lda #>palbuf
  sta p0+1
  jsr load_palette
  lda #MUS_BATTLE
  jsr music_play
  jsr ppu_on
  ; windows
  jsr draw_status_box
  jsr draw_msg_box
  ; intro
  lda ename
  sta p0
  lda ename+1
  sta p0+1
  jsr msg_line1
  lda #<txt_appears
  sta p0
  lda #>txt_appears
  sta p0+1
  ldx #2
  ldy #24
  jsr win_print
  jsr bpause
; -------------------------------------------------------- turn loop
@turn:
  jsr draw_cmd_box
  lda #22
  sta mn_col
  lda #2
  sta mn_row
  lda #2
  sta mn_step
  lda #5
  sta mn_count
  lda #0
  sta mn_cur
  jsr menu_run
  cmp #0
  bne :+
  jsr do_attack
  jmp @resolve
:
  cmp #1
  bne :+
  lda #0
  sta tech_none
  jsr do_tech
  lda tech_none
  bne @turn
  jmp @resolve
:
  cmp #2
  bne :+
  lda #0
  sta tech_none
  jsr do_item
  lda tech_none
  bne @turn
  jmp @resolve
:
  cmp #3
  bne :+
  jsr do_scan
  jmp @turn                     ; scan doesn't end turn
:
  ; flee
  jsr do_flee
  lda flee_ok
  beq @resolve
  jmp @leave
@resolve:
  lda ehp
  bne @enemyturn
  jmp @victory
@enemyturn:
  jsr enemy_turn
  lda hp
  bne @turn
  jmp @death
@victory:
  jsr do_victory
@leave:
  lda #MUS_NONE
  jsr music_play
  jmp redraw_field
@death:
  lda #1
  sta battle_result
  jsr do_death
  jmp @leave

; ---------------------------------------------------- draw enemy (BG)
draw_enemy_bg:
  lda egfx
  sta p0
  lda egfx+1
  sta p0+1
  ; startcol = (32 - e_w)/2 ; startrow = 5
  lda #32
  sec
  sbc e_w
  lsr
  sta bcol
  lda #5
  sta brow
  lda #0
  sta btmp                      ; row counter
@row:
  bit PPUSTATUS
  lda brow
  clc
  adc btmp
  pha
  lsr
  lsr
  lsr
  ora #$20
  sta PPUADDR
  pla
  and #$07
  asl
  asl
  asl
  asl
  asl
  clc
  adc bcol
  sta PPUADDR
  ldy #0
@col:
  lda (p0),y
  sta PPUDATA
  iny
  cpy e_w
  bne @col
  ; advance gfx ptr by e_w
  lda p0
  clc
  adc e_w
  sta p0
  bcc :+
  inc p0+1
:
  inc btmp
  lda btmp
  cmp e_h
  bne @row
  ; attributes: set covering cells to palette 1
  jsr enemy_attrs
  rts

; set attribute cells covering the enemy region to palette 1
enemy_attrs:
  ; attr cells: cols (bcol/4)..((bcol+e_w-1)/4), rows (brow/4)..((brow+e_h-1)/4)
  lda brow
  lsr
  lsr
  sta btmp                      ; attr row start
@ar:
  lda bcol
  lsr
  lsr
  sta p2                        ; attr col cursor
@ac:
  bit PPUSTATUS
  lda #$23
  sta PPUADDR
  lda btmp
  asl
  asl
  asl
  clc
  adc #$C0
  clc
  adc p2
  sta PPUADDR
  lda #$55                      ; all four quadrants palette 1
  sta PPUDATA
  inc p2
  lda bcol
  clc
  adc e_w
  sec
  sbc #1
  lsr
  lsr
  cmp p2
  bcs @ac
  inc btmp
  lda brow
  clc
  adc e_h
  sec
  sbc #1
  lsr
  lsr
  cmp btmp
  bcs @ar
  rts

; ---------------------------------------------------- windows
draw_status_box:
  lda #0
  sta uarg+0
  lda #0
  sta uarg+1
  lda #11
  sta uarg+2
  lda #7
  sta uarg+3
  jsr win_box
  jmp refresh_status

refresh_status:
  lda #<txt_lv
  sta p0
  lda #>txt_lv
  sta p0+1
  ldx #2
  ldy #1
  jsr win_print
  lda lvl
  sta num_lo
  lda #0
  sta num_hi
  ldx #5
  ldy #1
  jsr print_num
  lda #<txt_hp
  sta p0
  lda #>txt_hp
  sta p0+1
  ldx #2
  ldy #3
  jsr win_print
  lda hp
  sta num_lo
  lda #0
  sta num_hi
  ldx #5
  ldy #3
  jsr print_num
  lda #<txt_en
  sta p0
  lda #>txt_en
  sta p0+1
  ldx #2
  ldy #5
  jsr win_print
  lda en
  sta num_lo
  lda #0
  sta num_hi
  ldx #5
  ldy #5
  jsr print_num
  rts

draw_cmd_box:
  lda #20
  sta uarg+0
  lda #0
  sta uarg+1
  lda #12
  sta uarg+2
  lda #12
  sta uarg+3
  jsr win_box
  lda #0
  sta bi
@l:
  lda bi
  asl
  clc
  adc #2
  tay
  ldx bi
  lda cmd_lo,x
  sta p0
  lda cmd_hi,x
  sta p0+1
  ldx #23
  jsr win_print
  inc bi
  lda bi
  cmp #5
  bne @l
  rts

draw_msg_box:
  lda #0
  sta uarg+0
  lda #22
  sta uarg+1
  lda #32
  sta uarg+2
  lda #8
  sta uarg+3
  jmp win_box

; print string p0 at message line 1 (row 22 interior -> row 23)
msg_line1:
  ldx #2
  ldy #23
  jsr win_print
  rts

clear_msg:
  lda #28
  ldx #2
  ldy #23
  jsr win_clearline
  lda #28
  ldx #2
  ldy #24
  jsr win_clearline
  lda #28
  ldx #2
  ldy #25
  jmp win_clearline

; ---------------------------------------------------- player actions
do_attack:
  jsr clear_msg
  lda #<txt_youhit
  sta p0
  lda #>txt_youhit
  sta p0+1
  jsr msg_line1
  jsr calc_atk
  sta btmp
  lda e_def
  jsr damage_calc               ; dmg = f(btmp atk, e_def)
  lda #SFX_HIT
  jsr sfx_play
  jmp hurt_enemy

do_tech:
  ; sub-menu of known techs
  jsr draw_cmd_box              ; reuse box area for tech list
  ; list techs the player knows
  lda #0
  sta btmp                      ; count
  lda #0
  sta bi
@build:
  ldx bi
  lda skills
  and pow2,x
  beq @skip
  lda btmp
  asl
  clc
  adc #2
  tay
  ldx bi
  lda tech_name_l,x
  sta p0
  lda tech_name_h,x
  sta p0+1
  ldx #23
  jsr win_print
  ldx btmp
  lda bi
  sta tech_map,x
  inc btmp
@skip:
  inc bi
  lda bi
  cmp #5
  bne @build
  lda btmp
  bne :+
  jmp @cancel
:
  lda #22
  sta mn_col
  lda #2
  sta mn_row
  lda #2
  sta mn_step
  lda btmp
  sta mn_count
  lda #0
  sta mn_cur
  jsr menu_run
  cmp #$FF
  bne :+
  jmp @cancel
:
  tax
  lda tech_map,x
  sta btmp                      ; chosen tech id
  tax
  ; enough EN?
  lda en
  cmp tech_en,x
  bcs @cast
  jsr clear_msg
  lda #<txt_noen
  sta p0
  lda #>txt_noen
  sta p0+1
  jsr msg_line1
  jsr bpause
  lda #$FF
  sta tech_none
  rts
@cast:
  lda en
  sec
  sbc tech_en,x
  sta en
  jsr refresh_status
  lda #SFX_TECH
  jsr sfx_play
  ldx btmp
  cpx #1
  beq @repair
  cpx #2
  beq @scan2
  ; damaging tech (PULSE/OVERLOAD/PURGE)
  jsr clear_msg
  ldx btmp
  lda tech_name_l,x
  sta p0
  lda tech_name_h,x
  sta p0+1
  jsr msg_line1
  ldx btmp
  lda tech_pow,x
  sta btmp
  lda #4
  jsr rand_mod
  clc
  adc btmp
  sta btmp
  lda #0                        ; techs bypass some def
  jsr damage_calc
  jmp hurt_enemy
@repair:
  jsr clear_msg
  lda #<txt_repair
  sta p0
  lda #>txt_repair
  sta p0+1
  jsr msg_line1
  lda #20
  jsr rand_mod
  clc
  adc #30
  jsr heal_hp
  jsr refresh_status
  jsr bpause
  rts
@scan2:
  jsr show_scan
  lda #$FF
  sta tech_none                  ; scan doesn't cost a turn
  rts
@cancel:
  lda #$FF
  sta tech_none
  rts

do_scan:
  jsr show_scan
  rts

show_scan:
  lda #1
  sta scanned
  jsr clear_msg
  lda #<txt_scan
  sta p0
  lda #>txt_scan
  sta p0+1
  jsr msg_line1
  lda ename
  sta p0
  lda ename+1
  sta p0+1
  ldx #2
  ldy #24
  jsr win_print
  lda #<txt_hpc
  sta p0
  lda #>txt_hpc
  sta p0+1
  ldx #16
  ldy #24
  jsr win_print
  lda ehp
  sta num_lo
  lda #0
  sta num_hi
  ldx #20
  ldy #24
  jsr print_num
  jsr bpause
  rts

do_item:
  ; list consumables with count>0
  jsr draw_cmd_box
  lda #0
  sta btmp
  sta bi
@bl:
  ldx bi
  lda items,x
  beq @sk
  lda btmp
  asl
  clc
  adc #2
  tay
  ldx bi
  lda item_name_l,x
  sta p0
  lda item_name_h,x
  sta p0+1
  ldx #23
  jsr win_print
  ldx btmp
  lda bi
  sta tech_map,x
  inc btmp
@sk:
  inc bi
  lda bi
  cmp #4
  bne @bl
  lda btmp
  bne :+
  jsr clear_msg
  lda #<txt_noitem
  sta p0
  lda #>txt_noitem
  sta p0+1
  jsr msg_line1
  jsr bpause
  lda #$FF
  sta tech_none
  rts
:
  lda #22
  sta mn_col
  lda #2
  sta mn_row
  lda #2
  sta mn_step
  lda btmp
  sta mn_count
  lda #0
  sta mn_cur
  jsr menu_run
  cmp #$FF
  beq @cancel
  tax
  lda tech_map,x
  sta btmp                      ; item id
  tax
  dec items,x
  lda #SFX_ITEM
  jsr sfx_play
  jsr use_item_effect
  rts
@cancel:
  lda #$FF
  sta tech_none
  rts

; btmp = item id
use_item_effect:
  lda btmp
  beq @repair
  cmp #1
  beq @power
  cmp #2
  beq @patch
  ; purge charge -> damage enemy
  jsr clear_msg
  lda #<txt_purge
  sta p0
  lda #>txt_purge
  sta p0+1
  jsr msg_line1
  lda #35
  sta btmp
  lda #0
  jsr damage_calc
  jmp hurt_enemy
@repair:
  lda #20
  jsr rand_mod
  clc
  adc #40
  jsr heal_hp
  jmp @done
@power:
  lda #10
  jsr rand_mod
  clc
  adc #20
  clc
  adc en
  cmp maxen
  bcc :+
  lda maxen
:
  sta en
  jmp @done
@patch:
  lda maxhp
  sta hp
@done:
  jsr refresh_status
  jsr clear_msg
  lda #<txt_useit
  sta p0
  lda #>txt_useit
  sta p0+1
  jsr msg_line1
  jsr bpause
  rts

do_flee:
  lda #0
  sta flee_ok
  lda eid
  cmp #6                        ; boss can't flee
  beq @no
  jsr rng_step
  lda rng
  cmp #144
  bcc @no
  lda #1
  sta flee_ok
  jsr clear_msg
  lda #<txt_fled
  sta p0
  lda #>txt_fled
  sta p0+1
  jsr msg_line1
  jsr bpause
  rts
@no:
  jsr clear_msg
  lda #<txt_noflee
  sta p0
  lda #>txt_noflee
  sta p0+1
  jsr msg_line1
  jsr bpause
  rts

; ---------------------------------------------------- damage helpers
; btmp = attacker power, A = defender def -> dmg in dmg, applied by caller
damage_calc:
  lsr                           ; def/2
  sta p2
  lda btmp
  sec
  sbc p2
  bcs :+
  lda #1
:
  cmp #1
  bcs :+
  lda #1
:
  sta dmg
  ; + random(power/4 + 1)
  lda btmp
  lsr
  lsr
  clc
  adc #1
  jsr rand_mod
  clc
  adc dmg
  sta dmg
  rts

hurt_enemy:
  jsr clear_msg
  lda ename
  sta p0
  lda ename+1
  sta p0+1
  jsr msg_line1
  lda #<txt_takes
  sta p0
  lda #>txt_takes
  sta p0+1
  ldx #2
  ldy #24
  jsr win_print
  lda dmg
  sta num_lo
  lda #0
  sta num_hi
  ldx #14
  ldy #24
  jsr print_num
  ; apply
  lda ehp
  sec
  sbc dmg
  bcs :+
  lda #0
:
  sta ehp
  lda #14
  sta shake_ct
  jsr bpause
  rts

; A = heal amount, cap at maxhp
heal_hp:
  clc
  adc hp
  bcs @cap
  cmp maxhp
  bcc @ok
@cap:
  lda maxhp
@ok:
  sta hp
  rts

; ---------------------------------------------------- enemy turn
enemy_turn:
  ; special attack?
  lda e_ai
  beq @basic
  jsr rng_step
  lda rng
  cmp e_ai
  bcs @basic
  ; special: heavier hit
  jsr clear_msg
  lda ename
  sta p0
  lda ename+1
  sta p0+1
  jsr msg_line1
  lda #<txt_surge
  sta p0
  lda #>txt_surge
  sta p0+1
  ldx #2
  ldy #24
  jsr win_print
  lda e_spec
  sta btmp
  lda #6
  jsr rand_mod
  clc
  adc btmp
  sta dmg
  jmp @apply
@basic:
  jsr clear_msg
  lda ename
  sta p0
  lda ename+1
  sta p0+1
  jsr msg_line1
  lda #<txt_strikes
  sta p0
  lda #>txt_strikes
  sta p0+1
  ldx #2
  ldy #24
  jsr win_print
  lda e_atk
  sta btmp
  jsr calc_def
  jsr damage_calc
@apply:
  lda #SFX_HURT
  jsr sfx_play
  lda hp
  sec
  sbc dmg
  bcs :+
  lda #0
:
  sta hp
  jsr refresh_status
  jsr bpause
  rts

; ---------------------------------------------------- victory / death
do_victory:
  lda #MUS_NONE
  jsr music_play
  lda #SFX_FANFARE
  jsr sfx_play
  jsr clear_msg
  lda #<txt_down
  sta p0
  lda #>txt_down
  sta p0+1
  jsr msg_line1
  jsr bpause
  jsr clear_msg
  lda #<txt_gain
  sta p0
  lda #>txt_gain
  sta p0+1
  jsr msg_line1
  lda e_xp
  sta num_lo
  lda #0
  sta num_hi
  ldx #10
  ldy #23
  jsr print_num
  lda #<txt_xpc
  sta p0
  lda #>txt_xpc
  sta p0+1
  ldx #16
  ldy #23
  jsr win_print
  lda e_cr
  sta num_lo
  lda #0
  sta num_hi
  ldx #20
  ldy #23
  jsr print_num
  ; award
  lda xp
  clc
  adc e_xp
  sta xp
  bcc :+
  inc xp+1
:
  lda credits
  clc
  adc e_cr
  sta credits
  bcc :+
  inc credits+1
:
  jsr bpause
  jsr check_levelup
  rts

check_levelup:
  lda lvl
  cmp #15
  bcs @done
  ldx lvl
  dex
  txa
  asl
  tax
  lda xp+1
  cmp xp_next+1,x
  bcc @done
  bne @up
  lda xp
  cmp xp_next,x
  bcc @done
@up:
  inc lvl
  jsr apply_level
  lda maxhp
  sta hp
  lda maxen
  sta en
  jsr refresh_status
  lda #SFX_FANFARE
  jsr sfx_play
  jsr clear_msg
  lda #<txt_levelup
  sta p0
  lda #>txt_levelup
  sta p0+1
  jsr msg_line1
  lda lvl
  sta num_lo
  lda #0
  sta num_hi
  ldx #18
  ldy #23
  jsr print_num
  jsr bpause
  jsr learn_check
  jmp check_levelup
@done:
  rts

; learn techs whose level == current level (skip already-known)
learn_check:
  lda #0
  sta bi
@l:
  ldx bi
  lda tech_lvl,x
  cmp lvl
  bne @nx
  lda skills
  and pow2,x
  bne @nx                       ; already known
  lda skills
  ora pow2,x
  sta skills
  jsr clear_msg
  lda #<txt_learn
  sta p0
  lda #>txt_learn
  sta p0+1
  jsr msg_line1
  ldx bi
  lda tech_name_l,x
  sta p0
  lda tech_name_h,x
  sta p0+1
  ldx #14
  ldy #23
  jsr win_print
  jsr bpause
@nx:
  inc bi
  lda bi
  cmp #5
  bne @l
  rts

do_death:
  lda #MUS_NONE
  jsr music_play
  jsr clear_msg
  lda #<txt_offline
  sta p0
  lda #>txt_offline
  sta p0+1
  jsr msg_line1
  jsr bpause
  jsr bpause
  ; revive: half credits, full hp
  lsr credits+1
  ror credits
  lda maxhp
  sta hp
  lda maxen
  sta en
  rts

; ---------------------------------------------------- pause (A or timeout)
bpause:
  lda #55
  sta btmp
  jsr read_pad
@l:
  jsr wait_nmi
  jsr read_pad
  lda pad_new
  and #BTN_A
  bne @done
  dec btmp
  bne @l
@done:
  rts

.segment "ZEROPAGE"
flee_ok:  .res 1
tech_none:.res 1
shake_ct: .res 1
bi:       .res 1
eidx:     .res 1
.exportzp shake_ct

.segment "BSS"
tech_map: .res 5
palbuf:   .res 32

.segment "RODATA"
pow2: .byte 1,2,4,8,16
cmd_lo: .byte <c_atk,<c_tech,<c_item,<c_scan,<c_flee
cmd_hi: .byte >c_atk,>c_tech,>c_item,>c_scan,>c_flee
c_atk:  .byte "ATTACK", TXT_END
c_tech: .byte "TECH", TXT_END
c_item: .byte "ITEM", TXT_END
c_scan: .byte "SCAN", TXT_END
c_flee: .byte "FLEE", TXT_END

txt_lv: .byte "LV", TXT_END
txt_hp: .byte "HP", TXT_END
txt_en: .byte "EN", TXT_END
txt_appears: .byte "INTERCEPTS AXIOM.", TXT_END
txt_youhit:  .byte "AXIOM STRIKES.", TXT_END
txt_takes:   .byte "-", TXT_END
txt_scan:    .byte "SCAN COMPLETE:", TXT_END
txt_hpc:     .byte "HP", TXT_END
txt_repair:  .byte "REPAIR ROUTINE RUNS.", TXT_END
txt_purge:   .byte "PURGE CHARGE DETONATES!", TXT_END
txt_useit:   .byte "SUBSYSTEM RESTORED.", TXT_END
txt_noen:    .byte "NOT ENOUGH ENERGY.", TXT_END
txt_noitem:  .byte "NO ITEMS.", TXT_END
txt_strikes: .byte "LASHES AT AXIOM.", TXT_END
txt_surge:   .byte "SURGES! CRITICAL!", TXT_END
txt_down:    .byte "IS DESTROYED.", TXT_END
txt_gain:    .byte "GET", TXT_END
txt_xpc:     .byte "XP", TXT_END
txt_levelup: .byte "AXIOM ADVANCES. LV", TXT_END
txt_learn:   .byte "LEARNED", TXT_END
txt_offline: .byte "AXIOM GOES OFFLINE...", TXT_END
txt_fled:    .byte "AXIOM DISENGAGES.", TXT_END
txt_noflee:  .byte "CANNOT DISENGAGE!", TXT_END

bpal:
  .byte $0F,$00,$10,$20         ; P0 UI/text
  .byte $0F,$00,$10,$2C         ; P1 enemy (c1,c2,c3 patched at runtime +5,+6,+7)
  .byte $0F,$06,$16,$27         ; P2
  .byte $0F,$0C,$1C,$2C         ; P3
  .byte $0F,$0F,$10,$2C         ; sprite palettes (entry16=$0F keeps backdrop black)
  .byte $0F,$16,$27,$37
  .byte $0F,$13,$23,$29
  .byte $0F,$06,$28,$30
.segment "CODE"
