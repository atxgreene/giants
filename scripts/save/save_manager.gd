extends Node
## Local JSON save in user://. Stores persistent currency, codex unlocks,
## weapon aspects, upgrades, flags, and settings.

const SAVE_PATH := "user://watchers_save.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_profile(defaults: Dictionary) -> Dictionary:
	var profile: Dictionary = defaults.duplicate(true)
	if not has_save():
		return profile
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return profile
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		for k in parsed:
			if profile.has(k) and profile[k] is Dictionary and parsed[k] is Dictionary:
				for sub in parsed[k]:
					profile[k][sub] = parsed[k][sub]
			else:
				profile[k] = parsed[k]
	return profile

func save_profile(profile: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Could not write save file.")
		return
	f.store_string(JSON.stringify(profile, "  "))

func wipe() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
