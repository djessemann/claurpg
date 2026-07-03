; ============================================================================
; field.s — main loop, title, map screens, movement, NPCs, shops
; ============================================================================

.segment "ZEROPAGE"
fx:      .res 1                 ; facing/interact target
fy:      .res 1
enc_t:   .res 1                 ; encounter zone scratch
chest_i: .res 1

.segment "CODE"

; ------------------------------------------------------------------- main
main:
  jsr title_screen
  jsr new_game
@loop:
  jsr field_frame
  jmp @loop

new_game:
  lda #1
  sta lvl
  lda #0
  sta xp
  sta xp+1
  sta gold+1
  sta mp
  sta maxmp
  sta weap
  sta armr
  sta haskey
  sta sflags
  sta chests
  sta moving
  sta dopen_f
  sta shake
  lda #16
  sta gold
  lda #1
  sta herbs
  jsr apply_level
  lda maxhp
  sta hp
  lda #SCR_VILLAGE
  sta screen
  lda #7
  sta px
  lda #10
  sta py
  lda #1
  sta pdir
  jmp load_screen

; --------------------------------------------------------------- title screen
title_screen:
  jsr screen_off
  jsr music_stop
  jsr oam_clear
  ; clear nametable
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
  ; attributes: palette 3 everywhere...
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
  ; ...except the flame emblem block (palette 1)
  bit PPUSTATUS
  lda #$23
  sta PPUADDR
  lda #$C3
  sta PPUADDR
  lda #$55
  sta PPUDATA
  sta PPUDATA
  bit PPUSTATUS
  lda #$23
  sta PPUADDR
  lda #$CB
  sta PPUADDR
  lda #$55
  sta PPUDATA
  sta PPUDATA
  ; flame emblem: the wisp graphic, 4x4 tiles at col 14 row 3
  lda #<_GFX_WISP
  sta p0
  lda #>_GFX_WISP
  sta p0+1
  lda #4
  sta t3
  sta t4
  ldx #14
  ldy #3
  jsr draw_gfx_blank
  ; text
  lda #<txt_title1
  sta p0
  lda #>txt_title1
  sta p0+1
  ldx #7
  ldy #11
  jsr blank_print
  lda #<txt_title2
  sta p0
  lda #>txt_title2
  sta p0+1
  ldx #6
  ldy #14
  jsr blank_print
  lda #<txt_title3
  sta p0
  lda #>txt_title3
  sta p0+1
  ldx #10
  ldy #19
  jsr blank_print
  lda #<txt_title4
  sta p0
  lda #>txt_title4
  sta p0+1
  ldx #7
  ldy #27
  jsr blank_print
  ; palettes: black bg, white text, wisp colors in P1
  jsr load_field_pal
  bit PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$05
  sta PPUADDR
  lda #$16
  sta PPUDATA
  lda #$27
  sta PPUDATA
  lda #$30
  sta PPUDATA
  lda #MUS_TITLE
  jsr music_play
  jsr screen_on
@loop:
  jsr wait_frame
  jsr read_pad
  ; blink PRESS START
  lda frame_cnt
  and #$1F
  bne @noblink
  lda frame_cnt
  and #$20
  beq @show
  ldx #0
  lda #0
@wipe:
  sta rowbuf,x
  inx
  cpx #11
  bne @wipe
  jmp @put
@show:
  ldx #0
@cpy:
  lda txt_title3,x
  cmp #TXT_END
  beq @put
  sta rowbuf,x
  inx
  cpx #11
  bne @cpy
@put:
  ldy #19
  lda #10
  jsr tile_addr
  lda #11
  jsr queue_row
@noblink:
  lda pad_new
  and #BTN_START
  beq @loop
  ; season the RNG with the press timing
  lda frame_cnt
  eor rng0
  ora #$01
  sta rng0
  lda #SFX_BLIP
  jsr sfx_play
  rts

; ------------------------------------------------------------- screen loading
load_screen:
  jsr screen_off
  jsr oam_clear
  ldx screen
  lda _screen_music,x
  jsr music_play
  ; copy map into RAM
  ldx screen
  lda _screen_map_lo,x
  sta p0
  lda _screen_map_hi,x
  sta p0+1
  ldy #0
