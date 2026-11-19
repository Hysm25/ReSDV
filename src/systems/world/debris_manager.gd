class_name DebrisManager
extends Node2D

## World debris and foraging manager for ReSDV.
## Coordinates Twigs, Stones, Weeds, Wild Grass, and Seasonal Forageables across locations.
## Handles tool harvesting, stamina consumption, audio dispatch, and tile blocking.
## Strictly typed GDScript.

@export var current_location_id: StringName = &"Farm"

# Storage: location_id -> { Vector2i: DebrisObject }
var _debris: Dictionary[StringName, Dictionary] = {}


func _ready() -> void:
	z_index = 2
	y_sort_enabled = true
	if is_instance_valid(EventBus):
		EventBus.location_changed.connect(_on_location_changed)


func has_debris_at(loc: StringName, cell: Vector2i) -> bool:
	if _debris.has(loc):
		return _debris[loc].has(cell)
	return false


func get_debris_at(loc: StringName, cell: Vector2i) -> DebrisObject:
	if _debris.has(loc):
		return _debris[loc].get(cell, null) as DebrisObject
	return null


func is_obstacle_at(loc: StringName, cell: Vector2i) -> bool:
	var obj: DebrisObject = get_debris_at(loc, cell)
	if obj != null:
		return obj.is_obstacle
	return false


func get_all_debris_in(loc: StringName) -> Array[DebrisObject]:
	var result: Array[DebrisObject] = []
	if _debris.has(loc):
		for obj: Variant in _debris[loc].values():
			if obj is DebrisObject:
				result.append(obj as DebrisObject)
	return result


func spawn_debris(
	loc: StringName,
	cell: Vector2i,
	type: DebrisObject.DebrisType,
	sprite_idx: int = -1,
	item_id: StringName = &"",
	yield_id: StringName = &"",
	yield_count: int = 1
) -> DebrisObject:
	if not _debris.has(loc):
		_debris[loc] = {}

	# If there's already debris at this cell, remove it first
	if _debris[loc].has(cell):
		var old_obj: DebrisObject = _debris[loc][cell] as DebrisObject
		if is_instance_valid(old_obj):
			old_obj.queue_free()
		_debris[loc].erase(cell)

	var obj: DebrisObject = DebrisObject.new(cell, loc, type, sprite_idx, item_id, yield_id, yield_count)
	_debris[loc][cell] = obj
	add_child(obj)
	obj.update_position()
	obj.z_index = 2

	var is_active: bool = (loc == current_location_id)
	obj.visible = is_active
	obj.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED

	return obj


func spawn_twig(loc: StringName, cell: Vector2i, sprite_idx: int = 294) -> DebrisObject:
	return spawn_debris(loc, cell, DebrisObject.DebrisType.TWIG, sprite_idx, &"vanilla:294", &"vanilla:388", 1)


func spawn_stone(loc: StringName, cell: Vector2i, sprite_idx: int = 32) -> DebrisObject:
	return spawn_debris(loc, cell, DebrisObject.DebrisType.STONE, sprite_idx, &"vanilla:32", &"vanilla:390", 1)


func spawn_weed(loc: StringName, cell: Vector2i, sprite_idx: int = 0) -> DebrisObject:
	return spawn_debris(loc, cell, DebrisObject.DebrisType.WEED, sprite_idx, &"vanilla:0", &"vanilla:771", 1)


func spawn_grass(loc: StringName, cell: Vector2i, variation: int = 0) -> DebrisObject:
	return spawn_debris(loc, cell, DebrisObject.DebrisType.GRASS, variation, &"", &"vanilla:178", 1)


func spawn_forage(loc: StringName, cell: Vector2i, forage_id: StringName) -> DebrisObject:
	var namespaced_id: StringName = ContentRegistry.ensure_namespaced(forage_id) if is_instance_valid(ContentRegistry) else forage_id
	var sprite_idx: int = 18 # Daffodil default
	var item_data: ItemData = ContentRegistry.get_item(namespaced_id) if is_instance_valid(ContentRegistry) else null
	if item_data != null and item_data.sprite_index >= 0:
		sprite_idx = item_data.sprite_index
	else:
		# Fallback mapping for common forageables
		var clean_name: String = String(namespaced_id).replace("vanilla:", "")
		match clean_name:
			"16": sprite_idx = 16 # Wild Horseradish
			"18": sprite_idx = 18 # Daffodil
			"20": sprite_idx = 20 # Leek
			"22": sprite_idx = 22 # Dandelion

	return spawn_debris(loc, cell, DebrisObject.DebrisType.FORAGE, sprite_idx, namespaced_id, namespaced_id, 1)


func remove_debris(loc: StringName, cell: Vector2i) -> bool:
	if not _debris.has(loc) or not _debris[loc].has(cell):
		return false
	var obj: DebrisObject = _debris[loc][cell] as DebrisObject
	_debris[loc].erase(cell)
	if is_instance_valid(obj):
		obj.queue_free()
	return true


func pickup_forage(loc: StringName, cell: Vector2i, inv: InventoryManager = null) -> bool:
	var obj: DebrisObject = get_debris_at(loc, cell)
	if obj == null or not obj.is_forage():
		return false

	var f_id: StringName = obj.item_id
	var count: int = obj.yield_count

	if inv != null and not f_id.is_empty():
		inv.add_item(f_id, count)

	_debris[loc].erase(cell)
	if is_instance_valid(EventBus):
		EventBus.forage_collected.emit(loc, cell, f_id, count)

	print("[DebrisManager] Picked up forage %s x%d at %s in %s" % [f_id, count, str(cell), loc])
	obj.queue_free()
	return true


