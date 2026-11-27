; ============================================================
; world.asm  -  PERSON 2  (Modules 3, 4, 6, 13)
; Convention: see docs/CONVENTIONS.md
; ============================================================

; NOTE: PutPixel and FillRect (Module 2) are written by Person 1 in engine.asm.
; Every drawing procedure draws into the FRAME BUFFER, never into A000h.

; ------------------------------------------------------------
; GetTile(px, py)                                      Module 3
; Purpose : pixel position in the WORLD -> tile code from the
;           working map.  col = px >> 4, row = py >> 4,
;           index = row*60 + col  (row*60 = row*64 - row*4).
;           Outside the level: px < 0 or px >= 960 -> T_GROUND
;           (solid wall); py < 0 or py >= 192 -> T_SKY.
; Inputs  : [bp+6] = px (signed)   [bp+4] = py (signed)
; Outputs : AX = tile code
; Changes : AX only
; ------------------------------------------------------------
%if MAP_W != 60
%error "GetTile multiplies by 60 with shifts: change it if MAP_W changes"
%endif
GetTile:
        push bp
        mov bp, sp
        push bx
        push cx
        mov bx, [bp+6]              ; px
        cmp bx, LEVEL_PX
        jae .wall                   ; unsigned compare: negative px is huge, so caught too
        mov ax, [bp+4]              ; py
        cmp ax, MAP_H*TILE
        jae .sky                    ; same trick for py < 0
        shr bx, TILE_SHIFT          ; bx = col
        shr ax, TILE_SHIFT          ; ax = row
        mov cx, ax
        shl ax, 6                   ; row * 64
        shl cx, 2                   ; row * 4
        sub ax, cx                  ; row * 60
        add bx, ax                  ; bx = row*60 + col
        mov al, [map_working+bx]    ; indexed addressing
        xor ah, ah                  ; AX = tile code (0..12)
        jmp .out
.wall:  mov ax, T_GROUND
        jmp .out
.sky:   mov ax, T_SKY
.out:   pop cx
        pop bx
        pop bp
        ret 4

; ------------------------------------------------------------
; SetTile(col, row, code)                              Module 3
; Purpose : write one tile code into the WORKING map (map_original
;           is never touched). Used when a block is hit, a brick
;           breaks or a coin is taken. index = row*60 + col.
;           A col or row outside the map is ignored.
; Inputs  : [bp+8] = col   [bp+6] = row   [bp+4] = code (low byte)
; Outputs : none
; Changes : none (AX, BX, CX are saved and restored)
; ------------------------------------------------------------
SetTile:
        push bp
        mov bp, sp
        push ax
        push bx
        push cx
        mov ax, [bp+6]              ; row
        cmp ax, MAP_H
        jae .out                    ; unsigned: also catches negative row
        mov bx, [bp+8]              ; col
        cmp bx, MAP_W
        jae .out                    ; same for col
        mov cx, ax
        shl ax, 6                   ; row * 64
        shl cx, 2                   ; row * 4
        sub ax, cx                  ; row * 60
        add bx, ax                  ; bx = row*60 + col
        mov al, [bp+4]              ; new tile code
        mov [map_working+bx], al
.out:   pop cx
        pop bx
        pop ax
        pop bp
        ret 6

; ------------------------------------------------------------
; DrawTile(x, y, code)                                 Module 3
; Purpose : draw one bitmap tile into the frame buffer at signed
;           screen coordinates, using the tile pointer table.
;           Sky is not drawn (ClearBuffer already made the sky).
; Inputs  : [bp+8] = x   [bp+6] = y   [bp+4] = tile code
; Outputs : none
; Changes : none (AX, BX are saved and restored)
; ------------------------------------------------------------
DrawTile:
        push bp
        mov bp, sp
        push bx
        mov bx, [bp+4]
        cmp bx, T_SKY
        je .out
        cmp bx, T_FLAG
        ja .out
        shl bx, 1
        mov bx, [tile_sprites+bx]
        cmp word [bp+4], T_FLAG
        jne .draw
        cmp word [bp+6], 2*TILE
        jne .draw
        mov bx, tile_flag_top
.draw:  push word [bp+8]
        push word [bp+6]
        push bx
        push word 0
        call DrawSprite
.out:   pop bx
        pop bp
        ret 6

tile_sprites:
        dw 0, tile_ground, tile_brick, tile_q, tile_q, tile_empty
        dw tile_pipetl, tile_pipetr, tile_pipebl, tile_pipebr
        dw tile_stair, spr_coin, tile_flag

