; ============================================================================
; battle.s — DQ-style first-person battles, levels, boss, ending
; ============================================================================

.segment "ZEROPAGE"
e_atk:  .res 1
e_def:  .res 1
e_xp:   .res 1
e_gold: .res 1
e_sp:   .res 1                  ; chance/256 of a fire spell
e_fire: .res 1                  ; fire spell base damage
ename:  .res 2
egfx:   .res 2
e_w:    .res 1
e_h:    .res 1
bcol:   .res 1
brow:   .res 1
bres:   .res 1                  ; 0 fight on, 1 enemy dead, 2 fled, 3 hero died
dmg:    .res 1

.segment "CODE"

; ------------------------------------------------------------ derived stats
apply_level:
  ldx lvl
  dex
  lda tbl_str,x
  sta pstr
  lda tbl_agi,x
  sta pagi
  lda tbl_hp,x
  sta maxhp
  lda tbl_mp,x
  sta maxmp
  rts

calc_patk:
  ldx weap
  lda weap_atk,x
  clc
  adc pstr
  rts

calc_pdef:
  lda pagi
  lsr
  sta t3
  ldx armr
  lda armr_def,x
  clc
  adc t3
  rts

; --------------------------------------------------------------- battle setup
battle:
  sta eid
  lda #0
  sta bres
  lda #MUS_BATTLE
  jsr music_play
  jsr screen_off
  jsr oam_clear
  jsr clear_nt
  ; enemy record -> zero page
  lda eid
  asl
  asl
  asl
  asl
  tax
  lda enemy_tbl,x
  sta ename
  lda enemy_tbl+1,x
  sta ename+1
  lda enemy_tbl+2,x
  sta ehp
  lda enemy_tbl+3,x
  sta e_atk
  lda enemy_tbl+4,x
  sta e_def
  lda enemy_tbl+5,x
  sta e_xp
  lda enemy_tbl+6,x
  sta e_gold
  lda enemy_tbl+7,x
  sta e_sp
  lda enemy_tbl+8,x
  sta e_fire
  lda enemy_tbl+9,x
  sta egfx
  lda enemy_tbl+10,x
  sta egfx+1
  lda enemy_tbl+11,x
  sta e_w
  lda enemy_tbl+12,x
  sta e_h
  ; palettes
  jsr load_field_pal
  bit PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$05
  sta PPUADDR
  lda enemy_tbl+13,x
  sta PPUDATA
  lda enemy_tbl+14,x
  sta PPUDATA
  lda enemy_tbl+15,x
  sta PPUDATA
  ; enemy graphic, centered
  lda e_w
  lsr
  sta t3
  lda #16
  sec
  sbc t3
  sta bcol
  lda #9
  sta brow
  lda egfx
  sta p0
  lda egfx+1
  sta p0+1
  lda e_w
  sta t3
  lda e_h
  sta t4
  ldx bcol
  ldy brow
  jsr draw_gfx_blank
  ; windows
  lda #1
  sta wx
  sta wy
  lda #10
  sta ww
  lda #8
  sta wh
  jsr win_blank
  lda #20
  sta wx
  lda #1
  sta wy
  lda #11
  sta ww
  lda #9
  sta wh
  jsr win_blank
  lda #0
  sta wx
  lda #20
  sta wy
  lda #32
  sta ww
  lda #8
  sta wh
  jsr win_blank
  lda #1
  sta dopen_f
  jsr screen_on
  jsr cmd_items_fight
  jsr update_status
  ; intro
  jsr bclear
  lda eid
  cmp #EN_KING
  beq @king
  jsr put_ename
  lda #<txt_b_near
  sta p0
  lda #>txt_b_near
  sta p0+1
  jsr dput_str
  jmp @intro_done
@king:
  lda #<txt_b_kingrise
  sta p0
  lda #>txt_b_kingrise
  sta p0+1
  jsr dput_str
@intro_done:
  jsr bpause
