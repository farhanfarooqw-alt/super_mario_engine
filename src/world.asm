; ============================================================
; world.asm  -  PERSON 2  (Modules 3, 4, 6, 13)
; Stubs for now. Convention: see docs/CONVENTIONS.md
; ============================================================

; NOTE: PutPixel and FillRect (Module 2) are written by Person 1 in engine.asm.
; Every drawing procedure draws into the FRAME BUFFER, never into A000h.

; GetTile(px, py)  -> AX = tile code           Module 3
;   [bp+6]=px  [bp+4]=py   (pixel position in the WORLD)
GetTile:
    push bp
    mov bp, sp
    xor ax, ax
    pop bp
    ret 4

; SetTile(col, row, code)                      Module 3 (working map)
;   [bp+8]=col [bp+6]=row [bp+4]=code
SetTile:
    push bp
    mov bp, sp
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
