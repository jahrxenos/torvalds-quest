## Журнал строк: новая строка появляется снизу, старые плавно уходят вверх.
## На нём построены и панель диалогов, и вывод терминала.
class_name LogPanel
extends Control

## Сколько строк хранить; более старые удаляются.
const KEEP := 60
const SCROLL_TIME := 0.2

var line_height := 16
var visible_lines := 3
## Место под значок слева (0 — без значков).
var icon_size := 0

var _content: Control
var _rows: Array[Control] = []
var _tween: Tween


func _init(p_line_height: int = 16, p_visible_lines: int = 3, p_icon_size: int = 0) -> void:
	line_height = p_line_height
	visible_lines = p_visible_lines
	icon_size = p_icon_size
	clip_contents = true
	_content = Control.new()
	add_child(_content)


## Сколько символов помещается в строку текста.
func chars_per_line() -> int:
	var text_w := size.x - (icon_size + 4 if icon_size > 0 else 0)
	return maxi(10, int(text_w / UiFont.char_w))


## Одна строка экрана. text — BBCode; icon показывается слева (только при icon_size > 0).
func add_row(text: String, icon: Texture2D = null) -> void:
	var row := Control.new()
	row.position = Vector2(0, _rows.size() * line_height)
	row.size = Vector2(size.x, line_height)
	var x := 0
	if icon_size > 0:
		if icon:
			var pic := TextureRect.new()
			pic.texture = icon
			pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			pic.size = Vector2(icon_size, line_height)
			row.add_child(pic)
		x = icon_size + 4
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	style_label(label)
	label.position = Vector2(x, (line_height - UiFont.size) / 2 - 2)
	label.size = Vector2(size.x - x, line_height + 6)
	label.text = text
	row.add_child(label)
	_content.add_child(row)
	_rows.append(row)
	_trim()
	_scroll()


## Текст одним цветом с переносом по словам; значок только у первой строки.
func add_wrapped(plain: String, color: Color, icon: Texture2D = null) -> void:
	var first := true
	for line in wrap_words(plain, chars_per_line()):
		add_row("[color=#%s]%s[/color]" % [color.to_html(false), escape(line)], icon if first else null)
		first = false


func clear() -> void:
	for row in _rows:
		row.queue_free()
	_rows.clear()
	_content.position.y = 0


func _scroll() -> void:
	var target := -maxi(0, _rows.size() - visible_lines) * line_height
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_content, "position:y", float(target), SCROLL_TIME)


func _trim() -> void:
	if _rows.size() <= KEEP:
		return
	var drop := _rows.size() - KEEP
	for i in drop:
		_rows[i].queue_free()
	_rows = _rows.slice(drop)
	for row in _rows:
		row.position.y -= drop * line_height
	_content.position.y += drop * line_height


## Шрифт интерфейса для метки с BBCode.
static func style_label(label: RichTextLabel) -> void:
	label.clip_contents = false
	label.add_theme_font_override("normal_font", UiFont.regular)
	label.add_theme_font_override("bold_font", UiFont.bold)
	label.add_theme_font_size_override("normal_font_size", UiFont.size)
	label.add_theme_font_size_override("bold_font_size", UiFont.size)


## Перенос по словам на строки не длиннее width символов.
static func wrap_words(text: String, width: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	var cur := ""
	for word in text.split(" ", false):
		if cur == "":
			cur = word
		elif cur.length() + 1 + word.length() <= width:
			cur += " " + word
		elif word.length() <= 2 and word.left(1).to_lower() == word.left(1).to_upper() and cur.contains(" "):
			# Короткий кусок без букв («..», «+x») не отрываем: переносим вместе с предыдущим словом.
			var cut := cur.rfind(" ")
			lines.append(cur.left(cut))
			cur = cur.substr(cut + 1) + " " + word
		else:
			lines.append(cur)
			cur = word
	if cur != "" or lines.is_empty():
		lines.append(cur)
	return lines


## Экранирование квадратных скобок для BBCode.
static func escape(text: String) -> String:
	return text.replace("[", "[lb]")
