; ============================================================================
; engine.s — system core: reset, NMI, vblank queue, input, RNG, PPU helpers
; ============================================================================

.segment "ZEROPAGE"
nmib:   .res 1                  ; NMI-private scratch
oam_i:  .res 1

.segment "CODE"

reset:
  sei
  cld
  ldx #$40
  stx JOY2                      ; APU frame counter: no IRQ
  ldx #$FF
  txs
  inx
  stx PPUCTRL
  stx PPUMASK
  stx $4010
  bit PPUSTATUS
: bit PPUSTATUS                 ; warm up: vblank 1
  bpl :-
  lda #0
  tax
@clr:
  sta $0000,x
  sta $0100,x
  sta $0300,x
  sta $0400,x
  sta $0500,x
  sta $0600,x
  sta $0700,x
  inx
  bne @clr
  lda #$F0
@oam:
  sta $0200,x
  inx
  bne @oam
: bit PPUSTATUS                 ; vblank 2
  bpl :-
  lda #$5A
  sta rng0
  lda #$C3
  sta rng1
  lda #$0F
  sta $4015                     ; pulse1/2, triangle, noise on
  lda #$08
  sta $4001                     ; pulse sweep off (negate keeps lows audible)
  sta $4005
  lda #$80
  sta PPUCTRL                   ; NMI on
  jmp main

; ---------------------------------------------------------------------- NMI
nmi_handler:
  pha
  txa
  pha
  tya
  pha
  lda nmi_ready
  beq @no_present
  lda ppu_on
  beq @ack                      ; forced blank: main is drawing directly
  lda #0
  sta OAMADDR
  lda #$02
  sta OAMDMA
  ldx #0
@qloop:
  lda ppubuf,x
  beq @qdone
  sta nmib
  inx
  lda ppubuf,x
  sta PPUADDR
  inx
  lda ppubuf,x
  sta PPUADDR
  inx
@qwrite:
  lda ppubuf,x
  sta PPUDATA
  inx
  dec nmib
  bne @qwrite
  beq @qloop
@qdone:
  lda #0
  ldx shake
  beq @noshake
  lda frame_cnt
  and #$02
  asl                           ; 0 or 4 px jitter
@noshake:
  sta PPUSCROLL
  lda #0
  sta PPUSCROLL
  lda #$88                      ; NMI on, sprites in $1000
  sta PPUCTRL
  lda #$1E
  sta PPUMASK
@ack:
  lda #0
  sta nmi_ready
@no_present:
  inc frame_cnt
  jsr sound_update
  pla
  tay
  pla
  tax
  pla
irq_handler:
  rti

; ----------------------------------------------------------------- frame sync
wait_frame:
  lda #1
  sta nmi_ready
: lda nmi_ready
  bne :-
  lda #0
  sta ppubuf
  sta buf_end
  lda shake
  beq rng_step
  dec shake
  ; fall through

; -------------------------------------------------------------------- random
rng_step:
  ldy #8
  lda rng0
@l:
  asl
  rol rng1
  bcc :+
  eor #$39
:
  dey
  bne @l
  sta rng0
  rts

; A = modulus in, A = random 0..mod-1 out
rand_mod:
  sta t5
  jsr rng_step
  lda rng0
@l:
  cmp t5
  bcc @done
  sbc t5
  jmp @l
@done:
  rts

; --------------------------------------------------------------------- input
read_pad:
  lda pad
  sta pad_prev
  lda #1
  sta JOY1
  sta pad
  lsr
  sta JOY1
@l:
  lda JOY1
  lsr
  rol pad
  bcc @l
  lda pad_prev
  eor #$FF
  and pad
  sta pad_new
  rts

; -------------------------------------------------------- rendering on / off
screen_off:
  lda #0
  sta ppu_on
  jsr wait_frame
  lda #0
  sta PPUMASK
  lda #$80
  sta PPUCTRL                   ; keep NMI, +1 increment
  rts

screen_on:
  lda #1
  sta ppu_on
  jmp wait_frame

; -------------------------------------------------------------- vblank queue
; queue rowbuf[0..A-1] for PPU address t0(hi)/t1(lo)
queue_row:
  sta t2
  lda buf_end
  clc
  adc t2
  adc #4
  cmp #124
  bcc @ok
  jsr wait_frame                ; queue full: flush a frame first
@ok:
  ldx buf_end
  lda t2
  sta ppubuf,x
  inx
  lda t0
  sta ppubuf,x
  inx
  lda t1
  sta ppubuf,x
  inx
  ldy #0
