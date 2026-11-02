## Игровой экран: сверху комната, под ним панель диалогов, внизу терминал.
extends Control

const W := 640
const H := 360
const LEVEL := "res://levels/level1.json"
const C_BORDER := Color("#808080")

var kingdom: Kingdom
var progress := Progress.new()
var interp: Interpreter
var level: Dictionary
var speakers: Dictionary
var dialog: LogPanel
var terminal: TerminalPanel
var book: SpellBook
var room: RoomView
var menu: PauseMenu
var story: StoryWindow
var story_pages: Array = []
## Показывать предысторию и заставки (в отладочном режиме --demo не показываются).
var show_story := true
## Финальный уровень пройден: после последней реплики по Enter покажем эпилог.
var pending_epilogue := false
## Уровень пройден: после последней реплики по Enter — следующий уровень.
var pending_next := ""
## Какие предупреждения уровня уже сказаны.
var warned: Dictionary = {}
## Очередь реплик, которые показываются по Enter.
var queue: Array = []
var _queue_running := false
var level_path := ""
## Прогресс на момент начала уровня — для «Начать уровень заново».
var progress_at_start: Dictionary = {}
var place_label: Label
var fade: ColorRect
## Какую реплику персонажа показать следующей.
var npc_line := 0
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
	var args := OS.get_cmdline_user_args()
	show_story = "--demo=splash" in args or not Array(args).any(func(a): return a.begins_with("--demo"))
	if show_story:
		show_pages([{"title": Texts.t("prologue_title"), "text": Texts.t("prologue")}])
	# Отладка: --level=2 — начать со второго уровня, как будто первые пройдены.
	var start := LEVEL
	for a in args:
		if a.begins_with("--level="):
			var n := int(a.substr(8))
			for i in range(1, n):
				var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level%d.json" % i))
				progress.learn(d.get("spells", []))
				progress.apply_find(i, d.get("find", {}))
			start = "res://levels/level%d.json" % n
	_start_level(start)
	if "--demo" in args:
		_demo(["pwd", "ls", "@exit", "cd tower", "cd tower", "cd ..", "ls", "@door:tower", "@enter", "cd tower", "@npc", "@enter", "help"])
	elif "--demo=stable" in args:
		_demo(["@decor", "@enter", "@door:stable", "@enter", "cd stable", "@decor", "@enter", "@menu"])
	elif "--demo=splash" in args:
		_demo(["@page"])
	elif "--demo=epilogue" in args:
		_show_epilogue()
	elif "--demo=village" in args:
		_demo(["@door:square", "cd square", "@note", "@enter", "cat sign", "@exit", "cd ..", "@door:bakery", "cd bakery", "@npc", "@enter", "@note", "cat letter"])
	elif "--demo=tavern" in args:
		_demo(["@note", "cat book", "@cart", "mount cart", "ls cart", "mv cart/apples storage", "mv cart/map storage", "mv storage/map cart", "cp cart/map storage", "mv cart/cheese kitchen"])
	elif "--demo=rooms3" in args:
		_demo(["@cart", "mount cart", "mv cart/apples storage", "cp cart/map storage", "mv cart/cheese kitchen", "@shot:l3_tavern",
			"@door:storage", "cd storage", "@shot:l3_storage", "@exit", "cd ..", "@door:kitchen", "cd kitchen", "@shot:l3_kitchen",
			"@exit", "cd ..", "@exit", "cd ..", "@shot:l3_village", "@quit"])
	elif "--demo=look" in args:
		_demo(["@door:stable", "@enter", "@exit", "@enter", "@decor", "@enter"])
	elif "--demo=intro" in args:
		_demo(["@next", "@next", "@next", "@next", "ls", "@exit", "cd ..", "@door:tower", "cd tower", "@next"])


## Отладка: набирает заклинания сама, по букве. Запуск: godot --path game -- --demo
## Строки с @ — действия: @exit, @door:имя, @npc — встать к триггеру; @enter — нажать Enter.
func _demo(lines: Array) -> void:
	for line: String in lines:
		await get_tree().create_timer(1.2).timeout
		if line == "@enter":
			_interact()
			continue
		if line.begins_with("@shot:"):
			# Снимок экрана в build/ (рядом с папкой game), после завершения перехода.
			await get_tree().create_timer(0.6).timeout
			var path := ProjectSettings.globalize_path("res://").path_join("../build/%s.png" % line.substr(6))
			get_viewport().get_texture().get_image().save_png(path)
			continue
		if line == "@quit":
			get_tree().quit()
			continue
		if line == "@page":
			_next_page()
			continue
		if line == "@next":
			_next_line()
			continue
		if line == "@menu":
			_open_menu()
			continue
		if line.begins_with("@"):
			var parts := line.substr(1).split(":")
			room.stand_at(parts[0], parts[1] if parts.size() > 1 else "")
			continue
		for ch in line:
			terminal.type_char(ch)
			await get_tree().create_timer(0.05).timeout
		await get_tree().create_timer(0.3).timeout
		_cast(terminal.take_input())


# --- Экран -------------------------------------------------------------------

