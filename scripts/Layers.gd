extends RefCounted
## Physics layer bit values. Names match Project Settings > Layer Names > 2D Physics.

const WORLD := 1         # Layer 1: walls and pillars.
const PLAYER := 2        # Layer 2: the player.
const ENEMY := 4         # Layer 3: enemies.
const HAZARD_EDGE := 8   # Layer 4: invisible rim around pits and deep water.
const HAZARD_ZONE := 16  # Layer 5: inner area of a hazard; touching it means falling in.

const PLAYER_MASK := WORLD | ENEMY | HAZARD_EDGE
## Enemies on foot stop at the rim of a pit or pool...
const ENEMY_WALK_MASK := WORLD | PLAYER | ENEMY | HAZARD_EDGE
## ...but a knocked-back enemy slides straight over it.
const ENEMY_KNOCK_MASK := WORLD | PLAYER | ENEMY
