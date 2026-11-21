# INTERFACE_P3 - Person 3 (gameplay.asm)

All procedures follow docs/CONVENTIONS.md: parameters pushed left to right,
callee does `ret 2*n`, result in AX, every register that is not returned is preserved.
Positions are whole pixels (word) + fraction byte; velocities are signed 8.8.

## Procedures Person 1 / Person 2 call

| Procedure | Inputs | Outputs | Frame step |
|---|---|---|---|
| `ResetHero` | none | Mario = Small, hp 1, at START_X, feet on the ground, speeds 0, stomp 0, invuln 0, `hero_dead` 0, `level_won` 0 | on every new life / game |
| `ResetEnemies` | none | enemy table cleared and loaded from `enemy_spawns` (all idle) | on every new life / game |
| `UpdateMario` | none (reads keys with IsKeyDown) | hero variables; also counts `hero_invuln` down by 1 per frame | 3 |
| `UpdateEnemies` | none | enemy / shell / mushroom records | 4 |
| `ResolveCollisions` | none | score (through AddScore), hero form/hp, `hero_dead`, `level_won`, coins, map changes | 5 |
| `DrawHero` | none | draws Mario into the frame buffer (blinks while invulnerable) | 9 |
| `DrawEntities` | none | draws enemies, shells, mushrooms, coin pop-up | 9 |
| `RectOverlap(x1,y1,w1,h1,x2,y2,w2,h2)` | 8 words | AX = 1 overlap / 0 | helper |

## Shared flags (data.inc, "Hero (Person 3 writes)")

| Variable | Meaning | Who reads it |
|---|---|---|
| `hero_dead` | 1 = Mario must die (enemy touch as Small, pit y >= 192). Cleared by `ResetHero`. | Person 1: start the DYING state |
| `level_won` | 1 = flag pole touched (flag points already added). Cleared by `ResetHero`. | Person 1: start the WIN sequence |

Once `hero_dead` or `level_won` is 1, `ResolveCollisions` does nothing, so nothing is
counted twice. Person 1 writes `hero_y` / `hero_vy` only in the DYING and WIN states.

## Things Person 3 needs from the others

* **invulnerability timer**: `UpdateMario` already decrements `hero_invuln` once per frame.
  Person 1 must NOT decrement it again in frame step 6.
* **Person 2: `AddCoin` and `AddLife`** do not exist in world.asm yet.
  Until then `GiveCoin` keeps a private counter `p3_coins` (test only) and `GiveLife`
  writes `lives` directly (the only line of Person 3 that writes a Person 2 variable).
  When Person 2 adds the procedures, only `GiveCoin` / `GiveLife` change.
* **Person 2: sprites.** `DrawHero` / `DrawEntities` draw coloured rectangles. Replace the
  `FillRect` calls with `DrawSprite` when sprites.inc is merged.

## Other procedures in gameplay.asm (internal)

Module 9: `HeroHeight`, `HeroHorizontal`, `HeroVertical`.
Module 10: `TileSolid`, `HeroColumnSolid`, `HeroRowSolid`, `HeroXCollide`, `HeroYCollide`.
Module 11: `CountActive`, `EnemyUpdate`, `EnemyIdle`, `EnemyFlat`, `EnemyMove`, `EnemyWalkX`,
`EnemyHitsOther`, `EnemyFall`, `ResolveEnemies`, `ResolveOne`, `StompEnemy`, `StompReward`,
`KickShell`, `ResolveShells`, `ShellKills`, `HeroHurt`.
Module 12: `HeadHitBlock`, `HitBlock`, `SpawnMushroom`, `HeroGrow`, `CollectMapCoins`,
`CoinColumn`, `CheckPit`, `FlagColumn`, `CheckFlag`, `GivePoints`, `GiveCoin`, `GiveLife`.

## Enemy record use (constants.inc layout, 10 bytes)

| Field | Use |
|---|---|
| EN_TYPE | 0 free, 1 Goomba, 2 Koopa, 3 mushroom |
| EN_STATE | 0 idle, 1 walking, 2 flat Goomba, 3 stationary shell, 4 sliding shell |
| EN_TIMER | walking: fraction byte of the position; flat: frames left; shell: kick grace frames |
| EN_SPEED / EN_DIR | speed 8.8 (Goomba 0.5, Koopa 0.75, shell 3, mushroom 1) / 0 = left, 1 = right |

## Private constants and variables (end of gameplay.asm)

Constants: HITBOX_L/R/W, ET_* (types), ES_* (states), ENEMY_FALL, COL_* (temporary colours).
Variables: `stomp_table`, `flag_points`, `p3_prev_feet`, `p3_stomped`, `p3_score_lo/hi`,
`p3_coins`, `p3_pop_x/y/t`.

## Shared-file changes by Person 3

* data.inc: added `hero_dead` and `level_won` (Hero section).
* Nothing else in constants.inc, data.inc or mario.asm was changed.
