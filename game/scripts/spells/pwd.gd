extends Spell


func _init() -> void:
	name = "pwd"
	desc = "узнать, где ты"
	example = "pwd"


func run(it: Interpreter, _word: String, _args: Array, res: Dictionary) -> bool:
	var here := it.kingdom.cwd
	it.out(res, it.kingdom.pwd())
	if here.at != "":
		it.narrate(res, "pwd_at", {"at": here.at})
	else:
		it.narrate(res, "pwd_plain", {"title": here.title})
	return true
