## Прогресс игры: что Торвальд выучил и нашёл. Переходит с уровня на уровень и сохраняется на диск.
class_name Progress
extends RefCounted

## Заклинания, которые Торвальд уже знает.
var spells: Array[String] = []
## Находки: spellbook, letter, map, fireflies, hat.
var items: Array[String] = []
## Номера пройденных уровней.
var passed: Array[int] = []


func knows(spell: String) -> bool:
	return spell in spells


func learn(new_spells: Array) -> void:
	for s: String in new_spells:
		if s not in spells:
			spells.append(s)


## Находка уровня: предмет и заклинания, которые она даёт (например, Книга -> help).
func apply_find(level_id: int, find: Dictionary) -> void:
	var item: String = find.get("item", "")
	if item != "" and item not in items:
		items.append(item)
	learn(find.get("spells", []))
	if level_id not in passed:
		passed.append(level_id)


func to_dict() -> Dictionary:
	return {"spells": spells, "items": items, "passed": passed}


static func from_dict(d: Dictionary) -> Progress:
	var p := Progress.new()
	p.spells.assign(d.get("spells", []))
	p.items.assign(d.get("items", []))
	for n in d.get("passed", []):
		p.passed.append(int(n))
	return p
