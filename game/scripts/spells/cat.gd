extends Spell


func _init() -> void:
	name = "cat"
	desc = "прочитать записку"
	example = "cat letter"
	trigger = "note"


func run(it: Interpreter, _word: String, args: Array, res: Dictionary) -> bool:
	if args.is_empty():
		return it.say(res, "cat_no_arg")
	var r := it.kingdom.read(args[0])
	if r["err"] != Kingdom.Err.OK:
		return it.error(r["err"], args[0], res)
	for line: String in r["text"].split("\n"):
		it.out(res, line)
	return true
