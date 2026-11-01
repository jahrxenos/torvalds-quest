## Интерпретатор заклинаний. Настоящий Bash не запускается: понимает только заклинания игры.
## Сами заклинания лежат отдельными файлами в scripts/spells/, тексты — в data/texts.json.
## execute() возвращает строки для терминала и панели диалогов; интерфейс их только показывает.
class_name Interpreter
extends RefCounted

const SPELLS_DIR := "res://scripts/spells/"

## Говорящие в панели диалогов.
const TANENBUM := "tanenbum"
const NARRATOR := "narrator"

## Сообщение об ошибке для каждого кода Kingdom.Err.
const ERR_TEXT := {
	Kingdom.Err.NOT_FOUND: "err_not_found",
	Kingdom.Err.NOT_DIR: "err_not_dir",
	Kingdom.Err.IS_DIR: "err_is_dir",
	Kingdom.Err.EXISTS: "err_exists",
	Kingdom.Err.INVALID: "err_invalid",
	Kingdom.Err.NOT_MOUNTABLE: "err_not_mountable",
	Kingdom.Err.ALREADY_MOUNTED: "err_already_mounted",
}

## Все заклинания игры: имя -> Spell.
static var spells: Dictionary = {}

var kingdom: Kingdom
var progress: Progress
## Вид триггера, у которого стоит Торвальд ("" — не у триггера). Задаёт сцена.
var trigger: String = ""
## Ошибок подряд; после удачного заклинания сбрасывается.
var errors_in_row := 0


func _init(p_kingdom: Kingdom, p_progress: Progress) -> void:
	kingdom = p_kingdom
	progress = p_progress
	if spells.is_empty():
		load_spells()


## Находит все заклинания в scripts/spells/. Базовые классы (без имени) пропускаются.
static func load_spells() -> void:
	for file in ResourceLoader.list_directory(SPELLS_DIR):
		if not file.ends_with(".gd"):
			continue
		var script: Script = load(SPELLS_DIR + file)
		var spell = script.new()
		if spell is Spell and spell.name != "":
			spells[spell.name] = spell


func prompt() -> String:
	return "torvald@linux:%s$ " % kingdom.pwd()


## Результат: {"echo": строка с приглашением, "output": [строки терминала],
## "dialog": [{"speaker", "text"}], "open_book": bool, "goal_met": bool}.
func execute(line: String) -> Dictionary:
	var res := {"echo": prompt() + line, "output": [], "dialog": [], "open_book": false, "goal_met": false}
	var text := line.strip_edges()
	if text == "":
		return res
	if _run(text, res):
		errors_in_row = 0
	else:
		errors_in_row += 1
		_add_stage_hint(res)
	res["goal_met"] = kingdom.is_goal_met()
	return res


func _run(text: String, res: Dictionary) -> bool:
	if _has_cyrillic(text):
		return say(res, "cyrillic")
	var words := tokenize(text)
	var word: String = words[0]
	var spell_name := "./" if word.begins_with("./") else word
	if not spells.has(spell_name):
		var guess := _closest_spell(word)
		if guess != "":
			return say(res, "spell_guess", {"spell": guess})
		return say(res, "spell_unknown")
	if not progress.knows(spell_name):
		return say(res, "no_book" if spell_name == "help" else "spell_unknown")
	var spell: Spell = spells[spell_name]
	if spell.trigger != "" and trigger != spell.trigger:
		return say(res, "need_trigger", {"place": Texts.t("trigger_" + spell.trigger)})
	return spell.run(self, word, words.slice(1), res)


# --- Для заклинаний ----------------------------------------------------------

## Строка в терминал.
func out(res: Dictionary, line: String) -> void:
	res["output"].append(line)


## Реплика Таненбума по ключу текста. Возвращает false, чтобы писать return it.say(...).
func say(res: Dictionary, key: String, params: Dictionary = {}) -> bool:
	res["dialog"].append({"speaker": TANENBUM, "text": Texts.t(key, params)})
	return false


## Строка рассказчика по ключу текста.
func narrate(res: Dictionary, key: String, params: Dictionary = {}) -> void:
	narrate_text(res, Texts.t(key, params))


## Строка рассказчика готовым текстом (например, из уровня).
func narrate_text(res: Dictionary, text: String) -> void:
	res["dialog"].append({"speaker": NARRATOR, "text": text})


func error(err: Kingdom.Err, path: String, res: Dictionary) -> bool:
	if err == Kingdom.Err.LOCKED:
		var node := kingdom.resolve(path)
		if node and node.locked != "":
			res["dialog"].append({"speaker": TANENBUM, "text": node.locked})
			return false
		return say(res, "err_locked")
	return say(res, ERR_TEXT.get(err, "err_generic"), {"name": path.rstrip("/").get_file()})


# --- Подсказки ---------------------------------------------------------------

## После 2-й ошибки подряд — подсказка этапа, после 3-й и дальше — готовое заклинание.
func _add_stage_hint(res: Dictionary) -> void:
	if errors_in_row < 2:
		return
	var h := kingdom.current_hint()
	if errors_in_row == 2 and h.has("hint"):
		res["dialog"].append({"speaker": TANENBUM, "text": h["hint"]})
	elif errors_in_row >= 3 and h.has("answer"):
		say(res, "hint_answer", {"answer": h["answer"]})


# --- Разбор строки -----------------------------------------------------------

## Слова строки; кавычки объединяют слова с пробелами.
static func tokenize(text: String) -> Array[String]:
	var words: Array[String] = []
	var cur := ""
	var quote := ""
	for ch in text:
		if quote != "":
			if ch == quote:
				quote = ""
			else:
				cur += ch
		elif ch == "\"" or ch == "'":
			quote = ch
		elif ch == " " or ch == "\t":
			if cur != "":
				words.append(cur)
				cur = ""
		else:
			cur += ch
	if cur != "":
		words.append(cur)
	return words


static func _has_cyrillic(text: String) -> bool:
	for ch in text:
		var c := ch.unicode_at(0)
		if c >= 0x0400 and c <= 0x04FF:
			return true
	return false


## Ближайшее изученное заклинание для опечатки или "".
func _closest_spell(word: String) -> String:
	var best := ""
	var best_dist := 99
	for s: String in progress.spells:
		if s == "./":
			continue
		var d := edit_distance(word, s)
		if d < best_dist:
			best = s
			best_dist = d
	var limit := 1 if word.length() <= 3 else 2
	return best if best_dist <= limit else ""


## Расстояние Дамерау — Левенштейна (перестановка соседних букв считается одной ошибкой).
static func edit_distance(a: String, b: String) -> int:
	var d := []
	for i in a.length() + 1:
		var row := []
		row.resize(b.length() + 1)
		d.append(row)
		d[i][0] = i
	for j in b.length() + 1:
		d[0][j] = j
	for i in range(1, a.length() + 1):
		for j in range(1, b.length() + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			d[i][j] = mini(mini(d[i - 1][j] + 1, d[i][j - 1] + 1), d[i - 1][j - 1] + cost)
			if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
				d[i][j] = mini(d[i][j], d[i - 2][j - 2] + 1)
	return d[a.length()][b.length()]
