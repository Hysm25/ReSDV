class_name DialogueEngine
extends RefCounted

## Dialogue parsing, text token substitution, and dialogue selection engine for ReSDV.
## Parses authentic Stardew Valley dialogue strings ($h, $s, #$b#, @, %farm)
## and manages NPC conversation trees.

const DIALOGUE_DATA_DIR: String = "user://vanilla_data/Characters/Dialogue/"

# Emotion tag to portrait frame mapping
const EMOTION_MAP: Dictionary[String, int] = {
	"$h": 1, # Happy
	"$s": 2, # Sad
	"$u": 3, # Unique
	"$l": 4, # Love
	"$a": 5, # Angry
}

var _dialogue_cache: Dictionary[StringName, Dictionary] = {}


func load_npc_dialogue(npc_name: StringName) -> Dictionary:
	if _dialogue_cache.has(npc_name):
		return _dialogue_cache[npc_name]

	var file_path: String = DIALOGUE_DATA_DIR.path_join("%s.json" % String(npc_name))
	if not FileAccess.file_exists(file_path):
		push_warning("[DialogueEngine] Dialogue file not found: %s" % file_path)
		return {}

	var file: FileAccess = FileAccess.open(file_path, FileAccess.ModeFlags.READ)
	if file == null:
		return {}

	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK or not (json.data is Dictionary):
		push_error("[DialogueEngine] Failed to parse JSON in %s" % file_path)
		return {}

	var dict: Dictionary = json.data as Dictionary
	_dialogue_cache[npc_name] = dict
	return dict


func get_dialogue_entry(npc_name: StringName, key: String) -> String:
	var dict: Dictionary = load_npc_dialogue(npc_name)
	if dict.has(key):
		return String(dict[key])
	return ""


func get_best_dialogue(npc_name: StringName, day_of_week: String = "Mon", is_first_meeting: bool = false, season: String = "spring") -> String:
	var dict: Dictionary = load_npc_dialogue(npc_name)
	if dict.is_empty():
		return "Hello, neighbor!"

	# 1. First meeting / introduction
	if is_first_meeting and dict.has("Introduction"):
		return String(dict["Introduction"])

	# 2. Day of week specific dialogue (e.g. "Mon", "Tue")
	if dict.has(day_of_week):
		return String(dict[day_of_week])

	# 3. Season specific dialogue (e.g. "spring")
	if dict.has(season):
		return String(dict[season])

	# 4. Fallback to first available entry or introduction
	if dict.has("Introduction"):
		return String(dict["Introduction"])

	for k in dict.keys():
		var val: String = String(dict[k])
		if not val.is_empty() and not val.begins_with("http"):
			return val

	return "Hello there!"


func parse_dialogue(raw_text: String, player_name: String = "Farmer", farm_name: String = "Standard") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw_text.is_empty():
		return result

	# Replace Stardew text tokens
	var text: String = raw_text.replace("@", player_name)
	text = text.replace("%farm", farm_name)

	# Split into dialogue pages by #$b# or #$e# or #
	var raw_pages: PackedStringArray = text.split("#", false)
	if raw_pages.is_empty():
		raw_pages = PackedStringArray([text])

	for raw_page: String in raw_pages:
		var page_str: String = raw_page.strip_edges()
		if page_str.is_empty() or page_str == "$e" or page_str == "$b":
			continue

		# Clean out sub-commands like $e, $b, %noturn
		page_str = page_str.replace("$e", "").replace("$b", "").replace("%noturn", "").strip_edges()

		# Detect emotion tag at end of page (e.g. $h, $s, $u, $1, $2, etc.)
		var emotion_idx: int = 0
		var reg: RegEx = RegEx.new()
		reg.compile(r"\$([h|s|u|l|a]|\d+)$")
		var match_res: RegExMatch = reg.search(page_str)
		if match_res != null:
			var tag_str: String = match_res.get_string(0)
			if EMOTION_MAP.has(tag_str):
				emotion_idx = EMOTION_MAP[tag_str]
			elif tag_str.length() > 1 and tag_str.substr(1).is_valid_int():
				emotion_idx = tag_str.substr(1).to_int()
			page_str = page_str.substr(0, match_res.get_start()).strip_edges()

		if not page_str.is_empty():
			result.append({
				"text": page_str,
				"emotion": emotion_idx,
			})

	if result.is_empty() and not raw_text.is_empty():
		result.append({"text": raw_text, "emotion": 0})

	return result
