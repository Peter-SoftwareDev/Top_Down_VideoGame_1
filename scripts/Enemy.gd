extends CharacterBody2D
## Basic fortress guard.
##
## Senses: a vision cone. Seeing the player fills a suspicion meter (faster up close);
## when it's full the guard stops to shout, which brings nearby guards running.
## Kill or knock a guard mid-shout and the alarm never goes off.
## After an alert, a guard stays wary for the rest of the room: it sees further,
## notices faster, sweeps its surroundings and adds your last known spot to its patrol.
## Combat: a telegraphed lunge, sometimes delayed as a feint.
## Physics: knockback slides it over pit rims and into water; it passes pushes on to
## guards and crates it hits, and a hard wall slam stuns it.

const L = preload("res://scripts/Layers.gd")
const Fx = preload("res://scripts/Fx.gd")
const CharacterSprite = preload("res://scripts/CharacterSprite.gd")
const Body = preload("res://scripts/Body.gd")
const GUARD_GEAR := {"back": 2, "head": 2, "torso": 2, "hands": 2, "feet": 3}

signal died(enemy: Node, cause: String)

## CHARGE is only used by enemy types that charge (see Gaoler.gd).
enum State { PATROL, INVESTIGATE, SHOUT, ALERT, WINDUP, LUNGE, RECOVER, KNOCKED, STUNNED, DYING, CHARGE }

@export var max_health: int = 3
@export var walk_speed: float = 70.0
@export var chase_speed: float = 125.0
## Global positions to walk between, in order. Leave empty for a guard that stands still.
@export var patrol_points: PackedVector2Array = PackedVector2Array()
## Direction a standing guard faces, in degrees. 0 = right, 90 = down, 180 = left.
@export var facing_degrees: float = 0.0
@export var vision_range: float = 380.0
@export var vision_angle_degrees: float = 100.0

const RADIUS := 14.0
const CLOSE_SENSE := 55.0          # Notices the player this close even from behind.
# Suspicion
const NOTICE_TIME_NEAR := 0.3      # Seconds of sight to raise the alarm, up close...
const NOTICE_TIME_FAR := 1.3       # ...and at the edge of vision.
const SUSPICION_DECAY := 0.4       # Per second while the player is out of sight.
const SUSPICION_INVESTIGATE := 0.25
const CROUCH_NOTICE_MULT := 1.5
# Light: in pitch darkness an unaware guard sees only this share of its normal range.
const DARK_SIGHT_MULT := 0.35
const DARK_SIGHT_MULT_ALERTED := 0.6
const RELIGHT_REACH := 70.0
# Bodies
const BODY_LOOK_INTERVAL := 0.2
const BODY_ALARM_RADIUS := 420.0
const BODY_WEIGHT := 1.0   # A crouching player in the open takes longer to notice.
# Alarm
const SHOUT_TIME := 0.5            # Window to silence a guard before the alarm goes off.
const ALARM_RADIUS := 330.0
# Wariness after an alert
const WARY_RANGE_MULT := 1.15
const WARY_NOTICE_MULT := 0.65
const WARY_SPEED_MULT := 1.2
const WARY_PAUSE := 1.6
# Attack
const ATTACK_RANGE := 46.0
const WINDUP_TIME := 0.45          # The telegraph. Long enough to dodge or shove.
const FEINT_CHANCE := 0.3          # Chance of holding the wind-up longer.
const FEINT_EXTRA_MIN := 0.25
const FEINT_EXTRA_MAX := 0.45
const LUNGE_TIME := 0.16
const LUNGE_SPEED := 430.0
const LUNGE_KNOCK := 380.0         # How hard a landed lunge throws the player.
const RECOVER_TIME := 0.55         # Opening after an attack.
# Knockback
const KNOCK_FRICTION := 1500.0
const KNOCK_END_SPEED := 45.0
const WALL_SLAM_SPEED := 330.0     # Hitting a wall faster than this stuns.
const WALL_SLAM_STUN := 1.2
const CHAIN_TRANSFER := 0.8        # Share of push passed to whatever it crashes into.
const STUNNED_KNOCK_BONUS := 1.6   # Stunned guards fly further.
const CRUMBLE_MIN_SPEED := 300.0   # Only a real shove (not a weapon tap) breaks a rim.
# Movement
const LOSE_TRACK_TIME := 2.5
const PATROL_PAUSE := 0.8
const INVESTIGATE_LOOK_TIME := 1.8
const STUCK_TIME := 0.6
const DETOUR_TIME := 0.8
const CONE_RAYS := 14

