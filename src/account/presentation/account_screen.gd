class_name AccountScreen
extends Control

## Where a grown-up creates an account, logs in, logs out or deletes the account. Thin: it shows one
## page at a time, passes what was typed to AccountService and turns the result into a kid-safe message.
## Logging out and deleting also change the progress on the device; the app does that part through the
## two callables given to setup().

signal exit_requested

enum Page { GUEST, GATE, CREATE, LOGIN, CARD, ACCOUNT, CONFIRM, PRIVACY }
## What the confirm page is asking for.
enum Confirm { LOG_OUT_UNSAVED, DELETE }

const TITLES: Dictionary[Page, String] = {
	Page.GUEST: "Keep your stars and coins\non every device",
	Page.GATE: "Grown-ups only",
	Page.CREATE: "Your new account",
	Page.LOGIN: "Log in",
	Page.CARD: "Write this down!",
	Page.CONFIRM: "Are you sure?",
	Page.PRIVACY: "Privacy",
}
const MESSAGES: Dictionary[AuthGateway.Status, String] = {
	AuthGateway.Status.INVALID_USERNAME: "Use 3 to 16 letters or numbers for the name.",
	AuthGateway.Status.USERNAME_TAKEN: "That name is taken. Try another one.",
	AuthGateway.Status.WRONG_CREDENTIALS: "Name or password is wrong.",
	AuthGateway.Status.WEAK_PASSWORD: "Use a password with 8 letters or more.",
	AuthGateway.Status.TOO_MANY_ATTEMPTS: "Too many tries. Wait a little.",
	AuthGateway.Status.OFFLINE: "No internet. Try again later.",
	AuthGateway.Status.SESSION_EXPIRED: "Please log in again.",
	AuthGateway.Status.UNKNOWN: "Something went wrong. Try again.",
}
const CREATE_HINT := "Pick a nickname, not your real name."
const CARD_MESSAGE := "Write down this name and your password.\nA lost password cannot be recovered."
const UNSAVED_MESSAGE := "Your newest stars and coins are not saved yet.\nLog out anyway?"
const DELETE_MESSAGE := "This deletes the account and everything saved in it.\nType the password to delete it."
const DELETED_MESSAGE := "The account was deleted."

var _account: AccountService
## func(discard_unsaved: bool) -> bool, awaited: true when logged out.
var _log_out: Callable
## func(password: String) -> AuthGateway.Status, awaited.
var _delete_account: Callable
var _rng: RandomNumberGenerator
var _page := Page.GUEST
var _confirm := Confirm.DELETE
var _after_gate := Page.CREATE

@onready var _title: Label = %Title
@onready var _message: Label = %Message
@onready var _gate: ParentGate = %Gate
@onready var _new_name: LineEdit = %NewName
@onready var _new_password: LineEdit = %NewPassword
@onready var _login_name: LineEdit = %LoginName
@onready var _login_password: LineEdit = %LoginPassword
@onready var _card_name: Label = %CardName
@onready var _confirm_password: LineEdit = %ConfirmPassword
@onready var _show_password: CheckBox = %ShowPassword
@onready var _privacy_button: Button = %PrivacyButton
@onready var _blocker: Control = %Blocker
@onready var _pages: Dictionary[Page, Control] = {
	Page.GUEST: %GuestPage, Page.GATE: %Gate, Page.CREATE: %CreatePage, Page.LOGIN: %LoginPage,
	Page.CARD: %CardPage, Page.ACCOUNT: %AccountPage, Page.CONFIRM: %ConfirmPage, Page.PRIVACY: %PrivacyPage,
}


func setup(
	account: AccountService, log_out: Callable, delete_account: Callable, rng: RandomNumberGenerator
) -> void:
	_account = account
	_log_out = log_out
	_delete_account = delete_account
	_rng = rng