; ------------------------------------------------------------
; DrawMap                                              Module 3 / 6
; Purpose : draw the visible part of the working map into the frame
;           buffer: 20 columns + 1 partial column, starting at
;           column camera_x >> 4, shifted left by camera_x & 15
;           pixels, so the picture scrolls one pixel at a time.
;           Row 0 is the HUD strip (DrawHUD paints it), so tile rows
;           1..11 are drawn. The bottom 8 pixels stay black (A.1).
; Inputs  : none (reads camera_x and map_working)
; Outputs : none
; Changes : none (AX, BX, CX, DX, SI, DI are saved and restored)
; Registers inside: SI = map column, DI = screen x of that column,
;           CX = columns left to draw, DX = map row
; ------------------------------------------------------------
DrawMap:
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov ax, [camera_x]
        mov si, ax
        shr si, TILE_SHIFT          ; si = first column = camera_x / 16
        and ax, TILE-1              ; ax = camera_x mod 16
        mov di, ax
        neg di                      ; di = screen x of the first column (0 to -15)
        mov cx, VIEW_COLS+1         ; 20 columns + 1 partial = 21
.col:   cmp si, MAP_W
        jae .done                   ; past the last map column: nothing more to draw
        mov dx, 1                   ; start at row 1 (row 0 = HUD)
.row:   mov ax, dx
        shl ax, 6                   ; row * 64
        mov bx, dx
        shl bx, 2                   ; row * 4
        sub ax, bx                  ; row * 60
        add ax, si                  ; + column
        mov bx, ax
        mov al, [map_working+bx]    ; tile code at (si, dx)
        xor ah, ah
        push di                     ; x on the screen
        mov bx, dx
        shl bx, TILE_SHIFT          ; y = row * 16
        push bx
        push ax                     ; tile code
        call DrawTile
        inc dx
        cmp dx, MAP_H
        jb .row
        add di, TILE                ; next column, 16 pixels to the right
        inc si
        dec cx
        jnz .col
.done:  push word 0                 ; black strip y = 192..199
        push word MAP_H*TILE
        push word SCREEN_W
        push word SCREEN_H-MAP_H*TILE
        push word COL_BLACK
        call FillRect
        pop di
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        ret

; ------------------------------------------------------------
; ResetMap                                             Module 3
; Purpose : copy the untouched map_original over map_working with
;           ONE block move (REP MOVSW). Used at every new life and
;           new game, so broken bricks, used ? blocks and taken
;           coins come back.
; Inputs  : none
; Outputs : none
; Changes : none (CX, SI, DI, ES are saved and restored)
; ------------------------------------------------------------
%if MAP_SIZE & 1
%error "ResetMap copies words: MAP_SIZE must be even"
%endif
ResetMap:
        push cx
        push si
        push di
        push es
        push ds
        pop es                      ; ES = DS (a .COM has one segment)
        mov si, map_original        ; source      DS:SI
        mov di, map_working         ; destination ES:DI
        mov cx, MAP_SIZE/2          ; 720 bytes = 360 words
        cld                         ; copy forwards
        rep movsw
        pop es
        pop di
        pop si
        pop cx
        ret

; ------------------------------------------------------------
; DrawSprite(x, y, addr, flags) - Module 4
; Purpose: draw a bitmap with transparency, mirroring and clipping.
; Inputs: [bp+10]=x, [bp+8]=y, [bp+6]=bitmap, [bp+4]=flags
; Flags: bit 0 mirror, bit 1 blink (skip odd timer ticks).
; Bitmap: width byte, height byte, then width*height colour bytes.
; Outputs: none. Registers changed: none.
; ------------------------------------------------------------
DrawSprite:
        push bp
        mov bp, sp
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push es
        sub sp, 4                  ; [bp-16] width, [bp-18] rows remaining
        test word [bp+4], 2
        jz .setup
        test word [tick_count], 1
        jnz .out
.setup: mov si, [bp+6]
        xor ax, ax
        mov al, [si]
        mov [bp-16], ax
        mov al, [si+1]
        mov [bp-18], ax
        add si, 2
        mov dx, [bp+8]
        mov es, [fb_seg]
        cld
.row:   cmp word [bp-18], 0
        je .out
        cmp dx, SCREEN_H
        jae .skiprow               ; unsigned rejects negative y too
        mov ax, dx
        mov di, ax
        shl di, 8
        shl ax, 6
        add di, ax                 ; row start = y*320
        mov bx, [bp+10]
        mov cx, [bp-16]
        test word [bp+4], 1
        jz .normal
        add bx, cx
        dec bx
.mirror: jcxz .nextrow
        lodsb
        test al, al
        jz .mnext
        cmp bx, SCREEN_W
        jae .mnext
        mov [es:di+bx], al
