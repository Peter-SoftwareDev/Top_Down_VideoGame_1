extends CharacterBody2D
## Basic fortress guard for the M0 combat sandbox.
##
## Patrols, spots the player with a vision cone, telegraphs a lunge attack,
## investigates noises, and can be knocked back into pits and deep water.
## Knocked guards that hit other guards pass the push along (chain reactions).

const L = preload("res://scripts/Layers.gd")
const Fx = preload("res://scripts/Fx.gd")

signal died(enemy: Node, cause: String)

enum State { PATROL, INVESTIGATE, ALERT, WINDUP, LUNGE, RECOVER, KNOCKED, STUNNED, DYING }

@export var max_health: int = 3
@export var walk_speed: float = 70.0
@export var chase_speed: float = 125.0
## Global positions to walk between, in order. Leave empty for a guard that stands still.
@export var patrol_points: PackedVector2Array = PackedVector2Array()
## Direction a standing guard faces, in degrees. 0 = right, 90 = down, 180 = left.
@export var facing_degrees: float = 0.0
@export var vision_range: float = 250.0
@export var vision_angle_degrees: float = 100.0

const RADIUS := 14.0
const CLOSE_SENSE := 55.0          # Notices the player this close even from behind.
const ATTACK_RANGE := 46.0
const WINDUP_TIME := 0.45          # The telegraph. Long enough to dodge or shove.
const LUNGE_TIME := 0.16
const LUNGE_SPEED := 430.0
const RECOVER_TIME := 0.55         # Opening after an attack.
const KNOCK_FRICTION := 1500.0
const KNOCK_END_SPEED := 45.0
const WALL_SLAM_SPEED := 330.0     # Hitting a wall faster than this stuns.
const WALL_SLAM_STUN := 1.2
const CHAIN_TRANSFER := 0.8        # Share of push passed to a guard you crash into.
const LOSE_TRACK_TIME := 2.5
const PATROL_PAUSE := 0.8
const INVESTIGATE_LOOK_TIME := 1.8
const CONE_RAYS := 14

var health := 3
var state: State = State.PATROL
var state_time := 0.0
var facing := Vector2.RIGHT
var knock_velocity := Vector2.ZERO
var pending_stun := 0.0
var stun_duration := 0.0
var knock_hits: Array = []
var patrol_index := 0
var wait_time := 0.0
var look_time := 0.0
var home := Vector2.ZERO
var target_point := Vector2.ZERO
var unseen_time := 0.0
var lunge_dir := Vector2.ZERO
var lunge_landed := false
var hit_flash := 0.0
var cone_points := PackedVector2Array()
var player: Node2D
var feet: Area2D

func _ready() -> void:
	add_to_group("enemy")
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = L.ENEMY
	collision_mask = L.ENEMY_WALK_MASK
	health = max_health
	home = global_position
	facing = Vector2.RIGHT.rotated(deg_to_rad(facing_degrees))
	# A tiny sensor at the guard's centre. When it overlaps a hazard's inner zone, the guard falls in.
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

# --- Public API used by weapons and noise -------------------------------------

func is_dying() -> bool:
	return state == State.DYING

func is_unaware() -> bool:
	return state == State.PATROL or state == State.INVESTIGATE

## Lethal damage from a weapon. Hits on unaware guards kill outright;
## hits on stunned guards do double damage.
func take_damage(amount: int, cause: String) -> void:
	if state == State.DYING:
		return
	if is_unaware():
		_die("sneak")
		return
	if state == State.STUNNED:
		amount *= 2
	health -= amount
	hit_flash = 0.12
	if health <= 0:
		_die(cause)

## A physics push. `stun` seconds of stun begin when the guard stops sliding.
func apply_knockback(impulse: Vector2, stun: float) -> void:
	if state == State.DYING:
		return
	if state != State.KNOCKED:
		knock_hits.clear()
	if impulse.length() > knock_velocity.length():
		knock_velocity = impulse
	else:
		knock_velocity += impulse * 0.5
	pending_stun = maxf(pending_stun, stun)
	set_deferred("collision_mask", L.ENEMY_KNOCK_MASK)
	_set_state(State.KNOCKED)

