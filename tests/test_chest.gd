extends Node

## Automated test suite for Inventory Expansion (Backpack Upgrades),
## ItemContainer data storage, Chest world placement, pickup, and ChestUI modal transfers.

func _ready() -> void:
	print("=======================================================")
	print("--- Running Inventory Expansion & Chest Storage Suite ---")
	print("=======================================================")

	test_backpack_expansion()
	test_hotbar_row_cycling()
	test_item_container_storage()
	test_inventory_container_transfers()
	test_chest_world_placement_and_pickup()
	test_chest_ui_modal_interactions()
	test_chest_location_persistence()

	print("=======================================================")
	print("--- ALL INVENTORY & CHEST TESTS PASSED SUCCESSFULLY! ---")
	print("=======================================================")
	get_tree().quit(0)


func test_backpack_expansion() -> void:
	print("[Test 1] Testing InventoryManager capacity expansion...")
	var inv: InventoryManager = InventoryManager.new()
	add_child(inv)

	assert(inv.total_slots == 12, "Default capacity should be 12 slots")
	assert(inv.can_expand(), "Should be able to expand from 12 slots")

	# Put items in starting slots
	inv.set_slot(0, &"vanilla:hoe", 1)
	inv.set_slot(11, &"vanilla:472", 10)

	var capacity_signals: Array[int] = []
	inv.capacity_changed.connect(func(cap: int) -> void:
		capacity_signals.append(cap)
	)

	# Upgrade to Large Backpack (24 slots)
	var ok: bool = inv.upgrade_capacity(24)
	assert(ok, "Upgrade to 24 should succeed")
	assert(inv.total_slots == 24, "Total slots should now be 24")
	assert(inv.slots.size() == 24, "Slots array size should be 24")
	assert(inv.get_slot(0).item_id == &"vanilla:hoe", "Slot 0 item must be preserved")
	assert(inv.get_slot(11).item_id == &"vanilla:472", "Slot 11 item must be preserved")
	assert(inv.get_slot(12).is_empty(), "Newly expanded slots must be empty")
	assert(capacity_signals.size() == 1 and capacity_signals[0] == 24, "Signal should emit 24")

	# Upgrade to Deluxe Backpack (36 slots)
	ok = inv.upgrade_capacity(36)
	assert(ok, "Upgrade to 36 should succeed")
	assert(inv.total_slots == 36, "Total slots should now be 36")
	assert(not inv.can_expand(), "Cannot expand past maximum 36 slots")

	# Duplicate or downgrade attempts must fail
	ok = inv.upgrade_capacity(36)
	assert(not ok, "Cannot upgrade to same capacity")
	ok = inv.upgrade_capacity(24)
	assert(not ok, "Cannot downgrade capacity")

	inv.queue_free()
	print("[Test 1] Inventory expansion verified.")


func test_hotbar_row_cycling() -> void:
	print("[Test 2] Testing hotbar row cycling (Tab key rotation)...")
	var inv: InventoryManager = InventoryManager.new()
	add_child(inv)
	inv.upgrade_capacity(24) # 2 rows of 12

	inv.clear_all()
	# Row 0: slot 0 has hoe
	inv.set_slot(0, &"vanilla:hoe", 1)
	# Row 1: slot 12 has axe
	inv.set_slot(12, &"vanilla:axe", 1)

	assert(inv.get_slot(0).item_id == &"vanilla:hoe", "Active hotbar slot 0 has hoe")

	# Cycle row
	inv.cycle_hotbar_row()
	assert(inv.get_slot(0).item_id == &"vanilla:axe", "After cycling, hotbar slot 0 now has axe")
	assert(inv.get_slot(12).item_id == &"vanilla:hoe", "Row 1 slot 12 now has hoe")

	# Cycle row again -> returns to original
	inv.cycle_hotbar_row()
	assert(inv.get_slot(0).item_id == &"vanilla:hoe", "Second cycle returns original row")

	inv.queue_free()
	print("[Test 2] Hotbar row cycling verified.")


