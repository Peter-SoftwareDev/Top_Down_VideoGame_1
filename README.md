# Top Down Dungeon

A top-down survival dungeon crawler built in Godot 4.7. A prisoner escapes down through a ruined imperial fortress.
See [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) for the full design.

## Current milestone: M0 combat sandbox

A gray-box test area for physics combat, before building real floors, keys and progression. The original room is surrounded by three test zones connected by doorways:
- **The Bridge** (east): a narrow walkway between two pits, one with a crumbling rim, and a guard patrolling it.
- **The Dark Hall** (south-east): unlit, with barricades and crates for stealth, an unlit brazier, guards and a hound.
- **The Channel** (south): a long deep-water channel with a second Gaoler and a guard patrolling beside it.

- **Weapon select:** pick a loadout at the start. It's locked in for the run; R resets the room with the same loadout, and Esc goes back to the select screen.
- **Two loadouts:**
  - **Crossbow + Kick**: a lethal bolt at range, plus a short-range kick that doesn't kill but sends guards (and crates) sliding.
  - **Blade + Stun Rock**: a lethal slash up close, plus a thrown rock that stuns, knocks back and makes noise.
- **Charges and ammo:** the kick and the rock each have 1 charge that refills on a cooldown. Bolts and rocks are limited, but you can pick them up again where they land. Dropped ammo shows a marker that's visible even in the dark, and arrows at the screen edge point to ammo that's off-screen. Ammo that goes into a pit or water is lost.
- **Hazards:** guards knocked over the rim of a pit fall in, and guards knocked into deep water drown. The chasm's cracked rim crumbles under a guard that skids to a stop on it. A guard's hit can throw *you* in too (pit −2 health, water −1).
- **Crates:** block sight, slide when kicked, crush guards they hit, and break noisily after two hard impacts, spilling any ammo inside.
- **Chain reactions:** anything knocked into a guard or crate passes the push along. A guard slammed hard into a wall is stunned, and a stunned guard flies further when kicked.
- **Guards:** patrol with vision cones. Seeing you fills a suspicion meter (faster up close). When it's full, the guard stops to shout "HEY!", which brings nearby guards running. Kill or knock it mid-shout to stop the alarm. Once alerted, guards stay wary for the rest of the room: they see further, sweep around, and patrol your last known spot. Their lunge is telegraphed (orange ring), but sometimes delayed as a feint.
- **Crouch:** hold C or Ctrl to move slowly and hunch down. Crouched behind low cover (crates and the stone barricades), guards can't see you. Standing, they see over it. Crouching in the open also makes guards slower to notice you.
- **Light and shadow:** guards see you much further in torchlight than in darkness: in pitch dark, an unaware guard sees about a third as far. Tall walls and pillars cast real shadows. The eye icon under your HUD panel shows how visible you are (LIT / DIM / DARK). Your own faint glow is just so you can see; guards ignore it.
  - **Douse lights:** hit a wall torch or a brazier with a bolt or a rock to put it out. It hisses (a noise), and a guard who comes to check will relight it, so dousing doubles as a lure.
  - **Braziers** stand in the room as waist-high low cover you can crouch behind.
- **Gaoler (brute):** big, slow, 6 health. Kicks and rocks don't move it ("TOO HEAVY"). Only a crash from a guard or crate, or slamming into a wall, staggers it, and while staggered it can be kicked and takes double damage. From mid-range it telegraphs a straight shoulder charge with an orange lane on the floor. Sidestep it into a wall and it staggers. Get hit and you take 2 damage and get thrown hard (possibly into a pit). It bowls over guards and crates in its path, and crushes anything it pins against a wall. It won't charge at you across a pit, water or a half wall (barricade), but if the chasm is *behind* you, sidestep and it overshoots straight in.
- **Scent-hounds (pair):** fast and fragile (1 health). Short sight, but they follow the trail you walked over the last ~9 seconds, and smell you through cover up close. Their bark carries further than a shout. They're light, so kicks and rocks send them twice as far. Shake them off by outpacing the trail, or distract them with a rock.
- **Stealth bonus:** a lethal hit on an unaware guard kills it outright. Hits on stunned guards do double damage.
- **Floors and footsteps:** the test room has baked floor art: imperial paving in the main hall, hewn rock on the Bridge with an **iron catwalk** between the pits, hewn cells with **straw** in the Dark Hall, and Cistern **brick** around the Channel. Walking makes noise depending on the floor: straw is silent, stone and brick are quiet (only very close guards hear), puddles splash, and iron is loud enough to draw guards from about 160px. Crouching is always silent. The HUD shows the floor under you and how loud it is.
- **Characters and gear:** everyone is a pixel-art sprite with walk, idle, crouch and attack frames in four directions, lit by the torches. The player is built from gear layers (cloak, head, torso, hands, feet), so his look changes with what he wears. Press **G** to try the four gear sets: Prisoner, Scavenger, Turncoat (stolen guard gear) and Relic-bearer. Guards use the same layers in Gaolwarden gear.
- **Walls and pits:** walls are drawn as irregular masonry with a front face. Pits have broken, ragged edges, and their collision follows the drawn edge exactly.
- **Feel:** a short hit stop on heavy hits, and slow motion on falls and drownings.

### Controls

| Action | Input |
|---|---|
| Move | WASD / arrow keys |
| Aim | Mouse |
| Primary (bolt / slash) | Left mouse |
| Secondary (kick / rock) | Right mouse or E |
| Dodge (brief invulnerability, 1s cooldown) | Space or Shift |
| Crouch | Hold C or Ctrl |
| Back to weapon select | Esc |
| Try gear sets (testing) | G |
| Reset room | R |

## Floor art

The floor is baked from the room's layout by `tools/pixelart/bake_test_room.py` (Python 3 with Pillow and NumPy). After moving walls or hazards in `scenes/Main.tscn`, rebake:

```
python3 tools/pixelart/bake_test_room.py
```

It writes `assets/art/rooms/test_room_albedo.png`, `test_room_normal.png` and `test_room_materials.png` (the footstep map). The game works without Python; it's only needed to rebake. Material swatches for all of Gloamhold come from `tools/pixelart/materials.py`.

## Running the project

Open `project.godot` in Godot 4.7 and press F5.

## Project structure

- `scenes/Main.tscn`: the sandbox room. Walls, hazards, torches and guards can all be moved in the editor.
- `scripts/Player.gd`, `scripts/Enemy.gd`: the player and the guards. Tuning constants sit at the top of each file.
- `scripts/LoadoutSelect.gd`: the weapon select screen.
- `scripts/Gaoler.gd`, `scripts/Hound.gd`: enemy types built on `Enemy.gd`.
- `scripts/Hazard.gd`: pits and deep water (set `kind`, `size` and `crumbles` in the inspector).
- `scripts/Bolt.gd`, `scripts/Rock.gd`, `scripts/Pickup.gd`: projectiles and ammo pickups.
- `scripts/Crate.gd`: breakable, kickable crates (set `contents` in the inspector).
- `scripts/CharacterSprite.gd`: layered character sprites (gear stacking, outline, normal map, animation). Layers come from `tools/pixelart/characters.py`.
- `scripts/Floor.gd`: shows the baked floor (with its normal map) and answers "what material is here?" for footsteps.
- `scripts/Wall.gd`, `scripts/Torch.gd`: gray-box level pieces (tick `low` on a wall to make it a barricade).
- `scripts/Fx.gd`, `scripts/fx/`: popups, rings, noise and screen shake.
- `scripts/Layers.gd`: physics layer numbers.