func hear_noise(pos: Vector2, radius: float) -> void:
	if not is_unaware():
		return
	if global_position.distance_to(pos) > radius:
		return
	if state == State.PATROL:
		Fx.popup(self, global_position + Vector2(0, -30), "?", Color(1.0, 0.85, 0.3))
	target_point = pos
	look_time = INVESTIGATE_LOOK_TIME
	_set_state(State.INVESTIGATE)

# --- Main loop -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == State.DYING:
		return
	state_time += delta
	hit_flash = maxf(hit_flash - delta, 0.0)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	if state == State.KNOCKED:
		_do_knocked(delta)
	else:
		match state:
			State.PATROL:
				_do_patrol(delta)
			State.INVESTIGATE:
				_do_investigate(delta)
			State.ALERT:
				_do_chase(delta)
			State.WINDUP:
				velocity = Vector2.ZERO
				if _player_alive():
					_face_dir((player.global_position - global_position).normalized(), delta, 10.0)
				if state_time >= WINDUP_TIME:
					lunge_dir = facing
					lunge_landed = false
					_set_state(State.LUNGE)
			State.LUNGE:
				velocity = lunge_dir * LUNGE_SPEED
				_try_land_lunge()
				if state_time >= LUNGE_TIME:
					_set_state(State.RECOVER)
			State.RECOVER:
				velocity = velocity.move_toward(Vector2.ZERO, 2500.0 * delta)
				if state_time >= RECOVER_TIME:
					_set_state(State.ALERT)
			State.STUNNED:
				velocity = Vector2.ZERO
				if state_time >= stun_duration:
					_wake_alert()
		move_and_slide()
		_check_hazards()
	_update_cone()
	queue_redraw()

func _set_state(s: State) -> void:
	state = s
	state_time = 0.0

func _player_alive() -> bool:
	return player != null and is_instance_valid(player) and not player.is_dead

func _wake_alert() -> void:
	_set_state(State.ALERT)
	unseen_time = 0.0
	if _player_alive():
		target_point = player.global_position

func _become_alert() -> void:
	Fx.popup(self, global_position + Vector2(0, -30), "!", Color(1.0, 0.35, 0.3))
	_wake_alert()

# --- Senses ----------------------------------------------------------------------

func _can_see_player(alerted: bool) -> bool:
	if not _player_alive():
		return false
	var to := player.global_position - global_position
	var dist := to.length()
	var reach := vision_range * (1.4 if alerted else 1.0)
	if dist > reach:
		return false
	if not alerted and dist > CLOSE_SENSE:
		if absf(facing.angle_to(to)) > deg_to_rad(vision_angle_degrees) * 0.5:
			return false
	return _line_clear(player.global_position)

func _line_clear(to_pos: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position, to_pos, L.WORLD)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()

# --- Behaviours ------------------------------------------------------------------

func _move_toward(target: Vector2, speed: float, delta: float) -> void:
	var to := target - global_position
	if to.length() < 4.0:
		velocity = Vector2.ZERO
		return
	var dir := to.normalized()
	velocity = dir * speed
	_face_dir(dir, delta, 6.0)

func _face_dir(dir: Vector2, delta: float, rate: float) -> void:
	if dir == Vector2.ZERO:
		return
	facing = facing.slerp(dir, minf(1.0, rate * delta)).normalized()

func _do_patrol(delta: float) -> void:
	if _can_see_player(false):
		_become_alert()
		return
	if patrol_points.is_empty():
		_move_toward(home, walk_speed, delta)
		if global_position.distance_to(home) < 6.0:
			_face_dir(Vector2.RIGHT.rotated(deg_to_rad(facing_degrees)), delta, 4.0)
		return
	if wait_time > 0.0:
		wait_time -= delta
		velocity = Vector2.ZERO
		return
	var target := patrol_points[patrol_index]
	if global_position.distance_to(target) < 6.0:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		wait_time = PATROL_PAUSE
		velocity = Vector2.ZERO
	else:
		_move_toward(target, walk_speed, delta)

