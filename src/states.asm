; ============================================================
; states.asm  -  PERSON 1  (Modules 14 and 15)
; The game is a state machine: game_state indexes state_table
; (data.inc), the main loop in mario.asm calls the procedure of the
; current state once per frame (Manual 5.12).
; Still screens (Title, Paused, Life-lost, Complete, Game-over) are
; drawn only ONCE (screen_dirty) and then just stay on the screen.
; ============================================================

; ---- helper macros: push the arguments, then call ----
%macro rect 5                       ; rect x, y, w, h, colour
        push word %1
        push word %2
        push word %3
        push word %4
        push word %5
        call FillRect
%endmacro
%macro text 5                       ; text x, y, string_label, colour, scale
        push word %1
        push word %2
        push word %3
        push word %4
        push word %5
        call TxtStr
%endmacro
%macro keyp 1                       ; keyp SC_xxx -> AX = 1 if pressed this frame
        push word %1
        call KeyPressed
%endmacro
%macro goto 1                       ; goto ST_xxx -> SetState(ST_xxx)
        push word %1
        call SetState
%endmacro

; ------------------------------------------------------------
; SetState(newstate)
; Purpose : change the state, restart its timer, ask for a redraw,
;           forget old key presses and run the "entry actions".
; Inputs  : [bp+4] = new state number
; Outputs : none     Changes : none
; ------------------------------------------------------------
SetState:
        push bp
        mov bp, sp
        push ax
        mov ax, [bp+4]
        mov [game_state], al
        mov word [state_timer], 0
        mov byte [screen_dirty], 1
        call ClearHits              ; old key presses must not leak into the new state
        cmp ax, ST_DYING
        jne .n1
        call EnterDying
.n1:    cmp ax, ST_WIN
        jne .n2
        call EnterWin
.n2:    cmp ax, ST_COMPLETE
        jne .n3
        call EnterComplete
.n3:    pop ax
        pop bp
        ret 2

; ============================================================
; Module 15: ResetLevel and NewGame (play again without restarting)
; ============================================================

; ResetLevel : map (REP MOVSB copy), hero, enemies, camera, clock.
ResetLevel:
        push ax
        call ResetMap               ; working map <- original map
        call ResetHero
        call ResetEnemies
        mov word [camera_x], 0
        mov word [clock_secs], LEVEL_TIME
        mov ax, [tick_count]
        mov [clock_last], ax
        mov byte [clock_run], 0
        pop ax
        ret

; NewGame : score, coins, lives and then the level.
NewGame:
        mov word [score_lo], 0
        mov word [score_hi], 0
        mov byte [coins], 0
        mov byte [lives], START_LIVES
        call ResetLevel
        ret

; ============================================================
; TITLE
; ============================================================
StateTitle:
        keyp SC_DOWN
        test ax, ax
        jz .noDown
        mov byte [menu_sel], 1
        mov byte [screen_dirty], 1
.noDown:
        keyp SC_UP
        test ax, ax
        jz .noUp
        mov byte [menu_sel], 0
        mov byte [screen_dirty], 1
.noUp:
        keyp SC_ESC
        test ax, ax
        jnz .exit
        keyp SC_ENTER
        test ax, ax
        jz .draw
        cmp byte [menu_sel], 0
        jne .exit
        call NewGame                ; START GAME
        goto ST_PLAYING
        ret
.exit:  goto ST_EXIT
        ret
.draw:  cmp byte [screen_dirty], 0
        je .out
        call DrawTitleScreen
        call FlipBuffer
        mov byte [screen_dirty], 0
.out:   ret

; BrickTile(x, y)   one 16x16 brick for the borders
BrickTile:
        push bp
        mov bp, sp
        push ax
        push bx
        mov ax, [bp+6]
        mov bx, [bp+4]
        push ax
        push bx
        push word 16
        push word 16
        push word COL_GROUND
        call FillRect
        mov bx, [bp+4]
        add bx, 7
        push ax
        push bx
        push word 16
        push word 2
        push word COL_BLACK
        call FillRect               ; horizontal mortar line
        mov bx, [bp+4]
        add ax, 7
        push ax
        push bx
        push word 2
        push word 7
        push word COL_BLACK
        call FillRect               ; vertical mortar line (upper half)
        pop bx
        pop ax
        pop bp
        ret 4

; DrawBrickBorder : one tile thick brick frame around the 20 x 12 grid
DrawBrickBorder:
        push ax
        xor ax, ax