@cp:
  lda (p0),y
  sta maprm,y
  iny
  cpy #240
  bne @cp
  ; the Ash Door stays open once unlocked
  lda screen
  cmp #SCR_CAVE1
  bne @nodoor
  lda sflags
  and #SF_DOOR
  beq @nodoor
  lda #MT_CAVEFLOOR
  sta maprm+3*16+12
@nodoor:
  ; opened chests
  ldx #0
@chest:
  lda _chest_table,x
  cmp #$FF
  beq @chestdone
  cmp screen
  bne @next
  lda _chest_table+3,x
  and chests
  beq @next
  lda _chest_table+2,x
  asl
  asl
  asl
  asl
  clc
  adc _chest_table+1,x
  tay
  lda _chest_table+5,x
  sta maprm,y
@next:
  txa
  clc
  adc #6
  tax
  bne @chest
@chestdone:
  ; NPCs
  ldx screen
  lda _screen_npcs_lo,x
  sta p0
  lda _screen_npcs_hi,x
  sta p0+1
  ldy #0
  lda (p0),y
  sta npc_n
  asl
  asl
  clc
  adc npc_n                     ; count*5
  sta t3
  beq @npcdone
@npc:
  iny
  lda (p0),y
  sta npcs-1,y
  cpy t3
  bne @npc
@npcdone:
  jsr draw_map
  jsr load_field_pal
  jsr sync_hero_px
  jsr field_sprites
  jmp screen_on

load_field_pal:
  bit PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  ldx #0
@l:
  lda field_pal,x
  sta PPUDATA
  inx
  cpx #32
  bne @l
  rts

sync_hero_px:
  lda px
  asl
  asl
  asl
  asl
  sta hx
  lda py
  asl
  asl
  asl
  asl
  sta hy
  rts

; --------------------------------------------------------------- field frame
field_frame:
  jsr read_pad
  lda moving
  bne @move
  lda pad_new
  and #BTN_START
  beq :+
  jsr field_menu
  jmp @draw
:
  lda pad_new
  and #BTN_A
  beq :+
  jsr interact
  jmp @draw
:
  jsr try_walk
  jmp @draw
@move:
  jsr step_pixels
@draw:
  jsr field_sprites
  jmp wait_frame

; ------------------------------------------------------------------ movement
try_walk:
  lda pad
  and #BTN_UP
  beq :+
  lda #1
  bne @have
:
  lda pad
  and #BTN_DOWN
  beq :+
  lda #0
  beq @have
:
  lda pad
  and #BTN_LEFT
  beq :+
  lda #3
  bne @have
:
  lda pad
  and #BTN_RIGHT
  beq :+
  lda #2
  bne @have
:
  rts
@have:
  sta pdir
  tax
  lda px
  clc
  adc dir_dx,x
  sta nx
  lda py
  clc
  adc dir_dy,x
  sta ny
  lda nx
  cmp #16
  bcs try_edge
  lda ny
  cmp #15
  bcs try_edge
  ; solid tile?
  lda ny
  asl
  asl
  asl
  asl
  clc
  adc nx
  tay
  ldx maprm,y
  lda _mt_attr,x
  and #MTF_SOLID
  bne @blocked
  ; NPC in the way?
  jsr npc_at_target
  bcs @blocked
  lda #1
  sta moving
  lda #16
  sta mstep
@blocked:
  rts

; carry set if an NPC stands on (nx,ny)
npc_at_target:
  ldx #0
  ldy npc_n
  beq @no
@l:
  lda npcs,x
  cmp nx
  bne @next
  lda npcs+1,x
  cmp ny
  bne @next
  sec
  rts
@next:
  txa
  clc
  adc #5
  tax
  dey
  bne @l
@no:
  clc
  rts

try_edge:
  ldx screen
  lda _screen_flags,x
  and #$01
  beq @no
  lda nx
  cmp #$FF
  beq @west
  cmp #16
  beq @east
  lda ny
  cmp #$FF
  beq @north
  cmp #15
  beq @south
@no:
  rts