# Per-type tunables. Enemy types (Gaoler.gd, Hound.gd) change these before calling super._ready().
var radius := RADIUS
var close_sense := CLOSE_SENSE
var close_sense_through_walls := false   # Hounds smell you behind cover.
## Can a disguise fool this enemy? (Hounds go by smell.)
var fooled_by_looks := true
var body_alarm_pending := false
var _body_look_t := 0.0
var attack_range := ATTACK_RANGE
var windup_time := WINDUP_TIME
var feint_chance := FEINT_CHANCE
var lunge_time := LUNGE_TIME
var lunge_speed := LUNGE_SPEED
var lunge_knock := LUNGE_KNOCK
var lunge_damage := 1
var recover_time := RECOVER_TIME
var shout_time := SHOUT_TIME
var shout_text := "HEY!"
var alarm_radius := ALARM_RADIUS
## Multiplies every push this enemy receives. Light enemies > 1, heavy < 1.
var knock_scale := 1.0

var health := 3
var state: State = State.PATROL
var state_time := 0.0
var facing := Vector2.RIGHT
var suspicion := 0.0
var seeing := false
var last_glimpse := Vector2.ZERO
var has_shouted := false
var wary := false
var wary_waypoint_added := false
var knock_velocity := Vector2.ZERO
var knock_peak := 0.0
var pending_stun := 0.0
var stun_duration := 0.0
var knock_hits: Array = []
var embedded_bolts := 0
var patrol_index := 0
var wait_time := 0.0
var look_time := 0.0
var home := Vector2.ZERO
var target_point := Vector2.ZERO
var unseen_time := 0.0
var windup_duration := WINDUP_TIME
var lunge_dir := Vector2.ZERO
var lunge_landed := false
var stuck_time := 0.0
var detour_time := 0.0
var detour_dir := Vector2.ZERO
var hit_flash := 0.0
var cone_points := PackedVector2Array()
var player: Node2D
var feet: Area2D
var sprite: Node2D
var overlay: Node2D

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("pushable")
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = L.ENEMY
	collision_mask = L.ENEMY_WALK_MASK
	health = max_health
	home = global_position
	var body_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_shape != null and body_shape.shape is CircleShape2D:
		body_shape.shape = body_shape.shape.duplicate()
		body_shape.shape.radius = radius
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
	sprite = _make_sprite()
	if sprite != null:
		add_child(sprite)
	overlay = Node2D.new()
	add_child(overlay)
	overlay.draw.connect(_draw_overlay)

## Leave a body behind, with the same look as this guard.
func _spawn_body() -> void:
	var b := Body.new()
	if sprite != null:
		b.look = {"body": sprite.body, "gear": sprite.gear.duplicate(), "sheet_path": sprite.sheet_path,
			"frame_size": sprite.frame_size, "lift": sprite.lift}
	b.weight = _body_weight()
	b.radius = radius
	b.position = global_position
	get_parent().add_child(b)

func _body_weight() -> float:
	return BODY_WEIGHT

## The character's look. Enemy types override this.
func _make_sprite() -> Node2D:
	var s := CharacterSprite.new()
	s.body = "guard"
	s.gear = GUARD_GEAR.duplicate()
	return s

