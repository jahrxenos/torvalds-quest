## Игровой экран: сверху комната, под ним панель диалогов, внизу терминал.
## В веб-версии под терминалом — клавиатура с буквами: на телефоне вводить
## заклинания мышкой неудобно, а аппаратной клавиатуры там нет.
extends Control

const W := 640
const H := 360
const KB_H := 188
const LEVEL := "res://levels/level1.json"
const C_BORDER := Color("#808080")

var kingdom: Kingdom
var progress := Progress.new()
var interp: Interpreter
var level: Dictionary
var speakers: Dictionary
var dialog: LogPanel
var terminal: TerminalPanel
var keyboard: KeyboardPanel
var book: SpellBook
var room: RoomView
var menu: ButtonMenu
## Открытые экраны меню по порядку (Esc — вернуться на предыдущий).
var menu_stack: Array[String] = []
var settings: Dictionary = {}
## Идёт игра (а не главное меню).
var in_game := false
## После закрытия окна с текстом вернуться в главное меню (окно «Об игре»).
var story_back_to_menu := false
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
## Номер текущего этапа уровня (если у уровня есть phases).
var phase := 0
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
## Заклинания, выученные последними: в Книге они подсвечены.
var newest_spells: Array = []
## Высоты частей экрана зависят от шрифта.
var dialog_h := 0
var term_h := 0
var world_h := 0


func _ready() -> void:
	# Самопроверка собранной игры: TorvaldsQuest.x86_64 --headless -- --selftest
	if "--selftest" in OS.get_cmdline_user_args():
		Interpreter.load_spells()
		UiFont.setup()
		var font_ok := UiFont.regular != null
		print("selftest: заклинаний %d, шрифт %s, текст: %s" % [Interpreter.spells.size(), "есть" if font_ok else "НЕТ", Texts.t("cd_no_arg")])
		get_tree().quit(0 if Interpreter.spells.size() == 15 and font_ok else 1)
		return
	RenderingServer.set_default_clear_color(Color.BLACK)
	UiFont.setup()
	theme = UiFont.theme()
	dialog_h = UiFont.line_h * 3 + 8
	term_h = UiFont.line_h * TerminalPanel.LINES + 8
	world_h = H - dialog_h - term_h
	speakers = JSON.parse_string(FileAccess.get_file_as_string("res://data/speakers.json"))
	_build_screen()
	_setup_audio()
	settings = SaveGame.load_settings()
	_apply_settings()
	var args := OS.get_cmdline_user_args()
	var debug := Array(args).any(func(a): return a.begins_with("--demo") or a.begins_with("--level="))
	show_story = "--demo=splash" in args or not Array(args).any(func(a): return a.begins_with("--demo"))
	if OS.has_feature("web"):
		# В браузере нет аппаратной клавиатуры: экран с буквами — под основным экраном.
		get_window().size = Vector2i(W, H + KB_H)
		keyboard.visible = true
	if not debug:
		_show_main_menu()
		return
	if "--demo=menu" in args:
		_show_main_menu()
		_demo(["@shot:menu_main", "@screen:levels", "@shot:menu_levels", "@screen:settings", "@shot:menu_settings", "@quit"])
		return
	# Отладка: --level=2 — начать со второго уровня, как будто первые пройдены.
	var start_level := 1
	for a in args:
		if a.begins_with("--level="):
			start_level = int(a.substr(8))
	_begin_game(_progress_before(start_level), _level_path(start_level), start_level == 1)
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
	elif "--demo=forest" in args:
		_demo(["@shot:l4_start", "@scroll", "./scroll", "@note", "cat note", "@scroll", "chmod +x scroll", "./scroll",
			"@shot:l4_open", "@npc", "@enter", "@shot:l4_fireflies", "@quit"])
	elif "--demo=hall" in args:
		_demo(["@shot:l5_start", "@altar", "light torch1", "for t in torch*; do light $t; done", "@shot:l5_phase1",
			"@next", "@next", "@next", "@next", "@shot:l5_draft", "for t in torch*; do if dark $t; then light $t; fi; done",
			"@shot:l5_done", "@quit"])
	elif "--demo=shot" in args:
		# Кадр уровня для отчёта: build/screen_levelN.png
		var shots := {
			1: ["pwd", "ls", "@exit", "cd ..", "@door:tower", "cd tower", "@npc", "@enter"],
			2: ["@door:square", "cd square", "@note", "cat sign", "@exit", "cd ..", "@door:bakery", "cd bakery", "@npc", "@enter"],
			3: ["@note", "cat book", "@cart", "mount cart", "ls cart", "mv cart/apples storage"],
			4: ["@scroll", "chmod +x scroll", "./scroll", "@npc", "@enter"],
			5: ["@altar", "for t in torch*; do light $t; done", "@next", "@next", "@next", "@next",
				"for t in torch*; do if dark $t; then light $t; fi; done"],
		}
		var n := int(level.get("id", 1))
		_demo(shots[n] + ["@shot:screen_level%d" % n, "@quit"])
	elif "--demo=book" in args:
		_demo(["@next", "@next", "@next", "@next", "@shot:book_intro", "help", "@shot:book_open", "@quit"])
	elif "--demo=look" in args:
		_demo(["@door:stable", "@enter", "@exit", "@enter", "@decor", "@enter"])
	elif "--demo=intro" in args:
		_demo(["@next", "@next", "@next", "@next", "ls", "@exit", "cd ..", "@door:tower", "cd tower", "@next"])


