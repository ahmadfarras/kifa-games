extends GutTest

var progress: StarProgress


func before_each() -> void:
	progress = StarProgress.new()
	add_child_autofree(progress)
	progress.reset(5)


func _visible_stars() -> Array[Label]:
	var stars: Array[Label] = []
	for child in progress.get_children():
		if child.visible:
			stars.append(child)
	return stars


func test_reset_shows_one_dim_star_per_goal() -> void:
	assert_eq(_visible_stars().size(), 5)
	for star in _visible_stars():
		assert_eq(star.text, "⭐")
		assert_eq(star.modulate, StarProgress.OFF)
	assert_eq(progress.lit_count(), 0)


func test_light_next_lights_stars_in_order() -> void:
	progress.light_next()
	progress.light_next()

	assert_eq(progress.lit_count(), 2)
	assert_eq(_visible_stars()[0].modulate, Color.WHITE)
	assert_eq(_visible_stars()[1].modulate, Color.WHITE)
	assert_eq(_visible_stars()[2].modulate, StarProgress.OFF)


func test_light_next_stops_at_goal() -> void:
	for i in 7:
		progress.light_next()

	assert_eq(progress.lit_count(), 5)


func test_reset_dims_and_reuses_labels() -> void:
	progress.light_next()

	progress.reset(3)

	assert_eq(progress.get_child_count(), 5)
	assert_eq(_visible_stars().size(), 3)
	assert_eq(progress.lit_count(), 0)
	for star in _visible_stars():
		assert_eq(star.modulate, StarProgress.OFF)


func test_reset_grows_for_bigger_goal() -> void:
	progress.reset(8)

	assert_eq(_visible_stars().size(), 8)
