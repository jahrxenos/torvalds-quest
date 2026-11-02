## Королевство Линукс: дерево мест и предметов одного уровня.
## Методы возвращают код ошибки Err; текст для игрока формирует интерпретатор команд.
class_name Kingdom
extends RefCounted

enum Err {
	OK,
	NOT_FOUND,        ## такого места или предмета нет
	NOT_DIR,          ## это предмет, а не место
	IS_DIR,           ## это место, а не предмет
	LOCKED,           ## место закрыто
	EXISTS,           ## там уже есть предмет с таким именем
	INVALID,          ## нельзя переместить место внутрь самого себя или корень
	NOT_MOUNTABLE,    ## гостя нет в книге постояльцев
	ALREADY_MOUNTED,  ## повозка уже открыта
	NOT_EXEC,         ## свиток не заряжен
}

## Состояние факела хранится в его тексте, поэтому cat torch1 работает как обычно.
const TORCH_LIT := "Факел горит"
const TORCH_DARK := "Факел погас"

var root: KNode
var cwd: KNode
## Книга постояльцев (/etc/fstab): абсолютный путь точки подключения -> содержимое в формате уровня.
var fstab: Dictionary = {}
var mounted: Dictionary = {}
## Условия прохождения уровня; когда выполнены все, происходит находка.
var goal: Array = []
## Находка уровня: {"item", "speaker", "text", "spells"}.
var find: Dictionary = {}
## Подсказки этапов: [{"until": условие, "hint": фраза, "answer": заклинание}].
## Действует первая подсказка, чьё условие ещё не выполнено.
var hints: Array = []
## Что игрок уже сделал: абсолютные пути прочитанных предметов и прочитанных вслух свитков.
var read_paths: Dictionary = {}
var ran_paths: Dictionary = {}


func _init() -> void:
	root = KNode.new("", "Королевство Линукс", true)
	cwd = root


# --- Загрузка уровня ---------------------------------------------------------

## Данные уровня: {"world": {...}, "start": "/путь", "fstab": {"/путь": {...}}}.
## Узел с ключом "children" — место, без него — предмет с "text".
static func from_dict(data: Dictionary) -> Kingdom:
	var k := Kingdom.new()
	var world: Dictionary = data.get("world", {})
	for child_name: String in world:
		k.root.add_child(_build(child_name, world[child_name]))
	k.fstab = data.get("fstab", {})
	k.goal = data.get("goal", [])
	k.find = data.get("find", {})
	k.hints = data.get("hints", [])
	var start := k.resolve(data.get("start", "/"))
	if start and start.is_dir:
		k.cwd = start
	return k


static func load_level(path: String) -> Kingdom:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Не открыть уровень: %s" % path)
		return null
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Уровень не в формате JSON-объекта: %s" % path)
		return null
	return from_dict(data)


static func _build(node_name: String, d: Dictionary) -> KNode:
	var node := KNode.new(node_name, d.get("title", node_name), d.has("children"))
	node.text = d.get("text", "")
	node.executable = d.get("exec", false)
	node.locked = d.get("locked", "")
	node.to = d.get("to", "")
	node.at = d.get("at", "")
	node.mark = d.get("mark", "")
	node.data = d.duplicate()
	node.data.erase("children")
	var kids: Dictionary = d.get("children", {})
	for child_name: String in kids:
		node.add_child(_build(child_name, kids[child_name]))
	return node


# --- Пути --------------------------------------------------------------------

## Узел по пути (абсолютному или от текущего места); null, если его нет.
func resolve(path: String) -> KNode:
	var node := root if path.begins_with("/") else cwd
	for part in path.split("/", false):
		if part == ".":
			continue
		if part == "..":
			node = node.parent() if node.parent() else root
			continue
		if not node.is_dir:
			return null
		node = node.get_child(part)
		if node == null:
			return null
	return node


func path_of(node: KNode) -> String:
	if node == root:
		return "/"
	var parts: PackedStringArray = []
	var n := node
	while n and n != root:
		parts.insert(0, n.name)
		n = n.parent()
	return "/" + "/".join(parts)


func pwd() -> String:
	return path_of(cwd)


## Родительское место и имя последней части пути (для mv и cp в новое имя).
func _split_target(path: String) -> Array:
	var trimmed := path.rstrip("/")
	var slash := trimmed.rfind("/")
	if slash == -1:
		return [cwd, trimmed]
	var parent_path := trimmed.substr(0, slash) if slash > 0 else "/"
	return [resolve(parent_path), trimmed.substr(slash + 1)]


# --- Заклинания --------------------------------------------------------------

func cd(path: String = "/") -> Err:
	var node := resolve(path)
	if node == null:
		return Err.NOT_FOUND
	if not node.is_dir:
		return Err.NOT_DIR
	if node.locked != "":
		return Err.LOCKED
	cwd = node
	return Err.OK


## Результат: {"err": Err, "items": Array[KNode]}; для предмета — он сам.
func list(path: String = ".") -> Dictionary:
	var node := resolve(path)
	if node == null:
		return {"err": Err.NOT_FOUND, "items": []}
	if not node.is_dir:
		return {"err": Err.OK, "items": [node]}
	if node.locked != "":
		return {"err": Err.LOCKED, "items": []}
	var items: Array[KNode] = []
	for child_name in node.child_names():
		items.append(node.get_child(child_name))
	return {"err": Err.OK, "items": items}


## Результат: {"err": Err, "text": String}.
func read(path: String) -> Dictionary:
	var node := resolve(path)
	if node == null:
		return {"err": Err.NOT_FOUND, "text": ""}
	if node.is_dir:
		return {"err": Err.IS_DIR, "text": ""}
	read_paths[path_of(node)] = true
	return {"err": Err.OK, "text": node.text}