func _do_investigate(delta: float) -> void:
	if _can_see_player(false):
		_become_alert()
		return
	# Walk to the noise (give up after a few seconds if blocked), then look around.
	if global_position.distance_to(target_point) > 12.0 and state_time < 6.0:
		_move_toward(target_point, walk_speed * 1.4, delta)
	else:
		velocity = Vector2.ZERO
		facing = facing.rotated(2.0 * delta)
		look_time -= delta
		if look_time <= 0.0:
			wait_time = 0.0
			_set_state(State.PATROL)

func _do_chase(delta: float) -> void:
	if not _player_alive():
		_set_state(State.PATROL)
		return
	if _can_see_player(true):
		target_point = player.global_position
		unseen_time = 0.0
		if global_position.distance_to(target_point) <= ATTACK_RANGE:
			velocity = Vector2.ZERO
			_set_state(State.WINDUP)
			return
	else:
		unseen_time += delta
		if unseen_time >= LOSE_TRACK_TIME:
			look_time = INVESTIGATE_LOOK_TIME
			_set_state(State.INVESTIGATE)
			return
	_move_toward(target_point, chase_speed, delta)

func _try_land_lunge() -> void:
	if lunge_landed or not _player_alive():
		return
	if global_position.distance_to(player.global_position) < RADIUS + 12.0 + 8.0:
		lunge_landed = true
		player.take_damage(1, global_position)

func _do_knocked(delta: float) -> void:
	var speed_before := knock_velocity.length()
	velocity = knock_velocity
	move_and_slide()
	var slammed := false
	var chained := false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other = col.get_collider()
		if other is Node and other.is_in_group("enemy"):
			if other != self and not knock_hits.has(other) and not other.is_dying():
				knock_hits.append(other)
				other.apply_knockback(knock_velocity * CHAIN_TRANSFER, 0.4)
				other.knock_hits.append(self)
				knock_velocity *= 0.3
				chained = true
				Fx.popup(other, other.global_position + Vector2(0, -28), "CHAIN", Color(1.0, 0.6, 0.25))
		elif other is StaticBody2D and speed_before >= WALL_SLAM_SPEED and not slammed:
			slammed = true
			pending_stun = maxf(pending_stun, WALL_SLAM_STUN)
			knock_velocity = knock_velocity.bounce(col.get_normal()) * 0.25
			Fx.popup(self, global_position + Vector2(0, -28), "SLAM", Color(0.9, 0.9, 0.9))
			Fx.shake(self, 5.0)
	if not slammed and not chained:
		knock_velocity = velocity
	knock_velocity = knock_velocity.move_toward(Vector2.ZERO, KNOCK_FRICTION * delta)
	_check_hazards()
	if state == State.KNOCKED and knock_velocity.length() < KNOCK_END_SPEED:
		knock_velocity = Vector2.ZERO
		set_deferred("collision_mask", L.ENEMY_WALK_MASK)
		if pending_stun > 0.0:
			stun_duration = pending_stun
			pending_stun = 0.0
			_set_state(State.STUNNED)
		else:
			_wake_alert()

func _check_hazards() -> void:
	if state == State.DYING:
		return
	for area in feet.get_overlapping_areas():
		var hazard = area.get_parent()
		if hazard != null and hazard.is_in_group("hazard"):
			_die(hazard.kill_cause())
			return