; ----------------------------------------------------------------- turn loop
@turn:
  lda #21
  sta mn_cx
  lda #2
  sta mn_cy
  sta mn_st
  lda #4
  sta curmax
  jsr menu_run
  cmp #0
  beq @fight
  cmp #1
  beq @spell
  cmp #2
  beq @item
  cmp #3
  beq @run
  jmp @turn                     ; B cancels nothing here
@fight:
  jsr player_attack
  jmp @resolve
@spell:
  jsr spell_menu
  jmp @resolve
@item:
  jsr use_item
  jmp @resolve
@run:
  jsr try_run
@resolve:
  lda bres
  cmp #1
  beq @won
  cmp #2
  beq @out
  cmp #3
  beq @out
  cmp #4
  beq @noturn                   ; menu cancelled / nothing happened
  jsr enemy_turn
  lda bres
  cmp #3
  beq @out
@noturn:
  lda #0
  sta bres
  jmp @turn
@won:
  jmp victory
@out:
  lda #0
  sta dopen_f
  rts

; --------------------------------------------------------------- player turn
player_attack:
  jsr bclear
  lda #<txt_b_youatk
  sta p0
  lda #>txt_b_youatk
  sta p0+1
  jsr dput_str
  jsr bpause_s
  lda #SFX_HIT
  jsr sfx_play
  jsr flash_enemy
  jsr calc_patk
  sta t0
  lda e_def
  sta t1
  jsr calc_damage
  sta dmg
  jmp hurt_enemy

; deal dmg to the enemy, report, detect death
hurt_enemy:
  jsr bclear
  jsr put_ename
  lda #<txt_b_takes
  sta p0
  lda #>txt_b_takes
  sta p0+1
  jsr dput_str
  lda dmg
  sta num_lo
  lda #0
  sta num_hi
  jsr dput_num
  lda #<txt_b_dmg
  sta p0
  lda #>txt_b_dmg
  sta p0+1
  jsr dput_str
  jsr bpause
  lda ehp
  sec
  sbc dmg
  sta ehp
  bcc @dead
  beq @dead
  rts
@dead:
  lda #0
  sta ehp
  jsr erase_enemy
  lda #SFX_HURT
  jsr sfx_play
  jsr bclear
  jsr put_ename
  lda #<txt_b_defeated
  sta p0
  lda #>txt_b_defeated
  sta p0+1
  jsr dput_str
  jsr bpause
  lda #1
  sta bres
  rts

; ---------------------------------------------------------------- spell menu
spell_menu:
  jsr cmd_items_spell
  lda #21
  sta mn_cx
  lda #2
  sta mn_cy
  sta mn_st
  lda #3
  sta curmax
  jsr menu_run
  pha
  jsr cmd_items_fight
  pla
  cmp #$FF
  bne @pick
  lda #4
  sta bres                      ; cancelled: back to command menu
  rts
@pick:
  cmp #0
  bne :+
  jmp @heal
:
  cmp #1
  bne :+
  jmp @scorch
:
  ; storm
  lda lvl
  cmp #8
  bcs :+
  jmp @unknown
:
  lda mp
  cmp #9
  bcs :+
  jmp @nomp
:
  sec
  sbc #9
  sta mp
  jsr update_status
  lda #SFX_SPELL
  jsr sfx_play
  jsr bclear
  lda #<txt_b_storm
  sta p0
  lda #>txt_b_storm
  sta p0+1
  jsr dput_str
  jsr bpause_s
  jsr flash_enemy
  lda #12
  jsr rand_mod
  clc
  adc #24
  sta dmg
  jmp hurt_enemy
@heal:
  lda lvl
  cmp #3
  bcc @unknown
  lda mp
  cmp #4
  bcc @nomp
  sec
  sbc #4
  sta mp
  jsr heal_amount
  jsr update_status
  lda #SFX_SPELL
  jsr sfx_play
  jsr bclear
  lda #<txt_b_heal
  sta p0
  lda #>txt_b_heal
  sta p0+1
  jsr dput_str
  jmp bpause
