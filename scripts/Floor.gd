@tool
extends Node2D
## The room's floor.
##
## If baked floor art exists (see tools/pixelart/bake_test_room.py), it's shown with its
## normal map so torchlight shades the stones. Otherwise a gray-box grid is drawn.
## The bake also writes a small material map, used for footstep noise.

@export var size: Vector2 = Vector2(1400, 900):
	set(value):
		size = value
		queue_redraw()
@export var tile: float = 64.0
## Baked floor colours. Leave empty for the gray-box grid.
@export_file("*.png") var albedo_path: String = ""
@export_file("*.png") var normal_path: String = ""
## Material map: one pixel per `material_cell` world pixels, red channel = material id.
@export_file("*.png") var materials_path: String = ""
@export var material_cell: int = 16

const Assets = preload("res://scripts/Assets.gd")
const MATERIALS := ["stone", "straw", "iron", "brick", "water"]

var _sprite: Sprite2D
var _materials: Image

func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("floor")
	var albedo: Texture2D = Assets.texture(albedo_path) if albedo_path != "" else null
	if albedo != null:
		var ct := CanvasTexture.new()
		ct.diffuse_texture = albedo
		if normal_path != "":
			ct.normal_texture = Assets.texture(normal_path)
		_sprite = Sprite2D.new()
		_sprite.texture = ct
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
	if materials_path != "":
		_materials = Assets.image(materials_path)
	queue_redraw()

## The floor material at a world position: "stone", "straw", "iron", "brick" or "water".
func material_at(world_pos: Vector2) -> String:
	if _materials == null:
		return "stone"
	var local := world_pos - (global_position - size * 0.5)
	var cx := int(local.x / material_cell)
	var cy := int(local.y / material_cell)
	if cx < 0 or cy < 0 or cx >= _materials.get_width() or cy >= _materials.get_height():
		return "stone"
	var id := int(round(_materials.get_pixel(cx, cy).r * 255.0 / 40.0))
	return MATERIALS[clampi(id, 0, MATERIALS.size() - 1)]

func _draw() -> void:
	if _sprite != null:
		return
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, Color(0.2, 0.19, 0.21))
	var cols := int(size.x / tile)
	var rows := int(size.y / tile)
	for gx in cols:
		for gy in rows:
			var h: int = absi((gx * 73856093) ^ (gy * 19349663))
			if h % 7 == 0:
				var p := r.position + Vector2(gx, gy) * tile
				draw_rect(Rect2(p + Vector2(2, 2), Vector2(tile - 4, tile - 4)), Color(0, 0, 0, 0.12))
	var x := r.position.x
	while x <= r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.22), 1.0)
		x += tile
	var y := r.position.y
	while y <= r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0, 0, 0, 0.22), 1.0)
		y += tile
