class_name MapLoader
extends Node2D

## Loads and instantiates xTile map JSON exports in Godot 4.
## Constructs TileMapLayer child nodes for each map layer (Back, Buildings, Paths, Front, AlwaysFront, AlwaysFront2),
## loads referenced TileSheet textures, builds collision shapes for impassable tiles,
## and provides query APIs for diggability, passability, warps, and tile actions.

signal map_loaded(map_id: String)

const VANILLA_DATA_DIR: String = "user://vanilla_data/"
const DEFAULT_MAP_PATH: String = "user://vanilla_data/Maps/Farm.json"

@export var map_path: String = DEFAULT_MAP_PATH
@export var auto_load_on_ready: bool = true

var map_id: String = ""
var map_size: Vector2i = Vector2i.ZERO
var tile_size: Vector2i = Vector2i(16, 16)
var map_properties: Dictionary = {}

var tile_set: TileSet = null
var layers: Dictionary[String, TileMapLayer] = {}

var diggable_cells: Dictionary[Vector2i, bool] = {}
var impassable_cells: Dictionary[Vector2i, bool] = {}
var warps: Dictionary[Vector2i, Dictionary] = {}
var action_cells: Dictionary[Vector2i, String] = {}

var collision_body: StaticBody2D = null

func _ready() -> void:
	if auto_load_on_ready:
		if FileAccess.file_exists(map_path):
			load_map(map_path)
		else:
			print("[MapLoader] Map path '%s' not found on ready. Skipping auto-load." % map_path)

func load_map(file_path: String = "") -> bool:
	var target_path: String = file_path if not file_path.is_empty() else map_path
	if not FileAccess.file_exists(target_path):
		push_error("[MapLoader] Map file does not exist: %s" % target_path)
		return false

	var file: FileAccess = FileAccess.open(target_path, FileAccess.READ)
	if file == null:
		push_error("[MapLoader] Failed to open map file: %s (Error: %d)" % [target_path, FileAccess.get_open_error()])
		return false

	var json_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		push_error("[MapLoader] Invalid JSON in map file: %s" % target_path)
		return false

	var data: Dictionary = parsed as Dictionary
	var success: bool = _build_map_from_data(data)
	if success:
		map_loaded.emit(map_id)
	return success

func _build_map_from_data(data: Dictionary) -> bool:
	_cleanup_existing_map()

	map_id = data.get("id", "Map")
	map_size = Vector2i(data.get("width", 0), data.get("height", 0))
	tile_size = Vector2i(data.get("tile_width", 16), data.get("tile_height", 16))
	map_properties = data.get("properties", {})

	_parse_map_properties()

	# 1. Create TileSet and populate atlas sources
	tile_set = TileSet.new()
	tile_set.tile_size = tile_size

	var sheets_array: Array = data.get("tile_sheets", [])
	var sheet_to_source_id: Dictionary[String, int] = {}
	var sheet_cols: Dictionary[String, int] = {}
	var sheet_tile_props: Dictionary[String, Dictionary] = {}

	for i: int in range(sheets_array.size()):
		var s: Dictionary = sheets_array[i] as Dictionary
		var s_id: String = s.get("id", "")
		var s_rel_path: String = s.get("texture_path", "")
		var s_file_name: String = s.get("texture_file", "")
		var cols: int = s.get("width", 1)
		var t_props: Dictionary = s.get("tile_properties", {})

		sheet_to_source_id[s_id] = i
		sheet_cols[s_id] = cols
		sheet_tile_props[s_id] = t_props

		var tex: Texture2D = _load_texture(s_rel_path, s_file_name)
		if tex != null:
			var atlas_source: TileSetAtlasSource = TileSetAtlasSource.new()
			atlas_source.texture = tex
			atlas_source.texture_region_size = tile_size
			tile_set.add_source(atlas_source, i)
		else:
			push_warning("[MapLoader] Missing texture for sheet '%s'" % s_id)

	# 2. Instantiate TileMapLayer for each layer
	var layers_array: Array = data.get("layers", [])
	for l_dict: Dictionary in layers_array:
		var l_id: String = l_dict.get("id", "")
		var l_vis: bool = l_dict.get("visible", true)
		var tiles_array: Array = l_dict.get("tiles", [])

		var layer_node: TileMapLayer = TileMapLayer.new()
		layer_node.name = l_id
		layer_node.tile_set = tile_set
		layer_node.visible = l_vis
		layer_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer_node.collision_enabled = false # Physics handled via merged StaticBody2D

		match l_id:
			"Back":
				layer_node.z_index = 0
			"Paths":
				layer_node.z_index = 0
			"Buildings":
				layer_node.z_index = 1
			"Front":
				layer_node.z_index = 10
			"AlwaysFront", "AlwaysFront2":
				layer_node.z_index = 20
			_:
				layer_node.z_index = 0

		add_child(layer_node)
		layers[l_id] = layer_node

		for t: Dictionary in tiles_array:
			var cell := Vector2i(t.get("x", 0), t.get("y", 0))
			var s_id: String = t.get("sheet", "")
			var source_id: int = sheet_to_source_id.get(s_id, -1)
			if source_id < 0 or not tile_set.has_source(source_id):
				continue

			var t_idx: int = t.get("index", 0)
			var cols: int = sheet_cols.get(s_id, 1)
			var atlas_coords := Vector2i(t_idx % cols, t_idx / cols)

			var atlas_source: TileSetAtlasSource = tile_set.get_source(source_id) as TileSetAtlasSource
			if atlas_source != null and not atlas_source.has_tile(atlas_coords):
				atlas_source.create_tile(atlas_coords)

			layer_node.set_cell(cell, source_id, atlas_coords)

			# Collect tile properties
			var sheet_props_for_tile: Dictionary = sheet_tile_props.get(s_id, {}).get(str(t_idx), {})
			var tile_local_props: Dictionary = t.get("props", {})

			if tile_local_props.has("Action"):
				action_cells[cell] = String(tile_local_props["Action"])
			elif sheet_props_for_tile.has("Action"):
				action_cells[cell] = String(sheet_props_for_tile["Action"])

			if l_id == "Back":
				var dig_val = tile_local_props.get("Diggable", sheet_props_for_tile.get("Diggable", ""))
				if dig_val in ["T", "True", true, 1, "1"]:
					diggable_cells[cell] = true

			if l_id == "Buildings":
				var pass_val = tile_local_props.get("Passable", sheet_props_for_tile.get("Passable", ""))
				if not (pass_val in ["T", "True", true, 1, "1"]):
					impassable_cells[cell] = true

	# 3. Build merged static collision shapes for physics
	_build_collision_shapes()

	print("[MapLoader] Loaded map '%s' (%dx%d, %d layers, %d diggable tiles, %d impassable cells, %d warps)." % [
		map_id, map_size.x, map_size.y, layers.size(), diggable_cells.size(), impassable_cells.size(), warps.size()
	])
	return true