@west:
  ldx screen
  lda scr_col,x
  beq @no
  dec screen
  lda #15
  sta px
  jmp load_screen
@east:
  ldx screen
  lda scr_col,x
  cmp #2
  beq @no
  inc screen
  lda #0
  sta px
  jmp load_screen
@north:
  ldx screen
  lda scr_row,x
  beq @no
  lda screen
  sec
  sbc #3
  sta screen
  lda #14
  sta py
  jmp load_screen
@south:
  ldx screen
  lda scr_row,x
  cmp #2
  beq @no
  lda screen
  clc
  adc #3
  sta screen
  lda #0
  sta py
  jmp load_screen

step_pixels:
  ldx pdir
  lda hx
  clc
  adc dir_dx,x
  clc
  adc dir_dx,x
  sta hx
  lda hy
  clc
  adc dir_dy,x
  clc
  adc dir_dy,x
  sta hy
  dec mstep
  dec mstep
  bne @done
  lda #0
  sta moving
  lda nx
  sta px
  lda ny
  sta py
  jmp on_step
@done:
  rts

; ------------------------------------------------------------- step triggers
on_step:
  jsr do_warp
  bcs @warped
  lda py
  asl
  asl
  asl
  asl
  clc
  adc px
  tay
  ldx maprm,y
  lda _mt_attr,x
  sta t3
  ; the Ash King bars the forge
  lda screen
  cmp #SCR_FORGE
  bne @noboss
  lda py
  cmp #4
  bne @noboss
  lda sflags
  and #SF_BOSS
  bne @noboss
  jmp boss_event
@noboss:
  lda t3
  and #MTF_ENC
  beq @done
  ldx screen
  lda _screen_zone,x
  beq @done
  sta enc_t
  lda #10                       ; encounter rate /256
  sta t4
  lda enc_t
  cmp #4
  bne :+
  lda #18                       ; caves are angrier
  sta t4
:
  jsr rng_step
  lda rng0
  cmp t4
  bcs @done
  ; battle!
  lda enc_t
  sec
  sbc #1
  asl
  asl
  sta t4
  jsr rng_step
  lda rng0
  and #$03
  clc
  adc t4
  tax
  lda zone_enemies,x
  jsr battle
  jmp load_screen               ; redraw field
@warped:
@done:
  rts

; carry set if a warp fired (screen already reloaded)
do_warp:
  ldx #0
@l:
  lda _warp_table,x
  cmp #$FF
  beq @none
  cmp screen
  bne @next
  lda _warp_table+1,x
  cmp px
  bne @next
  lda _warp_table+2,x
  cmp py
  bne @next
  lda _warp_table+3,x
  sta screen
  lda _warp_table+4,x
  sta px
  lda _warp_table+5,x
  sta py
  lda #SFX_STAIR
  jsr sfx_play
  jsr load_screen
  sec
  rts
@next:
  txa
  clc
  adc #6
  tax
  bne @l
@none:
  clc
  rts

; ---------------------------------------------------------------- interaction
interact:
  ldx pdir
  lda px
  clc
  adc dir_dx,x
  sta fx
  lda py
  clc
  adc dir_dy,x
  sta fy
  lda fx
  cmp #16
  bcs @nothing
  lda fy
  cmp #15
  bcs @nothing
  ; NPC?
  ldx #0
  ldy npc_n
  beq @nonpc
@nl:
  lda npcs,x
  cmp fx
  bne @nn
  lda npcs+1,x
  cmp fy
  bne @nn
  lda npcs+4,x
  jmp do_dialog
@nn:
  txa
  clc
  adc #5
  tax
  dey
  bne @nl
@nonpc:
  ; chest?
  ldx #0
@cl:
  lda _chest_table,x
  cmp #$FF
  beq @nochest
  cmp screen
  bne @cn
  lda _chest_table+1,x
  cmp fx
  bne @cn
  lda _chest_table+2,x
  cmp fy
  bne @cn
  lda _chest_table+3,x
  and chests
  bne @cn                       ; already looted (tile is gone anyway)
  stx chest_i
  jmp open_chest
@cn:
  txa
  clc
  adc #6
  tax
  bne @cl
