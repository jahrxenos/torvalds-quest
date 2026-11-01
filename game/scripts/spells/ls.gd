extends Spell


func _init() -> void:
	name = "ls"
	desc = "осмотреться"
	example = "ls"


func run(it: Interpreter, _word: String, args: Array, res: Dictionary) -> bool:
	var path: String = args[0] if args.size() > 0 else "."
	var r := it.kingdom.list(path)
	if r["err"] != Kingdom.Err.OK:
		return it.error(r["err"], path, res)
	for node: KNode in r["items"]:
		var shown := node.name + ("/" if node.is_dir else "")
		var line := "%s— %s" % [shown.rpad(10), node.title]
		if node.mark != "":
			line += " (%s)" % node.mark
		it.out(res, line)
	return true
