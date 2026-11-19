class_name AudioManager
extends Node

## Isolated audio manager for ReSDV.
## Loads vanilla audio WAV files from user://vanilla_data/audio/
## and listens to EventBus signals to play authentic sound effects.

signal cue_played(cue_name: StringName)

const AUDIO_DIR: String = "user://vanilla_data/audio/"
const DEFAULT_POOL_SIZE: int = 8

var _streams: Dictionary[StringName, AudioStreamWAV] = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player_idx: int = 0
var _enabled: bool = true


func _ready() -> void:
	_init_player_pool()
	load_all_cues()
	_connect_event_bus()


func _init_player_pool() -> void:
	for i in range(DEFAULT_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "AudioPlayer_%d" % i
		player.bus = &"Master"
		add_child(player)
		_players.append(player)


func _connect_event_bus() -> void:
	if not is_instance_valid(EventBus):
		return
	
	EventBus.soil_tilled.connect(_on_soil_tilled)
	EventBus.crop_watered.connect(_on_crop_watered)
	EventBus.crop_planted.connect(_on_crop_planted)
	EventBus.crop_harvested.connect(_on_crop_harvested)
	EventBus.location_changed.connect(_on_location_changed)
	EventBus.item_selected.connect(_on_item_selected)
	EventBus.chest_opened.connect(func(_ch: Node) -> void: play_cue(&"openBox"))
	EventBus.chest_closed.connect(func(_ch: Node) -> void: play_cue(&"doorClose"))
	EventBus.chest_placed.connect(func(_cell: Vector2i, _ch: Node) -> void: play_cue(&"woodyStep"))
	EventBus.chest_removed.connect(func(_cell: Vector2i) -> void: play_cue(&"axchop"))


func load_all_cues() -> void:
	if not DirAccess.dir_exists_absolute(AUDIO_DIR):
		return
	
	var dir: DirAccess = DirAccess.open(AUDIO_DIR)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".wav"):
			var cue_name: StringName = StringName(file_name.get_basename())
			var stream: AudioStreamWAV = load_wav(AUDIO_DIR.path_join(file_name))
			if stream:
				_streams[cue_name] = stream
		file_name = dir.get_next()
	dir.list_dir_end()
	
	print("[AudioManager] Loaded %d audio cues from '%s'." % [_streams.size(), AUDIO_DIR])


static func load_wav(path: String) -> AudioStreamWAV:
	var global_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(global_path):
		return null
	
	var file: FileAccess = FileAccess.open(global_path, FileAccess.READ)
	if not file:
		return null
	
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	
	if bytes.size() < 44:
		return null
	
	var riff_tag: String = bytes.slice(0, 4).get_string_from_ascii()
	var wave_tag: String = bytes.slice(8, 12).get_string_from_ascii()
	if riff_tag != "RIFF" or wave_tag != "WAVE":
		return null
	
	# Parse chunks
	var channels: int = 2
	var sample_rate: int = 44100
	var bits_per_sample: int = 16
	var pcm_data: PackedByteArray = PackedByteArray()
	
	var pos: int = 12
	while pos < bytes.size() - 8:
		var chunk_id: String = bytes.slice(pos, pos + 4).get_string_from_ascii()
		var chunk_size: int = bytes.decode_u32(pos + 4)
		pos += 8
		
		if chunk_id == "fmt " and chunk_size >= 16:
			channels = bytes.decode_u16(pos + 2)
			sample_rate = bytes.decode_u32(pos + 4)
			bits_per_sample = bytes.decode_u16(pos + 14)
		elif chunk_id == "data":
			pcm_data = bytes.slice(pos, pos + chunk_size)
			break
		
		pos += chunk_size
		# Pad byte for odd chunk sizes in RIFF format
		if chunk_size % 2 == 1:
			pos += 1
	
	if pcm_data.is_empty():
		return null
	
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits_per_sample == 16 else AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = (channels == 2)
	stream.data = pcm_data
	return stream


func has_cue(cue_name: StringName) -> bool:
	return _streams.has(cue_name)


func get_stream(cue_name: StringName) -> AudioStreamWAV:
	return _streams.get(cue_name, null)


func get_loaded_cue_count() -> int:
	return _streams.size()


func play_cue(cue_name: StringName, volume_db: float = 0.0) -> bool:
	if not _enabled:
		return false
	if not _streams.has(cue_name):
		return false
	
	var stream: AudioStreamWAV = _streams[cue_name]
	var player: AudioStreamPlayer = _get_available_player()
	player.stream = stream
	player.volume_db = volume_db
	player.play()
	cue_played.emit(cue_name)
	return true


func _get_available_player() -> AudioStreamPlayer:
	if _players.is_empty():
		_init_player_pool()
	
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			return player
	
	# Round-robin steal if all busy
	var chosen: AudioStreamPlayer = _players[_next_player_idx]
	_next_player_idx = (_next_player_idx + 1) % _players.size()
	return chosen


func set_audio_enabled(enabled: bool) -> void:
	_enabled = enabled


func is_audio_enabled() -> bool:
	return _enabled


# --- EventBus Signal Handlers ---

func _on_soil_tilled(_cell: Vector2i) -> void:
	play_cue(&"hoeHit")


func _on_crop_watered(_cell: Vector2i) -> void:
	play_cue(&"wateringCan")


func _on_crop_planted(_cell: Vector2i, _crop_id: StringName) -> void:
	play_cue(&"dirtyHit")


func _on_crop_harvested(_cell: Vector2i, _crop_id: StringName, _yield_item_id: StringName, _count: int) -> void:
	play_cue(&"coin")


func _on_location_changed(from_map: StringName, to_map: StringName, _target_cell: Vector2i) -> void:
	if to_map == &"FarmHouse":
		play_cue(&"doorOpen")
	elif to_map == &"Farm" and from_map != &"":
		play_cue(&"doorClose")


func _on_item_selected(_slot_index: int, _item_id: StringName) -> void:
	play_cue(&"toolSwap")
