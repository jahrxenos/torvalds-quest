extends Control


func _ready() -> void:
	# Самопроверка собранной игры: TorvaldsQuest.x86_64 --headless -- --selftest
	if "--selftest" in OS.get_cmdline_user_args():
		Interpreter.load_spells()
		print("selftest: заклинаний %d, текст: %s" % [Interpreter.spells.size(), Texts.t("cd_no_arg")])
		get_tree().quit(0 if Interpreter.spells.size() == 10 else 1)
