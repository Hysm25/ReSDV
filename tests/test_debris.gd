extends Node

## Automated test suite for Foraging and Debris Clearing system:
## Twig chopping (Axe -> Wood), Stone breaking (Pickaxe -> Stone),
## Weed cutting (Scythe/Tools -> Fiber), Wild Grass cutting (Scythe -> Hay chance),
## Seasonal Forage picking (Hand -> Item), Ineffective tool rejection,
## Tilling obstruction enforcement, and Cross-location persistence.

func _ready() -> void:
	print("=======================================================")
	print("--- Running Foraging & Debris Clearing Test Suite ---")
	print("=======================================================")

	test_debris_spawning()
	test_axe_chops_twig()
	test_pickaxe_breaks_stone()
	test_scythe_cuts_weed()
	test_scythe_cuts_grass()
	test_hand_picks_up_forage()
	test_ineffective_tool_rejection()
	test_debris_blocks_tilling()
	test_player_tool_interaction()
	test_cross_location_persistence()
	test_debris_serialization()

	print("=======================================================")
	print("--- ALL FORAGING & DEBRIS TESTS PASSED SUCCESSFULLY! ---")
	print("=======================================================")
	get_tree().quit(0)


func test_debris_spawning() -> void:
	print("[Test 1] Testing DebrisManager spawning and obstacles...")
	var dm: DebrisManager = DebrisManager.new()
	add_child(dm)

	var twig: DebrisObject = dm.spawn_twig(&"Farm", Vector2i(10, 10))
	var stone: DebrisObject = dm.spawn_stone(&"Farm", Vector2i(11, 10))
	var weed: DebrisObject = dm.spawn_weed(&"Farm", Vector2i(12, 10))
	var grass: DebrisObject = dm.spawn_grass(&"Farm", Vector2i(13, 10))
	var forage: DebrisObject = dm.spawn_forage(&"Farm", Vector2i(14, 10), &"vanilla:18")

	assert(dm.has_debris_at(&"Farm", Vector2i(10, 10)), "Must have twig at (10, 10)")
	assert(dm.has_debris_at(&"Farm", Vector2i(11, 10)), "Must have stone at (11, 10)")
	assert(dm.has_debris_at(&"Farm", Vector2i(12, 10)), "Must have weed at (12, 10)")
	assert(dm.has_debris_at(&"Farm", Vector2i(13, 10)), "Must have grass at (13, 10)")
	assert(dm.has_debris_at(&"Farm", Vector2i(14, 10)), "Must have forage at (14, 10)")

	# Collision/Obstacle checks
	assert(dm.is_obstacle_at(&"Farm", Vector2i(10, 10)), "Twig must be an obstacle")
	assert(dm.is_obstacle_at(&"Farm", Vector2i(11, 10)), "Stone must be an obstacle")
	assert(not dm.is_obstacle_at(&"Farm", Vector2i(12, 10)), "Weed must not be an obstacle")
	assert(not dm.is_obstacle_at(&"Farm", Vector2i(13, 10)), "Grass must not be an obstacle")
	assert(not dm.is_obstacle_at(&"Farm", Vector2i(14, 10)), "Forage must not be an obstacle")

	assert(twig.yield_item_id == &"vanilla:388", "Twig must yield Wood (388)")
	assert(stone.yield_item_id == &"vanilla:390", "Stone must yield Stone (390)")
	assert(weed.yield_item_id == &"vanilla:771", "Weed must yield Fiber (771)")
	assert(grass.yield_item_id == &"vanilla:178", "Grass must yield Hay (178)")
	assert(forage.yield_item_id == &"vanilla:18", "Forage must yield Daffodil (18)")

	dm.queue_free()
	print("[Test 1] Spawning and obstacles verified.")


