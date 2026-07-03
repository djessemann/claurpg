; ============================================================================
; menu.s — generic vertical cursor menu (battle + field menus)
; ============================================================================
.include "defs.inc"
.include "gen/tiles.inc"

.importzp pad_new
.import wait_nmi, read_pad, win_putc, sfx_play
.export menu_run, mn_col, mn_row, mn_step, mn_count, mn_cur

.segment "ZEROPAGE"
mn_col:   .res 1
mn_row:   .res 1
mn_step:  .res 1
mn_count: .res 1
mn_cur:   .res 1

.segment "CODE"

; run menu; returns A = selected index, or $FF if B pressed. mn_cur preserved.
menu_run:
  jsr cur_on
@loop:
  jsr wait_nmi
  jsr read_pad
  lda pad_new
  and #BTN_UP
  beq @ckdn
  lda mn_cur
  beq @loop
  jsr cur_off
  dec mn_cur
  lda #SFX_BLIP
  jsr sfx_play
  jsr cur_on
  jmp @loop
@ckdn:
  lda pad_new
  and #BTN_DOWN
  beq @cka
  lda mn_cur
  clc
  adc #1
  cmp mn_count
  bcs @loop
  jsr cur_off
  inc mn_cur
  lda #SFX_BLIP
  jsr sfx_play
  jsr cur_on
  jmp @loop
@cka:
  lda pad_new
  and #BTN_A
  beq @ckb
  lda #SFX_BLIP
  jsr sfx_play
  jsr cur_off
  lda mn_cur
  rts
@ckb:
  lda pad_new
  and #BTN_B
  beq @loop
  jsr cur_off
  lda #$FF
  rts

cur_on:
  lda #CH_CUR
  bne cur_put
cur_off:
  lda #0
cur_put:
  pha
  ; row = mn_row + mn_cur*mn_step
  lda #0
  sta mn_tmp
  ldx mn_cur
  beq @done
@add:
  clc
  lda mn_tmp
  adc mn_step
  sta mn_tmp
  dex
  bne @add
@done:
  lda mn_row
  clc
  adc mn_tmp
  tay
  ldx mn_col
  pla
  jmp win_putc

.segment "ZEROPAGE"
mn_tmp: .res 1
