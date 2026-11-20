extends Node2D
## A layered ("paper-doll") pixel-art character.
##
## Humans are built at runtime from layer sheets in assets/art/chars/human/: a body plus
## whatever gear is equipped (back, head, torso, hands, feet; each by tier). The layers are
## stacked in the right order for each facing, outlined, and given a normal map so torchlight
## shades them. Change gear with set_gear() and the look updates immediately.
## Non-human characters use one ready-made sheet (sheet_path) instead.
##
## Sheet layout (from tools/pixelart/characters.py): 4 columns x 12 rows. For each direction
## (down, up, right; left = right mirrored): idle(2), walk(4), crouch(2), act(1).

const HUMAN_DIR := "res://assets/art/chars/human/"
const Assets = preload("res://scripts/Assets.gd")
const COLS := 4
const ROWS := 12
const DIRS := ["down", "up", "right"]
const ANIMS := ["idle", "walk", "crouch", "act"]
const NFRAMES := {"idle": 2, "walk": 4, "crouch": 2, "act": 1}
const FPS := {"idle": 2.0, "walk": 9.0, "crouch": 6.0, "act": 1.0}
const ORDER := {
	"down": ["back", "body", "feet", "torso", "hands", "head"],
	"right": ["back", "body", "feet", "torso", "hands", "head"],
	"up": ["body", "feet", "torso", "hands", "back", "head"],
}
const OUTLINE := Color(0.051, 0.043, 0.078)

## Body layer for humans ("prisoner" or "guard"). Ignored when sheet_path is set.
@export var body: String = "prisoner"
## A ready-made sheet for non-humans (the Gaoler, hounds). Leave empty for a layered human.
@export_file("*.png") var sheet_path: String = ""
@export var frame_size: Vector2i = Vector2i(24, 32)
## How far above the node's origin the sprite's centre sits (feet near the origin).
@export var lift: float = 10.0

var gear := {}
## Built sheets, shared between characters that look the same.
static var _cache := {}
var dir := "down"
var anim := "idle"
var _t := 0.0
var _sprite: Sprite2D

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.hframes = COLS
	_sprite.vframes = ROWS
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(0, -lift)
	add_child(_sprite)
	rebuild()

## Equip `tier` in `slot` (back, head, torso, hands, feet). Tier < 0 removes it.
func set_gear(slot: String, tier: int) -> void:
	if tier < 0:
		gear.erase(slot)
	else:
		gear[slot] = tier
	rebuild()

func set_all_gear(new_gear: Dictionary) -> void:
	gear = new_gear.duplicate()
	rebuild()

func rebuild() -> void:
	if _sprite == null:
		return
	var key := sheet_path if sheet_path != "" else body + str(gear)
	if not _cache.has(key):
		var img: Image = _load_image(sheet_path) if sheet_path != "" else _compose()
		if img == null:
			push_warning("Character art missing (%s): drawing simple shapes instead." % key)
			return
		if sheet_path == "":
			pass   # Human sheets are outlined in _compose(); full sheets come outlined already.
		var ct := CanvasTexture.new()
		ct.diffuse_texture = ImageTexture.create_from_image(img)
		ct.normal_texture = ImageTexture.create_from_image(_normal_map(img))
		_cache[key] = ct
	_sprite.texture = _cache[key]
	_apply_frame()

func _load_image(path: String) -> Image:
	if not Assets.exists(path):
		return null
	return Assets.image(path)

## False if the art couldn't be loaded; the character then falls back to simple shapes.
func is_loaded() -> bool:
	return _sprite != null and _sprite.texture != null

func _compose() -> Image:
	var fw := frame_size.x
	var fh := frame_size.y
	var out := Image.create(COLS * fw, ROWS * fh, false, Image.FORMAT_RGBA8)
	var body_img := _load_image(HUMAN_DIR + "body_%s.png" % body)
	if body_img == null:
		return null
	var layers := {"body": body_img}
	for slot in gear:
		layers[slot] = _load_image(HUMAN_DIR + "%s_%d.png" % [slot, gear[slot]])
	for di in DIRS.size():
		var d: String = DIRS[di]
		var band := Rect2i(0, di * 4 * fh, COLS * fw, 4 * fh)
		for slot in ORDER[d]:
			var layer: Image = layers.get(slot)
			if layer != null:
				out.blend_rect(layer, band, band.position)
	_outline(out, fw, fh)
	return out

## 1px dark outline around each frame's silhouette (never across frame edges).
func _outline(img: Image, fw: int, fh: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx: int = x + o.x
				var yy: int = y + o.y
				if xx < 0 or yy < 0 or xx >= w or yy >= h:
					continue
				if xx / fw != x / fw or yy / fh != y / fh:
					continue
				if src.get_pixel(xx, yy).a > 0.0:
					img.set_pixel(x, y, OUTLINE)
					break

## A simple normal map: rounded at the silhouette edges, with a little relief from brightness.
func _normal_map(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var n := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var height := PackedFloat32Array()
	height.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			height[y * w + x] = c.a * (0.6 + c.get_luminance() * 0.4)
	for y in h:
		for x in w:
			var a := img.get_pixel(x, y).a
			if a <= 0.0:
				n.set_pixel(x, y, Color(0.5, 0.5, 1.0, 0.0))
				continue
			var hl := height[y * w + maxi(x - 1, 0)]
			var hr := height[y * w + mini(x + 1, w - 1)]
			var hu := height[maxi(y - 1, 0) * w + x]
			var hd := height[mini(y + 1, h - 1) * w + x]
			var v := Vector3(-(hr - hl) * 1.5, (hd - hu) * 1.5, 1.0).normalized()
			n.set_pixel(x, y, Color(v.x * 0.5 + 0.5, v.y * 0.5 + 0.5, v.z * 0.5 + 0.5, 1.0))
	return n

## Call every frame: picks direction and animation, and advances the frame.
func animate(facing: Vector2, moving: bool, crouching: bool, acting: bool, delta: float) -> void:
	var new_dir := dir
	if facing.length() > 0.01:
		if absf(facing.x) > absf(facing.y) * 1.1:
			new_dir = "right"
			_sprite.flip_h = facing.x < 0.0
		else:
			new_dir = "down" if facing.y > 0.0 else "up"
			_sprite.flip_h = false
	var new_anim := "act" if acting else ("crouch" if crouching else ("walk" if moving else "idle"))
	if new_anim != anim or new_dir != dir:
		_t = 0.0
	dir = new_dir
	anim = new_anim
	if not (anim == "crouch" and not moving):
		_t += delta
	_apply_frame()

func _apply_frame() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var row := DIRS.find(dir) * 4 + ANIMS.find(anim)
	var col: int = int(_t * float(FPS[anim])) % int(NFRAMES[anim])
	_sprite.frame = row * COLS + col

func set_tint(c: Color) -> void:
	if _sprite != null:
		_sprite.modulate = c

func set_lying(lying: bool) -> void:
	if _sprite != null:
		_sprite.rotation = PI * 0.5 if lying else 0.0
		_sprite.position = Vector2(0, -lift * (0.2 if lying else 1.0))
