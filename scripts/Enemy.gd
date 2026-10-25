extends CharacterBody2D

@export var speed: float = 80.0
@export var health: int = 2

signal enemy_died

var target: Node2D
var attack_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("enemy")

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player")
		if target == null:
			return

	var direction = target.global_position - global_position
	var distance = direction.length()
	if distance > 0:
		direction = direction.normalized()

	if distance > 30.0:
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO
		attack_cooldown -= delta
		if attack_cooldown <= 0.0 and target.has_method("take_damage"):
			target.take_damage(1)
			attack_cooldown = 0.7

	move_and_slide()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		enemy_died.emit()
		queue_free()
