class_name WinScreen
extends ColorRect

## "You did it!" overlay with a trophy, the stars earned and confetti. The game decides what the buttons do.

signal play_again_pressed
signal home_pressed

@onready var _stars: Label = %Stars
@onready var _confetti: CPUParticles2D = %Confetti


func _ready() -> void:
	%PlayAgainButton.pressed.connect(play_again_pressed.emit)
	%HomeButton.pressed.connect(home_pressed.emit)


func celebrate(stars: String) -> void:
	_stars.text = stars
	var screen := get_viewport_rect().size
	_confetti.position = Vector2(screen.x * 0.5, -20.0)
	_confetti.emission_rect_extents = Vector2(screen.x * 0.5, 10.0)
	show()
	_confetti.restart()
