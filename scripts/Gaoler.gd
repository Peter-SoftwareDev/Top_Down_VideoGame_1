extends "res://scripts/Enemy.gd"
## GAOLER: a big, slow brute.
##
## Too heavy to kick or knock with a rock: it only reels from impacts (a guard or crate
## crashing into it) or from slamming into a wall. While staggered it can be kicked like
## anyone else, and takes double damage.
## Its signature move is a straight-line shoulder charge with a long telegraph.
## Sidestep it and it slams into the wall behind you and staggers. Stand between it and
## a pit and it can throw *you* in. Lure it across a pit and it can charge right in.

const CHARGE_MIN_RANGE := 90.0
const CHARGE_MAX_RANGE := 300.0
const CHARGE_WINDUP := 0.75
const CHARGE_SPEED := 430.0
const CHARGE_TIME := 0.85
const CHARGE_COOLDOWN := 2.5
const CHARGE_DAMAGE := 2
const CHARGE_KNOCK := 560.0
const SLAM_STAGGER := 2.2
const IMPACT_STAGGER := 1.2

var charge_dir := Vector2.ZERO
var charge_cd := 0.0
var charge_pending := false
var charge_hits: Array = []
var blocked_time := 0.0
const PIN_TIME := 0.12          # Blocked this long by a body = it's pinned and gets crushed.
const PIN_DAMAGE := 2
var _heavy_popup_cd := 0.0

func _ready() -> void:
	radius = 20.0
	attack_range = 52.0
	windup_time = 0.55
	feint_chance = 0.2
	lunge_speed = 380.0
	lunge_damage = 2
	lunge_knock = 460.0
	recover_time = 0.7
	shout_text = "INTRUDER!"
	knock_scale = 0.0
	super._ready()

func _make_sprite() -> Node2D:
	var s := CharacterSprite.new()
	s.sheet_path = "res://assets/art/chars/gaoler.png"
	s.frame_size = Vector2i(32, 40)
	s.lift = 13.0
	return s

func _sprite_height() -> float:
	return 40.0

func _physics_process(delta: float) -> void:
	charge_cd = maxf(charge_cd - delta, 0.0)
	_heavy_popup_cd = maxf(_heavy_popup_cd - delta, 0.0)
	super._physics_process(delta)

## Kicks and rocks barely register. Impacts and staggers are another story.
func apply_knockback(impulse: Vector2, stun: float, impact: bool = false) -> void:
	if state == State.DYING:
		return
	if state == State.STUNNED:
		_apply_push(impulse * 0.8, stun)
	elif impact:
		Fx.popup(self, global_position + Vector2(0, -34), "STAGGERED", Color(0.75, 0.8, 1.0))
		_apply_push(impulse * 0.35, maxf(stun, IMPACT_STAGGER))
	elif impulse.length() > 200.0:
		hit_flash = 0.08
		if _heavy_popup_cd <= 0.0:
			_heavy_popup_cd = 0.8
			Fx.popup(self, global_position + Vector2(0, -34), "TOO HEAVY", Color(0.8, 0.8, 0.8))
		if is_unaware():
			_wake_alert()

## No instant sneak kills on a brute: an unaware hit does triple damage instead.
func take_damage(amount: int, cause: String, allow_sneak: bool = true) -> void:
	if allow_sneak and is_unaware():
		amount *= 3
		_wake_alert()
	super.take_damage(amount, cause, false)

func _choose_attack() -> bool:
	var dist := global_position.distance_to(target_point)
	if dist <= attack_range:
		charge_pending = false
		_begin_windup(windup_time)
		return true
	if charge_cd <= 0.0 and dist >= CHARGE_MIN_RANGE and dist <= CHARGE_MAX_RANGE \
			and not _lane_blocked(target_point):
		charge_pending = true
		_begin_windup(CHARGE_WINDUP)
		return true
	return false

func _start_attack() -> void:
	if not charge_pending:
		super._start_attack()
		return
	charge_pending = false
	# The player may have moved during the wind-up. Never charge across a pit or water at them.
	if _player_alive() and _lane_blocked(player.global_position):
		Fx.popup(self, global_position + Vector2(0, -34), "...", Color(0.8, 0.8, 0.8))
		_set_state(State.RECOVER)
		return
	charge_dir = facing
	charge_cd = CHARGE_COOLDOWN
	charge_hits.clear()
	blocked_time = 0.0
	# Charging ignores pit rims: overshoot one and it goes in.
	collision_mask = L.ENEMY_KNOCK_MASK
	Fx.shake(self, 3.0)
	_set_state(State.CHARGE)

