extends CharacterBody2D
## The escaping prisoner. Two test loadouts:
##   CROSSBOW: bolt (ranged, lethal)  + shove (close, non-lethal physics push)
##   BLADE:    slash (close, lethal)  + stun rock (ranged, non-lethal physics hit)

const L = preload("res://scripts/Layers.gd")
const Fx = preload("res://scripts/Fx.gd")
const Bolt = preload("res://scripts/Bolt.gd")
const Rock = preload("res://scripts/Rock.gd")

signal health_changed(current: int, maximum: int)
signal died

enum Loadout { CROSSBOW, BLADE }

@export var loadout: Loadout = Loadout.CROSSBOW
@export var max_health: int = 5
## Aim at the mouse. Tests turn this off and set `aim` directly.
@export var mouse_aim: bool = true

const RADIUS := 12.0
const ENEMY_RADIUS := 14.0
const SPEED := 200.0
const DODGE_SPEED := 560.0
const DODGE_TIME := 0.2
const DODGE_COOLDOWN := 0.55
const HIT_INVULN := 0.8
const SWING_FX_TIME := 0.15
# Crossbow
const RELOAD_TIME := 0.85
const BOLT_DAMAGE := 2
# Shove
const SHOVE_RANGE := 70.0
const SHOVE_ARC := 100.0
const SHOVE_FORCE := 780.0
const SHOVE_STUN := 0.35
const SHOVE_COOLDOWN := 0.65
# Blade
const SLASH_RANGE := 58.0
const SLASH_ARC := 120.0
const SLASH_DAMAGE := 1
const SLASH_KNOCK := 140.0
const SLASH_COOLDOWN := 0.3
# Stun rock
const ROCK_RANGE := 420.0
const ROCK_COOLDOWN := 1.0

var health := 5
var is_dead := false
var aim := Vector2.RIGHT
var primary_cd := 0.0
var secondary_cd := 0.0
var dodge_time := 0.0
var dodge_cd := 0.0
var dodge_dir := Vector2.ZERO
var invuln := 0.0
var hurt_velocity := Vector2.ZERO
var swing_time := 0.0
var swing_kind := ""
var swing_dir := Vector2.RIGHT
var shake := 0.0

@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	add_to_group("player")
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = L.PLAYER
	collision_mask = L.PLAYER_MASK
	health = max_health

# --- Info for the HUD ------------------------------------------------------------

func loadout_name() -> String:
	return "Crossbow + Shove" if loadout == Loadout.CROSSBOW else "Blade + Stun Rock"

func primary_name() -> String:
	return "Bolt" if loadout == Loadout.CROSSBOW else "Slash"

func secondary_name() -> String:
	return "Shove" if loadout == Loadout.CROSSBOW else "Rock"

func primary_ready() -> float:
	var full := RELOAD_TIME if loadout == Loadout.CROSSBOW else SLASH_COOLDOWN
	return 1.0 - clampf(primary_cd / full, 0.0, 1.0)

func secondary_ready() -> float:
	var full := SHOVE_COOLDOWN if loadout == Loadout.CROSSBOW else ROCK_COOLDOWN
	return 1.0 - clampf(secondary_cd / full, 0.0, 1.0)

