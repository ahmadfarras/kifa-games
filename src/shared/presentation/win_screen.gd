class_name WinScreen
extends ColorRect

## Celebration overlay ("You did it!" by default) with an emoji, optional earned stars and confetti.
## Texts are set per game; the game decides what the two buttons do.

signal primary_pressed
signal secondary_pressed

@export var emoji := "🏆"
@export var title := "You did it!"
@export var primary_text := "🔄 Play again"
@export var secondary_text := "🏠"

@onready var _stars: Label = %Stars
@onready var _confetti: CPUParticles2D = %Confetti


func _ready() -> void:
	%Emoji.text = emoji
	%Title.text = title
	%PrimaryButton.text = primary_text
	%SecondaryButton.text = secondary_text
	%PrimaryButton.pressed.connect(primary_pressed.emit)
	%SecondaryButton.pressed.connect(secondary_pressed.emit)


## `stars`: e.g. "⭐⭐⭐"; empty hides the stars row.
func celebrate(stars: String = "") -> void:
	_stars.text = stars
	_stars.visible = not stars.is_empty()
	var screen := get_viewport_rect().size
	_confetti.position = Vector2(screen.x * 0.5, -20.0)
	_confetti.emission_rect_extents = Vector2(screen.x * 0.5, 10.0)
	show()
	_confetti.restart()
