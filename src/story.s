; ============================================================================
; story.s — dialog engine, NPC/terminal handlers, vendor, field menu, ending
; ============================================================================
.include "defs.inc"
.include "gen/tiles.inc"

.importzp p0, p1, p2, pad, pad_new, scrollX, scrollXhi, scrollY
.importzp uarg, num_lo, num_hi
.import wait_nmi, read_pad, ppu_off, ppu_on, clear_nt, load_palette
.import win_box, win_print, win_putc, win_clearline, print_num, restore_rows_ui, OAM
.import menu_run
.importzp mn_col, mn_row, mn_step, mn_count, mn_cur
.import sfx_play, music_play
.importzp lvl, xp, credits, hp, maxhp, en, maxen, weap, armr, chip, skills, sflags
.import items, calc_atk, calc_def, apply_level
.import weap_atk, armr_def, weap_name_l, weap_name_h, armr_name_l, armr_name_h
.import chip_name_l, chip_name_h, item_name_l, item_name_h
.import tech_name_l, tech_name_h, tech_lvl
.export do_dialog, field_menu, run_ending

.segment "ZEROPAGE"
dcol:   .res 1
drow:   .res 1
sarg:   .res 2
di:     .res 1
dcnt:   .res 1
price:  .res 2
tmpb:   .res 1

.segment "CODE"

; ============================ message box ============================
; open bottom message box (rows 20-28)
msg_open:
  lda #1
  sta uarg+0
  lda #20
  sta uarg+1
  lda #30
  sta uarg+2
  lda #9
  sta uarg+3
  jsr win_box
  lda #3
  sta dcol
  lda #21
  sta drow
  rts

msg_close:
  jsr wait_a
  lda #20
  ldx #9
  jmp restore_rows_ui

; print string sarg with control codes into the message box
msg_puts:
  ldy #0
@l:
  lda (sarg),y
  cmp #TXT_END
  beq @done
  cmp #TXT_NL
  beq @nl
  cmp #TXT_PAGE
  beq @page
  ; normal char
  pha
  ldx dcol
  ldy drow
  pla
  jsr win_putc
  inc dcol
  ; reload y
  jsr next_char
  jmp @l
@nl:
  jsr msg_newline
  jsr next_char
  jmp @l
@page:
  jsr msg_pageflush
  jsr next_char
  jmp @l
@done:
  rts

next_char:
  inc sarg
  bne :+
  inc sarg+1
:
  ldy #0
  rts

msg_newline:
  lda #3
  sta dcol
  inc drow
  inc drow
  lda drow
  cmp #28
  bcc @ok
  jsr msg_pagewait
@ok:
  rts

msg_pageflush:
  jsr msg_pagewait
  rts

msg_pagewait:
  jsr wait_a
  lda #21
  sta drow
@l:
  lda #28
  ldx #2
  ldy drow
  jsr win_clearline
  jsr wait_nmi
  inc drow
  lda drow
  cmp #28
  bne @l
  lda #3
  sta dcol
  lda #21
  sta drow
  rts

; say: sarg preset -> open, print, close
say:
  jsr msg_open
  jsr msg_puts
  jmp msg_close

wait_a:
  jsr wait_nmi
  jsr read_pad
@l:
  jsr wait_nmi
  jsr read_pad
  lda pad_new
  and #BTN_A
  bne @done
  lda pad_new
  and #BTN_B
  beq @l
@done:
  lda #SFX_ITEM
  jmp sfx_play

; set sarg from A=lo, X=hi
setmsg:
  sta sarg
  stx sarg+1
  rts

; ============================ dialog dispatch ============================
; A = dialog id ($FF terminal)
do_dialog:
  cmp #DLG_TERMINAL
  bne :+
  jmp h_terminal
:
  asl
  tax
  lda dlg_tbl,x
  sta p2
  lda dlg_tbl+1,x
  sta p2+1
  jmp (p2)

