class_name Username
extends RefCounted

## A username is picked by the kid (or their grown-up): 3 to 16 plain letters and digits, so it is easy
## to remember and to type on any keyboard. Upper and lower case are the same name ("budi7" = "Budi7"),
## so nobody is locked out by a capital letter. The server decides whether the name is still free.

const MIN_LENGTH := 3
const MAX_LENGTH := 16

static var _pattern := RegEx.create_from_string("^[A-Za-z0-9]{%d,%d}$" % [MIN_LENGTH, MAX_LENGTH])


## Returns the username without surrounding spaces, or "" when it is not an allowed one.
static func canonical(text: String) -> String:
	var typed := text.strip_edges()
	return typed if _pattern.search(typed) != null else ""


static func is_valid(text: String) -> bool:
	return not canonical(text).is_empty()
