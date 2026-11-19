extends Node2D
## M0 combat sandbox: one room to test whether physics combat is fun.

const Fx = preload("res://scripts/Fx.gd")

@onready var player = $Player
@onready var hud = $HUD

var kills := {"bolt": 0, "blade": 0, "sneak": 0, "pit": 0, "water": 0}
var enemies_total := 0
var enemies_left := 0

func _ready() -> void:
	# Gloom: darken everything, then light the player and the torches.
	var dark := CanvasModulate.new()
	dark.color = Color(0.5, 0.5, 0.6)
	add_child(dark)
	var lamp := PointLight2D.new()
	lamp.texture = Fx.radial_texture()
	lamp.texture_scale = 2.6
	lamp.energy = 0.85
	lamp.color = Color(1.0, 0.93, 0.82)
	player.add_child(lamp)

	# Popups and noise rings go on their own layer so the darkness doesn't hide them.
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 1
	fx_layer.follow_viewport_enabled = true
	fx_layer.add_to_group("fx_layer")
	add_child(fx_layer)

	for e in get_tree().get_nodes_in_group("enemy"):
		e.died.connect(_on_enemy_died)
		enemies_total += 1
	enemies_left = enemies_total
	player.died.connect(_on_player_died)
	hud.setup(self, player)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

func _on_enemy_died(_enemy: Node, cause: String) -> void:
	kills[cause] = kills.get(cause, 0) + 1
	enemies_left -= 1
	if enemies_left <= 0 and not player.is_dead:
		hud.show_message("Room cleared!\nPress R to reset the room and try another approach.")

func _on_player_died() -> void:
	hud.show_message("You died.\nPress R to try again.")