func test_axe_chops_twig() -> void:
	print("[Test 2] Testing Axe chops twig -> Wood + Stamina...")
	var dm: DebrisManager = DebrisManager.new()
	var inv: InventoryManager = InventoryManager.new()
	var energy: EnergyManager = EnergyManager.new()
	add_child(dm)
	add_child(inv)
	add_child(energy)

	var cell: Vector2i = Vector2i(5, 5)
	dm.spawn_twig(&"Farm", cell)

	var starting_energy: float = energy.current_energy
	var ok: bool = dm.hit_debris(&"Farm", cell, &"vanilla:axe", inv, energy)

	assert(ok, "Axe should successfully chop twig")
	assert(not dm.has_debris_at(&"Farm", cell), "Twig should be destroyed")
	assert(inv.get_item_count(&"vanilla:388") == 1, "Player should receive 1 Wood")
	assert(energy.current_energy == starting_energy - 2.0, "Axe swing must consume 2.0 energy")

	dm.queue_free()
	inv.queue_free()
	energy.queue_free()
	print("[Test 2] Twig chopping verified.")


func test_pickaxe_breaks_stone() -> void:
	print("[Test 3] Testing Pickaxe breaks stone -> Stone + Stamina...")
	var dm: DebrisManager = DebrisManager.new()
	var inv: InventoryManager = InventoryManager.new()
	var energy: EnergyManager = EnergyManager.new()
	add_child(dm)
	add_child(inv)
	add_child(energy)

	var cell: Vector2i = Vector2i(6, 6)
	dm.spawn_stone(&"Farm", cell)

	var starting_energy: float = energy.current_energy
	var ok: bool = dm.hit_debris(&"Farm", cell, &"vanilla:pickaxe", inv, energy)

	assert(ok, "Pickaxe should successfully break stone")
	assert(not dm.has_debris_at(&"Farm", cell), "Stone should be destroyed")
	assert(inv.get_item_count(&"vanilla:390") == 1, "Player should receive 1 Stone")
	assert(energy.current_energy == starting_energy - 2.0, "Pickaxe swing must consume 2.0 energy")

	dm.queue_free()
	inv.queue_free()
	energy.queue_free()
	print("[Test 3] Stone breaking verified.")


func test_scythe_cuts_weed() -> void:
	print("[Test 4] Testing Scythe cuts weed -> Fiber + 0 Stamina...")
	var dm: DebrisManager = DebrisManager.new()
	var inv: InventoryManager = InventoryManager.new()
	var energy: EnergyManager = EnergyManager.new()
	add_child(dm)
	add_child(inv)
	add_child(energy)

	var cell: Vector2i = Vector2i(7, 7)
	dm.spawn_weed(&"Farm", cell)

	var starting_energy: float = energy.current_energy
	var ok: bool = dm.hit_debris(&"Farm", cell, &"vanilla:scythe", inv, energy)

	assert(ok, "Scythe should successfully cut weed")
	assert(not dm.has_debris_at(&"Farm", cell), "Weed should be destroyed")
	assert(inv.get_item_count(&"vanilla:771") == 1, "Player should receive 1 Fiber")
	assert(energy.current_energy == starting_energy, "Scythe swing must consume 0.0 energy")

	dm.queue_free()
	inv.queue_free()
	energy.queue_free()
	print("[Test 4] Weed cutting verified.")


func test_scythe_cuts_grass() -> void:
	print("[Test 5] Testing Scythe cuts wild grass...")
	var dm: DebrisManager = DebrisManager.new()
	var inv: InventoryManager = InventoryManager.new()
	var energy: EnergyManager = EnergyManager.new()
	add_child(dm)
	add_child(inv)
	add_child(energy)

	var cell: Vector2i = Vector2i(8, 8)
	dm.spawn_grass(&"Farm", cell)

	var starting_energy: float = energy.current_energy
	var ok: bool = dm.hit_debris(&"Farm", cell, &"vanilla:scythe", inv, energy)

	assert(ok, "Scythe should successfully cut wild grass")
	assert(not dm.has_debris_at(&"Farm", cell), "Wild grass should be cleared")
	assert(energy.current_energy == starting_energy, "Scythe must consume 0 energy on grass")

	dm.queue_free()
	inv.queue_free()
	energy.queue_free()
	print("[Test 5] Wild grass cutting verified.")


