class_name CropData
extends Resource

## Base data representation for crops, their growth stages, and yields.
## Adheres to strict static typing standards for ReSDV.

@export var id: StringName = &""
@export var seed_item_id: StringName = &""
@export var harvest_item_id: StringName = &""
@export var growth_phase_days: Array[int] = []
@export var seasons: Array[String] = []
@export var regrow_after_harvest_days: int = -1
@export var is_trellis_crop: bool = false
@export var min_harvest: int = 1
@export var max_harvest: int = 1
@export var max_harvest_increase_per_farming_level: float = 0.0
@export var chance_for_extra_crops: float = 0.0
@export var texture_path: String = "TileSheets/crops"
@export var sprite_index: int = 0
@export var harvest_method: int = 0
@export var texture: Texture2D = null

func get_total_growth_days() -> int:
	var total: int = 0
	for days: int in growth_phase_days:
		total += days
	return total

func can_grow_in_season(season: String) -> bool:
	return seasons.has(season.to_lower())

func is_regrowable() -> bool:
	return regrow_after_harvest_days > 0

static func from_dict(data: Dictionary) -> CropData:
	var crop: CropData = CropData.new()
	if data.has("id"):
		crop.id = StringName(str(data["id"]))
	if data.has("seed_item_id"):
		crop.seed_item_id = StringName(str(data["seed_item_id"]))
	if data.has("harvest_item_id"):
		crop.harvest_item_id = StringName(str(data["harvest_item_id"]))
	if data.has("growth_phase_days"):
		var raw_phases: Array = data["growth_phase_days"] as Array
		var phases: Array[int] = []
		for phase: Variant in raw_phases:
			phases.append(int(phase))
		crop.growth_phase_days = phases
	if data.has("seasons"):
		var raw_seasons: Array = data["seasons"] as Array
		var s_list: Array[String] = []
		for s: Variant in raw_seasons:
			s_list.append(str(s).to_lower())
		crop.seasons = s_list
	if data.has("regrow_after_harvest_days"):
		crop.regrow_after_harvest_days = int(data["regrow_after_harvest_days"])
	if data.has("is_trellis_crop"):
		crop.is_trellis_crop = bool(data["is_trellis_crop"])
	if data.has("min_harvest"):
		crop.min_harvest = int(data["min_harvest"])
	if data.has("max_harvest"):
		crop.max_harvest = int(data["max_harvest"])
	if data.has("max_harvest_increase_per_farming_level"):
		crop.max_harvest_increase_per_farming_level = float(data["max_harvest_increase_per_farming_level"])
	if data.has("chance_for_extra_crops"):
		crop.chance_for_extra_crops = float(data["chance_for_extra_crops"])
	if data.has("texture"):
		crop.texture_path = str(data["texture"])
	elif data.has("texture_path"):
		crop.texture_path = str(data["texture_path"])
	if data.has("sprite_index"):
		crop.sprite_index = int(data["sprite_index"])
	if data.has("harvest_method"):
		crop.harvest_method = int(data["harvest_method"])
	return crop

func to_dict() -> Dictionary:
	var phases: Array[int] = growth_phase_days.duplicate()
	var s_list: Array[String] = seasons.duplicate()
	return {
		"id": String(id),
		"seed_item_id": String(seed_item_id),
		"harvest_item_id": String(harvest_item_id),
		"growth_phase_days": phases,
		"seasons": s_list,
		"regrow_after_harvest_days": regrow_after_harvest_days,
		"is_trellis_crop": is_trellis_crop,
		"min_harvest": min_harvest,
		"max_harvest": max_harvest,
		"max_harvest_increase_per_farming_level": max_harvest_increase_per_farming_level,
		"chance_for_extra_crops": chance_for_extra_crops,
		"texture_path": texture_path,
		"sprite_index": sprite_index,
		"harvest_method": harvest_method,
	}
