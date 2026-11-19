extends Node2D
## M0 combat sandbox: one room to test whether physics combat is fun.

const Fx = preload("res://scripts/Fx.gd")
const LoadoutSelect = preload("res://scripts/LoadoutSelect.gd")

## The loadout picked on the select screen. Survives room resets (R); Esc clears it.
static var chosen_loadout := -1

@onready var player = $Player
@onready var hud = $HUD

var kills := {"bolt": 0, "blade": 0, "sneak": 0, "pit": 0, "water": 0, "crush": 0}
var enemies_total := 0
var enemies_left := 0
var _slow_until_ms := 0
var _slow_scale := 1.0

func _ready() -> void:
	add_to_group("game")
	Engine.time_scale = 1.0
	# Gloom: darken everything, then light the player and the torches.
	var dark := CanvasModulate.new()
	dark.color = Color(0.36, 0.36, 0.46)
	add_child(dark)
	var lamp := PointLight2D.new()
	lamp.texture = Fx.radial_texture()
	# A faint glow so you can see where you're going. Guards ignore it: only torches
	# and braziers make you visible (see the light meter).
	lamp.texture_scale = 2.0
	lamp.energy = 0.55
	lamp.color = Color(1.0, 0.93, 0.82)
	lamp.height = 20.0
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

	if chosen_loadout < 0:
		get_tree().paused = true
		var select := LoadoutSelect.new()
		select.chosen.connect(_on_loadout_chosen)
		add_child(select)
	else:
		_apply_loadout(chosen_loadout)

func _on_loadout_chosen(loadout: int) -> void:
	chosen_loadout = loadout
	_apply_loadout(loadout)
	get_tree().paused = false

func _apply_loadout(loadout: int) -> void:
	player.loadout = loadout
	player.charges = player.secondary_max_charges

func _process(_delta: float) -> void:
	if _slow_until_ms > 0 and Time.get_ticks_msec() >= _slow_until_ms:
		_slow_until_ms = 0
		_slow_scale = 1.0
		Engine.time_scale = 1.0
	if Input.is_action_just_pressed("restart"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
	elif Input.is_action_just_pressed("menu"):
		chosen_loadout = -1
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()

## Slow time for `duration` real seconds. Overlapping calls keep the strongest slowdown.
func hitstop(duration: float, time_scale: float) -> void:
	var now := Time.get_ticks_msec()
	var until := now + int(duration * 1000.0)
	if _slow_until_ms > now:
		_slow_scale = minf(_slow_scale, time_scale)
		_slow_until_ms = maxi(_slow_until_ms, until)
	else:
		_slow_scale = time_scale
		_slow_until_ms = until
	Engine.time_scale = _slow_scale

func _on_enemy_died(_enemy: Node, cause: String) -> void:
	kills[cause] = kills.get(cause, 0) + 1
	enemies_left -= 1
	if enemies_left <= 0 and not player.is_dead:
		hud.show_message("Room cleared!\nPress R to reset the room and try another approach.")

func _on_player_died() -> void:
	hud.show_message("You died.\nPress R to try again.")
