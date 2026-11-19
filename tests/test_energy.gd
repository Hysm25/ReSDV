extends Node

## Automated test suite for EnergyManager, Stamina mechanics, Fatigue states,
## Food consumption, and Player tool animations.

func _ready() -> void:
	print("=======================================================")
	print("--- Running Energy & Stamina System Test Suite ---")
	print("=======================================================")

	test_initial_state()
	test_tool_energy_costs()
	test_exhaustion_threshold()
	test_passed_out_threshold()
	test_food_consumption()
	test_overnight_recovery()
	test_player_speed_and_tool_anim()
	test_hud_energy_display()

	print("=======================================================")
	print("--- ALL ENERGY & STAMINA TESTS PASSED SUCCESSFULLY! ---")
	print("=======================================================")
	get_tree().quit(0)


func test_initial_state() -> void:
	print("[Test 1] Testing EnergyManager initial values and signals...")
	var mgr: EnergyManager = EnergyManager.new()
	assert(mgr.current_energy == 270.0, "Default energy should be 270.0")
	assert(mgr.max_energy == 270.0, "Default max energy should be 270.0")
	assert(not mgr.is_exhausted, "Player should not start exhausted")
	assert(not mgr.is_passed_out(), "Player should not start passed out")
	assert(mgr.can_use_tool(), "Player should be able to use tools initially")
	mgr.free()
	print("[Test 1] Initial state verified.")


func test_tool_energy_costs() -> void:
	print("[Test 2] Testing individual tool energy costs...")
	var mgr: EnergyManager = EnergyManager.new()

	assert(mgr.get_tool_cost(&"vanilla:hoe") == 2.0, "Hoe should cost 2.0 stamina")
	assert(mgr.get_tool_cost(&"vanilla:watering_can") == 2.0, "Watering Can should cost 2.0 stamina")
	assert(mgr.get_tool_cost(&"vanilla:axe") == 2.0, "Axe should cost 2.0 stamina")
	assert(mgr.get_tool_cost(&"vanilla:pickaxe") == 2.0, "Pickaxe should cost 2.0 stamina")
	assert(mgr.get_tool_cost(&"vanilla:scythe") == 0.0, "Scythe should cost 0.0 stamina")

	# Hoe usage
	var ok: bool = mgr.consume_tool_energy(&"vanilla:hoe")
	assert(ok, "Hoe usage should succeed")
	assert(is_equal_approx(mgr.current_energy, 268.0), "Energy should be 268.0 after hoe use")

	# Scythe usage (free)
	ok = mgr.consume_tool_energy(&"vanilla:scythe")
	assert(ok, "Scythe usage should succeed")
	assert(is_equal_approx(mgr.current_energy, 268.0), "Energy should remain 268.0 after scythe use")

	# Watering can usage
	ok = mgr.consume_tool_energy(&"vanilla:watering_can")
	assert(ok, "Watering Can usage should succeed")
	assert(is_equal_approx(mgr.current_energy, 266.0), "Energy should be 266.0 after watering")

	mgr.free()
	print("[Test 2] Tool energy costs verified.")


func test_exhaustion_threshold() -> void:
	print("[Test 3] Testing exhaustion trigger at energy <= 0.0...")
	var mgr: EnergyManager = EnergyManager.new()

	var exhaustion_signal_fired: Array[bool] = [false]
	mgr.exhaustion_changed.connect(func(ex: bool) -> void:
		if ex:
			exhaustion_signal_fired[0] = true
	)

	# Consume almost all energy
	mgr.consume_energy(269.0)
	assert(is_equal_approx(mgr.current_energy, 1.0), "Energy should be 1.0")
	assert(not mgr.is_exhausted, "Should not be exhausted at 1.0 energy")

	# Cross exhaustion threshold
	mgr.consume_energy(2.0)
	assert(mgr.current_energy < 0.0, "Energy should be negative (-1.0)")
	assert(mgr.is_exhausted, "Should be exhausted when energy <= 0.0")
	assert(exhaustion_signal_fired[0], "exhaustion_changed signal should have fired")
	assert(mgr.can_use_tool(), "In vanilla, can still push through fatigue until -15.0")

	mgr.free()
	print("[Test 3] Exhaustion threshold verified.")


func test_passed_out_threshold() -> void:
	print("[Test 4] Testing passed out / incapacitation threshold at <= -15.0...")
	var mgr: EnergyManager = EnergyManager.new()

	var passed_out_fired: Array[bool] = [false]
	mgr.passed_out.connect(func() -> void:
		passed_out_fired[0] = true
	)

	# Deplete all energy into incapacitation
	mgr.consume_energy(270.0 + 20.0)
	assert(mgr.current_energy == -15.0, "Energy should be clamped at -15.0")
	assert(mgr.is_passed_out(), "Should be marked as passed out")
	assert(not mgr.can_use_tool(), "Cannot use tools when passed out / incapacitated")
	assert(passed_out_fired[0], "passed_out signal should have fired")

	# Further attempts to consume energy should fail
	var can_consume: bool = mgr.consume_energy(2.0)
	assert(not can_consume, "Cannot consume energy while passed out")

	mgr.free()
	print("[Test 4] Passed out threshold verified.")


