; ============================================================================
; data.s — text, enemies, level curves, shop stock
; ============================================================================
.segment "RODATA"

; ------------------------------------------------------------------- levels
;            L1  L2  L3  L4  L5  L6  L7  L8  L9 L10 L11 L12
tbl_str: .byte  5,  7,  9, 12, 15, 19, 24, 30, 37, 45, 54, 64
tbl_agi: .byte  4,  5,  7,  9, 11, 14, 17, 21, 26, 32, 39, 46
tbl_hp:  .byte 16, 22, 27, 34, 42, 52, 62, 74, 88,104,120,138
tbl_mp:  .byte  0,  0,  6, 12, 18, 24, 30, 38, 48, 60, 74, 90
; total XP required to reach level 2, 3, ...
next_xp: .word 8, 25, 60, 120, 220, 400, 680, 1050, 1550, 2200, 3000

weap_atk: .byte 2, 7, 14
armr_def: .byte 1, 10

weap_txt_lo: .byte <txt_w0, <txt_w1, <txt_w2
weap_txt_hi: .byte >txt_w0, >txt_w1, >txt_w2
armr_txt_lo: .byte <txt_a0, <txt_a1
armr_txt_hi: .byte >txt_a0, >txt_a1
txt_w0: .byte "OAK STICK", TXT_END
txt_w1: .byte "BRONZE BLADE", TXT_END
txt_w2: .byte "FLAME BRAND", TXT_END
txt_a0: .byte "CLOTH GARB", TXT_END
txt_a1: .byte "EMBER MAIL", TXT_END

; ------------------------------------------------------------------ enemies
; name(2) hp atk def xp gold spell% fire gfx(2) w h pal(3) = 16 bytes
enemy_tbl:
  .word en_slime
  .byte 8, 6, 3, 2, 3, 0, 0
  .word _GFX_SLIME
  .byte GFX_SLIME_W, GFX_SLIME_H, $00, $10, $30
  .word en_rat
  .byte 10, 8, 4, 3, 5, 0, 0
  .word _GFX_RAT
  .byte GFX_RAT_W, GFX_RAT_H, $07, $17, $30
  .word en_wolf
  .byte 16, 12, 6, 6, 9, 0, 0
  .word _GFX_WOLF
  .byte GFX_WOLF_W, GFX_WOLF_H, $01, $11, $30
  .word en_bat
  .byte 13, 11, 4, 5, 7, 0, 0
  .word _GFX_BAT
  .byte GFX_BAT_W, GFX_BAT_H, $03, $13, $30
  .word en_wisp
  .byte 18, 15, 8, 10, 14, 56, 8
  .word _GFX_WISP
  .byte GFX_WISP_W, GFX_WISP_H, $16, $27, $30
  .word en_golem
  .byte 30, 20, 14, 18, 22, 0, 0
  .word _GFX_GOLEM
  .byte GFX_GOLEM_W, GFX_GOLEM_H, $07, $27, $30
  .word en_knight
  .byte 42, 26, 16, 30, 38, 0, 0
  .word _GFX_KNIGHT
  .byte GFX_KNIGHT_W, GFX_KNIGHT_H, $05, $15, $30
  .word en_king
  .byte 110, 32, 18, 120, 0, 88, 14
  .word _GFX_KING
  .byte GFX_KING_W, GFX_KING_H, $04, $14, $27

en_slime:  .byte "THE ASH SLIME", TXT_END
en_rat:    .byte "THE CINDER RAT", TXT_END
en_wolf:   .byte "THE SOOT WOLF", TXT_END
en_bat:    .byte "THE EMBER BAT", TXT_END
en_wisp:   .byte "THE FLAME WISP", TXT_END
en_golem:  .byte "THE CINDER GOLEM", TXT_END
en_knight: .byte "THE ASH KNIGHT", TXT_END
en_king:   .byte "THE ASH KING", TXT_END

; --------------------------------------------------------------------- shop
shop_price: .byte 8, 40, 150, 120, 60
shop_kind:  .byte 0, 1, 1, 2, 3          ; herb / weapon / weapon / armor / key
shop_val:   .byte 0, 1, 2, 1, 0
shop_txt_lo: .byte <sh0, <sh1, <sh2, <sh3, <sh4
shop_txt_hi: .byte >sh0, >sh1, >sh2, >sh3, >sh4
sh0: .byte "HERB          8G", TXT_END
sh1: .byte "BRONZE BLADE 40G", TXT_END
sh2: .byte "FLAME BRAND 150G", TXT_END
sh3: .byte "EMBER MAIL  120G", TXT_END
sh4: .byte "EMBER KEY    60G", TXT_END

; -------------------------------------------------------------------- title
txt_title1: .byte "E M B E R F A L L", TXT_END
txt_title2: .byte "THE SUN IS GOING OUT", TXT_END
txt_title3: .byte "PRESS START", TXT_END
txt_title4: .byte "MMXXVI EMBER WORKS", TXT_END