func _update_sprite(delta: float) -> void:
	if sprite == null:
		return
	var action := ""
	var phase := 0.0
	match state:
		State.WINDUP:
			action = "strike"; phase = 0.0                          # hold the wind-up pose
		State.LUNGE:
			action = "strike"; phase = 0.4 + 0.6 * clampf(state_time / lunge_time, 0.0, 1.0)
		State.RECOVER:
			action = "strike"; phase = 1.0
	sprite.animate(facing, velocity.length() > 10.0, state == State.STUNNED, action, phase, delta)
	var tint := Color.WHITE
	if state == State.WINDUP:
		tint = Color.WHITE.lerp(Color(1.0, 0.55, 0.25), clampf(state_time / windup_duration, 0.0, 1.0))
	elif state == State.STUNNED:
		tint = Color(0.65, 0.7, 1.0)
	if hit_flash > 0.0:
		tint = Color(2.0, 2.0, 2.0)
	sprite.set_tint(tint)

# --- Public API used by weapons, props and noise ---------------------------------

func is_dying() -> bool:
	return state == State.DYING

func is_unaware() -> bool:
	return state == State.PATROL or state == State.INVESTIGATE

## Lethal damage. Weapon hits on unaware guards kill outright (`allow_sneak`);
## hits on stunned guards do double damage.
func take_damage(amount: int, cause: String, allow_sneak: bool = true) -> void:
	if state == State.DYING:
		return
	if allow_sneak and is_unaware():
		_die("sneak")
		return
	if state == State.STUNNED:
		amount *= 2
	health -= amount
	hit_flash = 0.12
	if health <= 0:
		_die(cause)

## A physics push. `stun` seconds of stun begin when the guard stops sliding.
## `impact` is true when the push comes from a body crashing into this one
## (a chain hit or a crate), rather than from a kick, rock or weapon.
func apply_knockback(impulse: Vector2, stun: float, impact: bool = false) -> void:
	if state == State.DYING:
		return
	_apply_push(impulse * knock_scale, stun)

func _apply_push(impulse: Vector2, stun: float) -> void:
	if state == State.STUNNED:
		impulse *= STUNNED_KNOCK_BONUS
	if state != State.KNOCKED:
		knock_hits.clear()
		knock_peak = 0.0
	if impulse.length() > knock_velocity.length():
		knock_velocity = impulse
	else:
		knock_velocity += impulse * 0.5
	knock_peak = maxf(knock_peak, knock_velocity.length())
	pending_stun = maxf(pending_stun, stun)
	wary = true
	set_deferred("collision_mask", L.ENEMY_KNOCK_MASK)
	_set_state(State.KNOCKED)

func hear_noise(pos: Vector2, radius: float) -> void:
	if not is_unaware():
		return
	if global_position.distance_to(pos) > radius:
		return
	if state == State.PATROL:
		Fx.popup(self, global_position + Vector2(0, -30), "?", Color(1.0, 0.85, 0.3))
	_investigate(pos)

func hear_alarm(source: Node, pos: Vector2, radius: float, target: Vector2) -> void:
	if source == self or not is_unaware():
		return
	if global_position.distance_to(pos) > radius:
		return
	Fx.popup(self, global_position + Vector2(0, -30), "!", Color(1.0, 0.35, 0.3))
	has_shouted = true   # Responders don't raise a second alarm.
	wary = true
	_set_state(State.ALERT)
	suspicion = 1.0
	unseen_time = 0.0
	target_point = target

# --- Main loop -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == State.DYING:
		return
	state_time += delta
	hit_flash = maxf(hit_flash - delta, 0.0)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	if state == State.KNOCKED:
		_do_knocked(delta)
	elif state == State.CHARGE:
		_do_special(delta)
	else:
		match state:
			State.PATROL:
				_do_patrol(delta)
			State.INVESTIGATE:
				_do_investigate(delta)
			State.SHOUT:
				_do_shout(delta)
			State.ALERT:
				_do_chase(delta)
			State.WINDUP:
				velocity = Vector2.ZERO
				if _player_alive():
					_face_dir((player.global_position - global_position).normalized(), delta, 10.0)
				if state_time >= windup_duration:
					_start_attack()
			State.LUNGE:
				velocity = lunge_dir * lunge_speed
				_try_land_lunge()
				if state_time >= lunge_time:
					_set_state(State.RECOVER)
			State.RECOVER:
				velocity = velocity.move_toward(Vector2.ZERO, 2500.0 * delta)
				if state_time >= recover_time:
					_set_state(State.ALERT)
			State.STUNNED:
				velocity = Vector2.ZERO
				if state_time >= stun_duration:
					_wake_alert()
		var wanted := velocity
		move_and_slide()
		_track_stuck(wanted, delta)
		_check_hazards()
	_update_cone()
	_update_sprite(delta)
	queue_redraw()
	overlay.queue_redraw()

