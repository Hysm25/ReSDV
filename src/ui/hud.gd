class_name HUD
extends CanvasLayer

## Minimal Stardew Valley styled HUD for the Vertical Slice.
## Displays in-game calendar, clock, active tool, and harvested items.

@onready var clock_label: Label = $ClockPanel/VBox/ClockLabel
@onready var date_label: Label = $ClockPanel/VBox/DateLabel
@onready var tool_label: Label = $ToolPanel/ToolLabel
@onready var harvest_label: Label = $ToolPanel/HarvestLabel
@onready var hotbar_ui: HotbarUI = $HotbarUI
@onready var energy_bar: ProgressBar = get_node_or_null("EnergyPanel/VBox/EnergyBar") as ProgressBar
@onready var energy_label: Label = get_node_or_null("EnergyPanel/VBox/EnergyLabel") as Label
@onready var status_label: Label = get_node_or_null("EnergyPanel/VBox/StatusLabel") as Label

var _current_season: String = "Spring"
var _current_day: int = 1
var _current_year: int = 1
var _formatted_time: String = "6:00 AM"

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.time_ticked.connect(_on_time_ticked)
	EventBus.crop_harvested.connect(_on_crop_harvested)
	EventBus.player_energy_changed.connect(_on_energy_changed)
	EventBus.player_exhausted.connect(_on_player_exhausted)
	_update_display()

func bind_inventory(mgr: InventoryManager) -> void:
	if hotbar_ui != null:
		hotbar_ui.bind_inventory(mgr)

func update_active_tool(tool_name: String) -> void:
	if tool_label != null:
		tool_label.text = "Active: " + tool_name

func update_harvest_count(total_harvested: int) -> void:
	if harvest_label != null:
		harvest_label.text = "Parsnips in Bag: %d" % total_harvested

func _on_day_started(day: int, season: String, year: int) -> void:
	_current_day = day
	_current_season = season.capitalize()
	_current_year = year
	_update_display()

func _on_time_ticked(time: int) -> void:
	var hours_24: int = (time / 100) % 24
	var mins: int = time % 100
	var suffix: String = "AM" if (hours_24 < 12 or hours_24 >= 24) else "PM"
	var display_hours: int = hours_24 % 12
	if display_hours == 0:
		display_hours = 12
	_formatted_time = "%d:%02d %s" % [display_hours, mins, suffix]
	_update_display()

func _on_crop_harvested(_cell: Vector2i, _crop_id: StringName, yield_id: StringName, count: int) -> void:
	print("[HUD] Harvest Notification: %s (+%d)" % [yield_id, count])

func _on_energy_changed(current: float, max_val: float) -> void:
	if energy_bar != null:
		energy_bar.max_value = max_val
		energy_bar.value = maxf(current, 0.0)
	if energy_label != null:
		energy_label.text = "%d" % int(round(current))
	_update_energy_color(current, max_val)

func _on_player_exhausted(is_exhausted: bool) -> void:
	if status_label != null:
		if is_exhausted:
			status_label.text = "TIRED!"
			status_label.modulate = Color(1.0, 0.3, 0.2)
		else:
			status_label.text = "Energy"
			status_label.modulate = Color.WHITE

func _update_energy_color(current: float, max_val: float) -> void:
	if energy_bar == null:
		return
	var ratio: float = current / max_val if max_val > 0.0 else 0.0
	if ratio > 0.5:
		energy_bar.modulate = Color(0.3, 0.9, 0.3)
	elif ratio > 0.2:
		energy_bar.modulate = Color(0.95, 0.8, 0.2)
	elif ratio > 0.0:
		energy_bar.modulate = Color(0.95, 0.4, 0.1)
	else:
		energy_bar.modulate = Color(0.9, 0.15, 0.15)

func _update_display() -> void:
	if date_label != null:
		date_label.text = "%s %d, Yr %d" % [_current_season, _current_day, _current_year]
	if clock_label != null:
		clock_label.text = _formatted_time
