extends Node

## Unit test suite for MapLoader and xTile map rendering.

func _ready() -> void:
	print("--- Running MapLoader Verification Test ---")
	test_farm_map_loading()
	test_farmhouse_map_loading()
	print("--- All MapLoader Verifications Passed Successfully! ---")
	get_tree().quit(0)

func test_farm_map_loading() -> void:
	var loader: MapLoader = MapLoader.new()
	loader.auto_load_on_ready = false
	add_child(loader)

	var ok: bool = loader.load_map("user://vanilla_data/Maps/Farm.json")
	assert(ok, "Farm map should load successfully")
	assert(loader.map_id == "Farm", "Map ID should be Farm")
	assert(loader.map_size == Vector2i(80, 65), "Farm map should be 80x65 tiles")
	assert(loader.tile_size == Vector2i(16, 16), "Tile size should be 16x16")

	# Check layers
	var expected_layers: Array[String] = ["Back", "Buildings", "Paths", "Front", "AlwaysFront", "AlwaysFront2"]
	assert(loader.layers.size() == expected_layers.size(), "Should have 6 layers")
	for layer_name: String in expected_layers:
		assert(loader.layers.has(layer_name), "Layer '%s' should exist" % layer_name)
		var layer_node: TileMapLayer = loader.layers[layer_name]
		assert(layer_node != null, "Layer node should not be null")
		assert(layer_node.tile_set != null, "Layer node must have tile_set assigned")

	# Check tile counts and properties
	print("[Test] Farm diggable cells count: %d" % loader.diggable_cells.size())
	assert(loader.diggable_cells.size() == 3680, "Expected 3680 diggable cells on Back layer")

	print("[Test] Farm impassable cells count: %d" % loader.impassable_cells.size())
	assert(loader.impassable_cells.size() == 1347, "Expected 1347 impassable cells on Buildings layer")

	# Ground tests: (64, 18 is dirt; 64, 14 is non-diggable grass/porch; 0, 0 is cliff on Buildings)
	assert(loader.is_tile_diggable(Vector2i(64, 18)), "Tile (64, 18) should be diggable dirt")
	assert(not loader.is_tile_diggable(Vector2i(64, 14)), "Tile (64, 14) should not be diggable (grass/porch)")
	assert(not loader.is_tile_passable(Vector2i(0, 0)), "Tile (0, 0) should be impassable cliff")
	assert(loader.is_tile_passable(Vector2i(64, 15)), "Tile (64, 15) should be passable ground")

	# Warps test
	print("[Test] Farm warps count: %d" % loader.warps.size())
	assert(loader.warps.size() >= 5, "Expected warps for BusStop, Forest, Backwoods, FarmCave")
	var bus_warp: Dictionary = loader.get_warp(Vector2i(80, 15))
	assert(bus_warp.get("target_map") == "BusStop", "Expected BusStop warp at (80, 15)")

	# Action test (Grandpa shrine at 8, 7)
	var shrine_action: String = loader.get_action(Vector2i(8, 7))
	assert("Farm.1" in shrine_action, "Expected Grandpa shrine action at (8, 7)")

	# Collision body check
	assert(loader.collision_body != null, "StaticBody2D collision body should be generated")
	assert(loader.collision_body.get_child_count() == 160, "Expected 160 merged collision shapes")
	print("[Test] Collision body verified with %d merged shapes." % loader.collision_body.get_child_count())

	loader.queue_free()

func test_farmhouse_map_loading() -> void:
	var loader: MapLoader = MapLoader.new()
	loader.auto_load_on_ready = false
	add_child(loader)

	var ok: bool = loader.load_map("user://vanilla_data/Maps/FarmHouse.json")
	assert(ok, "FarmHouse map should load successfully")
	assert(loader.map_id == "FarmHouse", "Map ID should be FarmHouse")
	assert(loader.map_size == Vector2i(12, 12), "FarmHouse map should be 12x12 tiles")
	assert(loader.layers.size() == 3, "FarmHouse should have 3 layers")

	print("[Test] FarmHouse loaded: %dx%d with %d layers." % [loader.map_size.x, loader.map_size.y, loader.layers.size()])
	loader.queue_free()
