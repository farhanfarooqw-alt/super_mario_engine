; ============================================================
; gameplay.asm  -  PERSON 3  (Modules 9, 10, 11, 12)
; Convention: see docs/CONVENTIONS.md  (stack parameters pushed left
; to right, callee does "ret 2*n", result in AX, registers that are
; not returned are preserved).
;
; Contents
;   Module 9  : ResetHero, UpdateMario (HeroHorizontal, HeroVertical)
;   Module 10 : tile collision (HeroXCollide, HeroYCollide), RectOverlap
;   Module 11 : ResetEnemies, UpdateEnemies, ResolveCollisions
;   Module 12 : blocks, coins, mushroom, flag pole
;   Drawing   : DrawHero, DrawEntities (Person 2 sprite renderer)
; ============================================================

; ---- private constants of Person 3 ----
HITBOX_L        equ 2               ; hitbox is 12 wide, centred in 16
HITBOX_R        equ 13              ; last pixel column of the hitbox
HITBOX_W        equ 12
ET_NONE         equ 0               ; enemy record types (EN_TYPE)
ET_GOOMBA       equ 1
ET_KOOPA        equ 2
ET_MUSH         equ 3
ES_IDLE         equ 0               ; enemy record states (EN_STATE)
ES_WALK         equ 1               ; walking (EN_TIMER = fraction byte)
ES_FLAT         equ 2               ; flat Goomba (EN_TIMER counts down)
ES_SHELL        equ 3               ; stationary shell (EN_TIMER = grace)
ES_SLIDE        equ 4               ; sliding shell (EN_TIMER = grace)
ENEMY_FALL      equ 2               ; enemies fall 2 pixels per frame

; ------------------------------------------------------------
; ResetHero
; Purpose : put Mario at the level start as Small Mario (form 0,
;           hp 1) with his FEET on the ground (feet-fixed rule:
;           y_top = y_feet - height, height of Small = 16).
;           Speeds, stomp chain, invulnerability and the shared
;           flags hero_dead / level_won are cleared.
; Inputs  : none
; Outputs : none (writes the hero variables of data.inc)
; Registers changed : none (only "mov memory, constant" is used)
; ------------------------------------------------------------
ResetHero:
    mov word [hero_x], START_X          ; whole pixels of x
    mov byte [hero_x_fr], 0             ; fraction of x
    mov word [hero_y], START_Y_FEET-TILE ; top = feet - 16
    mov byte [hero_y_fr], 0             ; fraction of y
    mov word [hero_vx], 0               ; not moving sideways
    mov word [hero_vy], 0               ; not moving up/down
    mov byte [hero_on_ground], 1        ; standing on the ground
    mov byte [hero_form], FORM_SMALL    ; Small Mario
    mov byte [hero_hp], 1               ; health 1
    mov byte [hero_face], 1             ; facing right
    mov word [hero_invuln], 0           ; not blinking
    mov word [hero_stomp], 0            ; stomp chain 0
    mov byte [hero_dead], 0             ; alive
    mov byte [level_won], 0             ; flag not touched
    ret

; ------------------------------------------------------------
; HeroHeight
; Purpose : height of Mario's sprite and hitbox for his form.
; Inputs  : none
; Outputs : AX = 16 (Small) or 32 (Super)
; Registers changed : AX
; ------------------------------------------------------------
HeroHeight:
    mov ax, TILE
    cmp byte [hero_form], FORM_SUPER
    jne .done
    mov ax, 2*TILE
.done:
    ret

; ------------------------------------------------------------
; UpdateMario     Module 9 + 10  (frame step 3)
; Purpose : one frame of Mario's movement. Order (Manual 5.6 tip):
;           X axis first (speed, move, wall collision), then the
;           Y axis (jump, gravity, move, floor / head collision).
;           Also counts the invulnerability timer down once per
;           frame, and remembers where the feet were BEFORE the
;           move (needed by the stomp test in ResolveCollisions).
; Inputs  : none (reads the keys through IsKeyDown)
; Outputs : none (writes the hero variables)
; Registers changed : none
; ------------------------------------------------------------
UpdateMario:
    push ax
    cmp word [hero_invuln], 0
    je .noinv
    dec word [hero_invuln]          ; blinking time runs out
.noinv:
    call HeroHeight
    add ax, [hero_y]                ; feet = top + height
    mov [p3_prev_feet], ax          ; feet of the previous frame
    call HeroHorizontal
    call HeroXCollide
    call HeroVertical
    call HeroYCollide
    pop ax
    ret

; ------------------------------------------------------------
; HeroHorizontal
; Purpose : Manual 5.2 walk / run / stop / brake / facing, then
;           move hero_x by the velocity (8.8 fixed point).
;   - Right (or Left) held : accelerate by ACCEL_WALK; if Mario is
;     moving the OTHER way, brake with twice the acceleration.
;   - Speed limit = MAX_WALK, or MAX_RUN while Left Shift is held.
;   - No direction (or both held): friction pulls speed to 0.
;   - Position = whole pixels + fraction byte: the fraction of the
;     velocity is added to hero_x_fr and the carry goes to hero_x.
;   - Mario cannot go past either end of the level (0 .. 944).
; Inputs  : none      Outputs : hero_vx, hero_x, hero_x_fr, hero_face
; Registers changed : none
; ------------------------------------------------------------
HeroHorizontal:
    push ax
    push bx
    push cx
    push dx
    mov bx, MAX_WALK                ; BX = speed limit
    push word SC_LSHIFT
    call IsKeyDown
    test ax, ax
    jz .gotmax
    mov bx, MAX_RUN                 ; Shift held: run limit
.gotmax:
    xor cx, cx                      ; CX = direction: right - left
    push word SC_RIGHT
    call IsKeyDown
    add cx, ax
    push word SC_LEFT
    call IsKeyDown
    sub cx, ax                      ; +1 right, -1 left, 0 none/both
    mov ax, [hero_vx]               ; AX = current speed (signed 8.8)
    cmp cx, 0
    jg .right
    jl .left
    cmp ax, 0                       ; no direction: friction
    jg .fricpos
    jl .fricneg
    jmp .store                      ; already 0
.fricpos:
    sub ax, FRICTION
    jge .store                      ; still >= 0
    xor ax, ax                      ; passed zero: stop
    jmp .store
.fricneg:
    add ax, FRICTION
    jle .store                      ; still <= 0
    xor ax, ax
    jmp .store
.right:
    mov byte [hero_face], 1         ; face right
    mov dx, ACCEL_WALK
    cmp ax, 0
    jge .raccel
    mov dx, ACCEL_WALK*2            ; moving left: brake faster
.raccel:
    add ax, dx
    cmp ax, bx
    jle .store
    mov ax, bx                      ; clamp to the limit
    jmp .store
