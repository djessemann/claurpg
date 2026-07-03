; ============================================================================
; game.s — main_init, field loop, hero movement, camera, metasprite draw
; (Milestone 1: single 32x15 area, smooth horizontal scroll, animated hero)
; ============================================================================
.include "defs.inc"
.include "gen/tiles.inc"

.importzp p0, p1, p2, pad, pad_new, frame_cnt
.importzp scrollX, scrollXhi, scrollY
.import wait_nmi, ppu_off, ppu_on, read_pad, set_chr_bg, set_chr_spr
.import load_palette, draw_screen, clear_nt, OAM, draw_col, rowbase
.import win_box, win_print, restore_rows_ui, print_num
.importzp colc, uarg, num_lo, num_hi
.import mt_attr_tbl
.import spr_AX_D0, spr_AX_D1, spr_AX_U0, spr_AX_U1, spr_AX_L0, spr_AX_L1
.importzp pad_new
.export main_init

MAPW = 48
MAPH = 15
MAXCAMX = MAPW*16 - 256          ; = 512

.segment "ZEROPAGE"
htx:   .res 1                    ; hero tile x (0..MAPW-1)
hty:   .res 1                    ; hero tile y (0..MAPH-1)
hpxL:  .res 1                    ; hero pixel x low
hpxH:  .res 1                    ; hero pixel x high (bit0)
hpy:   .res 1                    ; hero pixel y (0..)
hdir:  .res 1                    ; 0 down 1 up 2 right 3 left
moving:.res 1
mstep: .res 1
ntx:   .res 1                    ; step target tile
nty:   .res 1
camL:  .res 1                    ; camera worldX low
camH:  .res 1                    ; camera worldX high
sx:    .res 1                    ; scratch
sy:    .res 1
oami:  .res 1
col_first: .res 1                ; leftmost map col valid in torus
col_last:  .res 1                ; rightmost map col valid in torus
wcol:      .res 1
tmp_r:     .res 1
area_map_ptr: .res 2             ; pointer to current area map
area_w:       .res 1             ; current area width in metatiles
.exportzp area_map_ptr, area_w

.segment "BSS"
area_map: .res MAPW*MAPH

.segment "CODE"

main_init:
  jsr ppu_off
  jsr build_map
  lda #<area_map
  sta area_map_ptr
  lda #>area_map
  sta area_map_ptr+1
  lda #MAPW
  sta area_w
  lda #<pal_ship
  sta p0
  lda #>pal_ship
  sta p0+1
  jsr load_palette
  ; draw both nametables from the map
  lda #<area_map
  sta p0
  lda #>area_map
  sta p0+1
  lda #MAPW
  sta p1
  ldx #0
  lda #$20
  jsr draw_screen
  lda #<area_map
  sta p0
  lda #>area_map
  sta p0+1
  lda #MAPW
  sta p1
  ldx #16
  lda #$24
  jsr draw_screen
  lda #0
  sta col_first
  lda #31
  sta col_last
  ; hero start near left
  lda #3
  sta htx
  lda #7
  sta hty
  lda #0
  sta moving
  sta hdir
  jsr sync_hero_px
  jsr center_cam
  jsr build_oam
  jsr ppu_on
field_loop:
  jsr read_pad
  lda moving
  bne @step
  lda pad_new
  and #BTN_A
  beq :+
  jsr test_dialog
  jmp @after
:
  jsr try_move
  jmp @after
@step:
  jsr do_step
@after:
  jsr center_cam
  jsr stream_cols
  jsr build_oam
  jsr wait_nmi
  jmp field_loop

; stream one metatile column per side as the camera crosses boundaries
stream_cols:
  lda #<area_map
  sta p0
  lda #>area_map
  sta p0+1
  lda #MAPW
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
  ; right: ensure col_last >= wcol+16
  lda wcol
  clc
  adc #16
  sta tmp_r
  lda col_last
  cmp tmp_r
  bcs @left
  lda col_last
  cmp #MAPW-1
  bcs @left
  inc col_last
  lda col_last
  sta colc
  jsr draw_col
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
  lda col_first
  clc
  adc #31
  cmp col_last
  bcs @done
  sta col_last
