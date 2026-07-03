; ============================================================================
; game.s — main loop, area loading, movement, camera, NPCs, warps, encounters
; ============================================================================
.include "defs.inc"
.include "gen/tiles.inc"

.importzp p0, p1, p2, pad, pad_new, frame_cnt
.importzp scrollX, scrollXhi, scrollY
.import wait_nmi, ppu_off, ppu_on, read_pad, set_chr_bg, set_chr_spr, set_bank
.import load_palette, draw_screen, clear_nt, OAM, draw_col, draw_col_fb, draw_attr_col, rowbase
.import rand_mod, rng_step
.importzp rng, colc, uarg, num_lo, num_hi
.import win_box, win_print, restore_rows_ui, print_num, win_clearline, win_putc
.import menu_run
.importzp mn_col, mn_row, mn_step, mn_count, mn_cur
.import mt_attr_tbl
.import spr_AX_D0, spr_AX_D1, spr_AX_U0, spr_AX_U1, spr_AX_L0, spr_AX_L1
.import init_player, battle, battle_result, sfx_play, music_play
.import run_ending
.import area_map_lo, area_map_hi, area_wid, area_zone, area_music, area_pal
.import area_npc_lo, area_npc_hi, area_warp_lo, area_warp_hi, enc_pools
.import lvl, hp, maxhp, en, maxen, credits, sflags
.import do_dialog
.export main_init, redraw_field, center_cam, build_oam, load_area
.export cur_area, htx, hty, warp_dest, warp_dx, warp_dy
.export field_pal, fx, fy

.segment "ZEROPAGE"
htx:   .res 1
hty:   .res 1
hpxL:  .res 1
hpxH:  .res 1
hpy:   .res 1
hdir:  .res 1
moving:.res 1
mstep: .res 1
ntx:   .res 1
nty:   .res 1
camL:  .res 1
camH:  .res 1
sx:    .res 1
sy:    .res 1
oami:  .res 1
col_first: .res 1
col_last:  .res 1
wcol:      .res 1
tmp_r:     .res 1
cur_area:  .res 1
area_zoneN: .res 1
npc_ptr:   .res 2
npc_n:     .res 1
warp_ptr:  .res 2
warp_n:    .res 1
step_lo:   .res 1
fx:    .res 1
fy:    .res 1
warp_dest: .res 1
warp_dx:   .res 1
warp_dy:   .res 1
warp_pending: .res 1
maxcamx:   .res 1               ; (area_w*16-256)>>8 handling -> store hi/lo
maxcamxH:  .res 1

.segment "CODE"

main_init:
  jsr init_player
  lda #0
  sta cur_area
  lda #6
  sta htx
  lda #6
  sta hty
  lda #2
  sta hdir
  lda cur_area
  jsr load_area
field_loop:
  jsr read_pad
  lda moving
  bne @step
  lda pad_new
  and #BTN_START
  beq :+
  jsr field_menu
  jmp @after
:
  lda pad_new
  and #BTN_A
  beq :+
  jsr interact
  jmp @after
:
  jsr try_move
  jmp @after
@step:
  jsr do_step
  lda warp_pending
  beq @after
  lda #0
  sta warp_pending
  lda warp_dx
  sta htx
  lda warp_dy
  sta hty
  lda warp_dest
  jsr load_area
  jmp field_loop
@after:
  jsr center_cam
  jsr stream_cols
  jsr build_oam
  jsr wait_nmi
  jmp field_loop

; ---------------------------------------------------------- area loading
; A = area id ; hero at (htx,hty) must be preset
load_area:
  sta cur_area
  lda #0
  jsr set_bank                  ; map data bank
  ldx cur_area
  lda area_map_lo,x
  sta area_map_ptr
  lda area_map_hi,x
  sta area_map_ptr+1
  lda area_wid,x
  sta area_w
  lda area_zone,x
  sta area_zoneN
  lda area_npc_lo,x
  sta npc_ptr
  lda area_npc_hi,x
  sta npc_ptr+1
  lda area_warp_lo,x
  sta warp_ptr
  lda area_warp_hi,x
  sta warp_ptr+1
  ldy #0
  lda (npc_ptr),y
  sta npc_n
  lda (warp_ptr),y
  sta warp_n
  ; maxcamx = area_w*16 - 256  (16-bit)
  lda area_w
  asl
  asl
  asl
  asl
  sta maxcamx                   ; low of area_w*16
  lda area_w
  lsr
  lsr
  lsr
  lsr
  sta maxcamxH                  ; high of area_w*16
  ; subtract 256 -> just decrement high by 1
  dec maxcamxH
  lda area_music,x
  jsr music_play
  jsr ppu_off
  jsr load_field_pal
  lda #0
  sta moving
  jsr sync_hero_px
  jsr center_cam
  jsr recalc_cols
  jsr draw_area_fb
  jsr build_oam
  jmp ppu_on

