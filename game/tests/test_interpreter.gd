## Тесты интерпретатора заклинаний. Запуск:
## godot --headless --path game --script res://tests/test_interpreter.gd
extends SceneTree

const KingdomScript = preload("res://scripts/kingdom/kingdom.gd")
const ProgressScript = preload("res://scripts/progress.gd")
const InterpreterScript = preload("res://scripts/interpreter.gd")

var failed := 0
var passed := 0


func check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("ПРОВАЛ: ", what)


func _init() -> void:
	test_level1_walkthrough()
	test_errors_and_hints()
	test_typos_and_layout()
	test_triggers_and_book()
	test_level_names()
	test_spells_and_texts()
	test_tavern_narration()
	test_wrap()
	test_level2()
	test_level3()
	print("Тесты: пройдено %d, провалено %d" % [passed, failed])
	quit(1 if failed else 0)


func new_level1():
	var k = KingdomScript.load_level("res://levels/level1.json")
	var p = ProgressScript.new()
	p.learn(["pwd", "ls", "cd"])
	var it = InterpreterScript.new(k, p)
	it.trigger = "door"
	return it


func said(res: Dictionary) -> String:
	return " | ".join(res["dialog"].map(func(d): return d["text"]))


func test_level1_walkthrough() -> void:
	var it = new_level1()
	check(it.prompt() == "torvald@linux:/castle/yard$ ", "приглашение")
	var r = it.execute("pwd")
	check(r["output"] == ["/castle/yard"] and said(r) == "Торвальд стоит во дворе Замка.", "pwd: путь и рассказчик")
	r = it.execute("ls")
	check(r["output"] == ["garden/   — сад", "stable/   — конюшня"], "ls с русскими названиями")
	check(r["echo"] == "torvald@linux:/castle/yard$ ls", "эхо команды")
	r = it.execute("cd ..")
	check(said(r) == "Торвальд вошёл в Замок.", "cd ..: рассказчик с падежом")
	r = it.execute("ls")
	check(r["output"] == ["hall/     — Большой зал (закрыт)", "tower/    — башня Таненбума", "yard/     — двор Замка"], "ls в Замке с пометкой")
	r = it.execute("cd tower")
	check(said(r) == "Торвальд вошёл в башню Таненбума." and r["goal_met"], "цель уровня 1")


func test_errors_and_hints() -> void:
	var it = new_level1()
	var r = it.execute("cd tower")
	check(said(r).begins_with("Здесь нет ничего с магическим именем tower."), "1-я ошибка: общая фраза")
	r = it.execute("cd tower")
	check(said(r).contains("Чтобы выйти, произнеси заклинание cd .."), "2-я ошибка: подсказка этапа")
	r = it.execute("cd tower")
	check(said(r).ends_with("Произнеси заклинание cd .."), "3-я ошибка: готовое заклинание")
	it.execute("cd ..")
	r = it.execute("cd hall")
	check(said(r) == "Зал пока закрыт. Ты попадёшь туда в конце обучения.", "закрытый зал, счётчик сброшен")
	r = it.execute("cd")
	check(said(r).begins_with("Куда идти?"), "cd без места")


func test_typos_and_layout() -> void:
	var it = new_level1()
	check(said(it.execute("ды")).contains("кириллицей"), "кириллица")
	check(said(it.execute("sl")).contains("хотел сказать ls?"), "перестановка букв")
	check(said(it.execute("cdd ..")).contains("хотел сказать cd?"), "лишняя буква")
	check(said(it.execute("mount cart")).begins_with("Такого заклинания ты ещё не знаешь."), "не изученное заклинание")
	check(said(it.execute("xyzzy")).begins_with("Такого заклинания ты ещё не знаешь."), "бессмыслица")
	check(InterpreterScript.tokenize("cat 'old map'  x") == ["cat", "old map", "x"], "кавычки")
	check(InterpreterScript.edit_distance("help", "hepl") == 1, "расстояние")


func test_triggers_and_book() -> void:
	var it = new_level1()
	it.trigger = ""
	check(said(it.execute("cd ..")) == "Чтобы применить это заклинание, подойди к двери или выходу.", "cd не у двери")
	check(it.execute("ls")["output"].size() == 2, "ls работает везде")
	check(said(it.execute("help")).contains("нет Книги"), "help до находки")
	it.progress.learn(["help"])
	check(it.execute("help")["open_book"], "help открывает Книгу")


## Все магические имена во всех уровнях — строчная латиница, цифры, точка, дефис, подчёркивание.
func test_level_names() -> void:
	var re := RegEx.create_from_string("^[a-z0-9._-]+$")
	var dir := DirAccess.open("res://levels")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://levels/" + f))
		var bad := []
		_collect_bad_names(data.get("world", {}), re, bad)
		for point in data.get("fstab", {}):
			_collect_bad_names(data["fstab"][point], re, bad)
		check(bad.is_empty(), "%s: магические имена строчной латиницей %s" % [f, bad])


func _collect_bad_names(nodes: Dictionary, re: RegEx, bad: Array) -> void:
	for n: String in nodes:
		if re.search(n) == null:
			bad.append(n)
		_collect_bad_names(nodes[n].get("children", {}), re, bad)


