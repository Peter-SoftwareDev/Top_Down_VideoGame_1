extends RefCounted
## Loads art and sound in a way that works even before Godot has imported new files.
##
## When the game runs from the editor, files are read straight from the project folder, so a
## fresh `git pull` works immediately (no waiting for, or forgetting, the import step).
## In an exported game the raw files aren't packed, so the normal imported resources are used.

static func exists(path: String) -> bool:
	return FileAccess.file_exists(path) or ResourceLoader.exists(path)

static func image(path: String) -> Image:
	if OS.has_feature("editor") and FileAccess.file_exists(path) and path.ends_with(".png"):
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			img.convert(Image.FORMAT_RGBA8)
			return img
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			var img := tex.get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			return img
	push_warning("Couldn't load image: " + path)
	return null

static func texture(path: String) -> Texture2D:
	if OS.has_feature("editor") and FileAccess.file_exists(path):
		var img := image(path)
		if img != null:
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			return tex
	push_warning("Couldn't load texture: " + path)
	return null

static func sound(path: String) -> AudioStream:
	if OS.has_feature("editor") and FileAccess.file_exists(path) and path.ends_with(".wav"):
		var wav := AudioStreamWAV.load_from_file(path)
		if wav != null:
			return wav
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null