## Отладка: набирает заклинания сама, по букве. Запуск: godot --path game -- --demo
## Строки с @ — действия: @exit, @door:имя, @npc — встать к триггеру; @enter — нажать Enter.
func _demo(lines: Array) -> void:
	room.walk_locked = true
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
		if line.begins_with("@screen:"):
			_open_screen(line.substr(8))
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

	# Экранные кнопки: в браузере это единственный способ набрать заклинание.
	keyboard = KeyboardPanel.new()
	keyboard.position = Vector2(0, H)
	keyboard.size = Vector2(W, KB_H)
	keyboard.visible = false
	keyboard.char_typed.connect(_on_kb_char)
	keyboard.enter_pressed.connect(_on_kb_enter)
	keyboard.backspace_pressed.connect(_on_kb_backspace)
	add_child(keyboard)

	book = SpellBook.new()
	book.size = Vector2(600, H - 12)
	book.position = Vector2((W - 600) / 2, 6)
	add_child(book)

	menu = ButtonMenu.new()
	menu.size = Vector2(340, 250)
	menu.position = Vector2((W - 340) / 2, (H - 250) / 2)
	menu.chosen.connect(_on_menu)
	menu.adjusted.connect(_on_adjust)
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
	if story_back_to_menu:
		story_back_to_menu = false
		_open_screen("main")
		return
	room.input_enabled = in_game
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
	var level_spells: Array = level.get("spells", []).filter(func(s): return not progress.knows(s))
	progress.learn(level.get("spells", []))
	interp = Interpreter.new(kingdom, progress)
	finished = false
	warned.clear()
	phase = 0
	if level.has("phases"):
		kingdom.goal = level["phases"][0]["goal"]
		kingdom.torch_toggle = level["phases"][0].get("toggle", true)
	room.build(kingdom, kingdom.cwd)
	room.move_child(place_label, -1)
	room.move_child(fade, -1)
	room.input_enabled = true
	_update_place()
	play_music(level.get("music", "res://assets/music/level%d.ogg" % int(level.get("id", 0))))
	var splash: Dictionary = level.get("splash", {})
	if show_story and not splash.is_empty():
		show_pages([{"title": Texts.t("level_title", {"n": int(level.get("id", 0)), "title": level.get("title", "")}), "text": splash["text"]}])
	var intro: Array = level.get("intro", []).duplicate()
	if not level_spells.is_empty():
		newest_spells = level_spells
		var book_line := _book_line(level_spells)
		if book_line != "":
			intro.append({"speaker": Interpreter.NARRATOR, "text": book_line})
	say_queue(intro)


