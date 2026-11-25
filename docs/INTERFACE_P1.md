# Interface of Person 1 (engine, states) for Person 2 and Person 3

## Main loop (mario.asm)
Every timer tick: WaitTick, clock_run = 0, call the state procedure (jump table), UpdateClock.
Only StatePlaying sets clock_run = 1.

## What Person 1 provides
| Procedure | Inputs (stack) | Output |
|---|---|---|
| IsKeyDown(sc) | scan code | AX = 1 if held |
| KeyPressed(sc) | scan code | AX = 1 if the key was pressed since it was last asked (latched by the keyboard ISR, never misses a tap) |
| PutPixel(x, y, colour), FillRect(x, y, w, h, colour) | see engine.asm | none (clipped, into the frame buffer) |
| ClearBuffer | none | sky rows 0-191, black rows 192-199 |
| FlipBuffer | none | frame buffer copied to A000h |
| SetState(n) | state number | none |
| NewGame, ResetLevel | none | none |
| TxtChar, TxtStr, TxtNum, TxtNum32 | see text.asm | text in the frame buffer (BIOS 8x8 font) |

## What Person 1 expects
- Person 3 sets `hero_dead = 1` (enemy touch, pit) or `level_won = 1` (flag). Person 1 does the death animation, lives, win sequence, restart. The clock reaching 0 is handled by Person 1 (sets hero_dead).
- Person 3 provides ResetHero, ResetEnemies, UpdateMario, UpdateEnemies, ResolveCollisions and later DrawHero/DrawEntities (replace DrawHeroTemp in states.asm).
- Person 2 provides ResetMap, DrawMap, UpdateCamera, DrawHUD, AddScore(points), AddCoin and sprites (replace DrawHeroTemp).
- Person 1 also writes: `lives` (minus 1 on death, 3 on new game), `score_lo/hi` and `coins` (0 on new game), `hero_x/hero_y/hero_vy` only in the DYING and WIN states.
- `ResetHero` and `ResetEnemies` in gameplay.asm are MINIMAL versions written by Person 1 so that ResetLevel works; Person 3 replaces them.