func test_hand_picks_up_forage() -> void:
	print("[Test 6] Testing Hand picks up seasonal forage items...")
	var dm: DebrisManager = DebrisManager.new()
	var inv: InventoryManager = InventoryManager.new()
	add_child(dm)
	add_child(inv)

	var daffodil_cell: Vector2i = Vector2i(9, 9)
	var horseradish_cell: Vector2i = Vector2i(9, 10)
	dm.spawn_forage(&"Farm", daffodil_cell, &"vanilla:18")
	dm.spawn_forage(&"Farm", horseradish_cell, &"vanilla:16")

	var ok: bool = dm.pickup_forage(&"Farm", daffodil_cell, inv)
	assert(ok, "Should pick up Daffodil")
	assert(not dm.has_debris_at(&"Farm", daffodil_cell), "Daffodil should be collected from world")
	assert(inv.get_item_count(&"vanilla:18") == 1, "Player should have 1 Daffodil")

	ok = dm.pickup_forage(&"Farm", horseradish_cell, inv)
	assert(ok, "Should pick up Wild Horseradish")
	assert(not dm.has_debris_at(&"Farm", horseradish_cell), "Horseradish should be collected from world")
	assert(inv.get_item_count(&"vanilla:16") == 1, "Player should have 1 Wild Horseradish")

	dm.queue_free()
	inv.queue_free()
	print("[Test 6] Forage pickup verified.")


func test_ineffective_tool_rejection() -> void:
	print("[Test 7] Testing Ineffective tool rejection...")
	var dm: DebrisManager = DebrisManager.new()
	var inv: InventoryManager = InventoryManager.new()
	var energy: EnergyManager = EnergyManager.new()
	add_child(dm)
	add_child(inv)
	add_child(energy)

	# Scythe on Stone
	var stone_cell: Vector2i = Vector2i(20, 20)
	dm.spawn_stone(&"Farm", stone_cell)
	var start_e: float = energy.current_energy
	var ok: bool = dm.hit_debris(&"Farm", stone_cell, &"vanilla:scythe", inv, energy)
	assert(not ok, "Scythe cannot break stone")
	assert(dm.has_debris_at(&"Farm", stone_cell), "Stone must remain intact")
	assert(energy.current_energy == start_e, "Scythe tool energy is 0")

	# Pickaxe on Twig
	var twig_cell: Vector2i = Vector2i(21, 21)
	dm.spawn_twig(&"Farm", twig_cell)
	start_e = energy.current_energy
	ok = dm.hit_debris(&"Farm", twig_cell, &"vanilla:pickaxe", inv, energy)
	assert(not ok, "Pickaxe cannot chop twig")
	assert(dm.has_debris_at(&"Farm", twig_cell), "Twig must remain intact")
	assert(energy.current_energy == start_e - 2.0, "Tool swing in vain consumes energy")

	dm.queue_free()
	inv.queue_free()
	energy.queue_free()
	print("[Test 7] Ineffective tool rejection verified.")


func test_debris_blocks_tilling() -> void:
	print("[Test 8] Testing Debris blocks soil tilling...")
	var fg: FarmGrid = FarmGrid.new()
	var dm: DebrisManager = DebrisManager.new()
	fg.debris_manager = dm
	fg.grid_width = 30
	fg.grid_height = 30
	add_child(fg)
	add_child(dm)

	var cell: Vector2i = Vector2i(15, 15)
	dm.spawn_twig(&"Farm", cell)

	# Tilling while twig is present
	var ok: bool = fg.till_soil(cell)
	assert(not ok, "Tilling must fail when cell contains debris")
	assert(fg.get_soil_state(cell) == FarmGrid.SoilState.UNTILLED, "Soil must stay UNTILLED")

	# Clear twig
	dm.remove_debris(&"Farm", cell)
	assert(not dm.has_debris_at(&"Farm", cell), "Twig removed")

	# Tilling after clearing
	ok = fg.till_soil(cell)
	assert(ok, "Tilling must succeed once debris is cleared")
	assert(fg.get_soil_state(cell) == FarmGrid.SoilState.TILLED, "Soil must now be TILLED")

	fg.queue_free()
	dm.queue_free()
	print("[Test 8] Debris blocking tilling verified.")


