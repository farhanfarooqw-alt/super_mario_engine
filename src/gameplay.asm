; ============================================================
; gameplay.asm  -  PERSON 3  (Modules 9, 10, 11, 12)
; Stubs for now. Convention: see docs/CONVENTIONS.md
; ============================================================

; UpdateMario     Module 9 + 10
;   keys -> speed -> gravity -> jump -> move X then Y with tile collision
UpdateMario:
    ret

; RectOverlap(x1, y1, w1, h1, x2, y2, w2, h2)  -> AX = 1 overlap, 0 no
;   [bp+18]=x1 [bp+16]=y1 [bp+14]=w1 [bp+12]=h1
;   [bp+10]=x2 [bp+8]=y2  [bp+6]=w2  [bp+4]=h2
RectOverlap:
    push bp
    mov bp, sp
    xor ax, ax
    pop bp
    ret 16

; UpdateEnemies   Goombas, Koopas, shells, mushrooms     Module 11 + 12
UpdateEnemies:
    ret

; ResolveCollisions   Mario vs enemies/items/blocks (Section 5.6 order)
ResolveCollisions:
    ret
