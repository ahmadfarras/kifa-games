class_name ProgressCodec
extends RefCounted

## Turns Progress into a plain dictionary and back, for the save file and the cloud save.
## Incoming data is untrusted (a user-editable file, a server response): everything is validated and
## rebuilt through Progress.restore(), which keeps the invariants.
## Format v2: {"version": 2, "best_score": 42, "coins": 310, "owned": ["little_girl", "little_boy"]}.
## Data without "version" is v1 ({"best_score": N}): 0 coins and the free characters.

const VERSION := 2
const MAX_SCORE := 1_000_000_000


static func to_dictionary(progress: Progress) -> Dictionary:
	var owned: Array[String] = []
	for id in CharacterCatalog.ids():
		if progress.owns(id):
			owned.append(String(id))
	return {"version": VERSION, "best_score": progress.best_score, "coins": progress.coins, "owned": owned}


## Returns null when the data is unusable: not a dictionary, or written by a newer app.
static func from_dictionary(data: Variant) -> Progress:
	if typeof(data) != TYPE_DICTIONARY:
		return null
	if _valid_whole(data.get("version"), MAX_SCORE) > VERSION:
		return null
	return Progress.restore(
		_valid_whole(data.get("best_score"), MAX_SCORE),
		_valid_whole(data.get("coins"), Progress.MAX_COINS),
		_valid_ids(data.get("owned")),
	)


## Keeps only strings; the entry cap bounds the work on tampered data.
static func _valid_ids(value: Variant) -> Array[StringName]:
	var ids: Array[StringName] = []
	if typeof(value) != TYPE_ARRAY:
		return ids
	var entries: Array = value
	for i in mini(entries.size(), CharacterCatalog.ids().size() * 2):
		if typeof(entries[i]) == TYPE_STRING:
			ids.append(StringName(entries[i]))
	return ids


static func _valid_whole(value: Variant, max_value: int) -> int:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return 0
	if value < 0 or value > max_value or value != floorf(value):
		return 0
	return int(value)
