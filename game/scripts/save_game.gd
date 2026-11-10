## Сохранение игры и настроек в user:// (в браузере — в хранилище браузера).
## Игра сохраняется после каждого пройденного уровня; посреди уровня не сохраняется.
class_name SaveGame
extends RefCounted

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const DEFAULT_SETTINGS := {"music": 80, "sfx": 80, "fullscreen": false}


## next_level — путь уровня, с которого продолжать ("" — игра пройдена).
static func save(progress: Progress, next_level: String) -> void:
	_write(SAVE_PATH, {"progress": progress.to_dict(), "next_level": next_level})


## {"progress": Progress, "next_level": String} или пустой словарь, если сохранения нет.
static func load_game() -> Dictionary:
	var d := _read(SAVE_PATH)
	if d.is_empty():
		return {}
	return {"progress": Progress.from_dict(d.get("progress", {})), "next_level": d.get("next_level", "")}


static func has_save() -> bool:
	return not _read(SAVE_PATH).is_empty()


static func save_settings(settings: Dictionary) -> void:
	_write(SETTINGS_PATH, settings)


static func load_settings() -> Dictionary:
	var s := DEFAULT_SETTINGS.duplicate()
	s.merge(_read(SETTINGS_PATH), true)
	return s


static func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if typeof(data) == TYPE_DICTIONARY else {}
