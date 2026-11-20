; ============================================================
; text.asm  -  PERSON 1  (text for the Title, Pause, Life-lost,
; Level-complete and Game-over screens; Modules 13/14)
; Characters come from the BIOS 8x8 font (pointer read at start in
; InitEngine). Everything is drawn into the FRAME BUFFER with
; FillRect, one filled square per lit font pixel (scale 1, 2, 3...).
; Person 2's DrawHUD has its own text; these names (Txt...) do not
; clash with it.
; ============================================================

; ------------------------------------------------------------
; TxtChar(x, y, ch, colour, scale)
; Purpose : one character, 8*scale by 8*scale pixels, top-left (x,y)
; Inputs  : [bp+12]=x [bp+10]=y [bp+8]=ch [bp+6]=colour [bp+4]=scale
; Outputs : none     Changes : none
; ------------------------------------------------------------
TxtChar:
        push bp
        mov bp, sp
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push ds
        push es
        mov ax, [bp+8]              ; copy the 8 font bytes of this character
        and ax, 7Fh
        shl ax, 3                   ; ch * 8
        mov si, ax
        add si, [font_off]
        push cs
        pop es
        mov di, glyph_buf
        mov ax, [font_seg]
        mov ds, ax                  ; DS = font segment while copying
        mov cx, 4
        cld
        rep movsw
        push cs
        pop ds                      ; DS = our segment again
        xor si, si                  ; SI = row 0..7
        mov bx, [bp+10]             ; BX = y of this row
.row:   mov dl, [glyph_buf+si]      ; bits of this row, leftmost = bit 7
        mov di, [bp+12]             ; DI = x of the current column
        mov cx, 8
.col:   shl dl, 1
        jnc .skip                   ; bit was 0: nothing to draw
        push di
        push bx
        push word [bp+4]            ; w = scale
        push word [bp+4]            ; h = scale
        push word [bp+6]            ; colour
        call FillRect
.skip:  add di, [bp+4]
        loop .col
        add bx, [bp+4]
        inc si
        cmp si, 8
        jb .row
        pop es
        pop ds
        pop di
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        pop bp
        ret 10

; ------------------------------------------------------------
; TxtStr(x, y, addr, colour, scale)
; Purpose : zero-terminated string, characters 8*scale pixels apart
; Inputs  : [bp+12]=x [bp+10]=y [bp+8]=addr [bp+6]=colour [bp+4]=scale
; Outputs : none     Changes : none
; ------------------------------------------------------------
TxtStr:
        push bp
        mov bp, sp
        push ax
        push bx
        push si
        mov si, [bp+8]
        mov bx, [bp+12]
.next:  mov al, [si]
        test al, al
        jz .done
        xor ah, ah
        push bx
        push word [bp+10]
        push ax
        push word [bp+6]
        push word [bp+4]
        call TxtChar
        mov ax, [bp+4]
        shl ax, 3
        add bx, ax                  ; next character position
        inc si
        jmp .next
.done:  pop si
        pop bx
        pop ax
        pop bp
        ret 10

; ------------------------------------------------------------
; TxtNum(x, y, value, digits, colour, scale)
; Purpose : zero-padded decimal number (value is 16-bit, digits >= 1).
;           Digits come from repeated division by 10; the remainders
;           are pushed on the stack and popped in reverse order.
; Inputs  : [bp+14]=x [bp+12]=y [bp+10]=value [bp+8]=digits
;           [bp+6]=colour [bp+4]=scale
; Outputs : none     Changes : none
; ------------------------------------------------------------
TxtNum:
        push bp
        mov bp, sp
        push ax
        push bx
        push cx
        push dx
        push si
        mov ax, [bp+10]
        mov cx, [bp+8]
        mov bx, 10
.div:   xor dx, dx
        div bx                      ; AX = AX / 10, DX = remainder
        push dx
        loop .div
        mov si, [bp+14]
        mov cx, [bp+8]
.draw:  pop ax                      ; most significant digit first
        add ax, '0'
        push si
        push word [bp+12]
        push ax
        push word [bp+6]
        push word [bp+4]
        call TxtChar
        mov ax, [bp+4]
        shl ax, 3
        add si, ax
        loop .draw
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        pop bp
        ret 12

; ------------------------------------------------------------
; TxtNum32(x, y, lo, hi, colour, scale)
; Purpose : 6-digit zero-padded decimal of a 32-bit value (the score).
;           32-bit / 10 is done as two DIVs: first the high word, then
;           (remainder:low word).
; Inputs  : [bp+14]=x [bp+12]=y [bp+10]=lo [bp+8]=hi
;           [bp+6]=colour [bp+4]=scale
; Outputs : none     Changes : none
; ------------------------------------------------------------
TxtNum32:
        push bp
        mov bp, sp
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        mov si, [bp+8]              ; SI = high word
        mov di, [bp+10]             ; DI = low word
        mov bx, 10
        mov cx, 6
.div:   mov ax, si
        xor dx, dx
        div bx                      ; high / 10
        mov si, ax
        mov ax, di
        div bx                      ; (remainder:low) / 10
        mov di, ax
        push dx                     ; remainder = next digit (from the right)
        loop .div
        mov si, [bp+14]
        mov cx, 6
.draw:  pop ax
        add ax, '0'
        push si
        push word [bp+12]
        push ax
        push word [bp+6]
        push word [bp+4]
        call TxtChar
        mov ax, [bp+4]
        shl ax, 3
        add si, ax
        loop .draw
        pop di
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        pop bp
        ret 12
