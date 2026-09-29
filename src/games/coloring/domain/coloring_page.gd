class_name ColoringPage
extends RefCounted

## One picture being colored. Each region holds a palette colour index, or BLANK (unpainted / erased).
## The kid picks a brush colour and taps regions; the page is complete when no region is BLANK.
## Other layers read its fields but change state only through its methods.

const BLANK := -1

var colors: Array[int] = []
var brush := 0

var _celebrated := false


func _init(region_count: int) -> void:
	assert(region_count > 0, "a page needs regions")
	colors.resize(region_count)
	colors.fill(BLANK)


## `color` is a palette index, or BLANK for the eraser.
func pick(color: int) -> void:
	brush = color


## Paints the region with the brush. Returns true only the first time the page becomes complete
## (until clear()), so the celebration happens once per page.
func paint(region: int) -> bool:
	colors[region] = brush
	if _celebrated or not is_complete():
		return false
	_celebrated = true
	return true


func is_complete() -> bool:
	return not colors.has(BLANK)


func clear() -> void:
	colors.fill(BLANK)
	_celebrated = false


## Fills every region with a random colour from 0..color_count-1 (never BLANK).
func magic(color_count: int, rng: RandomNumberGenerator) -> void:
	for i in colors.size():
		colors[i] = rng.randi_range(0, color_count - 1)