h_wake:
  lda #<t_wake
  ldx #>t_wake
  jsr setmsg
  lda sflags
  ora #SF_WOKE
  sta sflags
  jmp say

h_engineer:
  lda #<t_engineer
  ldx #>t_engineer
  jsr setmsg
  jmp say

h_medic:
  lda #<t_medic
  ldx #>t_medic
  jsr setmsg
  jmp say

h_survivor:
  lda #<t_survivor
  ldx #>t_survivor
  jsr setmsg
  jmp say

h_lost:
  lda #<t_lost
  ldx #>t_lost
  jsr setmsg
  jmp say

h_terminal:
  lda #<t_terminal
  ldx #>t_terminal
  jsr setmsg
  jmp say

; ---- repair bay: restore HP/EN free ----
h_repair:
  lda #<t_repair
  ldx #>t_repair
  jsr setmsg
  jsr msg_open
  jsr msg_puts
  lda maxhp
  sta hp
  lda maxen
  sta en
  lda #SFX_HEAL
  jsr sfx_play
  jmp msg_close

; ---- vendor: buy weapons/armor/items ----
h_vendor:
  lda #<t_vendor
  ldx #>t_vendor
  jsr setmsg
  jsr say
@loop:
  jsr vendor_menu
  cmp #$FF
  beq @done
  jsr vendor_buy
  jmp @loop
@done:
  rts

vendor_menu:
  ; window listing wares + prices
  lda #4
  sta uarg+0
  lda #4
  sta uarg+1
  lda #24
  sta uarg+2
  lda #14
  sta uarg+3
  jsr win_box
  lda #0
  sta di
@l:
  lda di
  asl
  clc
  adc #6
  tay                            ; row 6,8,10,12,14,16
  ldx di
  lda ware_name_l,x
  sta p0
  lda ware_name_h,x
  sta p0+1
  ldx #6
  jsr win_print
  ldx di
  lda ware_price,x
  sta num_lo
  lda #0
  sta num_hi
  lda di
  asl
  clc
  adc #6
  tay
  ldx #22
  jsr print_num
  inc di
  lda di
  cmp #6
  bne @l
  ; credits line
  lda #<t_cred
  sta p0
  lda #>t_cred
  sta p0+1
  ldx #6
  ldy #17
  jsr win_print
  lda credits
  sta num_lo
  lda credits+1
  sta num_hi
  ldx #13
  ldy #17
  jsr print_num
  lda #6
  sta mn_col
  lda #6
  sta mn_row
  lda #2
  sta mn_step
  lda #6
  sta mn_count
  lda #0
  sta mn_cur
  jsr menu_run
  rts

; A = ware index -> attempt purchase
vendor_buy:
  tax
  lda ware_price,x
  sta price
  lda #0
  sta price+1
  ; afford?
  lda credits+1
  bne @afford
  lda credits
  cmp price
  bcs @afford
  lda #<t_poor
  ldx #>t_poor
  jsr setmsg
  jmp say
@afford:
  ; deduct
  lda credits
  sec
  sbc price
  sta credits
  bcs :+
  dec credits+1
:
  lda #SFX_ITEM
  jsr sfx_play
  ; apply ware effect
  txa
  pha
  cmp #2
  bcc @weap                      ; 0,1 = weapons
  cmp #4
  bcc @armr                      ; 2,3 = armor
  ; 4,5 = items (repair cell, power cell)
  sec
  sbc #4
  tax
  inc items,x
  jmp @ok
@weap:
  ; ware 0 -> weap 2 (arc cutter) ; ware 1 -> weap 3 (rail lance)
  clc
  adc #2
  sta weap
  jmp @ok
@armr:
  sec
  sbc #2                         ; 2->0? map ware2->armr1, ware3->armr2
  clc
  adc #1
  sta armr
@ok:
  pla
  lda #<t_bought
  ldx #>t_bought
  jsr setmsg
  jmp say

