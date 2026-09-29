class_name MatchRound
extends RefCounted

## One game on the board. The kid flips two cards: the same face makes a pair that stays open,
## different faces are a mismatch that flips back (hide_mismatch) before the next card can be flipped.
## Other layers read its fields but change state only through flip() and hide_mismatch().

enum Flip { IGNORED, FIRST, MATCH, MISMATCH }

## Pairs per level: easy, medium, hard.
const LEVELS: Array[int] = [3, 6, 8]

var cards: Array[Card] = []
var pairs: int
var matched_pairs := 0

var _first: Card = null
var _mismatch: Array[Card] = []


## Deals `pair_count` random faces out of `face_count` available pictures, each twice, shuffled.
func _init(pair_count: int, face_count: int, rng: RandomNumberGenerator) -> void:
	assert(pair_count > 0 and pair_count <= face_count, "need 1..face_count pairs")
	pairs = pair_count
	var faces := shuffled(range(face_count), rng).slice(0, pair_count)
	for face in shuffled(faces + faces, rng):
		cards.append(Card.new(face))


## Fisher-Yates shuffle with the given RNG, so rounds are reproducible in tests. O(n).
static func shuffled(items: Array, rng: RandomNumberGenerator) -> Array:
	var result := items.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = result[i]
		result[i] = result[j]
		result[j] = swap
	return result


func is_won() -> bool:
	return matched_pairs == pairs


## True while a mismatched pair is still showing; flips are ignored until hide_mismatch().
func is_waiting() -> bool:
	return not _mismatch.is_empty()


func flip(index: int) -> Flip:
	var card := cards[index]
	if is_waiting() or card.is_face_up:
		return Flip.IGNORED
	card.is_face_up = true
	if _first == null:
		_first = card
		return Flip.FIRST
	var first := _first
	_first = null
	if first.face == card.face:
		first.is_matched = true
		card.is_matched = true
		matched_pairs += 1
		return Flip.MATCH
	_mismatch = [first, card]
	return Flip.MISMATCH


func hide_mismatch() -> void:
	for card in _mismatch:
		card.is_face_up = false
	_mismatch.clear()
