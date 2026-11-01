extends Spell


func _init() -> void:
	name = "mount"
	desc = "открыть повозку гостя"
	example = "mount cart"
	trigger = "cart"


func run(it: Interpreter, _word: String, args: Array, res: Dictionary) -> bool:
	if args.is_empty():
		return it.say(res, "mount_no_arg")
	var err := it.kingdom.mount(args[0])
	if err != Kingdom.Err.OK:
		return it.error(err, args[0], res)
	it.narrate(res, "mounted")
	return true