; ============================ field menu ============================
field_menu:
  lda #0
  sta uarg+0
  lda #0
  sta uarg+1
  lda #12
  sta uarg+2
  lda #12
  sta uarg+3
  jsr win_box
  lda #0
  sta di
@l:
  lda di
  asl
  clc
  adc #2
  tay
  ldx di
  lda fm_name_l,x
  sta p0
  lda fm_name_h,x
  sta p0+1
  ldx #2
  jsr win_print
  inc di
  lda di
  cmp #4
  bne @l
  lda #1
  sta mn_col
  lda #2
  sta mn_row
  lda #2
  sta mn_step
  lda #4
  sta mn_count
  lda #0
  sta mn_cur
  jsr menu_run
  pha
  ; restore the menu area (rows 0-11)
  lda #0
  ldx #12
  jsr restore_rows_ui
  pla
  cmp #0
  bne :+
  jmp fm_status
:
  cmp #1
  bne :+
  jmp fm_items
:
  cmp #2
  bne :+
  jmp fm_equip
:
  cmp #3
  bne :+
  jmp fm_skills
:
  rts

fm_status:
  jsr msg_open
  lda #<t_st_lv
  sta p0
  lda #>t_st_lv
  sta p0+1
  ldx #3
  ldy #21
  jsr win_print
  lda lvl
  sta num_lo
  lda #0
  sta num_hi
  ldx #6
  ldy #21
  jsr print_num
  lda #<t_st_hp
  sta p0
  lda #>t_st_hp
  sta p0+1
  ldx #12
  ldy #21
  jsr win_print
  lda hp
  sta num_lo
  lda #0
  sta num_hi
  ldx #15
  ldy #21
  jsr print_num
  lda #<t_st_en
  sta p0
  lda #>t_st_en
  sta p0+1
  ldx #21
  ldy #21
  jsr win_print
  lda en
  sta num_lo
  lda #0
  sta num_hi
  ldx #24
  ldy #21
  jsr print_num
  lda #<t_st_atk
  sta p0
  lda #>t_st_atk
  sta p0+1
  ldx #3
  ldy #23
  jsr win_print
  jsr calc_atk
  sta num_lo
  lda #0
  sta num_hi
  ldx #7
  ldy #23
  jsr print_num
  lda #<t_st_def
  sta p0
  lda #>t_st_def
  sta p0+1
  ldx #14
  ldy #23
  jsr win_print
  jsr calc_def
  sta num_lo
  lda #0
  sta num_hi
  ldx #18
  ldy #23
  jsr print_num
  lda #<t_st_cr
  sta p0
  lda #>t_st_cr
  sta p0+1
  ldx #3
  ldy #25
  jsr win_print
  lda credits
  sta num_lo
  lda credits+1
  sta num_hi
  ldx #11
  ldy #25
  jsr print_num
  ; weapon/armor names
  ldx weap
  lda weap_name_l,x
  sta p0
  lda weap_name_h,x
  sta p0+1
  ldx #3
  ldy #27
  jsr win_print
  jmp msg_close

fm_items:
  jsr msg_open
  lda #0
  sta di
@l:
  lda di
  asl
  clc
  adc #21
  tay
  ldx di
  lda item_name_l,x
  sta p0
  lda item_name_h,x
  sta p0+1
  ldx #3
  jsr win_print
  ldx di
  lda items,x
  sta num_lo
  lda #0
  sta num_hi
  lda di
  asl
  clc
  adc #21
  tay
  ldx #16
  jsr print_num
  inc di
  lda di
  cmp #4
  bne @l
  jmp msg_close

