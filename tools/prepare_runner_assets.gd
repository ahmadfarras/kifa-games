extends SceneTree

## Turns the raw Runner art into small, game-ready textures. Raw packs stay in git but are hidden from
## Godot by .gdignore, so they are never imported or exported.
## Run from the project root:  godot --headless -s tools/prepare_runner_assets.gd

const PACK := "res://assets/runner/backgrounds/parallax_saturated_background_pack/"
const RAW_OBSTACLES := "res://assets/runner/backgrounds/obstacle/"
const OUT_LAYERS := "res://assets/runner/backgrounds/layers/"
const OUT_TREES := "res://assets/runner/backgrounds/trees/"
const OUT_DECORATIONS := "res://assets/runner/backgrounds/decorations/"
const OUT_OBSTACLES := "res://assets/runner/obstacles/"
const RAW_CHARACTERS := "res://assets/runner/characters/raw/"
const OUT_CHARACTERS := "res://assets/runner/characters/"

## Background layers are drawn at half their source size (source is 2048x1546).
const LAYER_SCALE := 0.5
## Source rows: where the flat sand under the trees starts, and where the foreground ground starts.
const SAND_TOP := 1154
const GROUND_TOP := 1204
const SAND_COLOR := Color8(251, 223, 173)

## Layer name -> [source files back to front, first row, end row]. Rows from "end" down are always covered
## by a nearer layer that is fully opaque across the whole width, so they are cropped away.
const LAYERS := {
	"clouds": [["10_distant_clouds.png", "09_distant_clouds1.png", "08_clouds.png"], 28, 397],
	"huge_clouds": [["07_huge_clouds.png"], 416, 861],
	"hills": [["06_hill2.png", "05_hill1.png"], 675, 1077],
	"far_trees": [["04_bushes.png", "03_distant_trees.png"], 831, SAND_TOP],
	"ground": [["01_ground.png"], GROUND_TOP, 1546],
}
## Every character is scaled so its standing (idle) body is this many pixels tall: same size and sharpness for all.
const BODY_HEIGHT := 193
## Keeps sprite sheets within the texture size every target GPU supports.
const MAX_SHEET_WIDTH := 2048
## Character -> raw frame prefix -> [animation, fps, loop]. Raw "Walk" frames are not used by the game.
## Pick fps so animations take the same time for every character (e.g. run cycle ~0.7 s).
const CHARACTERS := {
	"little_girl": {
		"Idle": ["idle", 20.0, true], "Run": ["run", 30.0, true], "Jump": ["jump", 30.0, false], "Dead": ["dead", 30.0, false],
	},
	"little_boy": {
		"Idle": ["idle", 20.0, true], "Run": ["run", 22.0, true], "Jump": ["jump", 30.0, false], "Dead": ["dead", 15.0, false],
	},
}
# "tiny grass.png" is left out: its loose blades look like they float above the ground.
const DECORATIONS := {
	"grass01.png": "grass_01.png",
	"grass02.png": "grass_02.png",
	"grass03.png": "grass_03.png",
	"grass04.png": "grass_04.png",
	"grass05.png": "grass_05.png",
	"grass06.png": "grass_06.png",
	"grass07.png": "grass_07.png",
	"grass08.png": "grass_08.png",
	"grass09.png": "grass_09.png",
	"flower01.png": "flower_01.png",
	"flower2 copy.png": "flower_02.png",
	"flowers copy.png": "flower_03.png",
}
# stone03/stone05 are pebble-sized: too small to see as an obstacle, so they are left out.
const OBSTACLES := {
	"mushroom01.png": "mushroom_01.png",
	"mushroom02.png": "mushroom_02.png",
	"mushroom03.png": "mushroom_03.png",
	"mushroom04.png": "mushroom_04.png",
	"mushroom05.png": "mushroom_05.png",
	"mushroom06.png": "mushroom_06.png",
	"spikes.png": "spikes_01.png",
	"spikes02.png": "spikes_02.png",
	"spikes and grass.png": "spikes_03.png",
	"stone01.png": "stone_01.png",
	"stone02.png": "stone_02.png",
	"stone04.png": "stone_04.png",
	"stone06.png": "stone_06.png",
}


