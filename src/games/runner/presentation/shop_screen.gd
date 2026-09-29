class_name ShopScreen
extends ColorRect

## Lists every character with its price and owned state; buying asks for a Yes/No confirmation first so
## small fingers don't spend coins by accident. Cards are built once and refreshed in place. No _process.

signal buy_requested(id: StringName)
signal closed

var _cards: Dictionary[StringName, ShopCard] = {}
var _coins := 0
var _pending_id: StringName

@onready var _cards_box: Container = %Cards
@onready var _card_template: ShopCard = %CardTemplate
@onready var _coins_label: Label = %ShopCoinsLabel
@onready var _confirm_panel: Control = %ConfirmPanel
@onready var _confirm_art: TextureRect = %ConfirmArt
@onready var _confirm_price: Label = %ConfirmPrice


func _ready() -> void:
	%CloseButton.pressed.connect(close)
	%YesButton.pressed.connect(_on_yes_pressed)
	%NoButton.pressed.connect(_confirm_panel.hide)


## `frames_by_id`: art for every catalog id. Builds one card per character, in catalog order. O(c).
func build(frames_by_id: Dictionary) -> void:
	for id in CharacterCatalog.ids():
		var card := _card_template.duplicate(DUPLICATE_SCRIPTS | DUPLICATE_GROUPS) as ShopCard
		card.setup(id, frames_by_id[id], CharacterCatalog.price(id))
		card.buy_pressed.connect(_on_buy_pressed)
		_cards_box.add_child(card)
		_cards[id] = card
	_cards_box.remove_child(_card_template)
	_card_template.free()


func card(id: StringName) -> ShopCard:
	return _cards.get(id)


## `focus_id`: card to animate first; unknown or empty focuses the first card.
func open(coins: int, owned: Dictionary, focus_id: StringName) -> void:
	refresh(coins, owned)
	_confirm_panel.hide()
	show()
	var focused: ShopCard = _cards.get(focus_id, _cards[CharacterCatalog.ids()[0]])
	focused.focus()


func refresh(coins: int, owned: Dictionary) -> void:
	_coins = coins
	_coins_label.text = "🪙 %d" % coins
	for id: StringName in _cards:
		_cards[id].refresh(coins, owned.has(id))


func celebrate(id: StringName) -> void:
	_cards[id].celebrate()


func close() -> void:
	hide()
	closed.emit()


func _on_buy_pressed(id: StringName) -> void:
	var picked := _cards[id]
	if _coins < picked.price:
		return
	_pending_id = id
	picked.focus()
	_confirm_art.texture = picked.art().frames.get_frame_texture(RunnerSprite.ANIM_IDLE, 0)
	_confirm_price.text = "🪙 %d" % picked.price
	_confirm_panel.show()


func _on_yes_pressed() -> void:
	_confirm_panel.hide()
	buy_requested.emit(_pending_id)
