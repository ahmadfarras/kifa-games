class_name MatchSession
extends RefCounted

## Use cases for Animal Match: start a round at a level, flip a card, hide a mismatched pair.

signal round_won

var match_round: MatchRound

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


## `face_count`: how many different card pictures exist.
func start(pairs: int, face_count: int) -> MatchRound:
	match_round = MatchRound.new(pairs, face_count, _rng)
	return match_round


func flip(index: int) -> MatchRound.Flip:
	var result := match_round.flip(index)
	if result == MatchRound.Flip.MATCH and match_round.is_won():
		round_won.emit()
	return result


func hide_mismatch() -> void:
	match_round.hide_mismatch()
