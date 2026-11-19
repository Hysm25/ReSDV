class_name LocationManager
extends Node2D

## Manages game locations, active map rendering, physics collisions,
## and seamless warp transitions between locations (e.g., Farm <-> FarmHouse).

signal warp_started(from_map: StringName, to_map: StringName, target_cell: Vector2i)
signal warp_completed(from_map: StringName, to_map: StringName, target_cell: Vector2i)

const DEFAULT_MAP_PATHS: Dictionary[StringName, String] = {
	&"Farm": "user://vanilla_data/Maps/Farm.json",
	&"FarmHouse": "user://vanilla_data/Maps/FarmHouse.json",
}

@export var current_location_id: StringName = &"Farm"
@export var player: Player = null
@export var farm_grid: FarmGrid = null
@export var crop_manager: CropManager = null
@export var auto_initialize: bool = true

var locations: Dictionary[StringName, MapLoader] = {}
var _is_transitioning: bool = false
var _cooldown_timer: float = 0.0

func _ready() -> void:
	if auto_initialize:
		initialize_locations()

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		if _cooldown_timer < 0.0:
			_cooldown_timer = 0.0

func initialize_locations() -> void:
	# Adopt any pre-existing MapLoader children
	for child: Node in get_children():
		if child is MapLoader:
			var loc_key: StringName = StringName(child.map_id if not child.map_id.is_empty() else child.name)
			locations[loc_key] = child

	# Ensure default locations are loaded
	for loc_key: StringName in DEFAULT_MAP_PATHS.keys():
		_ensure_location_loaded(loc_key)

	_setup_default_warps()
	activate_location(current_location_id, Vector2i(-1, -1), false)

func _ensure_location_loaded(loc_id: StringName) -> bool:
	if locations.has(loc_id):
		return true

	# Check children by name
	for child: Node in get_children():
		if child is MapLoader and (child.name == String(loc_id) or child.map_id == String(loc_id)):
			locations[loc_id] = child
			return true

	var map_path: String = DEFAULT_MAP_PATHS.get(loc_id, "")
	if map_path.is_empty() or not FileAccess.file_exists(map_path):
		push_warning("[LocationManager] Map file not found for location: %s (%s)" % [String(loc_id), map_path])
		return false

	var loader: MapLoader = MapLoader.new()
	loader.name = String(loc_id)
	loader.auto_load_on_ready = false
	add_child(loader)

	var ok: bool = loader.load_map(map_path)
	if not ok:
		push_error("[LocationManager] Failed to load map for location: %s" % String(loc_id))
		loader.queue_free()
		return false

	locations[loc_id] = loader
	return true

func _setup_default_warps() -> void:
	# 1. Farm -> FarmHouse doorway at (64, 14) landing inside at (3, 11)
	var farm_loader: MapLoader = locations.get(&"Farm")
	if farm_loader != null:
		farm_loader.add_warp(Vector2i(64, 14), &"FarmHouse", Vector2i(3, 11))

	# 2. FarmHouse -> Farm exit doorway at (3, 12) landing outside on porch at (64, 15)
	var fh_loader: MapLoader = locations.get(&"FarmHouse")
	if fh_loader != null:
		if not fh_loader.has_warp(Vector2i(3, 12)):
			fh_loader.add_warp(Vector2i(3, 12), &"Farm", Vector2i(64, 15))

