extends Node

## Automated test suite verifying ContentRegistry item icons, InventorySlot,
## InventoryManager stacking/removal, HotbarUI rendering, and Player integration.

func _ready() -> void:
	print("=======================================================")
	print("--- Running Inventory & Hotbar UI Full Integration ---")
	print("=======================================================")

	test_content_registry_icons()
	test_inventory_slot()
	test_inventory_manager()
	test_hotbar_ui()
	test_player_inventory_integration()

	print("=======================================================")
	print("--- ALL INVENTORY & HOTBAR TESTS PASSED! ---")
	print("=======================================================")
	get_tree().quit(0)

func test_content_registry_icons() -> void:
	print("[Test 1] ContentRegistry tool & item icons...")
	# Tools from tools.png
	var hoe_icon: AtlasTexture = ContentRegistry.get_item_icon(&"vanilla:hoe")
	assert(hoe_icon != null, "Hoe icon must not be null")
	assert(hoe_icon.region.size == Vector2(16, 16), "Hoe icon region must be 16x16")
	assert(hoe_icon.atlas != null, "Hoe icon atlas must be valid")

	var can_icon: AtlasTexture = ContentRegistry.get_item_icon(&"vanilla:watering_can")
	assert(can_icon != null, "Watering Can icon must not be null")
	assert(can_icon.region.size == Vector2(16, 16), "Watering Can icon region must be 16x16")

	# Items from springobjects.png
	var parsnip_icon: AtlasTexture = ContentRegistry.get_item_icon(&"vanilla:24")
	assert(parsnip_icon != null, "Parsnip icon must not be null")
	assert(parsnip_icon.region.size == Vector2(16, 16), "Parsnip icon region must be 16x16")

	var seeds_icon: AtlasTexture = ContentRegistry.get_item_icon(&"vanilla:472")
	assert(seeds_icon != null, "Parsnip Seeds icon must not be null")
	assert(seeds_icon.region.size == Vector2(16, 16), "Parsnip Seeds icon region must be 16x16")

	print("[Test 1] ContentRegistry icons verified.")

func test_inventory_slot() -> void:
	print("[Test 2] InventorySlot serialization and data queries...")
	var slot: InventorySlot = InventorySlot.new(&"vanilla:24", 10)
	assert(not slot.is_empty(), "Slot should not be empty")
	assert(slot.get_item_name() == "Parsnip", "Slot item name mismatch")
	assert(slot.get_icon() != null, "Slot icon should be populated")

	var dict: Dictionary = slot.to_dict()
	assert(dict["item_id"] == "vanilla:24", "to_dict item_id mismatch")
	assert(dict["count"] == 10, "to_dict count mismatch")

	var restored: InventorySlot = InventorySlot.from_dict(dict)
	assert(restored.item_id == &"vanilla:24", "from_dict item_id mismatch")
	assert(restored.count == 10, "from_dict count mismatch")

	slot.clear()
	assert(slot.is_empty(), "Cleared slot must be empty")
	print("[Test 2] InventorySlot verified.")

func test_inventory_manager() -> void:
	print("[Test 3] InventoryManager stacking, removal, and selection...")
	var mgr: InventoryManager = InventoryManager.new()
	mgr.auto_starter_inventory = false
	add_child(mgr)

	mgr.initialize_starter_inventory()
	assert(mgr.get_slot(0).item_id == &"vanilla:hoe", "Slot 0 should be Hoe")
	assert(mgr.get_slot(1).item_id == &"vanilla:watering_can", "Slot 1 should be Watering Can")
	assert(mgr.get_slot(2).item_id == &"vanilla:axe", "Slot 2 should be Axe")
	assert(mgr.get_slot(3).item_id == &"vanilla:pickaxe", "Slot 3 should be Pickaxe")
	assert(mgr.get_slot(4).item_id == &"vanilla:472", "Slot 4 should be Parsnip Seeds")
	assert(mgr.get_slot(4).count == 15, "Slot 4 count should be 15")
	assert(mgr.get_slot(5).is_empty(), "Slot 5 should be empty")

	# Test Stacking onto existing slot 4
	var leftover: int = mgr.add_item(&"vanilla:472", 5)
	assert(leftover == 0, "All seeds should be added")
	assert(mgr.get_slot(4).count == 20, "Slot 4 should now have 20 seeds")

	# Test Adding new item into first empty slot (slot 5)
	leftover = mgr.add_item(&"vanilla:24", 4)
	assert(leftover == 0, "Parsnips should be added")
	assert(mgr.get_slot(5).item_id == &"vanilla:24", "Slot 5 should contain Parsnip")
	assert(mgr.get_slot(5).count == 4, "Slot 5 count should be 4")
	assert(mgr.get_item_count(&"vanilla:24") == 4, "get_item_count should return 4")

	# Test Removing items
	assert(mgr.remove_item_at(4, 2), "remove_item_at should succeed")
	assert(mgr.get_slot(4).count == 18, "Slot 4 count should be 18")

	assert(mgr.remove_item(&"vanilla:24", 4), "remove_item should succeed")
	assert(mgr.get_slot(5).is_empty(), "Slot 5 should now be empty")
	assert(mgr.get_item_count(&"vanilla:24") == 0, "Parsnip count should be 0")

	# Test Slot swapping
	assert(mgr.swap_slots(0, 1), "swap_slots should succeed")
	assert(mgr.get_slot(0).item_id == &"vanilla:watering_can", "Slot 0 should now be Watering Can")
	assert(mgr.get_slot(1).item_id == &"vanilla:hoe", "Slot 1 should now be Hoe")

	# Test Slot selection
	mgr.select_slot(4)
	assert(mgr.selected_slot_index == 4, "Selected slot should be 4")
	assert(mgr.get_selected_item_id() == &"vanilla:472", "Selected item should be Parsnip Seeds")

	mgr.select_next_slot()
	assert(mgr.selected_slot_index == 5, "Next slot should be 5")
	mgr.select_previous_slot()
	assert(mgr.selected_slot_index == 4, "Previous slot should be 4")

	mgr.free()
	print("[Test 3] InventoryManager verified.")