@cp:
  lda rowbuf,y
  sta ppubuf,x
  inx
  iny
  cpy t2
  bne @cp
  lda #0
  sta ppubuf,x
  stx buf_end
  rts

; t0/t1 = nametable address of tile at col A, row Y
tile_addr:
  sta t1
  tya
  lsr
  lsr
  lsr
  clc
  adc #$20
  sta t0
  tya
  asl
  asl
  asl
  asl
  asl
  ora t1
  sta t1
  rts

; ------------------------------------------------------------- map rendering
; draw full screen from maprm — rendering must be off
draw_map:
  bit PPUSTATUS
  lda #0
  sta t3                        ; metatile row
@rows:
  lda t3
  lsr
  lsr
  clc
  adc #$20
  sta PPUADDR
  lda t3
  asl
  asl
  asl
  asl
  asl
  asl
  sta PPUADDR
  lda t3
  asl
  asl
  asl
  asl
  sta t4                        ; index of row start
  tay
@top:
  ldx maprm,y
  lda _mt_tl,x
  sta PPUDATA
  lda _mt_tr,x
  sta PPUDATA
  iny
  tya
  and #$0F
  bne @top
  lda t3
  lsr
  lsr
  clc
  adc #$20
  sta PPUADDR
  lda t3
  asl
  asl
  asl
  asl
  asl
  asl
  ora #$20
  sta PPUADDR
  ldy t4
@bot:
  ldx maprm,y
  lda _mt_bl,x
  sta PPUDATA
  lda _mt_br,x
  sta PPUDATA
  iny
  tya
  and #$0F
  bne @bot
  inc t3
  lda t3
  cmp #15
  bne @rows
  ; attributes
  bit PPUSTATUS
  lda #$23
  sta PPUADDR
  lda #$C0
  sta PPUADDR
  lda #0
  sta t5+0                      ; reuse t5 as attr index (rand unused here)
@attrs:
  ldx t5
  jsr attr_calc
  sta PPUDATA
  inc t5
  lda t5
  cmp #64
  bne @attrs
  rts

; A = attribute byte for attr cell X (0-63), from maprm
attr_calc:
  txa
  pha
  and #$07
  asl
  sta t4
  pla
  and #$38
  asl
  asl
  ora t4
  tay                           ; top-left metatile index
  ldx maprm,y
  lda _mt_attr,x
  and #$03
  sta t4
  iny
  ldx maprm,y
  lda _mt_attr,x
  and #$03
  asl
  asl
  ora t4
  sta t4
  tya
  clc
  adc #15                       ; +16 from TL (y is TL+1)
  cmp #240
  bcc :+
  sbc #16                       ; bottom attr row: mirror row 14
:
  tay
  ldx maprm,y
  lda _mt_attr,x
  and #$03
  asl
  asl
  asl
  asl
  ora t4
  sta t4
  iny
  ldx maprm,y
  lda _mt_attr,x
  and #$03
  lsr
  ror
  ror                           ; <<6 via rotate right x2 with 0 in bit7
  ora t4
  rts

; queue both tile rows of metatile row A (buffered restore)
queue_mtrow:
  pha
  asl
  asl
  asl
  asl
  sta t3                        ; map index base
  pla
  pha
  asl                           ; tile row = mtrow*2
  tay
  lda #0
  jsr tile_addr
  jsr stage_half_top
  lda #32
  jsr queue_row
  pla
  asl
  tay
  iny
  lda #0
  jsr tile_addr
  jsr stage_half_bot
  lda #32
  jmp queue_row

stage_half_top:
  lda #0
  sta t2                        ; col
@l:
  lda t3
  clc
  adc t2
  tay
  lda maprm,y
  tax
  lda t2
  asl
  tay
  lda _mt_tl,x
  sta rowbuf,y
  lda _mt_tr,x
  sta rowbuf+1,y
  inc t2
  lda t2
  cmp #16
  bne @l
  rts

stage_half_bot:
  lda #0
  sta t2
@l:
  lda t3
  clc
  adc t2
  tay
  lda maprm,y
  tax
  lda t2
  asl
  tay
  lda _mt_bl,x
  sta rowbuf,y
  lda _mt_br,x
  sta rowbuf+1,y
  inc t2
  lda t2
  cmp #16
  bne @l
  rts

