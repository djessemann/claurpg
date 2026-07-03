; ============================================================================
; ppu.s — VRAM queue helpers, palette load, metatile screen rendering
; ============================================================================
.include "defs.inc"

.importzp p0, p1, p2
.import wait_nmi, vq, vq_len
.export load_palette, draw_screen, clear_nt, vq_send, linebuf
.export vaddr_hi, vaddr_lo, addr_row, rowbase
.export _mt_tl, _mt_tr, _mt_bl, _mt_br, _mt_attr

.import mt_tl_tbl, mt_tr_tbl, mt_bl_tbl, mt_br_tbl, mt_attr_tbl
_mt_tl = mt_tl_tbl
_mt_tr = mt_tr_tbl
_mt_bl = mt_bl_tbl
_mt_br = mt_br_tbl
_mt_attr = mt_attr_tbl

.segment "ZEROPAGE"
nthi:     .res 1
mcol0:    .res 1
mrow:     .res 1
cnt_z:    .res 1
vaddr_hi: .res 1
vaddr_lo: .res 1
vqlen_z:  .res 1
vqctrl_z: .res 1
ax_z:     .res 1
ay_z:     .res 1

.segment "BSS"
linebuf:  .res 40

.segment "CODE"

; --------------------------------------------------------- palette upload
load_palette:
  bit PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #0
  sta PPUADDR
  ldy #0
@l:
  lda (p0),y
  sta PPUDATA
  iny
  cpy #32
  bne @l
  rts

; ----------------------------------------------------------- clear a NT
; A = nametable high byte ($20 or $24)
clear_nt:
  sta nthi
  bit PPUSTATUS
  lda nthi
  sta PPUADDR
  lda #0
  sta PPUADDR
  ldx #0
  ldy #4
  lda #0
@l:
  sta PPUDATA
  inx
  bne @l
  dey
  bne @l
  rts

; -------------------------------------------- draw one screen (16 mt cols)
;   A  = nametable high byte ($20/$24)
;   X  = starting metatile column in map
;   p0 = map pointer, p1 = area width in metatiles
; Rendering MUST be off.
draw_screen:
  sta nthi
  stx mcol0
  lda #0
  sta mrow
@rows:
  bit PPUSTATUS
  lda mrow
  asl
  jsr addr_row
  lda mrow
  jsr rowbase
  ldy mcol0
  ldx #16
@t:
  lda (p2),y
  stx cnt_z
  tax
  lda mt_tl_tbl,x
  sta PPUDATA
  lda mt_tr_tbl,x
  sta PPUDATA
  ldx cnt_z
  iny
  dex
  bne @t
  bit PPUSTATUS
  lda mrow
  asl
  clc
  adc #1
  jsr addr_row
  lda mrow
  jsr rowbase
  ldy mcol0
  ldx #16
@b:
  lda (p2),y
  stx cnt_z
  tax
  lda mt_bl_tbl,x
  sta PPUDATA
  lda mt_br_tbl,x
  sta PPUDATA
  ldx cnt_z
  iny
  dex
  bne @b
  inc mrow
  lda mrow
  cmp #15
  bne @rows
  jsr draw_attr
  rts

; A = tile row (0-29) -> PPUADDR nthi:row, col 0
addr_row:
  pha
  lsr
  lsr
  lsr
  ora nthi
  sta PPUADDR
  pla
  and #$07
  asl
  asl
  asl
  asl
  asl
  sta PPUADDR
  rts

; A = metatile row -> p2 = p0 + A*p1  (uses only Y + rbtmp)
rowbase:
  tay
  lda p0
  sta p2
  lda p0+1
  sta p2+1
  cpy #0
  beq @done
@add:
  clc
  lda p2
  adc p1
  sta p2
  bcc :+
  inc p2+1
:
  dey
  bne @add
@done:
  rts

; attributes for current screen (nthi), 8x8 cells from 16x15 metatiles
draw_attr:
  bit PPUSTATUS
  lda nthi
  ora #$03
  sta PPUADDR
  lda #$C0
  sta PPUADDR
  lda #0
  sta ay_z
@ry:
  lda #0
  sta ax_z
@rx:
  jsr attr_cell
  sta PPUDATA
  inc ax_z
  lda ax_z
  cmp #8
  bne @rx
  inc ay_z
  lda ay_z
  cmp #8
  bne @ry
  rts

; attribute byte for cell (ax_z, ay_z) from the 2x2 metatile block
attr_cell:
  ; TL metatile = map[ (ay*2) ][ mcol0 + ax*2 ]
  lda ay_z
  asl                            ; metatile row = ay*2
  cmp #15
  bcc :+
  lda #14                        ; clamp bottom partial row
:
  jsr rowbase                    ; p2 = row base
  lda ax_z
  asl
  clc
  adc mcol0
  tay                            ; col
  ; TL
  lda (p2),y
  tax
  lda mt_attr_tbl,x
  and #$03
  sta cnt_z
  ; TR
  iny
  lda (p2),y
  tax
  lda mt_attr_tbl,x
  and #$03
  asl
  asl
  ora cnt_z
  sta cnt_z
  ; next metatile row for BL/BR
  lda ay_z
  asl
  clc
  adc #1
  cmp #15
  bcc :+
  lda #14
:
  jsr rowbase
  lda ax_z
  asl
  clc
  adc mcol0
  tay
  lda (p2),y
  tax
  lda mt_attr_tbl,x
  and #$03
  asl
  asl
  asl
  asl
  ora cnt_z
  sta cnt_z
  iny
  lda (p2),y
  tax
  lda mt_attr_tbl,x
  and #$03
  asl
  asl
  asl
  asl
  asl
  asl
  ora cnt_z
  rts

; ------------------------------------------------------ queued VRAM send
; A = len, X = ctrl(0:+1 / 1:+32); address in vaddr_hi/vaddr_lo; data in linebuf
vq_send:
  sta vqlen_z
  stx vqctrl_z
@space:
  lda vq_len
  clc
  adc vqlen_z
  adc #6
  cmp #200
  bcc @ok
  jsr wait_nmi
@ok:
  ldy vq_len
  lda vqlen_z
  sta vq,y
  iny
  lda vqctrl_z
  sta vq,y
  iny
  lda vaddr_hi
  sta vq,y
  iny
  lda vaddr_lo
  sta vq,y
  iny
  ldx #0
@cp:
  lda linebuf,x
  sta vq,y
  iny
  inx
  cpx vqlen_z
  bne @cp
  sty vq_len
  lda #0
  sta vq,y
  rts
