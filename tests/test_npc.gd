extends Node

## Automated test suite for DialogueEngine, ScheduleEngine, NPC movement,
## authentic character/portrait textures, and DialogueBoxUI modal interactions.

func _ready() -> void:
	print("=======================================================")
	print("--- Running NPC Schedules & Dialogue Engine Test Suite ---")
	print("=======================================================")

	test_dialogue_engine_parsing()
	test_dialogue_token_substitution()
	test_schedule_engine_parsing()
	test_schedule_time_evaluation()
	test_npc_textures_and_movement()
	test_npc_manager_coordination()
	test_player_npc_dialogue_interaction()

	print("=======================================================")
	print("--- ALL NPC & DIALOGUE TESTS PASSED SUCCESSFULLY! ---")
	print("=======================================================")
	get_tree().quit(0)


func test_dialogue_engine_parsing() -> void:
	print("[Test 1] Testing DialogueEngine authentic data loading and parsing...")
	var engine: DialogueEngine = DialogueEngine.new()

	# Test Robin's dialogue loading from JSON
	var robin_dict: Dictionary = engine.load_npc_dialogue(&"Robin")
	assert(not robin_dict.is_empty(), "Robin dialogue must load from vanilla data")
	assert(robin_dict.has("Introduction"), "Robin must have Introduction dialogue")

	var intro_raw: String = robin_dict["Introduction"]
	assert(intro_raw.contains("Have you met everyone in town yet?"), "Introduction text matches authentic dialogue")

	var pages: Array[Dictionary] = engine.parse_dialogue(intro_raw)
	assert(pages.size() >= 1, "Should have at least 1 page")
	assert(pages[0]["text"] == "Have you met everyone in town yet? That sounds exhausting.", "Clean text parsed")
	assert(pages[0]["emotion"] == 0, "Default emotion should be 0")

	# Test Lewis's dialogue loading
	var lewis_dict: Dictionary = engine.load_npc_dialogue(&"Lewis")
	assert(not lewis_dict.is_empty(), "Lewis dialogue must load from vanilla data")
	assert(lewis_dict.has("Introduction"), "Lewis must have Introduction dialogue")

	print("[Test 1] DialogueEngine data loading and parsing verified.")


func test_dialogue_token_substitution() -> void:
	print("[Test 2] Testing Stardew dialogue token replacements (@, %farm) and emotions...")
	var engine: DialogueEngine = DialogueEngine.new()

	var test_str: String = "Hello @! Welcome to %farm Farm.$h#$b#I hope you like it here.$s"
	var pages: Array[Dictionary] = engine.parse_dialogue(test_str, "Ash", "Sunny")

	assert(pages.size() == 2, "Should parse into 2 dialogue pages")
	assert(pages[0]["text"] == "Hello Ash! Welcome to Sunny Farm.", "Tokens @ and %farm substituted")
	assert(pages[0]["emotion"] == 1, "Emotion tag $h must parse as 1 (happy)")

	assert(pages[1]["text"] == "I hope you like it here.", "Page 2 text matches")
	assert(pages[1]["emotion"] == 2, "Emotion tag $s must parse as 2 (sad)")

	# Test numeric tag $6
	var numeric_test: String = "Here is some wood.$6"
	var num_pages: Array[Dictionary] = engine.parse_dialogue(numeric_test)
	assert(num_pages[0]["emotion"] == 6, "Numeric tag $6 must parse as 6")

	print("[Test 2] Token substitutions and emotion tags verified.")