func _set_state(s: State) -> void:
	state = s
	state_time = 0.0
	stuck_time = 0.0

func _player_alive() -> bool:
	return player != null and is_instance_valid(player) and not player.is_dead

## Into the chase. The guard shouts first if it hasn't yet and can see the player.
func _wake_alert() -> void:
	_set_state(State.ALERT)
	suspicion = 1.0
	unseen_time = 0.0
	wary = true
	if _player_alive():
		target_point = player.global_position

func _investigate(pos: Vector2) -> void:
	target_point = pos
	look_time = INVESTIGATE_LOOK_TIME
	_set_state(State.INVESTIGATE)

# --- Senses ----------------------------------------------------------------------

func _sight_range(alerted: bool) -> float:
	var r := vision_range * (WARY_RANGE_MULT if wary else 1.0)
	return r * (1.4 if alerted else 1.0)

func _can_see_player(alerted: bool) -> bool:
	if not _player_alive():
		return false
	var to := player.global_position - global_position
	var dist := to.length()
	if dist > close_sense and dist > _sight_range(alerted) * _light_factor(alerted):
		return false
	if dist <= close_sense and close_sense_through_walls:
		return true
	if not alerted and dist > close_sense:
		if absf(facing.angle_to(to)) > deg_to_rad(vision_angle_degrees) * 0.5:
			return false
	return _line_clear(player.global_position, _cover_mask())

## How well the player can be seen where they stand: 1 in full light, less in darkness.
func _light_factor(alerted: bool) -> float:
	var l = player.get("light_level")
	if l == null:
		return 1.0
	return lerpf(DARK_SIGHT_MULT_ALERTED if alerted else DARK_SIGHT_MULT, 1.0, l)

## Unaware guards notice bodies in their vision cone. Bodies in darkness are only spotted up close.
func _look_for_bodies(delta: float) -> bool:
	_body_look_t -= delta
	if _body_look_t > 0.0:
		return false
	_body_look_t = BODY_LOOK_INTERVAL
	for b in get_tree().get_nodes_in_group("body"):
		if b.discovered:
			continue
		var to: Vector2 = b.global_position - global_position
		var dist := to.length()
		var reach := _sight_range(false) * lerpf(DARK_SIGHT_MULT, 1.0, b.light)
		if dist > reach:
			continue
		if dist > close_sense and absf(facing.angle_to(to)) > deg_to_rad(vision_angle_degrees) * 0.5:
			continue
		if not _line_clear(b.global_position, L.SIGHT_MASK):
			continue
		b.discovered = true
		body_alarm_pending = true
		wary = true
		Fx.popup(self, global_position + Vector2(0, -_sprite_height() - 6), "!?", Color(1.0, 0.6, 0.3))
		_investigate(b.global_position)
		return true
	return false

## At the body: shout, and bring every guard in earshot to search the area.
func _raise_body_alarm() -> void:
	body_alarm_pending = false
	velocity = Vector2.ZERO
	Fx.popup(self, global_position + Vector2(0, -_sprite_height() - 6), "BODY!", Color(1.0, 0.35, 0.3))
	Fx.alarm(self, global_position, BODY_ALARM_RADIUS, target_point)
	look_time = INVESTIGATE_LOOK_TIME * 2.0
	state_time = 6.0   # Stay here and look around.

## A guard checking out a noise relights any doused torch it finds there.
func _try_relight() -> void:
	for t in get_tree().get_nodes_in_group("torch"):
		if not t.lit and global_position.distance_to(t.global_position) <= RELIGHT_REACH:
			t.relight()

## Tall walls always block sight. Low cover (crates, barricades) only hides a crouching player.
func _cover_mask() -> int:
	return L.SIGHT_MASK if player.get("crouching") else L.WORLD