func _ready() -> void:
	_gate.setup(_rng)
	_gate.passed.connect(_on_gate_passed)
	# On phones the browser moves its focus to a hidden text box while the on-screen keyboard is open,
	# and Godot then stops drawing the caret. Forcing it for the focused field keeps it visible.
	for field: LineEdit in [_new_name, _new_password, _login_name, _login_password, _confirm_password]:
		field.focus_entered.connect(field.set_caret_force_displayed.bind(true))
		field.focus_exited.connect(field.set_caret_force_displayed.bind(false))
	_new_name.max_length = Username.MAX_LENGTH
	_login_name.max_length = Username.MAX_LENGTH
	_new_password.max_length = Password.MAX_LENGTH
	_login_password.max_length = Password.MAX_LENGTH
	_confirm_password.max_length = Password.MAX_LENGTH
	%BackButton.pressed.connect(_on_back_pressed)
	%LoginChoiceButton.pressed.connect(_show.bind(Page.LOGIN))
	%CreateChoiceButton.pressed.connect(_ask_gate.bind(Page.CREATE))
	%CreateButton.pressed.connect(_on_create_pressed)
	%LoginButton.pressed.connect(_on_login_pressed)
	%CardOkButton.pressed.connect(_show.bind(Page.ACCOUNT))
	%LogOutButton.pressed.connect(_on_log_out_pressed)
	%DeleteButton.pressed.connect(_ask_gate.bind(Page.CONFIRM))
	%YesButton.pressed.connect(_on_yes_pressed)
	%NoButton.pressed.connect(_show_home)
	_privacy_button.pressed.connect(_show.bind(Page.PRIVACY))
	_show_password.toggled.connect(_on_show_password_toggled)
	_show_home()


func _show_home(message := "") -> void:
	_show(Page.ACCOUNT if _account.is_signed_in() else Page.GUEST, message)


func _show(page: Page, message := "") -> void:
	_page = page
	for key: Page in _pages:
		_pages[key].visible = key == page
	_title.text = _account.username() if page == Page.ACCOUNT else TITLES[page]
	_message.text = message
	_message.visible = not message.is_empty()
	_show_password.visible = page in [Page.CREATE, Page.LOGIN] or (page == Page.CONFIRM and _confirm == Confirm.DELETE)
	_show_password.button_pressed = false
	_privacy_button.visible = page in [Page.GUEST, Page.ACCOUNT]
	# Typed passwords never stay around once the page changes.
	for field: LineEdit in [_new_password, _login_password, _confirm_password]:
		field.clear()


func _ask_gate(next: Page) -> void:
	_after_gate = next
	_gate.ask()
	_show(Page.GATE)


func _on_gate_passed() -> void:
	if _after_gate == Page.CREATE:
		_new_name.clear()
		_show(Page.CREATE, CREATE_HINT)
	else:
		_ask_confirm(Confirm.DELETE, DELETE_MESSAGE)


func _ask_confirm(confirm: Confirm, message: String) -> void:
	_confirm = confirm
	_confirm_password.visible = confirm == Confirm.DELETE
	_show(Page.CONFIRM, message)


func _on_create_pressed() -> void:
	var status: AuthGateway.Status = await _busy_while(
		_account.register.bind(_new_name.text, _new_password.text)
	)
	if status == AuthGateway.Status.OK:
		_card_name.text = _account.username()
		_show(Page.CARD, CARD_MESSAGE)
	else:
		# The typed name stays so it can be corrected; the password is cleared like on every page change.
		_show(Page.CREATE, MESSAGES[status])


func _on_login_pressed() -> void:
	var status: AuthGateway.Status = await _busy_while(
		_account.log_in.bind(_login_name.text, _login_password.text)
	)
	if status == AuthGateway.Status.OK:
		_show(Page.ACCOUNT)
	else:
		_show(Page.LOGIN, MESSAGES[status])


func _on_log_out_pressed() -> void:
	if await _busy_while(_log_out.bind(false)):
		_show_home()
	else:
		_ask_confirm(Confirm.LOG_OUT_UNSAVED, UNSAVED_MESSAGE)


func _on_yes_pressed() -> void:
	if _confirm == Confirm.LOG_OUT_UNSAVED:
		await _busy_while(_log_out.bind(true))
		_show_home()
		return
	var status: AuthGateway.Status = await _busy_while(_delete_account.bind(_confirm_password.text))
	if status == AuthGateway.Status.OK:
		_show_home(DELETED_MESSAGE)
	else:
		_ask_confirm(Confirm.DELETE, MESSAGES[status])


func _on_back_pressed() -> void:
	if _page in [Page.GUEST, Page.ACCOUNT]:
		exit_requested.emit()
	else:
		_show_home()


func _on_show_password_toggled(shown: bool) -> void:
	for field: LineEdit in [_new_password, _login_password, _confirm_password]:
		field.secret = not shown


## Blocks every button while a request is on its way, so nothing is sent twice.
func _busy_while(action: Callable) -> Variant:
	_blocker.show()
	var result: Variant = await action.call()
	_blocker.hide()
	return result