func _die(cause: String) -> void:
	state = State.DYING
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	feet.set_deferred("monitoring", false)
	velocity = Vector2.ZERO
	cone_points.clear()
	queue_redraw()
	died.emit(self, cause)
	var above := global_position + Vector2(0, -26)
	var tw := create_tween().set_parallel(true)
	match cause:
		"pit":
			Fx.popup(self, above, "FELL!", Color(0.95, 0.8, 0.5))
			var drift := global_position + knock_velocity.normalized() * 18.0
			tw.tween_property(self, "scale", Vector2(0.1, 0.1), 0.6).set_ease(Tween.EASE_IN)
			tw.tween_property(self, "rotation", 5.0, 0.6)
			tw.tween_property(self, "modulate", Color(0.2, 0.2, 0.2, 0.0), 0.6)
			tw.tween_property(self, "global_position", drift, 0.6)
		"water":
			Fx.popup(self, above, "DROWNED", Color(0.55, 0.75, 1.0))
			Fx.ring(self, global_position, 36.0, Color(0.6, 0.8, 1.0, 0.9))
			tw.tween_property(self, "scale", Vector2(0.6, 0.6), 0.9)
			tw.tween_property(self, "modulate", Color(0.3, 0.5, 1.0, 0.0), 0.9)
		_:
			if cause == "sneak":
				Fx.popup(self, above, "SNEAK KILL", Color(0.75, 1.0, 0.6))
			tw.tween_property(self, "scale", Vector2(1.3, 1.3), 0.35)
			tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.35)
	tw.chain().tween_callback(queue_free)

# --- Drawing ---------------------------------------------------------------------

func _update_cone() -> void:
	cone_points.clear()
	if state == State.KNOCKED or state == State.STUNNED or state == State.DYING:
		return
	var space := get_world_2d().direct_space_state
	var half := deg_to_rad(vision_angle_degrees) * 0.5
	for i in CONE_RAYS + 1:
		var ang := -half + (2.0 * half) * float(i) / CONE_RAYS
		var end := global_position + facing.rotated(ang) * vision_range
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, end, L.WORLD))
		if not hit.is_empty():
			end = hit.position
		cone_points.append(end - global_position)

func _draw() -> void:
	# Vision cone, drawn as a triangle fan.
	if cone_points.size() >= 2:
		var cc := Color(1, 1, 1, 0.07)
		if state == State.INVESTIGATE:
			cc = Color(1.0, 0.85, 0.3, 0.12)
		elif state != State.PATROL:
			cc = Color(1.0, 0.3, 0.25, 0.12)
		var cols := PackedColorArray([cc, cc, cc])
		for i in cone_points.size() - 1:
			draw_primitive(PackedVector2Array([Vector2.ZERO, cone_points[i], cone_points[i + 1]]), cols, PackedVector2Array())

	var body := Color(0.72, 0.24, 0.2)
	var windup_k := clampf(state_time / WINDUP_TIME, 0.0, 1.0)
	if state == State.STUNNED:
		body = Color(0.45, 0.45, 0.75)
	elif state == State.WINDUP:
		body = body.lerp(Color(1.0, 0.65, 0.2), windup_k)
	if hit_flash > 0.0:
		body = Color.WHITE
	draw_circle(Vector2.ZERO, RADIUS + 2.0, Color(0, 0, 0, 0.35))
	draw_circle(Vector2.ZERO, RADIUS, body)
	draw_circle(facing * (RADIUS - 4.0), 4.0, Color(0.25, 0.05, 0.05))

	if state == State.WINDUP:
		draw_arc(Vector2.ZERO, RADIUS + 4.0 + 16.0 * (1.0 - windup_k), 0.0, TAU, 24, Color(1.0, 0.6, 0.2, 0.9), 2.0)
	if state == State.STUNNED:
		for k in 3:
			var a := state_time * 4.0 + k * TAU / 3.0
			draw_circle(Vector2(cos(a) * 12.0, -RADIUS - 8.0 + sin(a) * 4.0), 2.5, Color(1.0, 1.0, 0.6))

	if state != State.DYING and health < max_health:
		for i in max_health:
			var pc := Color(0.9, 0.3, 0.25) if i < health else Color(0.2, 0.2, 0.2)
			draw_rect(Rect2(-12.0 + i * 9.0, RADIUS + 5.0, 7.0, 3.0), pc)

	var font := ThemeDB.fallback_font
	if state == State.ALERT or state == State.WINDUP or state == State.LUNGE or state == State.RECOVER:
		draw_string(font, Vector2(-3, -RADIUS - 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.35, 0.3))
	elif state == State.INVESTIGATE:
		draw_string(font, Vector2(-4, -RADIUS - 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.85, 0.3))
