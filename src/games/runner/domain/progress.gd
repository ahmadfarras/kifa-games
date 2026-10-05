class_name Progress
extends RefCounted

## Everything Runner keeps between launches: best score, coins (the wallet) and owned characters.
## Other layers read the fields; changes go through record_run(), buy() and absorb() so the invariants hold:
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


## Coins ever earned: what is in the wallet plus what was spent on owned characters.
func lifetime_earned() -> int:
	return coins + _spent()


## Merges progress from another device into this one and returns true when this one changed.
## Best score: the highest. Owned: both sets. Coins: the highest lifetime earnings minus the price of
## everything owned, so no character is lost and no coin is counted twice. Order doesn't matter and
## absorbing the same progress again changes nothing.
func absorb(other: Progress) -> bool:
	var earned := maxi(lifetime_earned(), other.lifetime_earned())
	var old_best := best_score
	var old_coins := coins
	var old_owned := owned.size()
	best_score = maxi(best_score, other.best_score)
	for id: StringName in other.owned:
		if CharacterCatalog.is_known(id):
			owned[id] = true
	coins = clampi(earned - _spent(), 0, MAX_COINS)
	return best_score != old_best or coins != old_coins or owned.size() != old_owned


func equals(other: Progress) -> bool:
	return (
		best_score == other.best_score
		and coins == other.coins
		and owned.size() == other.owned.size()
		and owned.has_all(other.owned.keys())
	)


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


func _spent() -> int:
	var total := 0
	for id: StringName in owned:
		total += CharacterCatalog.price(id)
	return total
