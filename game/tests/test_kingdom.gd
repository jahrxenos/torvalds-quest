## Тесты модели королевства. Запуск:
## godot --headless --path game --script res://tests/test_kingdom.gd
extends SceneTree

const KingdomScript = preload("res://scripts/kingdom/kingdom.gd")
const E = KingdomScript.Err
const ProgressScript = preload("res://scripts/progress.gd")

var failed := 0
var passed := 0


func check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("ПРОВАЛ: ", what)


func names(k, path := ".") -> Array:
	return k.list(path)["items"].map(func(n): return n.name)


func _init() -> void:
	test_level1()
	test_paths()
	test_tavern()
	test_forest()
	test_torches()
	test_goal_and_progress()
	print("Тесты: пройдено %d, провалено %d" % [passed, failed])
	quit(1 if failed else 0)


func test_level1() -> void:
	var k = KingdomScript.load_level("res://levels/level1.json")
	check(k != null, "уровень 1 загружается")
	check(k.pwd() == "/castle/yard", "старт во дворе")
	check(names(k) == ["garden", "stable"], "ls во дворе: сад и конюшня по алфавиту")
	check(k.cd("tower") == E.NOT_FOUND, "башни во дворе нет")
	check(k.cd("..") == E.OK and k.pwd() == "/castle", "cd .. ведёт в Замок")
	check(names(k) == ["hall", "tower", "yard"], "ls в Замке")
	check(k.cd("hall") == E.LOCKED and k.pwd() == "/castle", "Большой зал закрыт")
	check(k.cd("tower") == E.OK and k.pwd() == "/castle/tower", "cd tower")
	check(k.resolve("/castle/tower").title == "Башня Таненбума", "русское название")


func test_paths() -> void:
	var k = KingdomScript.load_level("res://levels/level1.json")
	check(k.cd("/castle/yard/stable") == E.OK, "абсолютный путь")
	check(k.cd("../garden") == E.OK and k.pwd() == "/castle/yard/garden", "cd ../garden")
	check(k.cd("/") == E.OK and k.pwd() == "/", "корень")
	check(k.cd("..") == E.OK and k.pwd() == "/", "выше корня некуда")
	check(k.cd("./castle/./yard/") == E.OK and k.pwd() == "/castle/yard", "точки и слэш в конце")


func test_tavern() -> void:
	var k = KingdomScript.from_dict({
		"start": "/village/tavern",
		"world": {"village": {"children": {"tavern": {"children": {
			"book": {"text": "Купец Борис. Повозка: cart"},
			"cart": {"children": {}},
			"storage": {"children": {}},
			"kitchen": {"children": {}},
		}}}}},
		"fstab": {"/village/tavern/cart": {
			"apples": {"title": "Яблоки"}, "cheese": {"title": "Сыр"}, "map": {"title": "Карта Леса", "text": "Тропа на поляну"},
		}},
	})
	check(names(k, "cart") == [], "повозка пуста до mount")
	check(k.read("book")["text"].contains("cart"), "cat book")
	check(k.read("cart")["err"] == E.IS_DIR, "cat места — ошибка")
	check(k.mount("storage") == E.NOT_MOUNTABLE, "кладовой нет в книге постояльцев")
	check(k.mount("cart") == E.OK, "mount cart")
	check(k.mount("cart") == E.ALREADY_MOUNTED, "повторный mount")
	check(names(k, "cart") == ["apples", "cheese", "map"], "товары в повозке")
	check(k.move("cart/apples", "storage") == E.OK, "mv яблок в кладовую")
	check(k.move("cart/cheese", "kitchen") == E.OK, "mv сыра на кухню")
	check(k.copy("cart/map", "storage") == E.OK, "cp карты")
	check(names(k, "storage") == ["apples", "map"] and names(k, "cart") == ["map"], "оригинал карты остался")
	check(k.copy("cart/map", "storage") == E.EXISTS, "вторая копия — уже есть")
	check(k.copy("storage", "kitchen") == E.IS_DIR, "cp места без -r нельзя")
	check(k.move("kitchen", "kitchen") == E.INVALID, "место в само себя")
	check(k.move("cart/map", "storage/map2") == E.OK and k.resolve("storage/map2").text == "Тропа на поляну", "mv с переименованием")
	check(k.move("nothing", "storage") == E.NOT_FOUND, "mv несуществующего")


func test_forest() -> void:
	var k = KingdomScript.from_dict({
		"start": "/forest",
		"world": {"forest": {"children": {"scroll": {"text": "Заросли расступаются"}, "path": {"children": {}}}}},
	})
	check(not k.resolve("scroll").executable, "свиток не заряжен")
	check(k.make_executable("scroll") == E.OK and k.resolve("scroll").executable, "chmod +x scroll")
	check(k.make_executable("path") == E.IS_DIR, "chmod +x места")



func test_torches() -> void:
	var k = KingdomScript.from_dict({
		"start": "/castle/hall",
		"world": {"castle": {"children": {"hall": {"children": {
			"torch1": {"text": KingdomScript.TORCH_LIT},
			"torch2": {"text": KingdomScript.TORCH_DARK},
			"torch3": {"text": KingdomScript.TORCH_DARK},
			"door": {"text": "Дверь"},
		}}}}},
		"goal": [{"lit": "torch*"}],
	})
	check(k.glob("torch*") == ["torch1", "torch2", "torch3"], "torch* — три факела")
	check(k.glob("/castle/hall/torch*").size() == 3, "шаблон с абсолютным путём")
	check(k.is_dark("torch2") and not k.is_dark("torch1"), "dark")
	check(k.read("torch2")["text"] == KingdomScript.TORCH_DARK, "cat факела")
	check(not k.is_goal_met(), "не все горят")
	for t in k.glob("torch*"):
		if k.is_dark(t):
			k.light(t)
	check(k.is_goal_met(), "цикл с условием зажёг все")
	k.light("torch1")
	check(k.is_dark("torch1") and not k.is_goal_met(), "light по горящему гасит")


func test_goal_and_progress() -> void:
	var k = KingdomScript.load_level("res://levels/level1.json")
	var p := ProgressScript.new()
	p.learn(["pwd", "ls", "cd"])
	check(not k.is_goal_met(), "цель не достигнута в начале")
	k.cd("/castle/tower")
	check(k.is_goal_met(), "цель уровня 1: в башне")
	p.apply_find(1, k.find)
	check(p.knows("help") and "spellbook" in p.items and 1 in p.passed, "находка: Книга и help")
	var restored = ProgressScript.from_dict(p.to_dict())
	check(restored.to_dict() == p.to_dict(), "прогресс сохраняется и загружается")

	var f = KingdomScript.from_dict({
		"start": "/forest",
		"world": {"forest": {"children": {"scroll": {"text": "Заросли расступаются"}}}},
		"goal": [{"ran": "/forest/scroll"}],
	})
	check(f.run("scroll")["err"] == E.NOT_EXEC, "незаряженный свиток молчит")
	f.make_executable("scroll")
	check(f.run("./scroll")["text"] == "Заросли расступаются" and f.is_goal_met(), "./scroll после chmod")
