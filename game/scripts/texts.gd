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
	# {Title} — то же, что {title}, но с заглавной буквы.
	if params.has("title") and not params.has("Title"):
		params = params.duplicate()
		params["Title"] = capitalize_first(params["title"])
	return String(_texts[key]).format(params)


static func capitalize_first(s: String) -> String:
	return s.left(1).to_upper() + s.substr(1)


static func has(key: String) -> bool:
	t("_note")
	return _texts.has(key)
