extends CharacterBody2D
## The escaping prisoner. Two loadouts, each one lethal weapon plus one non-lethal physics tool:
##   CROSSBOW: bolt (ranged, lethal)  + kick (close, physics push)
##   BLADE:    slash (close, lethal)  + stun rock (ranged, physics hit)
## Bolts and rocks are limited; pick them up again where they land.
## The kick and the rock use charges that refill one at a time (upgradeable later).

const L = preload("res://scripts/Layers.gd")
const Fx = preload("res://scripts/Fx.gd")
const Bolt = preload("res://scripts/Bolt.gd")
const Rock = preload("res://scripts/Rock.gd")
const CharacterSprite = preload("res://scripts/CharacterSprite.gd")
const Assets = preload("res://scripts/Assets.gd")

## Gear presets for testing (G cycles them). In the full game gear is found and earned.
const GEAR_PRESETS := [
	{"name": "Prisoner", "gear": {"hands": 0}},
	{"name": "Scavenger", "gear": {"back": 1, "head": 1, "torso": 1, "hands": 1, "feet": 1}},
	{"name": "Turncoat", "gear": {"back": 2, "head": 2, "torso": 2, "hands": 2, "feet": 2}},
	{"name": "Relic-bearer", "gear": {"back": 3, "head": 3, "torso": 3, "hands": 3, "feet": 3}},
]

signal health_changed(current: int, maximum: int)
signal died

enum Loadout { CROSSBOW, BLADE }

@export var loadout: Loadout = Loadout.CROSSBOW
@export var max_health: int = 5
## Uses of the kick / stun rock before waiting on the cooldown. Upgrade target.
@export var secondary_max_charges: int = 1
@export var bolts: int = 6
@export var max_bolts: int = 10
@export var rocks: int = 3
@export var max_rocks: int = 6
## Testing only: allow swapping loadout mid-run with Q. Normally the loadout is
## locked in on the weapon select screen.
@export var allow_loadout_swap: bool = false
## Testing only: force the light level (0..1). Negative = use the real lighting.
@export var light_override: float = -1.0
## Testing only: crouch without holding the key.
@export var crouch_hold: bool = false
## Aim at the mouse. Tests turn this off and set `aim` directly.
@export var mouse_aim: bool = true

const RADIUS := 12.0
const TARGET_RADIUS := 14.0
const SPEED := 200.0
const CROUCH_SPEED := 95.0
const DODGE_SPEED := 560.0
const DODGE_TIME := 0.2
const DODGE_COOLDOWN := 1.0
const HIT_INVULN := 0.8
const SWING_FX_TIME := 0.15
const HURT_FRICTION := 1400.0
# Falling
const PIT_FALL_DAMAGE := 2
const WATER_FALL_DAMAGE := 1
const FALL_INVULN := 1.2
# Crossbow
const RELOAD_TIME := 0.85
const BOLT_DAMAGE := 2
# Kick
const SHOVE_RANGE := 70.0
const SHOVE_ARC := 100.0
const SHOVE_FORCE := 560.0          # About 105px of slide.
const SHOVE_STUN := 0.35
const SHOVE_COOLDOWN := 1.4         # Time to refill one charge.
# Blade
const SLASH_RANGE := 58.0
const SLASH_ARC := 120.0
const SLASH_DAMAGE := 1
const SLASH_KNOCK := 140.0
const SLASH_COOLDOWN := 0.3
# Stun rock
const ROCK_RANGE := 420.0
const ROCK_COOLDOWN := 2.5          # Time to refill one charge.

var health := 5
var is_dead := false
## Crouched: slow, but hidden from guards behind crates and barricades.
var crouching := false
## How lit the player's spot is (0 dark .. 1 bright). Guards see much further in light.
var light_level := 1.0
var aim := Vector2.RIGHT
var primary_cd := 0.0
var charges := 1
var charge_cd := 0.0
var dodge_time := 0.0
var dodge_cd := 0.0
var dodge_dir := Vector2.ZERO
var invuln := 0.0
var hurt_velocity := Vector2.ZERO
var knocked := false
var last_safe := Vector2.ZERO
var swing_time := 0.0
var swing_kind := ""
var swing_dir := Vector2.RIGHT
var shake := 0.0
var feet: Area2D
var sprite: Node2D
var overlay: Node2D
var gear_preset := 0
## Scent trail for hounds: recent positions, each with the game time it was left.
var scent: Array[Dictionary] = []
var scent_clock := 0.0
var _scent_timer := 0.0