func test_item_container_storage() -> void:
	print("[Test 3] Testing ItemContainer stacking, removal, and serialization...")
	var container: ItemContainer = ItemContainer.new(36, "TestChest")
	assert(container.capacity == 36, "Container capacity must be 36")
	assert(container.is_empty(), "New container must be empty")

	# Add items
	var remaining: int = container.add_item(&"vanilla:24", 50) # Parsnip
	assert(remaining == 0, "All 50 Parsnips should be added")
	assert(not container.is_empty(), "Container is no longer empty")
	assert(container.get_slot(0).count == 50, "Slot 0 should hold 50 Parsnips")

	# Add same item to test stacking
	remaining = container.add_item(&"vanilla:24", 20)
	assert(remaining == 0, "Stacking into slot 0 should succeed")
	assert(container.get_slot(0).count == 70, "Slot 0 should hold 70 Parsnips")

	# Remove partial
	container.remove_item_at(0, 30)
	assert(container.get_slot(0).count == 40, "Slot 0 should hold 40 after removing 30")

	# Add second item
	container.set_slot(5, &"vanilla:hoe", 1)
	assert(container.get_slot(5).item_id == &"vanilla:hoe", "Slot 5 should hold Hoe")

	# Organize
	container.organize()
	# Organized items should be grouped at the beginning
	assert(not container.get_slot(0).is_empty(), "First slot must have an item after organize")
	assert(not container.get_slot(1).is_empty(), "Second slot must have an item after organize")

	# Test serialization to_dict / from_dict
	var serialized: Dictionary = container.to_dict()
	assert(serialized["capacity"] == 36, "Serialized capacity matches")
	assert(serialized["name"] == "TestChest", "Serialized name matches")

	var restored: ItemContainer = ItemContainer.from_dict(serialized)
	assert(restored.capacity == 36, "Restored capacity matches")
	assert(restored.container_name == "TestChest", "Restored name matches")
	assert(not restored.get_slot(0).is_empty(), "Restored slot 0 is populated")

	print("[Test 3] ItemContainer storage verified.")


func test_inventory_container_transfers() -> void:
	print("[Test 4] Testing deposit and withdraw between Inventory and Container...")
	var inv: InventoryManager = InventoryManager.new()
	var container: ItemContainer = ItemContainer.new(36, "Chest")
	add_child(inv)

	inv.clear_all()
	inv.set_slot(0, &"vanilla:24", 15) # 15 Parsnips in player inv slot 0

	# 1. Deposit 5 items from player to container
	var ok: bool = container.deposit_from_inventory(inv, 0, 5)
	assert(ok, "Deposit of 5 items should succeed")
	assert(inv.get_slot(0).count == 10, "Player slot 0 should have 10 remaining")
	assert(container.get_slot(0).count == 5, "Container slot 0 should have 5")

	# 2. Deposit rest of stack (-1)
	ok = container.deposit_from_inventory(inv, 0, -1)
	assert(ok, "Full deposit should succeed")
	assert(inv.get_slot(0).is_empty(), "Player slot 0 should now be empty")
	assert(container.get_slot(0).count == 15, "Container slot 0 should now have all 15")

	# 3. Withdraw 1 item from container to player
	ok = container.withdraw_to_inventory(inv, 0, 1)
	assert(ok, "Withdraw of 1 item should succeed")
	assert(container.get_slot(0).count == 14, "Container should have 14 remaining")
	assert(inv.get_slot(0).count == 1, "Player should have 1")

	# 4. Withdraw remaining stack (-1)
	ok = container.withdraw_to_inventory(inv, 0, -1)
	assert(ok, "Withdraw of entire stack should succeed")
	assert(container.get_slot(0).is_empty(), "Container should now be empty")
	assert(inv.get_slot(0).count == 15, "Player should have all 15")

	inv.queue_free()
	print("[Test 4] Inventory and Container transfers verified.")


func test_chest_world_placement_and_pickup() -> void:
	print("[Test 5] Testing Chest world placement, obstacle validity, and pickup...")
	var chest_mgr: ChestManager = ChestManager.new()
	var inv: InventoryManager = InventoryManager.new()
	add_child(chest_mgr)
	add_child(inv)

	var farm_loc: StringName = &"Farm"
	var cell: Vector2i = Vector2i(65, 18)

	assert(chest_mgr.can_place_chest(farm_loc, cell), "Cell (65, 18) should be valid for placement")

	# Place chest
	var chest: Chest = chest_mgr.place_chest(farm_loc, cell)
	assert(chest != null, "Placed chest must exist")
	assert(chest_mgr.has_chest_at(farm_loc, cell), "ChestManager must register chest at cell")
	assert(chest.position == Vector2(65 * 16, 18 * 16), "Chest position matches cell world coordinates")
	assert(not chest_mgr.can_place_chest(farm_loc, cell), "Cannot place duplicate chest at occupied cell")

	# Open & Close
	assert(not chest.is_open, "Chest should start closed")
	chest.open()
	assert(chest.is_open, "Chest should be open")
	chest.close()
	assert(not chest.is_open, "Chest should be closed")

	# Test pickup when NOT empty
	chest.container.set_slot(0, &"vanilla:24", 5)
	assert(not chest.is_empty(), "Chest is not empty")
	var pickup_ok: bool = chest_mgr.try_pickup_chest(farm_loc, cell, inv)
	assert(not pickup_ok, "Cannot pick up non-empty chest")
	assert(chest_mgr.has_chest_at(farm_loc, cell), "Chest must remain in world when not empty")

	# Empty chest and pick up
	chest.container.clear_slot(0) if chest.container.has_method("clear_slot") else chest.container.remove_item_at(0, 5)
	assert(chest.is_empty(), "Chest is now empty")

	pickup_ok = chest_mgr.try_pickup_chest(farm_loc, cell, inv)
	assert(pickup_ok, "Pickup of empty chest must succeed")
	assert(not chest_mgr.has_chest_at(farm_loc, cell), "Chest must be removed from world")
	assert(inv.has_item(&"vanilla:chest", 1), "Player inventory should receive vanilla:chest item")

	chest_mgr.queue_free()
	inv.queue_free()
	print("[Test 5] Chest placement and pickup verified.")


