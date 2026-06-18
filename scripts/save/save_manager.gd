extends Node
class_name SaveManager
## Local JSON save in user://. Stores persistent currency, codex unlocks,
## weapon aspects, upgrades, flags, and settings.
##
## Durable save architecture (Phase 2.5):
##   - every save carries a `save_version`
##   - old saves are migrated step-by-step up to CURRENT_SAVE_VERSION
##   - the previous file is backed up before any migration
##   - a corrupt or failed-migration save fails *visibly* and keeps the backup,
##     rather than silently wiping the player's progress
##   - missing fields are repaired from defaults so additive content (new
##     weapons, flags, settings) never breaks an existing save

const SAVE_PATH := "user://watchers_save.json"
const BACKUP_PATH := "user://watchers_save.bak.json"
const CURRENT_SAVE_VERSION := 2

## Set when the most recent load_profile hit a problem the player should know
## about. Game reads this after load and surfaces it as a toast.
var last_load_warning := ""

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_profile(defaults: Dictionary) -> Dictionary:
	last_load_warning = ""
	if not has_save():
		var fresh: Dictionary = defaults.duplicate(true)
		fresh["save_version"] = CURRENT_SAVE_VERSION
		return fresh
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		last_load_warning = "Save file could not be opened. Loaded defaults; your file was left untouched."
		return _fresh(defaults)
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		# Corrupt save: do NOT wipe. Preserve the bad file as a backup and warn.
		_write_text(BACKUP_PATH, raw)
		last_load_warning = "Your save was unreadable and has been backed up. Progress was NOT erased — the backup is at user://watchers_save.bak.json."
		return _fresh(defaults)
	var profile: Dictionary = parsed
	var version := int(profile.get("save_version", 0))
	if version < CURRENT_SAVE_VERSION:
		# Back up the original before touching it, then migrate forward.
		_write_text(BACKUP_PATH, raw)
		profile = migrate(profile, version)
	elif version > CURRENT_SAVE_VERSION:
		last_load_warning = "This save is from a newer version of the game. Loaded as-is; some fields may be ignored."
	profile = repair(profile, defaults)
	# Persist any migration/repair so the on-disk file is current.
	save_profile(profile)
	return profile

func _fresh(defaults: Dictionary) -> Dictionary:
	var fresh: Dictionary = defaults.duplicate(true)
	fresh["save_version"] = CURRENT_SAVE_VERSION
	return fresh

# ---------------------------------------------------------------- migration

func migrate(profile: Dictionary, from_version: int) -> Dictionary:
	## Run each step migration in order. If any step fails, stop, keep the
	## backup, and warn — the partially migrated + repaired profile still loads
	## so the player is never silently wiped.
	var v := from_version
	while v < CURRENT_SAVE_VERSION:
		var step := "_migrate_%d_to_%d" % [v, v + 1]
		if not has_method(step):
			last_load_warning = "No migration path from save version %d. Repaired and loaded what could be read; backup kept." % v
			break
		var ok: bool = call(step, profile)
		if not ok:
			last_load_warning = "Save migration (v%d → v%d) failed. Your old file is backed up; loaded a repaired copy." % [v, v + 1]
			break
		v += 1
	profile["save_version"] = maxi(v, from_version)
	return profile

## v0 (pre-versioning) → v1: nothing structural; repair handles new fields.
func _migrate_0_to_1(profile: Dictionary) -> bool:
	profile["save_version"] = 1
	return true

## v1 → v2: introduce the weapon system. Carry the player's old single equipped
## aspect into the new per-weapon map so they keep what they had.
func _migrate_1_to_2(profile: Dictionary) -> bool:
	if not profile.has("weapon"):
		profile["weapon"] = "flaming_sword"
	if not profile.has("weapons_unlocked"):
		profile["weapons_unlocked"] = ["flaming_sword"]
	if not profile.has("weapon_aspects"):
		var old_aspect := str(profile.get("aspect", "commission"))
		profile["weapon_aspects"] = {"flaming_sword": old_aspect}
	profile["save_version"] = 2
	return true

# ---------------------------------------------------------------- validation

func repair(profile: Dictionary, defaults: Dictionary) -> Dictionary:
	## Deep-merge defaults for any missing key (one level deep into sub-dicts,
	## which is how the profile is shaped), and coerce a few critical fields to
	## sane types so a hand-edited or partially-migrated save still runs.
	for k in defaults:
		if not profile.has(k):
			profile[k] = _dup(defaults[k])
		elif defaults[k] is Dictionary and profile[k] is Dictionary:
			for sub in defaults[k]:
				if not profile[k].has(sub):
					profile[k][sub] = _dup(defaults[k][sub])
	# Critical-field coercion / repair.
	if not (profile.get("codex") is Array):
		profile["codex"] = _dup(defaults.get("codex", []))
	if not (profile.get("weapons_unlocked") is Array) or (profile["weapons_unlocked"] as Array).is_empty():
		profile["weapons_unlocked"] = ["flaming_sword"]
	if not (profile.get("weapon_aspects") is Dictionary):
		profile["weapon_aspects"] = {"flaming_sword": "commission"}
	var weapon := str(profile.get("weapon", "flaming_sword"))
	if not (weapon in profile["weapons_unlocked"]):
		profile["weapon"] = "flaming_sword"
	profile["save_version"] = CURRENT_SAVE_VERSION
	return profile

func _dup(v):
	if v is Dictionary or v is Array:
		return v.duplicate(true)
	return v

# ---------------------------------------------------------------- io

func save_profile(profile: Dictionary) -> void:
	profile["save_version"] = CURRENT_SAVE_VERSION
	_write_text(SAVE_PATH, JSON.stringify(profile, "  "))

func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Could not write file: " + path)
		return
	f.store_string(text)
	f.close()

func wipe() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