@done:
  rts

; --- temporary UI test: message box + text, then restore ---
test_dialog:
  lda #1
  sta uarg+0
  lda #20
  sta uarg+1
  lda #30
  sta uarg+2
  lda #8
  sta uarg+3
  jsr win_box
  lda #<txt_test1
  sta p0
  lda #>txt_test1
  sta p0+1
  ldx #3
  ldy #22
  jsr win_print
  lda #<txt_test2
  sta p0
  lda #>txt_test2
  sta p0+1
  ldx #3
  ldy #24
  jsr win_print
  jsr wait_a
  lda #20
  ldx #8
  jsr restore_rows_ui
  rts

wait_a:
  jsr wait_nmi
  jsr read_pad
  lda pad_new
  and #BTN_A
  beq wait_a
  rts

; hero pixel pos from tile pos
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
  sta hpxH                       ; high bit of (htx*16)
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
  ; bounds
  lda ntx
  cmp #MAPW
  bcs @blocked                   ; >= MAPW (also catches $FF)
  lda nty
  cmp #MAPH
  bcs @blocked
  ; solid?
  jsr target_solid
  bne @blocked
  lda #1
  sta moving
  lda #16
  sta mstep
@blocked:
  rts

; Z=0 if target tile (ntx,nty) is solid
target_solid:
  lda #<area_map
  sta p0
  lda #>area_map
  sta p0+1
  lda #MAPW
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

do_step:
  ldx hdir
  ; advance pixel pos by 2 in dir
  lda dx_tbl,x
  bpl :+
  ; dx = -1 : hpx -= 2
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
  lda hpxL                       ; dx=+1
  clc
  adc #2
  sta hpxL
  bcc @dy
  inc hpxH
@dy:
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
@done:
  rts

; --------------------------------------------------------------- camera
; worldX = clamp(hpx - 120, 0, MAXCAMX)
center_cam:
  lda hpxL
  sec
  sbc #120
  sta camL
  lda hpxH
  sbc #0
  sta camH
  bcs @nonneg                    ; borrow -> negative -> clamp 0
  lda #0
  sta camL
  sta camH
  jmp @setscroll
@nonneg:
  lda camH
  cmp #>MAXCAMX
  bcc @setscroll
  bne @cap
  lda camL
  cmp #<MAXCAMX
  bcc @setscroll
@cap:
  lda #<MAXCAMX
  sta camL
  lda #>MAXCAMX
  sta camH
@setscroll:
  lda camL
  sta scrollX
  lda camH
  and #$01
  sta scrollXhi
  lda #0
  sta scrollY
  rts

; --------------------------------------------------------------- sprites
build_oam:
  lda #0
  sta oami
  ; hero screen pos = hpx - camX  (X), hpy (Y)
  lda hpxL
  sec
  sbc camL
  sta sx                         ; screen x
  lda hpy
  sta sy
  ; pick frame tiles into p0
  jsr hero_frame
  ; attr (palette 0, hflip if right)
  lda hdir
  cmp #2
  bne :+
  lda #$40                       ; hflip for right-facing
  jmp @draw
:
  lda #$00
@draw:
  sta p1                         ; attr in p1 lowbyte
  jsr draw_meta16
  ; clear the rest of OAM
  ldx oami
  lda #$F0
@clr:
  sta OAM,x
  inx
  inx
  inx
  inx
  bne @clr
  rts

; sets p0 -> 4 tile ids for current dir/frame
hero_frame:
  lda hdir
  cmp #1
  beq @up
  cmp #2
  beq @side
  cmp #3
  beq @side
  ; down
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

; returns Z=1 for frame0, Z=0 for frame1 (only animates while moving)
walkphase:
  lda moving
  beq @f0
  lda frame_cnt
  and #$08
  rts
@f0:
  lda #0
  rts

; draw 16x16 metasprite: p0->4 tiles(TL,TR,BL,BR), sx/sy screen pos, p1=attr
; honors hflip (attr bit6): swaps L/R tiles
draw_meta16:
  ldx oami
  ; TL
  lda sy
  sta OAM,x
  ldy #0
  lda p1
  and #$40
  beq @noflipTL
  ldy #1                         ; use TR tile at left when flipped
