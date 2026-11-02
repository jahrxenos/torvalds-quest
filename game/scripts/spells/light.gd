## light — зажечь факел (горящий от повторного заклинания гаснет).
extends Spell


func _init() -> void:
	name = "light"
	desc = "зажечь или погасить факел"
	example = "light torch1"
	trigger = "altar"


func run(it: Interpreter, _word: String, args: Array, res: Dictionary) -> bool:
	if args.is_empty():
		return it.say(res, "light_no_arg")
	var ok := true
	for path: String in args:
		var err := it.kingdom.light(path)
		if err != Kingdom.Err.OK:
			return it.error(err, path, res)
		var lit := not it.kingdom.is_dark(path)
		it.out(res, "%s: %s" % [path.get_file(), Texts.t("torch_state_lit" if lit else "torch_state_dark")])
		if not it.in_loop:
			it.narrate(res, "light_on" if lit else "light_off", {"name": path.get_file()})
	return ok