func _line_clear(to_pos: Vector2, mask: int = L.SIGHT_MASK) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position, to_pos, mask)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()

## Fill or drain the suspicion meter. Returns true when the guard has noticed the player.
func _update_suspicion(delta: float) -> bool:
	seeing = _can_see_player(false)
	if seeing:
		last_glimpse = player.global_position
		var dist := global_position.distance_to(player.global_position)
		if dist <= close_sense:
			suspicion = 1.0
		else:
			var reach := maxf(_sight_range(false) * _light_factor(false), close_sense + 1.0)
			var t := clampf((dist - close_sense) / (reach - close_sense), 0.0, 1.0)
			var notice_time := lerpf(NOTICE_TIME_NEAR, NOTICE_TIME_FAR, t)
			if wary:
				notice_time *= WARY_NOTICE_MULT
			if player.get("crouching"):
				notice_time *= CROUCH_NOTICE_MULT
			if player.has_method("notice_multiplier"):
				notice_time *= player.notice_multiplier(dist, wary, fooled_by_looks)
			suspicion += delta / notice_time
	else:
		suspicion = maxf(suspicion - SUSPICION_DECAY * delta, 0.0)
	if suspicion >= 1.0:
		_wake_alert()
		return true
	return false

# --- Behaviours ------------------------------------------------------------------

func _move_toward(target: Vector2, speed: float, delta: float) -> void:
	var to := target - global_position
	if to.length() < 4.0:
		velocity = Vector2.ZERO
		return
	var dir := to.normalized()
	if detour_time > 0.0:
		detour_time -= delta
		dir = (dir + detour_dir * 1.5).normalized()
	velocity = dir * speed
	_face_dir(to.normalized(), delta, 6.0)

func _face_dir(dir: Vector2, delta: float, rate: float) -> void:
	if dir == Vector2.ZERO:
		return
	facing = facing.slerp(dir, minf(1.0, rate * delta)).normalized()

## Notices when the guard is pushing against something and steps sideways.
func _track_stuck(wanted: Vector2, delta: float) -> void:
	if wanted.length() < 10.0:
		stuck_time = 0.0
		return
	if get_real_velocity().length() < wanted.length() * 0.3:
		stuck_time += delta
	else:
		stuck_time = maxf(stuck_time - delta, 0.0)
	if stuck_time >= STUCK_TIME:
		stuck_time = 0.0
		if state == State.PATROL and not patrol_points.is_empty():
			patrol_index = (patrol_index + 1) % patrol_points.size()
		else:
			detour_dir = wanted.normalized().orthogonal() * (1.0 if randf() < 0.5 else -1.0)
			detour_time = DETOUR_TIME

func _patrol_speed() -> float:
	return walk_speed * (WARY_SPEED_MULT if wary else 1.0)

func _do_patrol(delta: float) -> void:
	if _update_suspicion(delta):
		return
	if _look_for_bodies(delta):
		return
	if seeing:
		# "What was that?" Stop and stare while suspicion builds.
		velocity = Vector2.ZERO
		_face_dir((player.global_position - global_position).normalized(), delta, 5.0)
		return
	if suspicion >= SUSPICION_INVESTIGATE:
		_investigate(last_glimpse)
		return
	if _on_patrol_tick(delta):
		return
	if patrol_points.is_empty():
		_move_toward(home, _patrol_speed(), delta)
		if global_position.distance_to(home) < 6.0:
			if wary:
				facing = facing.rotated(1.2 * delta)
			else:
				_face_dir(Vector2.RIGHT.rotated(deg_to_rad(facing_degrees)), delta, 4.0)
		return
	if wait_time > 0.0:
		wait_time -= delta
		velocity = Vector2.ZERO
		if wary:
			facing = facing.rotated(2.5 * delta)   # Sweep the area.
		return
	var target := patrol_points[patrol_index]
	if global_position.distance_to(target) < 8.0:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		wait_time = WARY_PAUSE if wary else PATROL_PAUSE
		velocity = Vector2.ZERO
	else:
		_move_toward(target, _patrol_speed(), delta)

