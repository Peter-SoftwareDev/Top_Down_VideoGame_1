extends CanvasLayer
## Weapon select screen shown before a run. The choice is locked in for the run.

signal chosen(loadout: int)

const OPTIONS := [
	{
		"title": "Crossbow + Kick",
		"key": "1",
		"lines": [
			"LETHAL AT RANGE: a slow, heavy bolt.",
			"Limited bolts; pick them back up.",
			"",
			"NON-LETHAL UP CLOSE: a kick that",
			"sends guards and crates sliding,",
			"into pits, water and each other.",
		],
	},
	{
		"title": "Blade + Stun Rock",
		"key": "2",
		"lines": [
			"LETHAL UP CLOSE: a quick slash.",
			"Never runs out.",
			"",
			"NON-LETHAL AT RANGE: a thrown rock",
			"that stuns, knocks back and makes",
			"noise to lure guards away.",
		],
	},
]

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	center.add_child(column)

	column.add_child(_label("Choose your approach", 34, Color(0.95, 0.92, 0.85)))
	column.add_child(_label("Your choice is locked in for the run. Each pairs one lethal weapon with one physics tool.", 15, Color(0.75, 0.72, 0.66)))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)

	for i in OPTIONS.size():
		var opt: Dictionary = OPTIONS[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(330, 230)
		b.text = "[%s]  %s\n\n%s" % [opt.key, opt.title, "\n".join(opt.lines)]
		b.add_theme_font_size_override("font_size", 16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_pick.bind(i))
		row.add_child(b)
		if i == 0:
			b.grab_focus.call_deferred()

	column.add_child(_label("Click a card, or press 1 or 2.   In the room: R resets, Esc comes back here.", 14, Color(0.6, 0.58, 0.54)))

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_pick(0)
		elif event.keycode == KEY_2:
			_pick(1)

func _pick(i: int) -> void:
	chosen.emit(i)
	queue_free()