; ------------------------------------------------------------------ dialogue
txt_elder:
  .byte "SPARK OF TINDERHOLM. THE", TXT_NL
  .byte "SUN GUTTERS LIKE A SPENT", TXT_NL
  .byte "WICK. SOON ALL IS ASH.", TXT_PAGE
  .byte "LONG AGO THE ASH KING STOLE", TXT_NL
  .byte "THE SUNHEART FROM THE FORGE", TXT_NL
  .byte "UNDER MOUNT CINDER.", TXT_PAGE
  .byte "TAKE MY LAST GOLD. GO NORTH", TXT_NL
  .byte "THEN EAST TO THE MOUNTAIN,", TXT_NL
  .byte "AND BRING BACK THE DAWN.", TXT_END
txt_guard:
  .byte "THE DEEP DOOR OF THE CAVE", TXT_NL
  .byte "IS SEALED FAST.", TXT_PAGE
  .byte "ONLY THE EMBER KEY OPENS", TXT_NL
  .byte "IT. THE TRADER SELLS ONE,", TXT_NL
  .byte "FOR A PRICE.", TXT_END
txt_woman:
  .byte "EMBERS FALL LIKE GREY SNOW.", TXT_NL
  .byte "MY GARDEN SLEEPS AND WILL", TXT_NL
  .byte "NOT WAKE.", TXT_PAGE
  .byte "A SAGE KEEPS THE LAKE SHRINE", TXT_NL
  .byte "SOUTHWEST OF HERE. HE MENDS", TXT_NL
  .byte "WEARY TRAVELERS, FREE.", TXT_END
txt_man:
  .byte "WOLVES PROWL THE NORTH ROAD.", TXT_PAGE
  .byte "TRAIN ON SLIMES IN THE", TXT_NL
  .byte "MEADOWS FIRST, OR THE ASH", TXT_NL
  .byte "WILL HAVE YOUR BONES.", TXT_END
txt_sage1:
  .byte "BRAVE SPARK. THE LAST LIGHT", TXT_NL
  .byte "OF THE WORLD RIDES WITH YOU.", TXT_PAGE
  .byte "BE WHOLE AGAIN.", TXT_END
txt_sage2:
  .byte TXT_PAGE
  .byte "THE ASH KING WIELDS FIRE.", TXT_NL
  .byte "FACE HIM PAST LEVEL SEVEN,", TXT_NL
  .byte "OR NOT AT ALL.", TXT_END
txt_shop_hi:
  .byte "WELCOME, SPARKKEEPER.", TXT_NL
  .byte "TAKE WHAT YOU NEED.", TXT_END
txt_shop_bye:   .byte "COME AGAIN. WALK IN LIGHT.", TXT_END
txt_shop_poor:  .byte "YOUR POUCH IS TOO LIGHT.", TXT_END
txt_shop_thanks:.byte "THANK YOU KINDLY!", TXT_END
txt_shop_have:  .byte "YOU CARRY FINER ALREADY.", TXT_END
txt_shop_full:  .byte "YOU CAN CARRY NO MORE HERBS.", TXT_END
txt_inn_q:
  .byte "A WARM BED IS 6 GOLD.", TXT_NL
  .byte "WILL YOU REST?", TXT_END
txt_inn_no:     .byte "SAFE TRAVELS, THEN.", TXT_END
txt_inn_poor:   .byte "COME BACK WITH 6 GOLD.", TXT_END
txt_inn_morning:
  .byte "GOOD MORNING! THE GREY IS", TXT_NL
  .byte "THIN TODAY. MAY EMBERS", TXT_NL
  .byte "LIGHT YOUR ROAD.", TXT_END
txt_yes: .byte "YES", TXT_END
txt_no:  .byte "NO", TXT_END

txt_nothing:     .byte "THERE IS NOTHING THERE.", TXT_END
txt_chest1:      .byte "YOU FOUND ", TXT_END
txt_chest2:      .byte " GOLD!", TXT_END
txt_door_locked:
  .byte "SEALED FAST. A KEYHOLE", TXT_NL
  .byte "GLOWS FAINTLY.", TXT_END
txt_door_open:
  .byte "THE EMBER KEY TURNS WHITE", TXT_NL
  .byte "HOT. THE SEAL BREAKS!", TXT_END

