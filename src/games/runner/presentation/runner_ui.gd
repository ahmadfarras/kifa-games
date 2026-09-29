class_name RunnerUi
extends Control

## Start screen (select an owned character, then Start; coins and shop button), shop, score bar and game-over screen.
## Emits what the kid pressed; holds no game rules.

signal character_selected(frames: SpriteFrames)
signal runner_chosen(frames: SpriteFrames)
signal play_again_pressed
signal change_runner_pressed
signal back_pressed
## `id` is the locked character that was tapped, or empty for the shop button.
signal shop_requested(id: StringName)

const SCORE_POP_EVERY := 10
const SCORE_POP_SCALE := Vector2(1.25, 1.25)
const SCORE_POP_SECONDS := 0.15

@onready var shop: ShopScreen = %ShopScreen
@onready var _start_screen: Control = %StartScreen
@onready var _character_buttons: Container = %CharacterButtons
@onready var _score_bar: Control = %ScoreBar
@onready var _score_label: Label = %ScoreLabel
@onready var _best_label: Label = %BestLabel
@onready var _game_over_screen: Control = %GameOverScreen
@onready var _final_score_label: Label = %FinalScoreLabel
@onready var _final_best_label: Label = %FinalBestLabel
@onready var _final_coins_label: Label = %FinalCoinsLabel
@onready var _shop_bar: Control = %ShopBar
@onready var _coins_label: Label = %CoinsLabel


func _ready() -> void:
	var group := (_character_buttons.get_child(0) as CharacterButton).button_group
	group.pressed.connect(func(button: CharacterButton) -> void: character_selected.emit(button.frames))
	var frames_by_id := {}
	for button: CharacterButton in _character_buttons.get_children():
		button.shop_requested.connect(shop_requested.emit)
		frames_by_id[button.character_id] = button.frames
	shop.build(frames_by_id)
	shop.closed.connect(show_start)
	%ShopButton.pressed.connect(shop_requested.emit.bind(&""))
	var free: Dictionary[StringName, bool] = {}
	for id in CharacterCatalog.free_ids():
		free[id] = true
	show_progress(0, free)
	%StartButton.pressed.connect(_on_start_pressed)
	%PlayAgainButton.pressed.connect(play_again_pressed.emit)
	%ChangeRunnerButton.pressed.connect(change_runner_pressed.emit)
	%BackButton.pressed.connect(back_pressed.emit)


func selected_character() -> SpriteFrames:
	var group := (_character_buttons.get_child(0) as CharacterButton).button_group
	return (group.get_pressed_button() as CharacterButton).frames


## Locks every character not in `owned` and makes sure the selected one is owned. O(c), c = characters.
func show_progress(coins: int, owned: Dictionary) -> void:
	_coins_label.text = _coins_text(coins)
	var first_owned: CharacterButton = null
	for button: CharacterButton in _character_buttons.get_children():
		var locked := not owned.has(button.character_id)
		button.set_locked(locked, CharacterCatalog.price(button.character_id))
		if not locked and first_owned == null:
			first_owned = button
	var selected := _character_buttons.get_child(0).button_group.get_pressed_button() as CharacterButton
	if (selected == null or selected.is_locked) and first_owned != null:
		first_owned.button_pressed = true


func select_character(id: StringName) -> void:
	for button: CharacterButton in _character_buttons.get_children():
		if button.character_id == id and not button.is_locked:
			button.button_pressed = true


func show_shop(coins: int, owned: Dictionary, focus_id: StringName) -> void:
	_start_screen.hide()
	%BackButton.hide()
	_shop_bar.hide()
	shop.open(coins, owned, focus_id)


func show_start() -> void:
	shop.hide()
	_start_screen.show()
	%BackButton.show()
	_shop_bar.show()
	_score_bar.hide()
	_game_over_screen.hide()


func show_playing(best_score: int) -> void:
	_start_screen.hide()
	%BackButton.hide()
	_shop_bar.hide()
	_game_over_screen.hide()
	_score_bar.show()
	_score_label.text = _score_text(0)
	_best_label.text = _best_text(best_score)


func set_score(score: int) -> void:
	_score_label.text = _score_text(score)
	if score % SCORE_POP_EVERY == 0:
		_pop(_score_label)


func show_game_over(score: int, best_score: int, coins_earned: int) -> void:
	_final_score_label.text = _score_text(score)
	_final_coins_label.text = "+%d 🪙" % coins_earned
	_final_best_label.text = _best_text(best_score)
	_best_label.text = _best_text(best_score)
	_game_over_screen.show()


func _on_start_pressed() -> void:
	runner_chosen.emit(selected_character())


func _pop(label: Label) -> void:
	label.pivot_offset = label.size * 0.5
	var tween := label.create_tween()
	tween.tween_property(label, "scale", SCORE_POP_SCALE, SCORE_POP_SECONDS)
	tween.tween_property(label, "scale", Vector2.ONE, SCORE_POP_SECONDS)


static func _score_text(score: int) -> String:
	return "⭐ %d" % score


static func _best_text(best_score: int) -> String:
	return "🏆 %d" % best_score


static func _coins_text(coins: int) -> String:
	return "🪙 %d" % coins
