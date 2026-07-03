; ============================================================================
; sound.s — music driver (pulse1 melody + triangle bass) and sound effects
; ============================================================================
; Song streams: [note-index, frames] pairs; $FF = rest, $FE = loop to start.
; All APU writes happen inside the NMI to keep main-thread timing clean.

.segment "ZEROPAGE"
sfx_nzid:  .res 1
sfx_nznew: .res 1
sfx_p2id:  .res 1
sfx_p2new: .res 1
sfx_per:   .res 1
sfx_elap:  .res 1

.segment "CODE"

sound_update:
  jsr music_tick
  jmp sfx_tick

; A = song id (main thread); restarts only when the song changes
music_play:
  cmp mus
  beq @same
  pha
  lda #0
  sta mus                       ; mute while pointers move
  pla
  cmp #MUS_NONE
  beq music_stop
  pha
  sta t5
  ldx t5
  dex
  txa
  asl
  asl
  tax
  lda song_tbl,x
  sta m1ptr
  lda song_tbl+1,x
  sta m1ptr+1
  lda song_tbl+2,x
  sta m2ptr
  lda song_tbl+3,x
  sta m2ptr+1
  lda #1
  sta m1dly
  sta m2dly
  pla
  sta mus
@same:
  rts

music_stop:
  lda #0
  sta mus
  lda #$B0
  sta $4000
  lda #$80
  sta $4008
  rts

music_tick:
  lda mus
  bne :+
  rts
:
  ; --- pulse 1: melody
  dec m1dly
  bne @ch2
@fetch1:
  ldy #0
  lda (m1ptr),y
  cmp #$FE
  bne :+
  jsr m1_reload
  jmp @fetch1
:
  cmp #$FF
  bne @note1
  lda #$B0
  sta $4000
  jmp @dur1
@note1:
  tax
  lda #$B8                      ; duty 50, const vol 8
  sta $4000
  lda note_lo,x
  sta $4002
  lda note_hi,x
  sta $4003
@dur1:
  ldy #1
  lda (m1ptr),y
  sta m1dly
  lda m1ptr
  clc
  adc #2
  sta m1ptr
  bcc @ch2
  inc m1ptr+1
@ch2:
  ; --- triangle: bass
  dec m2dly
  bne @done
@fetch2:
  ldy #0
  lda (m2ptr),y
  cmp #$FE
  bne :+
  jsr m2_reload
  jmp @fetch2
:
  cmp #$FF
  bne @note2
  lda #$80
  sta $4008
  jmp @dur2
@note2:
  tax
  lda #$FF
  sta $4008
  lda note_lo,x
  sta $400A
  lda note_hi,x
  sta $400B
@dur2:
  ldy #1
  lda (m2ptr),y
  sta m2dly
  lda m2ptr
  clc
  adc #2
  sta m2ptr
  bcc @done
  inc m2ptr+1
@done:
  rts

m1_reload:
  ldx mus
  dex
  txa
  asl
  asl
  tax
  lda song_tbl,x
  sta m1ptr
  lda song_tbl+1,x
  sta m1ptr+1
  rts

m2_reload:
  ldx mus
  dex
  txa
  asl
  asl
  tax
  lda song_tbl+2,x
  sta m2ptr
  lda song_tbl+3,x
  sta m2ptr+1
  rts

; --------------------------------------------------------------------- SFX
; A = sfx id (main thread)
sfx_play:
  tax
  lda sfx_len,x
  cpx #SFX_HIT
  beq @noise
  cpx #SFX_HURT
  beq @noise
  sta sfx_hi
  stx sfx_p2id
  lda #1
  sta sfx_p2new
  rts
@noise:
  sta sfx_lo
  stx sfx_nzid
  lda #1
  sta sfx_nznew
  rts

sfx_tick:
  ; --- noise
  lda sfx_lo
  beq @nzsil
  dec sfx_lo
  lda sfx_nznew
  beq @nzmod
  lda #0
  sta sfx_nznew
  lda sfx_nzid
  cmp #SFX_HIT
  bne :+
  lda #$04
  bne @nzper
:
  lda #$0B
@nzper:
  sta $400E
  lda #$08
  sta $400F
@nzmod:
  lda sfx_lo
  cmp #15
  bcc :+
  lda #15
:
  ora #$30
  sta $400C
  jmp @p2
@nzsil:
  lda #$30
  sta $400C
@p2:
  ; --- pulse 2
  lda sfx_hi
  beq @p2sil
  dec sfx_hi
  lda sfx_p2new
  beq @p2mod
  lda #0
  sta sfx_p2new
  sta sfx_elap
  lda #$B6                      ; duty 50, const vol 6
  sta $4004
  ldx sfx_p2id
  lda p2_init_lo,x
  sta sfx_per
  sta $4006
  lda p2_init_hi,x
  sta $4007
@p2mod:
  inc sfx_elap
  ldx sfx_p2id
  cpx #SFX_SPELL
  beq @spell
  cpx #SFX_STAIR
  beq @stair
  cpx #SFX_GOLD
  beq @gold
  cpx #SFX_FANFARE
  beq @fanf
  rts
@spell:
  lda sfx_per
  sec
  sbc #10
  sta sfx_per
  sta $4006
  rts
@stair:
  lda sfx_per
  clc
  adc #10
  sta sfx_per
  sta $4006
  rts
@gold:
  lda sfx_elap
  and #$04
  beq :+
  lda #$54
  bne @gset
:
  lda #$7E
@gset:
  sta $4006
  rts
@fanf:
  lda sfx_elap
  lsr
  lsr
  lsr
  cmp #5
  bcc :+
  lda #4
:
  tax
  lda fanf_seq,x
  sta $4006
  rts
@p2sil:
  lda #$B0
  sta $4004
  rts

.segment "RODATA"
;              -    BLIP HIT  HURT SPEL STAIR GOLD FANF
sfx_len:  .byte 0,   5,   8,  16,  24,  14,  16,  44
p2_init_lo: .byte 0, $7E,  0,   0, $F0, $60, $7E, $D4
p2_init_hi: .byte 0,   0,  0,   0, $01, $00, $00, $00
fanf_seq: .byte $D4, $A8, $8D, $6A, $6A
.segment "CODE"