.mnext: dec bx
        loop .mirror
        jmp .nextrow
.normal: jcxz .nextrow
        lodsb
        test al, al
        jz .nnext
        cmp bx, SCREEN_W
        jae .nnext
        mov [es:di+bx], al
.nnext: inc bx
        loop .normal
        jmp .nextrow
.skiprow:
        add si, [bp-16]
.nextrow:
        inc dx
        dec word [bp-18]
        jmp .row
.out:   add sp, 4
        pop es
        pop di
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        pop bp
        ret 8

; UpdateCamera - Module 6. Inputs: shared hero position and camera.
; Outputs: camera_x, and hero left-edge correction per Section 5.3.
; Changes: no registers. Shared hero writes are limited to edge clamp.
UpdateCamera:
        push ax
        mov ax, [hero_x]
        cmp ax, [camera_x]
        jge .follow
        mov ax, [camera_x]
        mov [hero_x], ax
        mov byte [hero_x_fr], 0
        mov word [hero_vx], 0
.follow:
        sub ax, CAM_FOLLOW_X
        cmp ax, [camera_x]
        jle .done
        cmp ax, CAM_MAX
        jle .store
        mov ax, CAM_MAX
.store: mov [camera_x], ax
.done:  pop ax
        ret

; AddScore(points) - Module 13. [bp+4] = unsigned word points.
; Outputs: updated 32-bit score, clamped at 999999. Changes: none.
AddScore:
        push bp
        mov bp, sp
        push ax
        mov ax, [bp+4]
        add [score_lo], ax
        adc word [score_hi], 0
        jc .clamp
        cmp word [score_hi], MAX_SCORE_HI
        ja .clamp
        jb .done
        cmp word [score_lo], MAX_SCORE_LO
        jbe .done
.clamp: mov word [score_hi], MAX_SCORE_HI
        mov word [score_lo], MAX_SCORE_LO
.done:  pop ax
        pop bp
        ret 2

; AddCoin - no inputs; increment coin counter, award life at 100.
; Outputs: coins/lives. Changes: no registers. Score awarded separately.
AddCoin:
        inc byte [coins]
        cmp byte [coins], 100
        jb .done
        mov byte [coins], 0
        call AddLife
.done:  ret

; AddLife - no inputs. Outputs: lives capped at 99. Changes: none.
AddLife:
        cmp byte [lives], MAX_LIVES
        jae .done
        inc byte [lives]
.done:  ret

; DrawHUD - Module 13. Reads score, coins, lives, HP, clock.
; Outputs: 16-pixel HUD in frame buffer; changes no registers.
; Reuses the stack-based BIOS-font routines in text.asm.
%macro hud_text 3
        push word %1
        push word %2
        push word %3
        push word COL_TEXT
        push word 1
        call TxtStr
%endmacro
%macro hud_num 3
        push word %1
        push word 8
        push word %2
        push word %3
        push word COL_TEXT
        push word 1
        call TxtNum
%endmacro
DrawHUD:
        push ax
        push word 0
        push word 0
        push word SCREEN_W
        push word HUD_H
        push word COL_BLACK
        call FillRect
        hud_text 0,0,hud_score
        hud_text 64,0,hud_coins
        hud_text 120,0,hud_world
        hud_text 176,0,hud_time
        hud_text 224,0,hud_lives
        hud_text 272,0,hud_health
        push word 0
        push word 8
        push word [score_lo]
        push word [score_hi]
        push word COL_TEXT
        push word 1
        call TxtNum32
        hud_text 64,8,hud_x
        xor ax, ax
        mov al, [coins]
        hud_num 72,ax,2
        hud_text 120,8,hud_worldnum
        hud_num 176,[clock_secs],3
        hud_text 224,8,hud_x
        xor ax, ax
        mov al, [lives]
        hud_num 232,ax,2
        mov ax, spr_heart_empty
        cmp byte [hero_hp], 1
        jb .heart1
        mov ax, spr_heart_full
.heart1: push word 280
        push word 8
        push ax
        push word 0
        call DrawSprite
        mov ax, spr_heart_empty
        cmp byte [hero_hp], 2
        jb .heart2
        mov ax, spr_heart_full
.heart2: push word 296
        push word 8
        push ax
        push word 0
        call DrawSprite
        pop ax
        ret
%unmacro hud_text 3
%unmacro hud_num 3
hud_score db 'SCORE',0
hud_coins db 'COINS',0
hud_world db 'WORLD',0
hud_time db 'TIME',0
hud_lives db 'LIVES',0
hud_health db 'HP',0
hud_x db 'x',0
hud_worldnum db '1-1',0

%include "src/sprites.inc"