.left:
    mov byte [hero_face], 0         ; face left
    mov dx, ACCEL_WALK
    cmp ax, 0
    jle .laccel
    mov dx, ACCEL_WALK*2            ; moving right: brake faster
.laccel:
    sub ax, dx
    neg bx                          ; BX = -limit
    cmp ax, bx
    jge .store
    mov ax, bx                      ; clamp to -limit
.store:
    mov [hero_vx], ax
    mov bx, ax                      ; BL = fraction part of the speed
    sar ax, 8                       ; AX = whole pixels (signed)
    add bl, [hero_x_fr]             ; fraction + fraction, carry out
    mov [hero_x_fr], bl
    adc ax, 0                       ; carry becomes one more pixel
    add [hero_x], ax
    mov ax, [hero_x]                ; keep Mario inside the level
    cmp ax, 0
    jge .lowok
    mov word [hero_x], 0
    mov word [hero_vx], 0
    mov byte [hero_x_fr], 0
    jmp .done
.lowok:
    cmp ax, LEVEL_PX-TILE
    jle .done
    mov word [hero_x], LEVEL_PX-TILE
    mov word [hero_vx], 0
    mov byte [hero_x_fr], 0
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; HeroVertical
; Purpose : Manual 5.2 jump, variable jump height and gravity, then
;           move hero_y by the vertical velocity (8.8 fixed point).
;   1. Jump: Space held AND Mario on the ground -> vy = JUMP_START
;      (no double jump: in the air on_ground is 0).
;   2. Variable height: while rising (vy < 0), if Space is released
;      and vy is faster than JUMP_CUTOFF, vy = JUMP_CUTOFF.
;   3. Gravity: vy += GRAVITY, never more than MAX_FALL.
;   4. Move: whole pixels = vy >> 8, fraction added with carry.
;   The floor / head collision is done afterwards by HeroYCollide.
; Inputs  : none      Outputs : hero_vy, hero_y, hero_y_fr,
;                               hero_on_ground
; Registers changed : none
; ------------------------------------------------------------
HeroVertical:
    push ax
    push bx
    cmp byte [hero_on_ground], 0    ; jump only from the ground
    je .nojump
    push word SC_SPACE
    call IsKeyDown
    test ax, ax
    jz .nojump
    mov word [hero_vy], JUMP_START  ; big upward speed (-5.5)
    mov byte [hero_on_ground], 0
.nojump:
    cmp word [hero_vy], 0           ; rising only (vy < 0)
    jge .gravity
    cmp word [hero_vy], JUMP_CUTOFF
    jge .gravity                    ; already slower than the cut-off
    push word SC_SPACE
    call IsKeyDown
    test ax, ax
    jnz .gravity                    ; Space still held: keep rising
    mov word [hero_vy], JUMP_CUTOFF ; Space released: cut the jump
.gravity:
    mov ax, [hero_vy]
    add ax, GRAVITY                 ; pull down every frame
    cmp ax, MAX_FALL
    jle .gok
    mov ax, MAX_FALL                ; limit the falling speed
.gok:
    mov [hero_vy], ax
    mov bx, ax                      ; BL = fraction part of vy
    sar ax, 8                       ; AX = whole pixels (signed)
    add bl, [hero_y_fr]
    mov [hero_y_fr], bl
    adc ax, 0                       ; carry = one more pixel
    add [hero_y], ax
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; TileSolid(px, py)
; Purpose : is the tile under the WORLD pixel (px, py) solid?
;           Solid = codes 1..10 (ground, bricks, ? blocks, empty
;           block, pipes, stairs). Sky, coin and flag are not solid.
; Inputs  : [bp+6] = px   [bp+4] = py   (both signed)
; Outputs : AX = 1 solid, 0 not solid
; Registers changed : AX
; ------------------------------------------------------------
TileSolid:
    push bp
    mov bp, sp
    push word [bp+6]
    push word [bp+4]
    call GetTile                    ; AX = tile code
    cmp ax, T_GROUND
    jb .no                          ; 0 = sky
    cmp ax, T_STAIR
    ja .no                          ; 11 = coin, 12 = flag
    mov ax, 1
    jmp .out
.no:
    xor ax, ax
.out:
    pop bp
    ret 4

; ------------------------------------------------------------
; HeroColumnSolid(px)
; Purpose : is any tile solid in the vertical line x = px, from the
;           top of Mario's hitbox to its bottom pixel? Samples are
;           taken every 16 pixels (a 16 or 32 high box touches at
;           most 3 tile rows), plus the bottom pixel.
; Inputs  : [bp+4] = px (world x)
; Outputs : AX = 1 if a solid tile was found, else 0
; Registers changed : AX
; ------------------------------------------------------------
HeroColumnSolid:
    push bp
    mov bp, sp
    push cx
    push dx
    call HeroHeight
    mov cx, [hero_y]                ; CX = y of the current sample
    mov dx, cx
    add dx, ax
    dec dx                          ; DX = bottom pixel row
.loop:
    push word [bp+4]
    push cx
    call TileSolid
    test ax, ax
    jnz .out                        ; AX = 1: found
    cmp cx, dx
    jge .out                        ; bottom sample done, AX = 0
    add cx, TILE
    cmp cx, dx
    jle .loop
    mov cx, dx                      ; last sample: the bottom pixel
    jmp .loop
.out:
    pop dx
    pop cx
    pop bp
    ret 2

; ------------------------------------------------------------
; HeroRowSolid(py)
; Purpose : is a tile solid under the left or the right edge pixel
;           of Mario's hitbox on the world row y = py?
; Inputs  : [bp+4] = py (world y)
; Outputs : AX = 1 if solid at the left or right edge, else 0
; Registers changed : AX
; ------------------------------------------------------------
HeroRowSolid:
    push bp
    mov bp, sp
    mov ax, [hero_x]
    add ax, HITBOX_L
    push ax
    push word [bp+4]
    call TileSolid
    test ax, ax
    jnz .out
    mov ax, [hero_x]
    add ax, HITBOX_R
    push ax
    push word [bp+4]
    call TileSolid
.out:
    pop bp
    ret 2