func _build_screen() -> void:
	room = RoomView.new()
	room.size = Vector2(W, world_h)
	room.trigger_changed.connect(_on_trigger_changed)
	add_child(room)
	place_label = Label.new()
	place_label.position = Vector2(6, 2)
	place_label.add_theme_color_override("font_color", Color.WHITE)
	place_label.add_theme_color_override("font_outline_color", Color.BLACK)
	place_label.add_theme_constant_override("outline_size", 4)
	room.add_child(place_label)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.size = room.size
	fade.modulate.a = 0.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(fade)

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

	menu = PauseMenu.new()
	menu.size = Vector2(260, 150)
	menu.position = Vector2((W - 260) / 2, (H - 150) / 2)
	menu.resume.connect(_close_menu)
	menu.restart.connect(func():
		_close_menu()
		_restart_level())
	menu.quit_game.connect(func(): get_tree().quit())
	add_child(menu)

	story = StoryWindow.new()
	story.size = Vector2(600, H - 24)
	story.position = Vector2((W - 600) / 2, 12)
	add_child(story)


## Окна с текстом по очереди (предыстория, заставка уровня): Enter — следующее.
## Реплики уровня начинаются после последнего окна.
func show_pages(pages: Array) -> void:
	story_pages.append_array(pages)
	if not story.visible:
		_next_page()


func _next_page() -> void:
	if story_pages.is_empty():
		_close_story()
		return
	var page: Dictionary = story_pages.pop_front()
	room.input_enabled = false
	story.open(page["title"], page["text"], page.get("footer", Texts.t("prologue_footer")))


## Эпилог: после последней реплики финального уровня, по Enter.
func _show_epilogue() -> void:
	pending_epilogue = false
	show_pages([{"title": Texts.t("epilogue_title"), "text": Texts.t("epilogue"), "footer": Texts.t("epilogue_footer")}])


func _close_story() -> void:
	story.hide()
	room.input_enabled = true
	if not _queue_running:
		_next_line()


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


# --- Уровень -----------------------------------------------------------------

func _start_level(path: String) -> void:
	level_path = path
	progress_at_start = progress.to_dict()
	level = JSON.parse_string(FileAccess.get_file_as_string(path))
	kingdom = Kingdom.from_dict(level)
	progress.learn(level.get("spells", []))
	interp = Interpreter.new(kingdom, progress)
	finished = false
	warned.clear()
	room.build(kingdom, kingdom.cwd)
	room.move_child(place_label, -1)
	room.move_child(fade, -1)
	_update_place()
	var splash: Dictionary = level.get("splash", {})
	if show_story and not splash.is_empty():
		show_pages([{"title": Texts.t("level_title", {"n": int(level.get("id", 0)), "title": level.get("title", "")}), "text": splash["text"]}])
	say_queue(level.get("intro", []))


## Реплики по очереди: следующая — по Enter на пустой строке. У незаконченной очереди в конце ▸.
func say_queue(lines: Array) -> void:
	queue.append_array(lines)
	if not story.visible and not _queue_running:
		_next_line()


func _next_line() -> void:
	if queue.is_empty():
		_queue_running = false
		return
	_queue_running = true
	var line: Dictionary = queue.pop_front()
	var text: String = line["text"]
	if not queue.is_empty():
		text += " " + Texts.t("more")
	speak(line.get("speaker", Interpreter.NARRATOR), text)
	if queue.is_empty():
		_queue_running = false


func _update_place() -> void:
	terminal.set_path(kingdom.pwd())
	place_label.text = kingdom.cwd.title


## Начать уровень заново: прогресс — как в начале уровня, журнал и терминал чистые.
func _restart_level() -> void:
	progress = Progress.from_dict(progress_at_start)
	dialog.clear()
	terminal.clear()
	queue.clear()
	_queue_running = false
	_start_level(level_path)


func speak(speaker_id: String, text: String) -> void:
	speak_as(speakers.get(speaker_id, speakers["narrator"]), text)


## sp — говорящий: {"name", "tile" или "icon", "color"}.
func speak_as(sp: Dictionary, text: String) -> void:
	var shown := text if sp.get("name", "") == "" else "%s: %s" % [sp["name"], text]
	var icon: Texture2D = load(sp["icon"]) if sp.has("icon") else RoomView.tile(sp["tile"])
	dialog.add_wrapped(shown, Color(sp.get("color", "#e4e4e4")), icon)


func _open_menu() -> void:
	room.input_enabled = false
	menu.open()


func _close_menu() -> void:
	menu.hide()
	room.input_enabled = true


# --- Ввод --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var key := event as InputEventKey
	get_viewport().set_input_as_handled()
	if menu.visible:
		if key.keycode == KEY_ESCAPE:
			_close_menu()
		return
	if story.visible:
		if key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_next_page()
		return
	if book.visible:
		if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			book.hide()
			room.input_enabled = true
		return
	match key.keycode:
		KEY_ESCAPE:
			_open_menu()
		KEY_ENTER, KEY_KP_ENTER:
			if terminal.typed.strip_edges() == "":
				if not queue.is_empty():
					_next_line()
				elif pending_epilogue:
					_show_epilogue()
				elif pending_next != "":
					_go_next_level()
				else:
					_interact()
			else:
				_cast(terminal.take_input())
		KEY_BACKSPACE:
			terminal.backspace()
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
			pass  # ходьбу обрабатывает комната
		_:
			if key.unicode >= 32 and not key.ctrl_pressed and not key.alt_pressed:
				terminal.type_char(char(key.unicode))