@scorch:
  lda lvl
  cmp #5
  bcc @unknown
  lda mp
  cmp #5
  bcc @nomp
  sec
  sbc #5
  sta mp
  jsr update_status
  lda #SFX_SPELL
  jsr sfx_play
  jsr bclear
  lda #<txt_b_scorch
  sta p0
  lda #>txt_b_scorch
  sta p0+1
  jsr dput_str
  jsr bpause_s
  jsr flash_enemy
  lda #8
  jsr rand_mod
  clc
  adc #14
  sta dmg
  jmp hurt_enemy
@unknown:
  jsr bclear
  lda #<txt_b_unknown
  sta p0
  lda #>txt_b_unknown
  sta p0+1
  jsr dput_str
  jsr bpause
  lda #4
  sta bres
  rts
@nomp:
  jsr bclear
  lda #<txt_nomp
  sta p0
  lda #>txt_nomp
  sta p0+1
  jsr dput_str
  jsr bpause
  lda #4
  sta bres
  rts

; --------------------------------------------------------------------- items
use_item:
  lda herbs
  bne @use
  jsr bclear
  lda #<txt_noherb
  sta p0
  lda #>txt_noherb
  sta p0+1
  jsr dput_str
  jsr bpause
  lda #4
  sta bres
  rts
@use:
  dec herbs
  jsr herb_amount
  jsr update_status
  lda #SFX_SPELL
  jsr sfx_play
  jsr bclear
  lda #<txt_herbed
  sta p0
  lda #>txt_herbed
  sta p0+1
  jsr dput_str
  jmp bpause

; ----------------------------------------------------------------------- run
try_run:
  jsr bclear
  lda #<txt_b_flee
  sta p0
  lda #>txt_b_flee
  sta p0+1
  jsr dput_str
  jsr bpause_s
  lda #160
  sta t4
  lda eid
  cmp #EN_KING
  bne :+
  lda #48
  sta t4
:
  jsr rng_step
  lda rng0
  cmp t4
  bcs @fail
  lda #SFX_STAIR
  jsr sfx_play
  jsr bclear
  lda #<txt_b_fled
  sta p0
  lda #>txt_b_fled
  sta p0+1
  jsr dput_str
  jsr bpause
  lda #2
  sta bres
  rts
@fail:
  jsr bclear
  lda #<txt_b_blocked
  sta p0
  lda #>txt_b_blocked
  sta p0+1
  jsr dput_str
  jmp bpause

; ---------------------------------------------------------------- enemy turn
enemy_turn:
  lda e_sp
  beq @attack
  sta t4
  jsr rng_step
  lda rng0
  cmp t4
  bcs @attack
  ; fire breath
  jsr bclear
  jsr put_ename
  lda #<txt_b_fire
  sta p0
  lda #>txt_b_fire
  sta p0+1
  jsr dput_str
  jsr bpause_s
  lda #8
  jsr rand_mod
  clc
  adc e_fire
  sta dmg
  jmp hurt_player
@attack:
  jsr bclear
  jsr put_ename
  lda #<txt_b_attacks
  sta p0
  lda #>txt_b_attacks
  sta p0+1
  jsr dput_str
  jsr bpause_s
  lda e_atk
  sta t0
  jsr calc_pdef
  sta t1
  jsr calc_damage
  sta dmg
  ; fall through
hurt_player:
  lda #SFX_HURT
  jsr sfx_play
  lda #14
  sta shake
  lda hp
  sec
  sbc dmg
  sta hp
  bcc @dead
  beq @dead
  jsr update_status
  jsr bclear
  lda #<txt_b_youtake
  sta p0
  lda #>txt_b_youtake
  sta p0+1
  jsr dput_str
  lda dmg
  sta num_lo
  lda #0
  sta num_hi
  jsr dput_num
  lda #<txt_b_dmg
  sta p0
  lda #>txt_b_dmg
  sta p0+1
  jsr dput_str
  jmp bpause
@dead:
  lda #0
  sta hp
  jsr update_status
  jmp player_death