@noflipTL:
  lda (p0),y
  sta OAM+1,x
  lda p1
  sta OAM+2,x
  lda sx
  sta OAM+3,x
  ; TR
  lda sy
  sta OAM+4,x
  ldy #1
  lda p1
  and #$40
  beq @noflipTR
  ldy #0
@noflipTR:
  lda (p0),y
  sta OAM+5,x
  lda p1
  sta OAM+6,x
  lda sx
  clc
  adc #8
  sta OAM+7,x
  ; BL
  lda sy
  clc
  adc #8
  sta OAM+8,x
  ldy #2
  lda p1
  and #$40
  beq @noflipBL
  ldy #3
@noflipBL:
  lda (p0),y
  sta OAM+9,x
  lda p1
  sta OAM+10,x
  lda sx
  sta OAM+11,x
  ; BR
  lda sy
  clc
  adc #8
  sta OAM+12,x
  ldy #3
  lda p1
  and #$40
  beq @noflipBR
  ldy #2
@noflipBR:
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

; --------------------------------------------------------------- test map
build_map:
  lda #0
  sta sy                         ; row
@row:
  lda #0
  sta sx                         ; col
@col:
  ldx #MT_FLOOR
  lda sy
  beq @wall
  cmp #MAPH-1
  beq @wall
  lda sx
  beq @wall
  cmp #MAPW-1
  beq @wall
  bne @put
@wall:
  ldx #MT_WALL
@put:
  txa
  jsr setmt
  inc sx
  lda sx
  cmp #MAPW
  bne @col
  inc sy
  lda sy
  cmp #MAPH
  bne @row
  ; props
  lda #6
  sta sx
  lda #3
  sta sy
  lda #MT_CONSOLE
  jsr setmt
  inc sx
  lda #MT_CONSOLE
  jsr setmt
  lda #20
  sta sx
  lda #7
  sta sy
  lda #MT_CRATE
  jsr setmt
  lda #24
  sta sx
  lda #9
  sta sy
  lda #MT_VIEWPORT
  jsr setmt
  lda #12
  sta sx
  lda #11
  sta sy
  lda #MT_BLOOM
  jsr setmt
  ; more props spread across the long deck
  lda #34
  sta sx
  lda #4
  sta sy
  lda #MT_CRATE
  jsr setmt
  lda #35
  sta sx
  lda #MT_CRATE
  jsr setmt
  lda #40
  sta sx
  lda #10
  sta sy
  lda #MT_BLOOM
  jsr setmt
  lda #41
  sta sx
  lda #MT_BLOOM
  jsr setmt
  lda #44
  sta sx
  lda #3
  sta sy
  lda #MT_VIEWPORT
  jsr setmt
  lda #46
  sta sx
  lda #7
  sta sy
  lda #MT_DOOR
  jsr setmt
  rts

; store tile A at (sx=col, sy=row) in area_map
setmt:
  pha
  lda #<area_map
  sta p0
  lda #>area_map
  sta p0+1
  lda #MAPW
  sta p1
  lda sy
  jsr rowbase
  lda p2
  clc
  adc sx
  sta p2
  bcc :+
  inc p2+1
:
  pla
  ldy #0
  sta (p2),y
  rts

.segment "RODATA"
txt_test1: .byte "AXIOM ONLINE. THE EREBUS IS", TXT_END
txt_test2: .byte "DARK. LIFE SUPPORT: FAILING.", TXT_END
dx_tbl: .byte 0, 0, 1, $FF
dy_tbl: .byte 1, $FF, 0, 0

pal_ship:
  ; BG: metal, tech/cyan, bloom purple, amber
  .byte $0F,$00,$10,$20
  .byte $0F,$0C,$1C,$2C
  .byte $0F,$03,$13,$23
  .byte $0F,$06,$17,$28
  ; SPR: axiom(gray+cyan), crew skin, bloom, amber
  .byte $0F,$0F,$10,$2C
  .byte $0F,$16,$27,$37
  .byte $0F,$13,$23,$29
  .byte $0F,$06,$28,$30