.top:   push ax
        push word 0
        call BrickTile
        push ax
        push word 176
        call BrickTile
        add ax, 16
        cmp ax, 320
        jb .top
        mov ax, 16
.side:  push word 0
        push ax
        call BrickTile
        push word 304
        push ax
        call BrickTile
        add ax, 16
        cmp ax, 176
        jb .side
        pop ax
        ret

DrawTitleScreen:
        push ax
        call ClearBuffer
        call DrawBrickBorder
        text 30, 38, txt_super, COL_BLACK, 3     ; shadow
        text 28, 36, txt_super, 12, 3            ; red title
        text 112, 78, txt_engine, 15, 2
        rect 56, 104, 208, 60, 15                ; menu box: white frame
        rect 58, 106, 204, 56, COL_BLACK
        mov ax, 15                               ; colours of the two entries
        mov dx, 15
        cmp byte [menu_sel], 0
        jne .sel1
        mov ax, 14                               ; START GAME is highlighted (yellow)
        jmp .go
.sel1:  mov dx, 14                               ; EXIT is highlighted
.go:    cmp byte [menu_sel], 0
        jne .m1
        push word 68
        push word 114
        push word '>'
        push ax
        push word 2
        call TxtChar
        jmp .t0
.m1:    push word 68
        push word 138
        push word '>'
        push dx
        push word 2
        call TxtChar
.t0:    push word 92
        push word 114
        push word txt_start
        push ax
        push word 2
        call TxtStr
        push word 92
        push word 138
        push word txt_exit
        push dx
        push word 2
        call TxtStr
        text 24, 168, txt_team, COL_BLACK, 1
        pop ax
        ret

; ============================================================
; PLAYING  (frame order of Manual 5.13)
; ============================================================
StatePlaying:
        mov byte [clock_run], 1     ; the clock counts only while playing
        keyp SC_P
        test ax, ax
        jz .noP
        goto ST_PAUSED
        ret
.noP:   keyp SC_ESC
        test ax, ax
        jz .noEsc
        goto ST_TITLE
        ret
.noEsc:
        ; ---- debug keys (listed in the README) ----
        keyp SC_K
        test ax, ax
        jz .noK
        mov byte [hero_dead], 1     ; K = kill Mario
.noK:   keyp SC_W
        test ax, ax
        jz .noW
        mov byte [level_won], 1     ; W = touch the flag
.noW:   keyp SC_T
        test ax, ax
        jz .noT
        mov word [clock_secs], 5    ; T = clock to 5 seconds
.noT:
        call UpdateMario            ; 3  hero
        call UpdateEnemies          ; 4  enemies, shells, mushrooms
        call ResolveCollisions      ; 5  stomp, damage, kick, collect, score
        cmp word [clock_secs], 0    ; 6/7 clock at 0 kills Mario (Manual 5.10)
        ja .timeOk
        mov byte [hero_dead], 1
.timeOk:
        cmp byte [hero_dead], 0     ; 7  death and flag checks
        je .alive
        goto ST_DYING
        ret
.alive: cmp byte [level_won], 0
        je .go
        goto ST_WIN
        ret
.go:    call UpdateCamera           ; 8
        call DrawWorld              ; 9
        call FlipBuffer             ; 10
        ret

