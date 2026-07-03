; ============================================================================
; boot.s — MMC1 init, reset, NMI, frame sync, VRAM queue, input, RNG, banking
; ============================================================================
.include "defs.inc"

.segment "ZEROPAGE"
nmi_ready:  .res 1
render_on:  .res 1
frame_cnt:  .res 1
pad:        .res 1
pad_prev:   .res 1
pad_new:    .res 1
rng:        .res 2
p0:         .res 2
p1:         .res 2
p2:         .res 2
tmp:        .res 8              ; tmp+0..tmp+7 scratch
cur_bank:   .res 1             ; PRG bank currently at $8000

; scroll state (maintained by scroll.s, consumed by NMI)
scrollX:    .res 1             ; low 8 bits of horizontal scroll (0-255)
scrollXhi:  .res 1             ; bit0 = 9th bit (which nametable)
scrollY:    .res 1             ; 0-239
ppumask_sh: .res 1             ; shadow of PPUMASK to apply each frame
oam_top:    .res 1             ; next free OAM slot (bytes)

.segment "OAMSEG"
OAM:        .res 256

.segment "BSS"
; VRAM update queue: stream of [len, ctrl, hi, lo, data...] ; 0 len terminates.
;   ctrl bit0 = increment mode (0:+1 across, 1:+32 down)
vq:         .res 220
vq_len:     .res 1             ; bytes used in vq

.segment "CODE"

; ------------------------------------------------------------------- reset
.export reset
reset:
  sei
  cld
  ldx #$40
  stx JOY2                    ; disable APU frame IRQ
  ldx #$FF
  txs
  inx
  stx PPUCTRL
  stx PPUMASK
  stx $4010
  ; MMC1 reset: write $80 to control to reset shift register, then set mode
  lda #$80
  sta MMC1_CTRL
  ; control = $0E: vertical mirror(2) + PRG mode 3 fix-last(0C) + CHR 4k mode(00? bit4)
  ; bits: mirror=10(vertical), prg=11(fix last @C000, switch @8000), chr=1(two 4k)
  lda #%00011110
  MMC1W MMC1_CTRL
  lda #0
  MMC1W MMC1_CHR0             ; BG uses CHR window 0 -> 4k bank 0
  lda #1
  MMC1W MMC1_CHR1             ; sprites use CHR window 1 -> 4k bank 1
  lda #0
  sta cur_bank
  MMC1W MMC1_PRG             ; bank 0 at $8000 (fixed last already at $C000)

  bit PPUSTATUS
: bit PPUSTATUS
  bpl :-
  ; clear RAM
  lda #0
  tax
@clr:
  sta $00,x
  sta $0300,x
  sta $0400,x
  sta $0500,x
  sta $0600,x
  sta $0700,x
  inx
  bne @clr
  lda #$FF
  ldx #0
@oam:
  sta OAM,x
  inx
  bne @oam
: bit PPUSTATUS
  bpl :-
  lda #$C1
  sta rng
  lda #$17
  sta rng+1
  lda #%00011110
  sta ppumask_sh
  lda #$0F
  sta APUSTATUS
  lda #$80
  sta PPUCTRL               ; enable NMI
  jmp main

; ------------------------------------------------------------------- NMI
.export nmi
nmi:
  pha
  txa
  pha
  tya
  pha
  lda nmi_ready
  bne @go
  jmp @skip
@go:
  ; OAM DMA
  lda #0
  sta OAMADDR
  lda #>OAM
  sta OAMDMA
  ; flush VRAM queue
  ldx #0
  cpx vq_len
  beq @scroll
@qloop:
  lda vq,x                   ; len
  beq @scroll
  sta tmp+0
  inx
  lda vq,x                   ; ctrl
  and #$01
  beq :+
  lda #%10000100             ; +32 increment, NMI on
  bne :++
: lda #%10000000             ; +1 increment
:
  sta PPUCTRL
  inx
  lda vq,x                   ; hi
  sta PPUADDR
  inx
  lda vq,x                   ; lo
  sta PPUADDR
  inx
@qwrite:
  lda vq,x
  sta PPUDATA
  inx
  dec tmp+0
  bne @qwrite
  cpx vq_len
  bcc @qloop
@scroll:
  lda #0
  sta vq_len
  sta vq
  ; scroll registers
  bit PPUSTATUS
  lda scrollX
  sta PPUSCROLL
  lda scrollY
  sta PPUSCROLL
  lda #%10001000             ; NMI on, sprites @ $1000, bg @ $0000, +1 inc
  ora scrollXhi
  sta PPUCTRL
  lda ppumask_sh
  sta PPUMASK
  lda #0
  sta nmi_ready
@skip:
  inc frame_cnt
  jsr sound_tick
  pla
  tay
  pla
  tax
  pla
.export irq
irq:
  rti

; ------------------------------------------------------------- frame sync
.export wait_nmi
wait_nmi:
  lda #1
  sta nmi_ready
: lda nmi_ready
  bne :-
  jsr rng_step
  rts

; render on/off (forced blank for big direct draws)
.export ppu_off
ppu_off:
  lda #0
  sta render_on
  sta nmi_ready
  jsr wait_nmi_raw
  lda #0
  sta PPUMASK
  rts

.export ppu_on
ppu_on:
  lda #1
  sta render_on
  jmp wait_nmi

wait_nmi_raw:
  lda #1
  sta nmi_ready
: lda nmi_ready
  bne :-
  rts

; -------------------------------------------------------------------- RNG
.export rng_step
rng_step:
  lda rng
  asl
  asl
  eor rng
  asl
  eor rng
  asl
  asl
  eor rng
  asl
  rol rng+1                   ; galois-ish 16-bit
  rol rng
  lda rng
  rts

; A = modulus -> A in 0..mod-1
.export rand_mod
rand_mod:
  sta tmp+7
  jsr rng_step
  lda rng
@l:
  cmp tmp+7
  bcc @done
  sbc tmp+7
  jmp @l
@done:
  rts

; -------------------------------------------------------------------- input
.export read_pad
read_pad:
  lda pad
  sta pad_prev
  lda #1
  sta JOY1
  lda #0
  sta JOY1
  ldx #8
@l:
  lda JOY1
  and #3
  cmp #1
  rol pad
  dex
  bne @l
  lda pad_prev
  eor #$FF
  and pad
  sta pad_new
  rts

; ------------------------------------------------------------ PRG banking
; A = bank number for $8000-$BFFF window
.export set_bank
set_bank:
  sta cur_bank
  MMC1W MMC1_PRG
  rts

; A = 4k CHR bank for BG window ($0000)
.export set_chr_bg
set_chr_bg:
  MMC1W MMC1_CHR0
  rts

; A = 4k CHR bank for sprite window ($1000)
.export set_chr_spr
set_chr_spr:
  MMC1W MMC1_CHR1
  rts

; VRAM queue push helpers live in ppu.s (vq_begin / vq_byte / vq_row).
