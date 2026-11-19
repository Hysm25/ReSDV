class_name ChestManager
extends Node2D

## Manages placed chests, persistence, validity checking, and placement/removal
## across all locations (Farm, FarmHouse, etc.).

@export var current_location_id: StringName = &"Farm"

# Structure: { location_id: { Vector2i(cell): Chest } }
var _chests: Dictionary[StringName, Dictionary] = {}


func _ready() -> void:
	if is_instance_valid(EventBus):
		EventBus.location_changed.connect(_on_location_changed)


func can_place_chest(loc: StringName, cell: Vector2i, map_loader: MapLoader = null, _farm_grid: FarmGrid = null, crop_manager: CropManager = null) -> bool:
	if has_chest_at(loc, cell):
		return false

	if map_loader != null and map_loader.map_size != Vector2i.ZERO:
		if cell.x < 0 or cell.x >= map_loader.map_size.x or cell.y < 0 or cell.y >= map_loader.map_size.y:
			return false
		if map_loader.is_cell_impassable(cell):
			return false

	if crop_manager != null and crop_manager.has_crop(cell):
		return false

	return true


func place_chest(loc: StringName, cell: Vector2i) -> Chest:
	if not _chests.has(loc):
		_chests[loc] = {}

	var chest: Chest = Chest.new(cell, loc)
	_chests[loc][cell] = chest
	add_child(chest)

	chest.visible = (loc == current_location_id)
	chest.process_mode = Node.PROCESS_MODE_INHERIT if (loc == current_location_id) else Node.PROCESS_MODE_DISABLED

	if is_instance_valid(EventBus):
		EventBus.chest_placed.emit(cell, chest)

	print("[ChestManager] Placed chest at %s in %s" % [str(cell), loc])
	return chest


func has_chest_at(loc: StringName, cell: Vector2i) -> bool:
	if _chests.has(loc):
		return _chests[loc].has(cell)
	return false


func get_chest_at(loc: StringName, cell: Vector2i) -> Chest:
	if _chests.has(loc):
		return _chests[loc].get(cell, null)
	return null


func get_all_chests_in(loc: StringName) -> Array[Chest]:
	var result: Array[Chest] = []
	if _chests.has(loc):
		for ch: Variant in _chests[loc].values():
			if ch is Chest:
				result.append(ch as Chest)
	return result


func try_pickup_chest(loc: StringName, cell: Vector2i, inv: InventoryManager = null) -> bool:
	var chest: Chest = get_chest_at(loc, cell)
	if chest == null:
		return false

	if not chest.is_empty():
		chest.shake()
		print("[ChestManager] Cannot pick up chest at %s: chest is not empty!" % str(cell))
		return false

	# Empty chest can be picked up
	_chests[loc].erase(cell)
	if inv != null:
		inv.add_item(&"vanilla:chest", 1)

	if is_instance_valid(EventBus):
		EventBus.chest_removed.emit(cell)

	print("[ChestManager] Picked up empty chest at %s in %s" % [str(cell), loc])
	chest.queue_free()
	return true


func _on_location_changed(_from_map: StringName, to_map: StringName, _target_cell: Vector2i) -> void:
	current_location_id = to_map
	for loc: StringName in _chests.keys():
		var is_active: bool = (loc == current_location_id)
		for cell_key: Vector2i in _chests[loc].keys():
			var ch: Chest = _chests[loc][cell_key]
			if is_instance_valid(ch):
				ch.visible = is_active
				ch.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED


func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for loc: StringName in _chests.keys():
		var loc_dict: Dictionary = {}
		for cell: Vector2i in _chests[loc].keys():
			var ch: Chest = _chests[loc][cell]
			if is_instance_valid(ch) and ch.container != null:
				loc_dict["%d,%d" % [cell.x, cell.y]] = ch.container.to_dict()
		result[String(loc)] = loc_dict
	return result
