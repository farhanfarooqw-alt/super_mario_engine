# Super Mario Engine

**EL2003 – Computer Organization and Assembly Language**

FAST-NUCES | Fall 2026

A side-scrolling platform game developed in 16-bit x86 Assembly Language using NASM and VGA Mode 13h. The game runs in DOSBox.

## 1. Team Members

| Member | Roll Number | Assigned Modules |
|---|---|---|
| Farhan | 25F-0804 | 1, 2, 5, 7, 8, 14, 15 |
| Ahsan | 25F-0722 | 3, 4, 6, 13 |
| Haroon | 25F-0555 | 9, 10, 11, 12 |

## 2. Software Requirements

- NASM Assembler
- DOSBox 0.74-3 or later
- Windows Command Prompt
- Git (optional, for cloning the repository)

## 3. How to Download the Project

Open the GitHub repository:

https://github.com/farhanfarooqw-alt/COAL-PROJECT_BCS-3B_25F-0804_25F-0722_25F-0555

Click **Code → Download ZIP** and extract the downloaded folder.

Alternatively, clone the repository using Git:

`git clone https://github.com/farhanfarooqw-alt/super_mario_engine.git`

## 4. How to Run the Game

### Method 1 — Automatic Launch (Recommended)

1. Open the extracted project folder.
2. Click the File Explorer address bar.
3. Type `cmd` and press Enter.
4. Enter the following command:

`run.bat`

The game will automatically launch in DOSBox with the recommended performance settings.

You can also double-click the `run.bat` file directly.

Make sure DOSBox is installed. If it is installed in a custom location, the DOSBox path in `run.bat` may need to be updated.

### Method 2 — Manual Launch

1. Open DOSBox.
2. Mount the project folder using:

`mount c "C:\Your\Project\Folder"`

Replace the example path with the actual location of the project.

3. Enter:

`c:`

4. Run the game:

`MARIO.COM`

The game will now start.

## 5. How to Compile the Source Code

The compiled `MARIO.COM` executable is already included in the repository.

To rebuild the game after modifying the source code:

1. Install NASM and ensure it is available in the system PATH.
2. Open CMD inside the project folder.
3. Run:

`build.bat`

4. Wait for the `BUILD OK` message.
5. Run:

`run.bat`

The build script assembles the source code into the `MARIO.COM` executable.

## 6. DOSBox Performance Configuration

The project includes a dedicated `dosbox.conf` file configured with:

- CPU core: Auto
- CPU type: Auto
- CPU cycles: Fixed 50000

This configuration improves rendering performance without changing the game's timer-based physics.

When using `run.bat`, the configuration is loaded automatically.

When using the manual launch method, CPU cycles can also be adjusted with:

- Ctrl + F12: Increase CPU cycles.
- Ctrl + F11: Decrease CPU cycles.

## 7. Game Controls

| Key | Action |
|---|---|
| Left Arrow | Move left |
| Right Arrow | Move right |
| Left Shift | Run |
| Space | Jump |
| Hold Space | Higher jump |
| Up / Down | Menu navigation |
| Enter | Select / Continue |
| P | Pause / Resume |
| Esc | Return to title / Exit |

## 8. Game Features

- Side-scrolling platform gameplay.
- Small and Super Mario forms.
- Momentum-based movement and jumping.
- Smooth camera scrolling.
- Tile and entity collision detection.
- Goomba and Koopa enemies.
- Shell kicking and enemy stomping.
- Collectible coins and mushrooms.
- Destructible bricks and question blocks.
- Score, lives, health and countdown timer.
- Multiple game states and screens.
- Level restart and game-over functionality.
- Off-screen frame buffer.
- Custom keyboard and timer interrupt handlers.

## 9. Project File Structure

| File | Purpose |
|---|---|
| src/mario.asm | Main program and game loop |
| src/engine.asm | Graphics, keyboard and timer engine |
| src/world.asm | Map, sprites, camera and HUD |
| src/gameplay.asm | Physics, collisions, enemies and power-ups |
| src/states.asm | Game states and screens |
| src/text.asm | Text rendering procedures |
| src/constants.inc | Shared constants |
| src/data.inc | Shared game variables |
| src/level.inc | Level map |
| src/sprites.inc | Sprite and graphics data |
| src/test_p2.asm | World module testing |
| src/test_p3.asm | Gameplay module testing |
| build.bat | Main compilation script |
| build_p2.bat | World module compilation |
| build_p3.bat | Gameplay module compilation |
| run.bat | Automatic game launcher |
| dosbox.conf | DOSBox performance configuration |
| MARIO.COM | Compiled game executable |

## 10. Memory Management

The COM program uses one 64 KB segment for code, data and stack.

The 64,000-byte frame buffer is allocated in a separate memory segment using DOS interrupts.

The level map is maintained in two copies:

- `map_original`: Original level data.
- `map_working`: Modifiable level data.

When a level restarts, the original map is copied back into the working map using string instructions.

## 11. Game Timing

The Programmable Interval Timer is configured to approximately 30 Hz using divisor 39773.

The INT 08h timer interrupt controls the game loop. The original BIOS timer handler is chained at approximately 18.2 Hz to maintain the DOS system clock.

The original timer and keyboard interrupt vectors are restored when the game exits.

## 12. Game States

The game uses a state machine controlled by `game_state` and a jump table named `state_table`.

| State | Description |
|---|---|
| TITLE | Start game or exit |
| PLAYING | Normal gameplay |
| PAUSED | Gameplay and timer are frozen |
| DYING | Mario's death animation |
| LIFE LOST | Displays remaining lives |
| WIN SEQUENCE | Flag pole and winning animation |
| LEVEL COMPLETE | Final score and time bonus |
| GAME OVER | Displays the final score |
| EXIT | Restores system settings and exits to DOS |

## 13. Debug Controls

The following shortcuts are available during gameplay for testing:

| Key | Purpose |
|---|---|
| K | Force Mario's death |
| W | Simulate flag touch |
| T | Set the remaining time to 5 seconds |

These shortcuts are intended for development and demonstration purposes only.

## 14. Deviations from the Manual

- Positions are stored using a whole-pixel word and a fractional byte because a standard 8.8 fixed-point position cannot represent the entire level width.
- Velocities use signed 8.8 fixed-point arithmetic.
- The bottom eight rows of the frame buffer are cleared to black.
- Screen text uses the BIOS 8x8 font and is drawn into the frame buffer.

## 15. Bonus Features and Known Limitations

- Coin pop-up animation is implemented.
- The win sequence uses the permitted exit/disappearance option instead of entering a castle door.
- Rendering performance depends on the available DOSBox CPU cycles.
- The included DOSBox configuration provides the recommended performance settings.

## 16. Development and Version Control

The project was developed using separate GitHub branches for different module groups.

| Branch | Responsibility |
|---|---|
| states | Engine, interrupts and game states |
| world | Map, sprites, camera and HUD |
| gameplay | Physics, collisions, enemies and power-ups |
| main | Final integrated project |

The individual development history is preserved through Git commits and branch integration.

## 17. Academic Project

Developed as a semester project for the EL2003 Computer Organization and Assembly Language course at FAST-NUCES, Chiniot-Faisalabad Campus, Fall 2026.
