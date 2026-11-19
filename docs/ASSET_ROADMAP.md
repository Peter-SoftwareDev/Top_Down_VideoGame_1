# Asset Roadmap: Art, Music, Sound

Decision order: **art → music → sound effects**. Each section gives the options, a recommendation, and concrete first steps. See also [`ART_DIRECTION.md`](ART_DIRECTION.md).

---

## 1. Art

### Can code-generated pixel art be the final art? Honest answer
I generated a full style test (`assets/art/style_test/`): a palette, floor/wall tiles, a crate, a barricade, an animated torch, a brazier, the prisoner, a guard, the Gaoler, a hound, normal maps for all of them, and a lit 960×540 scene. Results:
- **Strong:** the palette, mood, lighting, tiles, simple props, and the chasm's depth. Code is very good at consistent, procedural materials.
- **Weaker:** characters and anything needing expressive drawing (faces, poses, animation). The grid-drawn characters read fine at game size but look stiff up close.

**So:** code-generated art is excellent for **tiles, materials, lighting, effects and placeholders**, and for setting up the pipeline. For the **beautiful, hand-worked characters and key art** you want, a human artist (you or someone you commission) should draw them, using the palette and rules set here.

### Paths
| Path | Cost | Speed | Result |
|---|---|---|---|
| **A. You learn pixel art** in Aseprite (~$20 one-time on Steam), helped by my generated tiles and palette | Time | Slow at first | Truly your own style |
| **B. Commission a pixel artist** for characters and key pieces; I generate tiles, effects and normal maps | Money (rates vary widely; get quotes for one character with walk + attack animations first) | Fast | Polished and consistent |
| **C. Hybrid (recommended):** I generate environment tiles and effects in code; you or an artist draw characters | Moderate | Good | Hand-made where it matters most |

### First steps (in order)
1. **Lock the palette** (`assets/art/style_test/palette.gpl` opens directly in Aseprite).
2. **I set up the pipeline in Godot:** 960×540 base resolution with whole-number scaling, pixel snapping, normal-mapped lighting, a TileMapLayer with terrains, and animated sprites. The gray-box shapes then get swapped for sprites.
3. **Replace the gray-box with the generated tiles and props.** I can do this right away.
4. **Characters:** draw the prisoner first (idle, walk, crouch and kick, 4 directions), as the reference for every other character.
5. **Normal maps:** generate them with the included script, or with **Laigter** (free, open source) for hand-drawn sprites.

---

## 2. Music

### What the game needs
- **Adaptive layers tied to the suspicion system:** a calm ambient bed while sneaking, a tension layer that fades in as any guard's suspicion rises, and percussion when an alarm goes off. Godot has this built in: **AudioStreamSynchronized** for layers that play in sync and fade in and out, and **AudioStreamInteractive** for switching sections with transition rules.
- **Style:** dark ambient. Low drones, bowed and low strings, sparse plucked or hammered instruments, distant choir, and metallic resonances (chains, bells) that come from the world itself. One short theme (a "Hearthmere" motif) that returns, transformed, in each region.

### Paths
| Path | Notes |
|---|---|
| **A. Compose it yourself** | **Bosca Ceoil Blue** (free, very beginner-friendly), **LMMS** (free) or **Reaper** (inexpensive) with free instrument libraries such as **Spitfire LABS** (strings, choir, drones). Dark ambient is one of the most forgiving genres to start in. |
| **B. Commission a composer** | Ask for **stems** (separate layers), not just finished tracks, so the adaptive system works. |
| **C. Licensed music** | For placeholders only (CC-BY tracks need credits). It won't feel like *this* game. |

**Recommendation:** start with **A** using placeholders during development, and decide on **B** once the art direction is locked, because music should follow the look.

---

## 3. Sound effects

### What the game needs
- **Gameplay readability first:** a distinct sound for every telegraph (wind-up, shout, bark, Gaoler charge), for suspicion rising, and for noise events (rock landing, crate breaking, torch doused). The noise rings you see should match what you hear.
- **A hand-made feel:** real recorded foley (stone, wood, chains, cloth, water) fits far better than retro synth sounds.

### Paths
| Path | Notes |
|---|---|
| **A. Record your own foley** | A phone or a small recorder is enough. Knock stones, break sticks, drag chains, splash water, rustle cloth. Edit in **Audacity** (free). The most "hand-worked" option, and fun. |
| **B. Free libraries** | **Sonniss GDC bundles**: free, royalty-free, released yearly (a 2026 bundle is out; check its licence on Sonniss's site). **Kenney** audio packs (CC0). **Freesound** (check each file's licence; prefer CC0). |
| **C. Generated placeholders** | jsfxr / ChipTone, or I can synthesize simple thuds, swishes and hisses in code. Placeholders only. |

**In Godot:** **AudioStreamRandomizer** (built in) plays slight pitch and volume variations so repeated sounds don't feel robotic. Audio buses give per-area reverb (stone halls vs. the open Rift).

**Recommendation:** **B now** (the Sonniss bundles cover most needs for free), plus **A** for signature sounds (the kick, the Drop, the crate break).

---

## What I can do next, in order
1. **Art pipeline + swap the gray-box for the generated tiles and props** (a big visual jump, fully reversible).
2. **Audio system:** sound hooks on every gameplay event, audio buses, and an adaptive-music controller driven by guard suspicion and alarms, ready for placeholder or real audio.
3. **Mechanics from `MECHANICS_REVIEW.md`,** starting with last known position and body discovery.

## Sources checked (November 2026)
- [Building adaptive music in Godot with AudioStreamInteractive (uhiyama-lab)](https://uhiyama-lab.com/en/notes/godot/adaptive-music-system/), [Godot AudioStreamInteractive class reference](https://docs.godotengine.org/fr/4.3/classes/class_audiostreaminteractive.html), [Godot forum: combining AudioStreamInteractive and AudioStreamSynchronized](https://forum.godotengine.org/t/help-combining-audiostreaminteractive-and-audiostreamsynchronized/100519)
- [Sonniss GDC 2026 bundle (Bedroom Producers Blog)](https://bedroomproducersblog.com/2026/03/16/sonniss-gdc-2026-bundle/), [rekkerd.org on the GDC 2026 bundle](https://rekkerd.org/sonniss-releases-gdc-2026-game-audio-bundle/)
- [Aseprite on SteamDB (price)](https://steamdb.info/app/431730), [Laigter on itch.io](https://azagaya.itch.io/laigter)