func test_chest_ui_modal_interactions() -> void:
	print("[Test 6] Testing ChestUI modal slot click transfers...")
	var chest_ui_scene: PackedScene = load("res://src/ui/chest_ui.tscn")
	assert(chest_ui_scene != null, "chest_ui.tscn must exist")
	var chest_ui: ChestUI = chest_ui_scene.instantiate() as ChestUI
	add_child(chest_ui)

	var inv: InventoryManager = InventoryManager.new()
	var chest: Chest = Chest.new(Vector2i(10, 10), &"Farm")
	add_child(inv)
	add_child(chest)

	# Put Parsnips in chest slot 0, Seeds in player inv slot 0
	chest.container.set_slot(0, &"vanilla:24", 20)
	inv.clear_all()
	inv.set_slot(0, &"vanilla:472", 10)

	# Open chest UI
	chest_ui.open_chest(chest, inv)
	assert(chest_ui.visible, "ChestUI should be visible when opened")
	assert(chest.is_open, "Chest should be in open state")

	# Click chest slot 0: transfers Parsnips to player inventory
	chest_ui._on_chest_slot_clicked(0, false)
	assert(inv.has_item(&"vanilla:24", 20), "Player should receive 20 Parsnips from chest")
	assert(chest.container.get_slot(0).is_empty(), "Chest slot 0 should now be empty")

	# Click player slot 0 (Seeds): deposits Seeds into chest
	chest_ui._on_player_slot_clicked(0, false)
	assert(chest.container.get_slot(0).item_id == &"vanilla:472", "Chest should receive Seeds")
	assert(chest.container.get_slot(0).count == 10, "Chest should have 10 Seeds")

	# Close chest UI
	chest_ui.close_chest()
	assert(not chest_ui.visible, "ChestUI should be hidden when closed")
	assert(not chest.is_open, "Chest should revert to closed state")

	chest_ui.queue_free()
	inv.queue_free()
	chest.queue_free()
	print("[Test 6] ChestUI modal interactions verified.")


func test_chest_location_persistence() -> void:
	print("[Test 7] Testing chest visibility & persistence across location changes...")
	var chest_mgr: ChestManager = ChestManager.new()
	add_child(chest_mgr)

	var farm_chest: Chest = chest_mgr.place_chest(&"Farm", Vector2i(60, 15))
	var house_chest: Chest = chest_mgr.place_chest(&"FarmHouse", Vector2i(5, 5))

	# Farm is active location
	EventBus.location_changed.emit(&"", &"Farm", Vector2i.ZERO)
	assert(farm_chest.visible, "Farm chest should be visible while on Farm")
	assert(farm_chest.process_mode == Node.PROCESS_MODE_INHERIT, "Farm chest collision active")
	assert(not house_chest.visible, "FarmHouse chest should be hidden while on Farm")
	assert(house_chest.process_mode == Node.PROCESS_MODE_DISABLED, "FarmHouse chest collision disabled")

	# Warp to FarmHouse
	EventBus.location_changed.emit(&"Farm", &"FarmHouse", Vector2i.ZERO)
	assert(not farm_chest.visible, "Farm chest should be hidden while in FarmHouse")
	assert(farm_chest.process_mode == Node.PROCESS_MODE_DISABLED, "Farm chest collision disabled")
	assert(house_chest.visible, "FarmHouse chest should be visible while in FarmHouse")
	assert(house_chest.process_mode == Node.PROCESS_MODE_INHERIT, "FarmHouse chest collision active")

	chest_mgr.queue_free()
	print("[Test 7] Chest location persistence verified.")
