; ============================================================================
; sound.s — EREBUS 2A03 APU music + sound-effects driver
; ============================================================================
; Architecture
; ------------
;   * Music: three streams of (note, duration_frames) events -- pulse1
;     (melody), triangle (bass), pulse2 (harmony/pad). Each channel has its
;     own pointer + frame counter and loops independently via a CTL_LOOP
;     marker (all three streams in a given song sum to the same total
;     frame length, so they stay in phase across the loop).
;   * SFX: two tiny "step sequencer" engines, one driving the noise channel
;     (percussive: HIT/HURT/DOOR) and one driving pulse2 (pitched blips /
;     arpeggios: BLIP/TECH/ITEM/FANFARE/DENY/HEAL). Each step is
;     (pitch-or-period, volume/instrument, duration); duration==0 ends the
;     sequence. While a pulse2 SFX is active, pulse2 music is frozen (its
;     pointer/counter simply aren't advanced) and the last music
;     period/instrument is cached so it can be restored the instant the
;     SFX finishes.
;   * Triangle has no volume control, so "rest" is implemented by clearing
;     its enable bit in $4015 (and "note on" by setting it); pulse1/pulse2
;     rests are implemented with constant-volume=0 instead (simpler, no
;     retrigger needed). Noise is always enabled; SFX inactivity is
;     volume 0.
;   * $4008 (triangle linear counter) is written every frame with a halted
;     max reload ($FF) so the hardware length/linear counters can never
;     auto-silence the channel out from under the driver -- all timing is
;     fully driver-managed.
;
; RAM budget: ~22 zero-page bytes (driver state only). All song/SFX data
; lives in RODATA in the fixed bank ($C000+), so it is always addressable
; regardless of PRG bank switching elsewhere in the game.
; ============================================================================

.include "defs.inc"

.export sound_tick, music_play, music_stop, sfx_play

; ---- control bytes in note streams --------------------------------------
CTL_REST = $FF                 ; rest for the following duration byte
CTL_LOOP = $FE                 ; followed by a 2-byte address to jump to

; ---- chromatic note table indices (C2..B5, 4 octaves, 48 semitones) -----
N_C2=0
N_Cs2=1
N_D2=2
N_Ds2=3
N_E2=4
N_F2=5
N_Fs2=6
N_G2=7
N_Gs2=8
N_A2=9
N_As2=10
N_B2=11
N_C3=12
N_Cs3=13
N_D3=14
N_Ds3=15
N_E3=16
N_F3=17
N_Fs3=18
N_G3=19
N_Gs3=20
N_A3=21
N_As3=22
N_B3=23
N_C4=24
N_Cs4=25
N_D4=26
N_Ds4=27
N_E4=28
N_F4=29
N_Fs4=30
N_G4=31
N_Gs4=32
N_A4=33
N_As4=34
N_B4=35
N_C5=36
N_Cs5=37
N_D5=38
N_Ds5=39
N_E5=40
N_F5=41
N_Fs5=42
N_G5=43
N_Gs5=44
N_A5=45
N_As5=46
N_B5=47

; ============================================================================
.segment "ZEROPAGE"

mus_cur_song:     .res 1  ; currently playing MUS_* id (0 = none)

mus_p1_ptr:       .res 2  ; pulse1 (melody) track pointer
mus_p1_cnt:       .res 1  ; frames left in current pulse1 event
mus_p1_instr:     .res 1  ; per-song base instrument byte (duty|halt|cv|vol)

mus_tr_ptr:       .res 2  ; triangle (bass) track pointer
mus_tr_cnt:       .res 1  ; frames left in current triangle event

mus_p2_ptr:       .res 2  ; pulse2 (harmony) track pointer
mus_p2_cnt:       .res 1  ; frames left in current pulse2 event
mus_p2_instr:     .res 1  ; per-song base instrument byte
mus_p2_lastreg:   .res 1  ; last $4004 value written by music (for SFX restore)
mus_p2_lastlo:    .res 1  ; last $4006 value written by music
mus_p2_lasthi:    .res 1  ; last $4007 value written by music

sfx_no_ptr:       .res 2  ; active noise-SFX step pointer (hi=0 -> inactive)
sfx_no_cnt:       .res 1  ; frames left in current noise-SFX step

sfx_p2_ptr:       .res 2  ; active pulse2-SFX step pointer (hi=0 -> inactive)
sfx_p2_cnt:       .res 1  ; frames left in current pulse2-SFX step

; total: 1+2+1+1 +2+1 +2+1+1+1+1+1 +2+1 +2+1 = 22 bytes

; ============================================================================
.segment "CODE"

; ---------------------------------------------------------------- sound_tick
; Called once per frame from NMI. Advances music + SFX and writes APU regs.
sound_tick:
  lda #$FF
  sta $4008             ; triangle: halt + max linear reload, every frame
  jsr tick_music_p1
  jsr tick_music_tri
  jsr tick_music_p2
  jsr service_sfx_noise
  jsr service_sfx_pulse2
  rts

; ---------------------------------------------------------------- music_play
; A = MUS_* id. Starts that song looping (no-op if already playing).
; A == MUS_NONE stops music.
music_play:
  cmp mus_cur_song
  beq @done
  cmp #MUS_NONE
  beq @stop
  sta mus_cur_song
  tax
  dex                       ; X = song index 0..7
  lda song_p1_lo,x
  sta mus_p1_ptr
  lda song_p1_hi,x
  sta mus_p1_ptr+1
  lda #0
  sta mus_p1_cnt
  lda song_p1_instr,x
  sta mus_p1_instr

  lda song_tr_lo,x
  sta mus_tr_ptr
  lda song_tr_hi,x
  sta mus_tr_ptr+1
  lda #0
  sta mus_tr_cnt

  lda song_p2_lo,x
  sta mus_p2_ptr
  lda song_p2_hi,x
  sta mus_p2_ptr+1
  lda #0
  sta mus_p2_cnt
  lda song_p2_instr,x
  sta mus_p2_instr
@done:
  rts
@stop:
  jmp music_stop

; ---------------------------------------------------------------- music_stop
; Silence music channels and mark no song playing.
music_stop:
  lda #MUS_NONE
  sta mus_cur_song
  lda #0
  sta mus_p1_ptr+1
  sta mus_tr_ptr+1
  sta mus_p2_ptr+1
  lda #$30                  ; duty0, halt, const-vol, vol=0
  sta $4000
  sta $4004
  lda #$0B                  ; all channels enabled except triangle
  sta APUSTATUS
  rts

; ------------------------------------------------------------------ sfx_play
; A = SFX_* id. Triggers a one-shot SFX on noise and/or pulse2.
sfx_play:
  tax
  lda sfx_noise_hi,x
  beq @noNoise
  sta sfx_no_ptr+1
  lda sfx_noise_lo,x
  sta sfx_no_ptr
  lda #0
  sta sfx_no_cnt
@noNoise:
  lda sfx_p2_hi,x
  beq @noP2
  sta sfx_p2_ptr+1
  lda sfx_p2_lo,x
  sta sfx_p2_ptr
  lda #0
  sta sfx_p2_cnt
@noP2:
  rts

; ======================================================================
; tick_music_p1 -- advance/program the pulse1 (melody) channel
; ======================================================================
tick_music_p1:
  lda mus_p1_cnt
  beq @fetch
  dec mus_p1_cnt
  rts
@fetch:
  lda mus_p1_ptr+1
  beq @rts
@read:
  ldy #0
  lda (mus_p1_ptr),y
  cmp #CTL_LOOP
  bne @chkrest
  iny
  lda (mus_p1_ptr),y
  pha
  iny
  lda (mus_p1_ptr),y
  sta mus_p1_ptr+1
  pla
  sta mus_p1_ptr
  jmp @read
@chkrest:
  pha
  iny
  lda (mus_p1_ptr),y
  sec
  sbc #1                    ; this frame is the 1st of 'duration' frames
  sta mus_p1_cnt
  clc
  lda mus_p1_ptr
  adc #2
  sta mus_p1_ptr
  bcc @noc
  inc mus_p1_ptr+1
@noc:
  pla
  cmp #CTL_REST
  beq @rest
  tax
  lda mus_p1_instr
  sta $4000
  lda PULSE_PER_LO,x
  sta $4002
  lda PULSE_PER_HI,x
  sta $4003
  rts
@rest:
  lda mus_p1_instr
  and #$F0
  sta $4000
@rts:
  rts

; ======================================================================
; tick_music_tri -- advance/program the triangle (bass) channel
; ======================================================================
tick_music_tri:
  lda mus_tr_cnt
  beq @fetch
  dec mus_tr_cnt
  rts
@fetch:
  lda mus_tr_ptr+1
  beq @rts
@read:
  ldy #0
  lda (mus_tr_ptr),y
  cmp #CTL_LOOP
  bne @chkrest
  iny
  lda (mus_tr_ptr),y
  pha
  iny
  lda (mus_tr_ptr),y
  sta mus_tr_ptr+1
  pla
  sta mus_tr_ptr
  jmp @read
@chkrest:
  pha
  iny
  lda (mus_tr_ptr),y
  sec
  sbc #1                    ; this frame is the 1st of 'duration' frames
  sta mus_tr_cnt
  clc
  lda mus_tr_ptr
  adc #2
  sta mus_tr_ptr
  bcc @noc
  inc mus_tr_ptr+1
@noc:
  pla
  cmp #CTL_REST
  beq @rest
  tax
  lda TRI_PER_LO,x
  sta $400A
  lda TRI_PER_HI,x
  sta $400B
  lda #$0F                  ; enable all 4 channels (triangle on)
  sta APUSTATUS
  rts
@rest:
  lda #$0B                  ; disable triangle only
  sta APUSTATUS
@rts:
  rts

; ======================================================================
; tick_music_p2 -- advance/program the pulse2 (harmony) channel.
; Frozen while a pulse2 SFX is active (sfx_p2_ptr+1 != 0).
; ======================================================================
tick_music_p2:
  lda sfx_p2_ptr+1
  bne @rts                  ; SFX owns pulse2 hardware this frame
  lda mus_p2_cnt
  beq @fetch
  dec mus_p2_cnt
  rts
@fetch:
  lda mus_p2_ptr+1
  beq @rts
@read:
  ldy #0
  lda (mus_p2_ptr),y
  cmp #CTL_LOOP
  bne @chkrest
  iny
  lda (mus_p2_ptr),y
  pha
  iny
  lda (mus_p2_ptr),y
  sta mus_p2_ptr+1
  pla
  sta mus_p2_ptr
  jmp @read
@chkrest:
  pha
  iny
  lda (mus_p2_ptr),y
  sec
  sbc #1                    ; this frame is the 1st of 'duration' frames
  sta mus_p2_cnt
  clc
  lda mus_p2_ptr
  adc #2
  sta mus_p2_ptr
  bcc @noc
  inc mus_p2_ptr+1
@noc:
  pla
  cmp #CTL_REST
  beq @rest
  tax
  lda mus_p2_instr
  sta mus_p2_lastreg
  sta $4004
  lda PULSE_PER_LO,x
  sta mus_p2_lastlo
  sta $4006
  lda PULSE_PER_HI,x
  sta mus_p2_lasthi
  sta $4007
  rts
@rest:
  lda mus_p2_instr
  and #$F0
  sta mus_p2_lastreg
  sta $4004
@rts:
  rts

; ======================================================================
; service_sfx_noise -- step the noise-channel SFX engine
; step = (period_byte [bit7=mode,bits3-0=period idx], volume, duration)
; ======================================================================
service_sfx_noise:
  lda sfx_no_ptr+1
  beq @rts
  lda sfx_no_cnt
  beq @fetch
  dec sfx_no_cnt
  rts
@fetch:
  ldy #2
  lda (sfx_no_ptr),y
  beq @stop
  sec
  sbc #1                    ; this frame is the 1st of 'duration' frames
  sta sfx_no_cnt
  ldy #0
  lda (sfx_no_ptr),y
  sta $400E
  ldy #1
  lda (sfx_no_ptr),y
  ora #$30                  ; halt + constant volume
  sta $400C
  clc
  lda sfx_no_ptr
  adc #3
  sta sfx_no_ptr
  bcc @nc
  inc sfx_no_ptr+1
@nc:
  rts
@stop:
  lda #$30                  ; volume 0 -> silent
  sta $400C
  lda #0
  sta sfx_no_ptr+1
@rts:
  rts

; ======================================================================
; service_sfx_pulse2 -- step the pulse2 SFX engine
; step = (note index, instrument byte, duration)
; ======================================================================
service_sfx_pulse2:
  lda sfx_p2_ptr+1
  beq @rts
  lda sfx_p2_cnt
  beq @fetch
  dec sfx_p2_cnt
  rts
@fetch:
  ldy #2
  lda (sfx_p2_ptr),y
  beq @stop
  sec
  sbc #1                    ; this frame is the 1st of 'duration' frames
  sta sfx_p2_cnt
  ldy #0
  lda (sfx_p2_ptr),y
  tax
  ldy #1
  lda (sfx_p2_ptr),y
  sta $4004
  lda PULSE_PER_LO,x
  sta $4006
  lda PULSE_PER_HI,x
  sta $4007
  clc
  lda sfx_p2_ptr
  adc #3
  sta sfx_p2_ptr
  bcc @nc
  inc sfx_p2_ptr+1
@nc:
  rts
@stop:
  lda #0
  sta sfx_p2_ptr+1           ; deactivate
  lda mus_p2_lastreg          ; restore whatever pulse2 music was doing
  sta $4004
  lda mus_p2_lastlo
  sta $4006
  lda mus_p2_lasthi
  sta $4007
@rts:
  rts

; ============================================================================
.segment "RODATA"

; ---- NTSC note period tables ---------------------------------------------
; period = round(1789773 / (16*freq)) - 1   (pulse, C2..B5)
; period = round(1789773 / (32*freq)) - 1   (triangle, C2..B5)
; A4 = 440Hz, equal temperament. Index 0 = C2 (~65.4Hz) .. index 47 = B5 (~988Hz)
PULSE_PER_LO:
  .byte $AD,$4D,$F3,$9D,$4C,$00,$B8,$74,$34,$F8,$BF,$89
  .byte $56,$26,$F9,$CE,$A6,$80,$5C,$3A,$1A,$FB,$DF,$C4
  .byte $AB,$93,$7C,$67,$52,$3F,$2D,$1C,$0C,$FD,$EF,$E1
  .byte $D5,$C9,$BD,$B3,$A9,$9F,$96,$8E,$86,$7E,$77,$70
PULSE_PER_HI:
  .byte $06,$06,$05,$05,$05,$05,$04,$04,$04,$03,$03,$03
  .byte $03,$03,$02,$02,$02,$02,$02,$02,$02,$01,$01,$01
  .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$00,$00,$00
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
TRI_PER_LO:
  .byte $56,$26,$F9,$CE,$A6,$80,$5C,$3A,$1A,$FB,$DF,$C4
  .byte $AB,$93,$7C,$67,$52,$3F,$2D,$1C,$0C,$FD,$EF,$E1
  .byte $D5,$C9,$BD,$B3,$A9,$9F,$96,$8E,$86,$7E,$77,$70
  .byte $6A,$64,$5E,$59,$54,$4F,$4B,$46,$42,$3F,$3B,$38
TRI_PER_HI:
  .byte $03,$03,$02,$02,$02,$02,$02,$02,$02,$01,$01,$01
  .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$00,$00,$00
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

; ---- per-song track pointers + base instrument bytes ----------------------
; order matches MUS_TITLE..MUS_SAFE (1..8), index = id-1
song_p1_lo:   .byte <song_title_p1,<song_ship_p1,<song_hold_p1,<song_bloom_p1,<song_battle_p1,<song_boss_p1,<song_end_p1,<song_safe_p1
song_p1_hi:   .byte >song_title_p1,>song_ship_p1,>song_hold_p1,>song_bloom_p1,>song_battle_p1,>song_boss_p1,>song_end_p1,>song_safe_p1
song_p1_instr:.byte $B8,$B9,$36,$F7,$BB,$BC,$BA,$77

song_tr_lo:   .byte <song_title_tr,<song_ship_tr,<song_hold_tr,<song_bloom_tr,<song_battle_tr,<song_boss_tr,<song_end_tr,<song_safe_tr
song_tr_hi:   .byte >song_title_tr,>song_ship_tr,>song_hold_tr,>song_bloom_tr,>song_battle_tr,>song_boss_tr,>song_end_tr,>song_safe_tr

song_p2_lo:   .byte <song_title_p2,<song_ship_p2,<song_hold_p2,<song_bloom_p2,<song_battle_p2,<song_boss_p2,<song_end_p2,<song_safe_p2
song_p2_hi:   .byte >song_title_p2,>song_ship_p2,>song_hold_p2,>song_bloom_p2,>song_battle_p2,>song_boss_p2,>song_end_p2,>song_safe_p2
song_p2_instr:.byte $74,$33,$33,$73,$B6,$B7,$75,$33

; ---- SFX dispatch tables (index = SFX_* id, 0 unused) ----------------------
; hi byte 0 = "no data for this channel"; lo/hi = address of step sequence.
sfx_noise_lo: .byte $00, $00,<sfx_hit_n,<sfx_hurt_n, $00,<sfx_door_n, $00, $00, $00, $00
sfx_noise_hi: .byte $00, $00,>sfx_hit_n,>sfx_hurt_n, $00,>sfx_door_n, $00, $00, $00, $00

sfx_p2_lo:    .byte $00,<sfx_blip_p2, $00, $00,<sfx_tech_p2, $00,<sfx_item_p2,<sfx_fanfare_p2,<sfx_deny_p2,<sfx_heal_p2
sfx_p2_hi:    .byte $00,>sfx_blip_p2, $00, $00,>sfx_tech_p2, $00,>sfx_item_p2,>sfx_fanfare_p2,>sfx_deny_p2,>sfx_heal_p2

; ---- noise SFX step data: (period_byte, volume, duration) duration=0 ends -
sfx_hit_n:                     ; SFX_HIT: sharp punchy strike
  .byte $06,15,3
  .byte $08,9,3
  .byte $0A,3,3
  .byte $00,0,0
sfx_hurt_n:                    ; SFX_HURT: harsher, longer, decaying
  .byte $0C,14,5
  .byte $0E,10,6
  .byte $0F,6,6
  .byte $0F,2,6
  .byte $00,0,0
sfx_door_n:                    ; SFX_DOOR: low mechanical rumble (metallic mode)
  .byte $8D,8,10
  .byte $8D,5,10
  .byte $8E,2,10
  .byte $00,0,0

; ---- pulse2 SFX step data: (note index, instrument byte, duration) --------
sfx_blip_p2:                   ; SFX_BLIP: short bright cursor blip
  .byte N_C5,$BD,3
  .byte N_G5,$B6,3
  .byte $00,0,0
sfx_tech_p2:                   ; SFX_TECH: quick ascending confirm chirp
  .byte N_C4,$BC,3
  .byte N_E4,$BC,3
  .byte N_G4,$BA,4
  .byte $00,0,0
sfx_item_p2:                   ; SFX_ITEM: cheerful ascending pickup
  .byte N_C4,$BC,4
  .byte N_E4,$BC,4
  .byte N_G4,$BC,4
  .byte N_C5,$BE,8
  .byte $00,0,0
sfx_fanfare_p2:                ; SFX_FANFARE: triumphant 4-note arpeggio
  .byte N_C4,$BD,6
  .byte N_E4,$BD,6
  .byte N_G4,$BD,6
  .byte N_C5,$BF,14
  .byte $00,0,0
sfx_deny_p2:                   ; SFX_DENY: harsh descending "no" buzz
  .byte N_Ds4,$FC,8
  .byte N_C4,$FA,10
  .byte $00,0,0
sfx_heal_p2:                   ; SFX_HEAL: gentle ascending shimmer
  .byte N_E4,$78,6
  .byte N_G4,$78,6
  .byte N_C5,$7A,10
  .byte $00,0,0

; ---- song note-event streams ----------------------------------------------
; ---- TITLE ----
song_title_p1:
  .byte N_A3,48
  .byte N_C4,48
  .byte N_E4,96
  .byte N_D4,48
  .byte N_C4,48
  .byte CTL_REST,96
  .byte N_E4,48
  .byte N_G4,48
  .byte N_F4,96
  .byte N_E4,48
  .byte CTL_REST,48
  .byte CTL_REST,96
  .byte N_C4,48
  .byte N_B3,48
  .byte N_A3,96
  .byte N_G3,48
  .byte N_A3,48
  .byte CTL_REST,96
  .byte N_E4,48
  .byte N_D4,48
  .byte N_C4,96
  .byte N_B3,48
  .byte N_A3,96
  .byte CTL_REST,48
  .byte CTL_LOOP
  .word song_title_p1
song_title_tr:
  .byte N_A2,192
  .byte N_A2,192
  .byte N_F2,192
  .byte N_E2,192
  .byte N_A2,192
  .byte N_G2,192
  .byte N_F2,192
  .byte N_E2,192
  .byte CTL_LOOP
  .word song_title_tr
song_title_p2:
  .byte N_A3,96
  .byte CTL_REST,96
  .byte N_A3,96
  .byte CTL_REST,96
  .byte N_F3,96
  .byte CTL_REST,96
  .byte N_E3,96
  .byte CTL_REST,96
  .byte N_A3,96
  .byte CTL_REST,96
  .byte N_G3,96
  .byte CTL_REST,96
  .byte N_F3,96
  .byte CTL_REST,96
  .byte N_E3,96
  .byte CTL_REST,96
  .byte CTL_LOOP
  .word song_title_p2

; ---- SHIP ----
song_ship_p1:
  .byte N_D4,32
  .byte N_F4,32
  .byte N_A4,32
  .byte N_G4,32
  .byte N_F4,32
  .byte N_E4,32
  .byte N_D4,64
  .byte N_C4,32
  .byte N_D4,32
  .byte N_F4,32
  .byte N_E4,32
  .byte N_D4,64
  .byte CTL_REST,64
  .byte N_As3,32
  .byte N_C4,32
  .byte N_D4,32
  .byte N_F4,32
  .byte N_G4,32
  .byte N_F4,32
  .byte N_E4,64
  .byte N_D4,32
  .byte N_C4,32
  .byte N_As3,32
  .byte N_A3,32
  .byte N_D4,64
  .byte CTL_REST,64
  .byte CTL_LOOP
  .word song_ship_p1
song_ship_tr:
  .byte N_D2,32
  .byte N_D2,32
  .byte N_A2,32
  .byte N_A2,32
  .byte N_As2,32
  .byte N_As2,32
  .byte N_C3,32
  .byte N_C3,32
  .byte N_D2,32
  .byte N_D2,32
  .byte N_A2,32
  .byte N_A2,32
  .byte N_F2,32
  .byte N_F2,32
  .byte N_C3,32
  .byte N_C3,32
  .byte N_D2,32
  .byte N_D2,32
  .byte N_As2,32
  .byte N_As2,32
  .byte N_A2,32
  .byte N_A2,32
  .byte N_G2,32
  .byte N_G2,32
  .byte N_D2,32
  .byte N_D2,32
  .byte N_C3,32
  .byte N_C3,32
  .byte N_A2,64
  .byte N_A2,64
  .byte CTL_LOOP
  .word song_ship_tr
song_ship_p2:
  .byte N_D3,64
  .byte CTL_REST,64
  .byte N_F3,64
  .byte CTL_REST,64
  .byte N_As3,64
  .byte CTL_REST,64
  .byte N_C4,64
  .byte CTL_REST,64
  .byte N_D3,64
  .byte CTL_REST,64
  .byte N_F3,64
  .byte CTL_REST,64
  .byte N_D3,64
  .byte CTL_REST,64
  .byte N_A3,64
  .byte CTL_REST,64
  .byte CTL_LOOP
  .word song_ship_p2

; ---- HOLD ----
song_hold_p1:
  .byte N_G3,112
  .byte N_Gs3,112
  .byte CTL_REST,112
  .byte N_G3,112
  .byte N_F3,112
  .byte N_Fs3,112
  .byte CTL_REST,224
  .byte N_Ds3,112
  .byte N_D3,112
  .byte CTL_REST,112
  .byte N_Ds3,112
  .byte N_C3,112
  .byte N_B2,112
  .byte CTL_REST,224
  .byte CTL_LOOP
  .word song_hold_p1
song_hold_tr:
  .byte N_C2,224
  .byte N_C2,224
  .byte N_C2,224
  .byte N_C2,224
  .byte N_B2,224
  .byte N_As2,224
  .byte N_C2,224
  .byte N_C2,224
  .byte CTL_LOOP
  .word song_hold_tr
song_hold_p2:
  .byte N_Ds3,224
  .byte CTL_REST,224
  .byte N_D3,224
  .byte CTL_REST,224
  .byte N_Cs3,224
  .byte CTL_REST,224
  .byte N_C3,224
  .byte CTL_REST,224
  .byte CTL_LOOP
  .word song_hold_p2

; ---- BLOOM ----
song_bloom_p1:
  .byte N_E4,40
  .byte N_Fs4,40
  .byte N_Gs4,40
  .byte N_As4,40
  .byte N_C5,80
  .byte CTL_REST,80
  .byte N_As4,40
  .byte N_Gs4,40
  .byte N_Fs4,40
  .byte N_E4,40
  .byte N_D4,80
  .byte CTL_REST,80
  .byte N_E4,40
  .byte N_G4,40
  .byte N_Fs4,40
  .byte N_Ds4,40
  .byte N_E4,80
  .byte CTL_REST,80
  .byte N_C4,40
  .byte N_D4,40
  .byte N_E4,40
  .byte N_Fs4,40
  .byte N_Gs4,80
  .byte CTL_REST,80
  .byte CTL_LOOP
  .word song_bloom_p1
song_bloom_tr:
  .byte N_E2,160
  .byte N_E2,160
  .byte N_Ds2,160
  .byte N_D2,160
  .byte N_E2,160
  .byte N_Fs2,160
  .byte N_C2,160
  .byte N_Cs2,160
  .byte CTL_LOOP
  .word song_bloom_tr
song_bloom_p2:
  .byte N_B3,80
  .byte N_As3,80
  .byte N_Gs3,80
  .byte N_G3,80
  .byte N_Fs3,80
  .byte N_F3,80
  .byte N_E3,80
  .byte N_Ds3,80
  .byte N_Fs3,80
  .byte N_G3,80
  .byte N_Gs3,80
  .byte N_A3,80
  .byte N_B3,80
  .byte N_C4,80
  .byte N_Cs4,80
  .byte CTL_REST,80
  .byte CTL_LOOP
  .word song_bloom_p2

; ---- BATTLE ----
song_battle_p1:
  .byte N_E4,16
  .byte N_G4,16
  .byte N_E4,16
  .byte N_F4,16
  .byte N_G4,16
  .byte N_A4,16
  .byte N_G4,16
  .byte N_F4,16
  .byte N_E4,16
  .byte N_G4,16
  .byte N_B4,16
  .byte N_A4,16
  .byte N_G4,32
  .byte N_F4,32
  .byte N_E4,16
  .byte N_D4,16
  .byte N_E4,16
  .byte N_F4,16
  .byte N_G4,16
  .byte N_F4,16
  .byte N_E4,16
  .byte N_D4,16
  .byte N_C4,16
  .byte N_D4,16
  .byte N_E4,16
  .byte N_F4,16
  .byte N_E4,32
  .byte CTL_REST,32
  .byte CTL_LOOP
  .word song_battle_p1
song_battle_tr:
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_F2,8
  .byte N_F2,8
  .byte N_F2,8
  .byte N_F2,8
  .byte N_F2,8
  .byte N_F2,8
  .byte N_F2,8
  .byte N_F2,8
  .byte N_F2,8
  .byte N_F2,8
  .byte N_F2,8
  .byte N_F2,8
  .byte N_F2,8
  .byte N_F2,8
  .byte N_F2,8
  .byte N_F2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_E2,8
  .byte N_B2,8
  .byte N_B2,8
  .byte N_B2,8
  .byte N_B2,8
  .byte N_B2,8
  .byte N_B2,8
  .byte N_B2,8
  .byte N_B2,8
  .byte N_B2,8
  .byte N_B2,8
  .byte N_B2,8
  .byte N_B2,8
  .byte N_B2,8
  .byte N_B2,8
  .byte N_B2,8
  .byte N_B2,8
  .byte CTL_LOOP
  .word song_battle_tr
song_battle_p2:
  .byte N_B3,16
  .byte N_E4,16
  .byte N_B3,16
  .byte N_E4,16
  .byte N_C4,16
  .byte N_F4,16
  .byte N_C4,16
  .byte N_F4,16
  .byte N_B3,16
  .byte N_E4,16
  .byte N_G4,16
  .byte N_E4,16
  .byte N_B3,32
  .byte N_B3,32
  .byte N_B3,16
  .byte N_D4,16
  .byte N_B3,16
  .byte N_D4,16
  .byte N_C4,16
  .byte N_E4,16
  .byte N_C4,16
  .byte N_E4,16
  .byte N_Gs3,16
  .byte N_C4,16
  .byte N_Gs3,16
  .byte N_C4,16
  .byte N_B3,32
  .byte CTL_REST,32
  .byte CTL_LOOP
  .word song_battle_p2

; ---- BOSS ----
song_boss_p1:
  .byte N_D4,20
  .byte N_D4,20
  .byte N_Ds4,20
  .byte N_D4,20
  .byte N_As3,20
  .byte N_As3,20
  .byte N_A3,40
  .byte N_D4,20
  .byte N_D4,20
  .byte N_Ds4,20
  .byte N_D4,20
  .byte N_G4,20
  .byte N_Fs4,20
  .byte N_F4,40
  .byte N_D4,20
  .byte N_C4,20
  .byte N_As3,20
  .byte N_A3,20
  .byte N_G3,20
  .byte N_G3,20
  .byte N_Gs3,40
  .byte N_A3,20
  .byte N_A3,20
  .byte N_As3,20
  .byte N_D4,20
  .byte N_D4,40
  .byte CTL_REST,40
  .byte CTL_LOOP
  .word song_boss_p1
song_boss_tr:
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_D2,10
  .byte N_As2,10
  .byte N_As2,10
  .byte N_As2,10
  .byte N_As2,10
  .byte N_As2,10
  .byte N_As2,10
  .byte N_As2,10
  .byte N_As2,10
  .byte N_As2,10
  .byte N_As2,10
  .byte N_As2,10
  .byte N_As2,10
  .byte N_As2,10
  .byte N_As2,10
  .byte N_As2,10
  .byte N_As2,10
  .byte N_A2,10
  .byte N_A2,10
  .byte N_A2,10
  .byte N_A2,10
  .byte N_A2,10
  .byte N_A2,10
  .byte N_A2,10
  .byte N_A2,10
  .byte N_A2,10
  .byte N_A2,10
  .byte N_A2,10
  .byte N_A2,10
  .byte N_A2,10
  .byte N_A2,10
  .byte N_A2,10
  .byte N_A2,10
  .byte CTL_LOOP
  .word song_boss_tr
song_boss_p2:
  .byte CTL_REST,40
  .byte N_D3,40
  .byte CTL_REST,40
  .byte N_D3,40
  .byte CTL_REST,40
  .byte N_F3,40
  .byte CTL_REST,40
  .byte N_Gs3,40
  .byte CTL_REST,40
  .byte N_A3,40
  .byte CTL_REST,40
  .byte N_A3,40
  .byte CTL_REST,40
  .byte N_D3,40
  .byte CTL_REST,40
  .byte N_D3,40
  .byte CTL_LOOP
  .word song_boss_p2

; ---- END ----
song_end_p1:
  .byte N_C4,32
  .byte N_E4,32
  .byte N_G4,32
  .byte N_E4,32
  .byte N_F4,32
  .byte N_A4,32
  .byte N_G4,64
  .byte N_E4,32
  .byte N_G4,32
  .byte N_C5,32
  .byte N_B4,32
  .byte N_A4,64
  .byte N_G4,64
  .byte N_F4,32
  .byte N_A4,32
  .byte N_G4,32
  .byte N_F4,32
  .byte N_E4,32
  .byte N_D4,32
  .byte N_C4,64
  .byte N_D4,32
  .byte N_F4,32
  .byte N_E4,32
  .byte N_G4,32
  .byte N_C5,64
  .byte CTL_REST,64
  .byte CTL_LOOP
  .word song_end_p1
song_end_tr:
  .byte N_C3,64
  .byte N_C3,64
  .byte N_F2,64
  .byte N_F2,64
  .byte N_G2,64
  .byte N_G2,64
  .byte N_C3,64
  .byte N_C3,64
  .byte N_F2,64
  .byte N_F2,64
  .byte N_G2,64
  .byte N_G2,64
  .byte N_A2,64
  .byte N_D3,64
  .byte N_G2,64
  .byte N_C3,64
  .byte CTL_LOOP
  .word song_end_tr
song_end_p2:
  .byte N_E3,64
  .byte N_G3,64
  .byte N_A3,64
  .byte N_C4,64
  .byte N_B3,64
  .byte N_D4,64
  .byte N_G3,64
  .byte N_C4,64
  .byte N_A3,64
  .byte N_C4,64
  .byte N_B3,64
  .byte N_D4,64
  .byte N_C4,64
  .byte N_F3,64
  .byte N_B3,64
  .byte N_G3,64
  .byte CTL_LOOP
  .word song_end_p2

; ---- SAFE ----
song_safe_p1:
  .byte N_E4,80
  .byte N_G4,80
  .byte N_F4,80
  .byte N_D4,80
  .byte N_C4,80
  .byte N_E4,80
  .byte N_G4,80
  .byte CTL_REST,80
  .byte N_A4,80
  .byte N_G4,80
  .byte N_F4,80
  .byte N_E4,80
  .byte N_D4,80
  .byte N_F4,80
  .byte N_E4,80
  .byte CTL_REST,80
  .byte CTL_LOOP
  .word song_safe_p1
song_safe_tr:
  .byte N_C3,160
  .byte N_F2,160
  .byte N_G2,160
  .byte N_C3,160
  .byte N_A2,160
  .byte N_F2,160
  .byte N_G2,160
  .byte N_C3,160
  .byte CTL_LOOP
  .word song_safe_tr
song_safe_p2:
  .byte N_C4,160
  .byte CTL_REST,160
  .byte N_A3,160
  .byte CTL_REST,160
  .byte N_G3,160
  .byte CTL_REST,160
  .byte N_E3,160
  .byte CTL_REST,160
  .byte CTL_LOOP
  .word song_safe_p2

