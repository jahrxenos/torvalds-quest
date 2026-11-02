## Окно Книги заклинаний поверх локации: выученные заклинания списком, по строке на каждое, без листания.
## Новое заклинание подсвечено. Закрывается по Enter и Esc (обрабатывает сцена).
class_name SpellBook
extends Panel

const C_TITLE := "#f0e68c"
const C_SPELL := "#5fd75f"
const C_DESC := "#e4e4e4"
const C_NEW := "#ffd75f"
const C_HINT := "#8a8a8a"

var _title: RichTextLabel
var _list: RichTextLabel
var _footer: RichTextLabel


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1a140c")
	style.border_color = Color("#c9a96f")
	style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)
	_title = _label(Vector2(0, 8), Vector2(size.x, UiFont.line_h))
	_title.text = "[center][color=%s]Книга заклинаний[/color][/center]" % C_TITLE
	_list = _label(Vector2(24, 12 + UiFont.line_h * 2), Vector2(size.x - 48, size.y - UiFont.line_h * 4))
	_footer = _label(Vector2(0, size.y - UiFont.line_h - 8), Vector2(size.x, UiFont.line_h))
	_footer.text = "[center][color=%s]Enter или Esc — закрыть книгу[/color][/center]" % C_HINT
	hide()


## spells — имена выученных заклинаний по порядку изучения; newest — подсвеченное.
## newest — заклинания, выученные последними: они подсвечены.
func open(spells: Array[String], newest: Array) -> void:
	var text := "[table=2]"
	for spell_name in spells:
		var spell: Spell = Interpreter.spells.get(spell_name)
		if spell == null:
			continue
		var color := C_NEW if spell_name in newest else C_SPELL
		text += "[cell][color=%s]%s[/color]   [/cell][cell][color=%s]%s[/color][/cell]" % [
			color, LogPanel.escape(spell.example), C_DESC, spell.desc]
	_list.text = text + "[/table]"
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
