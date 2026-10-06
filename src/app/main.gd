extends Node

## Composition root: shows the menu and builds each game with its concrete dependencies.
## Game scenes are loaded only when picked and freed on exit, so one game's art never stays in memory
## while another is played.

const HUB_SCENE := "res://src/app/hub.tscn"
const RUNNER_GAME_SCENE := "res://src/games/runner/presentation/runner_game.tscn"
const MATCH_GAME_SCENE := "res://src/games/match/presentation/match_game.tscn"
const MATH_GAME_SCENE := "res://src/games/math/presentation/math_game.tscn"
const COLORING_GAME_SCENE := "res://src/games/coloring/presentation/coloring_game.tscn"
const ACCOUNT_SCENE := "res://src/account/presentation/account_screen.tscn"
## Only the emoji the UI uses (see tools/subset_emoji_font.py).
const EMOJI_FONT := "res://assets/shared/fonts/noto_color_emoji_subset.ttf"

var _current: Node
var _account: AccountService
var _repository: ProgressRepository
var _cloud_saves: CloudSaves


## Optional, before the node enters the tree: tests pass in-memory services so nothing touches the
## network or the real save files. Without it _ready() builds the real ones.
func setup(account: AccountService, repository: ProgressRepository, cloud_saves: CloudSaves) -> void:
	_account = account
	_repository = repository
	_cloud_saves = cloud_saves


func _ready() -> void:
	use_bundled_emoji()
	if _cloud_saves == null:
		_build_services()
	show_hub()
	_cloud_saves.sync_device()


## Browsers give Godot no system emoji font, so emoji glyphs come from a bundled font that every
## text falls back to (desktop and mobile then look the same as Web).
static func use_bundled_emoji() -> void:
	var default_font := ThemeDB.fallback_font
	var emoji: Font = load(EMOJI_FONT)
	if not default_font.fallbacks.has(emoji):
		default_font.fallbacks = default_font.fallbacks + [emoji]


func show_hub() -> void:
	var hub: Hub = load(HUB_SCENE).instantiate()
	hub.game_chosen.connect(_on_game_chosen)
	hub.account_requested.connect(show_account)
	_switch_to(hub)
	hub.show_account(_account.username())


func show_account() -> void:
	var screen: AccountScreen = load(ACCOUNT_SCENE).instantiate()
	screen.setup(_account, _log_out, _cloud_saves.delete_account, _new_rng())
	screen.exit_requested.connect(show_hub)
	_switch_to(screen)


## True when logged out (the account screen warns and asks again when it is not).
func _log_out(discard_unsaved: bool) -> bool:
	return await _cloud_saves.log_out(discard_unsaved) == ProgressCloud.Result.OK


func _on_game_chosen(game: StringName) -> void:
	match game:
		Hub.RUNNER:
			_switch_to(_build_runner())
		Hub.MATCH:
			_switch_to(_build_match())
		Hub.MATH:
			_switch_to(_build_math())
		Hub.COLORING:
			_switch_to(_build_coloring())


func _build_runner() -> RunnerGame:
	var rng := _new_rng()
	var session := RunnerSession.new(_repository, rng)
	_cloud_saves.watch(session)
	var game: RunnerGame = load(RUNNER_GAME_SCENE).instantiate()
	game.setup(session, rng)
	game.exit_requested.connect(_on_runner_exit)
	return game


func _on_runner_exit() -> void:
	_cloud_saves.unwatch()
	show_hub()


func _build_match() -> MatchGame:
	var game: MatchGame = load(MATCH_GAME_SCENE).instantiate()
	game.setup(MatchSession.new(_new_rng()))
	game.exit_requested.connect(show_hub)
	return game


func _build_math() -> MathGame:
	var game: MathGame = load(MATH_GAME_SCENE).instantiate()
	game.setup(MathSession.new(_new_rng()))
	game.exit_requested.connect(show_hub)
	return game


func _build_coloring() -> ColoringGame:
	var game: ColoringGame = load(COLORING_GAME_SCENE).instantiate()
	game.setup(ColoringSession.new(_new_rng()))
	game.exit_requested.connect(show_hub)
	return game


## Accounts and cloud saves, built once: one HTTP node for logging in and one for cloud saves, so a
## cloud save request can wait for a login token without blocking itself.
func _build_services() -> void:
	var clock := Time.get_unix_time_from_system
	var config := FirebaseConfig.new()
	var gateway := FirebaseAuthGateway.new(_new_http(), config.api_key)
	_account = AccountService.new(gateway, JsonAccountStore.new(), clock)
	_repository = JsonProgressRepository.new()
	var documents := FirestoreDocuments.new(
		_new_http(), config.project_id, _account.id_token, _account.uid
	)
	var sync := ProgressSync.new(_repository, FirestoreProgressCloud.new(documents))
	_cloud_saves = CloudSaves.new(_account, _repository, sync, documents, clock)


func _new_http() -> JsonHttp:
	var request := JsonHttp.new_request()
	add_child(request)
	return JsonHttp.new(request)


func _switch_to(scene: Node) -> void:
	if _current != null:
		_current.queue_free()
	_current = scene
	add_child(scene)


func _new_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng
