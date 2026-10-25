extends CharacterBody2D

const SPEED = 220.0
const BULLET_SCENE = preload("res://scenes/Bullet.tscn")
const FIRE_RATE = 0.18

var fire_timer: float = 0.0
var health: int = 5

signal player_damaged(current_health)

func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if direction.length() > 0:
		direction = direction.normalized()

	velocity = direction * SPEED
	move_and_slide()

	fire_timer -= delta
	if Input.is_action_pressed("shoot") and fire_timer <= 0.0:
		shoot()
		fire_timer = FIRE_RATE

func shoot() -> void:
	var bullet = BULLET_SCENE.instantiate()
	var aim_direction = (get_global_mouse_position() - global_position).normalized()

	if aim_direction.length() == 0:
		aim_direction = Vector2.RIGHT

	bullet.position = global_position
	bullet.direction = aim_direction
	get_tree().current_scene.add_child(bullet)

func take_damage(amount: int) -> void:
	health -= amount
	player_damaged.emit(health)
	if health <= 0:
		queue_free()