## «Торвальд записал в Книгу заклинаний новое заклинание cat.» Пусто, если Книги ещё нет.
func _book_line(spell_names: Array) -> String:
	if not progress.knows("help"):
		return ""
	var shown: Array = spell_names.filter(func(s): return Interpreter.spells.has(s))
	if shown.is_empty():
		return ""
	if shown.size() == 1:
		return Texts.t("book_new_one", {"spells": shown[0]})
	var list: String = ", ".join(shown.slice(0, -1)) + " и " + str(shown.back())
	return Texts.t("book_new_many", {"spells": list})


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


# --- Меню --------------------------------------------------------------------

## Меню паузы по Esc во время игры.
func _open_menu() -> void:
	menu_stack.clear()
	_open_screen("pause")


func _close_menu() -> void:
	menu.hide()
	menu_stack.clear()
	room.input_enabled = in_game


## Главное меню: фоном двор Замка, игра не идёт.
func _show_main_menu() -> void:
	in_game = false
	story.hide()
	story_pages.clear()
	book.hide()
	queue.clear()
	_queue_running = false
	pending_next = ""
	pending_epilogue = false
	dialog.clear()
	terminal.clear()
	level = JSON.parse_string(FileAccess.get_file_as_string(LEVEL))
	kingdom = Kingdom.from_dict(level)
	room.build(kingdom, kingdom.cwd)
	room.move_child(place_label, -1)
	room.move_child(fade, -1)
	_update_place()
	room.input_enabled = false
	menu_stack.clear()
	_open_screen("main")
	play_music("res://assets/music/menu.ogg")


func _open_screen(screen: String) -> void:
	if menu_stack.is_empty() or menu_stack.back() != screen:
		menu_stack.append(screen)
	room.input_enabled = false
	var web := OS.get_name() == "Web"
	match screen:
		"main":
			var items := []
			var save := SaveGame.load_game()
			if not save.is_empty() and save["next_level"] != "":
				items.append({"id": "continue", "text": Texts.t("menu_continue")})
			items.append({"id": "new", "text": Texts.t("menu_new")})
			items.append({"id": "levels", "text": Texts.t("menu_levels")})
			items.append({"id": "settings", "text": Texts.t("menu_settings")})
			items.append({"id": "about", "text": Texts.t("menu_about")})
			if not web:
				items.append({"id": "quit", "text": Texts.t("menu_quit")})
			menu.open(Texts.t("prologue_title"), items, Texts.t("menu_subtitle"))
		"pause":
			var items := [
				{"id": "resume", "text": Texts.t("menu_resume")},
				{"id": "restart", "text": Texts.t("menu_restart")},
				{"id": "settings", "text": Texts.t("menu_settings")},
				{"id": "mainmenu", "text": Texts.t("menu_main")},
			]
			if not web:
				items.append({"id": "quit", "text": Texts.t("menu_quit")})
			menu.open(Texts.t("menu_pause"), items)
		"levels":
			var unlocked := _max_unlocked_level()
			var items := []
			for n in range(1, LEVEL_COUNT + 1):
				var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_level_path(n)))
				var text := Texts.t("level_title", {"n": n, "title": d.get("title", "")})
				items.append({"id": "level_%d" % n, "text": text, "disabled": n > unlocked})
			items.append({"id": "back", "text": Texts.t("menu_back")})
			menu.open(Texts.t("menu_levels"), items)
		"settings":
			menu.open(Texts.t("menu_settings"), [
				{"id": "music", "text": _setting_text("music")},
				{"id": "sfx", "text": _setting_text("sfx")},
				{"id": "fullscreen", "text": _setting_text("fullscreen")},
				{"id": "back", "text": Texts.t("menu_back")},
			], Texts.t("menu_settings_hint"))


## Esc в меню: на предыдущий экран; из паузы — обратно в игру; в главном меню ничего не делает.
func _menu_back() -> void:
	if menu_stack.size() > 1:
		menu_stack.pop_back()
		_open_screen(menu_stack.back())
	elif in_game:
		_close_menu()


