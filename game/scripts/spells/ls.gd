extends Spell


func _init() -> void:
	name = "ls"
	desc = "осмотреться"
	example = "ls"


func run(it: Interpreter, _word: String, args: Array, res: Dictionary) -> bool:
	# Несколько имён (например, после torch*) — показываем каждое.
	var paths: Array = args if not args.is_empty() else ["."]
	for path: String in paths:
		var r := it.kingdom.list(path)
		if r["err"] != Kingdom.Err.OK:
			return it.error(r["err"], path, res)
		for node: KNode in r["items"]:
			var shown := node.name + ("/" if node.is_dir else "")
			var line := "%s— %s" % [shown.rpad(10), node.title]
			var mark := _mark(node)
			if mark != "":
				line += " (%s)" % mark
			it.out(res, line)
	return true


## Пометка: своя у места или состояние факела.
static func _mark(node: KNode) -> String:
	if node.text == Kingdom.TORCH_LIT:
		return Texts.t("torch_state_lit")
	if node.text == Kingdom.TORCH_DARK:
		return Texts.t("torch_state_dark")
	return node.mark
