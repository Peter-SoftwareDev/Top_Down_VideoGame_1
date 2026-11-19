extends Area2D
## Thrown stun rock: non-lethal. Knocks a guard (or a crate) back and stuns it.
## Wherever it lands it makes a noise that draws unaware guards to investigate,
## and it can be picked up again (unless it fell into a pit or water).

const L = preload("res://scripts/Layers.gd")
const Fx = preload("res://scripts/Fx.gd")

const SPEED := 620.0
const KNOCK := 520.0
const STUN := 1.6
const NOISE_RADIUS := 240.0
const HIT_NOISE_RADIUS := 140.0

var start := Vector2.ZERO
var target := Vector2.ZERO
var dir := Vector2.RIGHT
var flight_time := 0.1
var t := 0.0
var done := false

func setup(from: Vector2, to: Vector2) -> void:
	start = from
	target = to
	position = from
	if to != from:
		dir = (to - from).normalized()
	flight_time = maxf(from.distance_to(to) / SPEED, 0.08)

func _ready() -> void:
	collision_layer = 0
	collision_mask = L.PROJECTILE_MASK
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 5.0
	cs.shape = c
	add_child(cs)
	z_index = 5
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if done:
		return
	t += delta
	var k := minf(t / flight_time, 1.0)
	position = start.lerp(target, k)
	queue_redraw()
	if k >= 1.0:
		_land(NOISE_RADIUS, global_position)

func _on_body_entered(body: Node) -> void:
	if done:
		return
	if body.has_method("apply_knockback"):
		if body.is_dying():
			return
		body.apply_knockback(dir * KNOCK, STUN)
		if body.is_in_group("enemy"):
			Fx.popup(body, body.global_position + Vector2(0, -28), "STUNNED", Color(0.7, 0.75, 1.0))
			Fx.hitstop(self, 0.06, 0.05)
		_land(HIT_NOISE_RADIUS, global_position - dir * 20.0)
	else:
		_land(NOISE_RADIUS, global_position - dir * 18.0)

func _land(radius: float, rest_at: Vector2) -> void:
	done = true
	Fx.noise(self, global_position, radius)
	Fx.drop(self, rest_at, "rock")
	queue_free()

func _draw() -> void:
	var k := clampf(t / flight_time, 0.0, 1.0)
	var h := sin(k * PI) * 18.0
	draw_circle(Vector2.ZERO, 4.0, Color(0, 0, 0, 0.35))
	draw_circle(Vector2(0, -h), 5.0, Color(0.62, 0.6, 0.56))
