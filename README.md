# Top Down Dungeon

A simple top-down shooter prototype built in Godot 4.

## Project structure

- `scenes/` contains the game scenes.
- `scripts/` contains the gameplay logic.
- `assets/art/` and `assets/sound/` are reserved for future art and audio.

## First milestone

The prototype includes:

- WASD movement
- shooting toward the mouse
- enemy spawning
- basic health and score tracking
- a HUD

## Running the project

Open `project.godot` in Godot 4 and press F5 to run the game.

## Suggested workflow

1. Create a scene.
2. Attach a script.
3. Test in Godot.
4. Refine behavior.
5. Save and commit.

## Input actions to add in Godot

Set these actions in Project > Project Settings > Input Map:

- `move_up` -> `W`
- `move_down` -> `S`
- `move_left` -> `A`
- `move_right` -> `D`
- `shoot` -> left mouse button or `Space`
