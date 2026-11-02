## for — повторить заклинание для каждого элемента: for t in torch*; do light $t; done
extends Spell


func _init() -> void:
	name = "for"
	desc = "повторить для каждого"
	example = "for t in torch*; do ...; done"
	trigger = "altar"


func run(it: Interpreter, _word: String, _args: Array, res: Dictionary) -> bool:
	return it.run_for(it.current_line, res)