const SCENT_INTERVAL := 0.2
# Footsteps: how far each step can be heard, by floor material (crouching is always silent).
const STEP_INTERVAL := 0.38
const STEP_NOISE := {"straw": 0.0, "stone": 40.0, "brick": 50.0, "water": 120.0, "iron": 160.0}
const STEP_RING_MIN := 100.0   # Only loud steps show a noise ring.
var floor_material := "stone"

# --- Gear effects -------------------------------------------------------------------
## What each piece does. step_mult scales footstep noise; clank is noise the gear itself makes
## (heard even on straw, and a little even when crouching); armor absorbs hits before health;
## notice_mult < 1 makes guards slower to notice you.
const GEAR_STATS := {
	"hands": {0: {"clank": 15.0}, 3: {"clank": 5.0}},                   # shackle chains rattle
	"feet": {1: {"step_mult": 0.7}, 3: {"step_mult": 1.4, "clank": 25.0, "armor": 1}},
	"torso": {1: {"armor": 1}, 2: {"armor": 2, "clank": 20.0}, 3: {"armor": 3, "clank": 25.0}},
	"head": {1: {"notice_mult": 0.9}, 2: {"armor": 1, "clank": 5.0}, 3: {"armor": 1, "clank": 5.0}},
	"back": {1: {"step_mult": 0.85}, 2: {"step_mult": 0.9}, 3: {"step_mult": 0.85, "notice_mult": 0.85}},
}
const GEAR_NAMES := {
	"hands": {0: "broken shackles", 1: "cloth wraps", 2: "leather gloves", 3: "bronze gauntlets"},
	"feet": {1: "rag foot-wraps", 2: "leather boots", 3: "iron greaves"},
	"torso": {1: "leather jerkin", 2: "Gaolwarden mail and tabard", 3: "bronze cuirass"},
	"head": {1: "hood", 2: "Gaolwarden helm", 3: "imperial bronze helm"},
	"back": {1: "tattered cloak", 2: "Gaolwarden cloak", 3: "Rift-teal mantle"},
}
const CROUCH_CLANK := 0.4          # Share of gear clank still heard while crouching.
const RECOGNIZE_DIST := 90.0       # Closer than this, a disguise doesn't fool anyone.
var armor := 0
var armor_max := 0
var step_mult := 1.0
var clank := 0.0
var notice_mult := 1.0
var _step_timer := 0.0
var _step_player: AudioStreamPlayer2D
var _step_sounds := {}
## Footstep loudness in dB per material (crouching is much quieter).
const STEP_VOLUME := {"straw": -14.0, "stone": -10.0, "brick": -11.0, "water": -6.0, "iron": -3.0}
const SCENT_LIFETIME := 9.0

@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	add_to_group("player")
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = L.PLAYER
	collision_mask = L.PLAYER_MASK
	health = max_health
	charges = secondary_max_charges
	last_safe = global_position
	_setup_step_sounds()
	sprite = CharacterSprite.new()
	sprite.gear = GEAR_PRESETS[0].gear.duplicate()
	add_child(sprite)
	_recalc_gear()
	armor = armor_max
	# Weapon, swing arcs and aim guides draw on top of the sprite.
	overlay = Node2D.new()
	add_child(overlay)
	overlay.draw.connect(_draw_overlay)
	feet = Area2D.new()
	feet.collision_layer = 0
	feet.collision_mask = L.HAZARD_ZONE
	feet.monitorable = false
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 3.0
	cs.shape = c
	feet.add_child(cs)
	add_child(feet)

# --- Info for the HUD ------------------------------------------------------------

func loadout_name() -> String:
	return "Crossbow + Kick" if loadout == Loadout.CROSSBOW else "Blade + Stun Rock"

func primary_name() -> String:
	return "Bolt  x%d" % bolts if loadout == Loadout.CROSSBOW else "Slash"

func secondary_name() -> String:
	return "Kick" if loadout == Loadout.CROSSBOW else "Rock  x%d" % rocks

func primary_ready() -> float:
	var full := RELOAD_TIME if loadout == Loadout.CROSSBOW else SLASH_COOLDOWN
	return 1.0 - clampf(primary_cd / full, 0.0, 1.0)

func _secondary_cooldown() -> float:
	return SHOVE_COOLDOWN if loadout == Loadout.CROSSBOW else ROCK_COOLDOWN

## Progress towards the next charge (1.0 when all charges are full).
func secondary_ready() -> float:
	if charges >= secondary_max_charges:
		return 1.0
	return 1.0 - clampf(charge_cd / _secondary_cooldown(), 0.0, 1.0)