func _on_menu(id: String) -> void:
	match id:
		"resume":
			_close_menu()
		"restart":
			_close_menu()
			_restart_level()
		"settings", "levels":
			_open_screen(id)
		"mainmenu":
			_show_main_menu()
		"quit":
			get_tree().quit()
		"back":
			_menu_back()
		"new":
			_close_menu()
			_new_game()
		"continue":
			var save := SaveGame.load_game()
			_close_menu()
			_begin_game(save["progress"], save["next_level"])
		"about":
			menu.hide()
			story_back_to_menu = true
			show_pages([{"title": Texts.t("about_title"), "text": Texts.t("about"), "footer": Texts.t("about_footer")}])
		"music", "sfx":
			_on_adjust(id, 1)
		"fullscreen":
			settings["fullscreen"] = not settings["fullscreen"]
			_apply_settings()
			menu.set_text(id, _setting_text(id))
		_:
			if id.begins_with("level_"):
				var n := int(id.substr(6))
				_close_menu()
				_begin_game(_progress_before(n), _level_path(n))


## ←/→ в настройках: громкость шагами по 10 %.
func _on_adjust(id: String, delta: int) -> void:
	if id in ["music", "sfx"]:
		var v: int = int(settings[id]) + delta * 10
		if v > 100:
			v = 0  # Enter по кругу: 100 % → 0 %
		settings[id] = clampi(v, 0, 100)
		_apply_settings()
		menu.set_text(id, _setting_text(id))
		play_sfx("click")


func _setting_text(id: String) -> String:
	match id:
		"music":
			return Texts.t("set_music", {"v": int(settings["music"])})
		"sfx":
			return Texts.t("set_sfx", {"v": int(settings["sfx"])})
		"fullscreen":
			return Texts.t("set_fullscreen_on" if settings["fullscreen"] else "set_fullscreen_off")
	return id


func _apply_settings() -> void:
	SaveGame.save_settings(settings)
	for bus in ["Music", "SFX"]:
		var idx := AudioServer.get_bus_index(bus)
		var v: float = settings["music" if bus == "Music" else "sfx"] / 100.0
		AudioServer.set_bus_mute(idx, v <= 0.0)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


# --- Начало игры и уровни ------------------------------------------------------

const LEVEL_COUNT := 5


static func _level_path(n: int) -> String:
	return "res://levels/level%d.json" % n


## До какого уровня можно дойти: следующий после последнего пройденного.
func _max_unlocked_level() -> int:
	var save := SaveGame.load_game()
	if save.is_empty():
		return 1
	var passed: Array = save["progress"].passed
	return mini(LEVEL_COUNT, (passed.max() if not passed.is_empty() else 0) + 1)


## Прогресс, как будто уровни до n пройдены: их заклинания и находки.
static func _progress_before(n: int) -> Progress:
	var p := Progress.new()
	for i in range(1, n):
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_level_path(i)))
		p.learn(d.get("spells", []))
		p.apply_find(i, d.get("find", {}))
	return p


func _new_game() -> void:
	_begin_game(Progress.new(), LEVEL, true)


func _begin_game(p: Progress, path: String, prologue: bool = false) -> void:
	progress = p
	in_game = true
	newest_spells = []
	dialog.clear()
	terminal.clear()
	queue.clear()
	_queue_running = false
	if prologue and show_story:
		show_pages([{"title": Texts.t("prologue_title"), "text": Texts.t("prologue")}])
	_start_level(path)


# --- Ввод --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var key := event as InputEventKey
	get_viewport().set_input_as_handled()
	if menu.visible:
		if key.keycode == KEY_ESCAPE:
			_menu_back()
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


## Экранные кнопки: буквы, знаки и пробел идут прямо в терминал.
func _on_kb_char(ch: String) -> void:
	if menu.visible or story.visible:
		return
	terminal.type_char(ch)


## «Стереть» с экранной клавиатуры: удаляет последний набранный символ.
func _on_kb_backspace() -> void:
	if menu.visible or story.visible:
		return
	terminal.backspace()


