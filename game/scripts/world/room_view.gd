## Комната — текущее место королевства, собранная автоматически по модели.
## Сетка 20×5 клеток по 32 px: стены по краю, двери в подкаталоги на верхней стене,
## выход наверх (..) слева, предметы на нижнем ряду пола. Торвальд ходит по клеткам.
class_name RoomView
extends Control

signal trigger_changed(trigger: Dictionary)

const COLS := 20
const ROWS := 5
const CELL := 32
const STEP_TIME := 0.14
## Клетка у выхода наверх.
const EXIT_CELL := Vector2i(1, 2)
const ITEM_ROW := 3

static var _themes: Dictionary = {}

var kingdom: Kingdom
var node: KNode
## Можно ли ходить (нельзя, пока открыта Книга или идёт переход).
var input_enabled := true
## Триггеры: {"kind", "spell", "node", "label", "cells", "pos", "npc"}.
var triggers: Array[Dictionary] = []
var hero_cell := Vector2i(10, 2)

var _blocked: Dictionary = {}
var _layer: Control
var _hero: TextureRect
var _label: Label
var _moving := false
var _current: Dictionary = {}


func _init() -> void:
	clip_contents = true
	if _themes.is_empty():
		_themes = JSON.parse_string(FileAccess.get_file_as_string("res://data/themes.json"))


## Собрать комнату для места p_node. back_from — имя места, из которого Торвальд вернулся наверх.
func build(p_kingdom: Kingdom, p_node: KNode, back_from: String = "") -> void:
	kingdom = p_kingdom
	node = p_node
	if _layer:
		_layer.queue_free()
	_layer = Control.new()
	_layer.position = Vector2(0, int((size.y - ROWS * CELL) / 2))
	add_child(_layer)
	triggers.clear()
	_blocked.clear()
	var theme := theme_of(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kingdom.path_of(node))
	for y in ROWS:
		for x in COLS:
			var wall := x == 0 or y == 0 or x == COLS - 1 or y == ROWS - 1
			var t: String = theme["wall"] if wall else theme["floor"][rng.randi() % theme["floor"].size()]
			_put(t, Vector2i(x, y))
			if wall:
				_blocked[Vector2i(x, y)] = true
	_place_exit(theme)
	_place_children(theme)
	_place_npcs()
	_place_decor(theme, rng)
	_hero = _put(_themes["hero"], Vector2i.ZERO)
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.hide()
	_layer.add_child(_label)
	hero_cell = _entry_cell(back_from)
	_hero.position = _cell_pos(hero_cell)
	_update_trigger()


## Оформление места: своё поле theme или ближайшего предка; по умолчанию — замок.
func theme_of(n: KNode) -> Dictionary:
	var p := n
	while p:
		if p.data.has("theme"):
			return _themes["themes"][p.data["theme"]]
		p = p.parent()
	return _themes["themes"]["castle"]


func current_trigger() -> Dictionary:
	return _current


# --- Расстановка -------------------------------------------------------------

func _place_exit(theme: Dictionary) -> void:
	if node == kingdom.root:
		return
	_put(theme["door"], Vector2i(0, EXIT_CELL.y))
	triggers.append({"kind": "exit", "spell": "door", "node": node.parent(), "label": "выход", "cells": [EXIT_CELL], "pos": Vector2i(0, EXIT_CELL.y)})


func _place_children(theme: Dictionary) -> void:
	var doors: Array[KNode] = []
	var items: Array[KNode] = []
	for child_name in node.child_names():
		var child := node.get_child(child_name)
		if child.is_dir and child.data.get("trigger", "door") == "door":
			doors.append(child)
		else:
			items.append(child)
	for i in doors.size():
		var col := clampi(roundi((i + 1) * float(COLS) / (doors.size() + 1)), 2, COLS - 3)
		var door := doors[i]
		_put(theme["locked"] if door.locked != "" else theme["door"], Vector2i(col, 0))
		triggers.append({"kind": "door", "spell": "door", "node": door, "label": door.title, "cells": [Vector2i(col, 1)], "pos": Vector2i(col, 0)})
	for i in items.size():
		var cell := Vector2i(4 + i * 3, ITEM_ROW)
		if cell.x > COLS - 3:
			break
		var item := items[i]
		var kind: String = item.data.get("trigger", "note" if not item.is_dir else "item")
		var sprite: String = item.data.get("sprite", _themes["objects"].get(kind, _themes["objects"]["item"]))
		_put(sprite, cell)
		_blocked[cell] = true
		var cells: Array[Vector2i] = [cell + Vector2i.UP, cell + Vector2i.LEFT, cell + Vector2i.RIGHT]
		triggers.append({"kind": kind, "spell": kind, "node": item, "label": item.title, "cells": cells, "pos": cell})


func _place_npcs() -> void:
	var npcs: Array = node.data.get("npcs", [])
	for i in npcs.size():
		var npc: Dictionary = npcs[i]
		var cell := Vector2i(COLS - 4 - i * 3, 1)
		_put(_themes["npcs"].get(npc["id"], _themes["objects"]["item"]), cell)
		_blocked[cell] = true
		var cells: Array[Vector2i] = [cell + Vector2i.DOWN, cell + Vector2i.LEFT, cell + Vector2i.RIGHT]
		triggers.append({"kind": "npc", "spell": "", "node": null, "label": npc.get("name", ""), "cells": cells, "pos": cell, "npc": npc})