func _do_investigate(delta: float) -> void:
	if _update_suspicion(delta):
		return
	if not body_alarm_pending and _look_for_bodies(delta):
		return
	if seeing:
		velocity = Vector2.ZERO
		_face_dir((player.global_position - global_position).normalized(), delta, 5.0)
		target_point = last_glimpse
		return
	# Walk to the spot (give up after a few seconds if blocked), then look around.
	# Close enough? (Things like braziers are solid, so "right next to it" counts.)
	var arrive_dist := 40.0 if get_real_velocity().length() < 20.0 and state_time > 0.3 else 12.0
	if global_position.distance_to(target_point) > arrive_dist and state_time < 6.0:
		_move_toward(target_point, _investigate_speed(), delta)
	elif body_alarm_pending:
		_raise_body_alarm()
	elif _on_arrived():
		return
	else:
		velocity = Vector2.ZERO
		_try_relight()
		facing = facing.rotated(2.0 * delta)
		look_time -= delta
		if look_time <= 0.0:
			_return_to_patrol()

func _return_to_patrol() -> void:
	suspicion = 0.0
	has_shouted = false
	wait_time = 0.0
	if wary and not wary_waypoint_added:
		# Widen the patrol to cover where the intruder was last seen.
		wary_waypoint_added = true
		if patrol_points.is_empty():
			patrol_points = PackedVector2Array([home, target_point])
		else:
			patrol_points.insert(patrol_index, target_point)
	_set_state(State.PATROL)

func _do_shout(delta: float) -> void:
	velocity = Vector2.ZERO
	if _player_alive():
		_face_dir((player.global_position - global_position).normalized(), delta, 10.0)
	if state_time >= shout_time:
		has_shouted = true
		Fx.popup(self, global_position + Vector2(0, -30), shout_text, Color(1.0, 0.35, 0.3))
		Fx.alarm(self, global_position, alarm_radius, player.global_position if _player_alive() else target_point)
		_set_state(State.ALERT)

func _do_chase(delta: float) -> void:
	if not _player_alive():
		_return_to_patrol()
		return
	if _can_see_player(true):
		target_point = player.global_position
		unseen_time = 0.0
		if not has_shouted:
			velocity = Vector2.ZERO
			_set_state(State.SHOUT)
			return
		if _choose_attack():
			return
	else:
		unseen_time += delta
		if unseen_time >= LOSE_TRACK_TIME:
			_investigate(target_point)
			return
	_move_toward(target_point, chase_speed, delta)

func _try_land_lunge() -> void:
	if lunge_landed or not _player_alive():
		return
	if global_position.distance_to(player.global_position) < radius + 12.0 + 8.0:
		lunge_landed = true
		player.take_damage(lunge_damage, global_position, lunge_knock)

# --- Hooks for enemy types --------------------------------------------------------

## Called each patrol tick when the guard has nothing better to do. Return true if handled.
func _on_patrol_tick(_delta: float) -> bool:
	return false

## Called when an investigation reaches its spot. Return true to keep going instead of looking around.
func _on_arrived() -> bool:
	return false

func _investigate_speed() -> float:
	return walk_speed * 1.4

## Decide whether to attack now (the player is in sight). Return true if an attack started.
func _choose_attack() -> bool:
	if global_position.distance_to(target_point) > attack_range:
		return false
	_begin_windup(windup_time)
	return true

func _begin_windup(base_time: float) -> void:
	velocity = Vector2.ZERO
	windup_duration = base_time
	if randf() < feint_chance:
		windup_duration += randf_range(FEINT_EXTRA_MIN, FEINT_EXTRA_MAX)
	_set_state(State.WINDUP)

## Called when the wind-up finishes.
func _start_attack() -> void:
	lunge_dir = facing
	lunge_landed = false
	_set_state(State.LUNGE)

## Movement for the CHARGE state (enemy types that charge).
func _do_special(_delta: float) -> void:
	_set_state(State.ALERT)

