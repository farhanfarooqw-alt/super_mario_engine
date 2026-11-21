; ============================================================
; test_p3.asm  -  PERSON 3's own test program (does NOT touch mario.asm)
; Build : build_p3.bat  ->  TESTP3.COM
;
; Tests Modules 9-12 (gameplay.asm) on the real level.
;   Left / Right = walk     Shift = run     Space = jump
;   Esc = quit              R = restart level
;   Debug keys:  S = become Super Mario     C = set coins to 99
;
; Mario, enemies, shells, mushrooms are coloured rectangles (red /
; light red = Mario Small / Super, brown = Goomba, green = Koopa,
; light green = shell, magenta = mushroom, yellow = coin pop-up).
; A small white "eye" shows which way Mario faces.
;
; Top strip, left to right (white digits):
;   SCORE (5 digits)   COINS (2)   HP (1)   STOMP CHAIN (2)   LIVES (1)
;   and a green box when the flag pole was touched (level_won).
;
; TestCamera is a TEMPORARY camera of my own and TestFrame plays the
; role of Person 1's state machine (restart after hero_dead, freeze
; after level_won). Person 2's UpdateCamera and DrawSprite are not
; merged yet.
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
        mov byte [p3_coins], 99     ; C: next coin = 100th (debug)
.noc:   cmp byte [level_won], 0
        jne .draw                   ; flag touched: everything frozen
        call UpdateMario            ; step 3
        call UpdateEnemies          ; step 4
        call ResolveCollisions      ; step 5
        cmp byte [hero_dead], 0
        je .alive
        call TestRestart            ; Mario died: start again
        jmp .draw
.alive: call TestCamera             ; step 8 (temporary camera)
.draw:  call ClearBuffer            ; step 9
        call DrawMap
        call DrawEntities
        call DrawHero
        call TestHUD
        pop ax
        ret

; ------------------------------------------------------------
; TestCamera   TEMPORARY camera (same rule as Manual 5.3):
;   follow Mario past screen x 160, clamp to CAM_MAX, never move
;   back, and stop Mario at the left edge of the screen.
; Inputs/Outputs : none      Changes : none
; ------------------------------------------------------------
TestCamera:
        push ax
        mov ax, [hero_x]
        sub ax, [camera_x]
        cmp ax, CAM_FOLLOW_X
        jle .leftwall
        mov ax, [hero_x]
        sub ax, CAM_FOLLOW_X        ; new camera = hero_x - 160
        cmp ax, CAM_MAX
        jle .clamped
        mov ax, CAM_MAX
.clamped:
        cmp ax, [camera_x]
        jle .leftwall               ; never decrease the camera
        mov [camera_x], ax
.leftwall:
        mov ax, [camera_x]
        cmp [hero_x], ax
        jge .done
        mov [hero_x], ax            ; invisible wall at the left edge
        mov word [hero_vx], 0
.done:  pop ax
        ret

; ------------------------------------------------------------
; TestHUD   numbers for checking the rules (see header)
; Inputs/Outputs : none      Changes : none
; ------------------------------------------------------------
TestHUD:
        push ax
        push word 4                 ; score (low word, 5 digits)
        push word 4
        push word [p3_score_lo]
        push word 5
        call TestShowNum
        push word 60                ; coins
        push word 4
        mov al, [p3_coins]
        xor ah, ah
        push ax
        push word 2
        call TestShowNum
        push word 84                ; hp
        push word 4
        mov al, [hero_hp]
        xor ah, ah
        push ax
        push word 1
        call TestShowNum
        push word 100               ; stomp chain
        push word 4
        push word [hero_stomp]
        push word 2
        call TestShowNum
        push word 124               ; lives
        push word 4
        mov al, [lives]
        xor ah, ah
        push ax
        push word 1
        call TestShowNum
        cmp byte [level_won], 0
        je .done
        push word 150               ; green box = flag touched
        push word 4
        push word 12
        push word 8
        push word 10
        call FillRect
.done:  pop ax
        ret

; ------------------------------------------------------------
; TestShowNum(x, y, value, digits)   decimal number, 3x5 font
; Inputs  : [bp+10]=x  [bp+8]=y  [bp+6]=value  [bp+4]=digits
; Outputs : none      Changes : none
; ------------------------------------------------------------
TestShowNum:
        push bp
        mov bp, sp
        push ax
        push bx
        push cx
        push dx
        mov ax, [bp+6]              ; value
        mov cx, [bp+4]              ; digits, drawn right to left
.next:  xor dx, dx
        mov bx, 10
        div bx                      ; AX = rest, DX = last digit
        push ax
        mov bx, cx
        dec bx
        shl bx, 3                   ; 8 pixels per digit
        add bx, [bp+10]
        push bx                     ; x of this digit
        push word [bp+8]            ; y
        push dx                     ; digit
        call TestDigit
        pop ax
        loop .next
        pop dx
        pop cx
        pop bx
        pop ax
        pop bp
        ret 8

; ------------------------------------------------------------
; TestDigit(x, y, digit)   one digit of 3x5 dots, each dot 2x2
; Inputs  : [bp+8]=x  [bp+6]=y  [bp+4]=digit (0..9)
; Outputs : none      Changes : none
; ------------------------------------------------------------
TestDigit:
        push bp
        mov bp, sp
        push ax
        push bx
        push cx
        push dx
        push si
        mov bx, [bp+4]
        shl bx, 1
        mov si, [font3x5+bx]        ; 15 bits, bit 14 = top-left dot
        xor cx, cx                  ; CX = dot number 0..14
.dot:   test si, 4000h
        jz .skip
        mov ax, cx
        xor dx, dx
        mov bx, 3
        div bx                      ; AX = row, DX = column
        shl dx, 1
        add dx, [bp+8]              ; x of the dot
        shl ax, 1
        add ax, [bp+6]              ; y of the dot
        push dx
        push ax
        push word 2
        push word 2
        push word COL_TEXT
        call FillRect
.skip:  shl si, 1
        inc cx
        cmp cx, 15
        jb .dot
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        pop bp
        ret 6

font3x5 dw 07B6Fh, 02C97h, 073E7h, 073CFh, 05BC9h, 079CFh, 079EFh, 07292h, 07BEFh, 07BCFh

%include "src/engine.asm"           ; Person 1
%include "src/world.asm"            ; Person 2
%include "src/gameplay.asm"         ; Person 3
%include "src/level.inc"            ; Person 2
%include "src/data.inc"             ; shared variables