; ------------------------------------------------------------------- victory
victory:
  lda #MUS_NONE
  jsr music_play
  lda #SFX_FANFARE
  jsr sfx_play
  jsr bclear
  lda #<txt_b_victory
  sta p0
  lda #>txt_b_victory
  sta p0+1
  jsr dput_str
  lda e_xp
  sta num_lo
  lda #0
  sta num_hi
  jsr dput_num
  lda #<txt_b_xpand
  sta p0
  lda #>txt_b_xpand
  sta p0+1
  jsr dput_str
  lda e_gold
  sta num_lo
  lda #0
  sta num_hi
  jsr dput_num
  lda #<txt_b_goldend
  sta p0
  lda #>txt_b_goldend
  sta p0+1
  jsr dput_str
  jsr bpause
  ; rewards
  lda xp
  clc
  adc e_xp
  sta xp
  bcc :+
  inc xp+1
:
  lda gold
  clc
  adc e_gold
  sta gold
  bcc :+
  inc gold+1
:
  ; level ups
@lvlchk:
  lda lvl
  cmp #MAX_LEVEL
  bcs @lvldone
  ldx lvl
  dex
  txa
  asl
  tax
  lda xp+1
  cmp next_xp+1,x
  bcc @lvldone
  bne @up
  lda xp
  cmp next_xp,x
  bcc @lvldone
@up:
  inc lvl
  jsr apply_level
  jsr update_status
  lda #SFX_FANFARE
  jsr sfx_play
  jsr bclear
  lda #<txt_b_level
  sta p0
  lda #>txt_b_level
  sta p0+1
  jsr dput_str
  lda lvl
  sta num_lo
  lda #0
  sta num_hi
  jsr dput_num
  lda #CH_BANG
  jsr dput_ch
  jsr bpause
  ; new spells?
  lda lvl
  cmp #3
  beq @sheal
  cmp #5
  beq @sscorch
  cmp #8
  beq @sstorm
  jmp @lvlchk
@sheal:
  lda #<txt_l_heal
  sta p0
  lda #>txt_l_heal
  sta p0+1
  jmp @stell
@sscorch:
  lda #<txt_l_scorch
  sta p0
  lda #>txt_l_scorch
  sta p0+1
  jmp @stell
@sstorm:
  lda #<txt_l_storm
  sta p0
  lda #>txt_l_storm
  sta p0+1
@stell:
  jsr bclear
  jsr dput_str
  jsr bpause
  jmp @lvlchk
@lvldone:
  lda #0
  sta dopen_f
  lda eid
  cmp #EN_KING
  bne @plain
  lda sflags
  ora #SF_BOSS
  sta sflags
  jmp ending
@plain:
  rts

; -------------------------------------------------------------------- death
player_death:
  jsr music_stop
  jsr bclear
  lda #<txt_b_fallen
  sta p0
  lda #>txt_b_fallen
  sta p0+1
  jsr dput_str
  jsr bpause
  jsr bpause
  ; half your gold stays on the ash
  lsr gold+1
  ror gold
  lda maxhp
  sta hp
  lda maxmp
  sta mp
  lda #0
  sta dopen_f
  sta shake
  lda #SCR_VILLAGE
  sta screen
  lda #7
  sta px
  lda #3
  sta py
  lda #0
  sta pdir
  jsr load_screen
  lda #<txt_revive
  sta p0
  lda #>txt_revive
  sta p0+1
  jsr say
  lda #3
  sta bres
  rts

; ------------------------------------------------------------------ the boss
boss_event:
  lda #<txt_boss
  sta p0
  lda #>txt_boss
  sta p0+1
  jsr say
  lda #EN_KING
  jsr battle
  jmp load_screen

; -------------------------------------------------------------------- ending
ending:
  jsr screen_off
  jsr oam_clear
  jsr clear_nt
  lda #MUS_END
  jsr music_play
  ldx #0
@lines:
  txa
  pha
  asl
  tay
  lda end_lines,y
  sta p0
  lda end_lines+1,y
  sta p0+1
  pla
  pha
  tax
  lda end_cols,x
  pha
  lda end_rows,x
  tay
  pla
  tax
  jsr blank_print
  pla
  tax
  inx
  cpx #END_NLINES
  bne @lines
  jsr screen_on
