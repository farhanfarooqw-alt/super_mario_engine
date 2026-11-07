; ============================================================
; engine.asm  -  PERSON 1
; Modules 1, 2, 5, 7, 8  (14 and 15 come later)
; Convention: docs/CONVENTIONS.md   (params on the stack, ret 2*n)
; All drawing goes into the FRAME BUFFER segment [fb_seg].
; ============================================================

; ------------------------------------------------------------
; InitEngine     Modules 1, 5, 7, 8
; Purpose : shrink our memory block, allocate the frame buffer
;           segment, switch to Mode 13h, hook keyboard and timer.
; Inputs  : none
; Outputs : CF = 0 success, CF = 1 failed (still in text mode,
;           nothing hooked)
; Changes : flags only
; ------------------------------------------------------------
InitEngine:
        push ax
        push bx
        push es
        push cs
        pop es                      ; INT 21h/4Ah needs ES = our PSP segment
        mov bx, 1000h               ; keep 64 KB (code + data + stack)
        mov ah, 4Ah
        int 21h                     ; give the rest of memory back to DOS
        jc .fail
        mov bx, FB_PARAS            ; 64000 bytes = 0FA0h paragraphs
        mov ah, 48h
        int 21h                     ; allocate the frame buffer segment
        jc .fail
        mov [fb_seg], ax
        mov ax, 0013h
        int 10h                     ; VGA Mode 13h
        call InstallKeyboard
        call InstallTimer
        clc
        jmp .out
.fail:
        stc
.out:
        pop es
        pop bx
        pop ax
        ret

; ------------------------------------------------------------
; ShutdownEngine   Modules 1, 7, 8       (call on EVERY exit path)
; Purpose : restore timer rate + vector, keyboard vector,
;           free the frame buffer, return to text mode.
; Inputs/Outputs : none      Changes : none
; ------------------------------------------------------------
ShutdownEngine:
        push ax
        push es
        call RemoveTimer
        call RemoveKeyboard
        mov ax, [fb_seg]
        test ax, ax
        jz .nofb
        mov es, ax
        mov ah, 49h
        int 21h                     ; free the frame buffer
.nofb:
        mov ax, 0003h
        int 10h                     ; back to text mode
        pop es
        pop ax
        ret

; ============================================================
; MODULE 2 - drawing primitives (into the frame buffer)
; ============================================================

; ------------------------------------------------------------
; PutPixel(x, y, colour)
; Purpose : one pixel; offset = y*320 + x = (y<<8) + (y<<6) + x
;           Pixels outside the screen are ignored.
; Inputs  : [bp+8]=x  [bp+6]=y  [bp+4]=colour (low byte)
; Outputs : none     Changes : none
; ------------------------------------------------------------
PutPixel:
        push bp
        mov bp, sp
        push ax
        push bx
        push di
        push es
        mov ax, [bp+6]              ; y
        cmp ax, SCREEN_H
        jae .out                    ; unsigned: also catches negative
        mov bx, [bp+8]              ; x
        cmp bx, SCREEN_W
        jae .out
        mov di, ax
        shl di, 8                   ; y * 256
        shl ax, 6                   ; y * 64
        add di, ax                  ; y * 320
        add di, bx                  ; + x
        mov es, [fb_seg]
        mov al, [bp+4]
        mov [es:di], al
.out:
        pop es
        pop di
        pop bx
        pop ax
        pop bp
        ret 6

; ------------------------------------------------------------
; FillRect(x, y, w, h, colour)
; Purpose : filled rectangle, clipped to the screen on all sides
;           (x and y are signed, so it may start off-screen).
; Inputs  : [bp+12]=x [bp+10]=y [bp+8]=w [bp+6]=h [bp+4]=colour
; Outputs : none     Changes : none
; ------------------------------------------------------------
FillRect:
        push bp
        mov bp, sp
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push es
        mov es, [fb_seg]
        mov ax, [bp+12]             ; x
        mov bx, [bp+10]             ; y
        mov cx, [bp+8]              ; w
        mov dx, [bp+6]              ; h
        test ax, ax                 ; clip left
        jns .xok
        add cx, ax
        xor ax, ax
