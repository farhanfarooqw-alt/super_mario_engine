# Super Mario Engine (EL2003 Computer Organization and Assembly Language)

Side-scrolling platform game in 16-bit x86 assembly (NASM), VGA Mode 13h, `MARIO.COM`, runs in DOSBox 0.74-3.

## Team
| Member | Roll no. | Modules |
|---|---|---|
| Person 1 (Farhan) | (fill in) | 1, 2, 5, 7, 8, 14, 15 |
| Person 2 (Ahsan) | (fill in) | 3, 4, 6, 13 |
| Person 3 (Haroon) | (fill in) | 9, 10, 11, 12 |

## Build and run
1. Install NASM (Windows build from nasm.us) and DOSBox 0.74-3.
2. `build.bat` (runs `nasm -f bin src\mario.asm -o MARIO.COM`; must say BUILD OK).
3. DOSBox: `mount c "<project folder>"`, `c:`, `MARIO.COM` (or double-click `run.bat` after editing the DOSBox path in it).

## Controls (Appendix A.3)
Left / Right = move, Left Shift = run, Space = jump (hold = higher), Up / Down = menu, Enter = select / continue, P = pause, Esc = back to title / exit from the title.

## Memory choices
`.COM` uses one 64 KB segment for code, data and stack. The 64,000-byte frame buffer lives in a second segment: at start `InitEngine` shrinks our memory block to 64 KB (INT 21h AH=4Ah) and allocates 0FA0h paragraphs (INT 21h AH=48h). It is freed on exit. The level map exists twice: `map_original` (never changed) and `map_working` (changed by blocks and coins); `ResetMap` copies the original back with one `REP MOVSB/MOVSW`.

## Timing
The timer chip is set to 30 Hz (divisor 39773) and INT 08h is hooked. The BIOS handler is chained at its original 18.2 Hz rate (accumulator carry) so the DOS clock stays correct. The game loop waits for `tick_count` to change, so the speed is the same on every PC. The timer rate and both vectors are restored on exit.

## Game states (Manual 5.12)
`game_state` indexes a jump table (`state_table`).
- TITLE: Up/Down moves the highlight, Enter on START GAME starts a new game, Enter on EXIT or Esc leaves to DOS.
- PLAYING: P pauses, Esc returns to the title, Mario dying goes to DYING, the flag goes to WIN SEQUENCE.
- PAUSED: updates and clock frozen, picture stays with a PAUSED box; P resumes, Esc returns to the title.
- DYING: about 1.5 s (hop up about 48 px, then fall, no collisions; pit death only falls); then lives - 1 and LIFE LOST or GAME OVER.
- LIFE LOST: about 2 s, then the level is reset (map, enemies, clock = 300, camera = 0, Small Mario) and PLAYING starts.
- WIN SEQUENCE: Mario snaps to the pole, slides down (about 1 s), walks off the level (about 1 s), then LEVEL COMPLETE.
- LEVEL COMPLETE: time left x 50 is added to the score; Enter returns to the title.
- GAME OVER: final score; Enter returns to the title.
- EXIT: restore keyboard and timer vectors, text mode, return to DOS.

## Debug keys (only while playing)
K = force death, W = simulate flag touch (100 points), T = set the clock to 5 seconds. Debug shortcuts are for testing only.

## Deviations from the manual
- Position = whole pixels (word) + fraction (byte); only velocity is pure 8.8, because an 8.8 position cannot reach x = 944.
- The bottom 8 rows of the frame buffer are cleared to black (Appendix A.1).
- Text on the screens uses the BIOS 8x8 font (pointer from INT 10h AX=1130h), drawn into the frame buffer.

## Bonus features / Known limitations
- Coin pop-up animation is implemented.
- The win animation uses the permitted exit/disappearance option instead of a castle door.
- Full integrated DOSBox demo and final team details must be verified before submission.