@nochest:
  ; facing tile special?
  lda fy
  asl
  asl
  asl
  asl
  clc
  adc fx
  tay
  lda maprm,y
  cmp #MT_LOCKDOOR
  beq @door
@nothing:
  lda #<txt_nothing
  sta p0
  lda #>txt_nothing
  sta p0+1
  jmp say
@door:
  jmp door_try

open_chest:
  ldx chest_i
  lda _chest_table+3,x
  ora chests
  sta chests
  lda _chest_table+4,x
  sta num_lo
  lda #0
  sta num_hi
  lda _chest_table+4,x
  clc
  adc gold
  sta gold
  bcc :+
  inc gold+1
:
  ; swap the tile out
  lda _chest_table+2,x
  asl
  asl
  asl
  asl
  clc
  adc _chest_table+1,x
  tay
  lda _chest_table+5,x
  sta maprm,y
  jsr redraw_facing
  lda #SFX_GOLD
  jsr sfx_play
  jsr dopen
  lda #<txt_chest1
  sta p0
  lda #>txt_chest1
  sta p0+1
  jsr dput_str
  jsr dput_num
  lda #<txt_chest2
  sta p0
  lda #>txt_chest2
  sta p0+1
  jsr dput_str
  jsr dwait_a
  jmp dclose

door_try:
  lda haskey
  bne @unlock
  lda #<txt_door_locked
  sta p0
  lda #>txt_door_locked
  sta p0+1
  jmp say
@unlock:
  lda sflags
  ora #SF_DOOR
  sta sflags
  lda fy
  asl
  asl
  asl
  asl
  clc
  adc fx
  tay
  lda #MT_CAVEFLOOR
  sta maprm,y
  jsr redraw_facing
  lda #SFX_STAIR
  jsr sfx_play
  lda #<txt_door_open
  sta p0
  lda #>txt_door_open
  sta p0+1
  jmp say

; redraw the metatile at (fx,fy) plus its attribute cell
redraw_facing:
  lda fy
  asl
  asl
  asl
  asl
  clc
  adc fx
  tay
  ldx maprm,y
  lda _mt_tl,x
  sta rowbuf
  lda _mt_tr,x
  sta rowbuf+1
  lda fy
  asl
  tay
  lda fx
  asl
  jsr tile_addr
  lda #2
  jsr queue_row
  lda fy
  asl
  asl
  asl
  asl
  clc
  adc fx
  tay
  ldx maprm,y
  lda _mt_bl,x
  sta rowbuf
  lda _mt_br,x
  sta rowbuf+1
  lda fy
  asl
  tay
  iny
  lda fx
  asl
  jsr tile_addr
  lda #2
  jsr queue_row
  ; attribute byte
  lda fy
  lsr
  asl
  asl
  asl
  sta t3
  lda fx
  lsr
  clc
  adc t3
  tax
  txa
  pha
  jsr attr_calc
  sta rowbuf
  pla
  clc
  adc #$C0
  sta t1
  lda #$23
  sta t0
  lda #1
  jsr queue_row
  jmp wait_frame

; --------------------------------------------------------------------- NPCs
do_dialog:
  asl
  tax
  lda dlg_tbl,x
  sta p1
  lda dlg_tbl+1,x
  sta p1+1
  jmp (p1)

h_elder:
  lda #<txt_elder
  sta p0
  lda #>txt_elder
  sta p0+1
  jmp say

h_guard:
  lda #<txt_guard
  sta p0
  lda #>txt_guard
  sta p0+1
  jmp say

h_woman:
  lda #<txt_woman
  sta p0
  lda #>txt_woman
  sta p0+1
  jmp say

h_man:
  lda #<txt_man
  sta p0
  lda #>txt_man
  sta p0+1
  jmp say

h_sage:
  jsr dopen
  lda #<txt_sage1
  sta p0
  lda #>txt_sage1
  sta p0+1
  jsr dput_str
  lda maxhp
  sta hp
  lda maxmp
  sta mp
  lda #SFX_SPELL
  jsr sfx_play
  lda #<txt_sage2
  sta p0
  lda #>txt_sage2
  sta p0+1
  jsr dput_str
  jsr dwait_a
  jmp dclose

