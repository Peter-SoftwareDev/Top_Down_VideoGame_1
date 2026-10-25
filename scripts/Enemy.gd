extends CharacterBody2D

@export var speed: float = 70.0
@export var health: int = 2

var target: Node2D

func _ready() -> void:
	if get_tree().current_scene != null and get_tree().current_scene.has_node("Player"):
		target = get_tree().current_scene.get_node("Player")

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	var direction = target.global_position - global_position
	if direction.length() > 0:
		direction = direction.normalized()
		velocity = direction * speed
		move_and_slide()

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()