@forever:
  jsr wait_frame
  jmp @forever

; ------------------------------------------------------------ battle helpers
put_ename:
  lda ename
  sta p0
  lda ename+1
  sta p0+1
  jmp dput_str

bclear:
  jmp dclear

; long pause (A skips)
bpause:
  lda #48
  sta cnt
  bne bp_go
; short pause
bpause_s:
  lda #22
  sta cnt
bp_go:
  jsr read_pad
@l:
  jsr wait_frame
  jsr read_pad
  lda pad_new
  and #BTN_A
  bne @done
  dec cnt
  bne @l
@done:
  rts

; damage roll: t0 attack vs t1 defense
calc_damage:
  lda t1
  lsr
  sta t1
  lda t0
  sec
  sbc t1
  bcs :+
  lda #0
:
  cmp #2
  bcs :+
  lda #2
:
  sta t0
  lsr
  sta t1                        ; base/2
  lda t0
  lsr
  lsr
  clc
  adc #1                        ; base/4 + 1
  jsr rand_mod
  clc
  adc t1
  rts

; white-out the enemy palette for a moment
flash_enemy:
  lda #$3F
  sta t0
  lda #$05
  sta t1
  lda #$30
  sta rowbuf
  sta rowbuf+1
  sta rowbuf+2
  lda #3
  jsr queue_row
  ldx #6
@w:
  jsr wait_frame
  dex
  bne @w
  lda eid
  asl
  asl
  asl
  asl
  tax
  lda enemy_tbl+13,x
  sta rowbuf
  lda enemy_tbl+14,x
  sta rowbuf+1
  lda enemy_tbl+15,x
  sta rowbuf+2
  lda #$3F
  sta t0
  lda #$05
  sta t1
  lda #3
  jsr queue_row
  jmp wait_frame

erase_enemy:
  lda #0
  sta t5
@row:
  ldx #0
  lda #0
@f:
  sta rowbuf,x
  inx
  cpx e_w
  bne @f
  lda brow
  clc
  adc t5
  tay
  lda bcol
  jsr tile_addr
  lda e_w
  jsr queue_row
  jsr wait_frame
  inc t5
  lda t5
  cmp e_h
  bne @row
  rts

; status window values (buffered)
update_status:
  lda lvl
  ldy #2
  ldx #0
  jsr stat_put
  lda hp
  ldy #4
  ldx #3
  jsr stat_put
  lda mp
  ldy #6
  ldx #6
  ; fall through
; A = value, Y = window row, X = label offset into stat_labels
stat_put:
  sta t0
  sty t4
  lda stat_labels,x
  sta rowbuf
  lda stat_labels+1,x
  sta rowbuf+1
  lda stat_labels+2,x
  sta rowbuf+2
  lda #0
  sta t1
  jsr bin_to_dec
  lda decbuf+2
  bne @h
  lda #0
  beq @hs
@h:
  clc
  adc #CH_0
@hs:
  sta rowbuf+3
  lda decbuf+3
  bne @t
  lda decbuf+2
  bne @t
  lda #0
  beq @ts
@t:
  lda decbuf+3
  clc
  adc #CH_0
@ts:
  sta rowbuf+4
  lda decbuf+4
  clc
  adc #CH_0
  sta rowbuf+5
  ldy t4
  lda #2
  jsr tile_addr
  lda #6
  jmp queue_row

; ---------------------------------------------------- direct-draw primitives
; clear nametable 0 + attributes to palette 3
clear_nt:
  bit PPUSTATUS
  lda #$20
  sta PPUADDR
  lda #$00
  sta PPUADDR
  ldx #0
  ldy #4
  lda #0
@clr:
  sta PPUDATA
  inx
  bne @clr
  dey
  bne @clr
  bit PPUSTATUS
  lda #$23
  sta PPUADDR
  lda #$C0
  sta PPUADDR
  ldx #64
  lda #$FF