.xok:   mov si, ax                  ; clip right
        add si, cx
        cmp si, SCREEN_W
        jle .wok
        mov cx, SCREEN_W
        sub cx, ax
.wok:   cmp cx, 0
        jle .done
        test bx, bx                 ; clip top
        jns .yok
        add dx, bx
        xor bx, bx
.yok:   mov si, bx                  ; clip bottom
        add si, dx
        cmp si, SCREEN_H
        jle .hok
        mov dx, SCREEN_H
        sub dx, bx
.hok:   cmp dx, 0
        jle .done
        mov di, bx                  ; di = y*320 + x
        shl di, 8
        mov si, bx
        shl si, 6
        add di, si
        add di, ax
        mov al, [bp+4]
        cld
.row:   push di
        push cx
        rep stosb                   ; one scanline
        pop cx
        pop di
        add di, SCREEN_W
        dec dx
        jnz .row
.done:  pop es
        pop di
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        pop bp
        ret 10

; ============================================================
; MODULE 5 - frame buffer and block operations
; ============================================================

; ------------------------------------------------------------
; ClearBuffer   fill the frame buffer with the sky colour
;               (REP STOSW, 32000 words, not a pixel loop)
; Inputs/Outputs : none      Changes : none
; ------------------------------------------------------------
ClearBuffer:
        push ax
        push cx
        push di
        push es
        mov es, [fb_seg]
        xor di, di
        mov al, COL_SKY
        mov ah, al
        mov cx, FB_BYTES/2
        cld
        rep stosw
        pop es
        pop di
        pop cx
        pop ax
        ret

; ------------------------------------------------------------
; FlipBuffer    copy frame buffer -> video memory A000h
;               (one REP MOVSW, 32000 words, once per tick)
; Inputs/Outputs : none      Changes : none
; ------------------------------------------------------------
FlipBuffer:
        push ax
        push cx
        push si
        push di
        push ds
        push es
        mov ax, VIDEO_SEG
        mov es, ax
        mov ax, [fb_seg]            ; read while DS is still ours
        mov ds, ax
        xor si, si
        xor di, di
        mov cx, FB_BYTES/2
        cld
        rep movsw
        pop es
        pop ds
        pop di
        pop si
        pop cx
        pop ax
        ret

; ============================================================
; MODULE 7 - keyboard interrupt handler (INT 09h)
; ============================================================

; ------------------------------------------------------------
; KbdISR   hardware interrupt, not called directly
; Purpose : read the scan code from port 60h and keep key_table
;           (1 = held). Bit 7 set = key released. The E0h prefix
;           byte of the arrow keys is ignored.
; ------------------------------------------------------------
KbdISR:
        push ax
        push bx
        push ds
        push cs
        pop ds                      ; DS = our segment (we interrupted anything)
        in al, 60h                  ; scan code
        cmp al, 0E0h
        je .eoi                     ; ignore the extended-key prefix
        cmp al, 0E1h
        je .eoi
        mov bl, al
        and bl, 7Fh                 ; code without the release bit
        xor bh, bh
        test al, 80h
        jnz .release
        mov byte [key_table+bx], 1
        jmp .eoi
.release:
        mov byte [key_table+bx], 0
.eoi:   mov al, 20h
        out 20h, al                 ; end of interrupt to the PIC
        pop ds
        pop bx
        pop ax
        iret

; InstallKeyboard: save old INT 09h (AH=35h), set ours (AH=25h)
InstallKeyboard:
        push ax
        push bx
        push dx
        push es
        mov ax, 3509h
        int 21h                     ; ES:BX = old vector
        mov [old_int09], bx
        mov [old_int09+2], es
        mov dx, KbdISR              ; DS:DX = our handler
        mov ax, 2509h
        int 21h
        pop es
        pop dx
        pop bx
        pop ax
        ret

; RemoveKeyboard: put the old INT 09h back (only if we saved one)
RemoveKeyboard:
        push ax
        push dx
        push ds
        mov ax, [old_int09+2]
        test ax, ax
        jz .skip
        lds dx, [old_int09]
        mov ax, 2509h
        int 21h