func activate_location(loc_id: StringName, target_cell: Vector2i = Vector2i(-1, -1), emit_signals: bool = true) -> bool:
	if not locations.has(loc_id):
		var loaded: bool = _ensure_location_loaded(loc_id)
		if not loaded:
			push_error("[LocationManager] Location '%s' cannot be activated (not loaded)." % String(loc_id))
			return false

	var from_map: StringName = current_location_id
	current_location_id = loc_id

	# 1. Update map visibility and physics collision
	for name_key: StringName in locations.keys():
		var loader: MapLoader = locations[name_key]
		var is_active: bool = (name_key == loc_id)
		loader.visible = is_active
		if loader.collision_body != null:
			loader.collision_body.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED

	var active_loader: MapLoader = locations[loc_id]

	# 2. Update FarmGrid & CropManager state visibility
	var is_farm: bool = (loc_id == &"Farm")
	if farm_grid != null:
		farm_grid.visible = is_farm
		farm_grid.process_mode = Node.PROCESS_MODE_INHERIT if is_farm else Node.PROCESS_MODE_DISABLED
		if is_farm:
			farm_grid.map_loader = active_loader
			farm_grid._sync_with_map_loader()

	if crop_manager != null:
		crop_manager.visible = is_farm
		crop_manager.process_mode = Node.PROCESS_MODE_INHERIT if is_farm else Node.PROCESS_MODE_DISABLED
		if is_farm and farm_grid != null:
			crop_manager.farm_grid = farm_grid

	# 3. Position Player and update Camera2D limits
	if player != null:
		player.location_manager = self
		player.map_loader = active_loader
		if target_cell != Vector2i(-1, -1):
			player.global_position = active_loader.cell_to_center_world(target_cell)
		elif is_farm:
			player.global_position = active_loader.cell_to_center_world(Vector2i(64, 15))
		else:
			player.global_position = active_loader.cell_to_center_world(Vector2i(active_loader.map_size.x / 2, active_loader.map_size.y / 2))

		# Set intuitive initial facing direction
		if loc_id == &"FarmHouse":
			player.facing_direction = Vector2i.UP
		elif loc_id == &"Farm" and target_cell == Vector2i(64, 15):
			player.facing_direction = Vector2i.DOWN

		player._apply_map_setup()

	# 4. Debounce and notification
	_is_transitioning = false

	if emit_signals:
		_cooldown_timer = 0.3
		warp_completed.emit(from_map, loc_id, target_cell)
		EventBus.location_changed.emit(from_map, loc_id, target_cell)
		print("[LocationManager] Location changed: '%s' -> '%s' (Landing cell: %s)" % [from_map, loc_id, str(target_cell)])
	else:
		_cooldown_timer = 0.0

	return true

func warp_to(to_map: StringName, target_cell: Vector2i) -> bool:
	if _is_transitioning or _cooldown_timer > 0.0:
		return false

	_is_transitioning = true
	warp_started.emit(current_location_id, to_map, target_cell)
	return activate_location(to_map, target_cell, true)

func check_and_trigger_warp(cell: Vector2i, facing: Vector2i = Vector2i.ZERO) -> bool:
	if _is_transitioning or _cooldown_timer > 0.0:
		return false

	var cur_loader: MapLoader = get_current_map_loader()
	if cur_loader == null:
		return false

	var warp_info: Dictionary = cur_loader.get_warp(cell)

	# Special cases for doorway tiles
	if warp_info.is_empty():
		if current_location_id == &"FarmHouse" and cell == Vector2i(3, 11) and facing == Vector2i.DOWN:
			warp_info = cur_loader.get_warp(Vector2i(3, 12))
		elif facing != Vector2i.ZERO and cur_loader.has_warp(cell + facing):
			warp_info = cur_loader.get_warp(cell + facing)

	if warp_info.is_empty():
		return false

	var target_map_str: String = String(warp_info.get("target_map", ""))
	if target_map_str.is_empty():
		return false

	var target_map: StringName = StringName(target_map_str)
	var target_coords: Vector2i = warp_info.get("target_coords", Vector2i(-1, -1))

	return warp_to(target_map, target_coords)

func get_current_map_loader() -> MapLoader:
	return locations.get(current_location_id)

func get_map_loader(loc_id: StringName) -> MapLoader:
	return locations.get(loc_id)

func is_current_location(loc_id: StringName) -> bool:
	return current_location_id == loc_id

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var loader: MapLoader = get_current_map_loader()
	if loader != null:
		return loader.world_to_cell(world_pos)
	return Vector2i(int(floor(world_pos.x / 16.0)), int(floor(world_pos.y / 16.0)))

func cell_to_world(cell: Vector2i) -> Vector2:
	var loader: MapLoader = get_current_map_loader()
	if loader != null:
		return loader.cell_to_world(cell)
	return Vector2(cell.x * 16.0, cell.y * 16.0)

func cell_to_center_world(cell: Vector2i) -> Vector2:
	var loader: MapLoader = get_current_map_loader()
	if loader != null:
		return loader.cell_to_center_world(cell)
	return Vector2(cell.x * 16.0 + 8.0, cell.y * 16.0 + 8.0)