func test_food_consumption() -> void:
	print("[Test 5] Testing edible food consumption and restoration...")
	var mgr: EnergyManager = EnergyManager.new()

	# Deplete energy to -5.0 (exhausted)
	mgr.consume_energy(275.0)
	assert(mgr.is_exhausted, "Should be exhausted")
	assert(mgr.current_energy == -5.0, "Energy should be -5.0")

	# Ingest inedible item
	var ate_hoe: bool = mgr.eat_item(&"vanilla:hoe")
	assert(not ate_hoe, "Cannot eat a hoe")
	assert(mgr.current_energy == -5.0, "Energy should remain unchanged")

	# Parsnip: vanilla:24 has edibility = 10 -> restores 10 * 2.5 = 25.0 energy
	var parsnip_item: ItemData = ContentRegistry.get_item(&"vanilla:24")
	assert(parsnip_item != null, "Parsnip item must be registered in ContentRegistry")
	assert(parsnip_item.is_edible(), "Parsnip must be edible")
	assert(parsnip_item.edibility == 10, "Parsnip edibility must be 10")

	var ate_parsnip: bool = mgr.eat_item(&"vanilla:24")
	assert(ate_parsnip, "Eating parsnip should succeed")
	# -5.0 + 25.0 = 20.0 energy -> should clear exhaustion!
	assert(is_equal_approx(mgr.current_energy, 20.0), "Energy should now be 20.0 (-5 + 25)")
	assert(not mgr.is_exhausted, "Exhaustion should be cleared after eating above 0.0 energy")

	# Cannot exceed max_energy
	mgr.restore_energy(500.0)
	assert(mgr.current_energy == 270.0, "Energy should not exceed max_energy")

	mgr.free()
	print("[Test 5] Food consumption verified.")


func test_overnight_recovery() -> void:
	print("[Test 6] Testing overnight sleep recovery (normal vs exhausted)...")
	var mgr: EnergyManager = EnergyManager.new()

	# Scenario A: Normal sleep recovery (100%)
	mgr.consume_energy(100.0)
	assert(mgr.current_energy == 170.0, "Current energy should be 170.0")
	assert(not mgr.is_exhausted, "Should not be exhausted")
	mgr.reset_for_new_day()
	assert(mgr.current_energy == 270.0, "Sleeping normal must restore 100% max energy")

	# Scenario B: Exhausted sleep recovery (50%)
	mgr.consume_energy(280.0)
	assert(mgr.is_exhausted, "Should be exhausted")
	mgr.reset_for_new_day()
	assert(is_equal_approx(mgr.current_energy, 135.0), "Sleeping exhausted must restore 50% max energy (135.0)")
	assert(not mgr.is_exhausted, "Exhaustion flag must be cleared on new day")

	mgr.free()
	print("[Test 6] Overnight recovery verified.")


func test_player_speed_and_tool_anim() -> void:
	print("[Test 7] Testing Player speed modulation and tool animation states...")
	var player: Player = Player.new()
	var mgr: EnergyManager = EnergyManager.new()
	var inv: InventoryManager = InventoryManager.new()
	add_child(player)
	add_child(mgr)
	add_child(inv)
	player.energy_manager = mgr
	player.inventory_manager = inv

	# Normal move speed
	assert(player.get_effective_move_speed() == 110.0, "Normal speed should be 110.0")

	# Trigger exhaustion
	mgr.consume_energy(275.0)
	assert(mgr.is_exhausted, "Manager should be exhausted")
	assert(player.get_effective_move_speed() == 55.0, "Exhausted speed should be halved to 55.0")

	# Test tool animation trigger
	assert(not player.is_using_tool, "Player should not start in tool animation")
	player._start_tool_animation(&"vanilla:hoe")
	assert(player.is_using_tool, "Player should be in tool animation")
	assert(player.animated_tool_id == &"vanilla:hoe", "Animated tool ID should be hoe")

	# Simulate physics process delta
	player._physics_process(0.25)
	assert(not player.is_using_tool, "Tool animation should finish after duration")

	# Test player eating from inventory
	mgr.restore_energy(270.0)
	mgr.consume_energy(275.0) # exhausted again at -5.0
	assert(mgr.is_exhausted, "Player should be exhausted")

	# Give player a parsnip in selected slot
	inv.clear_all()
	inv.set_slot(0, &"vanilla:24", 2)
	assert(inv.get_selected_slot().item_id == &"vanilla:24", "Slot 0 should have parsnip")

	var ate: bool = player.try_eat_selected_item()
	assert(ate, "Player should eat parsnip")
	assert(inv.get_selected_slot().count == 1, "Parsnip count should decrease to 1")
	assert(not mgr.is_exhausted, "Exhaustion cleared after eating parsnip")
	assert(player.get_effective_move_speed() == 110.0, "Speed restored to 110.0")

	player.queue_free()
	mgr.queue_free()
	inv.queue_free()
	print("[Test 7] Player speed and tool animation verified.")


func test_hud_energy_display() -> void:
	print("[Test 8] Testing HUD energy panel and reactive signal updates...")
	var hud_scene: PackedScene = load("res://src/ui/hud.tscn")
	assert(hud_scene != null, "hud.tscn must be loadable")
	var hud: HUD = hud_scene.instantiate() as HUD
	assert(hud != null, "hud instance must be valid")
	add_child(hud)

	# Emit energy change
	EventBus.player_energy_changed.emit(180.0, 270.0)
	assert(hud.energy_bar != null, "EnergyBar should exist in HUD")
	assert(is_equal_approx(hud.energy_bar.value, 180.0), "EnergyBar value should reflect 180.0")
	assert(hud.energy_label.text == "180", "EnergyLabel should display 180")

	# Emit exhaustion
	EventBus.player_exhausted.emit(true)
	assert(hud.status_label.text == "TIRED!", "StatusLabel should display TIRED! when exhausted")

	EventBus.player_exhausted.emit(false)
	assert(hud.status_label.text == "Energy", "StatusLabel should revert to Energy when recovered")

	hud.queue_free()
	print("[Test 8] HUD energy display verified.")