; ---------------------------------------------------------------------- shop
h_shop:
  jsr dopen
  lda #<txt_shop_hi
  sta p0
  lda #>txt_shop_hi
  sta p0+1
  jsr dput_str
  ; wares window
  lda #8
  sta wx
  lda #4
  sta wy
  lda #24
  sta ww
  lda #8
  sta wh
  jsr win_draw
  ldx #0
@items:
  txa
  pha
  lda shop_txt_lo,x
  sta p0
  lda shop_txt_hi,x
  sta p0+1
  txa
  clc
  adc #5
  tay
  ldx #11
  jsr wput
  pla
  tax
  inx
  cpx #5
  bne @items
  lda #9
  sta mn_cx
  lda #5
  sta mn_cy
  lda #1
  sta mn_st
  lda #5
  sta curmax
@loop:
  jsr menu_run
  cmp #$FF
  bne @buy
  ; leave
  jsr dclear
  lda #<txt_shop_bye
  sta p0
  lda #>txt_shop_bye
  sta p0+1
  jsr dput_str
  jsr dwait_a
  jsr dclose
  lda #2
  ldx #4
  jmp restore_rows
@buy:
  sta t3                        ; item index
  tax
  ; can afford?
  lda gold+1
  bne @rich
  lda gold
  cmp shop_price,x
  bcs @rich
  lda #<txt_shop_poor
  sta p0
  lda #>txt_shop_poor
  sta p0+1
  jsr shop_msg
  jmp @loop
@rich:
  ldx t3
  lda shop_kind,x
  beq @herb
  cmp #1
  beq @weapon
  cmp #2
  beq @armor
  ; key
  lda haskey
  bne @haveit
  lda #1
  sta haskey
  jmp @paid
@herb:
  lda herbs
  cmp #MAX_HERBS
  bcs @full
  inc herbs
  jmp @paid
@weapon:
  lda shop_val,x
  cmp weap
  beq @haveit
  bcc @haveit
  sta weap
  jmp @paid
@armor:
  lda shop_val,x
  cmp armr
  beq @haveit
  bcc @haveit
  sta armr
  jmp @paid
@paid:
  ldx t3
  lda gold
  sec
  sbc shop_price,x
  sta gold
  bcs :+
  dec gold+1
:
  lda #SFX_GOLD
  jsr sfx_play
  lda #<txt_shop_thanks
  sta p0
  lda #>txt_shop_thanks
  sta p0+1
  jsr shop_msg
  jmp @loop
@haveit:
  lda #<txt_shop_have
  sta p0
  lda #>txt_shop_have
  sta p0+1
  jsr shop_msg
  jmp @loop
@full:
  lda #<txt_shop_full
  sta p0
  lda #>txt_shop_full
  sta p0+1
  jsr shop_msg
  jmp @loop

shop_msg:
  jsr dclear
  jmp dput_str

; ----------------------------------------------------------------------- inn
h_inn:
  jsr dopen
  lda #<txt_inn_q
  sta p0
  lda #>txt_inn_q
  sta p0+1
  jsr dput_str
  ; yes/no
  lda #20
  sta wx
  lda #4
  sta wy
  lda #12
  sta ww
  lda #8
  sta wh
  jsr win_draw
  lda #<txt_yes
  sta p0
  lda #>txt_yes
  sta p0+1
  ldx #23
  ldy #6
  jsr wput
  lda #<txt_no
  sta p0
  lda #>txt_no
  sta p0+1
  ldx #23
  ldy #8
  jsr wput
  lda #22
  sta mn_cx
  lda #6
  sta mn_cy
  lda #2
  sta mn_st
  lda #2
  sta curmax
  jsr menu_run
  cmp #0
  beq @yes
  ; no
  jsr dclear
  lda #<txt_inn_no
  sta p0
  lda #>txt_inn_no
  sta p0+1
  jsr dput_str
  jsr dwait_a
  jsr dclose
  lda #2
  ldx #4
  jmp restore_rows
