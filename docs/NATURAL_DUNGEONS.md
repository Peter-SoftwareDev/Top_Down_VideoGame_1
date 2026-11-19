# Natural-Looking Dungeons

**Problem:** repeated 32×32 tiles create an obvious grid. Your eye finds the same stone again and again.
**Goal:** floors and walls that feel built, worn and ruined over centuries, without hand-painting every room.

## What the research says
1. **Variants and Wang tiles reduce repetition but don't remove it.** Several slightly different copies of a tile help. Wang/corner tiles (edges that must match their neighbours) give more variety but are harder to draw, and the pattern still repeats. Sean Barrett's **herringbone Wang tiles** break up grid artifacts in *layouts*, not textures.
2. **Avoid dominant, high-contrast details inside a tile.** One bright stone or crack in a tile makes every repeat obvious (*Pixel Art for Game Developers*).
3. **Layer large-scale variation over small detail.** A slow colour/tone drift across the whole room (a "macro" layer) plus decals placed on top hides repetition well.
4. **Voronoi/Worley cells make natural flagstones.** Each cell becomes a stone; warping the coordinates with noise roughens the joints; jitter controls how regular the stones are. This is the classic procedural flagstone technique.
5. **In Godot,** terrains pick between alternative tiles using a probability per tile, so tile variants are easy if we keep some tiles.

## The approach I recommend: "paint the story, generate the stones"
**Don't build floors from tiles at all.** Generate each room's floor as **one continuous surface**, driven by maps describing *what happened in this room*:

| Map | Comes from | Effect |
|---|---|---|
| **Wear** | Routes people walk (doorway to doorway), drawn as lines | Big smooth slabs, paler and polished, thin joints |
| **Moisture** | Distance to water, leaks, low spots | Damp darker stone, moss in the joints, puddles, small rough cobbles |
| **Grime** | Corners, wall bases, pit rims | Darker, dirtier, straw and debris build up |
| **Age / ruin** | Painted by hand, or noise | Missing stones, cracks, rubble, collapsed edges |
| *Region-specific:* **heat** (Foundry) | Furnaces and slag channels | Soot, scorch marks, glowing cracks |

Prototype result: `assets/art/style_test/natural_vs_tiled.png` (top: tiles, bottom: generated). Everything is still snapped to the game's palette with dithering, so it stays pixel art, and it keeps normal maps so torchlight works.

## Twelve ideas for natural dungeons
1. **Whole-room floors** from warped Voronoi stones, in **three sizes chosen by zone** (slabs on routes, flagstones in general, cobbles in damp ground), with seams where zones meet. *(Prototyped.)*
2. **Story maps** (wear, moisture, grime) generated from the level layout: water, walls, pits, plus "wear paths" you draw in the editor. *(Prototyped.)*
3. **Hand-painted control maps:** for special rooms, you paint a rough low-res map (e.g. red = worn, green = damp) and the generator does the stones. You direct, it details.
4. **Ragged hazards:** pit edges follow stone joints, so whole stones break away. *Collision must match:* the game would build the pit's collision polygon from the same noise, so what you see is exactly where you fall. *(Visual prototyped.)*
5. **Irregular masonry walls:** random block lengths and course heights, plus missing blocks, moss streaks below leaks, and roots in the deeper floors. *(Basic version prototyped.)*
6. **Scatter with spacing (Poisson disc):** pebbles, straw, bones and rubble placed so they never clump unnaturally. *(Prototyped.)*
7. **Hand-placed hero details on top:** imperial banners, chains, carvings, a prisoner's tally marks, blood trails. Generation does the background; the story is placed by hand.
8. **Contact shadows and dirt build-up** where floors meet walls, crates and pillars, so objects sit *in* the room rather than on top of it.
9. **A material set per region:**
   - *Penance Cells:* old flagstones, straw, iron grates
   - *Weeping Cistern:* slick stone, algae, drains, puddles
   - *Cinder Foundry:* iron plates, soot, slag, glowing cracks
   - *Lowmarch and Undervault:* living rock caves, with shapes from cellular automata, fungi and crystals
10. **Organic cave shapes** for the Hollowreach, using cellular automata or noise thresholds, so caverns look carved by water rather than built.
11. **A different seed each run:** a room keeps its layout, but its stones, cracks and debris change between runs. The game feels familiar but never identical.
12. **If we keep any tiles** (e.g. hand-drawn special floors): many low-contrast variants with Godot tile probabilities, corner/Wang transitions, and a macro tint over the top.

## How this would work in Godot
- **A room-art tool** (an in-editor button, built on `tools/pixelart/natural_room.py`) reads the room's walls, hazards, water and drawn wear paths, and bakes **albedo + normal-map textures** for the floor and walls.
- **In the scene:** each room's floor is one Sprite2D with a CanvasTexture (albedo + normal map) under the existing gameplay geometry, so torchlight and shadows keep working.
- **Ragged pits:** the same noise produces the visual edge *and* the CollisionPolygon2D for the rim and the fall zone.
- **Characters, props and hero details** stay as sprites on top.

## Sources
- [7 ways to break texture repetition (AITextured)](https://aitextured.com/articles/7_proven_ways_to_break_texture_repetition_on_large_surfaces.html)
- [Wang 2-corner tiles (DEV)](https://dev.to/joestrout/wang-2-corner-tiles-544k)
- [Pixel Art for Game Developers, ch. 32 (O'Reilly)](https://www.oreilly.com/library/view/pixel-art-for/9781482252316/chapter-32.html)
- [gamedev.net discussion on tile variants](https://gamedev.net/forums/topic/652513-side-scroller-level-textures/5125547/)
- [Top-down tiles, Pixelblog 43 (Slynyrd)](https://www.slynyrd.com/blog/2023/3/26/pixelblog-43-top-down-tiles-part-2)
- [stb herringbone Wang tile library](https://flutter.googlesource.com/third_party/stb/+/refs/heads/master/stb_herringbone_wang_tile.h)
- [Seeded exploration of Wang-tiled environments (Game Developer)](https://www.gamedeveloper.com/design/seeded-exploration-of-wang-tiled-environments)
- [Worley, "A Cellular Texture Basis Function"](https://cedric.cnam.fr/~cubaud/PROCEDURAL/worley.pdf)
- [Tileable Voronoi stone floor (gamedev.net)](https://comic.gamedev.net/blogs/entry/1831906-back-to-the-floor)
- [Voronoi noise jitter (PCGEx)](https://pcgex.gitbook.io/pcgex/node-library/utilities/noise/noise-voronoi)
- [Godot forum: random autotiles and probability](https://forum.godotengine.org/t/how-to-use-random-autotiles-in-godot-4/4022)
