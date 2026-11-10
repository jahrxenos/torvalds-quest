## Меню из кнопок: главное меню, пауза, выбор уровня, настройки.
## Стрелки ↑/↓ — выбор, Enter — выполнить, ←/→ — изменить значение (громкость). Esc обрабатывает сцена.
class_name ButtonMenu
extends Panel

signal chosen(id: String)
signal adjusted(id: String, delta: int)

const C_TITLE := "#f0e68c"
const C_TEXT := "#e4e4e4"
const C_FOCUS := "#5fd75f"
const C_DISABLED := "#6c6c6c"

var title := ""
var subtitle := ""
var _buttons: Dictionary = {}
var _order: Array[Button] = []
var _title_label: Label
var _subtitle_label: Label


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.92)
	style.border_color = Color("#808080")
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)
	_title_label = _label(10, C_TITLE)
	_subtitle_label = _label(10 + UiFont.line_h, "#a8a8a8")
	hide()


## items: [{"id", "text", "disabled"?}]. Перестраивает кнопки и открывает меню.
func open(p_title: String, items: Array, p_subtitle: String = "") -> void:
	title = p_title
	subtitle = p_subtitle
	_title_label.text = title
	_subtitle_label.text = subtitle
	for b in _order:
		b.queue_free()
	_order.clear()
	_buttons.clear()
	var top := 18 + UiFont.line_h * (2 if subtitle != "" else 1)
	for i in items.size():
		var it: Dictionary = items[i]
		var b := _button(it["text"], it.get("disabled", false))
		b.position = Vector2(20, top + i * (UiFont.line_h + 8))
		b.size = Vector2(size.x - 40, UiFont.line_h + 4)
		var id: String = it["id"]
		b.pressed.connect(func(): chosen.emit(id))
		b.gui_input.connect(func(e: InputEvent): _on_button_input(id, e))
		add_child(b)
		_buttons[id] = b
		_order.append(b)
	for i in _order.size():
		_order[i].focus_neighbor_top = _order[i - 1].get_path()
		_order[i].focus_neighbor_bottom = _order[(i + 1) % _order.size()].get_path()
	show()
	for b in _order:
		if not b.disabled:
			b.grab_focus()
			break


func set_text(id: String, text: String) -> void:
	if _buttons.has(id):
		_buttons[id].text = text


func _on_button_input(id: String, e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		if e.keycode == KEY_LEFT:
			adjusted.emit(id, -1)
			accept_event()
		elif e.keycode == KEY_RIGHT:
			adjusted.emit(id, 1)
			accept_event()


func _button(text: String, disabled: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.disabled = disabled
	b.focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	b.add_theme_color_override("font_color", Color(C_TEXT))
	b.add_theme_color_override("font_focus_color", Color(C_FOCUS))
	b.add_theme_color_override("font_hover_color", Color(C_FOCUS))
	b.add_theme_color_override("font_disabled_color", Color(C_DISABLED))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.37, 0.84, 0.37, 0.15)
	focus.border_color = Color(C_FOCUS)
	focus.set_border_width_all(1)
	b.add_theme_stylebox_override("focus", focus)
	return b


func _label(y: int, color: String) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(color))
	l.position = Vector2(0, y)
	l.size = Vector2(size.x, UiFont.line_h)
	add_child(l)
	return l