## Is anything in the way of a charge at `to_pos`: a wall, a half wall, a pit or water?
## Checks the middle and both shoulders of the lane. Crates don't count: it bowls them over.
## (Anything *beyond* the target doesn't count: that's the player's chance to make it overshoot.)
func _lane_blocked(to_pos: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var dir := (to_pos - global_position).normalized()
	var side := dir.orthogonal() * (radius - 2.0)
	for off in [Vector2.ZERO, side, -side]:
		var q := PhysicsRayQueryParameters2D.create(global_position + off, to_pos + off, L.WORLD | L.LOW_WALL | L.HAZARD_EDGE)
		if not space.intersect_ray(q).is_empty():
			return true
	return false

func _do_special(delta: float) -> void:
	var speed := CHARGE_SPEED * minf(1.0, 0.4 + state_time * 6.0)
	velocity = charge_dir * speed
	move_and_slide()
	var pinned_body: Node = null
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other = col.get_collider()
		if other is Node and other.is_in_group("player"):
			_end_charge()
			if not other.is_dead and other.dodge_time <= 0.0:
				Fx.popup(other, other.global_position + Vector2(0, -28), "SMASHED", Color(1.0, 0.4, 0.3))
				other.take_damage(CHARGE_DAMAGE, other.global_position - charge_dir * 20.0, CHARGE_KNOCK)
			return
		if other is Node and other.has_method("apply_knockback"):
			pinned_body = other
			if not charge_hits.has(other) and not other.is_dying():
				charge_hits.append(other)
				Fx.popup(other, other.global_position + Vector2(0, -28), "BOWLED", Color(1.0, 0.6, 0.25))
				other.apply_knockback(charge_dir * CHARGE_SPEED * 1.1, 0.6, true)
				Fx.hitstop(self, 0.06, 0.05)
			continue
		if other is StaticBody2D:
			# Into the wall. Staggered, and wide open.
			_end_charge()
			Fx.popup(self, global_position + Vector2(0, -34), "STAGGERED", Color(0.75, 0.8, 1.0))
			Fx.shake(self, 8.0)
			Fx.hitstop(self, 0.1, 0.05)
			Fx.noise(self, global_position, 200.0)
			stun_duration = SLAM_STAGGER
			_set_state(State.STUNNED)
			return
	# Something it bowled is stuck between it and a wall: crush it and stop.
	if pinned_body != null and get_real_velocity().length() < speed * 0.3:
		blocked_time += delta
		if blocked_time >= PIN_TIME:
			_end_charge()
			if not pinned_body.is_dying():
				Fx.popup(pinned_body, pinned_body.global_position + Vector2(0, -28), "CRUSHED", Color(1.0, 0.45, 0.3))
				Fx.hitstop(self, 0.08, 0.05)
				pinned_body.take_damage(PIN_DAMAGE, "crush", false)
			return
	else:
		blocked_time = 0.0
	_check_hazards()
	if state == State.CHARGE and state_time >= CHARGE_TIME:
		_end_charge()
		_set_state(State.RECOVER)

func _end_charge() -> void:
	velocity = Vector2.ZERO
	collision_mask = L.ENEMY_WALK_MASK
	_set_state(State.RECOVER)

func _base_color() -> Color:
	return Color(0.42, 0.36, 0.38)

func _draw_body(body: Color) -> void:
	draw_circle(Vector2.ZERO, radius, body)
	# Iron shoulder plates and a heavy brow.
	var side := facing.orthogonal()
	draw_circle(side * (radius - 4.0), 7.0, Color(0.3, 0.3, 0.33))
	draw_circle(-side * (radius - 4.0), 7.0, Color(0.3, 0.3, 0.33))
	draw_circle(facing * (radius - 6.0), 5.0, Color(0.15, 0.08, 0.08))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.2, 0.18, 0.2), 2.0)

func _draw_extra() -> void:
	# The charge telegraph: a lane on the floor that brightens as the wind-up completes.
	if state == State.WINDUP and charge_pending:
		var k := clampf(state_time / windup_duration, 0.0, 1.0)
		var lane := CHARGE_SPEED * CHARGE_TIME
		var side := facing.orthogonal() * radius
		var c := Color(1.0, 0.45, 0.2, 0.08 + 0.2 * k)
		var cols := PackedColorArray([c, c, c, c])
		draw_primitive(PackedVector2Array([side, facing * lane + side, facing * lane - side, -side]), cols, PackedVector2Array())