func test_hotbar_ui() -> void:
	print("[Test 4] HotbarUI view binding and slot rendering...")
	var mgr: InventoryManager = InventoryManager.new()
	add_child(mgr)
	mgr.initialize_starter_inventory()

	var hotbar: HotbarUI = HotbarUI.new()
	add_child(hotbar)
	hotbar.bind_inventory(mgr)

	assert(hotbar.slot_views.size() == 12, "Hotbar must contain 12 slot views")

	# Slot 0 should show Watering Can (or Hoe depending on starter)
	var slot0_view: HotbarSlotUI = hotbar.slot_views[0]
	assert(slot0_view.icon_rect.texture != null, "Slot 0 icon must be set")
	assert(slot0_view.is_selected, "Slot 0 should be selected initially")

	# Slot 4 (Parsnip Seeds)
	var slot4_view: HotbarSlotUI = hotbar.slot_views[4]
	assert(slot4_view.icon_rect.texture != null, "Slot 4 icon must be set")
	assert(slot4_view.count_label.text == "15", "Slot 4 count label must show 15")

	# Change selection to slot 4
	mgr.select_slot(4)
	assert(hotbar.slot_views[4].is_selected, "Slot 4 view must be selected")
	assert(not hotbar.slot_views[0].is_selected, "Slot 0 view must no longer be selected")

	hotbar.free()
	mgr.free()
	print("[Test 4] HotbarUI verified.")

func test_player_inventory_integration() -> void:
	print("[Test 5] Player tool & seed usage via InventoryManager...")
	var farm_grid: FarmGrid = FarmGrid.new()
	farm_grid.grid_width = 30
	farm_grid.grid_height = 30
	add_child(farm_grid)

	var crop_mgr: CropManager = CropManager.new()
	crop_mgr.farm_grid = farm_grid
	add_child(crop_mgr)

	var mgr: InventoryManager = InventoryManager.new()
	add_child(mgr)
	mgr.initialize_starter_inventory()

	var player: Player = Player.new()
	player.farm_grid = farm_grid
	player.crop_manager = crop_mgr
	player.inventory_manager = mgr
	add_child(player)

	var target: Vector2i = Vector2i(5, 5)
	player.target_cell = target

	# 1. Till soil using active Hoe in inventory (slot 0)
	mgr.select_slot(0)
	assert(mgr.get_selected_item_id() == &"vanilla:hoe", "Slot 0 must be Hoe")
	var tilled: bool = player.use_active_tool()
	assert(tilled, "Tilling soil with inventory Hoe must succeed")
	assert(farm_grid.is_tilled(target), "Cell (5, 5) must be tilled")

	# 2. Plant seeds from inventory (slot 4: 15 Parsnip Seeds)
	mgr.select_slot(4)
	assert(mgr.get_selected_item_id() == &"vanilla:472", "Slot 4 must be Parsnip Seeds")
	var planted: bool = player.use_active_tool()
	assert(planted, "Planting Parsnip Seeds from inventory must succeed")
	assert(mgr.get_slot(4).count == 14, "Parsnip seeds count must decrement from 15 to 14")
	assert(crop_mgr.has_crop(target), "Crop must be planted at (5, 5)")

	# 3. Water soil using Watering Can in inventory (slot 1)
	mgr.select_slot(1)
	assert(mgr.get_selected_item_id() == &"vanilla:watering_can", "Slot 1 must be Watering Can")
	var watered: bool = player.use_active_tool()
	assert(watered, "Watering soil with inventory Watering Can must succeed")
	assert(farm_grid.is_watered(target), "Cell (5, 5) must be watered")

	# 4. Advance growth to mature and harvest
	var crop: CropManager.PlantedCrop = crop_mgr.get_crop(target)
	crop.current_phase = 4 # Force mature
	assert(crop.is_mature(), "Crop must be mature")

	var initial_parsnips: int = mgr.get_item_count(&"vanilla:24")
	var harvested: bool = player.use_active_tool()
	assert(harvested, "Harvesting mature crop must succeed")
	assert(mgr.get_item_count(&"vanilla:24") == initial_parsnips + 1, "InventoryManager must receive 1 Parsnip yield")

	farm_grid.queue_free()
	crop_mgr.queue_free()
	player.queue_free()
	mgr.queue_free()
	print("[Test 5] Player inventory integration verified.")