; queue attribute row A (8 bytes) recomputed from maprm
queue_attr_row:
  asl
  asl
  asl
  sta t3                        ; attr index base
  lda #0
  sta t2
@l:
  lda t3
  clc
  adc t2
  tax
  jsr attr_calc
  ldy t2
  sta rowbuf,y
  inc t2
  lda t2
  cmp #8
  bne @l
  lda #$23
  sta t0
  lda t3
  clc
  adc #$C0
  sta t1
  lda #8
  jmp queue_row

.segment "ZEROPAGE"
rr_row: .res 1
rr_cnt: .res 1
rr_a0:  .res 1
rr_a1:  .res 1
.segment "CODE"

; restore metatile rows A..A+X-1 (tiles + touched attr rows), buffered
restore_rows:
  sta rr_row
  stx rr_cnt
  lsr
  sta rr_a0                     ; first attr row
  lda rr_row
  clc
  adc rr_cnt
  sec
  sbc #1
  lsr
  sta rr_a1                     ; last attr row
@rows:
  lda rr_row
  jsr queue_mtrow
  jsr wait_frame
  inc rr_row
  dec rr_cnt
  bne @rows
@attrs:
  lda rr_a0
  jsr queue_attr_row
  jsr wait_frame
  inc rr_a0
  lda rr_a0
  cmp rr_a1
  bcc @attrs
  beq @attrs
  rts

; ------------------------------------------------------------ direct printing
; print string p0 at col X, row Y — rendering must be off
blank_print:
  txa
  jsr tile_addr
  bit PPUSTATUS
  lda t0
  sta PPUADDR
  lda t1
  sta PPUADDR
  ldy #0
@l:
  lda (p0),y
  cmp #TXT_END
  beq @done
  sta PPUDATA
  iny
  bne @l
@done:
  rts

; fill A tiles of value t2 at t0/t1 — rendering must be off
blank_fill:
  tax
  bit PPUSTATUS
  lda t0
  sta PPUADDR
  lda t1
  sta PPUADDR
  lda t2
@l:
  sta PPUDATA
  dex
  bne @l
  rts

; ------------------------------------------------------------------ decimal
.segment "BSS"
decbuf: .res 5
.segment "CODE"

; convert t0(lo)/t1(hi) to 5 digits in decbuf
bin_to_dec:
  ldx #0
@digit:
  lda #0
  sta decbuf,x
@sub:
  lda t1
  cmp pow10_hi,x
  bcc @next
  bne @dosub
  lda t0
  cmp pow10_lo,x
  bcc @next
@dosub:
  lda t0
  sec
  sbc pow10_lo,x
  sta t0
  lda t1
  sbc pow10_hi,x
  sta t1
  inc decbuf,x
  jmp @sub
@next:
  inx
  cpx #5
  bne @digit
  rts

.segment "RODATA"
pow10_lo: .byte <10000, <1000, <100, <10, <1
pow10_hi: .byte >10000, >1000, >100, >10, >1
.segment "CODE"

; ------------------------------------------------------------------ sprites
oam_clear:
  lda #$F0
  ldx #0
@l:
  sta OAMBUF,x
  inx
  bne @l
  lda #0
  sta oam_i
  rts

; 16x16 metasprite: t0=x t1=y t2=tile t3=attr (bit6 = hflip)
draw_meta16:
  ldx oam_i
  lda t1
  beq :+
  sec
  sbc #1
:
  sta OAMBUF,x                  ; TL y
  sta OAMBUF+4,x
  clc
  adc #8
  sta OAMBUF+8,x                ; BL y
  sta OAMBUF+12,x
  lda t3
  sta OAMBUF+2,x
  sta OAMBUF+6,x
  sta OAMBUF+10,x
  sta OAMBUF+14,x
  lda t0
  sta OAMBUF+3,x                ; TL x
  sta OAMBUF+11,x
  clc
  adc #8
  sta OAMBUF+7,x
  sta OAMBUF+15,x
  lda t3
  and #$40
  bne @flip
  lda t2
  sta OAMBUF+1,x
  clc
  adc #1
  sta OAMBUF+5,x
  adc #1
  sta OAMBUF+9,x
  adc #1
  sta OAMBUF+13,x
  jmp @done
@flip:
  lda t2
  sta OAMBUF+5,x
  clc
  adc #1
  sta OAMBUF+1,x
  adc #1
  sta OAMBUF+13,x
  adc #1
  sta OAMBUF+9,x
@done:
  txa
  clc
  adc #16
  sta oam_i
  rts
