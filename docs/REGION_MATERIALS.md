# Floors and Materials by Region

**Principle:** floors become *less built and more carved* the deeper you go. The material underfoot tells the player where they are and how deep they've come. Flagstones are a surface material, so they return only near the end, at Hearthmere: a quiet sign that you're almost out.

| Depth | Region | Character of the floors |
|---|---|---|
| Upper | **Gloamhold** (Act 1) | Imperial construction (dressed stone, brick, iron, timber), increasingly cut straight from the Rift's cliff |
| Middle | **The Lowmarch** (Act 2) | Bare cliff and scree, with bolted planks and rope bridges. Old flagstones only at the watch-posts built on ledges |
| Deep | **The Hollowreach / Undervault** (Act 3) | Living rock and natural formations |
| Deepest | **The Ashen Delvings** (Act 4) | The Mine-Kings' precise monumental stonework, and working mine tunnels |
| Home | **Hearthmere** | Flagstones, packed earth and grass: the surface again |

## Gloamhold

### Floor 1: The Penance Cells (prison)
| Material | Where | Notes |
|---|---|---|
| **Rock-cut floor** | Cell blocks hewn into the cliff | Continuous rock with chisel marks worked in different directions, and hairline fissures. No joints at all. |
| **Dressed slabs** | Corridors, guard halls | Imperial paving in uneven courses and sizes: cracked, sunken and shifted over the centuries. |
| **Packed earth + straw** | Inside cells | Pale, sparse straw bedding over grey-brown earth, heaviest against the back wall. |
| **Iron grates** | Over the oubliette shafts (the Drop) | You see the Rift's glow far below. Rust has eaten through some bars: these are the crumbling rims. |
| **Bronze seals** | Judgement halls | Tarnished, with verdigris. Polished bright only where feet cross them. |

Swatches: `assets/art/style_test/materials/swatches_penance_cells.png`. How they meet: `cellblock_vignette.png`.

Weeping Cistern swatches: `swatches_weeping_cistern.png`. Cinder Foundry swatches: `swatches_cinder_foundry.png`.

### Floor 2: The Weeping Cistern
- **Basketweave brick** under vaults, slick with algae (herringbone is an alternative)
- **Tooled stone** with carved water channels and drains
- **Timber walkways and iron catwalks** over deep water (some planks rotten)

### Floor 3: The Cinder Foundry
- **Riveted cast-iron plates**
- **Soot-stained brick** hearth floors
- **Cooled slag channels,** with glowing cracks near the furnaces

## Below the fortress
- **The Lowmarch:** bare rock, scree, plank walkways bolted to the cliff, rope bridges, wyrmkite droppings. Old flagstones survive only in the watch-posts built on ledges.
- **The Undervault:** flowstone, terraced mineral pools, moss carpets, fungi, still lake shores and crystal veins.
- **The Ashen Delvings:** the Mine-Kings' huge single-block floors with carved channels; mine tunnels with cart rails, timber shoring and drifts of ash.

## Where materials meet: always give the boundary a reason
- **Cell to corridor:** a long dressed **sill stone** in the doorway, with iron door posts. *(Shown in the vignette.)*
- **Paving to shaft:** an iron frame around the grate.
- **Dry to flooded:** a step down, a drain channel or a kerb.
- **Built to natural:** broken ends of paving give way to rubble, then bare rock.
- **Surface layers** (straw, moss, soot, ash) fade out patch by patch, never along a straight line.

## Floors as gameplay (footsteps built; the rest proposed)

**Built:** footstep noise by material in the test room (straw silent, stone and brick quiet, puddles 120px, iron 160px; crouching is always silent). The bake writes a material map, so the art and the gameplay can never disagree.
Each material can change how you sneak, so players read a room by its floor.

| Floor | Footsteps | Other effect |
|---|---|---|
| Straw, moss, packed earth | Quiet | none |
| Rock-cut, dressed stone | Normal | none |
| Iron plates, grates, slag | Loud | Grates: you can see the floor below, and things below can see you |
| Rotten planks | Creak | A heavy body (the Gaoler!) can break through, making a new pit |
| Shallow water, puddles | Splash | Wet footprints that hounds follow more easily |
| Ash | Normal | Leaves visible footprints that guards and hounds can track |

## Generators
`tools/pixelart/materials.py` has a separate generator for each material: `rock_cut`, `dressed_slabs`, `earth_straw`, `iron_grate` and `bronze_inlay`. All are palette-snapped, normal-mapped and lit the same way. The natural-floor generator (`natural_room.py`) remains the base for the Lowmarch outposts and Hearthmere's flagstones. Later regions get their own generators: brick, planks, iron plates, cave rock.
