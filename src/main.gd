extends Node

const GOGImporter = preload("res://src/importer/gog_importer.gd")

func _ready() -> void:
	print("[Main] Engine core initializing...")
	if not GOGImporter.is_vanilla_data_ready():
		print("[Main] Vanilla data not detected. Triggering GOG extraction pipeline...")
		var ok: bool = GOGImporter.ensure_vanilla_data()
		if not ok:
			push_warning("[Main] GOG extraction pipeline could not complete automatically. Ensure GOG content path is valid.")
	else:
		print("[Main] Vanilla data detected and loaded.")
	print("[Main] Engine core initialized.")