; col_first = worldX>>4 clamped to [0, area_w-32]; col_last = col_first+31
recalc_cols:
  lda camL
  lsr
  lsr
  lsr
  lsr
  sta col_first
  lda camH
  asl
  asl
  asl
  asl
  ora col_first
  sta col_first
  lda area_w
  sec
  sbc #32
  cmp col_first
  bcs :+
  sta col_first
:
  lda col_first
  clc
  adc #31
  sta col_last
  rts

load_field_pal:
  ldx cur_area
  lda area_pal,x
  asl
  asl
  asl
  asl
  asl                           ; *32
  tax
  ; p0 = field_pal + area_pal*32
  lda #<field_pal
  sta p0
  lda #>field_pal
  clc
  adc #0
  sta p0+1
  txa
  clc
  adc p0
  sta p0
  bcc :+
  inc p0+1
:
  jmp load_palette

sync_hero_px:
  lda htx
  asl
  asl
  asl
  asl
  sta hpxL
  lda htx
  lsr
  lsr
  lsr
  lsr
  sta hpxH
  lda hty
  asl
  asl
  asl
  asl
  sta hpy
  rts

; ------------------------------------------------------------- movement
try_move:
  lda pad
  and #BTN_UP
  beq :+
  lda #1
  jmp @go
:
  lda pad
  and #BTN_DOWN
  beq :+
  lda #0
  jmp @go
:
  lda pad
  and #BTN_LEFT
  beq :+
  lda #3
  jmp @go
:
  lda pad
  and #BTN_RIGHT
  beq :+
  lda #2
  jmp @go
:
  rts
@go:
  sta hdir
  tax
  lda htx
  clc
  adc dx_tbl,x
  sta ntx
  lda hty
  clc
  adc dy_tbl,x
  sta nty
  lda ntx
  cmp area_w
  bcs @blocked
  lda nty
  cmp #15
  bcs @blocked
  jsr target_solid
  bne @blocked
  jsr npc_at_target
  bcs @blocked
  lda #1
  sta moving
  lda #16
  sta mstep
@blocked:
  rts

target_solid:
  lda area_map_ptr
  sta p0
  lda area_map_ptr+1
  sta p0+1
  lda area_w
  sta p1
  lda nty
  jsr rowbase
  lda p2
  clc
  adc ntx
  sta p2
  bcc :+
  inc p2+1
:
  ldy #0
  lda (p2),y
  tax
  lda mt_attr_tbl,x
  and #MTF_SOLID
  rts

; carry set if an NPC is on (ntx,nty)
npc_at_target:
  lda npc_n
  beq @no
  lda npc_ptr
  clc
  adc #1
  sta p0
  lda npc_ptr+1
  adc #0
  sta p0+1
  ldx npc_n
  ldy #0
@l:
  lda (p0),y
  cmp ntx
  bne @next
  iny
  lda (p0),y
  dey
  cmp nty
  bne @next
  sec
  rts
@next:
  tya
  clc
  adc #5
  tay
  dex
  bne @l
@no:
  clc
  rts

do_step:
  ldx hdir
  lda dx_tbl,x
  bpl :+
  lda hpxL
  sec
  sbc #2
  sta hpxL
  bcs @dy
  dec hpxH
  jmp @dy
:
  lda dx_tbl,x
  beq @dy
  lda hpxL
  clc
  adc #2
  sta hpxL
  bcc @dy
  inc hpxH
@dy:
  ldx hdir
  lda dy_tbl,x
  bpl :+
  lda hpy
  sec
  sbc #2
  sta hpy
  jmp @tick
:
  lda dy_tbl,x
  beq @tick
  lda hpy
  clc
  adc #2
  sta hpy
@tick:
  dec mstep
  dec mstep
  bne @done
  lda #0
  sta moving
  lda ntx
  sta htx
  lda nty
  sta hty
  jsr on_step
@done:
  rts

