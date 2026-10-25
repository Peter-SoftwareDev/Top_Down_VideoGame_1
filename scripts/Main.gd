extends Node2D

const ENEMY_SCENE = preload("res://scenes/Enemy.tscn")

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD

var score: int = 0
var spawn_timer: float = 0.0

func _ready() -> void:
	player.player_damaged.connect(_on_player_damaged)
	update_hud()
	spawn_enemy()

func _process(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_enemy()
		spawn_timer = 1.2

func spawn_enemy() -> void:
	if get_tree().current_scene == null:
		return

	var enemy = ENEMY_SCENE.instantiate()
	var radius = 300
	var angle = randf() * TAU
	var spawn_position = Vector2(
		cos(angle) * radius,
		sin(angle) * radius
	)
	spawn_position += player.global_position
	enemy.global_position = spawn_position
	add_child(enemy)
	enemy.add_to_group("enemy")

func _on_player_damaged(current_health: int) -> void:
	update_hud()
	if current_health <= 0:
		print("Game Over")

func _on_enemy_killed() -> void:
	score += 1
	update_hud()

func update_hud() -> void:
	if hud != null and hud.has_method("set_stats"):
		hud.set_stats(player.health if is_instance_valid(player) else 0, score)
