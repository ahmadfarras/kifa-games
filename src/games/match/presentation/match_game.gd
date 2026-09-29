class_name MatchGame
extends Control

## Animal Match screens: pick a level, flip cards on the board, win screen. Forwards taps to MatchSession and
## redraws cards from the round's state after every change (O(cards), event driven: nothing runs per frame).

signal exit_requested

## Card pictures; the domain refers to them by index (face).
const FACES: Array[String] = ["🐶", "🐱", "🐰", "🦊", "🐻", "🐼", "🐸", "🐵", "🦁", "🐷", "🐨", "🦄", "🐢", "🐙", "🦋", "🐞"]
## Picture on each level button, easy to hard (see MatchRound.LEVELS).
const LEVEL_FACES: Array[String] = ["🐣", "🐱", "🦁"]
const MAX_CARD_SIZE := 220.0
## Share of the screen the board may use.
const BOARD_AREA := Vector2(0.92, 0.72)
const GAP_RATIO := 0.02

@export var card_scene: PackedScene

var _session: MatchSession
var _level := 0
var _cards: Array[CardView] = []

@onready var _start_screen: Control = %StartScreen
@onready var _level_buttons: Container = %LevelButtons
@onready var _game_screen: Control = %GameScreen
@onready var _board: GridContainer = %Board
@onready var _progress: StarProgress = %Progress
@onready var _win_screen: WinScreen = %WinScreen
@onready var _wobble_timer: Timer = %WobbleTimer
@onready var _hide_timer: Timer = %HideTimer
@onready var _win_timer: Timer = %WinTimer


func setup(session: MatchSession) -> void:
	_session = session


## Columns and card size (px) so `card_count` cards fit `area`; portrait screens get fewer columns.
static func board_layout(card_count: int, area: Vector2, gap: float) -> Vector2i:
	var columns := 3 if card_count <= 6 else 4
	var rows := ceili(card_count / float(columns))
	if area.y > area.x and rows < columns:
		var swap := columns
		columns = rows
		rows = swap
	var width := (area.x - gap * (columns - 1)) / columns
	var height := (area.y - gap * (rows - 1)) / rows
	return Vector2i(columns, floori(minf(minf(width, height), MAX_CARD_SIZE)))


static func stars_text(level: int) -> String:
	return "⭐".repeat(level + 1)


func _ready() -> void:
	for level in MatchRound.LEVELS.size():
		_add_level_button(level)
	%BackButton.pressed.connect(exit_requested.emit)
	%HomeButton.pressed.connect(_show_start)
	_win_screen.secondary_pressed.connect(_show_start)
	_win_screen.primary_pressed.connect(func() -> void: _start(_level))
	_session.round_won.connect(_win_timer.start)
	_wobble_timer.timeout.connect(_wobble_mismatch)
	_hide_timer.timeout.connect(_hide_mismatch)
	_win_timer.timeout.connect(_show_win)
	get_viewport().size_changed.connect(_layout)
	_show_start()


func _add_level_button(level: int) -> void:
	var button: Button = %LevelButtonTemplate.duplicate()
	button.text = "%s\n%s" % [LEVEL_FACES[level], stars_text(level)]
	button.show()
	button.pressed.connect(func() -> void: _start(level))
	_level_buttons.add_child(button)


func _start(level: int) -> void:
	_level = level
	_stop_timers()
	var match_round := _session.start(MatchRound.LEVELS[level], FACES.size())
	_deal(match_round)
	_progress.reset(match_round.pairs)
	_start_screen.hide()
	_win_screen.hide()
	_game_screen.show()
	_layout()


func _deal(match_round: MatchRound) -> void:
	while _cards.size() < match_round.cards.size():
		var card: CardView = card_scene.instantiate()
		card.pressed.connect(_on_card_pressed.bind(_cards.size()))
		_board.add_child(card)
		_cards.append(card)
	for i in _cards.size():
		_cards[i].visible = i < match_round.cards.size()
		if _cards[i].visible:
			_cards[i].setup(FACES[match_round.cards[i].face], _cards[i].custom_minimum_size.x)


func _on_card_pressed(index: int) -> void:
	var result := _session.flip(index)
	if result == MatchRound.Flip.IGNORED:
		return
	_sync_cards()
	if result == MatchRound.Flip.MATCH:
		_progress.light_next()
	elif result == MatchRound.Flip.MISMATCH:
		_wobble_timer.start()
		_hide_timer.start()


## Brings every card view in line with its card in the round.
func _sync_cards() -> void:
	var cards := _session.match_round.cards
	for i in cards.size():
		var view := _cards[i]
		if cards[i].is_face_up != view.shows_face:
			if cards[i].is_face_up:
				view.turn_up()
			else:
				view.turn_down()
		if cards[i].is_matched and not view.shows_matched:
			view.celebrate()


func _wobble_mismatch() -> void:
	var cards := _session.match_round.cards
	for i in cards.size():
		if cards[i].is_face_up and not cards[i].is_matched:
			_cards[i].wobble()


func _hide_mismatch() -> void:
	_session.hide_mismatch()
	_sync_cards()


func _show_win() -> void:
	_win_screen.celebrate(stars_text(_level))


func _show_start() -> void:
	_stop_timers()
	_game_screen.hide()
	_win_screen.hide()
	_start_screen.show()


func _stop_timers() -> void:
	for timer in [_wobble_timer, _hide_timer, _win_timer]:
		timer.stop()


func _layout() -> void:
	var screen := get_viewport_rect().size
	var gap := minf(screen.x, screen.y) * GAP_RATIO
	if _session.match_round == null:
		return
	var layout := board_layout(_session.match_round.cards.size(), screen * BOARD_AREA, gap)
	_board.columns = layout.x
	_board.add_theme_constant_override("h_separation", int(gap))
	_board.add_theme_constant_override("v_separation", int(gap))
	for card in _cards:
		card.resize(layout.y)
