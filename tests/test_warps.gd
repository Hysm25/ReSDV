extends Node

## Automated test suite verifying LocationManager, bidirectional warping (Farm <-> FarmHouse),
## camera boundary adjustments, collision switching, and crop state persistence.

var signal_received: bool = false
var last_from: StringName = &""
var last_to: StringName = &""
var last_cell: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	print("=======================================================")
	print("--- Running Location & Warp Transition Verification ---")
	print("=======================================================")

	EventBus.location_changed.connect(_on_location_changed)

	# 1. Setup systems
	var time_manager: TimeManager = TimeManager.new()
	add_child(time_manager)

	var farm_grid: FarmGrid = FarmGrid.new()
	add_child(farm_grid)

	var crop_manager: CropManager = CropManager.new()
	crop_manager.farm_grid = farm_grid
	add_child(crop_manager)

	var player: Player = Player.new()
	player.farm_grid = farm_grid
	player.crop_manager = crop_manager
	var camera: Camera2D = Camera2D.new()
	camera.name = "Camera2D"
	player.add_child(camera)
	add_child(player)

	var loc_mgr: LocationManager = LocationManager.new()
	loc_mgr.auto_initialize = false
	loc_mgr.farm_grid = farm_grid
	loc_mgr.crop_manager = crop_manager
	loc_mgr.player = player
	add_child(loc_mgr)

	loc_mgr.initialize_locations()

	# [Step 1] Initial State on Farm
	print("[Step 1] Verifying initial Farm state...")
	assert(loc_mgr.current_location_id == &"Farm", "Initial location must be Farm")
	assert(farm_grid.visible, "FarmGrid must be visible on Farm")
	assert(farm_grid.process_mode == Node.PROCESS_MODE_INHERIT, "FarmGrid must be active on Farm")
	assert(crop_manager.visible, "CropManager must be visible on Farm")
	assert(crop_manager.process_mode == Node.PROCESS_MODE_INHERIT, "CropManager must be active on Farm")
	assert(player.global_position == loc_mgr.get_current_map_loader().cell_to_center_world(Vector2i(64, 15)), "Player should spawn at porch (64, 15)")
	assert(camera.limit_right == 1280 and camera.limit_bottom == 1040, "Camera limits should match Farm (1280x1040)")
	print("[Step 1] Initial Farm state verified.")

	# [Step 2] Plant crop on Farm before entering FarmHouse
	print("[Step 2] Planting crop on Farm...")
	var test_dirt: Vector2i = Vector2i(64, 18)
	assert(farm_grid.till_soil(test_dirt), "Tilling soil at (64, 18) must succeed")
	assert(crop_manager.plant_seed(test_dirt, &"472"), "Planting Parsnip at (64, 18) must succeed")
	var crop: CropManager.PlantedCrop = crop_manager.get_crop(test_dirt)
	assert(crop != null and crop.current_phase == 0, "Crop should be at phase 0")
	crop.is_watered_today = true
	print("[Step 2] Crop planted and watered at %s." % str(test_dirt))

	# [Step 3] Warp to FarmHouse via doorway (64, 14)
	print("[Step 3] Warping Farm -> FarmHouse...")
	signal_received = false
	loc_mgr._cooldown_timer = 0.0
	var warped_in: bool = loc_mgr.check_and_trigger_warp(Vector2i(64, 14))
	assert(warped_in, "Warping via door (64, 14) must succeed")
	assert(signal_received, "EventBus.location_changed signal must be emitted")
	assert(last_from == &"Farm" and last_to == &"FarmHouse", "Signal maps mismatch")
	assert(last_cell == Vector2i(3, 11), "Landing cell should be (3, 11)")

	# Verify FarmHouse state
	assert(loc_mgr.current_location_id == &"FarmHouse", "Current location must be FarmHouse")
	assert(not farm_grid.visible, "FarmGrid must be hidden inside FarmHouse")
	assert(farm_grid.process_mode == Node.PROCESS_MODE_DISABLED, "FarmGrid must be disabled inside FarmHouse")
	assert(not crop_manager.visible, "CropManager must be hidden inside FarmHouse")
	assert(crop_manager.process_mode == Node.PROCESS_MODE_DISABLED, "CropManager must be disabled inside FarmHouse")
	assert(camera.limit_right == 192 and camera.limit_bottom == 192, "Camera limits should match FarmHouse (192x192)")
	assert(loc_mgr.get_map_loader(&"FarmHouse").collision_body.process_mode == Node.PROCESS_MODE_INHERIT, "FarmHouse collision must be active")
	assert(loc_mgr.get_map_loader(&"Farm").collision_body.process_mode == Node.PROCESS_MODE_DISABLED, "Farm collision must be disabled")

	# Farming inside FarmHouse must be rejected
	player.target_cell = Vector2i(3, 10)
	player.active_tool = Player.ToolType.HOE
	assert(not player.use_active_tool(), "Farming inside FarmHouse must be disallowed")
	print("[Step 3] FarmHouse entry, camera clamping, collision mode, and tool suppression verified.")

	# [Step 4] Time progression while sleeping inside FarmHouse
	print("[Step 4] Simulating overnight day progression inside FarmHouse...")
	time_manager.advance_day()
	# Verify crop outside preserved its state and grew!
	assert(crop.current_phase == 1, "Crop on Farm must have grown to phase 1 overnight")
	print("[Step 4] Overnight crop growth and state persistence verified.")

	# [Step 5] Warp back to Farm via doorway exit (3, 12)
	print("[Step 5] Warping FarmHouse -> Farm...")
	signal_received = false
	# Clear cooldown timer for test execution
	loc_mgr._cooldown_timer = 0.0
	var warped_out: bool = loc_mgr.check_and_trigger_warp(Vector2i(3, 12))
	assert(warped_out, "Warping via exit (3, 12) must succeed")
	assert(signal_received, "EventBus.location_changed signal must be emitted")
	assert(last_from == &"FarmHouse" and last_to == &"Farm", "Signal maps mismatch")
	assert(last_cell == Vector2i(64, 15), "Landing cell should be (64, 15)")

	# Verify Farm restored state
	assert(loc_mgr.current_location_id == &"Farm", "Current location must be Farm")
	assert(farm_grid.visible, "FarmGrid must be visible on Farm")
	assert(farm_grid.process_mode == Node.PROCESS_MODE_INHERIT, "FarmGrid must be active on Farm")
	assert(crop_manager.visible, "CropManager must be visible on Farm")
	assert(crop_manager.process_mode == Node.PROCESS_MODE_INHERIT, "CropManager must be active on Farm")
	assert(camera.limit_right == 1280 and camera.limit_bottom == 1040, "Camera limits restored to Farm (1280x1040)")
	assert(loc_mgr.get_map_loader(&"Farm").collision_body.process_mode == Node.PROCESS_MODE_INHERIT, "Farm collision must be restored")
	assert(loc_mgr.get_map_loader(&"FarmHouse").collision_body.process_mode == Node.PROCESS_MODE_DISABLED, "FarmHouse collision must be disabled")

	# Check the crop at (64, 18) is intact and mature-able
	assert(crop_manager.has_crop(test_dirt), "Crop must still exist at (64, 18)")
	assert(crop.current_phase == 1, "Crop phase must be 1")

	# Advance 3 more days with watering to reach maturity
	for _i in range(3):
		crop.is_watered_today = true
		time_manager.advance_day()

	assert(crop.is_mature(), "Crop must now be mature (phase 4)")

	# Harvest on Farm
	player.target_cell = test_dirt
	player.active_tool = Player.ToolType.HAND
	var harvested: bool = player.use_active_tool()
	assert(harvested, "Harvesting mature crop on Farm must succeed")
	assert(player.harvest_bag.get(&"vanilla:24", 0) == 1, "Player must have 1 Parsnip")
	print("[Step 5] Return to Farm, camera expansion, and crop harvest verified.")

	print("=======================================================")
	print("--- ALL LOCATION & WARP TESTS PASSED SUCCESSFULLY! ---")
	print("=======================================================")
	get_tree().quit(0)

func _on_location_changed(from_map: StringName, to_map: StringName, target_cell: Vector2i) -> void:
	signal_received = true
	last_from = from_map
	last_to = to_map
	last_cell = target_cell
