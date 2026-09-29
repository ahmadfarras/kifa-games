class_name CharacterButton
extends Button

## One choice on the start screen, showing the character's idle animation (frames are already cropped
## to the visible body by the asset tool). Only the selected (pressed) button animates; the others show
## the first frame and don't process. Buttons share a ButtonGroup in toggle mode, so pressing one selects it.

@export var frames: SpriteFrames

var _frame := -1
var _elapsed := 0.0


func _ready() -> void:
	_show_frame(0)
	_update_processing()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_update_processing()


func _toggled(_toggled_on: bool) -> void:
	_elapsed = 0.0
	_show_frame(0)
	_update_processing()


func _process(delta: float) -> void:
	var fps := frames.get_animation_speed(RunnerSprite.ANIM_IDLE)
	var count := frames.get_frame_count(RunnerSprite.ANIM_IDLE)
	_elapsed = fmod(_elapsed + delta, count / fps)
	_show_frame(mini(int(_elapsed * fps), count - 1))


func _update_processing() -> void:
	set_process(button_pressed and is_visible_in_tree())


func _show_frame(index: int) -> void:
	if index == _frame:
		return
	_frame = index
	icon = frames.get_frame_texture(RunnerSprite.ANIM_IDLE, index)
