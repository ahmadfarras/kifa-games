class_name ColoringSession
extends RefCounted

## Use cases for Coloring Fun: open a page, pick a colour, paint, clear, magic colours.

signal page_completed

var page: ColoringPage

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


func open(region_count: int) -> ColoringPage:
	page = ColoringPage.new(region_count)
	return page


func pick(color: int) -> void:
	page.pick(color)


func paint(region: int) -> void:
	if page.paint(region):
		page_completed.emit()


func clear() -> void:
	page.clear()


func magic(color_count: int) -> void:
	page.magic(color_count, _rng)
