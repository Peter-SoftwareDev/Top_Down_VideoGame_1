extends RefCounted
## Physics layer bit values. Names match Project Settings > Layer Names > 2D Physics.

const WORLD := 1         # Layer 1: tall walls and pillars. Block sight and light.
const PLAYER := 2        # Layer 2: the player.
const ENEMY := 4         # Layer 3: enemies.
const HAZARD_EDGE := 8   # Layer 4: invisible rim around pits and deep water.
const HAZARD_ZONE := 16  # Layer 5: inner area of a hazard; touching it means falling in.
const PROP := 32         # Layer 6: crates and other pushable objects (low cover).
const LOW_WALL := 64     # Layer 7: barricades / half walls (low cover).
const TORCH := 128       # Layer 8: torches and braziers (can be knocked out).

## Low cover: hides a crouching player, but guards see over it otherwise.
const LOW_COVER := PROP | LOW_WALL
## What blocks a guard's sight of a crouching player.
const SIGHT_MASK := WORLD | LOW_COVER
## What projectiles hit.
const PROJECTILE_MASK := WORLD | ENEMY | LOW_COVER

## Bodies on foot stop at the rim of a pit or pool...
const PLAYER_MASK := WORLD | ENEMY | HAZARD_EDGE | LOW_COVER
const ENEMY_WALK_MASK := WORLD | PLAYER | ENEMY | HAZARD_EDGE | LOW_COVER
const PROP_REST_MASK := WORLD | PLAYER | ENEMY | HAZARD_EDGE | LOW_COVER
## ...but anything knocked back slides straight over it.
const PLAYER_KNOCK_MASK := WORLD | ENEMY | LOW_COVER
const ENEMY_KNOCK_MASK := WORLD | PLAYER | ENEMY | LOW_COVER
const PROP_KNOCK_MASK := WORLD | PLAYER | ENEMY | LOW_COVER
