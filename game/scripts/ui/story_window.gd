## Окно с текстом поверх игры: предыстория в начале игры. Закрывается по Enter (обрабатывает сцена).
class_name StoryWindow
extends Panel

const C_TITLE := "#f0e68c"
const C_TEXT := "#e4e4e4"
const C_HINT := "#8a8a8a"

var _title: RichTextLabel
var _text: RichTextLabel
var _footer: RichTextLabel


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0c0c14")
	style.border_color = Color("#c9a96f")
	style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)
	_title = _label(Vector2(0, 12), Vector2(size.x, UiFont.line_h))
	_text = _label(Vector2(28, 16 + UiFont.line_h * 2), Vector2(size.x - 56, size.y - UiFont.line_h * 5))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer = _label(Vector2(0, size.y - UiFont.line_h - 10), Vector2(size.x, UiFont.line_h))
	hide()


func open(title: String, text: String, footer: String) -> void:
	_title.text = "[center][color=%s]%s[/color][/center]" % [C_TITLE, title]
	_text.text = "[color=%s]%s[/color]" % [C_TEXT, LogPanel.escape(text)]
	_footer.text = "[center][color=%s]%s[/color][/center]" % [C_HINT, footer]
	show()


func _label(pos: Vector2, sz: Vector2) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.scroll_active = false
	l.position = pos
	l.size = sz
	LogPanel.style_label(l)
	l.add_theme_constant_override("line_separation", 2)
	add_child(l)
	return l