## Enter с экранной клавиатуры: то же, что и обычная Enter.
func _on_kb_enter() -> void:
	if menu.visible:
		return
	if story.visible:
		_next_page()
		return
	if book.visible:
		book.hide()
		room.input_enabled = true
		return
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
	play_sfx("spell" if interp.errors_in_row == 0 else "error")
	if kingdom.cwd != before:
		_transition(before)
	if res["open_book"]:
		room.input_enabled = false
		book.open(progress.spells, newest_spells)
		play_sfx("book")
	room.update_barrier()
	if level.get("live_room", false) and kingdom.cwd == before:
		room.refresh()  # факелы и другие предметы меняют вид
	_check_warnings()
	if res["goal_met"] and not finished:
		if phase < level.get("phases", []).size() - 1:
			_next_phase()
		else:
			_finish_level()


## Этапы уровня (поле phases): [{"goal": [...], "done": [реплики], "set": {путь: текст}}].
## Цель уровня — цель текущего этапа; когда она выполнена, меняются тексты предметов и начинается следующий этап.
func _next_phase() -> void:
	var phases: Array = level["phases"]
	var done: Dictionary = phases[phase]
	for path: String in done.get("set", {}):
		var n := kingdom.resolve(path)
		if n:
			n.text = done["set"][path]
	phase += 1
	kingdom.goal = phases[phase]["goal"]
	kingdom.torch_toggle = phases[phase].get("toggle", true)
	room.refresh()
	say_queue(done.get("done", []))

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
	room.celebrate()
	var find := kingdom.find
	var new_spells: Array = find.get("spells", []).filter(func(s): return not progress.knows(s))
	progress.apply_find(int(level.get("id", 0)), find)
	play_sfx("find")
	# Автосохранение: следующий уровень и всё, что Торвальд выучил и нашёл.
	SaveGame.save(progress, level.get("next", ""))
	var lines: Array = []
	if find.has("text"):
		lines.append({"speaker": find.get("speaker", Interpreter.NARRATOR), "text": find["text"]})
	if not new_spells.is_empty():
		newest_spells = new_spells
		var book_line := _book_line(new_spells)
		if book_line != "":
			lines.append({"speaker": Interpreter.NARRATOR, "text": book_line})
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
	play_sfx("door")
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
	if interp:  # в главном меню интерпретатора ещё нет
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
				play_sfx("talk")
			# Цель уровня может требовать разговора с персонажем ({"talked": id}).
			kingdom.talked[npc["id"]] = true
			if kingdom.is_goal_met() and not finished:
				_finish_level()
		"barrier":
			speak(Interpreter.TANENBUM, t["barrier"].get("look", Texts.t("look_decor", {"title": t["label"]})))
		"torch":
			var state := Texts.t("torch_state_lit" if n.text == Kingdom.TORCH_LIT else "torch_state_dark")
			speak(Interpreter.NARRATOR, Texts.t("look_torch", {"title": n.title, "name": n.name, "state": state}))
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


# --- Звук ----------------------------------------------------------------------

## Короткие звуки действий: файлы в assets/sfx (если файла нет — тишина).
const SFX := {
	"step": "res://assets/sfx/step.ogg",
	"spell": "res://assets/sfx/spell.ogg",
	"error": "res://assets/sfx/error.ogg",
	"door": "res://assets/sfx/door.ogg",
	"find": "res://assets/sfx/find.ogg",
	"click": "res://assets/sfx/click.ogg",
	"talk": "res://assets/sfx/talk.ogg",
	"book": "res://assets/sfx/book.ogg",
}

var _music: AudioStreamPlayer
var _music_path := ""
var _sfx_players: Array[AudioStreamPlayer] = []


func _setup_audio() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	room.stepped.connect(func(): play_sfx("step"))


## Фоновая музыка уровня: файл assets/music/levelN.ogg (или поле music в уровне). Нет файла — тишина.
func play_music(path: String) -> void:
	if path == _music_path:
		return
	_music_path = path
	_music.stop()
	if path == "" or not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true
	_music.stream = stream
	_music.play()


func play_sfx(id: String) -> void:
	var path: String = SFX.get(id, "")
	if path == "" or not ResourceLoader.exists(path):
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = load(path)
			p.play()
			return