func dodge_ready() -> float:
	return 1.0 - clampf(dodge_cd / (DODGE_COOLDOWN + DODGE_TIME), 0.0, 1.0)

# --- Main loop -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, 1500.0 * delta)
		move_and_slide()
		queue_redraw()
		return

	primary_cd = maxf(primary_cd - delta, 0.0)
	dodge_cd = maxf(dodge_cd - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	swing_time = maxf(swing_time - delta, 0.0)
	if charges < secondary_max_charges:
		charge_cd -= delta
		if charge_cd <= 0.0:
			charges += 1
			charge_cd = _secondary_cooldown() if charges < secondary_max_charges else 0.0

	if mouse_aim:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 2.0:
			aim = to_mouse.normalized()

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	crouching = (crouch_hold or Input.is_action_pressed("crouch")) and dodge_time <= 0.0 and not knocked
	if dodge_time > 0.0:
		dodge_time -= delta
		velocity = dodge_dir * DODGE_SPEED
	else:
		velocity = input * (CROUCH_SPEED if crouching else SPEED) + hurt_velocity
		hurt_velocity = hurt_velocity.move_toward(Vector2.ZERO, HURT_FRICTION * delta)
		if Input.is_action_just_pressed("dodge") and dodge_cd <= 0.0:
			dodge_dir = input if input != Vector2.ZERO else aim
			dodge_time = DODGE_TIME
			dodge_cd = DODGE_COOLDOWN + DODGE_TIME
		if Input.is_action_just_pressed("gear_preset"):
			cycle_gear()
		if allow_loadout_swap and Input.is_action_just_pressed("swap_loadout"):
			loadout = Loadout.BLADE if loadout == Loadout.CROSSBOW else Loadout.CROSSBOW
			primary_cd = 0.0
			charges = secondary_max_charges
			charge_cd = 0.0
		if loadout == Loadout.CROSSBOW:
			if Input.is_action_just_pressed("primary"):
				use_primary()
		elif Input.is_action_pressed("primary"):
			use_primary()
		if Input.is_action_just_pressed("secondary"):
			use_secondary()
	move_and_slide()
	_update_knocked()
	_update_sprite(delta)
	_leave_scent(delta)
	_footsteps(delta)
	light_level = light_override if light_override >= 0.0 else Fx.light_level(self, global_position)
	queue_redraw()

## While being thrown by a hit, the player can slide over a rim and fall in.
func _update_knocked() -> void:
	if knocked:
		for area in feet.get_overlapping_areas():
			var hazard = area.get_parent()
			if hazard != null and hazard.is_in_group("hazard"):
				_fall(hazard.kill_cause())
				return
		if hurt_velocity.length() < 20.0:
			knocked = false
			collision_mask = L.PLAYER_MASK
	elif dodge_time <= 0.0:
		last_safe = global_position

func _footsteps(delta: float) -> void:
	var floor_node := get_tree().get_first_node_in_group("floor")
	floor_material = floor_node.material_at(global_position) if floor_node != null else "stone"
	var moving := velocity.length() > 40.0 and not knocked
	if not moving:
		_step_timer = minf(_step_timer, STEP_INTERVAL * 0.5)
		return
	_step_timer -= delta
	if _step_timer > 0.0:
		return
	_step_timer = STEP_INTERVAL * (1.5 if crouching else 1.0)
	_play_step(floor_material)
	var radius: float = footstep_noise() * (1.5 if dodge_time > 0.0 else 1.0)
	if radius <= 0.0:
		return
	if radius >= STEP_RING_MIN:
		Fx.noise(self, global_position, radius)
	else:
		get_tree().call_group("enemy", "hear_noise", global_position, radius)

## Footstep sounds: every WAV named <material>_<n>.wav in assets/audio/steps, played with a
## little random pitch and volume so repeats don't sound mechanical.
func _setup_step_sounds() -> void:
	_step_player = AudioStreamPlayer2D.new()
	_step_player.max_distance = 900.0
	add_child(_step_player)
	for mat in STEP_NOISE.keys():
		var rnd := AudioStreamRandomizer.new()
		rnd.random_pitch = 1.12
		rnd.random_volume_offset_db = 2.0
		for i in 8:
			var path := "res://assets/audio/steps/%s_%d.wav" % [mat, i]
			var snd := Assets.sound(path) if Assets.exists(path) else null
			if snd != null:
				rnd.add_stream(-1, snd)
		if rnd.streams_count > 0:
			_step_sounds[mat] = rnd

func _play_step(mat: String) -> void:
	if not _step_sounds.has(mat):
		return
	_step_player.stream = _step_sounds[mat]
	_step_player.volume_db = STEP_VOLUME.get(mat, -10.0) - (12.0 if crouching else 0.0)
	_step_player.play()

## How far your footsteps carry right now: the floor, scaled by your footwear and cloak,
## plus whatever your gear rattles. Crouching silences your feet but not heavy armour.
func footstep_noise() -> float:
	if crouching:
		return clank * CROUCH_CLANK
	return STEP_NOISE.get(floor_material, 40.0) * step_mult + clank

func gear() -> Dictionary:
	return sprite.gear if sprite != null else {}

## Put on a piece of gear. Returns the tier it replaced (-1 if the slot was empty).
func equip(slot: String, tier: int) -> int:
	var old: int = gear().get(slot, -1)
	sprite.set_gear(slot, tier)
	var old_max := armor_max
	_recalc_gear()
	armor = clampi(armor + maxi(armor_max - old_max, 0), 0, armor_max)
	return old

func _recalc_gear() -> void:
	step_mult = 1.0; clank = 0.0; notice_mult = 1.0; armor_max = 0
	for slot in gear():
		var stats: Dictionary = GEAR_STATS.get(slot, {}).get(gear()[slot], {})
		step_mult *= stats.get("step_mult", 1.0)
		clank += stats.get("clank", 0.0)
		notice_mult *= stats.get("notice_mult", 1.0)
		armor_max += stats.get("armor", 0)
	armor = mini(armor, armor_max)

## 1.0 = full Gaolwarden disguise (helm and tabard), 0.5 = half of it, 0 = none.
func disguise_level() -> float:
	var g := gear()
	var level := 0.0
	if g.get("head", -1) == 2:
		level += 0.5
	if g.get("torso", -1) == 2:
		level += 0.5
	return level

## How much longer than normal a guard takes to notice you (1.0 = normal).
func notice_multiplier(dist: float, guard_is_wary: bool, fooled_by_looks: bool) -> float:
	var m := 1.0 / notice_mult
	var d := disguise_level()
	if d > 0.0 and fooled_by_looks and not guard_is_wary and not crouching and dist > RECOGNIZE_DIST:
		# A guard walking openly is just another guard. Sneaking about is not.
		m *= 1.0 + d * 2.3
		if gear().get("back", -1) == 2:
			m *= 1.25
	return m

func gear_summary() -> String:
	var parts := []
	if armor_max > 0:
		parts.append("armour %d/%d" % [armor, armor_max])
	if disguise_level() >= 1.0:
		parts.append("DISGUISED")
	elif disguise_level() > 0.0:
		parts.append("half-disguised")
	if clank > 0.0:
		parts.append("clank %d" % int(clank))
	return "  |  ".join(parts)

func _leave_scent(delta: float) -> void:
	scent_clock += delta
	_scent_timer -= delta
	if _scent_timer <= 0.0:
		_scent_timer = SCENT_INTERVAL
		if scent.is_empty() or scent.back().pos.distance_to(global_position) > 6.0:
			scent.append({"pos": global_position, "time": scent_clock})
	while not scent.is_empty() and scent_clock - scent[0].time > SCENT_LIFETIME:
		scent.pop_front()

func cycle_gear() -> void:
	gear_preset = (gear_preset + 1) % GEAR_PRESETS.size()
	sprite.set_all_gear(GEAR_PRESETS[gear_preset].gear)
	_recalc_gear()
	armor = armor_max
	Fx.popup(self, global_position + Vector2(0, -40), GEAR_PRESETS[gear_preset].name, Color(1.0, 0.85, 0.55))

func gear_name() -> String:
	return GEAR_PRESETS[gear_preset].name

func _update_sprite(delta: float) -> void:
	if sprite == null:
		return
	var moving := velocity.length() > 20.0
	var action := ""
	var phase := 0.0
	if swing_time > 0.0:
		action = "kick" if swing_kind == "shove" else "strike"
		phase = 1.0 - swing_time / SWING_FX_TIME
	sprite.animate(aim, moving, crouching, action, phase, delta)
	var a := 1.0
	if invuln > 0.0 and int(invuln * 20.0) % 2 == 0:
		a = 0.35
	sprite.set_tint(Color(1, 1, 1, a))
	overlay.queue_redraw()

func _process(delta: float) -> void:
	if camera != null:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	shake = move_toward(shake, 0.0, 30.0 * delta)

func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)

