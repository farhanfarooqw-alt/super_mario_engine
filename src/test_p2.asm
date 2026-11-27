; ============================================================
; test_p2.asm  -  PERSON 2's own test program (does NOT touch mario.asm)
; Build : build_p2.bat  ->  TESTP2.COM
;
; Step 1 test (Module 3: map and tiles):
;   Left / Right = scroll the map (Shift = faster)
;   Space        = SetTile: put a brick on row 8, in the middle column
;   Enter        = ResetMap: restore the original map
;   G            = switch between map test and sprite gallery
;   Esc          = quit
;   Startup runs camera and score/counter checks; failure exits to DOS.
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
        call TestRules
        test ax, ax
        jz .frame
        call ShutdownEngine
        mov dx, p2_fail
        mov ah, 09h
        int 21h
        mov ax, 4C02h
        int 21h
.frame:
        call WaitTick               ; one frame per timer tick
        keyq SC_ESC
        test ax, ax
        jnz .quit
        push word 22h               ; G scan code
        call KeyPressed
        test ax, ax
        jz .mode
        xor byte [gallery_mode], 1
.mode:  cmp byte [gallery_mode], 0
        jne .gallery
        call TestFrame
        jmp .flip
.gallery:
        call TestGallery
.flip:  call FlipBuffer
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

; TestRules: return AX=0 success, AX=1 failure. Only test program state.
; Uses worked example from section 5.3, score carry, cap and coin rollover.
TestRules:
        mov word [camera_x], 0
        mov word [hero_x], 200
        call UpdateCamera
        cmp word [camera_x], 40
        je .ok1
        jmp near .bad
.ok1:
        mov word [hero_x], 500
        call UpdateCamera
        cmp word [camera_x], 340
        je .ok2
        jmp near .bad
.ok2:
        mov word [hero_x], 400
        call UpdateCamera
        cmp word [camera_x], 340
        je .ok3
        jmp near .bad
.ok3:
        mov word [hero_x], 300
        mov word [hero_vx], 123
        call UpdateCamera
        cmp word [hero_x], 340
        je .ok4
        jmp near .bad
.ok4:
        cmp word [hero_vx], 0
        je .ok5
        jmp near .bad
.ok5:
        mov word [hero_x], 944
        call UpdateCamera
        cmp word [camera_x], CAM_MAX
        je .ok6
        jmp near .bad
.ok6:
        mov word [score_lo], 0FFFFh
        mov word [score_hi], 0
        push word 1
        call AddScore
        cmp word [score_hi], 1
        je .ok7
        jmp near .bad
.ok7:
        cmp word [score_lo], 0
        je .ok8
        jmp near .bad
.ok8:
        mov word [score_hi], MAX_SCORE_HI
        mov word [score_lo], MAX_SCORE_LO-1
        push word 200
        call AddScore
        cmp word [score_lo], MAX_SCORE_LO
        je .ok9
        jmp near .bad
.ok9:
        cmp word [score_hi], MAX_SCORE_HI
        je .ok10
        jmp near .bad
.ok10:
        mov byte [coins], 99
        mov byte [lives], 3
        call AddCoin
        cmp byte [coins], 0
        je .ok11
        jmp near .bad
.ok11:
        cmp byte [lives], 4
        je .ok12
        jmp near .bad
.ok12:
        mov byte [lives], MAX_LIVES
        call AddLife
        cmp byte [lives], MAX_LIVES
        je .ok13
        jmp near .bad
.ok13:
        mov word [camera_x], 0
        mov word [hero_x], START_X
        mov word [score_hi], 0
        mov word [score_lo], 0
        mov byte [coins], 0
        mov byte [lives], START_LIVES
        xor ax, ax
        ret
.bad:   mov ax, 1
        ret

; TestGallery: draw each sprite, mirrored/clipped samples and live HUD.
; Inputs: none. Outputs: framebuffer. Changes: none.
%macro show_sprite 4
        push word %1
        push word %2
        push word %3
        push word %4
        call DrawSprite
%endmacro
TestGallery:
        call ClearBuffer
        show_sprite 20,32,spr_small_stand,0
        show_sprite 60,32,spr_small_run,0
        show_sprite 100,32,spr_small_jump,0
        show_sprite 140,32,spr_small_run,1
        show_sprite 180,32,spr_super_stand,0
        show_sprite 220,32,spr_super_run,0
        show_sprite 260,32,spr_super_jump,1
        show_sprite 20,96,spr_goomba,0
        show_sprite 60,96,spr_goomba_flat,0
        show_sprite 100,96,spr_koopa,0
        show_sprite 140,96,spr_shell,0
        show_sprite 180,96,spr_mushroom,0
        show_sprite 220,96,spr_coin,0
        show_sprite 260,96,spr_small_stand,2
        call DrawHUD
        show_sprite -8,70,spr_small_run,0
        show_sprite 312,70,spr_small_run,1
        show_sprite 150,-8,spr_coin,0
        show_sprite 150,192,spr_coin,0
        ret
%unmacro show_sprite 4

gallery_mode db 0
p2_fail db 'P2 rule test failed.',13,10,'$'

%include "src/text.asm"             ; shared text routines used by DrawHUD
%include "src/engine.asm"           ; Person 1
%include "src/world.asm"            ; Person 2
%include "src/gameplay.asm"         ; Person 3 (stubs)
%include "src/level.inc"            ; Person 2
%include "src/data.inc"             ; shared variables
