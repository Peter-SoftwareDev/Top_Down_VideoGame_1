# Top Down Dungeon

A top-down survival dungeon crawler built in Godot 4.7. A prisoner escapes down through a ruined imperial fortress.
See [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) for the full design.

## Current milestone: M0 combat sandbox

One gray-box room for testing whether physics combat is fun before building floors, keys and progression.

- **Two loadouts** (press Q to swap while testing):
  - **Crossbow + Kick**: a lethal bolt at range, plus a short-range kick that doesn't kill but sends guards (and crates) sliding.
  - **Blade + Stun Rock**: a lethal slash up close, plus a thrown rock that stuns, knocks back and makes noise.
- **Charges and ammo:** the kick and the rock each have 1 charge that refills on a cooldown. Bolts and rocks are limited, but you can pick them up again where they land (glowing on the floor). Ammo that goes into a pit or water is lost.
- **Hazards:** guards knocked over the rim of a pit fall in, and guards knocked into deep water drown. The chasm's cracked rim crumbles under a guard that skids to a stop on it. A guard's hit can throw *you* in too (pit −2 health, water −1).
- **Crates:** block sight, slide when kicked, crush guards they hit, and break noisily after two hard impacts, spilling any ammo inside.
- **Chain reactions:** anything knocked into a guard or crate passes the push along. A guard slammed hard into a wall is stunned, and a stunned guard flies further when kicked.
- **Guards:** patrol with vision cones. Seeing you fills a suspicion meter (faster up close). When it's full, the guard stops to shout "HEY!", which brings nearby guards running. Kill or knock it mid-shout to stop the alarm. Once alerted, guards stay wary for the rest of the room: they see further, sweep around, and patrol your last known spot. Their lunge is telegraphed (orange ring), but sometimes delayed as a feint.
- **Stealth bonus:** a lethal hit on an unaware guard kills it outright. Hits on stunned guards do double damage.
- **Feel:** a short hit stop on heavy hits, and slow motion on falls and drownings.

### Controls

| Action | Input |
|---|---|
| Move | WASD / arrow keys |
| Aim | Mouse |
| Primary (bolt / slash) | Left mouse |
| Secondary (kick / rock) | Right mouse or E |
| Dodge (brief invulnerability, 1s cooldown) | Space or Shift |
| Swap loadout | Q or Tab |
| Reset room | R |

## Running the project

Open `project.godot` in Godot 4.7 and press F5.

## Project structure

- `scenes/Main.tscn`: the sandbox room. Walls, hazards, torches and guards can all be moved in the editor.
- `scripts/Player.gd`, `scripts/Enemy.gd`: the player and the guards. Tuning constants sit at the top of each file.
- `scripts/Hazard.gd`: pits and deep water (set `kind`, `size` and `crumbles` in the inspector).
- `scripts/Bolt.gd`, `scripts/Rock.gd`, `scripts/Pickup.gd`: projectiles and ammo pickups.
- `scripts/Crate.gd`: breakable, kickable crates (set `contents` in the inspector).
- `scripts/Wall.gd`, `scripts/Floor.gd`, `scripts/Torch.gd`: gray-box level pieces.
- `scripts/Fx.gd`, `scripts/fx/`: popups, rings, noise and screen shake.
- `scripts/Layers.gd`: physics layer numbers.
