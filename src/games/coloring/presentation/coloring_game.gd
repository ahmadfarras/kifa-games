class_name ColoringGame
extends Control

## Coloring Fun screens: pick a picture, tap regions to paint them, celebrate. Event driven: the canvas
## redraws only on taps, and "magic" reveals its colours with a short repeating timer.

signal exit_requested

const PALETTE: Array[Color] = [
	Color("#ff4d4d"), Color("#ff9f1c"), Color("#ffd93d"), Color("#6bcb77"), Color("#4d96ff"),
	Color("#9b5de5"), Color("#ff6bb5"), Color("#8ee3ef"), Color("#a0704f"),
]
## How a BLANK (unpainted / erased) region looks.
const BLANK_COLOR := Color.WHITE
const ERASER_TEXT := "🧼"
const SWATCH_SIZE := 64.0
const SWATCH_BORDER := Color(0, 0, 0, 0.12)
const SELECTED_BORDER := Color("#444444")
const SELECTED_SCALE := Vector2(1.25, 1.25)

var _session: ColoringSession
var _picture: ColoringPicture
## Colour index shown per region; lags behind the page only while magic is revealing.
var _shown: Array[int] = []
var _display: Array[Color] = []
var _reveal_next := 0
var _swatches: Array[Button] = []
var _swatch_colors: Array[int] = []
var _swatch_styles: Array[StyleBoxFlat] = []

@onready var _pick_screen: Control = %PickScreen
@onready var _picture_buttons: Container = %PictureButtons
@onready var _color_screen: Control = %ColorScreen
@onready var _canvas: ColoringCanvas = %Canvas
@onready var _palette: GridContainer = %Palette
@onready var _finish_screen: WinScreen = %FinishScreen
@onready var _magic_timer: Timer = %MagicTimer
@onready var _complete_timer: Timer = %CompleteTimer


func setup(session: ColoringSession) -> void:
	_session = session


func _ready() -> void:
	for i in PictureLibrary.IDS.size():
		_add_picture_button(i)
	for color in PALETTE.size():
		_add_swatch(color)
	_add_swatch(ColoringPage.BLANK)
	%BackButton.pressed.connect(exit_requested.emit)
	%PicturesButton.pressed.connect(_show_pick)
	%MagicButton.pressed.connect(_magic)
	%ClearButton.pressed.connect(_clear)
	%FinishButton.pressed.connect(_finish_screen.celebrate)
	_finish_screen.primary_pressed.connect(_finish_screen.hide)
	_finish_screen.secondary_pressed.connect(_show_pick)
	_canvas.region_tapped.connect(_on_region_tapped)
	_session.page_completed.connect(_complete_timer.start)
	_complete_timer.timeout.connect(_finish_screen.celebrate)
	_magic_timer.timeout.connect(_reveal_one)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_pick()


func _add_picture_button(index: int) -> void:
	var button: Button = %PictureButtonTemplate.duplicate()
	button.text = PictureLibrary.ICONS[index]
	button.show()
	button.pressed.connect(_open.bind(PictureLibrary.IDS[index]))
	_picture_buttons.add_child(button)


func _add_swatch(color: int) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2.ONE * SWATCH_SIZE
	button.pivot_offset = button.custom_minimum_size * 0.5
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 28)
	if color == ColoringPage.BLANK:
		button.text = ERASER_TEXT
	var style := StyleBoxFlat.new()
	style.bg_color = BLANK_COLOR if color == ColoringPage.BLANK else PALETTE[color]
	style.set_corner_radius_all(int(SWATCH_SIZE))
	style.set_border_width_all(4)
	style.border_color = SWATCH_BORDER
	button.pressed.connect(_pick.bind(_swatches.size()))
	_palette.add_child(button)
	_swatches.append(button)
	_swatch_colors.append(color)
	_swatch_styles.append(style)
	_paint_swatch(button, style)


func _open(id: StringName) -> void:
	_picture = PictureLibrary.build(id)
	var page := _session.open(_picture.region_count)
	_magic_timer.stop()
	_complete_timer.stop()
	_shown = page.colors.duplicate()
	_display.resize(_shown.size())
	_refresh()
	_canvas.show_picture(_picture, _display)
	_pick(0)
	_pick_screen.hide()
	_finish_screen.hide()
	_color_screen.show()


func _pick(swatch: int) -> void:
	_session.pick(_swatch_colors[swatch])
	for i in _swatches.size():
		var selected := i == swatch
		_swatch_styles[i].border_color = SELECTED_BORDER if selected else SWATCH_BORDER
		_swatches[i].scale = SELECTED_SCALE if selected else Vector2.ONE
		_swatches[i].rotation = 0.0
	var tween := _swatches[swatch].create_tween()
	for degrees in [-8.0, 8.0, 0.0]:
		tween.tween_property(_swatches[swatch], "rotation", deg_to_rad(degrees), 0.1)


func _on_region_tapped(region: int) -> void:
	_finish_reveal()
	_session.paint(region)
	_shown[region] = _session.page.colors[region]
	_refresh()


func _magic() -> void:
	_session.magic(PALETTE.size())
	_reveal_next = 0
	_magic_timer.start()


## Shows the next magic colour; the timer repeats until every region is revealed.
func _reveal_one() -> void:
	_shown[_reveal_next] = _session.page.colors[_reveal_next]
	_reveal_next += 1
	if _reveal_next >= _shown.size():
		_magic_timer.stop()
	_refresh()


func _finish_reveal() -> void:
	if _magic_timer.is_stopped():
		return
	_magic_timer.stop()
	_shown = _session.page.colors.duplicate()


func _clear() -> void:
	_magic_timer.stop()
	_complete_timer.stop()
	_session.clear()
	_shown = _session.page.colors.duplicate()
	_refresh()


func _refresh() -> void:
	for i in _shown.size():
		_display[i] = BLANK_COLOR if _shown[i] == ColoringPage.BLANK else PALETTE[_shown[i]]
	_canvas.refresh()


func _show_pick() -> void:
	_magic_timer.stop()
	_complete_timer.stop()
	_color_screen.hide()
	_finish_screen.hide()
	_pick_screen.show()


func _layout() -> void:
	var screen := get_viewport_rect().size
	_palette.columns = _swatches.size() if screen.x > screen.y else ceili(_swatches.size() / 2.0)


static func _paint_swatch(button: Button, style: StyleBox) -> void:
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, style)
