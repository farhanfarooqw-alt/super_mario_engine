; ============================================================
; data.inc  -  shared variables.   RULE: only the OWNER writes,
; everybody else only reads.
; ============================================================

; ---- Engine (Person 1 writes) ----
game_state      db ST_TITLE
fb_seg          dw 0                ; frame buffer segment (INT 21h AH=48h)
tick_count      dw 0                ; incremented by timer ISR
last_tick       dw 0
old_int09       dd 0                ; saved keyboard vector (offset:segment)
old_int08       dd 0                ; saved timer vector
key_table       times 128 db 0      ; 1 = key held, index = scan code
clock_secs      dw LEVEL_TIME
clock_last      dw 0                ; tick_count value at the last clock step
clock_run       db 0                ; 1 = clock counts, 0 = frozen
chain_acc       dw 0                ; decides when to chain the old timer handler

; ---- Camera (Person 2 writes) ----
camera_x        dw 0

; ---- Score and counters (Person 2 writes through AddScore) ----
score_lo        dw 0                ; 32-bit score, ADD/ADC
score_hi        dw 0
coins           db 0
lives           db START_LIVES

; ---- Hero (Person 3 writes) ----
; Position = whole pixels (word) + fraction (byte). Velocity = 8.8 word.
; (A pure 8.8 position cannot reach x = 944, so only velocity is 8.8.)
hero_x          dw START_X
hero_x_fr       db 0
hero_y          dw 0                ; y of the TOP of the sprite
hero_y_fr       db 0
hero_vx         dw 0                ; signed 8.8
hero_vy         dw 0                ; signed 8.8
hero_on_ground  db 0
hero_form       db FORM_SMALL
hero_hp         db 1
hero_face       db 1                ; 1 = right, 0 = left
hero_invuln     dw 0
hero_stomp      dw 0                ; stomp chain counter

; ---- Enemies (Person 3 writes) ----
enemy_table     times ENEMY_COUNT*ENEMY_SIZE db 0

; ---- Map: original is never changed, working copy is (Person 2 owns) ----
; map_original and level data are included from level.inc later.
map_working     times MAP_SIZE db 0

; ---- Temporary Stage-2 test data (Person 1; removed when Module 14 is done) ----
demo_x          dw 100
msg_nomem       db 'Not enough memory to run the game.', 13, 10, '$'