@yes:
  lda gold+1
  bne @canpay
  lda gold
  cmp #6
  bcs @canpay
  jsr dclear
  lda #<txt_inn_poor
  sta p0
  lda #>txt_inn_poor
  sta p0+1
  jsr dput_str
  jsr dwait_a
  jsr dclose
  lda #2
  ldx #4
  jmp restore_rows
@canpay:
  lda gold
  sec
  sbc #6
  sta gold
  bcs :+
  dec gold+1
:
  ; sleep: fade out, restore, fade in
  jsr screen_off
  jsr music_stop
  lda maxhp
  sta hp
  lda maxmp
  sta mp
  lda #0
  sta dopen_f
  ldx #70
@zz:
  jsr wait_frame
  dex
  bne @zz
  jsr load_screen
  jsr dopen
  lda #<txt_inn_morning
  sta p0
  lda #>txt_inn_morning
  sta p0+1
  jsr dput_str
  jsr dwait_a
  jmp dclose

; ----------------------------------------------------------------- field menu
field_menu:
  lda #0
  sta wx
  sta wy
  lda #16
  sta ww
  lda #8
  sta wh
  jsr win_draw
  lda #<txt_m_status
  sta p0
  lda #>txt_m_status
  sta p0+1
  ldx #4
  ldy #2
  jsr wput
  lda #<txt_m_heal
  sta p0
  lda #>txt_m_heal
  sta p0+1
  ldx #4
  ldy #4
  jsr wput
  lda #<txt_m_herb
  sta p0
  lda #>txt_m_herb
  sta p0+1
  ldx #4
  ldy #6
  jsr wput
  lda #3
  sta mn_cx
  lda #2
  sta mn_cy
  sta mn_st
  lda #3
  sta curmax
  jsr menu_run
  pha
  lda #0
  ldx #4
  jsr restore_rows
  pla
  cmp #0
  beq @status
  cmp #1
  beq @heal
  cmp #2
  beq @herb
  rts
@status:
  jmp status_show
@heal:
  jmp cast_heal_field
@herb:
  jmp use_herb_field

status_show:
  jsr dopen
  lda #<txt_s_lv
  sta p0
  lda #>txt_s_lv
  sta p0+1
  jsr dput_str
  lda lvl
  sta num_lo
  lda #0
  sta num_hi
  jsr dput_num
  lda #<txt_s_xp
  sta p0
  lda #>txt_s_xp
  sta p0+1
  jsr dput_str
  lda xp
  sta num_lo
  lda xp+1
  sta num_hi
  jsr dput_num
  jsr dnewline
  lda #<txt_s_hp
  sta p0
  lda #>txt_s_hp
  sta p0+1
  jsr dput_str
  lda hp
  sta num_lo
  lda #0
  sta num_hi
  jsr dput_num
  lda #CH_SLASH
  jsr dput_ch
  lda maxhp
  sta num_lo
  jsr dput_num
  lda #<txt_s_mp
  sta p0
  lda #>txt_s_mp
  sta p0+1
  jsr dput_str
  lda mp
  sta num_lo
  jsr dput_num
  lda #CH_SLASH
  jsr dput_ch
  lda maxmp
  sta num_lo
  jsr dput_num
  jsr dnewline
  lda #<txt_s_gold
  sta p0
  lda #>txt_s_gold
  sta p0+1
  jsr dput_str
  lda gold
  sta num_lo
  lda gold+1
  sta num_hi
  jsr dput_num
  lda #<txt_s_herbs
  sta p0
  lda #>txt_s_herbs
  sta p0+1
  jsr dput_str
  lda herbs
  sta num_lo
  lda #0
  sta num_hi
  jsr dput_num
  jsr dpage
  lda #<txt_s_atk
  sta p0
  lda #>txt_s_atk
  sta p0+1
  jsr dput_str
  jsr calc_patk
  sta num_lo
  lda #0
  sta num_hi
  jsr dput_num
  lda #<txt_s_def
  sta p0
  lda #>txt_s_def
  sta p0+1
  jsr dput_str
  jsr calc_pdef
  sta num_lo
  jsr dput_num
  jsr dnewline
  ldx weap
  lda weap_txt_lo,x
  sta p0
  lda weap_txt_hi,x
  sta p0+1
  jsr dput_str
  jsr dnewline
  ldx armr
  lda armr_txt_lo,x
  sta p0
  lda armr_txt_hi,x
  sta p0+1
  jsr dput_str
  lda haskey
  beq @nokey
  lda #<txt_s_key
  sta p0
  lda #>txt_s_key
  sta p0+1
  jsr dput_str