.skip:  pop ds
        pop dx
        pop ax
        ret

; ------------------------------------------------------------
; IsKeyDown(scancode)
; Purpose : is this key held?   Inputs: [bp+4] = scan code
; Outputs : AX = 1 held, 0 not held     Changes : AX only
; ------------------------------------------------------------
IsKeyDown:
        push bp
        mov bp, sp
        push bx
        mov bx, [bp+4]
        and bx, 7Fh
        mov al, [key_table+bx]
        xor ah, ah
        pop bx
        pop bp
        ret 2

; ============================================================
; MODULE 8 - timer interrupt and game clock
; ============================================================

; ------------------------------------------------------------
; TimerISR   hardware interrupt INT 08h (now FRAME_HZ times/s)
; Purpose : count ticks. The BIOS handler still needs its original
;           18.2 Hz rate to keep the DOS clock right, so it is
;           chained only when chain_acc overflows (carry).
; ------------------------------------------------------------
TimerISR:
        push ax
        push ds
        push cs
        pop ds
        inc word [tick_count]
        add word [chain_acc], PIT_DIVISOR
        jc .chain                   ; carry = time for one BIOS tick
        mov al, 20h
        out 20h, al                 ; we send the EOI ourselves
        pop ds
        pop ax
        iret
.chain: pushf
        call far [old_int08]        ; BIOS handler sends the EOI and IRETs here
        pop ds
        pop ax
        iret

; InstallTimer: save INT 08h, hook ours, set timer chip to FRAME_HZ
InstallTimer:
        push ax
        push bx
        push dx
        push es
        mov ax, 3508h
        int 21h
        mov [old_int08], bx
        mov [old_int08+2], es
        cli
        mov dx, TimerISR
        mov ax, 2508h
        int 21h
        mov al, 36h                 ; channel 0, lo/hi byte, mode 3
        out 43h, al
        mov ax, PIT_DIVISOR
        out 40h, al
        mov al, ah
        out 40h, al
        sti
        pop es
        pop dx
        pop bx
        pop ax
        ret

; RemoveTimer: normal rate (divisor 0 = 65536) and old vector back
RemoveTimer:
        push ax
        push dx
        push ds
        mov ax, [old_int08+2]
        test ax, ax
        jz .skip
        cli
        mov al, 36h
        out 43h, al
        xor al, al
        out 40h, al
        out 40h, al                 ; divisor 65536 = 18.2 Hz
        lds dx, [old_int08]
        mov ax, 2508h
        int 21h
        sti
.skip:  pop ds
        pop dx
        pop ax
        ret

; ------------------------------------------------------------
; WaitTick   wait until the timer ISR changes tick_count
; Inputs/Outputs : none      Changes : none
; ------------------------------------------------------------
WaitTick:
        push ax
.again: mov ax, [tick_count]
        cmp ax, [last_tick]
        jne .go
        hlt                         ; sleep until the next interrupt
        jmp .again
.go:    mov [last_tick], ax
        pop ax
        ret

; ------------------------------------------------------------
; UpdateClock   call once per frame
; Purpose : when clock_run = 1, take one second off clock_secs
;           for every TICKS_PER_SEC real ticks (so a slow PC
;           still counts real seconds). Frozen when clock_run = 0.
; Inputs/Outputs : none      Changes : none
; ------------------------------------------------------------
UpdateClock:
        push ax
        mov ax, [tick_count]
        cmp byte [clock_run], 0
        jne .run
        mov [clock_last], ax        ; frozen: do not collect time
        jmp .out
.run:   mov ax, [tick_count]
        sub ax, [clock_last]
        cmp ax, TICKS_PER_SEC
        jb .out
        add word [clock_last], TICKS_PER_SEC
        cmp word [clock_secs], 0
        je .out                     ; Module 15 will notice 0 and kill Mario
        dec word [clock_secs]
.out:   pop ax
        ret

; ------------------------------------------------------------
; ResetLevel  (Module 15)  /  NewGame (Module 15)   - stubs for now
; ------------------------------------------------------------
ResetLevel:
        ret
NewGame:
        ret
