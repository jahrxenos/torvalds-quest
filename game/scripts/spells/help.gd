extends Spell


func _init() -> void:
	name = "help"
	desc = "открыть Книгу заклинаний"
	example = "help"


func run(_it: Interpreter, _word: String, _args: Array, res: Dictionary) -> bool:
	res["open_book"] = true
	return true
