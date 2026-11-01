## Игровой экран: сверху поле, под ним панель диалогов, внизу терминал.
## Временно (до ходьбы, задача #11) Торвальд как будто всегда стоит у двери.
extends Control

const W := 640
const H := 360
const LEVEL := "res://levels/level1.json"
const DUNGEON := preload("res://assets/tiny-dungeon/tilemap_packed.png")
const TILE_FLOOR := 48
const TILE_TORVALD := 85
const C_BORDER := Color("#808080")

var kingdom: Kingdom
var progress := Progress.new()
var interp: Interpreter
var level: Dictionary
var speakers: Dictionary
var dialog: LogPanel
var terminal: TerminalPanel
var book: SpellBook
var place_label: Label
var finished := false
var newest_spell := ""
## Высоты частей экрана зависят от шрифта.
var dialog_h := 0
var term_h := 0
var world_h := 0


func _ready() -> void:
	# Самопроверка собранной игры: TorvaldsQuest.x86_64 --headless -- --selftest
	if "--selftest" in OS.get_cmdline_user_args():
		Interpreter.load_spells()
		print("selftest: заклинаний %d, текст: %s" % [Interpreter.spells.size(), Texts.t("cd_no_arg")])
		get_tree().quit(0 if Interpreter.spells.size() == 10 else 1)
		return
	RenderingServer.set_default_clear_color(Color.BLACK)
	UiFont.setup()
	theme = UiFont.theme()
	dialog_h = UiFont.line_h * 3 + 8
	term_h = UiFont.line_h * TerminalPanel.LINES + 8
	world_h = H - dialog_h - term_h
	speakers = JSON.parse_string(FileAccess.get_file_as_string("res://data/speakers.json"))
	_build_screen()
	_start_level(LEVEL)
	if "--demo" in OS.get_cmdline_user_args():
		_demo(["pwd", "ls", "cd tower", "cd tower", "cd ..", "ls", "cd tower", "help"])


## Отладка: набирает заклинания сама, по букве. Запуск: godot --path game -- --demo
func _demo(lines: Array) -> void:
	for line: String in lines:
		await get_tree().create_timer(1.2).timeout
		for ch in line:
			terminal.type_char(ch)
			await get_tree().create_timer(0.05).timeout
		await get_tree().create_timer(0.3).timeout
		_cast(terminal.take_input())


# --- Экран -------------------------------------------------------------------

func _build_screen() -> void:
	var world := Control.new()
	world.size = Vector2(W, world_h)
	world.clip_contents = true
	add_child(world)
	var floor_rect := TextureRect.new()
	floor_rect.texture = tile(DUNGEON, TILE_FLOOR)
	floor_rect.stretch_mode = TextureRect.STRETCH_TILE
	floor_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_rect.size = Vector2(W / 2, world_h / 2 + 1)
	floor_rect.scale = Vector2(2, 2)
	world.add_child(floor_rect)
	var hero := TextureRect.new()
	hero.texture = tile(DUNGEON, TILE_TORVALD)
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero.scale = Vector2(2, 2)
	hero.position = Vector2(W / 2 - 16, world_h / 2 - 16)
	world.add_child(hero)
	place_label = Label.new()
	place_label.position = Vector2(6, 4)
	place_label.add_theme_color_override("font_color", Color.WHITE)
	place_label.add_theme_color_override("font_outline_color", Color.BLACK)
	place_label.add_theme_constant_override("outline_size", 4)
	world.add_child(place_label)

	_frame(Rect2(0, world_h, W, dialog_h))
	_frame(Rect2(0, world_h + dialog_h - 1, W, term_h + 1))
	dialog = LogPanel.new(UiFont.line_h, 3, 16)
	dialog.position = Vector2(5, world_h + 4)
	dialog.size = Vector2(W - 10, dialog_h - 8)
	add_child(dialog)
	terminal = TerminalPanel.new()
	terminal.position = Vector2(5, world_h + dialog_h + 3)
	terminal.size = Vector2(W - 10, UiFont.line_h * TerminalPanel.LINES)
	add_child(terminal)

	book = SpellBook.new()
	book.size = Vector2(600, H - 12)
	book.position = Vector2((W - 600) / 2, 6)
	add_child(book)


func _frame(rect: Rect2) -> void:
	var p := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", style)
	p.position = rect.position
	p.size = rect.size
	add_child(p)


static func tile(sheet: Texture2D, index: int) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = sheet
	t.region = Rect2((index % 12) * 16, (index / 12) * 16, 16, 16)
	return t


# --- Уровень -----------------------------------------------------------------

func _start_level(path: String) -> void:
	level = JSON.parse_string(FileAccess.get_file_as_string(path))
	kingdom = Kingdom.from_dict(level)
	progress.learn(level.get("spells", []))
	interp = Interpreter.new(kingdom, progress)
	interp.trigger = "door"  # временно, до ходьбы (#11)
	finished = false
	_update_place()
	for line: Dictionary in level.get("intro", []):
		speak(line["speaker"], line["text"])


func _update_place() -> void:
	terminal.set_path(kingdom.pwd())
	place_label.text = kingdom.cwd.title


func speak(speaker_id: String, text: String) -> void:
	var sp: Dictionary = speakers.get(speaker_id, speakers["narrator"])
	var shown := text if sp["name"] == "" else "%s: %s" % [sp["name"], text]
	dialog.add_wrapped(shown, Color(sp["color"]), _icon(sp))


func _icon(sp: Dictionary) -> Texture2D:
	if sp.has("icon"):
		return load(sp["icon"])
	return tile(load(sp["sheet"]), int(sp["tile"]))


# --- Ввод --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var key := event as InputEventKey
	get_viewport().set_input_as_handled()
	if book.visible:
		if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			book.hide()
		return
	match key.keycode:
		KEY_ESCAPE:
			pass  # меню паузы — задача #17
		KEY_ENTER, KEY_KP_ENTER:
			if terminal.typed.strip_edges() == "":
				speak(Interpreter.TANENBUM, Texts.t("action_nothing"))
			else:
				_cast(terminal.take_input())
		KEY_BACKSPACE:
			terminal.backspace()
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
			pass  # ходьба — задача #11
		_:
			if key.unicode >= 32 and not key.ctrl_pressed and not key.alt_pressed:
				terminal.type_char(char(key.unicode))


func _cast(line: String) -> void:
	var res := interp.execute(line)
	for out: String in res["output"]:
		terminal.print_line(out)
	for d: Dictionary in res["dialog"]:
		speak(d["speaker"], d["text"])
	_update_place()
	if res["open_book"]:
		book.open(progress.spells, newest_spell)
	if res["goal_met"] and not finished:
		_finish_level()


func _finish_level() -> void:
	finished = true
	var find := kingdom.find
	if find.has("text"):
		speak(find.get("speaker", Interpreter.NARRATOR), find["text"])
	progress.apply_find(int(level.get("id", 0)), find)
	var new_spells: Array = find.get("spells", [])
	if not new_spells.is_empty():
		newest_spell = new_spells.back()
	speak(Interpreter.NARRATOR, Texts.t("level_done"))
