# Conventions (all three members follow these)

## 1. Calling convention
- Parameters are pushed on the stack, LEFT to RIGHT (first parameter pushed first).
- Callee starts with `push bp` / `mov bp, sp`. The LAST parameter is at [bp+4],
  the one before it at [bp+6], and so on (each parameter is one word).
- Callee cleans the stack itself: `ret 2*n` (n = number of parameters).
- Return value in AX (32-bit: DX:AX). Registers the procedure does not return
  MUST be preserved (push/pop them). Flags need not be preserved.
- Every procedure has a comment block: name, purpose, inputs, outputs, registers changed.

Example call: GetTile(px, py)
    push word [hero_x]      ; first parameter
    push word [hero_y]      ; last parameter  -> [bp+4]
    call GetTile            ; AX = tile code

## 2. Ownership
- Only the owner of a variable writes it. Others read only (see data.inc).
- Person 1 = engine.asm, Person 2 = world.asm + level.inc, Person 3 = gameplay.asm.
- constants.inc, data.inc, mario.asm: change only after telling the group.

## 3. Numbers
- Velocities are 8.8 fixed point (signed word). Positions are whole pixels (word)
  + fraction byte, because a pure 8.8 position cannot reach x = 944.
  Write this clarification in the README (deviations section).
- Use only the whole-pixel part for camera and drawing.

## 4. Git
- Own branch per person, merge by Pull Request, never squash.
- Commit small and often with a message that says what was done.

## 5. Engine facts every member needs (Person 1, Stage 2)
- All drawing procedures draw into the FRAME BUFFER ([fb_seg]); only FlipBuffer touches A000h.
- Frame loop: WaitTick first (one frame per timer tick, 30 per second), FlipBuffer last.
- The keyboard is read ONLY through IsKeyDown(scancode); never call INT 16h in the game.
- Clock: set clock_run = 1 to count down, 0 to freeze; call UpdateClock once per frame.
- Timer runs at 30 Hz (PIT_DIVISOR). The BIOS handler is chained at 18.2 Hz so the DOS clock stays right.
- Always call ShutdownEngine before exiting (restores keyboard, timer, text mode).
- PutPixel/FillRect clip to the screen, so negative x/y and off-screen drawing are safe.
