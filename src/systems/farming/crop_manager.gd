class_name CropManager
extends Node2D

## Manages planted crop lifecycle, daily growth progression, and harvesting.
## Renders authentic crop sprites from user://vanilla_data/TileSheets/crops.png.

class PlantedCrop:
	var cell: Vector2i
	var crop_id: StringName
	var crop_data: CropData
	var current_phase: int = 0
	var day_of_current_phase: int = 0
	var is_watered_today: bool = false

	func _init(p_cell: Vector2i, p_crop_id: StringName, p_data: CropData) -> void:
		cell = p_cell
		crop_id = p_crop_id
		crop_data = p_data
		current_phase = 0
		day_of_current_phase = 0
		is_watered_today = false

	func is_mature() -> bool:
		if crop_data == null:
			return false
		return current_phase >= crop_data.growth_phase_days.size()

const CROPS_PNG_PATH: String = "user://vanilla_data/TileSheets/crops.png"
const TILE_SIZE: int = 16

@export var farm_grid: FarmGrid = null

var crops_texture: Texture2D = null
var _crops: Dictionary[Vector2i, PlantedCrop] = {}

func _ready() -> void:
	_load_crops_texture()
	EventBus.day_started.connect(_on_day_started)
	EventBus.crop_watered.connect(_on_crop_watered)

func _load_crops_texture() -> void:
	if not FileAccess.file_exists(CROPS_PNG_PATH):
		print("[CropManager] Vanilla crops.png not found at '%s'. Using procedural fallback." % CROPS_PNG_PATH)
		return

	var global_path: String = ProjectSettings.globalize_path(CROPS_PNG_PATH)
	var image: Image = Image.load_from_file(global_path)
	if image != null and not image.is_empty():
		crops_texture = ImageTexture.create_from_image(image)
		print("[CropManager] Successfully loaded vanilla crops texture: %dx%d" % [crops_texture.get_width(), crops_texture.get_height()])

func _draw() -> void:
	for cell: Vector2i in _crops.keys():
		var crop: PlantedCrop = _crops[cell]
		_draw_crop(crop)

func _draw_crop(crop: PlantedCrop) -> void:
	var world_pos: Vector2 = Vector2(crop.cell.x * TILE_SIZE, crop.cell.y * TILE_SIZE)

	if crops_texture != null and crop.crop_data != null:
		var sprite_idx: int = crop.crop_data.sprite_index
		var col_base_x: int = (sprite_idx / 26) * 128
		var row_y: int = (sprite_idx % 26) * 32
		var phase_col: int = clampi(crop.current_phase, 0, 7)
		var src_x: int = col_base_x + phase_col * 16

		var src_rect: Rect2 = Rect2(src_x, row_y, 16, 32)
		# Crop sprite is 16x32; align bottom with tile bottom (offset y by -16)
		var dest_rect: Rect2 = Rect2(world_pos.x, world_pos.y - 16.0, 16.0, 32.0)
		draw_texture_rect_region(crops_texture, dest_rect, src_rect)
	else:
		# Procedural fallback visualization
		var phase: int = crop.current_phase
		var max_phase: int = crop.crop_data.growth_phase_days.size() if crop.crop_data != null else 4
		var color: Color = Color(0.2, 0.8, 0.2)
		if crop.is_mature():
			color = Color(0.9, 0.7, 0.1) # Mature gold
		var size_factor: float = float(phase + 1) / float(max_phase + 1)
		var radius: float = 2.0 + size_factor * 4.0
		draw_circle(world_pos + Vector2(8, 8), radius, color)

func plant_seed(cell: Vector2i, seed_item_id: StringName) -> bool:
	if has_crop(cell):
		return false
	if farm_grid != null and not farm_grid.is_tilled(cell):
		return false

	var crop_data: CropData = ContentRegistry.get_crop(seed_item_id)
	if crop_data == null:
		# Try resolving as seed ID
		crop_data = ContentRegistry.get_crop(ContentRegistry.ensure_namespaced(seed_item_id))
	if crop_data == null:
		# Check all crops where seed_item_id matches
		for registered_crop: CropData in ContentRegistry.get_all_crops():
			if registered_crop.seed_item_id == seed_item_id or registered_crop.seed_item_id == ContentRegistry.ensure_namespaced(seed_item_id):
				crop_data = registered_crop
				break

	if crop_data == null:
		push_error("[CropManager] No CropData found for seed: %s" % seed_item_id)
		return false

	var crop: PlantedCrop = PlantedCrop.new(cell, crop_data.id, crop_data)
	if farm_grid != null and farm_grid.is_watered(cell):
		crop.is_watered_today = true

	_crops[cell] = crop
	EventBus.crop_planted.emit(cell, crop_data.id)
	queue_redraw()
	return true

func has_crop(cell: Vector2i) -> bool:
	return _crops.has(cell)

func get_crop(cell: Vector2i) -> PlantedCrop:
	return _crops.get(cell, null)

func is_mature(cell: Vector2i) -> bool:
	var crop: PlantedCrop = get_crop(cell)
	return crop != null and crop.is_mature()

func harvest_crop(cell: Vector2i) -> Dictionary:
	var crop: PlantedCrop = get_crop(cell)
	if crop == null:
		return {"success": false, "yield_item_id": &"", "count": 0}
	if not crop.is_mature():
		return {"success": false, "yield_item_id": &"", "count": 0}

	var yield_id: StringName = crop.crop_data.harvest_item_id
	var count: int = crop.crop_data.min_harvest

	if crop.crop_data.is_regrowable():
		# Reset to regrow phase
		crop.current_phase = maxi(0, crop.crop_data.growth_phase_days.size() - 1)
		crop.day_of_current_phase = 0
	else:
		_crops.erase(cell)

	EventBus.crop_harvested.emit(cell, crop.crop_id, yield_id, count)
	queue_redraw()
	return {"success": true, "yield_item_id": yield_id, "count": count}

func _on_crop_watered(cell: Vector2i) -> void:
	var crop: PlantedCrop = get_crop(cell)
	if crop != null:
		crop.is_watered_today = true

func _on_day_started(_day: int, _season: String, _year: int) -> void:
	for cell: Vector2i in _crops.keys():
		var crop: PlantedCrop = _crops[cell]
		if crop.is_watered_today:
			_advance_crop_growth(crop)
		# Soil dries out; require watering for next day
		crop.is_watered_today = false
	queue_redraw()

func _advance_crop_growth(crop: PlantedCrop) -> void:
	if crop.is_mature():
		return

	crop.day_of_current_phase += 1
	var target_days: int = crop.crop_data.growth_phase_days[crop.current_phase]
	if crop.day_of_current_phase >= target_days:
		crop.current_phase += 1
		crop.day_of_current_phase = 0
		EventBus.crop_grown.emit(crop.cell, crop.current_phase)
