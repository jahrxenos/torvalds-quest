## Терминал: последние строки вывода и строка ввода с приглашением и мигающим курсором.
## Истории команд и автодополнения нет: ребёнок пишет заклинания сам.
class_name TerminalPanel
extends Control

const LINES := 6
const MAX_INPUT := 60

const C_USER := "#5fd75f"   # torvald@linux — зелёный, как в Debian
const C_PATH := "#5f87ff"   # путь — синий
const C_TEXT := "#e4e4e4"   # обычный вывод
const C_DIR := "#5fd7ff"    # места в выводе ls — голубые

var typed := ""
var _prompt_path := "/"
var _history: LogPanel
var _input: RichTextLabel
var _cursor_on := true


func _ready() -> void:
	var lh := UiFont.line_h
	_history = LogPanel.new(lh, LINES - 1)
	_history.position = Vector2.ZERO
	_history.size = Vector2(size.x, lh * (LINES - 1))
	add_child(_history)
	_input = RichTextLabel.new()
	_input.bbcode_enabled = true
	_input.scroll_active = false
	_input.autowrap_mode = TextServer.AUTOWRAP_OFF
	LogPanel.style_label(_input)
	_input.position = Vector2(0, lh * (LINES - 1) + (lh - UiFont.size) / 2 - 2)
	_input.size = Vector2(size.x, lh + 6)
	add_child(_input)
	var blink := Timer.new()
	blink.wait_time = 0.5
	blink.autostart = true
	blink.timeout.connect(func():
		_cursor_on = not _cursor_on
		_refresh())
	add_child(blink)
	_refresh()


func set_path(path: String) -> void:
	_prompt_path = path
	_refresh()


func type_char(ch: String) -> void:
	if typed.length() < MAX_INPUT:
		typed += ch.to_lower()
		_cursor_on = true
		_refresh()


func backspace() -> void:
	typed = typed.left(-1)
	_cursor_on = true
	_refresh()


## Забрать набранную строку: она уходит в историю вместе с приглашением.
func take_input() -> String:
	var line := typed
	_history.add_row(_prompt_bbcode() + "[color=%s]%s[/color]" % [C_TEXT, LogPanel.escape(line)])
	typed = ""
	_refresh()
	return line


func clear() -> void:
	_history.clear()
	typed = ""
	_refresh()


func print_line(text: String) -> void:
	_history.add_row(_colorize(text))


func _prompt_bbcode() -> String:
	return "[b][color=%s]torvald@linux[/color][/b][color=%s]:[/color][b][color=%s]%s[/color][/b][color=%s]$ [/color]" % [
		C_USER, C_TEXT, C_PATH, LogPanel.escape(_prompt_path), C_TEXT]


func _refresh() -> void:
	if _input == null:
		return
	var cursor := "█" if _cursor_on else " "
	_input.text = _prompt_bbcode() + "[color=%s]%s%s[/color]" % [C_TEXT, LogPanel.escape(typed), cursor]


## Строки вывода ls: имя места («garden/») голубым, остальное обычным цветом.
func _colorize(text: String) -> String:
	var space := text.find(" ")
	if space > 0 and text[space - 1] == "/" and text.contains("— "):
		return "[color=%s]%s[/color][color=%s]%s[/color]" % [C_DIR, LogPanel.escape(text.left(space)), C_TEXT, LogPanel.escape(text.substr(space))]
	return "[color=%s]%s[/color]" % [C_TEXT, LogPanel.escape(text)]