@attr:
  sta PPUDATA
  dex
  bne @attr
  ; enemy block -> palette 1
  bit PPUSTATUS
  lda #$23
  sta PPUADDR
  lda #$D3
  sta PPUADDR
  lda #$55
  sta PPUDATA
  sta PPUDATA
  bit PPUSTATUS
  lda #$23
  sta PPUADDR
  lda #$DB
  sta PPUADDR
  lda #$55
  sta PPUDATA
  sta PPUDATA
  rts

; window at (wx,wy) size ww x wh, drawn directly (rendering off)
win_blank:
  lda wy
  sta t3
  lda wy
  clc
  adc wh
  sec
  sbc #1
  sta t4                        ; bottom row
@row:
  ldy t3
  lda wx
  jsr tile_addr
  bit PPUSTATUS
  lda t0
  sta PPUADDR
  lda t1
  sta PPUADDR
  ; left edge
  lda t3
  cmp wy
  beq @top
  cmp t4
  beq @bot
  lda #BORD_L
  sta PPUDATA
  ldx ww
  dex
  dex
  lda #0
@mf:
  sta PPUDATA
  dex
  bne @mf
  lda #BORD_R
  sta PPUDATA
  jmp @next
@top:
  lda #BORD_TL
  sta PPUDATA
  ldx ww
  dex
  dex
  lda #BORD_T
@tf:
  sta PPUDATA
  dex
  bne @tf
  lda #BORD_TR
  sta PPUDATA
  jmp @next
@bot:
  lda #BORD_BL
  sta PPUDATA
  ldx ww
  dex
  dex
  lda #BORD_B
@bf:
  sta PPUDATA
  dex
  bne @bf
  lda #BORD_BR
  sta PPUDATA
@next:
  inc t3
  lda t3
  cmp t4
  bcc @row
  beq @row
  rts

; enemy graphic p0 (t3 wide, t4 tall) at col X row Y — rendering off
draw_gfx_blank:
  stx bcol
  sty brow
  lda #0
  sta t5
@row:
  lda brow
  clc
  adc t5
  tay
  lda bcol
  jsr tile_addr
  bit PPUSTATUS
  lda t0
  sta PPUADDR
  lda t1
  sta PPUADDR
  ldy #0
@col:
  lda (p0),y
  sta PPUDATA
  iny
  cpy t3
  bne @col
  ; advance p0 by one row
  lda p0
  clc
  adc t3
  sta p0
  bcc :+
  inc p0+1
:
  inc t5
  lda t5
  cmp t4
  bne @row
  rts

; command window contents
cmd_items_fight:
  jsr cmd_wipe
  lda #<txt_c_fight
  sta p0
  lda #>txt_c_fight
  sta p0+1
  ldx #22
  ldy #2
  jsr wput
  lda #<txt_c_spell
  sta p0
  lda #>txt_c_spell
  sta p0+1
  ldx #22
  ldy #4
  jsr wput
  lda #<txt_c_item
  sta p0
  lda #>txt_c_item
  sta p0+1
  ldx #22
  ldy #6
  jsr wput
  lda #<txt_c_run
  sta p0
  lda #>txt_c_run
  sta p0+1
  ldx #22
  ldy #8
  jmp wput

cmd_items_spell:
  jsr cmd_wipe
  lda #<txt_c_heal
  sta p0
  lda #>txt_c_heal
  sta p0+1
  ldx #22
  ldy #2
  jsr wput
  lda #<txt_c_scorch
  sta p0
  lda #>txt_c_scorch
  sta p0+1
  ldx #22
  ldy #4
  jsr wput
  lda #<txt_c_storm
  sta p0
  lda #>txt_c_storm
  sta p0+1
  ldx #22
  ldy #6
  jmp wput

cmd_wipe:
  lda #2
  sta t5
@l:
  ldx #0
  lda #0
@f:
  sta rowbuf,x
  inx
  cpx #9
  bne @f
  ldy t5
  lda #21
  jsr tile_addr
  lda #9
  jsr queue_row
  jsr wait_frame
  inc t5
  lda t5
  cmp #9
  bne @l
  rts