func test_schedule_engine_parsing() -> void:
	print("[Test 3] Testing ScheduleEngine schedule string parsing...")
	var engine: ScheduleEngine = ScheduleEngine.new()

	# Robin schedule sample: "800 ScienceHouse 8 18 2/1700 Mountain 29 36 2/1930 ScienceHouse 16 5 0/2100 ScienceHouse 21 4 1 robin_sleep"
	var sched_str: String = "800 ScienceHouse 8 18 2/1700 Mountain 29 36 2/1930 ScienceHouse 16 5 0/2100 ScienceHouse 21 4 1 robin_sleep"
	var points: Array[Dictionary] = engine.parse_schedule_string(sched_str)

	assert(points.size() == 4, "Should parse exactly 4 schedule waypoints")

	# Point 0: 800
	assert(points[0]["time"] == 800, "Point 0 time is 800")
	assert(points[0]["location"] == &"ScienceHouse", "Point 0 location matches")
	assert(points[0]["cell"] == Vector2i(8, 18), "Point 0 cell matches (8, 18)")
	assert(points[0]["facing"] == Vector2i.DOWN, "Direction 2 is DOWN")

	# Point 1: 1700
	assert(points[1]["time"] == 1700, "Point 1 time is 1700")
	assert(points[1]["location"] == &"Mountain", "Point 1 location is Mountain")
	assert(points[1]["cell"] == Vector2i(29, 36), "Point 1 cell matches (29, 36)")

	# Point 3: 2100 with animation
	assert(points[3]["time"] == 2100, "Point 3 time is 2100")
	assert(points[3]["animation"] == "robin_sleep", "Point 3 animation is robin_sleep")
	assert(points[3]["facing"] == Vector2i.RIGHT, "Direction 1 is RIGHT")

	print("[Test 3] ScheduleEngine string parsing verified.")


func test_schedule_time_evaluation() -> void:
	print("[Test 4] Testing active schedule point resolution based on game time...")
	var engine: ScheduleEngine = ScheduleEngine.new()

	# Robin's authentic schedule
	var robin_sched: Dictionary = engine.load_npc_schedule(&"Robin")
	assert(not robin_sched.is_empty(), "Robin schedule data must load")

	# Before 800 AM (e.g. 600 AM) -> returns earliest point
	var pt_600: Dictionary = engine.get_active_schedule_point(&"Robin", 600, "Mon", "spring")
	assert(not pt_600.is_empty(), "Should resolve active point at 600 AM")
	assert(pt_600["time"] <= 800, "Resolved point should be morning schedule point")

	# At 1800 (6:00 PM) -> point at 1700 should be active
	var pt_1800: Dictionary = engine.get_active_schedule_point(&"Robin", 1800, "Mon", "spring")
	assert(pt_1800["time"] == 1700, "Point at 1700 should be active at 1800")

	print("[Test 4] Schedule time evaluation verified.")


func test_npc_textures_and_movement() -> void:
	print("[Test 5] Testing NPC sprite/portrait texture loading and movement...")
	var npc: NPC = NPC.new(&"Robin", Vector2i(10, 10), &"Farm")
	add_child(npc)

	# Verify textures loaded from vanilla_data
	assert(npc.character_texture != null, "Robin character sprite sheet must be loaded")
	assert(npc.portrait_texture != null, "Robin portrait sheet must be loaded")
	assert(npc.character_texture.get_size() == Vector2(64, 320), "Robin sprite sheet size must be 64x320")
	assert(npc.portrait_texture.get_size() == Vector2(128, 256), "Robin portrait sheet size must be 128x256")

	# Test ordered movement to adjacent tile (11, 10)
	var dest_reached: Array[bool] = [false]
	npc.schedule_destination_reached.connect(func(_target: Vector2i) -> void:
		dest_reached[0] = true
	)

	npc.walk_to_cell(Vector2i(11, 10))
	assert(npc.is_moving, "NPC should be in moving state")
	assert(npc.facing_direction == Vector2i.RIGHT, "NPC should face RIGHT while moving east")

	# Simulate physics process steps
	for _i in range(10):
		npc._physics_process(0.05)

	# Complete arrival
	npc._physics_process(0.5)
	assert(dest_reached[0], "schedule_destination_reached signal must fire on arrival")
	assert(not npc.is_moving, "NPC should stop moving after reaching destination")
	assert(npc.cell == Vector2i(11, 10), "NPC cell should update to destination (11, 10)")

	npc.queue_free()
	print("[Test 5] NPC textures and movement verified.")