# --- Actions ---------------------------------------------------------------------

func use_primary() -> void:
	if primary_cd > 0.0 or is_dead:
		return
	if loadout == Loadout.CROSSBOW:
		_fire_bolt()
	else:
		_slash()

func use_secondary() -> void:
	if charges <= 0 or is_dead:
		return
	if loadout == Loadout.BLADE and rocks <= 0:
		Fx.popup(self, global_position + Vector2(0, -24), "No rocks", Color(0.8, 0.8, 0.8))
		return
	if charges >= secondary_max_charges:
		charge_cd = _secondary_cooldown()
	charges -= 1
	if loadout == Loadout.CROSSBOW:
		_shove()
	else:
		_throw_rock()

func collect(kind: String, amount: int) -> bool:
	if kind == "bolt":
		if bolts >= max_bolts:
			return false
		bolts = mini(bolts + amount, max_bolts)
	elif kind == "rock":
		if rocks >= max_rocks:
			return false
		rocks = mini(rocks + amount, max_rocks)
	else:
		return false
	Fx.popup(self, global_position + Vector2(0, -24), "+%d %s" % [amount, kind + ("s" if amount > 1 else "")], Color(1.0, 0.95, 0.7))
	return true

func _in_arc(e: Node2D, reach: float, arc_degrees: float) -> bool:
	var to := e.global_position - global_position
	var d := to.length()
	var r: float = e.radius if "radius" in e else TARGET_RADIUS
	if d > reach + r:
		return false
	if d < RADIUS + r + 6.0:
		return true
	return absf(aim.angle_to(to)) <= deg_to_rad(arc_degrees) * 0.5

