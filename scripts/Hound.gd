extends "res://scripts/Enemy.gd"
## SCENT-HOUND: fast, fragile, hunts in pairs.
##
## Short sight, but it follows your scent trail: the path you walked over the last
## few seconds. It smells you through cover when close. When it finds you it barks,
## which carries further than a guard's shout.
## It's light: kicks and rocks send it twice as far.
## Shake it off by staying ahead until the trail goes cold, or distract it with a rock.

const SNIFF_RANGE := 150.0

var tracking := false
var trail_time := -INF

func _ready() -> void:
	radius = 10.0
	walk_speed = 95.0
	chase_speed = 215.0
	vision_range = 200.0
	vision_angle_degrees = 140.0
	close_sense = 80.0
	close_sense_through_walls = true
	fooled_by_looks = false
	attack_range = 38.0
	windup_time = 0.3
	feint_chance = 0.1
	lunge_speed = 520.0
	lunge_knock = 220.0
	recover_time = 0.4
	shout_time = 0.2
	shout_text = "BARK!"
	alarm_radius = 400.0
	knock_scale = 2.0
	super._ready()

func _make_sprite() -> Node2D:
	var s := CharacterSprite.new()
	s.sheet_path = "res://assets/art/chars/hound.png"
	s.frame_size = Vector2i(32, 24)
	s.lift = 6.0
	return s

func _sprite_height() -> float:
	return 18.0

func hear_noise(pos: Vector2, r: float) -> void:
	if is_unaware() and global_position.distance_to(pos) <= r:
		tracking = false
	super.hear_noise(pos, r)

## Pick the freshest scent point it can reach from here.
func _pick_scent() -> bool:
	if not _player_alive() or not "scent" in player:
		return false
	var best: Dictionary = {}
	for point in player.scent:
		if point.time <= trail_time:
			continue
		if global_position.distance_to(point.pos) > SNIFF_RANGE:
			continue
		if not _line_clear(point.pos):
			continue
		if best.is_empty() or point.time > best.time:
			best = point
	if best.is_empty():
		return false
	trail_time = best.time
	target_point = best.pos
	return true

func _on_patrol_tick(_delta: float) -> bool:
	if _pick_scent():
		if not tracking:
			Fx.popup(self, global_position + Vector2(0, -24), "sniff", Color(1.0, 0.85, 0.3))
		tracking = true
		_investigate(target_point)
		return true
	return false

func _on_arrived() -> bool:
	if tracking and _pick_scent():
		_set_state(State.INVESTIGATE)   # Fresh timer for the next leg of the trail.
		return true
	tracking = false
	return false

func _investigate_speed() -> float:
	return walk_speed * (1.8 if tracking else 1.4)

func _base_color() -> Color:
	return Color(0.55, 0.38, 0.25)

func _draw_body(body: Color) -> void:
	# Long body and a snout pointing where it's facing.
	draw_circle(-facing * 6.0, radius * 0.85, body)
	draw_circle(Vector2.ZERO, radius, body)
	draw_circle(facing * 9.0, 5.0, body.darkened(0.2))
	draw_circle(facing * 13.0, 2.0, Color(0.1, 0.05, 0.05))
	var side := facing.orthogonal()
	draw_circle(facing * 2.0 + side * 6.0, 2.5, body.darkened(0.4))
	draw_circle(facing * 2.0 - side * 6.0, 2.5, body.darkened(0.4))

func _draw_extra() -> void:
	if tracking and state == State.INVESTIGATE:
		for i in 3:
			var off := facing * (16.0 + i * 6.0) + facing.orthogonal() * sin(state_time * 10.0 + i) * 3.0
			draw_circle(off, 1.5, Color(1.0, 0.85, 0.3, 0.6 - i * 0.15))
