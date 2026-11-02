## * — «все подходящие»: torch* — все факелы. Работает внутри других заклинаний.
extends Spell


func _init() -> void:
	name = "*"
	desc = "все подходящие (torch* — все факелы)"
	example = "ls torch*"


func run(it: Interpreter, _word: String, _args: Array, res: Dictionary) -> bool:
	return it.say(res, "star_alone")
