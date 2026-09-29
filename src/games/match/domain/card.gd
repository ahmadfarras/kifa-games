class_name Card
extends RefCounted

## One card on the board. `face` says which picture it shows; two cards with the same face are a pair.

var face: int
var is_face_up := false
var is_matched := false


func _init(card_face: int) -> void:
	face = card_face
