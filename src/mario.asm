; ============================================================
; mario.asm  -  Super Mario Engine  (EL2003 semester project)
; Build : nasm -f bin src\mario.asm -o MARIO.COM
; This file only holds the entry point, the frame order and
; the %include list. Real code lives in the module files.
; ============================================================
        cpu 186                     ; 16-bit real mode (shifts by constants allowed)
        org 100h                    ; .COM entry point

start:
        jmp main

%include "src/constants.inc"

; ------------------------------------------------------------
; keyq  helper macro:  keyq SC_xxx  ->  AX = 1 if that key is held
; ------------------------------------------------------------
%macro keyq 1
        push word %1
        call IsKeyDown
%endmacro

; ------------------------------------------------------------
; main   TEMPORARY Stage-2 test program (Module 14 replaces it).
; Shows: colour swatches (Module 2), a block that moves smoothly
; with no flicker (Module 5), three "key held" lights (Module 7:
; hold Right + Shift + Space), and a light that changes every real
; second (Module 8).   Left/Right = move,  Shift = faster,  Esc = quit.
; ------------------------------------------------------------
main:
        call InitEngine
        jnc .ready
        mov dx, msg_nomem           ; could not get memory: say so and leave
        mov ah, 09h
        int 21h
        mov ax, 4C01h
        int 21h
.ready:
        mov byte [clock_run], 1
.frame:
        call WaitTick               ; one frame per timer tick
        keyq SC_ESC
        test ax, ax
        jnz .quit

        ; --- move the block (speed 2, or 5 with Shift) ---
        mov bx, 2
        keyq SC_LSHIFT
        test ax, ax
        jz .slow
        mov bx, 5
.slow:  keyq SC_LEFT
        test ax, ax
        jz .noleft
        sub [demo_x], bx
.noleft:
        keyq SC_RIGHT
        test ax, ax
        jz .noright
        add [demo_x], bx
.noright:
        cmp word [demo_x], 0
        jge .lok
        mov word [demo_x], 0
.lok:   cmp word [demo_x], SCREEN_W-16
        jle .rok
        mov word [demo_x], SCREEN_W-16
.rok:
        call UpdateClock
        call ClearBuffer

        ; --- colour swatches 0..15 along the bottom (Module 2 test) ---
        xor si, si
.sw:    mov ax, si
        shl ax, 4                   ; x = i * 16
        push ax
        push word 176
        push word 16
        push word 16
        push si                     ; colour = i
        call FillRect
        inc si
        cmp si, 16
        jb .sw

        ; --- the moving block ---
        push word [demo_x]
        push word 100
        push word 16
        push word 16
        push word COL_COIN
        call FillRect

        ; --- key lights: Right, Shift, Space (white when held, grey if not) ---
        mov di, 10
        keyq SC_RIGHT
        call .light
        mov di, 30
        keyq SC_LSHIFT
        call .light
        mov di, 50
        keyq SC_SPACE
        call .light

        ; --- second light: changes colour once per real second ---
        mov ax, [clock_secs]
        and ax, 7
        inc ax                      ; colour 1..8
        push word 80
        push word 10
        push word 16
        push word 16
        push ax
        call FillRect

        call FlipBuffer
        jmp .frame

.quit:  call ShutdownEngine         ; restores vectors, timer, text mode
        mov ax, 4C00h
        int 21h

; .light : draw a 16x16 light at x = DI; AX = 1 held -> white (15), else dark grey (8)
.light: mov dx, 8
        test ax, ax
        jz .l1
        mov dx, 15
.l1:    push di
        push word 10
        push word 16
        push word 16
        push dx
        call FillRect
        ret

; ------------------------------------------------------------
; GamePlayingFrame   Section 5.13: frame order in PLAYING state.
; Not called yet (Module 14 will call it). Keep this order!
; ------------------------------------------------------------
GamePlayingFrame:
        call WaitTick               ; 1  wait for next timer tick
                                    ; 2  key table is filled by the keyboard ISR
        call UpdateMario            ; 3  speed, gravity, jump, tile collision
        call UpdateEnemies          ; 4  enemies, shells, mushrooms
        call ResolveCollisions      ; 5  stomp, damage, kick, collect, score
                                    ; 6  clock + invulnerability (Module 8/9)
                                    ; 7  death and flag checks (Module 15)
        call UpdateCamera           ; 8  camera (Section 5.3)
        call ClearBuffer            ; 9  clear, then draw everything
        call DrawMap
        call DrawHUD
        call FlipBuffer             ; 10 copy frame buffer to video memory
        ret

%include "src/engine.asm"           ; Person 1
%include "src/world.asm"            ; Person 2
%include "src/gameplay.asm"         ; Person 3
%include "src/level.inc"            ; Person 2 (level data)
%include "src/data.inc"             ; shared variables
