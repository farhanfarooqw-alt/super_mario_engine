; ============================================================
; test_p2.asm  -  PERSON 2's own test program (does NOT touch mario.asm)
; Build : build_p2.bat  ->  TESTP2.COM
;
; Step 1 test (Module 3: map and tiles):
;   Left / Right = scroll the map (Shift = faster)
;   Space        = SetTile: put a brick on row 8, in the middle column
;   Enter        = ResetMap: restore the original map
;   Esc          = quit
;   Light at top-left: GREEN when GetTile says that tile is a brick,
;                      RED otherwise.
; The camera is moved by the keys here only for testing; in the real
; game UpdateCamera (Module 6) moves it from hero_x.
; ============================================================
        cpu 186
        org 100h

start:
        jmp main

%include "src/constants.inc"

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
        call ResetMap               ; map_working starts empty: copy the original in
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
; TestFrame   one frame of the Step 1 test (everything except
;             waiting for the tick and flipping the buffer)
; Inputs/Outputs : none      Changes : none
; ------------------------------------------------------------
TestFrame:
        push ax
        push bx
        push cx
        push dx
        mov bx, 2                   ; scroll speed 2, or 6 with Shift
        keyq SC_LSHIFT
        test ax, ax
        jz .slow
        mov bx, 6
.slow:  keyq SC_LEFT
        test ax, ax
        jz .noleft
        sub [camera_x], bx
.noleft:
        keyq SC_RIGHT
        test ax, ax
        jz .noright
        add [camera_x], bx
.noright:
        cmp word [camera_x], 0      ; keep the camera inside 0 .. CAM_MAX
        jge .lowok
        mov word [camera_x], 0
.lowok: cmp word [camera_x], CAM_MAX
        jle .highok
        mov word [camera_x], CAM_MAX
.highok:
        mov cx, [camera_x]
        shr cx, TILE_SHIFT
        add cx, 10                  ; CX = map column in the middle of the screen
        keyq SC_SPACE
        test ax, ax
        jz .nospace
        push cx                     ; SetTile(col, row 8, brick)
        push word 8
        push word T_BRICK
        call SetTile
.nospace:
        keyq SC_ENTER
        test ax, ax
        jz .noenter
        call ResetMap
.noenter:
        call ClearBuffer
        call DrawMap
        mov ax, cx                  ; GetTile(col*16, 8*16) tells us what is there
        shl ax, TILE_SHIFT
        push ax
        push word 8*TILE
        call GetTile
        mov dx, 4                   ; red
        cmp ax, T_BRICK
        jne .light
        mov dx, 10                  ; green: it is a brick
.light: push word 4
        push word 4
        push word 24
        push word 8
        push dx
        call FillRect
        pop dx
        pop cx
        pop bx
        pop ax
        ret

%include "src/engine.asm"           ; Person 1
%include "src/world.asm"            ; Person 2
%include "src/gameplay.asm"         ; Person 3 (stubs)
%include "src/level.inc"            ; Person 2
%include "src/data.inc"             ; shared variables
