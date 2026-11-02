## Меню паузы по Esc: Продолжить, Начать уровень заново, Выход (в браузере выхода нет).
## Стрелки — выбор, Enter — выполнить, Esc — закрыть. Полное меню с настройками — задача #17.
class_name PauseMenu
extends Panel

signal resume
signal restart
signal quit_game

var _buttons: Array[Button] = []


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.92)
	style.border_color = Color("#808080")
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)
	var title := Label.new()
	title.text = "Пауза"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#f0e68c"))
	title.position = Vector2(0, 10)
	title.size = Vector2(size.x, UiFont.line_h)
	add_child(title)
	_add_button("Продолжить", resume)
	_add_button("Начать уровень заново", restart)
	if OS.get_name() != "Web":
		_add_button("Выход", quit_game)
	for i in _buttons.size():
		_buttons[i].focus_neighbor_top = _buttons[i - 1].get_path()
		_buttons[i].focus_neighbor_bottom = _buttons[(i + 1) % _buttons.size()].get_path()
	hide()


func _add_button(text: String, sig: Signal) -> void:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.position = Vector2(20, 44 + _buttons.size() * (UiFont.line_h + 10))
	b.size = Vector2(size.x - 40, UiFont.line_h + 6)
	b.add_theme_color_override("font_color", Color("#e4e4e4"))
	b.add_theme_color_override("font_focus_color", Color("#5fd75f"))
	b.add_theme_color_override("font_hover_color", Color("#5fd75f"))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.37, 0.84, 0.37, 0.15)
	focus.border_color = Color("#5fd75f")
	focus.set_border_width_all(1)
	b.add_theme_stylebox_override("focus", focus)
	b.pressed.connect(func(): sig.emit())
	add_child(b)
	_buttons.append(b)


func open() -> void:
	show()
	_buttons[0].grab_focus()
