extends Node

## Central data registry for ReSDV.
## Ingests vanilla data directly from user://vanilla_data/ under the vanilla:* namespace.
## Adheres to strict static typing standards.

const VANILLA_DATA_DIR: String = "user://vanilla_data/"
const DEFAULT_NAMESPACE: String = "vanilla"

var _items: Dictionary[StringName, ItemData] = {}
var _crops: Dictionary[StringName, CropData] = {}
var _springobjects_texture: Texture2D = null
var _tools_texture: Texture2D = null
var _icon_cache: Dictionary[StringName, AtlasTexture] = {}

func _ready() -> void:
	load_vanilla_data()

func ensure_namespaced(id: StringName, default_namespace: String = DEFAULT_NAMESPACE) -> StringName:
	var id_str: String = String(id)
	if id_str.is_empty():
		return &""
	if id_str.contains(":"):
		return id
	return StringName(default_namespace + ":" + id_str)

# --- Item Registry ---

func register_item(id: StringName, item: ItemData) -> bool:
	if item == null:
		push_error("[ContentRegistry] Failed to register null ItemData for id: %s" % id)
		return false
	var namespaced_id: StringName = ensure_namespaced(id)
	item.id = namespaced_id
	_items[namespaced_id] = item
	EventBus.content_registered.emit(&"item", namespaced_id)
	return true

func get_item(id: StringName) -> ItemData:
	var namespaced_id: StringName = ensure_namespaced(id)
	return _items.get(namespaced_id, null)

func has_item(id: StringName) -> bool:
	var namespaced_id: StringName = ensure_namespaced(id)
	return _items.has(namespaced_id)

func get_all_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item: ItemData in _items.values():
		result.append(item)
	return result

func get_springobjects_texture() -> Texture2D:
	if _springobjects_texture == null:
		var path: String = VANILLA_DATA_DIR.path_join("Maps/springobjects.png")
		if FileAccess.file_exists(path):
			var abs_path: String = ProjectSettings.globalize_path(path)
			var img: Image = Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				_springobjects_texture = ImageTexture.create_from_image(img)
	return _springobjects_texture

func get_tools_texture() -> Texture2D:
	if _tools_texture == null:
		var path: String = VANILLA_DATA_DIR.path_join("TileSheets/tools.png")
		if FileAccess.file_exists(path):
			var abs_path: String = ProjectSettings.globalize_path(path)
			var img: Image = Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				_tools_texture = ImageTexture.create_from_image(img)
	return _tools_texture

func get_item_icon(id: StringName) -> AtlasTexture:
	var namespaced_id: StringName = ensure_namespaced(id)
	if _icon_cache.has(namespaced_id):
		return _icon_cache[namespaced_id]

	var item: ItemData = get_item(namespaced_id)
	if item == null:
		return null

	var is_tool: bool = item.category == ItemData.Category.TOOL or item.texture_path.contains("tools")
	var base_tex: Texture2D = get_tools_texture() if is_tool else get_springobjects_texture()
	if base_tex == null:
		return null

	var cols: int = 21 if is_tool else 24
	var idx: int = item.sprite_index if item.sprite_index >= 0 else 0
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = base_tex
	atlas.region = Rect2((idx % cols) * 16, (idx / cols) * 16, 16, 16)
	atlas.filter_clip = true

	_icon_cache[namespaced_id] = atlas
	return atlas

# --- Crop Registry ---

func register_crop(id: StringName, crop: CropData) -> bool:
	if crop == null:
		push_error("[ContentRegistry] Failed to register null CropData for id: %s" % id)
		return false
	var namespaced_id: StringName = ensure_namespaced(id)
	crop.id = namespaced_id
	if not crop.seed_item_id.is_empty():
		crop.seed_item_id = ensure_namespaced(crop.seed_item_id)
	if not crop.harvest_item_id.is_empty():
		crop.harvest_item_id = ensure_namespaced(crop.harvest_item_id)
	_crops[namespaced_id] = crop
	EventBus.content_registered.emit(&"crop", namespaced_id)
	return true

func get_crop(id: StringName) -> CropData:
	var namespaced_id: StringName = ensure_namespaced(id)
	return _crops.get(namespaced_id, null)

func has_crop(id: StringName) -> bool:
	var namespaced_id: StringName = ensure_namespaced(id)
	return _crops.has(namespaced_id)

func get_all_crops() -> Array[CropData]:
	var result: Array[CropData] = []
	for crop: CropData in _crops.values():
		result.append(crop)
	return result

# --- Vanilla Ingestion Pipeline ---