func hit_debris(
	loc: StringName,
	cell: Vector2i,
	tool_id: StringName,
	inv: InventoryManager = null,
	energy: EnergyManager = null
) -> bool:
	var obj: DebrisObject = get_debris_at(loc, cell)
	if obj == null:
		return false

	if obj.is_forage():
		obj.shake()
		return false

	if obj.can_be_hit_by(tool_id):
		if energy != null:
			energy.consume_tool_energy(tool_id)

		obj.health -= 1
		if obj.health <= 0:
			var debris_type_int: int = int(obj.debris_type)
			var y_id: StringName = obj.yield_item_id
			var y_cnt: int = obj.yield_count

			# Wild grass hay yield: 50% chance in vanilla SDV
			if obj.debris_type == DebrisObject.DebrisType.GRASS:
				if randf() > 0.5:
					y_cnt = 0

			if inv != null and y_cnt > 0 and not y_id.is_empty():
				inv.add_item(y_id, y_cnt)

			_debris[loc].erase(cell)
			if is_instance_valid(EventBus):
				EventBus.debris_cleared.emit(loc, cell, debris_type_int, y_id, y_cnt)

			print("[DebrisManager] Cleared %s at %s in %s (Yield: %s x%d)" % [
				DebrisObject.DebrisType.keys()[debris_type_int],
				str(cell),
				loc,
				y_id,
				y_cnt
			])
			obj.queue_free()
			return true
		else:
			obj.shake()
			return true
	else:
		# Ineffective tool: consume energy, shake object
		if energy != null:
			energy.consume_tool_energy(tool_id)
		obj.shake()
		print("[DebrisManager] Ineffective tool %s on %s at %s" % [
			tool_id,
			DebrisObject.DebrisType.keys()[int(obj.debris_type)],
			str(cell)
		])
		return false


func spawn_initial_farm_debris(_map_loader: MapLoader = null) -> void:
	# Spawns starter debris across the Farm in open diggable spots
	# Weeds
	spawn_weed(&"Farm", Vector2i(60, 18), 0)
	spawn_weed(&"Farm", Vector2i(61, 18), 313)
	spawn_weed(&"Farm", Vector2i(60, 19), 314)
	spawn_weed(&"Farm", Vector2i(65, 20), 315)
	spawn_weed(&"Farm", Vector2i(66, 21), 0)
	spawn_weed(&"Farm", Vector2i(68, 17), 313)

	# Twigs
	spawn_twig(&"Farm", Vector2i(59, 17), 294)
	spawn_twig(&"Farm", Vector2i(62, 19), 295)
	spawn_twig(&"Farm", Vector2i(66, 18), 294)
	spawn_twig(&"Farm", Vector2i(67, 22), 295)

	# Stones
	spawn_stone(&"Farm", Vector2i(61, 17), 32)
	spawn_stone(&"Farm", Vector2i(58, 19), 34)
	spawn_stone(&"Farm", Vector2i(67, 19), 343)
	spawn_stone(&"Farm", Vector2i(63, 22), 32)

	# Wild Grass
	spawn_grass(&"Farm", Vector2i(55, 17), 0)
	spawn_grass(&"Farm", Vector2i(56, 17), 1)
	spawn_grass(&"Farm", Vector2i(55, 18), 2)
	spawn_grass(&"Farm", Vector2i(56, 18), 3)
	spawn_grass(&"Farm", Vector2i(70, 19), 0)
	spawn_grass(&"Farm", Vector2i(70, 20), 1)

	# Spring Forageables
	spawn_forage(&"Farm", Vector2i(63, 16), &"vanilla:16") # Wild Horseradish
	spawn_forage(&"Farm", Vector2i(66, 16), &"vanilla:18") # Daffodil
	spawn_forage(&"Farm", Vector2i(58, 20), &"vanilla:22") # Dandelion
	spawn_forage(&"Farm", Vector2i(69, 18), &"vanilla:20") # Leek

	print("[DebrisManager] Initial farm debris and forage spawned successfully.")


func _on_location_changed(_from_map: StringName, to_map: StringName, _target_cell: Vector2i) -> void:
	current_location_id = to_map
	for loc: StringName in _debris.keys():
		var is_active: bool = (loc == current_location_id)
		for cell_key: Vector2i in _debris[loc].keys():
			var obj: DebrisObject = _debris[loc][cell_key] as DebrisObject
			if is_instance_valid(obj):
				obj.visible = is_active
				obj.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED


func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for loc: StringName in _debris.keys():
		var loc_list: Array = []
		for cell: Vector2i in _debris[loc].keys():
			var obj: DebrisObject = _debris[loc][cell] as DebrisObject
			if is_instance_valid(obj):
				loc_list.append(obj.to_dict())
		result[String(loc)] = loc_list
	return result


func load_from_dict(data: Dictionary) -> void:
	# Clear existing debris
	for loc: StringName in _debris.keys():
		for cell: Vector2i in _debris[loc].keys():
			var obj: DebrisObject = _debris[loc][cell] as DebrisObject
			if is_instance_valid(obj):
				obj.queue_free()
	_debris.clear()

	for loc_str: String in data.keys():
		var loc: StringName = StringName(loc_str)
		_debris[loc] = {}
		var loc_list: Array = data[loc_str] as Array
		for obj_data: Variant in loc_list:
			if obj_data is Dictionary:
				var obj: DebrisObject = DebrisObject.from_dict(obj_data as Dictionary, loc)
				_debris[loc][obj.cell] = obj
				add_child(obj)
				obj.update_position()
				obj.z_index = 2
				var is_active: bool = (loc == current_location_id)
				obj.visible = is_active
				obj.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED
