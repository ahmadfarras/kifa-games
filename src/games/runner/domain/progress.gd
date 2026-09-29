class_name Progress
extends RefCounted

## Everything Runner keeps between launches: best score, coins (the wallet) and owned characters.
## Other layers read the fields; changes go through record_run() and buy() so the invariants hold:
## 0 <= coins <= MAX_COINS, owned holds every free character and only known ones.

enum Purchase { BOUGHT, ALREADY_OWNED, NOT_ENOUGH_COINS, UNKNOWN_CHARACTER }

const MAX_COINS := 1_000_000_000

var best_score := 0
var coins := 0
var owned: Dictionary[StringName, bool] = {}


static func fresh() -> Progress:
	var progress := Progress.new()
	for id in CharacterCatalog.free_ids():
		progress.owned[id] = true
	return progress


## Rebuilds saved progress, clamping values and dropping unknown ids so the invariants hold.
static func restore(saved_best: int, saved_coins: int, saved_owned: Array[StringName]) -> Progress:
	var progress := fresh()
	progress.best_score = maxi(saved_best, 0)
	progress.coins = clampi(saved_coins, 0, MAX_COINS)
	for id in saved_owned:
		if CharacterCatalog.is_known(id):
			progress.owned[id] = true
	return progress


func owns(id: StringName) -> bool:
	return owned.has(id)


## Returns the coins earned: 1 per star of the run's score.
func record_run(score: int) -> int:
	var earned := clampi(score, 0, MAX_COINS - coins)
	best_score = maxi(best_score, score)
	coins += earned
	return earned


func can_afford(id: StringName) -> bool:
	return CharacterCatalog.is_known(id) and coins >= CharacterCatalog.price(id)


func buy(id: StringName) -> Purchase:
	if not CharacterCatalog.is_known(id):
		return Purchase.UNKNOWN_CHARACTER
	if owns(id):
		return Purchase.ALREADY_OWNED
	if not can_afford(id):
		return Purchase.NOT_ENOUGH_COINS
	coins -= CharacterCatalog.price(id)
	owned[id] = true
	return Purchase.BOUGHT
