extends Spell


func _init() -> void:
	name = "cd"
	desc = "перейти в другое место"
	example = "cd stable"
	trigger = "door"


func run(it: Interpreter, _word: String, args: Array, res: Dictionary) -> bool:
	if args.is_empty():
		return it.say(res, "cd_no_arg")
	var err := it.kingdom.cd(args[0])
	if err != Kingdom.Err.OK:
		return it.error(err, args[0], res)
	var here := it.kingdom.cwd
	if here.to != "":
		it.narrate(res, "cd_entered", {"to": here.to})
	else:
		it.narrate(res, "cd_entered_plain", {"title": here.title})
	return true