func _swing(kind: String) -> void:
	swing_kind = kind
	swing_dir = aim
	swing_time = SWING_FX_TIME

func _fire_bolt() -> void:
	if bolts <= 0:
		primary_cd = 0.3
		Fx.popup(self, global_position + Vector2(0, -24), "No bolts", Color(0.8, 0.8, 0.8))
		return
	bolts -= 1
	primary_cd = RELOAD_TIME
	_swing("shoot")
	var b := Bolt.new()
	b.direction = aim
	b.damage = BOLT_DAMAGE
	b.position = global_position + aim * (RADIUS + 6.0)
	get_parent().add_child(b)
	add_shake(1.5)

func _shove() -> void:
	_swing("shove")
	var hit := false
	for e in get_tree().get_nodes_in_group("pushable"):
		if e.is_dying():
			continue
		if _in_arc(e, SHOVE_RANGE, SHOVE_ARC):
			# Push straight along the aim so it's easy to predict where things go.
			e.apply_knockback(aim * SHOVE_FORCE, SHOVE_STUN)
			hit = true
	if hit:
		add_shake(4.0)
		Fx.hitstop(self, 0.06, 0.05)

func _slash() -> void:
	primary_cd = SLASH_COOLDOWN
	_swing("slash")
	var hit := false
	for e in get_tree().get_nodes_in_group("pushable"):
		if e.is_dying():
			continue
		if _in_arc(e, SLASH_RANGE, SLASH_ARC):
			e.take_damage(SLASH_DAMAGE, "blade")
			e.apply_knockback(aim * SLASH_KNOCK, 0.0)
			hit = true
	if hit:
		add_shake(2.0)
		Fx.hitstop(self, 0.04, 0.05)

func _rock_target() -> Vector2:
	var to := (get_global_mouse_position() - global_position) if mouse_aim else aim * ROCK_RANGE
	return global_position + to.limit_length(ROCK_RANGE)

func _throw_rock() -> void:
	rocks -= 1
	_swing("throw")
	var r := Rock.new()
	r.setup(global_position + aim * (RADIUS + 4.0), _rock_target())
	get_parent().add_child(r)

func take_damage(amount: int, from_pos: Vector2, knock: float = 320.0) -> void:
	if is_dead or invuln > 0.0 or dodge_time > 0.0:
		return
	if armor > 0:
		var absorbed := mini(armor, amount)
		armor -= absorbed
		amount -= absorbed
		Fx.popup(self, global_position + Vector2(0, -36), "ARMOUR" if armor > 0 else "ARMOUR BROKEN", Color(0.75, 0.8, 0.9))
	health = maxi(health - amount, 0)
	invuln = HIT_INVULN
	hurt_velocity = (global_position - from_pos).normalized() * knock
	knocked = true
	collision_mask = L.PLAYER_KNOCK_MASK
	add_shake(6.0)
	Fx.hitstop(self, 0.08, 0.05)
	health_changed.emit(health, max_health)
	if health <= 0:
		_die()