; DrawWorld : clear, tiles, hero, HUD  (enemies/items: Person 3's DrawEntities later)
DrawWorld:
        call ClearBuffer
        call DrawMap
        call DrawHeroTemp
        call DrawHUD
        ret

; DrawHeroTemp : TEMPORARY red box in place of Mario until Person 2's sprites
;   and Person 3's DrawHero exist.  screen_x = world_x - camera_x
DrawHeroTemp:
        push ax
        push bx
        mov ax, [hero_x]
        sub ax, [camera_x]
        mov bx, 16
        cmp byte [hero_form], FORM_SMALL
        je .h
        mov bx, 32
.h:     push ax
        push word [hero_y]
        push word 16
        push bx
        push word 12
        call FillRect
        pop bx
        pop ax
        ret

; ============================================================
; PAUSED : the picture stays, a box is drawn once on top
; ============================================================
StatePaused:
        keyp SC_P
        test ax, ax
        jz .noP
        goto ST_PLAYING
        ret
.noP:   keyp SC_ESC
        test ax, ax
        jz .draw
        goto ST_TITLE
        ret
.draw:  cmp byte [screen_dirty], 0
        je .out
        rect 80, 72, 160, 56, 15
        rect 82, 74, 156, 52, COL_BLACK
        text 112, 84, txt_paused, 14, 2
        text 92, 108, txt_resume, 15, 1
        call FlipBuffer
        mov byte [screen_dirty], 0
.out:   ret

; ============================================================
; DYING : hop up about 48 px, then fall off the screen, no collisions
; ============================================================
EnterDying:
        push ax
        mov word [hero_vx], 0
        mov word [hero_vy], DEATH_HOP
        mov ax, [hero_y]
        cmp ax, PIT_Y
        jl .done                    ; killed by an enemy or the clock: hop first
        mov word [hero_vy], 0       ; pit death: no hop, just keep falling
.done:  pop ax
        ret

StateDying:
        inc word [state_timer]
        mov ax, [hero_vy]           ; vy = vy + gravity
        add ax, GRAVITY
        mov [hero_vy], ax
        mov bl, [hero_y_fr]         ; y = y + vy   (position = pixels + fraction)
        add bl, al
        mov [hero_y_fr], bl
        mov al, ah
        cbw                         ; AX = signed whole pixels of vy
        adc ax, 0                   ; + carry from the fraction
        add [hero_y], ax
        call DrawWorld
        call FlipBuffer
        cmp word [state_timer], DEATH_FRAMES
        jb .out
        dec byte [lives]            ; Manual 5.8 step 3
        cmp byte [lives], 0
        je .over
        goto ST_LIFELOST
        ret
.over:  goto ST_GAMEOVER
.out:   ret

; ============================================================
; LIFE LOST : WORLD 1-1, Mario icon, lives left, about 2 seconds
; ============================================================
StateLifeLost:
        cmp byte [screen_dirty], 0
        je .wait
        rect 0, 0, 320, 200, COL_BLACK
        text 88, 50, txt_world, 15, 2
        rect 120, 90, 16, 16, 12                ; TEMP Mario icon
        text 168, 90, txt_x, 15, 2
        xor ax, ax
        mov al, [lives]
        mov bx, 1                               ; one digit ...
        cmp ax, 10
        jb .d
        mov bx, 2                               ; ... or two
.d:     push word 200
        push word 90
        push ax
        push bx
        push word 15
        push word 2
        call TxtNum
        text 80, 140, txt_liveleft, 14, 2
        call FlipBuffer
        mov byte [screen_dirty], 0
.wait:  inc word [state_timer]
        cmp word [state_timer], LIFELOST_FRAMES
        jb .out
        call ResetLevel             ; map, enemies, clock, camera, Mario
        goto ST_PLAYING
.out:   ret

; ============================================================
; WIN SEQUENCE : snap to the pole, slide down, walk to the castle
; ============================================================
EnterWin:
        mov word [hero_x], FLAG_COL*TILE        ; snap to the pole
        mov word [hero_vx], 0
        mov word [hero_vy], 0
        ret

StateWin:
        push ax
        push dx
        inc word [state_timer]
        mov ax, [state_timer]
        cmp ax, WIN_SLIDE_FRAMES
        ja .walk
        mov dx, 144                 ; feet on the ground: top = 160 - height
        cmp byte [hero_form], FORM_SMALL
        je .s
        mov dx, 128
.s:     mov ax, [hero_y]
        cmp ax, dx
        jge .draw
        add ax, 3                   ; slide down 3 px per frame
        cmp ax, dx
        jle .st
        mov ax, dx
.st:    mov [hero_y], ax
        jmp .draw
.walk:  add word [hero_x], 2        ; walk towards the castle door
        cmp ax, WIN_SLIDE_FRAMES+WIN_WALK_FRAMES
        jb .draw
        goto ST_COMPLETE
        jmp .out
.draw:  call DrawWorld
        call FlipBuffer
.out:   pop dx
        pop ax
        ret

; ============================================================
; LEVEL COMPLETE : bonus = time left * 50 is added once
; ============================================================
EnterComplete:
        push ax
        push bx
        push dx
        mov ax, [clock_secs]
        mov [win_time], ax
        mov bx, 50
        mul bx                      ; AX = time * 50 (at most 15000)
        mov [win_bonus], ax
        mov ax, [score_lo]          ; remember the score before the bonus
        mov [win_score_lo], ax
        mov ax, [score_hi]
        mov [win_score_hi], ax
        push word [win_bonus]
        call AddScore               ; Person 2's 32-bit ADD/ADC
        pop dx
        pop bx
        pop ax
        ret

StateComplete:
        keyp SC_ENTER
        test ax, ax
        jz .draw
        goto ST_TITLE
        ret
.draw:  cmp byte [screen_dirty], 0
        je .out
        rect 0, 0, 320, 200, COL_BLACK
        rect 24, 16, 272, 160, 14               ; yellow frame
        rect 27, 19, 266, 154, 1                ; dark blue panel
        text 40, 28, txt_complete, 14, 2
        text 56, 64, txt_score, 15, 1
        push word 176
        push word 64
        push word [win_score_lo]
        push word [win_score_hi]
        push word 15
        push word 1
        call TxtNum32
        text 56, 80, txt_coins, 15, 1
        text 176, 80, txt_x, 15, 1
        xor ax, ax
        mov al, [coins]
        push word 192
        push word 80
        push ax
        push word 2
        push word 15
        push word 1
        call TxtNum
        text 56, 96, txt_timeleft, 15, 1
        push word 176
        push word 96
        push word [win_time]
        push word 3
        push word 15
        push word 1
        call TxtNum
        text 216, 96, txt_x50, 15, 1
        text 56, 112, txt_bonus, 15, 1
        text 176, 112, txt_plus, 15, 1
        push word 192
        push word 112
        push word [win_bonus]
        push word 5
        push word 15
        push word 1
        call TxtNum
        text 56, 134, txt_final, 14, 1
        push word 176
        push word 134
        push word [score_lo]
        push word [score_hi]
        push word 14
        push word 1
        call TxtNum32
        text 64, 156, txt_enter_c, 10, 1
        call FlipBuffer
        mov byte [screen_dirty], 0
.out:   ret

; ============================================================
; GAME OVER
; ============================================================
StateGameOver:
        keyp SC_ENTER
        test ax, ax
        jz .draw
        goto ST_TITLE
        ret
.draw:  cmp byte [screen_dirty], 0
        je .out
        rect 0, 0, 320, 200, COL_BLACK
        rect 40, 30, 240, 130, 4                ; red frame
        rect 43, 33, 234, 124, COL_BLACK
        text 52, 50, txt_gameover, 12, 3
        text 64, 96, txt_score, 15, 2
        push word 160
        push word 96
        push word [score_lo]
        push word [score_hi]
        push word 15
        push word 2
        call TxtNum32
        text 96, 124, txt_coins, 14, 1
        xor ax, ax
        mov al, [coins]
        push word 144
        push word 124
        push ax
        push word 2
        push word 14
        push word 1
        call TxtNum
        text 176, 124, txt_time, 14, 1
        push word 216
        push word 124
        push word [clock_secs]
        push word 3
        push word 14
        push word 1
        call TxtNum
        text 60, 144, txt_enter_t, 10, 1
        call FlipBuffer
        mov byte [screen_dirty], 0
.out:   ret

; ============================================================
; EXIT : the main loop stops when it sees this state
; ============================================================
StateExit:
        ret

; ============================================================
; State table and text strings (Modules 14/15 data; kept here so that
; test programs of the other members do not need these labels)
; ============================================================
state_table     dw StateTitle, StatePlaying, StatePaused, StateDying
                dw StateLifeLost, StateWin, StateComplete, StateGameOver, StateExit
txt_super       db 'SUPER MARIO', 0
txt_engine      db 'ENGINE', 0
txt_start       db 'START GAME', 0
txt_exit        db 'EXIT', 0
txt_team        db 'Group #XX  Names of the team here', 0
txt_paused      db 'PAUSED', 0
txt_resume      db 'Press P to resume', 0
txt_world       db 'WORLD 1-1', 0
txt_x           db 'x', 0
txt_liveleft    db 'LIVES LEFT', 0
txt_gameover    db 'GAME OVER', 0
txt_score       db 'SCORE', 0
txt_coins       db 'COINS', 0
txt_time        db 'TIME', 0
txt_complete    db 'LEVEL COMPLETE!', 0
txt_timeleft    db 'TIME LEFT', 0
txt_x50         db 'x 50', 0
txt_bonus       db 'TIME BONUS', 0
txt_plus        db '+', 0
txt_final       db 'FINAL SCORE', 0
txt_enter_t     db 'Press ENTER for the title', 0
txt_enter_c     db 'Press ENTER to continue', 0