func test_npc_manager_coordination() -> void:
	print("[Test 6] Testing NPCManager timeline scheduling and location visibility...")
	var manager: NPCManager = NPCManager.new()
	add_child(manager)

	var robin: NPC = manager.spawn_npc(&"Robin", Vector2i(15, 15), &"Farm")
	assert(manager.get_npc(&"Robin") == robin, "Manager should retrieve Robin")
	assert(manager.has_npc_at(&"Farm", Vector2i(15, 15)), "Manager should find Robin at (15, 15)")

	# Test location visibility switching
	manager.current_location_id = &"Farm"
	manager._update_npc_visibility(robin)
	assert(robin.visible, "Robin should be visible on Farm")

	# Switch location to FarmHouse
	EventBus.location_changed.emit(&"Farm", &"FarmHouse", Vector2i.ZERO)
	assert(not robin.visible, "Robin should be hidden when location is FarmHouse")
	assert(robin.process_mode == Node.PROCESS_MODE_DISABLED, "Robin process disabled while away")

	# Switch back
	EventBus.location_changed.emit(&"FarmHouse", &"Farm", Vector2i.ZERO)
	assert(robin.visible, "Robin should be visible again upon returning to Farm")

	manager.queue_free()
	print("[Test 6] NPCManager coordination verified.")


func test_player_npc_dialogue_interaction() -> void:
	print("[Test 7] Testing Player interaction with NPC and DialogueBoxUI modal...")
	var ui_scene: PackedScene = load("res://src/ui/dialogue_box_ui.tscn")
	assert(ui_scene != null, "dialogue_box_ui.tscn must exist")
	var dialogue_ui: DialogueBoxUI = ui_scene.instantiate() as DialogueBoxUI
	add_child(dialogue_ui)

	var manager: NPCManager = NPCManager.new()
	manager.dialogue_ui = dialogue_ui
	add_child(manager)

	var robin: NPC = manager.spawn_npc(&"Robin", Vector2i(64, 16), &"Farm")
	var player: Player = Player.new()
	player.global_position = Vector2(64 * 16 + 8, 15 * 16 + 8) # cell (64, 15)
	player.facing_direction = Vector2i.DOWN
	player.target_cell = Vector2i(64, 16) # target is Robin's cell
	player.npc_manager = manager
	player.dialogue_ui = dialogue_ui
	add_child(player)

	assert(not dialogue_ui.visible, "Dialogue UI should start hidden")
	assert(not robin.is_talking, "Robin should not start talking")

	# Trigger player action facing Robin
	var interacted: bool = player.use_active_tool()
	assert(interacted, "Player use_active_tool should interact with NPC")
	assert(robin.is_talking, "Robin should enter talking state")
	assert(robin.facing_direction == Vector2i.UP, "Robin should turn UP to face player")
	assert(dialogue_ui.visible, "DialogueBoxUI should become visible")
	assert(dialogue_ui.name_label.text == "Robin", "Dialogue nameplate should display Robin")
	assert(dialogue_ui.text_label.text.length() > 0, "Dialogue text should be populated")
	assert(dialogue_ui.portrait_rect.visible, "Portrait should be visible for Robin")

	# Advance / close dialogue
	dialogue_ui.advance_page()
	# If multiple pages or single page, advancing to end closes dialogue
	if dialogue_ui.visible:
		dialogue_ui.advance_page()

	assert(not dialogue_ui.visible, "DialogueBoxUI should close")
	assert(not robin.is_talking, "Robin should exit talking state")

	dialogue_ui.queue_free()
	manager.queue_free()
	player.queue_free()
	print("[Test 7] Player-NPC dialogue interaction verified.")