func test_spells_and_texts() -> void:
	InterpreterScript.load_spells()
	var names: Array = InterpreterScript.spells.keys()
	names.sort()
	check(names == ["./", "cat", "cd", "chmod", "cp", "help", "ls", "mount", "mv", "pwd"], "заклинания найдены в папке: %s" % [names])
	for s in InterpreterScript.spells.values():
		check(s.desc != "" and s.example != "", "у %s есть описание и пример для Книги" % s.name)
		if s.trigger != "":
			check(Texts.has("trigger_" + s.trigger), "текст для триггера %s" % s.trigger)
	# Все ключи текстов, которые встречаются в коде, есть в texts.json.
	var re := RegEx.create_from_string("(?:say|narrate|Texts\\.t)\\(\\s*(?:res,\\s*)?\"([a-z_]+)\"")
	var missing := []
	for f in ["res://scripts/interpreter.gd"] + Array(DirAccess.get_files_at("res://scripts/spells")).map(func(x): return "res://scripts/spells/" + x):
		if not f.ends_with(".gd"):
			continue
		for m in re.search_all(FileAccess.get_file_as_string(f)):
			if not m.get_string(1).ends_with("_") and not Texts.has(m.get_string(1)):
				missing.append(m.get_string(1))
	check(missing.is_empty(), "все ключи текстов есть в texts.json %s" % [missing])


func test_tavern_narration() -> void:
	var k = KingdomScript.from_dict({
		"start": "/village/tavern",
		"world": {"village": {"children": {"tavern": {"children": {
			"cart": {"children": {}},
			"storage": {"title": "кладовая", "to": "в кладовую", "children": {}},
		}}}}},
		"fstab": {"/village/tavern/cart": {"apples": {"title": "яблоки"}, "map": {"title": "карта Леса"}}},
	})
	var p = ProgressScript.new()
	p.learn(["mount", "mv", "cp"])
	var it = InterpreterScript.new(k, p)
	it.trigger = "cart"
	check(said(it.execute("mount cart")) == "Торвальд открыл повозку гостя.", "mount cart")
	check(said(it.execute("mv cart/apples storage")) == "Торвальд перенёс предмет (яблоки) в кладовую.", "mv: рассказчик")
	check(said(it.execute("cp cart/map storage")) == "Торвальд скопировал предмет (карта Леса) в кладовую.", "cp: рассказчик")


func test_wrap() -> void:
	var lines = preload("res://scripts/ui/log_panel.gd").wrap_words("произнеси заклинание cd ..", 22)
	check(Array(lines) == ["произнеси заклинание", "cd .."], "«cd ..» не разрывается при переносе: %s" % [lines])


func test_level2() -> void:
	check(InterpreterScript.route("/village", "/village/square") == "square", "маршрут в дочернее место")
	check(InterpreterScript.route("/village/square", "/village/mill") == "../mill", "маршрут в соседнее место")
	check(InterpreterScript.route("/village/square", "/village") == "..", "маршрут наверх")
	check(InterpreterScript.route("/castle", "/village/mill") == "/village/mill", "маршрут издалека")
	var k = KingdomScript.load_level("res://levels/level2.json")
	var p = ProgressScript.new()
	p.learn(["pwd", "ls", "cd", "help", "cat"])
	var it = InterpreterScript.new(k, p)
	it.trigger = "door"
	for i in 3:
		it.execute("cat sign")
	check(said(it.execute("cat sign")).ends_with("Произнеси заклинание cd square"), "подсказка ведёт на площадь")
	it.execute("cd square")
	it.trigger = "note"
	var r = it.execute("cat sign")
	check(r["output"] == ["Бабушка Марта живёт у мельницы."], "cat sign")
	for i in 3:
		r = it.execute("cat nothing")
	check(said(r).ends_with("Произнеси заклинание cd ../mill"), "следующий этап: на мельницу через ..")
	it.trigger = "door"
	it.execute("cd ../mill")
	it.trigger = "note"
	check(it.execute("cat note")["output"][0].contains("пекарню"), "записка на мельнице")
	it.trigger = "door"
	it.execute("cd ../bakery")
	it.trigger = "note"
	r = it.execute("cat letter")
	check(r["output"].size() == 4 and r["goal_met"], "письмо прочитано, цель уровня 2")


func test_level3() -> void:
	var k = KingdomScript.load_level("res://levels/level3.json")
	var p = ProgressScript.new()
	p.learn(["pwd", "ls", "cd", "help", "cat", "mount", "mv", "cp"])
	var it = InterpreterScript.new(k, p)
	it.trigger = "note"
	check(it.execute("cat book")["output"][1].contains("cart"), "книга постояльцев")
	it.trigger = "cart"
	check(it.execute("ls cart")["output"].is_empty(), "повозка пуста до mount")
	check(said(it.execute("mount cart")) == "Торвальд открыл повозку гостя.", "mount cart")
	it.execute("mv cart/apples storage")
	it.execute("mv cart/cheese kitchen")
	it.execute("mv cart/map storage")
	var warn = [{"missing": "/village/tavern/cart/map"}, {"mounted": "/village/tavern/cart"}]
	check(k.conditions_met(warn), "ловушка: карта унесена, предупреждение сработает")
	for i in 3:
		it.execute("mv nothing storage")
	check(said(it.execute("mv nothing storage")).ends_with("mv storage/map cart"), "подсказка вернуть карту")
	it.execute("mv storage/map cart")
	check(not k.conditions_met(warn), "карта вернулась")
	var r = it.execute("cp cart/map storage")
	check(said(r) == "Торвальд скопировал предмет (карта Леса) в кладовую." and r["goal_met"], "копия карты, цель уровня 3")
