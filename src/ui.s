; ============================================================================
; ui.s — windows/text over the scrolling field (queued; restore from map)
; ============================================================================
.include "defs.inc"
.include "gen/tiles.inc"

.importzp p0, p1, p2, scrollX, scrollXhi
.importzp area_map_ptr, area_w, vaddr_hi, vaddr_lo
.import wait_nmi, vq_send, linebuf, rowbase
.import mt_tl_tbl, mt_tr_tbl, mt_bl_tbl, mt_br_tbl
.export scr_addr, queue_hstrip, stage_maprow, restore_rows_ui
.export win_box, win_print, win_clearline, print_num, num_lo, num_hi, win_putc
.exportzp uarg

.segment "ZEROPAGE"
uarg:    .res 6                 ; generic window args: col,row,w,h,+
wtc:     .res 1                 ; world tile col of current write start
wntbit:  .res 1                 ; which NT the start is in (0/1)
splitn:  .res 1                 ; tiles until NT boundary
hlen:    .res 1
srow:    .res 1
scount:  .res 1
qh_len:  .res 1
qh_col:  .res 1
qh_row:  .res 1
qh_split:.res 1
qh_cnt:  .res 1
mpar:    .res 1                 ; metatile parity of first tile
mmc:     .res 1                 ; metatile column cursor
num_lo:  .res 1
num_hi:  .res 1
ndig:    .res 1
nstart:  .res 1
drem:    .res 1
rr_row:  .res 1
rr_cnt:  .res 1

.segment "CODE"

; screen tile (col in uarg+4 semantics) -> vaddr for (screenCol=A, row=Y)
; returns vaddr_hi/lo set; splitn = tiles left before NT wrap from this col
; worldTileCol = (scrollXhi*256 + scrollX)>>3 + A
scr_addr:
  sta uarg+5                    ; screen col
  ; worldTileCol = (scrollX>>3) + (scrollXhi<<5) + col
  lda scrollX
  lsr
  lsr
  lsr
  sta wtc
  lda scrollXhi
  beq :+
  lda wtc
  clc
  adc #32
  sta wtc
:
  lda wtc
  clc
  adc uarg+5
  and #$3F                      ; wrap to torus (64 tiles = 2 NT)
  sta wtc
  ; NT bit = (wtc>>5)&1 ; x = wtc&31
  lda wtc
  and #$20
  beq @nt0
  lda #$24
  sta vaddr_hi
  lda #1
  sta wntbit
  jmp @x
@nt0:
  lda #$20
  sta vaddr_hi
  lda #0
  sta wntbit
@x:
  lda wtc
  and #$1F
  sta wtc                       ; x (0-31)
  ; addr lo = row*32 + x ; addr hi += row>>3
  tya
  and #$07
  asl
  asl
  asl
  asl
  asl
  ora wtc
  sta vaddr_lo
  tya
  lsr
  lsr
  lsr
  clc
  adc vaddr_hi
  sta vaddr_hi
  ; splitn = 32 - x
  lda #32
  sec
  sbc wtc
  sta splitn
  rts

; queue a horizontal run: linebuf[0..A-1] at screenCol=X, row=Y (splits at NT)
queue_hstrip:
  sta qh_len
  stx qh_col
  sty qh_row
  lda qh_col
  ldy qh_row
  jsr scr_addr                  ; vaddr for start; splitn tiles until wrap
  lda splitn
  sta qh_split
  lda qh_len
  cmp qh_split
  bcc @one                      ; fits before wrap
  beq @one
  ; two segments: first 'qh_split', then remainder
  lda qh_split
  ldx #0
  jsr vq_send                   ; sends linebuf[0..qh_split-1] at vaddr
  lda qh_len
  sec
  sbc qh_split
  sta qh_cnt
  ldx #0
  ldy qh_split
@sh:
  lda linebuf,y
  sta linebuf2,x
  iny
  inx
  cpx qh_cnt
  bne @sh
  ldx #0
@sh2:
  lda linebuf2,x
  sta linebuf,x
  inx
  cpx qh_cnt
  bne @sh2
  lda qh_col
  clc
  adc qh_split
  ldy qh_row
  jsr scr_addr
  lda qh_cnt
  ldx #0
  jmp vq_send
@one:
  lda qh_len
  ldx #0
  jmp vq_send

.segment "BSS"
linebuf2: .res 34

.segment "CODE"

; stage 32 map tiles for tile-row A into linebuf (at current scroll)
stage_maprow:
  sta srow
  ; metatile row = srow>>1 ; top half if (srow&1)==0
  lda srow
  lsr
  sta scount                    ; metatile row
  ; p2 = area_map + metatileRow * area_w
  lda area_map_ptr
  sta p0
  lda area_map_ptr+1
  sta p0+1
  lda area_w
  sta p1
  lda scount
  jsr rowbase                   ; p2 = row base
  ; worldMetatileCol0 = worldX>>4 ; par = (worldX>>3)&1
  lda scrollX
  lsr
  lsr
  lsr
  lsr
  sta mmc
  lda scrollXhi
  beq :+
  lda mmc
  clc
  adc #16
  sta mmc
:
  lda scrollX
  lsr
  lsr
  lsr
  and #$01
  sta mpar
  ; iterate 32 tiles
  ldx #0                        ; linebuf idx