func _cast(line: String) -> void:
	# Ребёнок уже колдует: недочитанные реплики показываем сразу, чтобы очередь не отставала от действий.
	while not queue.is_empty():
		var q: Dictionary = queue.pop_front()
		speak(q.get("speaker", Interpreter.NARRATOR), q["text"])
	_queue_running = false
	var before := kingdom.cwd
	var res := interp.execute(line)
	for out: String in res["output"]:
		terminal.print_line(out)
	for d: Dictionary in res["dialog"]:
		speak(d["speaker"], d["text"])
	_update_place()
	if kingdom.cwd != before:
		_transition(before)
	if res["open_book"]:
		room.input_enabled = false
		book.open(progress.spells, newest_spell)
	_check_warnings()
	if res["goal_met"] and not finished:
		_finish_level()


## Предупреждения уровня: {"when": [условия], "speaker", "text"}. Говорится один раз,
## пока условия выполнены; если ребёнок исправил ошибку и повторил её — скажется снова.
func _check_warnings() -> void:
	for w: Dictionary in level.get("warnings", []):
		var active := kingdom.conditions_met(w.get("when", []))
		if active and not warned.has(w):
			warned[w] = true
			speak(w.get("speaker", Interpreter.TANENBUM), w["text"])
		elif not active:
			warned.erase(w)


func _finish_level() -> void:
	finished = true
	var find := kingdom.find
	progress.apply_find(int(level.get("id", 0)), find)
	var new_spells: Array = find.get("spells", [])
	if not new_spells.is_empty():
		newest_spell = new_spells.back()
	var lines: Array = []
	if find.has("text"):
		lines.append({"speaker": find.get("speaker", Interpreter.NARRATOR), "text": find["text"]})
	# Итог уровня: что Торвальд получил; если в уровне не задан — общее «Уровень пройден!».
	lines.append({"speaker": Interpreter.NARRATOR, "text": level.get("result", Texts.t("level_done"))})
	lines.append_array(level.get("outro", []))
	if level.has("next_goal"):
		lines.append({"speaker": Interpreter.NARRATOR, "text": level["next_goal"]})
	pending_epilogue = level.get("final", false)
	pending_next = level.get("next", "")
	if pending_next != "":
		lines.append({"speaker": Interpreter.NARRATOR, "text": Texts.t("next_level")})
	say_queue(lines)


## Переход на следующий уровень: чистые журнал и терминал, заставка нового уровня.
func _go_next_level() -> void:
	var path := pending_next
	pending_next = ""
	dialog.clear()
	terminal.clear()
	_start_level(path)


# --- Комнаты и триггеры ------------------------------------------------------

## Переход в другое место: затемнение, новая комната, проявление.
func _transition(old: KNode) -> void:
	room.input_enabled = false
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.15)
	await tw.finished
	var back := old.name if kingdom.cwd == old.parent() else ""
	room.build(kingdom, kingdom.cwd, back)
	room.move_child(place_label, -1)
	room.move_child(fade, -1)
	tw = create_tween()
	tw.tween_property(fade, "modulate:a", 0.0, 0.15)
	await tw.finished
	room.input_enabled = not book.visible


func _on_trigger_changed(t: Dictionary) -> void:
	interp.trigger = t.get("spell", "")
	npc_line = 0


## Enter на пустой строке: действие у триггера.
func _interact() -> void:
	var t := room.current_trigger()
	if t.is_empty():
		speak(Interpreter.TANENBUM, Texts.t("action_nothing"))
		return
	var n: KNode = t["node"]
	match t["kind"]:
		"decor":
			var d: Dictionary = t["decor"]
			var title: String = d.get("title", "")
			if d.has("say"):
				speak_as({"name": title.left(1).to_upper() + title.substr(1), "tile": d["tile"]}, d["say"])
			else:
				speak(Interpreter.NARRATOR, Texts.t("look_decor", {"title": title}))
		"npc":
			var npc: Dictionary = t["npc"]
			var lines: Array = npc.get("lines", [])
			if not lines.is_empty():
				speak(npc["id"], lines[npc_line % lines.size()])
				npc_line += 1
		"door":
			if n.locked != "":
				speak(Interpreter.TANENBUM, n.locked)
			else:
				speak(Interpreter.TANENBUM, Texts.t("look_door", {"title": n.title, "name": n.name}))
		"exit":
			if n and n.to != "":
				speak(Interpreter.TANENBUM, Texts.t("look_exit", {"to": n.to}))
			else:
				speak(Interpreter.TANENBUM, Texts.t("look_exit_plain"))
		_:
			var key: String = "look_" + t["kind"]
			if not Texts.has(key):
				key = "look_item"
			speak(Interpreter.TANENBUM, Texts.t(key, {"title": n.title, "name": n.name}))
