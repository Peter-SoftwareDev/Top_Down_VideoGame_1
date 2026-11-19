extends RefCounted
## Physics layer bit values. Names match Project Settings > Layer Names > 2D Physics.

const WORLD := 1         # Layer 1: walls and pillars.
const PLAYER := 2        # Layer 2: the player.
const ENEMY := 4         # Layer 3: enemies.
const HAZARD_EDGE := 8   # Layer 4: invisible rim around pits and deep water.
const HAZARD_ZONE := 16  # Layer 5: inner area of a hazard; touching it means falling in.
const PROP := 32         # Layer 6: crates and other pushable objects.

## What blocks a guard's line of sight.
const SIGHT_MASK := WORLD | PROP
## What projectiles hit.
const PROJECTILE_MASK := WORLD | ENEMY | PROP

## Bodies on foot stop at the rim of a pit or pool...
const PLAYER_MASK := WORLD | ENEMY | HAZARD_EDGE | PROP
const ENEMY_WALK_MASK := WORLD | PLAYER | ENEMY | HAZARD_EDGE | PROP
const PROP_REST_MASK := WORLD | PLAYER | ENEMY | HAZARD_EDGE | PROP
## ...but anything knocked back slides straight over it.
const PLAYER_KNOCK_MASK := WORLD | ENEMY | PROP
const ENEMY_KNOCK_MASK := WORLD | PLAYER | ENEMY | PROP
const PROP_KNOCK_MASK := WORLD | PLAYER | ENEMY | PROP