func _fall(cause: String) -> void:
	knocked = false
	hurt_velocity = Vector2.ZERO
	collision_mask = L.PLAYER_MASK
	var dmg := PIT_FALL_DAMAGE if cause == "pit" else WATER_FALL_DAMAGE
	Fx.popup(self, global_position + Vector2(0, -24), "FELL!" if cause == "pit" else "SPLASH!", Color(1.0, 0.5, 0.4))
	if cause == "water":
		Fx.ring(self, global_position, 30.0, Color(0.6, 0.8, 1.0, 0.9))
	Fx.hitstop(self, 0.4, 0.3)
	health = maxi(health - dmg, 0)
	health_changed.emit(health, max_health)
	global_position = last_safe
	if camera != null:
		camera.reset_smoothing()
	invuln = FALL_INVULN
	if health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	if sprite != null:
		sprite.set_lying(true)
		sprite.set_tint(Color(0.55, 0.5, 0.5))
	died.emit()

# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	# Under the sprite: a contact shadow and the dodge trail.
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, RADIUS, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if sprite == null or not sprite.is_loaded():
		# Art missing: fall back to the old gray-box body so you're never invisible.
		draw_circle(Vector2.ZERO, RADIUS, Color(0.86, 0.8, 0.64) if not is_dead else Color(0.3, 0.28, 0.25))
		draw_circle(aim * 5.0, 4.0, Color(0.3, 0.25, 0.2))
	if is_dead:
		return
	if dodge_time > 0.0:
		draw_circle(-dodge_dir * 10.0 + Vector2(0, -10), RADIUS * 0.9, Color(0.86, 0.8, 0.64, 0.25))
		draw_circle(-dodge_dir * 20.0 + Vector2(0, -10), RADIUS * 0.75, Color(0.86, 0.8, 0.64, 0.12))

## On top of the sprite: swing arcs, the weapon and aim guides.
func _draw_overlay() -> void:
	if is_dead:
		return
	var o := overlay
	var hand := Vector2(0, -9)   # Weapons are held at chest height.
	var alpha := 1.0
	if swing_time > 0.0 and (swing_kind == "shove" or swing_kind == "slash"):
		var k := swing_time / SWING_FX_TIME
		var is_shove := swing_kind == "shove"
		var reach := SHOVE_RANGE if is_shove else SLASH_RANGE
		var arc := deg_to_rad(SHOVE_ARC if is_shove else SLASH_ARC)
		var c := Color(0.8, 0.9, 1.0, 0.5 * k) if is_shove else Color(1.0, 1.0, 1.0, 0.8 * k)
		var a := swing_dir.angle()
		for i in 3:
			o.draw_arc(Vector2.ZERO, reach * (0.55 + 0.2 * i), a - arc * 0.5, a + arc * 0.5, 18, c, 3.0 if is_shove else 2.0)
	if loadout == Loadout.CROSSBOW:
		var base := hand + aim * 4.0
		var tip := hand + aim * (RADIUS + 10.0)
		var side := aim.orthogonal() * 7.0
		o.draw_line(base, tip, Color(0.55, 0.4, 0.25, alpha), 3.0)
		o.draw_line(tip - aim * 5.0 + side, tip - aim * 5.0 - side, Color(0.6, 0.5, 0.4, alpha), 2.0)
		if primary_cd > 0.0:
			o.draw_arc(Vector2.ZERO, RADIUS + 5.0, -PI * 0.5, -PI * 0.5 + TAU * primary_ready(), 24, Color(1, 1, 1, 0.5), 2.0)
		elif bolts > 0:
			o.draw_line(hand + aim * (RADIUS + 12.0), hand + aim * 160.0, Color(1.0, 0.9, 0.6, 0.12), 1.0)
	else:
		o.draw_line(hand + aim * 6.0, hand + aim * (RADIUS + 12.0), Color(0.8, 0.82, 0.86, alpha), 3.0)
		if rocks > 0:
			var target_local := _rock_target() - global_position
			var rc := Color(0.85, 0.85, 0.85, 0.35 if charges > 0 else 0.12)
			o.draw_arc(target_local, 10.0, 0.0, TAU, 16, rc, 1.5)
			o.draw_dashed_line(aim * (RADIUS + 6.0), target_local, Color(1, 1, 1, 0.08), 1.0, 6.0)
