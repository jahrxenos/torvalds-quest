## Тексты игры из data/texts.json. Texts.t("ключ", {"name": "tower"}).
class_name Texts
extends RefCounted

const PATH := "res://data/texts.json"

static var _texts: Dictionary = {}


static func t(key: String, params: Dictionary = {}) -> String:
	if _texts.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_texts = data if typeof(data) == TYPE_DICTIONARY else {}
	if not _texts.has(key):
		push_error("Нет текста с ключом %s" % key)
		return key
	return String(_texts[key]).format(params)


static func has(key: String) -> bool:
	t("_note")
	return _texts.has(key)
