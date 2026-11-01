## Узел королевства: место (каталог) или предмет (файл).
class_name KNode
extends RefCounted

## Магическое имя — оно пишется в заклинаниях.
var name: String
## Название в игре, по-русски.
var title: String
var is_dir: bool = false
## Текст записки или свитка.
var text: String = ""
## Свиток «заряжен» (chmod +x).
var executable: bool = false
## Непустая строка — место закрыто, это сообщение для игрока.
var locked: String = ""
## Формы для рассказчика: «куда» (в конюшню) и «где» (в конюшне).
var to: String = ""
var at: String = ""
## Пометка в выводе ls, например «закрыт» или «заросла».
var mark: String = ""
## Дочерние узлы: магическое имя -> KNode.
var children: Dictionary = {}

var _parent: WeakRef = null


func _init(p_name: String = "", p_title: String = "", p_is_dir: bool = false) -> void:
	name = p_name
	title = p_title if p_title != "" else p_name
	is_dir = p_is_dir


func parent() -> KNode:
	return _parent.get_ref() if _parent else null


func add_child(node: KNode) -> void:
	children[node.name] = node
	node._parent = weakref(self)


func remove_child(node: KNode) -> void:
	children.erase(node.name)
	node._parent = null


func get_child(child_name: String) -> KNode:
	return children.get(child_name)


## Имена детей по алфавиту, как в выводе ls.
func child_names() -> Array[String]:
	var names: Array[String] = []
	names.assign(children.keys())
	names.sort()
	return names


## Глубокая копия узла (без родителя).
func duplicate_node() -> KNode:
	var copy := KNode.new(name, title, is_dir)
	copy.text = text
	copy.executable = executable
	copy.locked = locked
	copy.to = to
	copy.at = at
	copy.mark = mark
	for child: KNode in children.values():
		copy.add_child(child.duplicate_node())
	return copy


func is_ancestor_of(node: KNode) -> bool:
	var p := node.parent()
	while p:
		if p == self:
			return true
		p = p.parent()
	return false
