extends CharacterBody2D

const SPEED = 220.0
const BULLET_SCENE = preload("res://scenes/Bullet.tscn")
const FIRE_RATE = 0.18

@export var max_health: int = 5
var health: int = max_health
var fire_timer: float = 0.0

signal player_damaged(current_health)

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if direction.length() > 1.0:
		direction = direction.normalized()

	velocity = direction * SPEED
	move_and_slide()

	var aim_vector = get_global_mouse_position() - global_position
	if aim_vector.length() > 0.0:
		rotation = aim_vector.angle()

	fire_timer -= delta
	if Input.is_action_pressed("shoot") and fire_timer <= 0.0:
		shoot()
		fire_timer = FIRE_RATE

func shoot() -> void:
	var bullet = BULLET_SCENE.instantiate()
	var aim_direction = (get_global_mouse_position() - global_position)
	if aim_direction.length() > 0:
		aim_direction = aim_direction.normalized()
	else:
		aim_direction = Vector2.RIGHT

	bullet.global_position = global_position + aim_direction * 24.0
	bullet.direction = aim_direction
	bullet.rotation = aim_direction.angle()
	get_tree().current_scene.add_child(bullet)

func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	player_damaged.emit(health)
	if health <= 0:
		queue_free()
