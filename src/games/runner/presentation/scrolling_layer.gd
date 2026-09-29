class_name ScrollingLayer
extends Sprite2D

## One background strip that tiles horizontally and scrolls slower than the world for depth (parallax).
## Drawn in a single draw call: the region is as wide as the screen and the texture repeats
## (use texture_repeat MIRROR for art whose left and right edges don't match).

## 1 = moves with the ground, 0 = never moves.
@export_range(0.0, 1.0) var scroll_factor := 1.0
## Top of this strip in art pixels (see RunnerBackground.ART_HEIGHT).
@export var art_top := 0.0


func fit(pixel_scale: float, screen_width: float) -> void:
	scale = Vector2.ONE * pixel_scale
	position.y = art_top * pixel_scale
	region_rect.size = Vector2(screen_width / pixel_scale, texture.get_height())


func scroll(distance: float) -> void:
	# Two texture widths is a full period for both REPEAT and MIRROR tiling.
	region_rect.position.x = fmod(distance * scroll_factor / scale.x, texture.get_width() * 2.0)