func _init() -> void:
	for dir in [OUT_LAYERS, OUT_TREES, OUT_DECORATIONS, OUT_OBSTACLES]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for layer_name: String in LAYERS:
		_build_layer(layer_name, LAYERS[layer_name])
	_build_trees()
	_crop_all(DECORATIONS, PACK, OUT_DECORATIONS)
	_crop_all(OBSTACLES, RAW_OBSTACLES, OUT_OBSTACLES)
	for character: String in CHARACTERS:
		_build_character(character, CHARACTERS[character])
	quit()


func _build_layer(layer_name: String, spec: Array) -> void:
	var first: int = spec[1]
	var end: int = spec[2]
	var merged: Image = null
	for file: String in spec[0]:
		var image := _load(PACK + file)
		var rows := Rect2i(0, first, image.get_width(), end - first)
		if merged == null:
			merged = image.get_region(rows)
		else:
			merged.blend_rect(image, rows, Vector2i.ZERO)
	_save(merged, OUT_LAYERS + layer_name + ".png", LAYER_SCALE)


func _build_trees() -> void:
	var image := _load(PACK + "02_trees and bushes.png").get_region(Rect2i(0, 0, 2048, GROUND_TOP))
	# The game draws the flat sand as a plain band; keep only trees, bushes and their shadows.
	for y in range(SAND_TOP, GROUND_TOP):
		for x in image.get_width():
			if image.get_pixel(x, y).is_equal_approx(SAND_COLOR):
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	var count := 0
	for columns in _column_runs(image):
		var cluster := image.get_region(Rect2i(columns.x, 0, columns.y - columns.x, GROUND_TOP))
		var top := cluster.get_used_rect().position.y
		count += 1
		# Keep the bottom at GROUND_TOP so every tree is placed with its bottom on the ground line.
		_save(cluster.get_region(Rect2i(0, top, cluster.get_width(), GROUND_TOP - top)), OUT_TREES + "tree_%02d.png" % count, LAYER_SCALE)


## Writes one sprite sheet per animation plus a SpriteFrames .tres whose frames are AtlasTextures.
## Each frame is cropped to its own visible pixels and packed tightly (rows, left to right); the AtlasTexture
## margin restores the animation's common frame box (the union of all its frames), so frames stay aligned.
## metadata/bodies stores each animation's first-frame visible rect inside that box, which RunnerSprite uses
## to size and anchor (feet) the character without reading pixels at runtime.
func _build_character(character: String, animations: Dictionary) -> void:
	var raw_dir := RAW_CHARACTERS + character + "/"
	var out_dir := OUT_CHARACTERS + character + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var scale := float(BODY_HEIGHT) / _load(raw_dir + "Idle (1).png").get_used_rect().size.y
	var ext := PackedStringArray()
	var subs := PackedStringArray()
	var entries := PackedStringArray()
	var bodies := PackedStringArray()
	for prefix: String in animations:
		var spec: Array = animations[prefix]
		var animation: String = spec[0]
		var frames := _load_frames(raw_dir, prefix, scale)
		var used: Array[Rect2i] = []
		var box := frames[0].get_used_rect()
		for frame in frames:
			used.append(frame.get_used_rect())
			box = box.merge(used[-1])
		var spots := _pack(used)
		var sheet := Image.create_empty(spots[-1].x, spots[-1].y, false, Image.FORMAT_RGBA8)
		var frame_refs := PackedStringArray()
		for i in frames.size():
			var at := Vector2i(spots[i].x, spots[i].y)
			sheet.blit_rect(frames[i], used[i], at)
			var id := "%s_%d" % [animation, i]
			var inset := used[i].position - box.position
			subs.append('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("%s")\nregion = Rect2(%d, %d, %d, %d)\nmargin = Rect2(%d, %d, %d, %d)\n' % [
				id, animation, at.x, at.y, used[i].size.x, used[i].size.y,
				inset.x, inset.y, box.size.x - used[i].size.x, box.size.y - used[i].size.y])
			frame_refs.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % id)
		var body := used[0]
		bodies.append('&"%s": Rect2i(%d, %d, %d, %d)' % [animation, body.position.x - box.position.x, body.position.y - box.position.y, body.size.x, body.size.y])
		_save(sheet, out_dir + animation + ".png", 1.0)
		ext.append('[ext_resource type="Texture2D" path="%s" id="%s"]' % [out_dir + animation + ".png", animation])
		entries.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % [", ".join(frame_refs), str(spec[2]).to_lower(), animation, spec[1]])
	var text := '[gd_resource type="SpriteFrames" format=3]\n\n%s\n\n%s\n[resource]\nmetadata/bodies = {%s}\nanimations = [%s]\n' % [
		"\n".join(ext), "\n".join(subs), ", ".join(bodies), ", ".join(entries)]
	var file := FileAccess.open(ProjectSettings.globalize_path(OUT_CHARACTERS + character + ".tres"), FileAccess.WRITE)
	file.store_string(text)
	print("%s%s.tres" % [OUT_CHARACTERS, character])


