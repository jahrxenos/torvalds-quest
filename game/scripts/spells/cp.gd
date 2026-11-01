extends TransferSpell


func _init() -> void:
	name = "cp"
	desc = "скопировать предмет"
	example = "cp map storage"
	trigger = "cart"
	keep_original = true
