extends Node

func _ready() -> void:
	print("=======================================================")
	print("--- Running Vertical Slice Full Integration Tests ---")
	print("=======================================================")

	# 1. Test TimeManager
	var time_manager: TimeManager = TimeManager.new()
	add_child(time_manager)
	
	print("[Test 1] TimeManager initial calendar state...")
	assert(time_manager.current_day == 1, "Day should be 1")
	assert(time_manager.get_current_season() == "spring", "Season should be spring")
	assert(time_manager.current_year == 1, "Year should be 1")
	assert(time_manager.current_time == 600, "Start time should be 600 (06:00 AM)")
	assert(time_manager.get_formatted_time() == "6:00 AM", "Formatted time mismatch")

	time_manager.advance_time(10)
	assert(time_manager.current_time == 610, "Time after 10m should be 610")
	assert(time_manager.get_formatted_time() == "6:10 AM", "Formatted time mismatch")

	time_manager.advance_time(50)
	assert(time_manager.current_time == 700, "Time after 50m should be 700")
	assert(time_manager.get_formatted_time() == "7:00 AM", "Formatted time mismatch")

	time_manager.advance_day()
	assert(time_manager.current_day == 2, "Day should advance to 2")
	assert(time_manager.current_time == 600, "Time on new day should reset to 600")
	print("[Test 1] TimeManager verification PASSED.")

	# 2. Test FarmGrid & Soil States
	print("[Test 2] FarmGrid terrain & soil mechanics...")
	var farm_grid: FarmGrid = FarmGrid.new()
	farm_grid.grid_width = 30
	farm_grid.grid_height = 20
	add_child(farm_grid)

	var test_cell: Vector2i = Vector2i(5, 5)
	assert(farm_grid.get_soil_state(test_cell) == FarmGrid.SoilState.UNTILLED, "Initial soil state should be UNTILLED")
	assert(not farm_grid.is_tilled(test_cell), "Should not be tilled initially")

	var tilled_ok: bool = farm_grid.till_soil(test_cell)
	assert(tilled_ok, "Till soil should succeed")
	assert(farm_grid.get_soil_state(test_cell) == FarmGrid.SoilState.TILLED, "Soil should now be TILLED")
	assert(farm_grid.is_tilled(test_cell), "is_tilled should return true")

	# Cannot re-till already tilled soil
	assert(not farm_grid.till_soil(test_cell), "Till soil on already tilled cell should fail")

	# Water the soil
	var watered_ok: bool = farm_grid.water_soil(test_cell)
	assert(watered_ok, "Water soil should succeed")
	assert(farm_grid.get_soil_state(test_cell) == FarmGrid.SoilState.WATERED, "Soil should now be WATERED")
	assert(farm_grid.is_watered(test_cell), "is_watered should return true")

	# Cannot water untilled soil
	var untill_cell: Vector2i = Vector2i(6, 6)
	assert(not farm_grid.water_soil(untill_cell), "Watering untilled soil should fail")
	print("[Test 2] FarmGrid verification PASSED.")

	# 3. Test CropManager & Parsnip Lifecycle
	print("[Test 3] CropManager planting, growth, and harvest...")
	var crop_manager: CropManager = CropManager.new()
	crop_manager.farm_grid = farm_grid
	add_child(crop_manager)

	# Cannot plant on untilled soil
	var plant_untilled: bool = crop_manager.plant_seed(untill_cell, &"472")
	assert(not plant_untilled, "Planting on untilled soil must fail")

	# Plant Parsnip seed (vanilla:472) on tilled & watered soil (5, 5)
	var planted_ok: bool = crop_manager.plant_seed(test_cell, &"472")
	assert(planted_ok, "Planting Parsnip seeds on tilled soil should succeed")
	assert(crop_manager.has_crop(test_cell), "has_crop should return true")

	var crop: CropManager.PlantedCrop = crop_manager.get_crop(test_cell)
	assert(crop != null, "PlantedCrop instance must not be null")
	assert(crop.current_phase == 0, "Initial crop phase must be 0")
	assert(not crop.is_mature(), "Crop must not be mature initially")

	# Advance 4 days with watering to reach full maturity (Parsnip phases: [1, 1, 1, 1])
	print("[Test 3] Simulating 4 days of growth with daily watering...")
	for day: int in range(1, 5):
		crop.is_watered_today = true
		time_manager.advance_day()
		print("  - Day %d ended: Crop phase is now %d (Mature: %s)" % [day, crop.current_phase, str(crop.is_mature())])

	assert(crop.current_phase == 4, "Parsnip must reach phase 4 after 4 growth days")
	assert(crop.is_mature(), "Crop must report is_mature == true")
	assert(crop_manager.is_mature(test_cell), "crop_manager.is_mature must return true")

	# Harvest the mature Parsnip
	var harvest_res: Dictionary = crop_manager.harvest_crop(test_cell)
	assert(harvest_res.get("success", false), "Harvest must succeed")
	assert(harvest_res["yield_item_id"] == &"vanilla:24", "Harvest yield must be vanilla:24 (Parsnip)")
	assert(harvest_res["count"] == 1, "Parsnip yield count must be 1")
	assert(not crop_manager.has_crop(test_cell), "Non-regrowable crop must be cleared after harvest")
	print("[Test 3] CropManager verification PASSED.")

	# 4. Test Player & Full Gameplay Loop
	print("[Test 4] Player interaction loop (till -> plant -> water -> mature -> harvest)...")
	var player: Player = Player.new()
	player.farm_grid = farm_grid
	player.crop_manager = crop_manager
	add_child(player)

	var p_cell: Vector2i = Vector2i(8, 8)
	player.global_position = farm_grid.cell_to_center_world(p_cell)
	player.facing_direction = Vector2i.RIGHT
	player._update_target_cell()
	var action_cell: Vector2i = Vector2i(9, 8)
	assert(player.target_cell == action_cell, "Player target cell calculation mismatch")

	# 4a. Till target cell with Hoe
	player.active_tool = Player.ToolType.HOE
	var tilled_by_player: bool = player.use_active_tool()
	assert(tilled_by_player, "Player tilling soil should succeed")
	assert(farm_grid.is_tilled(action_cell), "Target cell should now be tilled")

	# 4b. Plant Parsnip Seeds
	var initial_seeds: int = player.parsnip_seeds_count
	player.active_tool = Player.ToolType.PARSNIP_SEEDS
	var planted_by_player: bool = player.use_active_tool()
	assert(planted_by_player, "Player planting seeds should succeed")
	assert(player.parsnip_seeds_count == initial_seeds - 1, "Player seed count must decrement by 1")
	assert(crop_manager.has_crop(action_cell), "CropManager must track crop at action_cell")

	# 4c. Water with Watering Can
	player.active_tool = Player.ToolType.WATERING_CAN
	var watered_by_player: bool = player.use_active_tool()
	assert(watered_by_player, "Player watering should succeed")
	assert(farm_grid.is_watered(action_cell), "Target cell must be watered")

	# 4d. Advance 4 days of watering
	var p_crop: CropManager.PlantedCrop = crop_manager.get_crop(action_cell)
	for d: int in range(4):
		p_crop.is_watered_today = true
		time_manager.advance_day()

	assert(p_crop.is_mature(), "Player-planted Parsnip should be fully mature after 4 days")

	# 4e. Harvest with Hand
	player.active_tool = Player.ToolType.HAND
	var harvested_by_player: bool = player.use_active_tool()
	assert(harvested_by_player, "Player harvesting mature crop should succeed")
	assert(player.harvest_bag.get(&"vanilla:24", 0) == 1, "Player bag must contain exactly 1 vanilla:24 Parsnip")
	assert(not crop_manager.has_crop(action_cell), "Harvested tile should no longer have crop")
	print("[Test 4] Player interaction loop PASSED.")

	print("=======================================================")
	print("--- ALL VERTICAL SLICE INTEGRATION TESTS PASSED! ---")
	print("=======================================================")
	get_tree().quit(0)
