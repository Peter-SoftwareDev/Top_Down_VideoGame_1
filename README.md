# Top Down Dungeon

A top-down survival dungeon crawler built in Godot 4.7. A prisoner escapes down through a ruined imperial fortress.
See [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) for the full design.

## Current milestone: M0 combat sandbox

One gray-box room for testing whether physics combat is fun before building floors, keys and progression.

- **Two loadouts** (press Q to swap while testing):
  - **Crossbow + Shove**: a lethal bolt at range, plus a short-range shove that doesn't kill but sends guards flying.
  - **Blade + Stun Rock**: a lethal slash up close, plus a thrown rock that stuns, knocks back and makes noise.
- **Hazards:** guards knocked over the rim of a pit fall in, and guards knocked into deep water drown. Guards on foot never wander in by themselves. The player can't fall in.
- **Chain reactions:** a guard knocked into another guard passes the push along. A guard slammed hard into a wall is stunned.
- **Guards:** patrol, spot you with a vision cone, telegraph their lunge (orange wind-up ring), and investigate noises (`?`).
- **Stealth bonus:** a lethal hit on an unaware guard kills it outright. Hits on stunned guards do double damage.

### Controls

| Action | Input |
|---|---|
| Move | WASD / arrow keys |
| Aim | Mouse |
| Primary (bolt / slash) | Left mouse |
| Secondary (shove / rock) | Right mouse or E |
| Dodge (brief invulnerability) | Space or Shift |
| Swap loadout | Q or Tab |
| Reset room | R |

## Running the project

Open `project.godot` in Godot 4.7 and press F5.

## Project structure

- `scenes/Main.tscn`: the sandbox room. Walls, hazards, torches and guards can all be moved in the editor.
- `scripts/Player.gd`, `scripts/Enemy.gd`: the player and the guards. Tuning constants sit at the top of each file.
- `scripts/Hazard.gd`: pits and deep water (set `kind` and `size` in the inspector).
- `scripts/Bolt.gd`, `scripts/Rock.gd`: projectiles.
- `scripts/Wall.gd`, `scripts/Floor.gd`, `scripts/Torch.gd`: gray-box level pieces.
- `scripts/Fx.gd`, `scripts/fx/`: popups, rings, noise and screen shake.
- `scripts/Layers.gd`: physics layer numbers.
