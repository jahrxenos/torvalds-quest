## if — сделать, только если условие верно: if dark torch1; then light torch1; fi
extends Spell


func _init() -> void:
	name = "if"
	desc = "сделать, если условие верно"
	example = "if dark $t; then ...; fi"
	trigger = "altar"


func run(it: Interpreter, _word: String, _args: Array, res: Dictionary) -> bool:
	return it.run_if(it.current_line, res)