func load_vanilla_data() -> void:
	EventBus.content_loading_started.emit()
	
	if not DirAccess.dir_exists_absolute(VANILLA_DATA_DIR):
		print("[ContentRegistry] Vanilla data directory not found at '%s'. Extraction needed." % VANILLA_DATA_DIR)
		EventBus.content_loading_finished.emit(0, 0)
		return

	print("[ContentRegistry] Ingesting vanilla data from '%s'..." % VANILLA_DATA_DIR)
	var loaded_items: int = 0
	var loaded_crops: int = 0

	# Attempt loading items from JSON
	var items_json_path: String = VANILLA_DATA_DIR.path_join("Objects.json")
	if not FileAccess.file_exists(items_json_path):
		items_json_path = VANILLA_DATA_DIR.path_join("Data/Objects.json")
	if not FileAccess.file_exists(items_json_path):
		items_json_path = VANILLA_DATA_DIR.path_join("items.json")
	if FileAccess.file_exists(items_json_path):
		loaded_items = load_items_from_json_file(items_json_path)

	# Attempt loading crops from JSON
	var crops_json_path: String = VANILLA_DATA_DIR.path_join("Crops.json")
	if not FileAccess.file_exists(crops_json_path):
		crops_json_path = VANILLA_DATA_DIR.path_join("Data/Crops.json")
	if not FileAccess.file_exists(crops_json_path):
		crops_json_path = VANILLA_DATA_DIR.path_join("crops.json")
	if FileAccess.file_exists(crops_json_path):
		loaded_crops = load_crops_from_json_file(crops_json_path)

	# Ensure default tools are registered with authentic sprite indices
	register_default_tools()

	print("[ContentRegistry] Ingestion complete. Items: %d, Crops: %d." % [_items.size(), loaded_crops])
	EventBus.content_loading_finished.emit(_items.size(), loaded_crops)

func register_default_tools() -> void:
	var tools_def: Array[Dictionary] = [
		{
			"id": "hoe",
			"name": "Hoe",
			"description": "Used to till dirt.",
			"category": int(ItemData.Category.TOOL),
			"texture_path": "TileSheets/tools.png",
			"sprite_index": 21,
			"max_stack": 1,
		},
		{
			"id": "watering_can",
			"name": "Watering Can",
			"description": "Used to water crops.",
			"category": int(ItemData.Category.TOOL),
			"texture_path": "TileSheets/tools.png",
			"sprite_index": 273,
			"max_stack": 1,
		},
		{
			"id": "axe",
			"name": "Axe",
			"description": "Used to chop wood.",
			"category": int(ItemData.Category.TOOL),
			"texture_path": "TileSheets/tools.png",
			"sprite_index": 189,
			"max_stack": 1,
		},
		{
			"id": "pickaxe",
			"name": "Pickaxe",
			"description": "Used to break stones.",
			"category": int(ItemData.Category.TOOL),
			"texture_path": "TileSheets/tools.png",
			"sprite_index": 105,
			"max_stack": 1,
		},
		{
			"id": "scythe",
			"name": "Scythe",
			"description": "Used to cut grass and harvest crops.",
			"category": int(ItemData.Category.TOOL),
			"texture_path": "TileSheets/tools.png",
			"sprite_index": 47,
			"max_stack": 1,
		},
	]
	for d: Dictionary in tools_def:
		var item: ItemData = ItemData.from_dict(d)
		register_item(item.id, item)

func load_items_from_json_file(file_path: String) -> int:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.ModeFlags.READ)
	if file == null:
		push_error("[ContentRegistry] Cannot open items file: %s" % file_path)
		return 0
	
	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var error: Error = json.parse(text)
	if error != OK:
		push_error("[ContentRegistry] JSON parse error in %s: %s at line %d" % [file_path, json.get_error_message(), json.get_error_line()])
		return 0

	var data: Variant = json.data
	var count: int = 0
	if data is Dictionary:
		var dict: Dictionary = data as Dictionary
		for key: Variant in dict.keys():
			var item_dict: Variant = dict[key]
			if item_dict is Dictionary:
				var item: ItemData = ItemData.from_dict(item_dict as Dictionary)
				if item.id.is_empty():
					item.id = StringName(str(key))
				if register_item(item.id, item):
					count += 1
	elif data is Array:
		var arr: Array = data as Array
		for item_elem: Variant in arr:
			if item_elem is Dictionary:
				var item: ItemData = ItemData.from_dict(item_elem as Dictionary)
				if not item.id.is_empty() and register_item(item.id, item):
					count += 1

	return count

func load_crops_from_json_file(file_path: String) -> int:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.ModeFlags.READ)
	if file == null:
		push_error("[ContentRegistry] Cannot open crops file: %s" % file_path)
		return 0

	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var error: Error = json.parse(text)
	if error != OK:
		push_error("[ContentRegistry] JSON parse error in %s: %s at line %d" % [file_path, json.get_error_message(), json.get_error_line()])
		return 0

	var data: Variant = json.data
	var count: int = 0
	if data is Dictionary:
		var dict: Dictionary = data as Dictionary
		for key: Variant in dict.keys():
			var crop_dict: Variant = dict[key]
			if crop_dict is Dictionary:
				var crop: CropData = CropData.from_dict(crop_dict as Dictionary)
				if crop.id.is_empty():
					crop.id = StringName(str(key))
				if register_crop(crop.id, crop):
					count += 1
	elif data is Array:
		var arr: Array = data as Array
		for crop_elem: Variant in arr:
			if crop_elem is Dictionary:
				var crop: CropData = CropData.from_dict(crop_elem as Dictionary)
				if not crop.id.is_empty() and register_crop(crop.id, crop):
					count += 1

	return count