; ------------------------------------------------------------
; HeroXCollide
; Purpose : wall collision after the X move (Manual 5.6 "Wall in
;           front"). Moving right: test the right edge column; moving
;           left: the left edge column. If solid, put Mario against
;           the wall (edge just outside the tile) and set vx = 0.
; Inputs  : none      Outputs : hero_x, hero_x_fr, hero_vx
; Registers changed : none
; ------------------------------------------------------------
HeroXCollide:
    push ax
    push bx
    cmp word [hero_vx], 0
    je .done
    jl .left
    mov bx, [hero_x]
    add bx, HITBOX_R                ; BX = x of the right edge
    push bx
    call HeroColumnSolid
    test ax, ax
    jz .done
    and bx, 0FFF0h                  ; left side of the tile column
    sub bx, HITBOX_R+1              ; right edge = tile left - 1
    mov [hero_x], bx
    jmp .stop
.left:
    mov bx, [hero_x]
    add bx, HITBOX_L                ; BX = x of the left edge
    push bx
    call HeroColumnSolid
    test ax, ax
    jz .done
    and bx, 0FFF0h                  ; left side of the tile column
    add bx, TILE-HITBOX_L           ; left edge = tile right side
    mov [hero_x], bx
.stop:
    mov byte [hero_x_fr], 0
    mov word [hero_vx], 0
.done:
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; HeroYCollide
; Purpose : floor and head collision after the Y move.
;   Falling (or standing, vy >= 0): look at the pixel line just
;     under the feet; if solid, put Mario on top of the tile,
;     vy = 0, on_ground = 1, stomp chain = 0 (landing).
;     Probing the line UNDER the feet keeps on_ground = 1 on
;     the frames when gravity moves less than a whole pixel.
;   Rising (vy < 0): look at the top row of the hitbox; if solid,
;     trigger the block under the head centre (Module 12), put the
;     head under the tile and set vy = 0 (he starts falling).
; Inputs  : none
; Outputs : hero_y, hero_y_fr, hero_vy, hero_on_ground, hero_stomp
; Registers changed : none
; ------------------------------------------------------------
HeroYCollide:
    push ax
    push bx
    push cx
    call HeroHeight
    mov cx, ax                      ; CX = height
    cmp word [hero_vy], 0
    jl .rising
    mov bx, [hero_y]
    add bx, cx                      ; BX = pixel line under the feet
    push bx
    call HeroRowSolid
    test ax, ax
    jz .air
    and bx, 0FFF0h                  ; top of that tile row
    sub bx, cx                      ; y_top = tile_top - height
    mov [hero_y], bx
    mov byte [hero_y_fr], 0
    mov word [hero_vy], 0
    mov byte [hero_on_ground], 1
    mov word [hero_stomp], 0        ; landing resets the stomp chain
    jmp .done
.air:
    mov byte [hero_on_ground], 0
    jmp .done
.rising:
    mov byte [hero_on_ground], 0
    mov bx, [hero_y]                ; BX = top row of the head
    push bx
    call HeroRowSolid
    test ax, ax
    jz .done
    call HeadHitBlock               ; Module 12: trigger the block
    mov bx, [hero_y]
    and bx, 0FFF0h
    add bx, TILE                    ; head just under the tile
    mov [hero_y], bx
    mov byte [hero_y_fr], 0
    mov word [hero_vy], 0
.done:
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; RectOverlap(x1, y1, w1, h1, x2, y2, w2, h2)
; Purpose : do two rectangles overlap? (Module 10)
;           Overlap if x1 < x2+w2 and x2 < x1+w1 and
;                      y1 < y2+h2 and y2 < y1+h1   (signed compares)
; Inputs  : [bp+18]=x1 [bp+16]=y1 [bp+14]=w1 [bp+12]=h1
;           [bp+10]=x2 [bp+8]=y2  [bp+6]=w2  [bp+4]=h2
; Outputs : AX = 1 overlap, 0 no overlap
; Registers changed : AX
; ------------------------------------------------------------
RectOverlap:
    push bp
    mov bp, sp
    mov ax, [bp+10]                 ; x2
    add ax, [bp+6]                  ; x2 + w2
    cmp [bp+18], ax                 ; x1 < x2 + w2 ?
    jge .no
    mov ax, [bp+18]
    add ax, [bp+14]                 ; x1 + w1
    cmp [bp+10], ax                 ; x2 < x1 + w1 ?
    jge .no
    mov ax, [bp+8]
    add ax, [bp+4]                  ; y2 + h2
    cmp [bp+16], ax                 ; y1 < y2 + h2 ?
    jge .no
    mov ax, [bp+16]
    add ax, [bp+12]                 ; y1 + h1
    cmp [bp+8], ax                  ; y2 < y1 + h1 ?
    jge .no
    mov ax, 1
    jmp .out
.no:
    xor ax, ax
.out:
    pop bp
    ret 16

; ============================================================
; MODULE 12 - blocks, coins, mushroom
; ============================================================

; ------------------------------------------------------------
; HeadHitBlock
; Purpose : Mario's head hit a solid tile. Use the tile under the
;           horizontal centre of the head (Manual 5.9): column =
;           (hero_x + 8) / 16, row = hero_y / 16, then HitBlock.
; Inputs  : none      Outputs : none
; Registers changed : none
; ------------------------------------------------------------
HeadHitBlock:
    push ax
    push bx
    mov ax, [hero_x]
    add ax, TILE/2                  ; horizontal centre of the head
    shr ax, TILE_SHIFT              ; column
    mov bx, [hero_y]
    shr bx, TILE_SHIFT              ; row
    push ax
    push bx
    call HitBlock
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; HitBlock(col, row)
; Purpose : what a head hit does to the tile at (col, row):
;   brick    : Small = nothing; Super = tile becomes sky, +50
;   ? coin   : tile becomes an empty block, coin pops out (+200)
;   ? mushr. : tile becomes an empty block, mushroom appears on top
;   others   : nothing.   Only map_working changes (SetTile).
; Inputs  : [bp+6] = col   [bp+4] = row
; Outputs : none
; Registers changed : none
; ------------------------------------------------------------
HitBlock:
    push bp
    mov bp, sp
    push ax
    push bx
    mov ax, [bp+6]
    shl ax, TILE_SHIFT              ; world x of the tile
    mov bx, [bp+4]
    shl bx, TILE_SHIFT              ; world y of the tile
    push ax
    push bx
    call GetTile                    ; AX = tile code
    cmp ax, T_BRICK
    je .brick
    cmp ax, T_QCOIN
    je .qcoin
    cmp ax, T_QMUSH
    je .qmush
    jmp .out
.brick:
    cmp byte [hero_form], FORM_SUPER
    jne .out                        ; Small Mario: nothing
    push word [bp+6]
    push word [bp+4]
    push word T_SKY                 ; the brick is destroyed
    call SetTile
    push word 50
    call GivePoints
    jmp .out
.qcoin:
    push word [bp+6]
    push word [bp+4]
    push word T_EMPTY               ; used block
    call SetTile
    call GiveCoin                   ; +200 and one coin
    mov ax, [bp+6]
    shl ax, TILE_SHIFT
    mov [p3_pop_x], ax              ; little coin that pops out
    mov ax, [bp+4]
    dec ax
    shl ax, TILE_SHIFT
    mov [p3_pop_y], ax
    mov byte [p3_pop_t], 16
    jmp .out
.qmush:
    push word [bp+6]
    push word [bp+4]
    push word T_EMPTY               ; used block
    call SetTile
    push word [bp+6]
    push word [bp+4]
    call SpawnMushroom
.out:
    pop bx
    pop ax
    pop bp
    ret 4

; ------------------------------------------------------------
; SpawnMushroom(col, row)
; Purpose : put a mushroom on top of the block at (col, row): take
;           the first free enemy record (type 0), type = mushroom,
;           state = walking, x = col*16, y = (row-1)*16, speed =
;           MUSH_SPEED, direction = right. If the table is full
;           nothing happens.
; Inputs  : [bp+6] = col   [bp+4] = row
; Outputs : none
; Registers changed : none
; ------------------------------------------------------------
SpawnMushroom:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    mov bx, enemy_table             ; BX = address of a record
    mov cx, ENEMY_COUNT
.find:
    cmp byte [bx+EN_TYPE], ET_NONE
    je .found
    add bx, ENEMY_SIZE
    loop .find
    jmp .out                        ; table full
.found:
    mov byte [bx+EN_TYPE], ET_MUSH
    mov byte [bx+EN_STATE], ES_WALK
    mov ax, [bp+6]
    shl ax, TILE_SHIFT
    mov [bx+EN_X], ax
    mov ax, [bp+4]
    dec ax                          ; the tile above the block
    shl ax, TILE_SHIFT
    mov [bx+EN_Y], ax
    mov word [bx+EN_SPEED], MUSH_SPEED
    mov byte [bx+EN_DIR], 1         ; moves right
    mov byte [bx+EN_TIMER], 0
.out:
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4

; ------------------------------------------------------------
; GivePoints(points) - add points through the shared 32-bit score.
; Inputs: [bp+4] points. Outputs: score. Registers changed: none.
; ------------------------------------------------------------
GivePoints:
    push bp
    mov bp, sp
    push word [bp+4]
    call AddScore
    pop bp
    ret 2

; GiveCoin - +200 points and one coin, using Person 2 counters.
; Inputs: none. Outputs: score, coins, lives. Registers changed: none.
GiveCoin:
    push word 200
    call GivePoints
    call AddCoin
    ret

; GiveLife - extra life, capped by Person 2's AddLife.
; Inputs: none. Outputs: lives. Registers changed: none.
GiveLife:
    call AddLife
    ret

; ------------------------------------------------------------
; HeroGrow
; Purpose : mushroom collected. Small becomes Super (hp 2) with the
;           FEET FIXED: the sprite gets 16 higher, so the top moves
;           up by 16 (y_top = y_feet - 32). Already Super: nothing
;           (hp never exceeds 2).
; Inputs  : none      Outputs : none      Registers changed : none
; ------------------------------------------------------------
HeroGrow:
    cmp byte [hero_form], FORM_SUPER
    je .done
    mov byte [hero_form], FORM_SUPER
    mov byte [hero_hp], 2
    sub word [hero_y], TILE
.done:
    ret

; ------------------------------------------------------------
; HeroHurt
; Purpose : Mario touched something dangerous (Manual 5.7).
;           Invulnerable: nothing. Super: becomes Small with the feet
;           fixed (top moves down 16), 2 s invulnerability. Small:
;           hero_dead = 1 (Person 1 runs the death sequence).
; Inputs  : none      Outputs : none      Registers changed : none
; ------------------------------------------------------------
HeroHurt:
    cmp word [hero_invuln], 0
    jne .done
    cmp byte [hero_form], FORM_SUPER
    jne .die
    mov byte [hero_form], FORM_SMALL
    mov byte [hero_hp], 1
    add word [hero_y], TILE         ; feet fixed: top moves down
    mov word [hero_invuln], INVULN_FRAMES
    jmp .done
.die:
    mov byte [hero_dead], 1
.done:
    ret

; ============================================================
; MODULE 11 - enemies and shells
; ============================================================

; ------------------------------------------------------------
; ResetEnemies
; Purpose : clear the enemy table (REP STOSW) and load it from the
;           enemy_spawns list of level.inc: type, state idle, x, y,
;           speed (Goomba or Koopa speed), direction left, timer 0.
;           Also stops a coin pop-up that is still on screen.
; Inputs  : none      Outputs : enemy_table
; Registers changed : none
; ------------------------------------------------------------
ResetEnemies:
    push ax
    push bx
    push cx
    push si
    push di
    push es
    push ds
    pop es                          ; ES = DS (one segment)
    mov di, enemy_table
    mov cx, ENEMY_COUNT*ENEMY_SIZE/2
    xor ax, ax
    cld
    rep stosw                       ; clear all records
    mov byte [p3_pop_t], 0
    mov si, enemy_spawns            ; DS:SI walks the spawn list
    mov bx, enemy_table             ; BX = record being filled
.next:
    cmp bx, enemy_table+ENEMY_COUNT*ENEMY_SIZE
    jae .done                       ; table full
    lodsb                           ; AL = type, 0 = end marker
    test al, al
    jz .done
    mov [bx+EN_TYPE], al
    mov byte [bx+EN_STATE], ES_IDLE
    lodsw
    mov [bx+EN_X], ax
    lodsw
    mov [bx+EN_Y], ax
    mov word [bx+EN_SPEED], GOOMBA_SPEED
    cmp byte [bx+EN_TYPE], ET_KOOPA
    jne .dirset
    mov word [bx+EN_SPEED], KOOPA_SPEED
.dirset:
    mov byte [bx+EN_DIR], 0         ; starts walking left
    mov byte [bx+EN_TIMER], 0
    add bx, ENEMY_SIZE
    jmp .next
.done:
    pop es
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; CountActive
; Purpose : how many records are active (type used, not idle)?
;           Used for the "at most 8 enemies" rule.
; Inputs  : none
; Outputs : AX = number of active records
; Registers changed : AX
; ------------------------------------------------------------
CountActive:
    push bx
    push cx
    xor ax, ax
    mov bx, enemy_table
    mov cx, ENEMY_COUNT
.l:
    cmp byte [bx+EN_TYPE], ET_NONE
    je .n
    cmp byte [bx+EN_STATE], ES_IDLE
    je .n
    inc ax
.n:
    add bx, ENEMY_SIZE
    loop .l
    pop cx
    pop bx
    ret

; ------------------------------------------------------------
; UpdateEnemies   (frame step 4)
; Purpose : walk through the table and update every used record;
;           also moves the coin pop-up.
; Inputs  : none      Outputs : enemy_table
; Registers changed : none
; ------------------------------------------------------------
UpdateEnemies:
    push bx
    push cx
    cmp byte [p3_pop_t], 0
    je .nopop
    dec byte [p3_pop_t]
    sub word [p3_pop_y], 2          ; the coin rises
.nopop:
    mov bx, enemy_table
    mov cx, ENEMY_COUNT
.l:
    cmp byte [bx+EN_TYPE], ET_NONE
    je .n
    push bx
    call EnemyUpdate
.n:
    add bx, ENEMY_SIZE
    loop .l
    pop cx
    pop bx
    ret

; ------------------------------------------------------------
; EnemyUpdate(record)
; Purpose : one record. Remove it if it is more than 32 pixels left
;           of the camera or below the map; otherwise act by state:
;           idle = wait for activation, flat = count down, else move.
; Inputs  : [bp+4] = address of the record
; Outputs : record changed      Registers changed : none
; ------------------------------------------------------------
EnemyUpdate:
    push bp
    mov bp, sp
    push ax
    push bx
    mov bx, [bp+4]
    mov ax, [bx+EN_X]
    sub ax, [camera_x]              ; screen x
    cmp ax, -32
    jl .remove                      ; far left of the camera
    cmp word [bx+EN_Y], MAP_H*TILE
    jg .remove                      ; fell below the map
    mov al, [bx+EN_STATE]
    cmp al, ES_IDLE
    je .idle
    cmp al, ES_FLAT
    je .flat
    push bx
    call EnemyMove
    jmp .out
.idle:
    push bx
    call EnemyIdle
    jmp .out
.flat:
    push bx
    call EnemyFlat
    jmp .out
.remove:
    mov byte [bx+EN_TYPE], ET_NONE
.out:
    pop bx
    pop ax
    pop bp
    ret 2

; ------------------------------------------------------------
; EnemyIdle(record)
; Purpose : an idle enemy stands still until it is within one tile
;           of the visible screen (screen x < 336); then it starts
;           walking, but only while fewer than 8 are active.
; Inputs  : [bp+4] = address of the record      Registers changed : none
; ------------------------------------------------------------
EnemyIdle:
    push bp
    mov bp, sp
    push ax
    push bx
    mov bx, [bp+4]
    mov ax, [bx+EN_X]
    sub ax, [camera_x]
    cmp ax, SCREEN_W+TILE
    jge .out                        ; still too far to the right
    call CountActive
    cmp ax, MAX_ACTIVE_ENEMIES
    jae .out                        ; already 8 active
    mov byte [bx+EN_STATE], ES_WALK
.out:
    pop bx
    pop ax
    pop bp
    ret 2

; ------------------------------------------------------------
; EnemyFlat(record)
; Purpose : flat Goomba: count EN_TIMER down; at 0 remove it.
; Inputs  : [bp+4] = address of the record      Registers changed : none
; ------------------------------------------------------------
EnemyFlat:
    push bp
    mov bp, sp
    push bx
    mov bx, [bp+4]
    dec byte [bx+EN_TIMER]
    jnz .out
    mov byte [bx+EN_TYPE], ET_NONE
.out:
    pop bx
    pop bp
    ret 2

; ------------------------------------------------------------
; EnemyMove(record)
; Purpose : walking enemy, stationary shell, sliding shell or
;           mushroom: horizontal step (not for a stationary shell)
;           and then gravity. For shells EN_TIMER is the kick grace
;           and is counted down here.
; Inputs  : [bp+4] = address of the record      Registers changed : none
; ------------------------------------------------------------
EnemyMove:
    push bp
    mov bp, sp
    push ax
    push bx
    mov bx, [bp+4]
    mov al, [bx+EN_STATE]
    cmp al, ES_WALK
    je .horiz
    cmp byte [bx+EN_TIMER], 0       ; shell: count the grace down
    je .nograce
    dec byte [bx+EN_TIMER]
.nograce:
    cmp al, ES_SLIDE
    jne .fall                       ; stationary shell: no walking
.horiz:
    push bx
    call EnemyWalkX
.fall:
    push bx
    call EnemyFall
    pop bx
    pop ax
    pop bp
    ret 2

; ------------------------------------------------------------
; EnemyWalkX(record)
; Purpose : horizontal move of a walking enemy, sliding shell or
;           mushroom by its speed (8.8). Walking: the fraction is
;           kept in EN_TIMER (0.5 px/frame = 1 pixel every 2nd
;           frame); sliding: whole pixels only.
;           The enemy TURNS (no move this frame) when
;             - a solid tile is in front (probe at mid height),
;             - Koopa walking on the ground has no ground in front,
;             - a Goomba/Koopa walking would overlap another enemy.
; Inputs  : [bp+4] = address of the record      Registers changed : none
; ------------------------------------------------------------
EnemyWalkX:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    mov bx, [bp+4]
    mov ax, [bx+EN_SPEED]           ; AH = whole pixels, AL = fraction
    xor dx, dx
    mov dl, ah                      ; DX = whole pixels per frame
    cmp byte [bx+EN_STATE], ES_WALK
    jne .step                       ; sliding shell: no fraction
    add al, [bx+EN_TIMER]           ; fraction accumulator, carry out
    mov [bx+EN_TIMER], al
    adc dx, 0                       ; carry = one more pixel
.step:
    mov cx, [bx+EN_X]
    cmp byte [bx+EN_DIR], 0
    je .goleft
    add cx, dx                      ; CX = new x (moving right)
    mov si, cx
    add si, TILE-1                  ; SI = probe x: right edge
    jmp .probe
.goleft:
    sub cx, dx                      ; CX = new x (moving left)
    mov si, cx                      ; SI = probe x: left edge
.probe:
    push si
    mov ax, [bx+EN_Y]
    add ax, TILE/2
    push ax
    call TileSolid                  ; wall in front?
    test ax, ax
    jnz .turn
    cmp byte [bx+EN_TYPE], ET_KOOPA
    jne .others
    cmp byte [bx+EN_STATE], ES_WALK
    jne .others
    mov ax, [bx+EN_X]               ; Koopa: standing on ground?
    add ax, TILE/2
    push ax
    mov ax, [bx+EN_Y]
    add ax, TILE
    push ax
    call TileSolid
    test ax, ax
    jz .others                      ; in the air: no edge check
    push si                         ; ground under the front foot?
    mov ax, [bx+EN_Y]
    add ax, TILE
    push ax
    call TileSolid
    test ax, ax
    jz .turn                        ; platform edge: turn round
.others:
    cmp byte [bx+EN_STATE], ES_WALK
    jne .move
    cmp byte [bx+EN_TYPE], ET_MUSH
    je .move
    push bx
    push cx
    call EnemyHitsOther
    test ax, ax
    jnz .turn
.move:
    mov [bx+EN_X], cx
    jmp .out
.turn:
    xor byte [bx+EN_DIR], 1         ; 0 <-> 1
.out:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 2

; ------------------------------------------------------------
; EnemyHitsOther(record, newx)
; Purpose : would this enemy, placed at x = newx, overlap another
;           Goomba/Koopa (walking, shell or sliding; not idle or
;           flat; not itself)?
; Inputs  : [bp+6] = address of the record   [bp+4] = newx
; Outputs : AX = 1 overlap, 0 free      Registers changed : AX
; ------------------------------------------------------------
EnemyHitsOther:
    push bp
    mov bp, sp
    push bx
    push cx
    push si
    mov si, [bp+6]                  ; SI = this record
    mov bx, enemy_table
    mov cx, ENEMY_COUNT
.l:
    cmp bx, si
    je .n                           ; not against itself
    cmp byte [bx+EN_TYPE], ET_NONE
    je .n
    cmp byte [bx+EN_TYPE], ET_MUSH
    jae .n                          ; mushrooms do not block
    cmp byte [bx+EN_STATE], ES_IDLE
    je .n
    cmp byte [bx+EN_STATE], ES_FLAT
    je .n
    push word [bp+4]                ; x1 = new x
    push word [si+EN_Y]
    push word TILE
    push word TILE
    push word [bx+EN_X]
    push word [bx+EN_Y]
    push word TILE
    push word TILE
    call RectOverlap
    test ax, ax
    jnz .out                        ; AX = 1
.n:
    add bx, ENEMY_SIZE
    loop .l
    xor ax, ax
.out:
    pop si
    pop cx
    pop bx
    pop bp
    ret 4

; ------------------------------------------------------------
; EnemyFall(record)
; Purpose : gravity for enemies: look at the pixel line under the
;           centre of the feet. Solid: stand on the tile. Not
;           solid: fall ENEMY_FALL pixels (walks off ledges).
; Inputs  : [bp+4] = address of the record      Registers changed : none
; ------------------------------------------------------------
EnemyFall:
    push bp
    mov bp, sp
    push ax
    push bx
    mov bx, [bp+4]
    mov ax, [bx+EN_X]
    add ax, TILE/2
    push ax
    mov ax, [bx+EN_Y]
    add ax, TILE
    push ax
    call TileSolid
    test ax, ax
    jz .fall
    mov ax, [bx+EN_Y]
    add ax, TILE
    and ax, 0FFF0h                  ; top of the tile under the feet
    sub ax, TILE
    mov [bx+EN_Y], ax
    jmp .out
.fall:
    add word [bx+EN_Y], ENEMY_FALL
.out:
    pop bx
    pop ax
    pop bp
    ret 2

; ============================================================
; ResolveCollisions (frame step 5) - Manual 5.6 order
; ============================================================

; ------------------------------------------------------------
; ResolveCollisions
; Purpose : Mario against enemies, shells, mushrooms, coins, pit
;           and flag pole. Does nothing once hero_dead or level_won
;           is set (Person 1's states take over).
; Inputs  : none      Outputs : score, hero flags, enemy records
; Registers changed : none
; ------------------------------------------------------------
ResolveCollisions:
    cmp byte [hero_dead], 0
    jne .done
    cmp byte [level_won], 0
    jne .done
    mov byte [p3_stomped], 0        ; no stomp yet in this frame
    call ResolveEnemies             ; stomp, hurt, kick, mushroom
    cmp byte [hero_dead], 0
    jne .done
    call ResolveShells              ; sliding shell kills enemies
    call CollectMapCoins            ; coin tiles
    call CheckPit                   ; fell below the map
    cmp byte [hero_dead], 0
    jne .done
    call CheckFlag                  ; flag pole
.done:
    ret

; ------------------------------------------------------------
; ResolveEnemies
; Purpose : run ResolveOne for every active record that can touch
;           Mario (not idle, not a flat Goomba).
; Inputs/Outputs : none      Registers changed : none
; ------------------------------------------------------------
ResolveEnemies:
    push bx
    push cx
    mov bx, enemy_table
    mov cx, ENEMY_COUNT
.l:
    cmp byte [bx+EN_TYPE], ET_NONE
    je .n
    cmp byte [bx+EN_STATE], ES_IDLE
    je .n
    cmp byte [bx+EN_STATE], ES_FLAT
    je .n
    push bx
    call ResolveOne
    cmp byte [hero_dead], 0
    jne .finish
.n:
    add bx, ENEMY_SIZE
    loop .l
.finish:
    pop cx
    pop bx
    ret

; ------------------------------------------------------------
; ResolveOne(record)
; Purpose : Mario against ONE record (Manual 5.6 table).
;   no overlap            : nothing
;   mushroom              : +1000, Small becomes Super, removed
;   stationary shell      : kick +400 (ignored during its grace)
;   sliding shell < grace : ignored
;   stomp test            : Mario moving down AND his feet in the
;                           previous frame above the upper half of
;                           the enemy (or a stomp already happened
;                           this frame)   -> StompEnemy
;   otherwise             : HeroHurt (ignored while invulnerable)
; Inputs  : [bp+4] = address of the record      Registers changed : none
; ------------------------------------------------------------
ResolveOne:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    mov bx, [bp+4]
    call HeroHeight
    mov cx, ax                      ; CX = Mario's height
    mov ax, [hero_x]
    add ax, HITBOX_L
    push ax                         ; x1 = hitbox left
    push word [hero_y]              ; y1
    push word HITBOX_W              ; w1
    push cx                         ; h1
    push word [bx+EN_X]
    push word [bx+EN_Y]
    push word TILE
    push word TILE
    call RectOverlap
    test ax, ax
    jz .out
    cmp byte [bx+EN_TYPE], ET_MUSH
    jne .enemy
    mov byte [bx+EN_TYPE], ET_NONE  ; mushroom collected
    push word 1000
    call GivePoints
    call HeroGrow
    jmp .out
.enemy:
    mov al, [bx+EN_STATE]
    cmp al, ES_SHELL
    jne .notshell
    cmp byte [bx+EN_TIMER], 0
    jne .out                        ; grace: ignore Mario
    push bx
    call KickShell
    jmp .out
.notshell:
    cmp al, ES_SLIDE
    jne .stomptest
    cmp byte [bx+EN_TIMER], 0
    jne .out                        ; just kicked: ignore Mario
.stomptest:
    cmp byte [p3_stomped], 0
    jne .stomp                      ; second enemy of the same stomp
    cmp word [hero_vy], 0
    jle .hurt                       ; not moving down
    mov ax, [bx+EN_Y]
    add ax, TILE/2                  ; middle line of the enemy
    cmp [p3_prev_feet], ax
    jg .hurt                        ; feet were below the upper half
.stomp:
    push bx
    call StompEnemy
    jmp .out
.hurt:
    call HeroHurt
.out:
    pop cx
    pop bx
    pop ax
    pop bp
    ret 2

; ------------------------------------------------------------
; StompEnemy(record)
; Purpose : Mario stomps this enemy: chain points (or 1-UP), chain
;           + 1, Mario bounces (Space held = higher bounce).
;           Goomba -> flat for FLAT_FRAMES. Koopa or sliding shell
;           -> stationary shell with a grace time so that Mario,
;           still touching it, does not kick it at once.
; Inputs  : [bp+4] = address of the record      Registers changed : none
; ------------------------------------------------------------
StompEnemy:
    push bp
    mov bp, sp
    push ax
    push bx
    mov bx, [bp+4]
    mov byte [p3_stomped], 1
    call StompReward
    mov word [hero_vy], JUMP_CUTOFF ; small bounce (-2.0)
    push word SC_SPACE
    call IsKeyDown
    test ax, ax
    jz .nb
    mov word [hero_vy], STOMP_BOUNCE ; Space held: -3.0
.nb:
    mov byte [hero_on_ground], 0
    cmp byte [bx+EN_TYPE], ET_GOOMBA
    jne .koopa
    mov byte [bx+EN_STATE], ES_FLAT
    mov byte [bx+EN_TIMER], FLAT_FRAMES
    jmp .out
.koopa:
    mov byte [bx+EN_STATE], ES_SHELL
    mov byte [bx+EN_TIMER], SHELL_GRACE
.out:
    pop bx
    pop ax
    pop bp
    ret 2

; ------------------------------------------------------------
; StompReward
; Purpose : points for the next stomp of this jump: the chain
;           counter hero_stomp indexes the word table stomp_table
;           (100,200,400,500,800,1000,2000,4000,5000,8000). The 11th
;           and later stomps give a 1-UP. Then the counter + 1.
; Inputs  : none      Outputs : score, hero_stomp
; Registers changed : none
; ------------------------------------------------------------
StompReward:
    push bx
    mov bx, [hero_stomp]
    cmp bx, 10
    jb .points
    call GiveLife                   ; stomp 11 and later: 1-UP
    jmp .count
.points:
    shl bx, 1                       ; word table: index * 2
    push word [stomp_table+bx]
    call GivePoints
.count:
    cmp word [hero_stomp], 20       ; keep the counter small
    jae .done
    inc word [hero_stomp]
.done:
    pop bx
    ret

; ------------------------------------------------------------
; KickShell(record)
; Purpose : Mario touches a stationary shell: +400, the shell slides
;           away from Mario at SHELL_SPEED and ignores Mario for
;           SHELL_GRACE frames (the kick cannot hurt him).
; Inputs  : [bp+4] = address of the record      Registers changed : none
; ------------------------------------------------------------
KickShell:
    push bp
    mov bp, sp
    push ax
    push bx
    mov bx, [bp+4]
    push word 400
    call GivePoints
    mov byte [bx+EN_STATE], ES_SLIDE
    mov word [bx+EN_SPEED], SHELL_SPEED
    mov byte [bx+EN_TIMER], SHELL_GRACE
    mov byte [bx+EN_DIR], 0         ; default: slide left
    mov ax, [hero_x]
    cmp ax, [bx+EN_X]
    jge .out                        ; Mario on the right: shell goes left
    mov byte [bx+EN_DIR], 1         ; Mario on the left: shell goes right
.out:
    pop bx
    pop ax
    pop bp
    ret 2

; ------------------------------------------------------------
; ResolveShells
; Purpose : for every sliding shell run ShellKills.
; Inputs/Outputs : none      Registers changed : none
; ------------------------------------------------------------
ResolveShells:
    push bx
    push cx
    mov bx, enemy_table
    mov cx, ENEMY_COUNT
.l:
    cmp byte [bx+EN_TYPE], ET_KOOPA
    jne .n
    cmp byte [bx+EN_STATE], ES_SLIDE
    jne .n
    push bx
    call ShellKills
.n:
    add bx, ENEMY_SIZE
    loop .l
    pop cx
    pop bx
    ret

; ------------------------------------------------------------
; ShellKills(record)
; Purpose : the sliding shell removes every Goomba/Koopa it touches
;           (walking or stationary shell), +500 each.
; Inputs  : [bp+4] = address of the sliding shell      Registers changed : none
; ------------------------------------------------------------
ShellKills:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push si
    mov si, [bp+4]                  ; SI = the sliding shell
    mov bx, enemy_table
    mov cx, ENEMY_COUNT
.l:
    cmp bx, si
    je .n
    cmp byte [bx+EN_TYPE], ET_NONE
    je .n
    cmp byte [bx+EN_TYPE], ET_MUSH
    jae .n
    cmp byte [bx+EN_STATE], ES_WALK
    je .test
    cmp byte [bx+EN_STATE], ES_SHELL
    jne .n
.test:
    push word [si+EN_X]
    push word [si+EN_Y]
    push word TILE
    push word TILE
    push word [bx+EN_X]
    push word [bx+EN_Y]
    push word TILE
    push word TILE
    call RectOverlap
    test ax, ax
    jz .n
    mov byte [bx+EN_TYPE], ET_NONE  ; enemy removed
    push word 500
    call GivePoints
.n:
    add bx, ENEMY_SIZE
    loop .l
    pop si
    pop cx
    pop bx
    pop ax
    pop bp
    ret 2

; ------------------------------------------------------------
; CollectMapCoins
; Purpose : coin tiles are not solid; they are collected when Mario's
;           hitbox overlaps them: test the left and the right edge
;           column of the hitbox (CoinColumn).
; Inputs/Outputs : none      Registers changed : none
; ------------------------------------------------------------
CollectMapCoins:
    push ax
    mov ax, [hero_x]
    add ax, HITBOX_L
    push ax
    call CoinColumn
    mov ax, [hero_x]
    add ax, HITBOX_R
    push ax
    call CoinColumn
    pop ax
    ret

; ------------------------------------------------------------
; CoinColumn(px)
; Purpose : in the vertical line x = px (top to bottom of Mario's
;           hitbox, sampled every 16 pixels) turn every coin tile
;           into sky in map_working and call GiveCoin for it.
; Inputs  : [bp+4] = px      Outputs : none      Registers changed : none
; ------------------------------------------------------------
CoinColumn:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    call HeroHeight
    mov cx, [hero_y]
    mov dx, cx
    add dx, ax
    dec dx                          ; DX = bottom pixel row
.loop:
    push word [bp+4]
    push cx
    call GetTile
    cmp ax, T_COIN
    jne .next
    mov ax, [bp+4]
    shr ax, TILE_SHIFT              ; column
    mov bx, cx
    shr bx, TILE_SHIFT              ; row
    push ax
    push bx
    push word T_SKY                 ; the coin disappears
    call SetTile
    call GiveCoin
.next:
    cmp cx, dx
    jge .done
    add cx, TILE
    cmp cx, dx
    jle .loop
    mov cx, dx
    jmp .loop
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 2

; ------------------------------------------------------------
; CheckPit
; Purpose : the top of Mario passed below the bottom of the map
;           (y >= PIT_Y = 192): hero_dead = 1 at any health.
; Inputs/Outputs : none      Registers changed : none
; ------------------------------------------------------------
CheckPit:
    cmp word [hero_y], PIT_Y
    jl .done
    mov byte [hero_dead], 1
.done:
    ret

; ------------------------------------------------------------
; FlagColumn(px)
; Purpose : is there a flag pole tile in the vertical line x = px
;           (top to bottom of Mario's hitbox)?
; Inputs  : [bp+4] = px
; Outputs : AX = 1 flag found, 0 not      Registers changed : AX
; ------------------------------------------------------------
FlagColumn:
    push bp
    mov bp, sp
    push cx
    push dx
    call HeroHeight
    mov cx, [hero_y]
    mov dx, cx
    add dx, ax
    dec dx
.loop:
    push word [bp+4]
    push cx
    call GetTile
    cmp ax, T_FLAG
    je .yes
    cmp cx, dx
    jge .no
    add cx, TILE
    cmp cx, dx
    jle .loop
    mov cx, dx
    jmp .loop
.yes:
    mov ax, 1
    jmp .out
.no:
    xor ax, ax
.out:
    pop dx
    pop cx
    pop bp
    ret 2

; ------------------------------------------------------------
; CheckFlag
; Purpose : Mario overlaps the flag pole: points by the map row of
;           his bottom edge (rows 2-3 5000, 4 2000, 5 800, 6-7 400,
;           8 100 - word table flag_points indexed by row), then
;           level_won = 1. Only once.
; Inputs/Outputs : none      Registers changed : none
; ------------------------------------------------------------
CheckFlag:
    push ax
    push bx
    cmp byte [level_won], 0
    jne .done
    mov ax, [hero_x]
    add ax, HITBOX_L
    push ax
    call FlagColumn
    test ax, ax
    jnz .hit
    mov ax, [hero_x]
    add ax, HITBOX_R
    push ax
    call FlagColumn
    test ax, ax
    jz .done
.hit:
    call HeroHeight
    mov bx, [hero_y]
    add bx, ax
    dec bx                          ; bottom pixel row of Mario
    shr bx, TILE_SHIFT              ; map row of his feet
    cmp bx, 11
    jbe .ok
    mov bx, 11                      ; keep inside the table
.ok:
    shl bx, 1                       ; word table: index * 2
    push word [flag_points+bx]
    call GivePoints
    mov byte [level_won], 1
.done:
    pop bx
    pop ax
    ret

; ============================================================
; DRAWING (frame step 9) - Person 2 sprite bitmaps
; ============================================================

; DrawHero - choose a pose and render at world x minus camera x.
; Inputs: hero fields, camera. Outputs: frame buffer. Changes: none.
DrawHero:
    push ax
    push bx
    push cx
    push dx
    mov ax, [hero_invuln]
    test ax, ax
    jz .visible
    test al, 1                      ; alternate frames while invulnerable
    jnz .done
.visible:
    mov dx, [hero_x]
    sub dx, [camera_x]
    cmp dx, -TILE
    jle .done
    cmp dx, SCREEN_W
    jge .done
    mov bx, spr_small_stand
    cmp byte [hero_form], FORM_SUPER
    je .super
    cmp byte [hero_on_ground], 0
    je .smalljump
    cmp word [hero_vx], 0
    je .pose
    mov bx, spr_small_run
    jmp .pose
.smalljump:
    mov bx, spr_small_jump
    jmp .pose
.super:
    mov bx, spr_super_stand
    cmp byte [hero_on_ground], 0
    je .superjump
    cmp word [hero_vx], 0
    je .pose
    mov bx, spr_super_run
    jmp .pose
.superjump:
    mov bx, spr_super_jump
.pose:
    xor cx, cx
    cmp byte [hero_face], 0
    jne .draw
    inc cx                          ; bit 0 mirrors the right-facing sprite
.draw:
    push dx
    push word [hero_y]
    push bx
    push cx
    call DrawSprite
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; DrawEntities - render active records and the rising coin sprite.
; Inputs: enemy_table, pop-up fields. Outputs: frame buffer. Changes: none.
DrawEntities:
    push ax
    push bx
    push cx
    mov bx, enemy_table
    mov cx, ENEMY_COUNT
.next:
    cmp byte [bx+EN_TYPE], ET_NONE
    je .skip
    cmp byte [bx+EN_STATE], ES_IDLE
    je .skip
    push bx
    call DrawOneEntity
.skip:
    add bx, ENEMY_SIZE
    loop .next
    cmp byte [p3_pop_t], 0
    je .done
    mov ax, [p3_pop_x]
    sub ax, [camera_x]
    cmp ax, -TILE
    jle .done
    cmp ax, SCREEN_W
    jge .done
    push ax
    push word [p3_pop_y]
    push word spr_coin
    push word 0
    call DrawSprite
.done:
    pop cx
    pop bx
    pop ax
    ret

; DrawOneEntity(record) - choose bitmap by type and state.
; Inputs: [bp+4] record address. Outputs: frame buffer. Changes: none.
DrawOneEntity:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    mov bx, [bp+4]
    mov dx, [bx+EN_X]
    sub dx, [camera_x]
    cmp dx, -TILE
    jle .out
    cmp dx, SCREEN_W
    jge .out
    mov ax, spr_goomba
    cmp byte [bx+EN_TYPE], ET_MUSH
    je .mush
    cmp byte [bx+EN_TYPE], ET_KOOPA
    je .koopa
    cmp byte [bx+EN_STATE], ES_FLAT
    jne .flags
    mov ax, spr_goomba_flat
    jmp .flags
.mush:
    mov ax, spr_mushroom
    jmp .flags
.koopa:
    mov ax, spr_koopa
    cmp byte [bx+EN_STATE], ES_WALK
    je .flags
    mov ax, spr_shell
.flags:
    xor cx, cx
    cmp byte [bx+EN_DIR], 0
    jne .draw
    inc cx
.draw:
    push dx
    push word [bx+EN_Y]
    push ax
    push cx
    call DrawSprite
.out:
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 2

; ============================================================
; Private data of Person 3 (used only by gameplay.asm)
; ============================================================
stomp_table     dw 100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000
flag_points     dw 5000, 5000, 5000, 5000, 2000, 800, 400, 400, 100, 100, 100, 100
p3_prev_feet    dw 0                ; Mario's feet in the previous frame
p3_stomped      db 0                ; 1 = a stomp already happened this frame
p3_pop_x        dw 0                ; coin pop-up: world x, y and frames left
p3_pop_y        dw 0
p3_pop_t        db 0
