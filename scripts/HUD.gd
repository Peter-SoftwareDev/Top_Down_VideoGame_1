extends CanvasLayer
## Health, loadout, cooldowns, room status, kill tally and controls.

var main: Node
var player: Node
var message := ""
var canvas: Control

func _ready() -> void:
	layer = 10
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.draw.connect(_draw_hud)

func setup(main_node: Node, player_node: Node) -> void:
	main = main_node
	player = player_node

func show_message(text: String) -> void:
	message = text

func _process(_delta: float) -> void:
	canvas.queue_redraw()

func _text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	canvas.draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _text_width(text: String, font_size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

func _bar(pos: Vector2, label: String, ratio: float) -> void:
	_text(pos + Vector2(0, 10), label, 12, Color(0.8, 0.78, 0.72))
	canvas.draw_rect(Rect2(pos + Vector2(0, 15), Vector2(120, 6)), Color(0.15, 0.15, 0.15))
	var c := Color(0.9, 0.85, 0.6) if ratio >= 1.0 else Color(0.5, 0.48, 0.4)
	canvas.draw_rect(Rect2(pos + Vector2(0, 15), Vector2(120 * ratio, 6)), c)

func _draw_hud() -> void:
	if player == null or main == null:
		return
	var vp := canvas.size
	var light := Color(0.95, 0.92, 0.85)

	canvas.draw_rect(Rect2(12, 12, 412, 96), Color(0, 0, 0, 0.5))
	for i in player.max_health:
		var hc := Color(0.85, 0.2, 0.2) if i < player.health else Color(0.25, 0.2, 0.2)
		canvas.draw_rect(Rect2(24 + i * 22, 24, 18, 18), hc)
	_text(Vector2(24, 62), player.loadout_name(), 16, light)
	_bar(Vector2(24, 72), "LMB  " + player.primary_name(), player.primary_ready())
	_bar(Vector2(160, 72), "RMB  " + player.secondary_name(), player.secondary_ready())
	_bar(Vector2(296, 72), "Dodge", player.dodge_ready())
	# Charge pips for the kick / rock.
	for i in player.secondary_max_charges:
		var cc := Color(0.9, 0.85, 0.6) if i < player.charges else Color(0.3, 0.3, 0.28)
		canvas.draw_rect(Rect2(250 - i * 10, 76, 7, 7), cc)

	var k: Dictionary = main.kills
	var lines := [
		"Guards left: %d / %d" % [main.enemies_left, main.enemies_total],
		"Bolt %d   Blade %d   Sneak %d" % [k.bolt, k.blade, k.sneak],
		"Pit %d   Water %d   Crate %d" % [k.pit, k.water, k.crate],
	]
	var box_w := 250.0
	canvas.draw_rect(Rect2(vp.x - box_w - 12, 12, box_w, 74), Color(0, 0, 0, 0.5))
	for i in lines.size():
		_text(Vector2(vp.x - box_w, 34 + i * 20), lines[i], 14, light)

	var help := [
		"WASD move  |  Mouse aim  |  LMB primary  |  RMB secondary",
		"Space dodge  |  Q swap loadout  |  R reset room",
	]
	for i in help.size():
		_text(Vector2(16, vp.y - 34 + i * 18), help[i], 13, Color(0.8, 0.78, 0.72, 0.8))

	if message != "":
		var parts := message.split("\n")
		var h := parts.size() * 34.0 + 24.0
		canvas.draw_rect(Rect2(0, vp.y * 0.5 - h * 0.5, vp.x, h), Color(0, 0, 0, 0.6))
		for i in parts.size():
			var fs := 28 if i == 0 else 16
			var w := _text_width(parts[i], fs)
			_text(Vector2((vp.x - w) * 0.5, vp.y * 0.5 - h * 0.5 + 44 + i * 34), parts[i], fs, light)
