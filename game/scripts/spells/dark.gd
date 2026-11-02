## dark — проверить, темно ли (погас ли факел). В условии if даёт «да», если темно.
extends Spell


func _init() -> void:
	name = "dark"
	desc = "проверить, погас ли факел"
	example = "dark torch1"
	trigger = "altar"


func run(it: Interpreter, _word: String, args: Array, res: Dictionary) -> bool:
	if args.is_empty():
		return it.say(res, "dark_no_arg")
	for path: String in args:
		if it.kingdom.resolve(path) == null:
			return it.error(Kingdom.Err.NOT_FOUND, path, res)
		it.out(res, "%s: %s" % [path.get_file(), Texts.t("dark_yes" if it.kingdom.is_dark(path) else "dark_no")])
	return true
