## Шрифт интерфейса и размеры, которые от него зависят (ширина знака, высота строки).
class_name UiFont
extends RefCounted

## GNU Unifont: пиксельный шрифт под сетку 16 px, поэтому только размер 16 (в других размерах буквы искажаются).
const PATH := "res://assets/fonts/unifont.otf"

static var regular: Font
static var bold: Font
static var size := 16
static var char_w := 8
static var line_h := 18


static func setup() -> void:
	regular = _load(PATH)
	bold = regular
	size = 16
	char_w = 8
	line_h = size + 2


## Пиксельный шрифт без сглаживания: чётко при увеличении в целое число раз.
static func _load(path: String) -> FontFile:
	var f := FontFile.new()
	f.load_dynamic_font(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = regular
	t.default_font_size = size
	return t
