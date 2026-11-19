class_name EnergyManager
extends Node

## Player stamina, fatigue, and energy management system for ReSDV.
## Manages stamina consumption per tool, exhaustion states, edible item recovery,
## and overnight sleep restoration adhering strictly to vanilla Stardew Valley mechanics.

signal energy_changed(current: float, max_val: float)
signal exhaustion_changed(is_exhausted: bool)
signal passed_out()

const DEFAULT_MAX_ENERGY: float = 270.0
const EXHAUSTION_THRESHOLD: float = 0.0
const PASSED_OUT_THRESHOLD: float = -15.0
const BASE_TOOL_COST: float = 2.0
const OVERNIGHT_EXHAUSTED_RECOVERY_RATIO: float = 0.5

const TOOL_ENERGY_COSTS: Dictionary[StringName, float] = {
	&"vanilla:hoe": 2.0,
	&"vanilla:watering_can": 2.0,
	&"vanilla:axe": 2.0,
	&"vanilla:pickaxe": 2.0,
	&"vanilla:scythe": 0.0,
}

@export var max_energy: float = DEFAULT_MAX_ENERGY
@export var current_energy: float = DEFAULT_MAX_ENERGY

var is_exhausted: bool = false


func _ready() -> void:
	if is_instance_valid(EventBus):
		EventBus.day_started.connect(_on_day_started)
		# Emit initial energy state
		EventBus.player_energy_changed.emit(current_energy, max_energy)
		EventBus.player_exhausted.emit(is_exhausted)


func get_tool_cost(tool_id: StringName) -> float:
	if TOOL_ENERGY_COSTS.has(tool_id):
		return TOOL_ENERGY_COSTS[tool_id]
	# Fallback for unrecognized tools
	var id_str: String = String(tool_id)
	if id_str.contains("hoe") or id_str.contains("water") or id_str.contains("axe") or id_str.contains("pickaxe"):
		return BASE_TOOL_COST
	elif id_str.contains("scythe"):
		return 0.0
	return 0.0


func can_use_tool(_tool_id: StringName = &"") -> bool:
	# In vanilla, player can work until -15.0. Once <= -15.0, player is incapacitated.
	return not is_passed_out()


func consume_tool_energy(tool_id: StringName) -> bool:
	var cost: float = get_tool_cost(tool_id)
	if cost <= 0.0:
		return true
	return consume_energy(cost)


func consume_energy(amount: float) -> bool:
	if is_passed_out():
		return false
	
	current_energy -= amount
	
	# Check exhaustion
	if current_energy <= EXHAUSTION_THRESHOLD and not is_exhausted:
		_set_exhausted(true)
	
	# Clamp to incapacitated threshold
	if current_energy <= PASSED_OUT_THRESHOLD:
		current_energy = PASSED_OUT_THRESHOLD
		passed_out.emit()
	
	_emit_updates()
	return true


func restore_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	
	current_energy = minf(current_energy + amount, max_energy)
	
	# If recovered above exhaustion threshold with food/rest
	if current_energy > EXHAUSTION_THRESHOLD and is_exhausted:
		_set_exhausted(false)
	
	_emit_updates()


func eat_item(item_id: StringName) -> bool:
	var item_data: ItemData = ContentRegistry.get_item(item_id)
	if item_data == null or not item_data.is_edible():
		return false
	
	# Vanilla Stardew formula: Energy restored = edibility * 2.5
	var energy_gain: float = float(item_data.edibility) * 2.5
	restore_energy(energy_gain)
	
	# Also update health if edibility gives health (vanilla formula: health = energy * 0.45)
	var health_gain: float = energy_gain * 0.45
	if is_instance_valid(EventBus):
		EventBus.player_health_changed.emit(health_gain, 100.0)
	
	return true


func is_passed_out() -> bool:
	return current_energy <= PASSED_OUT_THRESHOLD


func reset_for_new_day() -> void:
	if is_exhausted:
		# Sleeping exhausted recovers only 50% max energy
		current_energy = max_energy * OVERNIGHT_EXHAUSTED_RECOVERY_RATIO
		_set_exhausted(false)
		print("[EnergyManager] Woke up from exhaustion. Energy recovered to 50%% (%.1f / %.1f)" % [current_energy, max_energy])
	else:
		# Sleeping normal recovers to full 100%
		current_energy = max_energy
		print("[EnergyManager] Full night of rest. Energy fully restored (%.1f / %.1f)" % [current_energy, max_energy])
	
	_emit_updates()


func _on_day_started(_day: int, _season: String, _year: int) -> void:
	reset_for_new_day()


func _set_exhausted(value: bool) -> void:
	if is_exhausted != value:
		is_exhausted = value
		exhaustion_changed.emit(is_exhausted)
		if is_instance_valid(EventBus):
			EventBus.player_exhausted.emit(is_exhausted)
		print("[EnergyManager] Exhaustion state changed: %s" % ("EXHAUSTED" if is_exhausted else "NORMAL"))


func _emit_updates() -> void:
	energy_changed.emit(current_energy, max_energy)
	if is_instance_valid(EventBus):
		EventBus.player_energy_changed.emit(current_energy, max_energy)
