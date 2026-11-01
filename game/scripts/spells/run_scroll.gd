## ./свиток — прочитать заряженный свиток вслух.
extends Spell


func _init() -> void:
	name = "./"
	desc = "прочитать свиток вслух"
	example = "./scroll"
	trigger = "scroll"


func run(it: Interpreter, word: String, _args: Array, res: Dictionary) -> bool:
	var path := word.substr(2)
	var r := it.kingdom.run(path)
	if r["err"] == Kingdom.Err.NOT_EXEC:
		return it.say(res, "scroll_silent")
	if r["err"] != Kingdom.Err.OK:
		return it.error(r["err"], path, res)
	it.narrate_text(res, r["text"])
	return true
