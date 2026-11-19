extends Node

func _ready() -> void:
	print("--- Running Core Verification Test ---")
	
	# Verify EventBus signal
	var signal_received: Array[bool] = [false]
	EventBus.content_registered.connect(func(category: StringName, id: StringName) -> void:
		print("[Test] Signal received: content_registered -> ", category, " : ", id)
		signal_received[0] = true
	)
	
	# Create and register ItemData
	var item: ItemData = ItemData.new()
	item.name = "Parsnip"
	item.description = "A spring root."
	item.category = ItemData.Category.CROP
	item.price = 35
	item.edibility = 10
	var registered_item: bool = ContentRegistry.register_item(&"parsnip", item)
	assert(registered_item, "Item registration failed")
	assert(signal_received[0], "EventBus signal not received")
	assert(ContentRegistry.has_item(&"vanilla:parsnip"), "has_item failed with full namespace")
	assert(ContentRegistry.has_item(&"parsnip"), "has_item failed with auto namespace")
	
	var retrieved_item: ItemData = ContentRegistry.get_item(&"parsnip")
	assert(retrieved_item != null, "get_item returned null")
	assert(retrieved_item.name == "Parsnip", "retrieved_item name mismatch")
	assert(retrieved_item.is_edible(), "is_edible check failed")
	print("[Test] ItemData verification passed.")
	
	# Create and register CropData
	var crop: CropData = CropData.new()
	crop.seed_item_id = &"parsnip_seeds"
	crop.harvest_item_id = &"parsnip"
	crop.growth_phase_days = [1, 1, 1, 1]
	crop.seasons = ["spring"]
	var registered_crop: bool = ContentRegistry.register_crop(&"crop_parsnip", crop)
	assert(registered_crop, "Crop registration failed")
	assert(ContentRegistry.has_crop(&"vanilla:crop_parsnip"), "has_crop failed with full namespace")
	assert(ContentRegistry.has_crop(&"crop_parsnip"), "has_crop failed with auto namespace")
	
	var retrieved_crop: CropData = ContentRegistry.get_crop(&"crop_parsnip")
	assert(retrieved_crop != null, "get_crop returned null")
	assert(retrieved_crop.get_total_growth_days() == 4, "Total growth days mismatch")
	assert(retrieved_crop.can_grow_in_season("Spring"), "can_grow_in_season case sensitivity failed")
	assert(retrieved_crop.seed_item_id == &"vanilla:parsnip_seeds", "seed_item_id auto-namespace failed")
	print("[Test] CropData verification passed.")
	
	# Test dictionary serialization/deserialization
	var item_dict: Dictionary = item.to_dict()
	var restored_item: ItemData = ItemData.from_dict(item_dict)
	assert(restored_item.name == item.name, "Serialization name mismatch")
	assert(restored_item.category == item.category, "Serialization category mismatch")
	print("[Test] Serialization verification passed.")
	
	print("--- All Core Verifications Passed Successfully! ---")
	get_tree().quit(0)