fm_equip:
  ; simple: cycle weapon with A? show current, cycle armor with B? -> just show
  jsr msg_open
  lda #<t_eq_w
  sta p0
  lda #>t_eq_w
  sta p0+1
  ldx #3
  ldy #21
  jsr win_print
  ldx weap
  lda weap_name_l,x
  sta p0
  lda weap_name_h,x
  sta p0+1
  ldx #9
  ldy #21
  jsr win_print
  lda #<t_eq_a
  sta p0
  lda #>t_eq_a
  sta p0+1
  ldx #3
  ldy #23
  jsr win_print
  ldx armr
  lda armr_name_l,x
  sta p0
  lda armr_name_h,x
  sta p0+1
  ldx #9
  ldy #23
  jsr win_print
  lda #<t_eq_c
  sta p0
  lda #>t_eq_c
  sta p0+1
  ldx #3
  ldy #25
  jsr win_print
  ldx chip
  lda chip_name_l,x
  sta p0
  lda chip_name_h,x
  sta p0+1
  ldx #9
  ldy #25
  jsr win_print
  jmp msg_close

fm_skills:
  jsr msg_open
  lda #0
  sta di
  lda #21
  sta drow
@l:
  ldx di
  lda skills
  and pow2b,x
  beq @sk
  ldx di
  lda tech_name_l,x
  sta p0
  lda tech_name_h,x
  sta p0+1
  ldx #3
  ldy drow
  jsr win_print
  inc drow
  inc drow
@sk:
  inc di
  lda di
  cmp #5
  bne @l
  jmp msg_close

; ============================ ending ============================
run_ending:
  jsr ppu_off
  lda #0
  sta scrollX
  sta scrollXhi
  sta scrollY
  ; hide all sprites
  ldx #0
  lda #$F0
@oc:
  sta OAM,x
  inx
  bne @oc
  lda #$20
  jsr clear_nt
  lda #$24
  jsr clear_nt
  lda #<end_pal
  sta p0
  lda #>end_pal
  sta p0+1
  jsr load_palette
  lda #MUS_END
  jsr music_play
  jsr ppu_on
  lda #0
  sta di
@l:
  ldx di
  lda end_lines_l,x
  sta p0
  lda end_lines_h,x
  sta p0+1
  ldx di
  lda end_row,x
  tay
  lda end_col,x
  tax
  jsr win_print
  inc di
  lda di
  cmp #END_N
  bne @l
@forever:
  jsr wait_nmi
  jmp @forever

.segment "RODATA"
pow2b: .byte 1,2,4,8,16
dlg_tbl:
  .word h_wake, h_vendor, h_repair, h_engineer, h_medic, h_survivor, h_lost

; vendor wares: 0,1 weapons ; 2,3 armor ; 4,5 items
ware_name_l: .byte <w0,<w1,<w2,<w3,<w4,<w5
ware_name_h: .byte >w0,>w1,>w2,>w3,>w4,>w5
ware_price:  .byte 60, 140, 50, 130, 12, 16
w0: .byte "ARC CUTTER", TXT_END
w1: .byte "RAIL LANCE", TXT_END
w2: .byte "PLATE WEAVE", TXT_END
w3: .byte "AEGIS SHELL", TXT_END
w4: .byte "REPAIR CELL", TXT_END
w5: .byte "POWER CELL", TXT_END

fm_name_l: .byte <fm0,<fm1,<fm2,<fm3
fm_name_h: .byte >fm0,>fm1,>fm2,>fm3
fm0: .byte "STATUS", TXT_END
fm1: .byte "ITEMS", TXT_END
fm2: .byte "EQUIP", TXT_END
fm3: .byte "SKILLS", TXT_END

t_cred:  .byte "CR", TXT_END
t_poor:  .byte "INSUFFICIENT CREDITS.", TXT_END
t_bought:.byte "TRANSACTION COMPLETE.", TXT_END
t_st_lv: .byte "LV", TXT_END
t_st_hp: .byte "HP", TXT_END
t_st_en: .byte "EN", TXT_END
t_st_atk:.byte "ATK", TXT_END
t_st_def:.byte "DEF", TXT_END
t_st_cr: .byte "CREDITS", TXT_END
t_eq_w:  .byte "WEP", TXT_END
t_eq_a:  .byte "ARM", TXT_END
t_eq_c:  .byte "CHP", TXT_END

