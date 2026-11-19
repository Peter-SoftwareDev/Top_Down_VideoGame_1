extends Area2D
## Crossbow bolt: fast, lethal, small knockback. Flies over pits and water.

const L = preload("res://scripts/Layers.gd")
const Fx = preload("res://scripts/Fx.gd")

var direction := Vector2.RIGHT
var damage := 2
var speed := 950.0
var knock := 160.0
var life := 1.2
var done := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = L.WORLD | L.ENEMY
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 4.0
	cs.shape = c
	add_child(cs)
	rotation = direction.angle()
	z_index = 5
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if done:
		return
	if body.is_in_group("enemy"):
		if body.is_dying():
			return
		done = true
		body.take_damage(damage, "bolt")
		body.apply_knockback(direction * knock, 0.0)
	else:
		done = true
		Fx.ring(self, global_position, 8.0, Color(0.8, 0.7, 0.5))
	queue_free()

func _draw() -> void:
	var c := Color(0.8, 0.65, 0.45)
	draw_line(Vector2(-12, 0), Vector2(6, 0), c, 2.0)
	draw_primitive(PackedVector2Array([Vector2(10, 0), Vector2(4, -3), Vector2(4, 3)]), PackedColorArray([c, c, c]), PackedVector2Array())
