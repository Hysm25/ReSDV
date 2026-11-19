extends Node

const GOGImporter = preload("res://src/importer/gog_importer.gd")

@onready var location_manager: LocationManager = $LocationManager
@onready var inventory_manager: InventoryManager = $InventoryManager
@onready var audio_manager: AudioManager = $AudioManager
@onready var energy_manager: EnergyManager = $EnergyManager
@onready var chest_manager: ChestManager = $ChestManager
@onready var debris_manager: DebrisManager = $DebrisManager
@onready var chest_ui: ChestUI = $ChestUI
@onready var npc_manager: NPCManager = $NPCManager
@onready var dialogue_ui: DialogueBoxUI = $DialogueBoxUI
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

	if location_manager != null and location_manager.locations.is_empty():
		location_manager.initialize_locations()

	if debris_manager != null:
		debris_manager.spawn_initial_farm_debris()

	if hud != null and inventory_manager != null:
		hud.bind_inventory(inventory_manager)

	# Connect Player and HUD events
	if player != null and hud != null:
		EventBus.item_selected.connect(func(_slot: int, _item_id: StringName) -> void:
			hud.update_active_tool(player.get_active_tool_name())
		)
		EventBus.crop_harvested.connect(func(_cell: Vector2i, _crop_id: StringName, yield_id: StringName, _count: int) -> void:
			var total: int = inventory_manager.get_item_count(yield_id) if inventory_manager != null else player.harvest_bag.get(yield_id, 0)
			hud.update_harvest_count(total)
		)
		hud.update_active_tool(player.get_active_tool_name())

	print("[Main] ReSDV Vertical Slice initialized successfully.")
