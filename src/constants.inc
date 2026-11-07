; ============================================================
; constants.inc  -  shared constants (ALL members use this file)
; Change a value here only after telling the whole group.
; ============================================================

; ---- Display (Appendix A.1) ----
SCREEN_W        equ 320
SCREEN_H        equ 200
VIDEO_SEG       equ 0A000h
FB_BYTES        equ 64000           ; one full frame
FB_PARAS        equ 0FA0h           ; 64000 / 16 paragraphs for INT 21h AH=48h
TILE            equ 16              ; tile / sprite size in pixels
TILE_SHIFT      equ 4               ; x >> 4 = x / 16
HUD_H           equ 16              ; map row 0 is the HUD strip
VIEW_COLS       equ 20
VIEW_ROWS       equ 12

; ---- Level (Section 5.15) ----
MAP_W           equ 60              ; tiles
MAP_H           equ 12
MAP_SIZE        equ MAP_W*MAP_H     ; bytes
LEVEL_PX        equ MAP_W*TILE      ; 960
CAM_FOLLOW_X    equ 160             ; Mario stays here once past the middle
CAM_MAX         equ LEVEL_PX-SCREEN_W   ; 640
START_X         equ 32              ; Mario start (world x, pixels)
START_Y_FEET    equ 10*TILE         ; feet on top of ground row 10 (y = 160)
PIT_Y           equ 192             ; top of Mario below this = dead

; ---- Tile codes (Appendix A.2) ----
T_SKY           equ 0
T_GROUND        equ 1
T_BRICK         equ 2
T_QCOIN         equ 3
T_QMUSH         equ 4
T_EMPTY         equ 5
T_PIPE_TL       equ 6
T_PIPE_TR       equ 7
T_PIPE_BL       equ 8
T_PIPE_BR       equ 9
T_STAIR         equ 10
T_COIN          equ 11
T_FLAG          equ 12

; ---- Scan codes (Appendix A.3) ----
SC_ESC          equ 01h
SC_ENTER        equ 1Ch
SC_P            equ 19h
SC_LSHIFT       equ 2Ah
SC_SPACE        equ 39h
SC_UP           equ 48h
SC_LEFT         equ 4Bh
SC_RIGHT        equ 4Dh
SC_DOWN         equ 50h

; ---- Timing ----
FRAME_HZ        equ 30              ; target frames per second
PIT_DIVISOR     equ 39773           ; 1193182 / 30 (timer chip divisor)
TICKS_PER_SEC   equ FRAME_HZ

; ---- Game limits (Appendix A.4) ----
START_LIVES     equ 3
MAX_LIVES       equ 99
LEVEL_TIME      equ 300
INVULN_FRAMES   equ 2*FRAME_HZ      ; about 2 seconds
SHELL_GRACE     equ 8               ; frames
FLAT_FRAMES     equ FRAME_HZ        ; flat Goomba, about 1 s
DEATH_FRAMES    equ 45              ; about 1.5 s
LIFELOST_FRAMES equ 2*FRAME_HZ      ; about 2 s
MAX_SCORE_HI    equ 0Fh             ; 999,999 = 000F423Fh
MAX_SCORE_LO    equ 423Fh
MAX_ACTIVE_ENEMIES equ 8

; ---- Physics, 8.8 fixed point (Appendix A.5) ----
ACCEL_WALK      equ 0020h
FRICTION        equ 0010h
MAX_WALK        equ 0180h
MAX_RUN         equ 0280h
GRAVITY         equ 0040h
JUMP_START      equ 0FA80h          ; -5.5
JUMP_CUTOFF     equ 0FE00h          ; -2.0
MAX_FALL        equ 0400h
STOMP_BOUNCE    equ 0FD00h          ; -3.0
GOOMBA_SPEED    equ 0080h
KOOPA_SPEED     equ 00C0h
SHELL_SPEED     equ 0300h
MUSH_SPEED      equ 0100h

; ---- Game states (Section 5.12): index into the jump table ----
ST_TITLE        equ 0
ST_PLAYING      equ 1
ST_PAUSED       equ 2
ST_DYING        equ 3
ST_LIFELOST     equ 4
ST_WIN          equ 5
ST_COMPLETE     equ 6
ST_GAMEOVER     equ 7
ST_EXIT         equ 8

; ---- Hero form ----
FORM_SMALL      equ 0
FORM_SUPER      equ 1

; ---- Enemy table (Section 5.5) ----
ENEMY_COUNT     equ 16              ; records in the table
ENEMY_SIZE      equ 10              ; bytes per record
EN_TYPE         equ 0               ; db  0 = unused, 1 = Goomba, 2 = Koopa, 3 = Mushroom
EN_STATE        equ 1               ; db  walking, flat, shell, sliding, dead...
EN_X            equ 2               ; dw  world x (pixels)
EN_Y            equ 4               ; dw  y of top (pixels)
EN_SPEED        equ 6               ; dw  8.8 speed
EN_DIR          equ 8               ; db  0 = left, 1 = right
EN_TIMER        equ 9               ; db  flat / grace timer

; ---- Colours: default VGA palette indices (0 is transparent in sprites) ----
COL_BLACK       equ 0
COL_SKY         equ 9
COL_GROUND      equ 6
COL_GRASS       equ 10
COL_BRICK       equ 4
COL_PIPE        equ 2
COL_COIN        equ 14
COL_TEXT        equ 15