func _do_knocked(delta: float) -> void:
	var speed_before := knock_velocity.length()
	velocity = knock_velocity
	move_and_slide()
	var slammed := false
	var chained := false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other = col.get_collider()
		if other is Node and other.has_method("apply_knockback"):
			if other != self and not knock_hits.has(other) and not other.is_dying():
				knock_hits.append(other)
				other.apply_knockback(knock_velocity * CHAIN_TRANSFER, 0.4, true)
				if "knock_hits" in other:
					other.knock_hits.append(self)
				knock_velocity *= 0.3
				chained = true
				if other.is_in_group("enemy"):
					Fx.popup(other, other.global_position + Vector2(0, -28), "CHAIN", Color(1.0, 0.6, 0.25))
		elif other is StaticBody2D and speed_before >= WALL_SLAM_SPEED and not slammed:
			slammed = true
			pending_stun = maxf(pending_stun, WALL_SLAM_STUN)
			knock_velocity = knock_velocity.bounce(col.get_normal()) * 0.25
			Fx.popup(self, global_position + Vector2(0, -28), "SLAM", Color(0.9, 0.9, 0.9))
			Fx.shake(self, 5.0)
			Fx.hitstop(self, 0.08, 0.05)
	if not slammed and not chained:
		knock_velocity = velocity
	knock_velocity = knock_velocity.move_toward(Vector2.ZERO, KNOCK_FRICTION * delta)
	_check_hazards()
	if state == State.KNOCKED and knock_velocity.length() < KNOCK_END_SPEED:
		knock_velocity = Vector2.ZERO
		if knock_peak >= CRUMBLE_MIN_SPEED:
			for h in get_tree().get_nodes_in_group("hazard"):
				if h.try_crumble(global_position, radius):
					_die("pit")
					return
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
			Fx.hitstop(self, 0.45, 0.3)
			var drift := global_position + knock_velocity.normalized() * 18.0
			tw.tween_property(self, "scale", Vector2(0.1, 0.1), 0.6).set_ease(Tween.EASE_IN)
			tw.tween_property(self, "rotation", 5.0, 0.6)
			tw.tween_property(self, "modulate", Color(0.2, 0.2, 0.2, 0.0), 0.6)
			tw.tween_property(self, "global_position", drift, 0.6)
		"water":
			Fx.popup(self, above, "DROWNED", Color(0.55, 0.75, 1.0))
			Fx.ring(self, global_position, 36.0, Color(0.6, 0.8, 1.0, 0.9))
			Fx.hitstop(self, 0.45, 0.3)
			tw.tween_property(self, "scale", Vector2(0.6, 0.6), 0.9)
			tw.tween_property(self, "modulate", Color(0.3, 0.5, 1.0, 0.0), 0.9)
		_:
			# Bolts stuck in the guard drop where it falls. In a pit or water they're lost.
			Fx.drop(self, global_position, "bolt", embedded_bolts)
			if cause == "sneak":
				Fx.popup(self, above, "SNEAK KILL", Color(0.75, 1.0, 0.6))
			Fx.hitstop(self, 0.09, 0.05)
			_spawn_body.call_deferred()
			if sprite != null:
				sprite.visible = false
			tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.15)
	tw.chain().tween_callback(queue_free)

# --- Drawing ---------------------------------------------------------------------

func _update_cone() -> void:
	cone_points.clear()
	if state == State.KNOCKED or state == State.STUNNED or state == State.DYING or state == State.CHARGE:
		return
	var space := get_world_2d().direct_space_state
	var half := deg_to_rad(vision_angle_degrees) * 0.5
	var reach := _sight_range(false)
	for i in CONE_RAYS + 1:
		var ang := -half + (2.0 * half) * float(i) / CONE_RAYS
		var end := global_position + facing.rotated(ang) * reach
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, end, L.WORLD))
		if not hit.is_empty():
			end = hit.position
		cone_points.append(end - global_position)

## How tall the sprite is above the feet (for placing icons above the head).
func _sprite_height() -> float:
	return 30.0 if sprite != null else radius + 4.0

func _base_color() -> Color:
	return Color(0.72, 0.24, 0.2)

func _draw_body(body: Color) -> void:
	draw_circle(Vector2.ZERO, radius, body)
	draw_circle(facing * (radius - 4.0), 4.0, Color(0.25, 0.05, 0.05))