## Предметы и животные для уюта: свои из уровня (поле decor места) и случайные из набора области.
## Ставятся только на верхний и нижний ряды пола, средний ряд остаётся свободным проходом.
func _place_decor(theme: Dictionary, rng: RandomNumberGenerator) -> void:
	var taken := {}
	for t in triggers:
		taken[t["pos"]] = true
		for c in t["cells"]:
			taken[c] = true
	var free: Array[Vector2i] = []
	for y in [1, ITEM_ROW]:
		for x in range(2, COLS - 2):
			var cell := Vector2i(x, y)
			if not taken.has(cell) and not _blocked.has(cell):
				free.append(cell)
	var chosen: Array = node.data.get("decor", []).duplicate()
	var pool: Array = theme.get("decor", [])
	if not pool.is_empty():
		var limits: Array = theme.get("decor_count", _themes.get("decor_count", [4, 6]))
		var count := rng.randi_range(int(limits[0]), int(limits[1]))
		# Без повторов: перемешиваем набор и берём по порядку.
		var shuffled := pool.duplicate()
		for i in range(shuffled.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = shuffled[i]
			shuffled[i] = shuffled[j]
			shuffled[j] = tmp
		for i in mini(count, shuffled.size()):
			chosen.append(shuffled[i])
	for d: Dictionary in chosen:
		if free.is_empty():
			break
		var cell: Vector2i = free.pop_at(rng.randi() % free.size())
		_put(d["tile"], cell)
		_blocked[cell] = true
		var cells: Array[Vector2i] = [cell + Vector2i.UP, cell + Vector2i.DOWN, cell + Vector2i.LEFT, cell + Vector2i.RIGHT]
		triggers.append({"kind": "decor", "spell": "", "node": null, "label": d.get("title", ""), "cells": cells, "pos": cell, "decor": d})


## Где появляется Торвальд: перед дверью места, из которого вернулся, иначе у выхода.
func _entry_cell(back_from: String) -> Vector2i:
	if back_from != "":
		for t in triggers:
			if t["kind"] == "door" and t["node"].name == back_from:
				return t["cells"][0]
	if node != kingdom.root:
		return EXIT_CELL
	return Vector2i(COLS / 2, 2)


## Поставить Торвальда к триггеру (для отладочного режима).
func stand_at(kind: String, node_name: String = "") -> void:
	for t in triggers:
		if t["kind"] == kind and (node_name == "" or (t["node"] and t["node"].name == node_name)):
			var free_cells: Array = t["cells"].filter(func(c): return not _blocked.has(c))
			if free_cells.is_empty():
				continue
			hero_cell = free_cells[0]
			_hero.position = _cell_pos(hero_cell)
			_update_trigger()
			return


func _put(tile_ref: String, cell: Vector2i) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tile(tile_ref)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.scale = Vector2(2, 2)
	r.position = _cell_pos(cell)
	_layer.add_child(r)
	return r


static func tile(tile_ref: String) -> AtlasTexture:
	if _themes.is_empty():
		_themes = JSON.parse_string(FileAccess.get_file_as_string("res://data/themes.json"))
	var parts := tile_ref.split(":")
	var t := AtlasTexture.new()
	t.atlas = load(_themes["sheets"][parts[0]])
	var index := int(parts[1])
	var cols := t.atlas.get_width() / 16  # в листах разное число тайлов в строке
	t.region = Rect2((index % cols) * 16, (index / cols) * 16, 16, 16)
	return t


func _cell_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL, cell.y * CELL)


# --- Ходьба ------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _moving or not input_enabled or _hero == null:
		return
	var dir := Vector2i.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		dir = Vector2i.LEFT
	elif Input.is_key_pressed(KEY_RIGHT):
		dir = Vector2i.RIGHT
	elif Input.is_key_pressed(KEY_UP):
		dir = Vector2i.UP
	elif Input.is_key_pressed(KEY_DOWN):
		dir = Vector2i.DOWN
	if dir != Vector2i.ZERO:
		step(dir)


func step(dir: Vector2i) -> void:
	if dir.x != 0:
		_hero.flip_h = dir.x < 0
	var target := hero_cell + dir
	if _blocked.has(target):
		return
	hero_cell = target
	_moving = true
	var tw := create_tween()
	tw.tween_property(_hero, "position", _cell_pos(target), STEP_TIME)
	tw.tween_callback(func():
		_moving = false
		_update_trigger())


func _update_trigger() -> void:
	var found: Dictionary = {}
	for t in triggers:
		if hero_cell in t["cells"]:
			found = t
			break
	if found != _current:
		_current = found
		_show_label(found)
		trigger_changed.emit(found)


func _show_label(t: Dictionary) -> void:
	if t.is_empty() or t["label"] == "":
		_label.hide()
		return
	_label.text = Texts.capitalize_first(t["label"])
	_label.reset_size()
	var p := _cell_pos(t["pos"])
	var x := clampf(p.x + CELL / 2.0 - _label.size.x / 2, 2, COLS * CELL - _label.size.x - 2)
	# Над предметом; у дверей в верхней стене — поверх самой двери.
	var y := p.y - _label.size.y + 4 if t["pos"].y > 0 else p.y + 2
	_label.position = Vector2(x, y)
	_label.show()
