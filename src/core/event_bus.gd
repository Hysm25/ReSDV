extends Node

## Global typed EventBus singleton for ReSDV.
## Decouples systems and components through strictly typed signals.

# Calendar & Time System
signal day_started(day: int, season: String, year: int)
signal day_ended(day: int, season: String, year: int)
signal time_ticked(time_of_day: int)
signal season_changed(new_season: String, year: int)
signal year_changed(new_year: int)

# Farming System
signal crop_planted(cell: Vector2i, crop_id: StringName)
signal crop_watered(cell: Vector2i)
signal crop_grown(cell: Vector2i, new_stage: int)
signal crop_harvested(cell: Vector2i, crop_id: StringName, yield_item_id: StringName, count: int)
signal soil_tilled(cell: Vector2i)

# Inventory & Tools
signal item_used(item_id: StringName, target_position: Vector2)
signal item_selected(slot_index: int, item_id: StringName)
signal inventory_changed(slot_index: int, item_id: StringName, count: int)
signal inventory_capacity_changed(new_capacity: int)
signal chest_opened(chest: Node)
signal chest_closed(chest: Node)
signal chest_placed(cell: Vector2i, chest: Node)
signal chest_removed(cell: Vector2i)

# Player Status & Economy
signal player_energy_changed(new_energy: float, max_energy: float)
signal player_health_changed(new_health: float, max_health: float)
signal player_exhausted(is_exhausted: bool)
signal money_changed(new_amount: int, delta: int)
signal location_changed(from_map: StringName, to_map: StringName, target_cell: Vector2i)

# NPCs & Dialogue
signal dialogue_started(speaker_name: StringName, text: String, portrait_tex: Texture2D, emotion_idx: int)
signal dialogue_page_changed(page_index: int, total_pages: int, text: String, emotion_idx: int)
signal dialogue_ended(speaker_name: StringName)
signal npc_moved(npc_name: StringName, location_id: StringName, cell: Vector2i)
signal npc_schedule_point_reached(npc_name: StringName, point_index: int, point: Dictionary)

# World, Debris & Forage
signal debris_cleared(location_id: StringName, cell: Vector2i, debris_type: int, yield_item_id: StringName, count: int)
signal forage_collected(location_id: StringName, cell: Vector2i, item_id: StringName, count: int)

# Content Registry & Data Ingestion
signal content_registered(category: StringName, id: StringName)
signal content_loading_started()
signal content_loading_finished(item_count: int, crop_count: int)