## Extra overlays for enemy types (telegraphs etc.).
func _draw_extra() -> void:
	pass

func _draw() -> void:
	# Vision cone: white when calm, shading to yellow then red as suspicion builds.
	if cone_points.size() >= 2:
		var cc := Color(1, 1, 1, 0.06)
		if state == State.PATROL or state == State.INVESTIGATE:
			var calm := Color(1.0, 0.85, 0.3, 0.12) if state == State.INVESTIGATE else Color(1, 1, 1, 0.06)
			cc = calm.lerp(Color(1.0, 0.3, 0.2, 0.2), suspicion)
		else:
			cc = Color(1.0, 0.3, 0.25, 0.07)
		var cols := PackedColorArray([cc, cc, cc])
		for i in cone_points.size() - 1:
			draw_primitive(PackedVector2Array([Vector2.ZERO, cone_points[i], cone_points[i + 1]]), cols, PackedVector2Array())

	if sprite != null and sprite.is_loaded():
		# Contact shadow, and the "wary" ring on the floor around the feet.
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, radius + 1.0, Color(0, 0, 0, 0.35))
		if wary and state != State.DYING:
			draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 24, Color(1.0, 0.75, 0.3, 0.6), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var body := _base_color()
		if state == State.STUNNED:
			body = Color(0.45, 0.45, 0.75)
		elif state == State.WINDUP:
			body = body.lerp(Color(1.0, 0.65, 0.2), clampf(state_time / windup_duration, 0.0, 1.0))
		if hit_flash > 0.0:
			body = Color.WHITE
		draw_circle(Vector2.ZERO, radius + 2.0, Color(0, 0, 0, 0.35))
		_draw_body(body)
	_draw_extra()

## Drawn above the sprite: telegraphs, stun stars, health, suspicion and alert icons.
func _draw_overlay() -> void:
	var o := overlay
	var top := -_sprite_height()
	var windup_k := clampf(state_time / windup_duration, 0.0, 1.0)

	if state == State.WINDUP:
		o.draw_arc(Vector2.ZERO, radius + 4.0 + 16.0 * (1.0 - windup_k), 0.0, TAU, 24, Color(1.0, 0.6, 0.2, 0.9), 2.0)
	if state == State.SHOUT:
		var sk := clampf(state_time / SHOUT_TIME, 0.0, 1.0)
		for i in 2:
			o.draw_arc(Vector2.ZERO, radius + 6.0 + i * 7.0 + sk * 6.0, -PI * 0.9, -PI * 0.1, 10, Color(1.0, 0.3, 0.25, 0.8 - i * 0.3), 2.0)
	if state == State.STUNNED:
		for k in 3:
			var a := state_time * 4.0 + k * TAU / 3.0
			o.draw_circle(Vector2(cos(a) * 12.0, top - 4.0 + sin(a) * 4.0), 2.5, Color(1.0, 1.0, 0.6))

	if state != State.DYING and health < max_health:
		for i in max_health:
			var pc := Color(0.9, 0.3, 0.25) if i < health else Color(0.2, 0.2, 0.2)
			o.draw_rect(Rect2(-12.0 + i * 9.0, 4.0, 7.0, 3.0), pc)

	# Suspicion meter above the head while it's building.
	if (state == State.PATROL or state == State.INVESTIGATE) and suspicion > 0.02:
		o.draw_rect(Rect2(-12, top - 10, 24, 4), Color(0, 0, 0, 0.6))
		o.draw_rect(Rect2(-12, top - 10, 24 * suspicion, 4), Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.3, 0.2), suspicion))

	var font := ThemeDB.fallback_font
	if state == State.ALERT or state == State.WINDUP or state == State.LUNGE or state == State.RECOVER or state == State.SHOUT or state == State.CHARGE:
		o.draw_string(font, Vector2(-3, top - 2), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.35, 0.3))
	elif state == State.INVESTIGATE and suspicion <= 0.02:
		o.draw_string(font, Vector2(-4, top - 2), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.85, 0.3))