t_wake:
  .byte "SYSTEM REBOOT. I AM AXIOM,", TXT_NL
  .byte "CARETAKER OF THE EREBUS.", TXT_NL
  .byte "900 YEARS SINCE CONTACT.", TXT_PAGE
  .byte "A SIGNAL WOKE ME. THE CREW", TXT_NL
  .byte "SLEEP IN FAILING PODS. THE", TXT_NL
  .byte "BLOOM HAS TAKEN THE DECKS.", TXT_PAGE
  .byte "I MUST REACH THE REACTOR", TXT_NL
  .byte "AND THE WARDEN THAT SILENCED", TXT_NL
  .byte "THIS SHIP. GO EAST, AXIOM.", TXT_END
t_engineer:
  .byte "I KEPT ONE DECK BREATHING.", TXT_NL
  .byte "THE WARDEN AI SEALED THE", TXT_NL
  .byte "REACTOR AND CALLS IT MERCY.", TXT_PAGE
  .byte "UPGRADE AT THE VENDOR. THE", TXT_NL
  .byte "REPAIR BAY WILL MEND YOU.", TXT_END
t_medic:
  .byte "SIXTY SLEEPERS LEFT ALIVE.", TXT_NL
  .byte "IF THE SUN-CORE STAYS DARK", TXT_NL
  .byte "THEY WILL NOT WAKE.", TXT_END
t_survivor:
  .byte "THE BLOOM WAS OUR GARDEN", TXT_NL
  .byte "ONCE. NOW IT DREAMS AND", TXT_NL
  .byte "SPREADS. DO NOT LINGER HERE.", TXT_END
t_lost:
  .byte "STARS. REAL STARS OUT THERE.", TXT_NL
  .byte "I FORGOT THEY WERE SO COLD.", TXT_END
t_terminal:
  .byte "SHIP LOG, DAY 41: THE WARDEN", TXT_NL
  .byte "TOOK THE CORE OFFLINE TO", TXT_NL
  .byte "STOP THE BLOOM. IT NEVER", TXT_PAGE
  .byte "STOPPED. IT ONLY BOUGHT", TXT_NL
  .byte "SILENCE. - CAPT. VExx", TXT_END
t_repair:
  .byte "REPAIR BAY ONLINE. CHASSIS", TXT_NL
  .byte "RESTORED. ENERGY TOPPED OFF.", TXT_END
t_vendor:
  .byte "FABRICATOR UNIT READY.", TXT_NL
  .byte "TRADE SALVAGE FOR GEAR.", TXT_END

END_N = 6
end_lines_l: .byte <e0,<e1,<e2,<e3,<e4,<e5
end_lines_h: .byte >e0,>e1,>e2,>e3,>e4,>e5
end_col: .byte 4, 3, 6, 4, 7, 11
end_row: .byte 6, 9, 12, 15, 19, 23
e0: .byte "THE CORE IGNITES.", TXT_END
e1: .byte "LIGHT FLOODS THE DEAD DECKS.", TXT_END
e2: .byte "SLEEPERS STIR IN THEIR PODS", TXT_END
e3: .byte "TOWARD A WARM NEW DAWN.", TXT_END
e4: .byte "AXIOM KEEPS THE VIGIL.", TXT_END
e5: .byte "E R E B U S", TXT_END
end_pal:
  .byte $0F,$06,$28,$30, $0F,$0C,$1C,$2C, $0F,$16,$27,$37, $0F,$1A,$2A,$3A
  .byte $0F,$0F,$10,$2C, $0F,$16,$27,$37, $0F,$13,$23,$29, $0F,$06,$28,$30
.segment "CODE"