; ---------------------------------------------------------------- field menu
txt_m_status: .byte "STATUS", TXT_END
txt_m_heal:   .byte "HEAL", TXT_END
txt_m_herb:   .byte "HERB", TXT_END
txt_s_lv:     .byte "LV ", TXT_END
txt_s_xp:     .byte "  XP ", TXT_END
txt_s_hp:     .byte "HP ", TXT_END
txt_s_mp:     .byte "  MP ", TXT_END
txt_s_gold:   .byte "GOLD ", TXT_END
txt_s_herbs:  .byte "  HERBS ", TXT_END
txt_s_atk:    .byte "ATK ", TXT_END
txt_s_def:    .byte "  DEF ", TXT_END
txt_s_key:    .byte ", EMBER KEY", TXT_END
txt_nospell:  .byte "YOU KNOW NO SPELLS YET.", TXT_END
txt_nomp:     .byte "NOT ENOUGH MP.", TXT_END
txt_healed:   .byte "HEAL KNITS YOUR WOUNDS.", TXT_END
txt_noherb:   .byte "NO HERBS LEFT.", TXT_END
txt_herbed:   .byte "THE HERB WARMS YOU.", TXT_END

; -------------------------------------------------------------------- battle
txt_c_fight:  .byte "FIGHT", TXT_END
txt_c_spell:  .byte "SPELL", TXT_END
txt_c_item:   .byte "ITEM", TXT_END
txt_c_run:    .byte "RUN", TXT_END
txt_c_heal:   .byte "HEAL", TXT_END
txt_c_scorch: .byte "SCORCH", TXT_END
txt_c_storm:  .byte "STORM", TXT_END

txt_b_near:     .byte " DRAWS NEAR!", TXT_END
txt_b_kingrise:
  .byte "THE ASH KING RISES FROM", TXT_NL
  .byte "HIS COLD THRONE!", TXT_END
txt_b_youatk:   .byte "YOU ATTACK!", TXT_END
txt_b_takes:    .byte " TAKES ", TXT_END
txt_b_dmg:      .byte " DAMAGE.", TXT_END
txt_b_defeated: .byte " IS DEFEATED!", TXT_END
txt_b_attacks:  .byte " ATTACKS!", TXT_END
txt_b_fire:     .byte " BREATHES FIRE!", TXT_END
txt_b_youtake:  .byte "YOU TAKE ", TXT_END
txt_b_flee:     .byte "YOU TURN TO FLEE!", TXT_END
txt_b_fled:     .byte "YOU ESCAPED.", TXT_END
txt_b_blocked:  .byte "THE WAY IS BLOCKED!", TXT_END
txt_b_victory:  .byte "VICTORY! YOU GAIN ", TXT_END
txt_b_xpand:    .byte " XP", TXT_NL, "AND ", TXT_END
txt_b_goldend:  .byte " GOLD.", TXT_END
txt_b_level:
  .byte "COURAGE SURGES!", TXT_NL
  .byte "YOU ARE NOW LEVEL ", TXT_END
txt_b_unknown:  .byte "YOU DO NOT KNOW THAT YET.", TXT_END
txt_l_heal:     .byte "YOU LEARNED HEAL!", TXT_END
txt_l_scorch:   .byte "YOU LEARNED SCORCH!", TXT_END
txt_l_storm:    .byte "YOU LEARNED EMBERSTORM!", TXT_END
txt_b_storm:    .byte "EMBERSTORM HOWLS AND BURNS!", TXT_END
txt_b_scorch:   .byte "SCORCH SEARS THE FOE!", TXT_END
txt_b_heal:     .byte "HEAL KNITS YOUR WOUNDS.", TXT_END
txt_b_fallen:   .byte "YOU HAVE FALLEN...", TXT_END
txt_revive:
  .byte "THE ELDER'S HANDS PULL YOU", TXT_NL
  .byte "BACK FROM THE GREY. HALF", TXT_NL
  .byte "YOUR GOLD PAID THE ASH.", TXT_END
txt_boss:
  .byte "A VOICE LIKE COLD IRON:", TXT_PAGE
  .byte "SO. THE LAST SPARK CRAWLS", TXT_NL
  .byte "TO MY FORGE TO DIE.", TXT_PAGE
  .byte "COME, LITTLE LIGHT. I WILL", TXT_NL
  .byte "SNUFF YOU AS I SNUFFED", TXT_NL
  .byte "THE SUN.", TXT_END

; -------------------------------------------------------------------- ending
stat_labels: .byte "LV ", "HP ", "MP "

END_NLINES = 8
end_lines:
  .word e_l0, e_l1, e_l2, e_l3, e_l4, e_l5, e_l6, e_l7
end_cols: .byte 3, 2, 4, 7, 3, 4, 7, 12
end_rows: .byte 6, 9, 11, 13, 16, 18, 22, 25
e_l0: .byte "THE SUNHEART SETTLES HOME.", TXT_END
e_l1: .byte "THE FORGE ROARS. FAR ABOVE,", TXT_END
e_l2: .byte "DAWN SPILLS GOLD ACROSS", TXT_END
e_l3: .byte "THE SLEEPING ASH.", TXT_END
e_l4: .byte "TINDERHOLM WAKES TO COLOR.", TXT_END
e_l5: .byte "THE LAST SPARK IS HOME.", TXT_END
e_l6: .byte "E M B E R F A L L", TXT_END
e_l7: .byte "THE END", TXT_END
.segment "CODE"