func test_player_tool_interaction() -> void:
	print("[Test 9] Testing Player integrated tool interaction on debris...")
	var player: Player = Player.new()
	var dm: DebrisManager = DebrisManager.new()
	var inv: InventoryManager = InventoryManager.new()
	var energy: EnergyManager = EnergyManager.new()
	var fg: FarmGrid = FarmGrid.new()

	player.debris_manager = dm
	player.inventory_manager = inv
	player.energy_manager = energy
	player.farm_grid = fg
	fg.debris_manager = dm

	add_child(dm)
	add_child(inv)
	add_child(energy)
	add_child(fg)
	add_child(player)

	# Target cell right in front of player
	player.position = Vector2(16 * 5, 16 * 5)
	player.target_cell = Vector2i(5, 6)

	# 1. Chop twig with Axe via Player
	dm.spawn_twig(&"Farm", player.target_cell)
	inv.set_slot(0, &"vanilla:axe", 1)
	inv.select_slot(0)

	var ok: bool = player.use_active_tool()
	assert(ok, "Player should use Axe on twig")
	assert(not dm.has_debris_at(&"Farm", player.target_cell), "Twig should be destroyed by player")
	assert(inv.get_item_count(&"vanilla:388") == 1, "Player inventory should receive Wood")

	# 2. Pick up forage via Player
	dm.spawn_forage(&"Farm", player.target_cell, &"vanilla:18")
	inv.select_slot(1) # Empty slot

	ok = player.use_active_tool()
	assert(ok, "Player should pick up forage")
	assert(not dm.has_debris_at(&"Farm", player.target_cell), "Forage should be removed from world")
	assert(inv.get_item_count(&"vanilla:18") == 1, "Player should receive Daffodil")

	player.queue_free()
	dm.queue_free()
	inv.queue_free()
	energy.queue_free()
	fg.queue_free()
	print("[Test 9] Player integrated interaction verified.")


func test_cross_location_persistence() -> void:
	print("[Test 10] Testing cross-location visibility and persistence...")
	var dm: DebrisManager = DebrisManager.new()
	add_child(dm)

	var twig: DebrisObject = dm.spawn_twig(&"Farm", Vector2i(5, 5))
	assert(twig.visible, "Farm twig should be visible on Farm")

	# Switch location to FarmHouse
	EventBus.location_changed.emit(&"Farm", &"FarmHouse", Vector2i(3, 11))
	assert(not twig.visible, "Farm twig must be hidden when indoors")
	assert(twig.process_mode == Node.PROCESS_MODE_DISABLED, "Farm twig must be paused when indoors")

	# Switch location back to Farm
	EventBus.location_changed.emit(&"FarmHouse", &"Farm", Vector2i(64, 15))
	assert(twig.visible, "Farm twig must be visible again outside")
	assert(twig.process_mode == Node.PROCESS_MODE_INHERIT, "Farm twig must be active again outside")

	dm.queue_free()
	print("[Test 10] Cross-location persistence verified.")


func test_debris_serialization() -> void:
	print("[Test 11] Testing DebrisManager serialization (to_dict / load_from_dict)...")
	var dm: DebrisManager = DebrisManager.new()
	add_child(dm)

	dm.spawn_twig(&"Farm", Vector2i(1, 1))
	dm.spawn_stone(&"Farm", Vector2i(2, 2))
	dm.spawn_forage(&"Farm", Vector2i(3, 3), &"vanilla:18")

	var dict: Dictionary = dm.to_dict()
	assert(dict.has("Farm"), "Saved dict must contain Farm location")
	var farm_list: Array = dict["Farm"] as Array
	assert(farm_list.size() == 3, "Farm should have 3 serialized objects")

	# Create second manager and load
	var dm2: DebrisManager = DebrisManager.new()
	add_child(dm2)
	dm2.load_from_dict(dict)

	assert(dm2.has_debris_at(&"Farm", Vector2i(1, 1)), "Twig should be restored at (1, 1)")
	assert(dm2.has_debris_at(&"Farm", Vector2i(2, 2)), "Stone should be restored at (2, 2)")
	assert(dm2.has_debris_at(&"Farm", Vector2i(3, 3)), "Forage should be restored at (3, 3)")

	var restored_twig: DebrisObject = dm2.get_debris_at(&"Farm", Vector2i(1, 1))
	assert(restored_twig.debris_type == DebrisObject.DebrisType.TWIG, "Type must be TWIG")

	dm.queue_free()
	dm2.queue_free()
	print("[Test 11] Serialization verified.")