@l:
  ldy mmc
  lda (p2),y                    ; metatile id
  pha
  lda mpar
  bne @right
  ; left tile: top->tl bottom->bl
  pla
  tay
  lda srow
  and #$01
  bne @bl
  lda mt_tl_tbl,y
  jmp @put
@bl:
  lda mt_bl_tbl,y
  jmp @put
@right:
  pla
  tay
  lda srow
  and #$01
  bne @br
  lda mt_tr_tbl,y
  jmp @put
@br:
  lda mt_br_tbl,y
@put:
  sta linebuf,x
  inx
  ; advance parity/metatile
  lda mpar
  eor #$01
  sta mpar
  bne @next                     ; became 1 (was left) -> stay same metatile
  inc mmc                       ; became 0 (was right) -> next metatile
@next:
  cpx #32
  bne @l
  rts

; redraw tile rows [A .. A+X-1] from the map (queued, one row per frame)
restore_rows_ui:
  sta rr_row
  stx rr_cnt
@l:
  lda rr_row
  jsr stage_maprow
  lda #32
  ldx #0
  ldy rr_row
  jsr queue_hstrip
  jsr wait_nmi
  inc rr_row
  dec rr_cnt
  bne @l
  rts

; ---------------------------------------------------------- window drawing
; draw a box: uarg+0=col uarg+1=row uarg+2=w uarg+3=h (queued, restore-safe)
win_box:
  ; top border row
  ldx #0
  lda #BORD_TL
  sta linebuf
  ldx #1
  lda #BORD_T
@t:
  sta linebuf,x
  inx
  cpx uarg+2
  bne @t
  lda #BORD_TR
  ldy uarg+2
  dey
  sta linebuf,y
  lda uarg+2
  ldx uarg+0
  ldy uarg+1
  jsr queue_hstrip
  jsr wait_nmi
  ; middle rows
  lda uarg+1
  clc
  adc #1
  sta srow
  lda uarg+1
  clc
  adc uarg+3
  sec
  sbc #1
  sta scount                    ; bottom row index
@mid:
  ldx #0
  lda #BORD_L
  sta linebuf
  ldx #1
  lda #0
@mf:
  sta linebuf,x
  inx
  cpx uarg+2
  bne @mf
  lda #BORD_R
  ldy uarg+2
  dey
  sta linebuf,y
  lda uarg+2
  ldx uarg+0
  ldy srow
  jsr queue_hstrip
  jsr wait_nmi
  inc srow
  lda srow
  cmp scount
  bne @mid
  ; bottom border
  ldx #0
  lda #BORD_BL
  sta linebuf
  ldx #1
  lda #BORD_B
@b:
  sta linebuf,x
  inx
  cpx uarg+2
  bne @b
  lda #BORD_BR
  ldy uarg+2
  dey
  sta linebuf,y
  lda uarg+2
  ldx uarg+0
  ldy scount
  jsr queue_hstrip
  jmp wait_nmi

; print string p0 at screen tile col X, tile row Y (single line, no controls)
win_print:
  stx uarg+5
  sty srow
  ldy #0
@l:
  lda (p0),y
  cmp #TXT_END
  beq @done
  sta linebuf,y
  iny
  bne @l
@done:
  sty hlen
  lda hlen
  beq @skip
  lda hlen
  ldx uarg+5
  ldy srow
  jsr queue_hstrip
@skip:
  rts

; put single tile A at screen col X, row Y
win_putc:
  sta linebuf
  lda #1
  jmp queue_hstrip

; clear W tiles at col X row Y
win_clearline:
  sta hlen
  stx nstart                    ; save col
  sty ndig                      ; save row
  ldy #0
  lda #0
@l:
  sta linebuf,y
  iny
  cpy hlen
  bne @l
  lda hlen
  ldx nstart
  ldy ndig
  jmp queue_hstrip

; print num_lo/num_hi (16-bit) at screen col X row Y, W digits (leading spaces)
print_num:
  stx uarg+5
  sty srow
  lda num_lo
  sta p2
  lda num_hi
  sta p2+1
  ; produce digits in linebuf2 (reverse). div10 clobbers X, so index via ndig.
  lda #0
  sta ndig
@dl:
  jsr div10                     ; p2 /= 10, remainder in A
  clc
  adc #CH_0
  ldy ndig
  sta linebuf2,y
  inc ndig
  lda p2
  ora p2+1
  bne @dl
   ; ndig = number of digits; emit right-aligned (leading spaces)
  ldy #0
  lda #5
  sec
  sbc ndig                      ; leading spaces (assume width 5)
  sta nstart
@sp:
  lda nstart
  beq @dig
  lda #0
  sta linebuf,y
  iny
  dec nstart
  jmp @sp
@dig:
  ldx ndig
@do:
  dex
  lda linebuf2,x
  sta linebuf,y
  iny
  cpx #0
  bne @do
  lda #5
  ldx uarg+5
  ldy srow
  jmp queue_hstrip

; p2 = p2 / 10 ; remainder -> A
div10:
  lda #0
  sta drem
  ldx #16
@l:
  asl p2
  rol p2+1
  rol drem
  lda drem
  cmp #10
  bcc :+
  sbc #10
  sta drem
  inc p2
:
  dex
  bne @l
  lda drem
  rts