## Shelf packing: places rects left to right in rows no wider than MAX_SHEET_WIDTH.
## Returns each rect's top-left corner, followed by the total sheet size as the last element.
func _pack(rects: Array[Rect2i]) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	var cursor := Vector2i.ZERO
	var row_height := 0
	var width := 0
	for rect in rects:
		if cursor.x + rect.size.x > MAX_SHEET_WIDTH:
			cursor = Vector2i(0, cursor.y + row_height)
			row_height = 0
		spots.append(cursor)
		cursor.x += rect.size.x
		width = maxi(width, cursor.x)
		row_height = maxi(row_height, rect.size.y)
	spots.append(Vector2i(width, cursor.y + row_height))
	return spots


func _load_frames(raw_dir: String, prefix: String, scale: float) -> Array[Image]:
	var frames: Array[Image] = []
	var path := "%s%s (%d).png" % [raw_dir, prefix, 1]
	while FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		var image := _load(path)
		image.fix_alpha_edges()
		image.resize(roundi(image.get_width() * scale), roundi(image.get_height() * scale), Image.INTERPOLATE_LANCZOS)
		assert(frames.is_empty() or image.get_size() == frames[0].get_size(), "frames of %s differ in size" % prefix)
		frames.append(image)
		path = "%s%s (%d).png" % [raw_dir, prefix, frames.size() + 1]
	return frames


func _column_runs(image: Image) -> Array[Vector2i]:
	var runs: Array[Vector2i] = []
	var start := -1
	for x in image.get_width() + 1:
		var filled := x < image.get_width() and not image.get_region(Rect2i(x, 0, 1, image.get_height())).is_invisible()
		if filled and start < 0:
			start = x
		elif not filled and start >= 0:
			runs.append(Vector2i(start, x))
			start = -1
	return runs


func _crop_all(names: Dictionary, source_dir: String, out_dir: String) -> void:
	for source: String in names:
		var image := _load(source_dir + source)
		_save(image.get_region(image.get_used_rect()), out_dir + names[source], 1.0)


func _load(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_RGBA8)
	return image


func _save(image: Image, path: String, scale: float) -> void:
	# Spread edge colors into transparent pixels so scaling/filtering doesn't create dark fringes.
	image.fix_alpha_edges()
	if scale != 1.0:
		image.resize(roundi(image.get_width() * scale), roundi(image.get_height() * scale), Image.INTERPOLATE_LANCZOS)
	image.save_png(ProjectSettings.globalize_path(path))
	print("%s %s" % [path, image.get_size()])
