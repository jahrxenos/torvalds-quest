## Экранные кнопки: позволяют ребёнку набирать заклинания без физической клавиатуры.
## Нужны в веб-версии: на телефоне или планшете другой клавиатуры нет.
## Кнопки нажимаются и мышкой, и касанием.
class_name KeyboardPanel
extends Panel

signal char_typed(ch: String)
signal enter_pressed()
signal backspace_pressed()

const C_TEXT := "#e4e4e4"
const C_SPECIAL := "#d7a85f"
const C_ENTER := "#5fd75f"
const C_BG := "#0c0c14"
const C_BORDER := "#808080"

const ROW1 := ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
const ROW2 := ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
const ROW3 := ["z", "x", "c", "v", "b", "n", "m"]
const SPECIALS := [".", ",", ":", ";", "/", "*", "+", "$"]

const PAD := 8
const KEY_W := 58
const KEY_H := 38
const ROW_STEP := 44
const SP_W := 44
const SPACE_W := 104
const ENTER_W := 100
const ROW_GAP := 4

var _bg_box: StyleBoxFlat
var _key_box: StyleBoxFlat
var _hover_box: StyleBoxFlat
var _down_box: StyleBoxFlat


func _ready() -> void:
	_bg_box = StyleBoxFlat.new()
	_bg_box.bg_color = Color(C_BG)
	_bg_box.border_color = Color(C_BORDER)
	_bg_box.set_border_width_all(1)
	add_theme_stylebox_override("panel", _bg_box)

	_key_box = StyleBoxFlat.new()
	_key_box.bg_color = Color("#24282f")
	_key_box.border_color = Color("#4a4f58")
	_key_box.set_border_width_all(1)

	_hover_box = StyleBoxFlat.new()
	_hover_box.bg_color = Color("#343a44")
	_hover_box.border_color = Color(C_ENTER)
	_hover_box.set_border_width_all(1)

	_down_box = StyleBoxFlat.new()
	_down_box.bg_color = Color("#1a1d23")
	_down_box.border_color = Color(C_ENTER)
	_down_box.set_border_width_all(1)

	var y := PAD
	y = _letter_row(ROW1, y)
	y = _letter_row(ROW2, y)
	var row3_y := y
	y = _letter_row(ROW3, y)
	_backspace_button(size.x - PAD - 108, row3_y)
	_bottom_row(y + 4)


## Один ряд букв: кнопки по 58 px с шагом 62 px, ряд центрируется.
func _letter_row(row: Array, y: int) -> int:
	var total := row.size() * (KEY_W + 4) - 4
	var x := int((size.x - total) / 2)
	for ch in row:
		_key_button(ch, x, y, KEY_W, KEY_H, C_TEXT)
		x += KEY_W + 4
	return y + ROW_STEP


## Кнопка «Стереть»: удаляет последний символ (как клавиша Backspace).
func _backspace_button(x: int, y: int) -> void:
	var b := Button.new()
	b.text = "Стереть"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", Color(C_TEXT))
	b.add_theme_stylebox_override("normal", _key_box)
	b.add_theme_stylebox_override("hover", _hover_box)
	b.add_theme_stylebox_override("pressed", _down_box)
	b.position = Vector2i(x, y)
	b.size = Vector2i(108, KEY_H)
	b.pressed.connect(func(): backspace_pressed.emit())
	add_child(b)


## Нижний ряд: знаки, пробел и Enter — всё, что нужно для заклинаний.
func _bottom_row(y: int) -> void:
	var sp_total := SPECIALS.size() * (SP_W + 4) - 4
	var total := sp_total + ROW_GAP + SPACE_W + ROW_GAP + ENTER_W
	var x := int((size.x - total) / 2)
	for ch in SPECIALS:
		_key_button(ch, x, y, SP_W, 36, C_SPECIAL)
		x += SP_W + 4
	_space_button(x + ROW_GAP, y)
	_enter_button(x + ROW_GAP + SPACE_W + ROW_GAP, y)


func _key_button(ch: String, x: int, y: int, w: int, h: int, color: String) -> void:
	var b := Button.new()
	b.text = ch
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", Color(color))
	b.add_theme_stylebox_override("normal", _key_box)
	b.add_theme_stylebox_override("hover", _hover_box)
	b.add_theme_stylebox_override("pressed", _down_box)
	b.position = Vector2i(x, y)
	b.size = Vector2i(w, h)
	b.pressed.connect(func(): char_typed.emit(ch))
	add_child(b)


## Пробел: кнопка шире обычной, ребёнку по ней попасть проще.
func _space_button(x: int, y: int) -> void:
	var b := Button.new()
	b.text = "Пробел"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", Color(C_TEXT))
	b.add_theme_stylebox_override("normal", _key_box)
	b.add_theme_stylebox_override("hover", _hover_box)
	b.add_theme_stylebox_override("pressed", _down_box)
	b.position = Vector2i(x, y)
	b.size = Vector2i(SPACE_W, 36)
	b.pressed.connect(func(): char_typed.emit(" "))
	add_child(b)


func _enter_button(x: int, y: int) -> void:
	var b := Button.new()
	b.text = "Enter"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", Color(C_ENTER))
	b.add_theme_stylebox_override("normal", _key_box)
	b.add_theme_stylebox_override("hover", _hover_box)
	b.add_theme_stylebox_override("pressed", _down_box)
	b.position = Vector2i(x, y)
	b.size = Vector2i(ENTER_W, 36)
	b.pressed.connect(func(): enter_pressed.emit())
	add_child(b)
