; ============================================================
; world.asm  -  PERSON 2  (Modules 3, 4, 6, 13)
; Stubs for now. Convention: see docs/CONVENTIONS.md
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
; Purpose : draw ONE 16x16 tile into the frame buffer at screen
;           position (x, y) (top-left, signed, may be partly off-
;           screen: FillRect clips). For now a tile is a coloured
;           rectangle taken from tile_colour (looked up by tile
;           code); Module 4 replaces it with real art.
;           Sky is not drawn (ClearBuffer already made the sky).
; Inputs  : [bp+8] = x   [bp+6] = y   [bp+4] = tile code
; Outputs : none
; Changes : none (AX, BX are saved and restored)
; ------------------------------------------------------------
DrawTile:
        push bp
        mov bp, sp
        push ax
        push bx
        mov bx, [bp+4]              ; tile code
        cmp bx, T_SKY
        je .out                     ; sky: nothing to draw
        cmp bx, T_FLAG
        ja .out                     ; unknown code: ignore (unsigned)
        mov al, [tile_colour+bx]    ; colour index for this tile
        xor ah, ah
        push word [bp+8]            ; x
        push word [bp+6]            ; y
        push word TILE              ; w
        push word TILE              ; h
        push ax                     ; colour
        call FillRect
.out:   pop bx
        pop ax
        pop bp
        ret 6

; tile_colour : default-palette colour for each tile code 0..12
;   sky ground brick ?coin ?mush empty pipeTL pipeTR pipeBL pipeBR stair coin flag
tile_colour:
        db COL_SKY, COL_GROUND, COL_BRICK, 12, 12, 8, 10, 10, COL_PIPE, COL_PIPE, 7, COL_COIN, COL_TEXT

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

; DrawSprite(x, y, addr, flags)                Module 4
;   [bp+10]=x [bp+8]=y [bp+6]=addr [bp+4]=flags (bit0 = mirror)
DrawSprite:
    push bp
    mov bp, sp
    pop bp
    ret 8

; UpdateCamera    rule of Section 5.3, once per frame   Module 6
UpdateCamera:
    ret

; AddScore(points)    32-bit ADD/ADC, clamp 999,999     Module 13
;   [bp+4]=points (word)
AddScore:
    push bp
    mov bp, sp
    pop bp
    ret 2

; DrawHUD     score, coins, world, time, lives, hearts  Module 13
DrawHUD:
    ret
