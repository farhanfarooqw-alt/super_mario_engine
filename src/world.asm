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

; DrawMap     draws the visible part using camera_x   Module 3 / 6
DrawMap:
    ret

; ResetMap    map_original -> map_working with REP MOVSB/W   Module 3
ResetMap:
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
