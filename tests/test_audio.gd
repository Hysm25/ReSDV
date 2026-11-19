extends Node

## Automated test suite for XACT Audio Extraction and AudioManager.
## Verifies audio extraction, WAV formatting, cue mapping, stream validity,
## and EventBus reactive playback.

const GOGImporter = preload("res://src/importer/gog_importer.gd")

var _last_cue_played: StringName = &""
var _cue_play_count: int = 0


func _ready() -> void:
	print("--- Running Test Suite: test_audio.tscn ---")
	
	_test_audio_files_exist()
	_test_wav_header_validity()
	_test_audio_manager_loading()
	_test_event_bus_audio_reactions()
	
	print("[test_audio] ALL AUDIO SYSTEM TESTS PASSED SUCCESSFULLY!")
	get_tree().quit(0)


func _test_audio_files_exist() -> void:
	print("[test_audio] 1. Checking audio files in vanilla_data/audio/...")
	assert(GOGImporter.is_vanilla_data_ready(), "Vanilla data should be ready and complete.")
	
	var expected_cues: Array[String] = [
		"hoeHit", "dirtyHit", "wateringCan", "slosh", "coin", "harvest",
		"seeds", "doorOpen", "doorClose", "axchop", "pickUpItem", "toolSwap"
	]
	
	for cue: String in expected_cues:
		var wav_path: String = "user://vanilla_data/audio/%s.wav" % cue
		assert(FileAccess.file_exists(wav_path), "Audio file '%s' must exist on disk." % wav_path)
	
	print("[test_audio] Expected audio files exist on disk.")


func _test_wav_header_validity() -> void:
	print("[test_audio] 2. Checking WAV header and PCM sample validity...")
	var test_cues: Array[String] = ["hoeHit", "wateringCan", "coin", "doorClose"]
	
	for cue: String in test_cues:
		var wav_path: String = "user://vanilla_data/audio/%s.wav" % cue
		var stream: AudioStreamWAV = AudioManager.load_wav(wav_path)
		assert(stream != null, "Failed to load WAV into AudioStreamWAV for '%s'" % cue)
		assert(stream.mix_rate == 44100, "Sample rate for '%s' should be 44100 Hz, got %d" % [cue, stream.mix_rate])
		assert(stream.stereo == true, "'%s' should be stereo (2 channels)" % cue)
		assert(stream.format == AudioStreamWAV.FORMAT_16_BITS, "'%s' format should be 16-bit PCM" % cue)
		assert(stream.get_length() > 0.1, "'%s' duration should be > 0.1s, got %.2fs" % [cue, stream.get_length()])
		print("  - '%s': duration %.2fs, %d Hz stereo 16-bit PCM (OK)" % [cue, stream.get_length(), stream.mix_rate])
	
	print("[test_audio] All sample WAV headers validated successfully.")


func _test_audio_manager_loading() -> void:
	print("[test_audio] 3. Testing AudioManager initialization and cue registry...")
	var audio_mgr: AudioManager = AudioManager.new()
	add_child(audio_mgr)
	
	assert(audio_mgr.get_loaded_cue_count() >= 20, "AudioManager should load >= 20 cues, got %d" % audio_mgr.get_loaded_cue_count())
	assert(audio_mgr.has_cue(&"hoeHit"), "Should have 'hoeHit' cue")
	assert(audio_mgr.has_cue(&"wateringCan"), "Should have 'wateringCan' cue")
	assert(audio_mgr.has_cue(&"dirtyHit"), "Should have 'dirtyHit' cue")
	assert(audio_mgr.has_cue(&"coin"), "Should have 'coin' cue")
	assert(audio_mgr.has_cue(&"doorOpen"), "Should have 'doorOpen' cue")
	assert(audio_mgr.has_cue(&"doorClose"), "Should have 'doorClose' cue")
	assert(audio_mgr.has_cue(&"seeds"), "Should have 'seeds' cue")
	assert(audio_mgr.has_cue(&"harvest"), "Should have 'harvest' cue")
	assert(not audio_mgr.has_cue(&"nonexistent_cue_1234"), "Should not have nonexistent cue")
	
	var stream: AudioStreamWAV = audio_mgr.get_stream(&"doorClose")
	assert(stream != null, "Stream for 'doorClose' must not be null")
	assert(stream.get_length() >= 0.95 and stream.get_length() <= 1.05, "DoorClose stream length should be ~1.0s")
	
	audio_mgr.free()
	print("[test_audio] AudioManager registry validated successfully.")


func _test_event_bus_audio_reactions() -> void:
	print("[test_audio] 4. Testing EventBus signal reactions...")
	var audio_mgr: AudioManager = AudioManager.new()
	add_child(audio_mgr)
	
	audio_mgr.cue_played.connect(func(cue: StringName) -> void:
		_last_cue_played = cue
		_cue_play_count += 1
	)
	
	# Test direct play
	var direct_ok: bool = audio_mgr.play_cue(&"seeds")
	assert(direct_ok == true, "Direct play_cue(&'seeds') should succeed")
	assert(_last_cue_played == &"seeds", "Last cue should be 'seeds'")
	
	var bad_ok: bool = audio_mgr.play_cue(&"invalid_cue")
	assert(bad_ok == false, "play_cue with invalid cue should return false")
	
	# Test EventBus: soil_tilled -> hoeHit
	_last_cue_played = &""
	EventBus.soil_tilled.emit(Vector2i(64, 18))
	assert(_last_cue_played == &"hoeHit", "soil_tilled should trigger 'hoeHit', got '%s'" % _last_cue_played)
	
	# Test EventBus: crop_watered -> wateringCan
	_last_cue_played = &""
	EventBus.crop_watered.emit(Vector2i(64, 18))
	assert(_last_cue_played == &"wateringCan", "crop_watered should trigger 'wateringCan', got '%s'" % _last_cue_played)
	
	# Test EventBus: crop_planted -> dirtyHit
	_last_cue_played = &""
	EventBus.crop_planted.emit(Vector2i(64, 18), &"vanilla:472")
	assert(_last_cue_played == &"dirtyHit", "crop_planted should trigger 'dirtyHit', got '%s'" % _last_cue_played)
	
	# Test EventBus: crop_harvested -> coin
	_last_cue_played = &""
	EventBus.crop_harvested.emit(Vector2i(64, 18), &"vanilla:472", &"vanilla:24", 1)
	assert(_last_cue_played == &"coin", "crop_harvested should trigger 'coin', got '%s'" % _last_cue_played)
	
	# Test EventBus: location_changed into FarmHouse -> doorOpen
	_last_cue_played = &""
	EventBus.location_changed.emit(&"Farm", &"FarmHouse", Vector2i(3, 11))
	assert(_last_cue_played == &"doorOpen", "Warping to FarmHouse should trigger 'doorOpen', got '%s'" % _last_cue_played)
	
	# Test EventBus: location_changed into Farm -> doorClose
	_last_cue_played = &""
	EventBus.location_changed.emit(&"FarmHouse", &"Farm", Vector2i(64, 15))
	assert(_last_cue_played == &"doorClose", "Warping back to Farm should trigger 'doorClose', got '%s'" % _last_cue_played)
	
	# Test EventBus: item_selected -> toolSwap
	_last_cue_played = &""
	EventBus.item_selected.emit(1, &"vanilla:watering_can")
	assert(_last_cue_played == &"toolSwap", "item_selected should trigger 'toolSwap', got '%s'" % _last_cue_played)
	
	audio_mgr.free()
	print("[test_audio] EventBus signal reactions verified successfully.")