func _load_texture(tex_rel_path: String, tex_file_name: String) -> Texture2D:
	var possible_paths: Array[String] = [
		VANILLA_DATA_DIR.path_join(tex_rel_path),
		VANILLA_DATA_DIR.path_join("Maps").path_join(tex_file_name),
		VANILLA_DATA_DIR.path_join("TileSheets").path_join(tex_file_name),
	]

	for path: String in possible_paths:
		if FileAccess.file_exists(path):
			var abs_path: String = ProjectSettings.globalize_path(path)
			var img: Image = Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				return ImageTexture.create_from_image(img)

	push_warning("[MapLoader] Could not load texture for '%s' / '%s'" % [tex_rel_path, tex_file_name])
	return null

func _parse_map_properties() -> void:
	warps.clear()
	var warp_str: String = String(map_properties.get("Warp", "")).strip_edges()
	if warp_str.is_empty():
		return

	var parts: PackedStringArray = warp_str.split(" ", false)
	var i: int = 0
	while i + 4 < parts.size():
		var src_x: int = parts[i].to_int()
		var src_y: int = parts[i + 1].to_int()
		var target_map: String = parts[i + 2]
		var dst_x: int = parts[i + 3].to_int()
		var dst_y: int = parts[i + 4].to_int()

		warps[Vector2i(src_x, src_y)] = {
			"target_map": target_map,
			"target_coords": Vector2i(dst_x, dst_y)
		}
		i += 5

func _build_collision_shapes() -> void:
	if impassable_cells.is_empty():
		return

	collision_body = StaticBody2D.new()
	collision_body.name = "MapCollision"
	add_child(collision_body)

	# Group contiguous horizontal impassable cells into merged rectangles
	for y: int in range(map_size.y):
		var in_run: bool = false
		var x_start: int = 0
		for x: int in range(map_size.x):
			var cell := Vector2i(x, y)
			if impassable_cells.has(cell):
				if not in_run:
					in_run = true
					x_start = x
			else:
				if in_run:
					_create_rect_collision(x_start, y, x - x_start, 1)
					in_run = false
		if in_run:
			_create_rect_collision(x_start, y, map_size.x - x_start, 1)

func _create_rect_collision(x: int, y: int, w: int, h: int) -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	var size_vec := Vector2(w * tile_size.x, h * tile_size.y)
	shape.size = size_vec

	var col_shape := CollisionShape2D.new()
	col_shape.shape = shape
	col_shape.position = Vector2(
		x * tile_size.x + (size_vec.x / 2.0),
		y * tile_size.y + (size_vec.y / 2.0)
	)
	collision_body.add_child(col_shape)

func _cleanup_existing_map() -> void:
	for layer: TileMapLayer in layers.values():
		if is_instance_valid(layer):
			layer.queue_free()
	layers.clear()

	if is_instance_valid(collision_body):
		collision_body.queue_free()
		collision_body = null

	diggable_cells.clear()
	impassable_cells.clear()
	warps.clear()
	action_cells.clear()
	tile_set = null

func is_tile_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < map_size.x and cell.y >= 0 and cell.y < map_size.y

func is_tile_diggable(cell: Vector2i) -> bool:
	if not is_tile_in_bounds(cell):
		return false
	return diggable_cells.has(cell) and not impassable_cells.has(cell)

func is_tile_passable(cell: Vector2i) -> bool:
	if not is_tile_in_bounds(cell):
		return false
	return not impassable_cells.has(cell)

func get_warp(cell: Vector2i) -> Dictionary:
	return warps.get(cell, {})

func get_action(cell: Vector2i) -> String:
	return action_cells.get(cell, "")

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / float(tile_size.x))), int(floor(world_pos.y / float(tile_size.y))))

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * tile_size.x, cell.y * tile_size.y)

func cell_to_center_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * tile_size.x + (tile_size.x / 2.0), cell.y * tile_size.y + (tile_size.y / 2.0))
