class_name CharacterButton
extends Button

## One choice on the start screen. Shows the character's first idle frame as its picture.

@export var frames: SpriteFrames


func _ready() -> void:
	icon = frames.get_frame_texture(RunnerGame.ANIM_IDLE, 0)
