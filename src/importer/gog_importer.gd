class_name GOGImporter
extends RefCounted

## Godot wrapper and trigger for the vanilla asset extraction pipeline.
## Executes the native/Python pipeline to extract assets from a user-owned GOG installation
## directly into user://vanilla_data/ without committing any copyrighted content.

const DEFAULT_GOG_CONTENT_PATH: String = "/home/hysm/Games/Stardew Valley/Content"
const VANILLA_DATA_DIR: String = "user://vanilla_data/"
const EXTRACTOR_SCRIPT_RES: String = "res://src/importer/extract_assets.py"

static func is_vanilla_data_ready() -> bool:
	if not DirAccess.dir_exists_absolute(VANILLA_DATA_DIR):
		return false
	
	var required_files: Array[String] = [
		VANILLA_DATA_DIR.path_join("Objects.json"),
		VANILLA_DATA_DIR.path_join("Crops.json"),
		VANILLA_DATA_DIR.path_join("TileSheets/crops.png"),
		VANILLA_DATA_DIR.path_join("TileSheets/tools.png"),
		VANILLA_DATA_DIR.path_join("Maps/springobjects.png"),
	]
	
	for file_path: String in required_files:
		if not FileAccess.file_exists(file_path):
			return false
			
	return true

static func get_default_content_path() -> String:
	return DEFAULT_GOG_CONTENT_PATH

static func run_extraction(content_dir: String = "", output_dir: String = "") -> Dictionary:
	var target_content: String = content_dir if not content_dir.is_empty() else DEFAULT_GOG_CONTENT_PATH
	var target_output: String = output_dir if not output_dir.is_empty() else ProjectSettings.globalize_path(VANILLA_DATA_DIR)
	var script_path: String = ProjectSettings.globalize_path(EXTRACTOR_SCRIPT_RES)

	if not DirAccess.dir_exists_absolute(target_content):
		var err_msg: String = "[GOGImporter] Content directory not found: %s" % target_content
		push_error(err_msg)
		return {"success": false, "exit_code": -1, "output": err_msg}

	var args: PackedStringArray = [
		script_path,
		"--content-dir", target_content,
		"--output-dir", target_output,
	]

	print("[GOGImporter] Running asset extraction pipeline...")
	print("  Python script: %s" % script_path)
	print("  Content source: %s" % target_content)
	print("  Destination: %s" % target_output)

	var output_lines: Array = []
	var exit_code: int = OS.execute("python3", args, output_lines, true)

	var full_output: String = "\n".join(output_lines)
	if exit_code != 0:
		push_error("[GOGImporter] Extraction pipeline failed with exit code %d:\n%s" % [exit_code, full_output])
		return {"success": false, "exit_code": exit_code, "output": full_output}

	print("[GOGImporter] Extraction pipeline succeeded!")
	return {"success": true, "exit_code": exit_code, "output": full_output}

static func ensure_vanilla_data(content_dir: String = "") -> bool:
	if is_vanilla_data_ready():
		print("[GOGImporter] Vanilla data is already present in '%s'." % VANILLA_DATA_DIR)
		return true

	print("[GOGImporter] Vanilla data missing or incomplete. Initiating extraction...")
	var result: Dictionary = run_extraction(content_dir)
	if not result.get("success", false):
		return false

	if is_vanilla_data_ready():
		ContentRegistry.load_vanilla_data()
		return true

	push_error("[GOGImporter] Extraction reported success but required files are missing.")
	return false
