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

# Player Status & Economy
signal player_energy_changed(new_energy: float, max_energy: float)
signal player_health_changed(new_health: float, max_health: float)
signal money_changed(new_amount: int, delta: int)
signal location_changed(from_map: StringName, to_map: StringName, target_cell: Vector2i)

# Content Registry & Data Ingestion
signal content_registered(category: StringName, id: StringName)
signal content_loading_started()
signal content_loading_finished(item_count: int, crop_count: int)
