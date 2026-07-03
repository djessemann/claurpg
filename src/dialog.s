; ============================================================================
; dialog.s — text windows, typewriter printing, generic menus
; ============================================================================
; The message window is DQ-style: full width, tile rows 20-27, black interior,
; white border, three text lines at rows 21/23/25, text columns 2-29.

.segment "ZEROPAGE"
wx:     .res 1                  ; generic window args
wy:     .res 1
ww:     .res 1
wh:     .res 1
mn_cx:  .res 1                  ; menu cursor column
mn_cy:  .res 1                  ; menu first item row
mn_st:  .res 1                  ; menu row step
dopen_f:.res 1                  ; message window currently open?
num_lo: .res 1                  ; number for dput_num
num_hi: .res 1
dn_go:  .res 1
dn_i:   .res 1

.segment "CODE"

DLG_ROW = 20                    ; window top tile row

; ---------------------------------------------------------- generic window
; draw window at (wx,wy) size ww x wh (buffered). caller aligns to attr grid.
win_draw:
  ; top border
  lda #BORD_TL
  sta rowbuf
  ldx #1
  lda #BORD_T
@t:
  sta rowbuf,x
  inx
  cpx ww
  bne @t
  lda #BORD_TR
  sta rowbuf-1,x
  ldy wy
  lda wx
  jsr tile_addr
  lda ww
  jsr queue_row
  jsr wait_frame
  ; middle rows
  lda wy
  clc
  adc #1
  sta t3                        ; current row
  lda wy
  clc
  adc wh
  sec
  sbc #1
  sta t4                        ; bottom row
@mid:
  lda #BORD_L
  sta rowbuf
  ldx #1
  lda #0
@m:
  sta rowbuf,x
  inx
  cpx ww
  bne @m
  lda #BORD_R
  sta rowbuf-1,x
  ldy t3
  lda wx
  jsr tile_addr
  lda ww
  jsr queue_row
  jsr wait_frame
  inc t3
  lda t3
  cmp t4
  bne @mid
  ; bottom border
  lda #BORD_BL
  sta rowbuf
  ldx #1
  lda #BORD_B
@b:
  sta rowbuf,x
  inx
  cpx ww
  bne @b
  lda #BORD_BR
  sta rowbuf-1,x
  ldy t4
  lda wx
  jsr tile_addr
  lda ww
  jsr queue_row
  ; attributes: palette 3 for all covered cells
  lda wx
  lsr
  lsr
  sta t3                        ; first attr col
  lda wx
  clc
  adc ww
  sec
  sbc #1
  lsr
  lsr
  sec
  sbc t3
  clc
  adc #1
  sta t4                        ; attr col count
  lda wy
  lsr
  lsr
  sta t5                        ; attr row
  lda wy
  clc
  adc wh
  sec
  sbc #1
  lsr
  lsr
  sta cnt                       ; last attr row
@arow:
  ldx #0
  lda #$FF
@af:
  sta rowbuf,x
  inx
  cpx t4
  bne @af
  lda #$23
  sta t0
  lda t5
  asl
  asl
  asl
  clc
  adc #$C0
  clc
  adc t3
  sta t1
  lda t4
  jsr queue_row
  jsr wait_frame
  inc t5
  lda t5
  cmp cnt
  bcc @arow
  beq @arow
  rts

; write string p0 at col X row Y (single buffered row, no controls)
wput:
  txa
  jsr tile_addr
  ldy #0
@l:
  lda (p0),y
  cmp #TXT_END
  beq @done
  sta rowbuf,y
  iny
  bne @l
@done:
  tya
  jmp queue_row

; put single tile A at col X row Y
wtile:
  pha
  txa
  jsr tile_addr
  pla
  sta rowbuf
  lda #1
  jmp queue_row

; ------------------------------------------------------------ message window
dopen:
  lda dopen_f
  bne @already
  lda #0
  sta wx
  lda #DLG_ROW
  sta wy
  lda #32
  sta ww
  lda #8
  sta wh
  jsr win_draw
  lda #1
  sta dopen_f
@already:
  lda #2
  sta dcol
  lda #0
  sta drow
  rts

dclose:
  lda dopen_f
  beq @done
  lda #0
  sta dopen_f
  lda #10
  ldx #4
  jmp restore_rows
@done:
  rts

