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
; main   Module 14: the game loop.
;   InitEngine, then once per timer tick: run the procedure of the
;   current state (state_table) and count the clock.
;   ShutdownEngine restores keyboard, timer and text mode.
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
        push word ST_TITLE
        call SetState
.frame:
        call WaitTick               ; 1  one frame per timer tick
        mov byte [clock_run], 0     ; only StatePlaying turns the clock on
        xor bx, bx
        mov bl, [game_state]
        cmp bl, ST_EXIT
        je .quit
        shl bx, 1
        call word [state_table+bx]  ; jump table indexed by the state number
        call UpdateClock            ; 6  one second per TICKS_PER_SEC ticks
        jmp .frame
.quit:  call ShutdownEngine         ; restores vectors, timer, text mode
        mov ax, 4C00h
        int 21h

%include "src/engine.asm"           ; Person 1
%include "src/world.asm"            ; Person 2
%include "src/gameplay.asm"         ; Person 3
%include "src/text.asm"             ; Person 1 (text for the screens)
%include "src/states.asm"           ; Person 1 (Modules 14, 15)
%include "src/level.inc"            ; Person 2 (level data)
%include "src/data.inc"             ; shared variables

