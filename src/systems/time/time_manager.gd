class_name TimeManager
extends Node

## Manages the game clock, calendar days, seasons, and years for ReSDV.
## Ticks every 10 in-game minutes (default 7.0s real time) and communicates via EventBus.

signal tick_occurred(time: int)
signal day_advanced(day: int, season: String, year: int)

const DAYS_PER_SEASON: int = 28
const SEASONS: Array[String] = ["spring", "summer", "fall", "winter"]
const START_TIME: int = 600      # 06:00 AM
const PASS_OUT_TIME: int = 2600  # 02:00 AM next day (26:00)
const MINUTES_PER_TICK: int = 10

@export var seconds_per_tick: float = 7.0
@export var is_paused: bool = false

var current_year: int = 1
var current_season_index: int = 0
var current_day: int = 1
var current_time: int = START_TIME

var _tick_accumulator: float = 0.0

func _ready() -> void:
	# Emit initial day start on scene ready
	call_deferred(&"_emit_initial_day")

func _emit_initial_day() -> void:
	EventBus.day_started.emit(current_day, get_current_season(), current_year)
	EventBus.time_ticked.emit(current_time)

func _process(delta: float) -> void:
	if is_paused:
		return

	_tick_accumulator += delta
	if _tick_accumulator >= seconds_per_tick:
		_tick_accumulator -= seconds_per_tick
		advance_time(MINUTES_PER_TICK)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
		
	# Debug key: F1 or T to advance to next day immediately
	if event.keycode == KEY_F1 or event.keycode == KEY_T:
		print("[TimeManager] Debug key triggered: Fast-forwarding to next day.")
		advance_day()
	# Debug key: F2 to advance 1 hour (60 minutes)
	elif event.keycode == KEY_F2:
		advance_time(60)

func get_current_season() -> String:
	return SEASONS[current_season_index]

func advance_time(minutes: int = 10) -> void:
	var total_minutes: int = _time_to_minutes(current_time) + minutes
	current_time = _minutes_to_time(total_minutes)
	
	EventBus.time_ticked.emit(current_time)
	tick_occurred.emit(current_time)
	
	if current_time >= PASS_OUT_TIME:
		print("[TimeManager] Past 2:00 AM. Farmer passed out!")
		advance_day()

func advance_day() -> void:
	EventBus.day_ended.emit(current_day, get_current_season(), current_year)
	
	current_day += 1
	current_time = START_TIME
	_tick_accumulator = 0.0
	
	if current_day > DAYS_PER_SEASON:
		current_day = 1
		current_season_index += 1
		if current_season_index >= SEASONS.size():
			current_season_index = 0
			current_year += 1
			EventBus.year_changed.emit(current_year)
		EventBus.season_changed.emit(get_current_season(), current_year)
	
	print("[TimeManager] Day started: %s %d, Year %d at 06:00 AM" % [get_current_season().capitalize(), current_day, current_year])
	EventBus.day_started.emit(current_day, get_current_season(), current_year)
	EventBus.time_ticked.emit(current_time)
	day_advanced.emit(current_day, get_current_season(), current_year)

func get_formatted_time() -> String:
	var hours_24: int = (current_time / 100) % 24
	var mins: int = current_time % 100
	var suffix: String = "AM" if (hours_24 < 12 or hours_24 >= 24) else "PM"
	var display_hours: int = hours_24 % 12
	if display_hours == 0:
		display_hours = 12
	return "%d:%02d %s" % [display_hours, mins, suffix]

func _time_to_minutes(time: int) -> int:
	var hours: int = time / 100
	var mins: int = time % 100
	return hours * 60 + mins

func _minutes_to_time(minutes: int) -> int:
	var hours: int = minutes / 60
	var mins: int = minutes % 60
	return hours * 100 + mins