; ------------------------------------------------------------- step triggers
on_step:
  jsr check_warp
  bcs @done
  ; boss trigger in the WARDEN chamber
  lda cur_area
  cmp #5
  bne @enc
  lda sflags
  and #SF_BOSS
  bne @enc
  lda hty
  cmp #6
  bne @enc
  lda #6
  jsr battle
  lda battle_result
  beq @bosswon
  jmp redraw_field
@bosswon:
  lda sflags
  ora #SF_BOSS
  sta sflags
  jmp run_ending
@enc:
  ; encounter?
  lda area_zoneN
  beq @done
  ; tile has ENC flag?
  lda hty
  jsr map_tile                  ; A = metatile id at (htx,hty)
  tax
  lda mt_attr_tbl,x
  and #MTF_ENC
  beq @done
  jsr rng_step
  lda rng
  cmp #24                       ; ~9% per step
  bcs @done
  ; pick enemy from pool[zone]
  lda area_zoneN
  sec
  sbc #1
  asl
  asl
  sta sx
  jsr rng_step
  lda rng
  and #$03
  clc
  adc sx
  tax
  lda enc_pools,x
  jsr battle
  jmp redraw_field
@done:
  rts

; A=row(hty implied) ; returns metatile id at (htx, A) in A
map_tile:
  pha
  lda area_map_ptr
  sta p0
  lda area_map_ptr+1
  sta p0+1
  lda area_w
  sta p1
  pla
  jsr rowbase
  lda p2
  clc
  adc htx
  sta p2
  bcc :+
  inc p2+1
:
  ldy #0
  lda (p2),y
  rts

; carry set if a warp fired (and area reloaded)
check_warp:
  lda warp_n
  beq @none
  lda warp_ptr
  clc
  adc #1
  sta p0
  lda warp_ptr+1
  adc #0
  sta p0+1
  ldx warp_n
  ldy #0
@l:
  lda (p0),y
  cmp htx
  bne @next
  iny
  lda (p0),y
  dey
  cmp hty
  bne @next
  ; matched! dest at +2, dx +3, dy +4
  ldy #2
  lda (p0),y
  sta warp_dest
  iny
  lda (p0),y
  sta warp_dx
  iny
  lda (p0),y
  sta warp_dy
  lda #SFX_DOOR
  jsr sfx_play
  lda #1
  sta warp_pending              ; defer the actual load to field_loop top level
  sec
  rts
@next:
  tya
  clc
  adc #5
  tay
  dex
  bne @l
@none:
  clc
  rts

; -------------------------------------------------------------- camera
center_cam:
  lda hpxL
  sec
  sbc #120
  sta camL
  lda hpxH
  sbc #0
  sta camH
  bcs @nn
  lda #0
  sta camL
  sta camH
  jmp @set
@nn:
  ; clamp to maxcamx (maxcamxH:maxcamx)
  lda camH
  cmp maxcamxH
  bcc @set
  bne @cap
  lda camL
  cmp maxcamx
  bcc @set
@cap:
  lda maxcamx
  sta camL
  lda maxcamxH
  sta camH
@set:
  lda camL
  sta scrollX
  lda camH
  and #$01
  sta scrollXhi
  lda #0
  sta scrollY
  rts

; ---------------------------------------------------------- draw area
draw_area_fb:
  lda area_map_ptr
  sta p0
  lda area_map_ptr+1
  sta p0+1
  lda area_w
  sta p1
  lda col_first
  sta colc
  ldx #32
@l:
  stx sx
  jsr draw_col_fb
  inc colc
  ldx sx
  dex
  bne @l
  rts

redraw_field:
  jsr ppu_off
  lda #0
  jsr set_bank
  jsr load_field_pal
  jsr center_cam
  jsr recalc_cols
  jsr draw_area_fb
  jsr build_oam
  jmp ppu_on

; --------------------------------------------------------- column streaming
stream_cols:
  lda area_map_ptr
  sta p0
  lda area_map_ptr+1
  sta p0+1
  lda area_w
  sta p1
  lda camL
  lsr
  lsr
  lsr
  lsr
  sta wcol
  lda camH
  asl
  asl
  asl
  asl
  ora wcol
  sta wcol
  lda wcol
  clc
  adc #16
  sta tmp_r
  lda col_last
  cmp tmp_r
  bcs @left
  lda col_last
  clc
  adc #1
  cmp area_w
  bcs @left
  inc col_last
  lda col_last
  sta colc
  jsr draw_col
  jsr draw_attr_col              ; attr from map (valid even before pair tiles)
  lda col_last
  sec
  sbc #31
  cmp col_first
  bcc @left
  sta col_first