@nokey:
  jsr dwait_a
  jmp dclose

cast_heal_field:
  lda lvl
  cmp #3
  bcs :+
  lda #<txt_nospell
  sta p0
  lda #>txt_nospell
  sta p0+1
  jmp say
:
  lda mp
  cmp #4
  bcs :+
  lda #<txt_nomp
  sta p0
  lda #>txt_nomp
  sta p0+1
  jmp say
:
  lda mp
  sec
  sbc #4
  sta mp
  jsr heal_amount
  lda #SFX_SPELL
  jsr sfx_play
  lda #<txt_healed
  sta p0
  lda #>txt_healed
  sta p0+1
  jmp say

use_herb_field:
  lda herbs
  bne :+
  lda #<txt_noherb
  sta p0
  lda #>txt_noherb
  sta p0+1
  jmp say
:
  dec herbs
  jsr herb_amount
  lda #SFX_SPELL
  jsr sfx_play
  lda #<txt_herbed
  sta p0
  lda #>txt_herbed
  sta p0+1
  jmp say

; hp += 12 + rand(8), capped
heal_amount:
  lda #8
  jsr rand_mod
  clc
  adc #12
  jmp add_hp

herb_amount:
  lda #8
  jsr rand_mod
  clc
  adc #22
add_hp:
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

; ------------------------------------------------------------------- sprites
field_sprites:
  jsr oam_clear
  ; hero
  lda hx
  sta t0
  lda hy
  sta t1
  ldx pdir
  lda hero_base,x
  sta t2
  lda moving
  beq @stand
  lda frame_cnt
  and #$08
  beq @stand
  lda t2
  clc
  adc #4
  sta t2
@stand:
  lda hero_attr,x
  sta t3
  jsr draw_meta16
  ; NPCs
  ldx #0
  lda npc_n
  sta cnt
  beq @done
@nl:
  lda npcs,x
  asl
  asl
  asl
  asl
  sta t0
  lda npcs+1,x
  asl
  asl
  asl
  asl
  sta t1
  lda npcs+2,x
  sta t2
  lda npcs+3,x
  sta t3
  txa
  pha
  jsr draw_meta16
  pla
  tax
  txa
  clc
  adc #5
  tax
  dec cnt
  bne @nl
@done:
  rts

; --------------------------------------------------------------------- tables
.segment "RODATA"
dir_dx:    .byte 0, 0, 1, $FF
dir_dy:    .byte 1, $FF, 0, 0
scr_col:   .byte 0,1,2,0,1,2,0,1,2,0,0,0,0
scr_row:   .byte 0,0,0,1,1,1,2,2,2,0,0,0,0
hero_base: .byte SPR_HD0, SPR_HU0, SPR_HR0, SPR_HR0
hero_attr: .byte $00, $00, $00, $40
dlg_tbl:
  .word h_elder, h_guard, h_shop, h_inn, h_woman, h_man, h_sage
zone_enemies:
  .byte EN_SLIME, EN_RAT,   EN_SLIME, EN_RAT     ; zone 1: meadows
  .byte EN_WOLF,  EN_BAT,   EN_RAT,   EN_WOLF    ; zone 2: woods, roads
  .byte EN_WISP,  EN_GOLEM, EN_WOLF,  EN_BAT     ; zone 3: ashlands
  .byte EN_GOLEM, EN_KNIGHT,EN_WISP,  EN_KNIGHT  ; zone 4: the deep
field_pal:
  .byte $0F,$0A,$2A,$30,  $0F,$02,$21,$30,  $0F,$07,$27,$30,  $0F,$00,$10,$30
  .byte $0F,$0F,$16,$27,  $0F,$0F,$01,$27,  $0F,$0F,$1A,$27,  $0F,$0F,$06,$27
.segment "CODE"
