extends Node

const GOGImporter = preload("res://src/importer/gog_importer.gd")

@onready var map_loader: MapLoader = $MapLoader
@onready var farm_grid: FarmGrid = $FarmGrid
@onready var crop_manager: CropManager = $CropManager
@onready var player: Player = $Player
@onready var time_manager: TimeManager = $TimeManager
@onready var hud: HUD = $HUD

func _ready() -> void:
	print("[Main] Initializing ReSDV Vertical Slice...")
	
	# Verify and load vanilla assets if needed
	if not GOGImporter.is_vanilla_data_ready():
		print("[Main] Vanilla data not detected. Triggering GOG extraction pipeline...")
		var ok: bool = GOGImporter.ensure_vanilla_data()
		if not ok:
			push_warning("[Main] GOG extraction pipeline could not complete automatically.")
	else:
		print("[Main] Vanilla data detected and ready.")

	if map_loader != null and map_loader.layers.is_empty():
		map_loader.load_map()

	# Connect Player and HUD events
	if player != null and hud != null:
		EventBus.item_selected.connect(func(_slot: int, _item_id: StringName) -> void:
			hud.update_active_tool(player.get_active_tool_name())
		)
		EventBus.crop_harvested.connect(func(_cell: Vector2i, _crop_id: StringName, yield_id: StringName, _count: int) -> void:
			var total: int = player.harvest_bag.get(yield_id, 0)
			hud.update_harvest_count(total)
		)
		hud.update_active_tool(player.get_active_tool_name())

	print("[Main] ReSDV Vertical Slice initialized successfully.")
