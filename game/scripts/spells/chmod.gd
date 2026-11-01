extends Spell


func _init() -> void:
	name = "chmod"
	desc = "зарядить свиток силой"
	example = "chmod +x scroll"
	trigger = "scroll"


func run(it: Interpreter, _word: String, args: Array, res: Dictionary) -> bool:
	if args.size() < 2 or args[0] != "+x":
		return it.say(res, "chmod_usage")
	var err := it.kingdom.make_executable(args[1])
	if err != Kingdom.Err.OK:
		return it.error(err, args[1], res)
	it.narrate(res, "chmod_done")
	return true
