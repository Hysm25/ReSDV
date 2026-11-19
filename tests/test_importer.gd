extends Node

const GOGImporter = preload("res://src/importer/gog_importer.gd")

func _ready() -> void:
	print("--- Running GOG Importer & Vanilla Ingestion Verification Test ---")

	# Test 1: Check GOGImporter status
	var ready_status: bool = GOGImporter.is_vanilla_data_ready()
	print("[Test] GOGImporter.is_vanilla_data_ready() -> ", ready_status)
	assert(ready_status, "Vanilla data should be ready in user://vanilla_data/")

	# Test 2: Check ContentRegistry items count
	var all_items: Array[ItemData] = ContentRegistry.get_all_items()
	print("[Test] Registered Items count: ", all_items.size())
	assert(all_items.size() >= 790, "Expected at least 790 vanilla items registered")

	# Test 3: Check specific items (Parsnip 24, Parsnip Seeds 472, Ancient Fruit 454)
	var parsnip: ItemData = ContentRegistry.get_item(&"24")
	assert(parsnip != null, "Item 24 (Parsnip) not found in registry")
	print("[Test] Item 24: Name='%s', Price=%d, Edibility=%d" % [parsnip.name, parsnip.price, parsnip.edibility])
	assert(parsnip.name == "Parsnip", "Item 24 name should be 'Parsnip'")
	assert(parsnip.price == 35, "Parsnip price should be 35")
	assert(parsnip.edibility == 10, "Parsnip edibility should be 10")
	assert(parsnip.is_edible(), "Parsnip should be edible")

	var parsnip_seeds: ItemData = ContentRegistry.get_item(&"472")
	assert(parsnip_seeds != null, "Item 472 (Parsnip Seeds) not found in registry")
	print("[Test] Item 472: Name='%s', Price=%d" % [parsnip_seeds.name, parsnip_seeds.price])
	assert(parsnip_seeds.name == "Parsnip Seeds", "Item 472 name should be 'Parsnip Seeds'")
	assert(parsnip_seeds.category == ItemData.Category.SEED, "Item 472 should be category SEED")

	var ancient_fruit: ItemData = ContentRegistry.get_item(&"454")
	assert(ancient_fruit != null, "Item 454 (Ancient Fruit) not found in registry")
	print("[Test] Item 454: Name='%s', Price=%d" % [ancient_fruit.name, ancient_fruit.price])
	assert(ancient_fruit.name == "Ancient Fruit", "Item 454 name should be 'Ancient Fruit'")
	assert(ancient_fruit.price == 550, "Ancient Fruit price should be 550")

	# Test 4: Check ContentRegistry crops count
	var all_crops: Array[CropData] = ContentRegistry.get_all_crops()
	print("[Test] Registered Crops count: ", all_crops.size())
	assert(all_crops.size() == 50, "Expected exactly 50 vanilla crops registered")

	# Test 5: Check specific crops (Parsnip 472, Ancient Fruit 499, Qi Fruit 890)
	var parsnip_crop: CropData = ContentRegistry.get_crop(&"472")
	assert(parsnip_crop != null, "Crop 472 (Parsnip Crop) not found in registry")
	print("[Test] Crop 472: Harvest='%s', Seasons=%s, Phases=%s" % [parsnip_crop.harvest_item_id, str(parsnip_crop.seasons), str(parsnip_crop.growth_phase_days)])
	assert(parsnip_crop.harvest_item_id == &"vanilla:24", "Crop 472 harvest should be vanilla:24")
	assert(parsnip_crop.get_total_growth_days() == 4, "Parsnip should take 4 days to grow")
	assert(parsnip_crop.can_grow_in_season("spring"), "Parsnip should grow in spring")
	assert(not parsnip_crop.can_grow_in_season("summer"), "Parsnip should not grow in summer")

	var ancient_crop: CropData = ContentRegistry.get_crop(&"499")
	assert(ancient_crop != null, "Crop 499 (Ancient Fruit Crop) not found in registry")
	print("[Test] Crop 499: Harvest='%s', Regrow=%d" % [ancient_crop.harvest_item_id, ancient_crop.regrow_after_harvest_days])
	assert(ancient_crop.harvest_item_id == &"vanilla:454", "Crop 499 harvest should be vanilla:454")
	assert(ancient_crop.regrow_after_harvest_days == 7, "Ancient fruit regrow should be 7 days")
	assert(ancient_crop.can_grow_in_season("spring") and ancient_crop.can_grow_in_season("summer") and ancient_crop.can_grow_in_season("fall"), "Ancient Fruit should grow in Spring, Summer, Fall")

	print("--- All Importer & Vanilla Ingestion Verifications Passed Successfully! ---")
	get_tree().quit(0)