@left:
  lda col_first
  cmp wcol
  bcc @done
  beq @done
  lda col_first
  beq @done
  dec col_first
  lda col_first
  sta colc
  jsr draw_col
  jsr draw_attr_col
  lda col_first
  clc
  adc #31
  cmp col_last
  bcs @done
  sta col_last
@done:
  rts

; -------------------------------------------------------------- interaction
interact:
  ldx hdir
  lda htx
  clc
  adc dx_tbl,x
  sta fx
  lda hty
  clc
  adc dy_tbl,x
  sta fy
  ; NPC?
  lda npc_n
  beq @noNpc
  lda npc_ptr
  clc
  adc #1
  sta p0
  lda npc_ptr+1
  adc #0
  sta p0+1
  ldx npc_n
  ldy #0
@l:
  lda (p0),y
  cmp fx
  bne @next
  iny
  lda (p0),y
  dey
  cmp fy
  bne @next
  ; found NPC: dlg id at +4
  iny
  iny
  iny
  iny
  lda (p0),y
  jmp do_dialog
@next:
  tya
  clc
  adc #5
  tay
  dex
  bne @l
@noNpc:
  ; terminal (SIGN) tile?
  lda fy
  cmp #15
  bcs @none
  lda fx
  cmp area_w
  bcs @none
  ; read facing tile
  lda area_map_ptr
  sta p0
  lda area_map_ptr+1
  sta p0+1
  lda area_w
  sta p1
  lda fy
  jsr rowbase
  lda p2
  clc
  adc fx
  sta p2
  bcc :+
  inc p2+1
:
  ldy #0
  lda (p2),y
  tax
  lda mt_attr_tbl,x
  and #MTF_SIGN
  beq @none
  lda #$FF                      ; special: terminal dialog
  jmp do_dialog
@none:
  rts

; -------------------------------------------------------------- field menu
.import field_menu

; ------------------------------------------------------------------ sprites
build_oam:
  lda #0
  sta oami
  ; hero centered
  lda hpxL
  sec
  sbc camL
  sta sx
  lda hpy
  sta sy
  jsr hero_frame
  lda hdir
  cmp #2
  bne :+
  lda #$40
  jmp @a
:
  lda #$00
@a:
  sta p1
  jsr draw_meta16
  ; NPCs
  lda npc_n
  beq @clr
  lda npc_ptr
  clc
  adc #1
  sta p2
  lda npc_ptr+1
  adc #0
  sta p2+1
  lda npc_n
  sta sy+1                       ; count (reuse)
@nl:
  ; npc x,y in world tiles -> screen px
  ldy #0
  lda (p2),y
  asl
  asl
  asl
  asl
  sec
  sbc camL
  sta sx
  ; if off-screen (>240 wrap) skip? keep simple
  ldy #1
  lda (p2),y
  asl
  asl
  asl
  asl
  sta sy
  ldy #2
  lda (p2),y
  sta p0                         ; sprite tile base
  ; sprite is 2x2 consecutive: build p0 -> pointer to 4-tile list? use tilebase
  ldy #3
  lda (p2),y
  sta p1                         ; palette attr
  jsr draw_npc
  lda p2
  clc
  adc #5
  sta p2
  bcc :+
  inc p2+1
:
  dec sy+1
  bne @nl
@clr:
  ldx oami
  lda #$F0
@c:
  sta OAM,x
  inx
  inx
  inx
  inx
  bne @c
  rts

; draw NPC 16x16 from tile base in p0, attr in p1, pos sx/sy (consecutive tiles)
draw_npc:
  ldx oami
  lda sy
  sta OAM,x
  lda p0
  sta OAM+1,x
  lda p1
  sta OAM+2,x
  lda sx
  sta OAM+3,x
  lda sy
  sta OAM+4,x
  lda p0
  clc
  adc #1
  sta OAM+5,x
  lda p1
  sta OAM+6,x
  lda sx
  clc
  adc #8
  sta OAM+7,x
  lda sy
  clc
  adc #8
  sta OAM+8,x
  lda p0
  clc
  adc #2
  sta OAM+9,x
  lda p1
  sta OAM+10,x
  lda sx
  sta OAM+11,x
  lda sy
  clc
  adc #8
  sta OAM+12,x
  lda p0
  clc
  adc #3
  sta OAM+13,x
  lda p1
  sta OAM+14,x
  lda sx
  clc
  adc #8
  sta OAM+15,x
  txa
  clc
  adc #16
  sta oami
  rts

