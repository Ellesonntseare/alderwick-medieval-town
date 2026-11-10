extends "res://background_json_save.gd"

const VERSION := 1
const MAX_BYTES := 8 * 1024 * 1024

static func plain(value: Variant, depth := 0) -> bool:
	if depth > 20:return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:return true
		TYPE_FLOAT:return is_finite(value)
		TYPE_STRING, TYPE_STRING_NAME:return String(value).length() <= 200000
		TYPE_ARRAY:
			if value.size() > 20000:return false
			for child in value:
				if not plain(child, depth + 1):return false
			return true
		TYPE_DICTIONARY:
			if value.size() > 20000:return false
			for key in value:
				if not (key is String or key is StringName) or String(key).length() > 300 or not plain(value[key], depth + 1):return false
			return true
	return false

static func number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3:return false
	for component in value:
		if not number(component, -10000, 10000):return false
	return true

static func counts(value: Variant) -> bool:
	if not value is Dictionary:return false
	for key in value:
		if not (key is String or key is StringName) or not number(value[key], 0, 1000000000) or float(value[key]) != floorf(float(value[key])):return false
	return true

static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or not plain(data) or data.get("version") != VERSION:return false
	for section in ["player", "adventures", "economy", "home", "challenge", "world", "physical", "markets", "extensions"]:
		if not data.get(section) is Dictionary:return false
	var player: Dictionary = data.player
	if not vector(player.get("position")) or not vector(player.get("rotation")) or not player.get("inside") is bool or not number(player.get("view"), 0, 2):return false
	if not counts(data.adventures.get("inventory")) or not data.adventures.get("progress") is Dictionary or not data.adventures.get("relationships") is Dictionary:return false
	for progress in data.adventures.progress.values():
		if not progress is Dictionary or progress.get("status") not in ["unmet", "offered", "active", "complete"] or not number(progress.get("step"), 0, 1000):return false
	for field in ["player_coins", "player_food", "treasury"]:
		if not number(data.economy.get(field), 0, 1000000000):return false
	if not counts(data.economy.get("story_rewards")) or not counts(data.home.get("storage")):return false
	if not data.world.get("enabled") is bool or not number(data.world.get("phase"), 0, 1) or not number(data.world.get("cycle_seconds"), 10, 86400):return false
	if not data.challenge.get("active") is String or not number(data.challenge.get("remaining"), 0, 86400) or not counts(data.challenge.get("completions")) or not counts(data.challenge.get("progress")):return false
	if not data.physical.get("objects") is Dictionary or not data.physical.get("carried") is String:return false
	for record in data.physical.objects.values():
		if not record is Dictionary or not vector(record.get("position")) or not vector(record.get("rotation")) or not counts(record.get("stock")):return false
	for market in data.markets.values():
		if not counts(market):return false
	return true

static func load_valid(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file or file.get_length() > MAX_BYTES:return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or envelope.get("version") != VERSION or not envelope.get("payload") is String or not envelope.get("sha256") is String:return {}
	var payload: String = envelope.payload
	if payload.sha256_text() != envelope.sha256 or parser.parse(payload) != OK:return {}
	return parser.data if valid_snapshot(parser.data) else {}

func write_payload(path: String, data: Dictionary) -> Error:
	if not valid_snapshot(data):return ERR_INVALID_DATA
	var payload := JSON.stringify(data, "", false, true)
	var text := JSON.stringify({"version":VERSION,"payload":payload,"sha256":payload.sha256_text()})
	if text.to_utf8_buffer().size() > MAX_BYTES:return ERR_OUT_OF_MEMORY
	var temporary := path + ".pending-" + str(get_instance_id())
	var result := write_text(temporary, text)
	if result != OK:return result
	# Preserve the most recent complete, validated previous snapshot. A corrupt
	# primary must never overwrite the last good recovery copy.
	if not load_valid(path).is_empty():
		var backup := path + ".backup"
		var backup_pending := backup + ".pending-" + str(get_instance_id())
		result = write_text(backup_pending, FileAccess.get_file_as_string(path))
		if result == OK:result = DirAccess.rename_absolute(backup_pending, backup)
	if result == OK:result = DirAccess.rename_absolute(temporary, path)
	if result != OK and FileAccess.file_exists(temporary):DirAccess.remove_absolute(temporary)
	return result

func write_text(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:return FileAccess.get_open_error()
	file.store_string(text);file.flush()
	var result := file.get_error();file.close()
	return result
