## Общая часть mv и cp: перенести или скопировать предмет.
class_name TransferSpell
extends Spell

var keep_original := false


func run(it: Interpreter, _word: String, args: Array, res: Dictionary) -> bool:
	if args.size() < 2:
		return it.say(res, "cp_no_args" if keep_original else "mv_no_args")
	var src: KNode = it.kingdom.resolve(args[0])
	var item_title := src.title if src else ""
	var err := it.kingdom.copy(args[0], args[1]) if keep_original else it.kingdom.move(args[0], args[1])
	if err != Kingdom.Err.OK:
		return it.error(err, args[0], res)
	var dst := it.kingdom.resolve(args[1])
	var dest_dir := dst if dst and dst.is_dir else (dst.parent() if dst else null)
	var to := dest_dir.to if dest_dir and dest_dir.to != "" else Texts.t("to_new_place")
	it.narrate(res, "copied" if keep_original else "moved", {"item": item_title, "to": to})
	return true
