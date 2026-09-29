class_name ShopCard
extends PanelContainer

## One character in the shop: its art plus Owned (✅), Buy (price) or Too expensive (price greyed and a
## progress bar towards it). The art is a CharacterButton, so only the focused card animates.

signal buy_pressed(id: StringName)

const CELEBRATE_SCALE := Vector2(1.15, 1.15)
const CELEBRATE_SECONDS := 0.2

var character_id: StringName
var price := 0

@onready var _owned_label: Label = $Layout/OwnedLabel
@onready var _buy_button: Button = $Layout/BuyButton
@onready var _bar: ProgressBar = $Layout/Bar
@onready var _bar_label: Label = $Layout/BarLabel


func _ready() -> void:
	_buy_button.pressed.connect(func() -> void: buy_pressed.emit(character_id))


## Call before the card enters the tree: the art shows its first frame on ready.
func setup(id: StringName, frames: SpriteFrames, card_price: int) -> void:
	character_id = id
	price = card_price
	art().frames = frames


func art() -> CharacterButton:
	return $Layout/Art


func refresh(coins: int, owned: bool) -> void:
	var too_expensive := not owned and coins < price
	_owned_label.visible = owned
	_buy_button.visible = not owned
	_buy_button.disabled = too_expensive
	_buy_button.text = "🪙 %d" % price
	_bar.visible = too_expensive
	_bar.max_value = price
	_bar.value = coins
	_bar_label.visible = too_expensive
	_bar_label.text = "🪙 %d / %d" % [coins, price]


func focus() -> void:
	art().button_pressed = true


func celebrate() -> void:
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.tween_property(self, "scale", CELEBRATE_SCALE, CELEBRATE_SECONDS)
	tween.tween_property(self, "scale", Vector2.ONE, CELEBRATE_SECONDS)