; print char A at cursor (typewriter pacing, A button fast-forwards)
dput_ch:
  pha
  lda drow
  asl
  clc
  adc #DLG_ROW+1
  tay
  pla
  pha
  txa
  pha
  lda dcol
  jsr tile_addr
  pla
  tax
  pla
  sta rowbuf
  lda #1
  jsr queue_row
  jsr read_pad
  lda pad
  and #BTN_A
  bne @fast
  jsr wait_frame
@fast:
  inc dcol
  lda dcol
  cmp #30
  bcc @ok
  jsr dnewline
@ok:
  rts

dnewline:
  lda #2
  sta dcol
  inc drow
  lda drow
  cmp #3
  bcc @ok
  jsr dpage
@ok:
  rts

; wait for A, then wipe the text lines
dpage:
  ; page-more marker
  lda #CH_CURSOR
  ldx #29
  ldy #DLG_ROW+6
  jsr wtile
  jsr dwait_a
  lda #0
  ldx #29
  ldy #DLG_ROW+6
  jsr wtile
dclear:
  lda #0
  sta t3
@l:
  ldx #0
  lda #0
@f:
  sta rowbuf,x
  inx
  cpx #28
  bne @f
  lda t3
  asl
  clc
  adc #DLG_ROW+1
  tay
  lda #2
  jsr tile_addr
  lda #28
  jsr queue_row
  jsr wait_frame
  inc t3
  lda t3
  cmp #3
  bne @l
  lda #2
  sta dcol
  lda #0
  sta drow
  rts

; wait for a fresh A press
dwait_a:
  jsr read_pad
  jsr wait_frame
  jsr read_pad
@l:
  lda pad_new
  and #BTN_A
  bne @done
  jsr wait_frame
  jsr read_pad
  jmp @l
@done:
  lda #SFX_BLIP
  jsr sfx_play
  rts

; print string at p0 with control codes
dput_str:
@l:
  ldy #0
  lda (p0),y
  inc p0
  bne :+
  inc p0+1
:
  cmp #TXT_END
  beq @done
  cmp #TXT_PAGE
  beq @page
  cmp #TXT_NL
  beq @nl
  jsr dput_ch
  jmp @l
@page:
  jsr dpage
  jmp @l
@nl:
  jsr dnewline
  jmp @l
@done:
  rts

; print 16-bit number num_lo/num_hi at cursor (no leading zeros)
dput_num:
  lda num_lo
  sta t0
  lda num_hi
  sta t1
  jsr bin_to_dec
  lda #0
  sta dn_go
  sta dn_i
@l:
  ldx dn_i
  lda decbuf,x
  bne @print
  lda dn_go
  bne @print
  cpx #4
  beq @print
  bne @skip
@print:
  inc dn_go
  ldx dn_i
  lda decbuf,x
  clc
  adc #CH_0
  jsr dput_ch
@skip:
  inc dn_i
  lda dn_i
  cmp #5
  bne @l
  rts

; say(p0): open window, print, wait A, close
say:
  jsr dopen
  jsr dput_str
  jsr dwait_a
  jmp dclose

; --------------------------------------------------------------- menu driver
; cursor at column mn_cx, items at rows mn_cy + i*mn_st, curmax items.
; returns A = index, or $FF if cancelled. preserves window.
menu_run:
  lda #0
  sta cur
@redraw:
  jsr menu_cursor_on
@loop:
  jsr wait_frame
  jsr read_pad
  lda pad_new
  and #BTN_UP
  beq @ckdown
  lda cur
  beq @loop
  jsr menu_cursor_off
  dec cur
  lda #SFX_BLIP
  jsr sfx_play
  jmp @redraw
@ckdown:
  lda pad_new
  and #BTN_DOWN
  beq @cka
  lda cur
  clc
  adc #1
  cmp curmax
  bcs @loop
  jsr menu_cursor_off
  inc cur
  lda #SFX_BLIP
  jsr sfx_play
  jmp @redraw
@cka:
  lda pad_new
  and #BTN_A
  beq @ckb
  lda #SFX_BLIP
  jsr sfx_play
  lda cur
  rts
@ckb:
  lda pad_new
  and #BTN_B
  beq @loop
  lda #$FF
  rts

menu_cursor_on:
  lda #CH_CURSOR
  bne menu_cursor_put
menu_cursor_off:
  lda #0
menu_cursor_put:
  pha
  lda cur
  ldx mn_st
  cpx #2
  bne @s1
  asl
@s1:
  clc
  adc mn_cy
  tay
  ldx mn_cx
  pla
  jmp wtile
