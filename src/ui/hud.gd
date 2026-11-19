class_name HUD
extends CanvasLayer

## Minimal Stardew Valley styled HUD for the Vertical Slice.
## Displays in-game calendar, clock, active tool, and harvested items.

@onready var clock_label: Label = $ClockPanel/VBox/ClockLabel
@onready var date_label: Label = $ClockPanel/VBox/DateLabel
@onready var tool_label: Label = $ToolPanel/ToolLabel
@onready var harvest_label: Label = $ToolPanel/HarvestLabel
@onready var hotbar_ui: HotbarUI = $HotbarUI

var _current_season: String = "Spring"
var _current_day: int = 1
var _current_year: int = 1
var _formatted_time: String = "6:00 AM"

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.time_ticked.connect(_on_time_ticked)
	EventBus.crop_harvested.connect(_on_crop_harvested)
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

func _update_display() -> void:
	if date_label != null:
		date_label.text = "%s %d, Yr %d" % [_current_season, _current_day, _current_year]
	if clock_label != null:
		clock_label.text = _formatted_time
