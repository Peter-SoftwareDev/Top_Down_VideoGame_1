# Art Direction (proposal)

**Goal:** a game that feels beautiful, hand-made and gloomy, where light and darkness are both the mood and the gameplay.

## Recommended style: hand-made pixel art with real lighting

Hand-pixelled sprites and tiles, lit by Godot's 2D lights with **normal maps**, so torchlight rakes across stone, crates and armour as you move.

Why this fits:
- **Light and shadow are already a core mechanic.** Normal-mapped pixel art makes "is this spot lit?" beautiful and readable at the same time.
- **Pixel art reads as hand-made.** Every pixel is a decision. It also scales well to a small team: one person can make it.
- **It suits Godot** (TileMapLayer terrains, AnimatedSprite2D, normal maps, light occluders) and our current gray-box geometry.

### Technical baseline
| Setting | Choice | Why |
|---|---|---|
| Base resolution | **960×540**, scaled ×2 to 1080p (×4 to 4K) | Whole-number scaling keeps pixels crisp. Shows about the same amount of the room as the current camera. |
| Tile size | **32×32** | Matches the current world scale (player ≈ 24px across). |
| Characters | About **24×32** sprites, 3/4 top-down view | Readable silhouettes at this size. |
| Directions | **4 directions** (left mirrors right) + a freely rotating weapon | Much less animation work than 8 directions; mouse aim still feels exact. |
| Filtering | Nearest-neighbour, pixel snapping on | No blurry pixels. |
| Lighting | Normal map for every tile and sprite, shadows from walls | Torches already cast shadows in the prototype. |

### Palette (about 40 colours, chosen up front)
- **Stone and shadow:** cold blue-violet greys. The fortress is old, wet and dark.
- **Firelight:** ember orange and warm gold. The only warmth in the world, and it means danger (you're visible).
- **The Rift and the Deep:** a faint teal or green glow from below. Mysterious, not friendly.
- **Water:** deep blue-black with pale ripple highlights.
- **Danger (UI only):** a muted blood red for alerts and wind-ups.

### Things that make it feel hand-made
- **Detail placed by hand:** cracks, puddles, chains, bones, collapsed masonry and banners of the fallen empire, so no corner looks generated.
- **Depth in the chasms:** several parallax layers that shift slightly with the camera, so pits feel bottomless. Faint lights far below hint at the floors underneath.
- **Living light:** flickering flames, drifting embers, dust motes in torch beams, mist over water.
- **Small animation touches:** guards shift their weight, hounds sniff the ground, the Gaoler breathes heavily, crates splinter into pieces.
- **Dithering** in gradients (light falloff, fog) instead of smooth blends.

## Alternatives considered
- **Hand-painted 2D (illustrated look):** gorgeous, but slower to produce and harder to keep consistent across many animations.
- **3D models rendered into pixel sprites:** makes many directions and animations easy, but needs 3D skills and can look less hand-made.
- **Minimal flat shapes (like the current gray-box) with strong lighting:** cheapest, and could look elegant, but loses the "hand-worked" feeling you want.

## Who makes the art? Options
1. **You learn pixel art** (Aseprite is the standard tool, about 20 USD). Start with tiles: stone floor, wall, pit rim. Characters come later.
2. **Commission a pixel artist** for a style test, then the core set.
3. **Placeholder asset packs** (CC0, e.g. Kenney) to prototype the pipeline, replaced later.

What I can do: set up the pipeline (base resolution and scaling, pixel snapping, normal-map lighting, tilemap terrains, animation hookup), write the art bible and shot lists, and make simple procedural placeholders in the right format so real art can drop straight in.

## Suggested next step: one style test
Make **one 960×540 scene** of the Prison: floor and wall tiles, one pit rim, a torch, a crate, the player and a guard (idle and walk), all lit and normal-mapped. If that one image feels right, the rest of the game follows from it.
