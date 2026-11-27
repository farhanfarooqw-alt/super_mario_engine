; ============================================================
; test_p3.asm  -  PERSON 3's own test program (does NOT touch mario.asm)
; Build : build_p3.bat  ->  TESTP3.COM
;
; Tests Modules 9-12 (gameplay.asm) on the real level.
;   Left / Right = walk     Shift = run     Space = jump
;   Esc = quit              R = restart level
;   Debug keys:  S = become Super Mario     C = set coins to 99
;
; Uses the real Person 2 sprites, camera and HUD. R restarts the map;
; S grows Mario; C sets shared coins to 99 (next coin gives a life).
; A green marker under the HUD means the flag was touched.
; This is a gameplay test, not the final Person 1 state machine.
; ============================================================
        cpu 186
        org 100h

start:
        jmp main

%include "src/constants.inc"

KEY_R   equ 13h                     ; scan codes used only by this test
KEY_C   equ 2Eh
KEY_S   equ 1Fh

; keyq SC_xxx  ->  AX = 1 if that key is held
%macro keyq 1
        push word %1
        call IsKeyDown
%endmacro

main:
        call InitEngine
        jnc .ready
        mov dx, msg_nomem           ; no memory: say so and leave
        mov ah, 09h
        int 21h
        mov ax, 4C01h
        int 21h
.ready:
        call TestRestart            ; map, Mario, enemies, camera
.frame:
        call WaitTick               ; one frame per timer tick
        keyq SC_ESC
        test ax, ax
        jnz .quit
        call TestFrame
        call FlipBuffer
        jmp .frame
.quit:  call ShutdownEngine         ; restores keyboard, timer, text mode
        mov ax, 4C00h
        int 21h

; ------------------------------------------------------------
; TestRestart   stand-in for Person 1's ResetLevel: working map,
;               Mario, enemy table and camera back to the start
; Inputs/Outputs : none      Changes : none
; ------------------------------------------------------------
TestRestart:
        call ResetMap
        call ResetHero
        call ResetEnemies
        mov word [camera_x], 0
        ret

; ------------------------------------------------------------
; TestFrame   one frame in the order of Manual 5.13
; Inputs/Outputs : none      Changes : none
; ------------------------------------------------------------
TestFrame:
        push ax
        keyq KEY_R
        test ax, ax
        jz .nor
        call TestRestart            ; R: restart the level
.nor:   keyq KEY_S
        test ax, ax
        jz .nos
        call HeroGrow               ; S: become Super (debug)
.nos:   keyq KEY_C
        test ax, ax
        jz .noc
        mov byte [coins], 99     ; C: next coin = 100th (debug)
.noc:   cmp byte [level_won], 0
        jne .draw                   ; flag touched: everything frozen
        call UpdateMario            ; step 3
        call UpdateEnemies          ; step 4
        call ResolveCollisions      ; step 5
        cmp byte [hero_dead], 0
        je .alive
        call TestRestart            ; Mario died: start again
        jmp .draw
.alive: call UpdateCamera           ; step 8 (real Person 2 camera)
.draw:  call ClearBuffer            ; step 9
        call DrawMap
        call DrawEntities
        call DrawHero
        call TestHUD
        pop ax
        ret

; ------------------------------------------------------------
; TestHUD - real HUD and a green flag marker for testing.
; Inputs: shared game state. Outputs: frame buffer. Changes: none.
TestHUD:
        call DrawHUD
        cmp byte [level_won], 0
        je .done
        push word 150
        push word 16
        push word 12
        push word 8
        push word 10
        call FillRect
.done:  ret

%include "src/engine.asm"           ; Person 1
%include "src/text.asm"             ; HUD font procedures
%include "src/world.asm"            ; Person 2
%include "src/gameplay.asm"         ; Person 3
%include "src/level.inc"            ; Person 2
%include "src/data.inc"             ; shared variables