func move(src_path: String, dst_path: String) -> Err:
	return _transfer(src_path, dst_path, false)


func copy(src_path: String, dst_path: String) -> Err:
	return _transfer(src_path, dst_path, true)


func _transfer(src_path: String, dst_path: String, keep_original: bool) -> Err:
	var src := resolve(src_path)
	if src == null:
		return Err.NOT_FOUND
	if src == root:
		return Err.INVALID
	if keep_original and src.is_dir:
		return Err.IS_DIR  # cp без -r места не копирует
	var dst := resolve(dst_path)
	var target_dir: KNode
	var new_name: String
	if dst and dst.is_dir:
		target_dir = dst
		new_name = src.name
	else:
		var split := _split_target(dst_path)
		target_dir = split[0]
		new_name = split[1]
		if target_dir == null:
			return Err.NOT_FOUND
		if not target_dir.is_dir:
			return Err.NOT_DIR
	if target_dir.locked != "":
		return Err.LOCKED
	if src == target_dir or src.is_ancestor_of(target_dir):
		return Err.INVALID
	if target_dir.get_child(new_name):
		return Err.EXISTS
	var node := src.duplicate_node() if keep_original else src
	if not keep_original:
		src.parent().remove_child(src)
	node.name = new_name
	target_dir.add_child(node)
	return Err.OK


## chmod +x: зарядить свиток.
func make_executable(path: String) -> Err:
	var node := resolve(path)
	if node == null:
		return Err.NOT_FOUND
	if node.is_dir:
		return Err.IS_DIR
	node.executable = true
	return Err.OK


## mount <точка>: открыть повозку гостя, записанного в книге постояльцев.
func mount(path: String) -> Err:
	var node := resolve(path)
	if node == null:
		return Err.NOT_FOUND
	if not node.is_dir:
		return Err.NOT_DIR
	var abs_path := path_of(node)
	if not fstab.has(abs_path):
		return Err.NOT_MOUNTABLE
	if mounted.has(abs_path):
		return Err.ALREADY_MOUNTED
	var contents: Dictionary = fstab[abs_path]
	for child_name: String in contents:
		node.add_child(_build(child_name, contents[child_name]))
	mounted[abs_path] = true
	return Err.OK


## ./свиток: прочитать заряженный свиток вслух. Результат: {"err": Err, "text": String}.
func run(path: String) -> Dictionary:
	var node := resolve(path)
	if node == null:
		return {"err": Err.NOT_FOUND, "text": ""}
	if node.is_dir:
		return {"err": Err.IS_DIR, "text": ""}
	if not node.executable:
		return {"err": Err.NOT_EXEC, "text": ""}
	ran_paths[path_of(node)] = true
	return {"err": Err.OK, "text": node.text}


# --- Факелы (заклинания светлячков) -----------------------------------------

## light: зажечь погасший факел; горящий от повторного заклинания гаснет.
func light(path: String) -> Err:
	var node := resolve(path)
	if node == null:
		return Err.NOT_FOUND
	if node.is_dir:
		return Err.IS_DIR
	node.text = TORCH_LIT if node.text == TORCH_DARK else TORCH_DARK
	return Err.OK


## dark: темно ли (погас ли факел). Для if: true — погас.
func is_dark(path: String) -> bool:
	var node := resolve(path)
	return node != null and not node.is_dir and node.text == TORCH_DARK


# --- Цель уровня -------------------------------------------------------------

## Условия: {"cwd": путь} — Торвальд стоит здесь; {"read": путь} — предмет прочитан;
## {"exists": путь} / {"missing": путь} — предмет есть / его нет; {"ran": путь} — свиток прочитан вслух;
## {"text": путь, "is": строка} — у предмета такой текст (факелы); {"lit": "шаблон"} — горят все подходящие факелы.
func is_goal_met() -> bool:
	if goal.is_empty():
		return false
	for cond: Dictionary in goal:
		if not _condition_met(cond):
			return false
	return true


func _condition_met(cond: Dictionary) -> bool:
	if cond.has("cwd"):
		return pwd() == cond["cwd"]
	if cond.has("read"):
		return read_paths.has(cond["read"])
	if cond.has("exists"):
		return resolve(cond["exists"]) != null
	if cond.has("missing"):
		return resolve(cond["missing"]) == null
	if cond.has("ran"):
		return ran_paths.has(cond["ran"])
	if cond.has("text"):
		var node := resolve(cond["text"])
		return node != null and node.text == cond.get("is", "")
	if cond.has("lit"):
		var torches := glob(cond["lit"])
		return not torches.is_empty() and torches.all(func(p): return not is_dark(p))
	push_error("Неизвестное условие цели: %s" % cond)
	return false


## Звёздочка в последней части пути: torch* -> пути всех подходящих предметов по алфавиту.
func glob(pattern: String) -> Array[String]:
	var result: Array[String] = []
	var split := _split_target(pattern)
	var dir: KNode = split[0]
	var mask: String = split[1]
	if dir == null or not dir.is_dir:
		return result
	var prefix := pattern.substr(0, pattern.length() - mask.length())
	for child_name in dir.child_names():
		if child_name.match(mask):
			result.append(prefix + child_name)
	return result


## Подсказка текущего этапа уровня или пустой словарь.
func current_hint() -> Dictionary:
	for h: Dictionary in hints:
		if not h.has("until") or not _condition_met(h["until"]):
			return h
	return {}
