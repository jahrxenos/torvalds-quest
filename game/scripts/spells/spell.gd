## Основа заклинания. Каждое заклинание — отдельный файл в этой папке:
## интерпретатор находит их сам, чтобы добавить заклинание, достаточно нового файла.
class_name Spell
extends RefCounted

## Как произносится (первое слово строки); для свитков — "./".
var name: String = ""
## Строка для Книги заклинаний.
var desc: String = ""
var example: String = ""
## Вид триггера, у которого работает заклинание ("" — везде): door, note, cart, scroll, altar.
var trigger: String = ""


## word — первое слово как его набрали (для ./scroll), args — остальные слова.
## Возвращает true, если заклинание удалось.
func run(_it: Interpreter, _word: String, _args: Array, _res: Dictionary) -> bool:
	return false