hero_frame:
  lda hdir
  cmp #1
  beq @up
  cmp #2
  beq @side
  cmp #3
  beq @side
  jsr walkphase
  bne :+
  lda #<spr_AX_D0
  ldx #>spr_AX_D0
  jmp @set
:
  lda #<spr_AX_D1
  ldx #>spr_AX_D1
  jmp @set
@up:
  jsr walkphase
  bne :+
  lda #<spr_AX_U0
  ldx #>spr_AX_U0
  jmp @set
:
  lda #<spr_AX_U1
  ldx #>spr_AX_U1
  jmp @set
@side:
  jsr walkphase
  bne :+
  lda #<spr_AX_L0
  ldx #>spr_AX_L0
  jmp @set
:
  lda #<spr_AX_L1
  ldx #>spr_AX_L1
@set:
  sta p0
  stx p0+1
  rts

walkphase:
  lda moving
  beq @f0
  lda frame_cnt
  and #$08
  rts
@f0:
  lda #0
  rts

; draw 16x16 metasprite: p0->4 tiles, sx/sy pos, p1=attr, honors hflip bit6
draw_meta16:
  ldx oami
  lda sy
  sta OAM,x
  ldy #0
  lda p1
  and #$40
  beq :+
  ldy #1
:
  lda (p0),y
  sta OAM+1,x
  lda p1
  sta OAM+2,x
  lda sx
  sta OAM+3,x
  lda sy
  sta OAM+4,x
  ldy #1
  lda p1
  and #$40
  beq :+
  ldy #0
:
  lda (p0),y
  sta OAM+5,x
  lda p1
  sta OAM+6,x
  lda sx
  clc
  adc #8
  sta OAM+7,x
  lda sy
  clc
  adc #8
  sta OAM+8,x
  ldy #2
  lda p1
  and #$40
  beq :+
  ldy #3
:
  lda (p0),y
  sta OAM+9,x
  lda p1
  sta OAM+10,x
  lda sx
  sta OAM+11,x
  lda sy
  clc
  adc #8
  sta OAM+12,x
  ldy #3
  lda p1
  and #$40
  beq :+
  ldy #2
:
  lda (p0),y
  sta OAM+13,x
  lda p1
  sta OAM+14,x
  lda sx
  clc
  adc #8
  sta OAM+15,x
  txa
  clc
  adc #16
  sta oami
  rts

.segment "ZEROPAGE"
area_map_ptr: .res 2
area_w:       .res 1
.exportzp area_map_ptr, area_w

.segment "RODATA"
dx_tbl: .byte 0, 0, 1, $FF
dy_tbl: .byte 1, $FF, 0, 0

; four field palette sets (32 bytes each): metal, hub-safe, bloom, hazard
field_pal:
  ; 0 metal ship
  .byte $0F,$00,$10,$20, $0F,$0C,$1C,$2C, $0F,$03,$13,$23, $0F,$06,$17,$28
  .byte $0F,$0F,$10,$2C, $0F,$16,$27,$37, $0F,$13,$23,$29, $0F,$06,$28,$30
  ; 1 hub (warmer, greens)
  .byte $0F,$00,$10,$20, $0F,$0C,$1C,$2C, $0F,$1A,$2A,$3A, $0F,$06,$28,$38
  .byte $0F,$0F,$10,$2C, $0F,$16,$27,$37, $0F,$1A,$2A,$3A, $0F,$06,$28,$30
  ; 2 bloom (purples/greens)
  .byte $0F,$00,$10,$20, $0F,$0C,$1C,$2C, $0F,$03,$13,$23, $0F,$09,$19,$29
  .byte $0F,$0F,$10,$2C, $0F,$16,$27,$37, $0F,$13,$23,$29, $0F,$06,$28,$30
  ; 3 reactor (amber/red hazard)
  .byte $0F,$00,$10,$20, $0F,$0C,$1C,$2C, $0F,$06,$16,$26, $0F,$16,$28,$38
  .byte $0F,$0F,$10,$2C, $0F,$16,$27,$37, $0F,$13,$23,$29, $0F,$06,$28,$30