# --- Main loop -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, 1500.0 * delta)
		move_and_slide()
		queue_redraw()
		return

	primary_cd = maxf(primary_cd - delta, 0.0)
	secondary_cd = maxf(secondary_cd - delta, 0.0)
	dodge_cd = maxf(dodge_cd - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	swing_time = maxf(swing_time - delta, 0.0)

	if mouse_aim:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 2.0:
			aim = to_mouse.normalized()

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dodge_time > 0.0:
		dodge_time -= delta
		velocity = dodge_dir * DODGE_SPEED
	else:
		velocity = input * SPEED + hurt_velocity
		hurt_velocity = hurt_velocity.move_toward(Vector2.ZERO, 1400.0 * delta)
		if Input.is_action_just_pressed("dodge") and dodge_cd <= 0.0:
			dodge_dir = input if input != Vector2.ZERO else aim
			dodge_time = DODGE_TIME
			dodge_cd = DODGE_COOLDOWN + DODGE_TIME
		if Input.is_action_just_pressed("swap_loadout"):
			loadout = Loadout.BLADE if loadout == Loadout.CROSSBOW else Loadout.CROSSBOW
			primary_cd = 0.0
			secondary_cd = 0.0
		if loadout == Loadout.CROSSBOW:
			if Input.is_action_just_pressed("primary"):
				use_primary()
		elif Input.is_action_pressed("primary"):
			use_primary()
		if Input.is_action_just_pressed("secondary"):
			use_secondary()
	move_and_slide()
	queue_redraw()

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
	if secondary_cd > 0.0 or is_dead:
		return
	if loadout == Loadout.CROSSBOW:
		_shove()
	else:
		_throw_rock()

func _in_arc(e: Node2D, reach: float, arc_degrees: float) -> bool:
	var to := e.global_position - global_position
	var d := to.length()
	if d > reach + ENEMY_RADIUS:
		return false
	if d < RADIUS + ENEMY_RADIUS + 6.0:
		return true
	return absf(aim.angle_to(to)) <= deg_to_rad(arc_degrees) * 0.5

func _swing(kind: String) -> void:
	swing_kind = kind
	swing_dir = aim
	swing_time = SWING_FX_TIME

func _fire_bolt() -> void:
	primary_cd = RELOAD_TIME
	var b := Bolt.new()
	b.direction = aim
	b.damage = BOLT_DAMAGE
	b.position = global_position + aim * (RADIUS + 6.0)
	get_parent().add_child(b)
	add_shake(1.5)

func _shove() -> void:
	secondary_cd = SHOVE_COOLDOWN
	_swing("shove")
	var hit := false
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.is_dying():
			continue
		if _in_arc(e, SHOVE_RANGE, SHOVE_ARC):
			# Push straight along the aim so it's easy to predict where they'll go.
			e.apply_knockback(aim * SHOVE_FORCE, SHOVE_STUN)
			hit = true
	if hit:
		add_shake(4.0)

func _slash() -> void:
	primary_cd = SLASH_COOLDOWN
	_swing("slash")
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.is_dying():
			continue
		if _in_arc(e, SLASH_RANGE, SLASH_ARC):
			e.take_damage(SLASH_DAMAGE, "blade")
			e.apply_knockback(aim * SLASH_KNOCK, 0.0)
			add_shake(2.0)

func _rock_target() -> Vector2:
	var to := (get_global_mouse_position() - global_position) if mouse_aim else aim * ROCK_RANGE
	return global_position + to.limit_length(ROCK_RANGE)

func _throw_rock() -> void:
	secondary_cd = ROCK_COOLDOWN
	var r := Rock.new()
	r.setup(global_position + aim * (RADIUS + 4.0), _rock_target())
	get_parent().add_child(r)

func take_damage(amount: int, from_pos: Vector2) -> void:
	if is_dead or invuln > 0.0 or dodge_time > 0.0:
		return
	health = maxi(health - amount, 0)
	invuln = HIT_INVULN
	hurt_velocity = (global_position - from_pos).normalized() * 320.0
	add_shake(6.0)
	health_changed.emit(health, max_health)
	if health <= 0:
		is_dead = true
		died.emit()

# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	if is_dead:
		draw_circle(Vector2.ZERO, RADIUS, Color(0.3, 0.28, 0.25))
		draw_line(Vector2(-6, -6), Vector2(6, 6), Color(0.1, 0.1, 0.1), 2.0)
		draw_line(Vector2(-6, 6), Vector2(6, -6), Color(0.1, 0.1, 0.1), 2.0)
		return
	var alpha := 1.0
	if invuln > 0.0 and int(invuln * 20.0) % 2 == 0:
		alpha = 0.35
	if dodge_time > 0.0:
		draw_circle(-dodge_dir * 10.0, RADIUS * 0.9, Color(0.86, 0.8, 0.64, 0.3))
		draw_circle(-dodge_dir * 20.0, RADIUS * 0.75, Color(0.86, 0.8, 0.64, 0.15))

	if swing_time > 0.0:
		var k := swing_time / SWING_FX_TIME
		var is_shove := swing_kind == "shove"
		var reach := SHOVE_RANGE if is_shove else SLASH_RANGE
		var arc := deg_to_rad(SHOVE_ARC if is_shove else SLASH_ARC)
		var c := Color(0.8, 0.9, 1.0, 0.5 * k) if is_shove else Color(1.0, 1.0, 1.0, 0.8 * k)
		var a := swing_dir.angle()
		for i in 3:
			draw_arc(Vector2.ZERO, reach * (0.55 + 0.2 * i), a - arc * 0.5, a + arc * 0.5, 18, c, 3.0 if is_shove else 2.0)

	draw_circle(Vector2.ZERO, RADIUS, Color(0.86, 0.8, 0.64, alpha))
	draw_circle(aim * 5.0, 4.0, Color(0.3, 0.25, 0.2, alpha))

	if loadout == Loadout.CROSSBOW:
		var tip := aim * (RADIUS + 14.0)
		var side := aim.orthogonal() * 9.0
		draw_line(aim * RADIUS * 0.5, tip, Color(0.55, 0.4, 0.25, alpha), 3.0)
		draw_line(tip - aim * 6.0 + side, tip - aim * 6.0 - side, Color(0.6, 0.5, 0.4, alpha), 2.0)
		if primary_cd > 0.0:
			draw_arc(Vector2.ZERO, RADIUS + 5.0, -PI * 0.5, -PI * 0.5 + TAU * primary_ready(), 24, Color(1, 1, 1, 0.5), 2.0)
		else:
			draw_line(aim * (RADIUS + 16.0), aim * 160.0, Color(1.0, 0.9, 0.6, 0.12), 1.0)
	else:
		draw_line(aim * RADIUS, aim * (RADIUS + 16.0), Color(0.8, 0.82, 0.86, alpha), 3.0)
		var target_local := _rock_target() - global_position
		var rc := Color(0.85, 0.85, 0.85, 0.35 if secondary_cd <= 0.0 else 0.12)
		draw_arc(target_local, 10.0, 0.0, TAU, 16, rc, 1.5)
		draw_dashed_line(aim * (RADIUS + 6.0), target_local, Color(1, 1, 1, 0.08), 1.0, 6.0)
