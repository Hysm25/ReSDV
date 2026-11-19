class_name DialogueBoxUI
extends CanvasLayer

## Authentic Stardew Valley dialogue box UI for ReSDV.
## Renders 64x64 NPC portraits with emotion expressions, speaker nameplate,
## multi-page text dialogues, and advance prompts.

signal dialogue_finished()
signal page_advanced(page_idx: int)

@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var name_label: Label = $CenterContainer/MainPanel/VBox/Header/NameLabel
@onready var text_label: Label = $CenterContainer/MainPanel/VBox/ContentHBox/TextLabel
@onready var portrait_rect: TextureRect = $CenterContainer/MainPanel/VBox/ContentHBox/PortraitBox/PortraitRect
@onready var arrow_label: Label = $CenterContainer/MainPanel/VBox/Footer/ArrowLabel

var _speaker: String = ""
var _pages: Array[Dictionary] = []
var _portrait_tex: Texture2D = null
var _current_page_idx: int = 0


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		advance_page()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_E:
			advance_page()
			get_viewport().set_input_as_handled()


func show_dialogue(speaker: String, pages: Array[Dictionary], portrait_tex: Texture2D = null) -> void:
	if pages.is_empty():
		return

	_speaker = speaker
	_pages = pages
	_portrait_tex = portrait_tex
	_current_page_idx = 0

	_display_current_page()
	visible = true

	var first_page: Dictionary = _pages[0]
	if is_instance_valid(EventBus):
		EventBus.dialogue_started.emit(StringName(_speaker), first_page.get("text", ""), _portrait_tex, first_page.get("emotion", 0))


func advance_page() -> void:
	if not visible:
		return

	_current_page_idx += 1
	if _current_page_idx >= _pages.size():
		close_dialogue()
	else:
		_display_current_page()
		page_advanced.emit(_current_page_idx)
		var page: Dictionary = _pages[_current_page_idx]
		if is_instance_valid(EventBus):
			EventBus.dialogue_page_changed.emit(_current_page_idx, _pages.size(), page.get("text", ""), page.get("emotion", 0))


func close_dialogue() -> void:
	if not visible:
		return

	visible = false
	dialogue_finished.emit()
	if is_instance_valid(EventBus):
		EventBus.dialogue_ended.emit(StringName(_speaker))


func _display_current_page() -> void:
	if _current_page_idx < 0 or _current_page_idx >= _pages.size():
		return

	var page: Dictionary = _pages[_current_page_idx]
	var text: String = page.get("text", "")
	var emotion: int = page.get("emotion", 0)

	if name_label != null:
		name_label.text = _speaker

	if text_label != null:
		text_label.text = text

	if portrait_rect != null:
		if _portrait_tex != null:
			# Stardew portraits are 128px wide (2 cols of 64px, 64px high per emotion)
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = _portrait_tex
			var col: int = emotion % 2
			var row: int = emotion / 2
			atlas.region = Rect2(col * 64, row * 64, 64, 64)
			portrait_rect.texture = atlas
			portrait_rect.visible = true
		else:
			portrait_rect.texture = null
			portrait_rect.visible = false

	if arrow_label != null:
		arrow_label.text = "▼" if (_current_page_idx < _pages.size() - 1) else "●"
