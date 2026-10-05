extends GutTest

const ScreenScene := preload("res://src/account/presentation/account_screen.tscn")
const FakeServices := preload("res://tests/unit/app/fake_services.gd")

var services: FakeServices
var screen: AccountScreen


func before_each() -> void:
	_open(false)


func _open(signed_in: bool) -> void:
	services = FakeServices.new(signed_in)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	screen = ScreenScene.instantiate()
	screen.setup(services.account, _log_out, services.cloud_saves.delete_account, rng)
	add_child_autofree(screen)
	watch_signals(screen)


func _log_out(discard_unsaved: bool) -> bool:
	return await services.cloud_saves.log_out(discard_unsaved) == ProgressCloud.Result.OK


func _press(button: String) -> void:
	(screen.get_node("%" + button) as Button).pressed.emit()


func _text(node: String) -> String:
	return screen.get_node("%" + node).text


func _type(field: String, text: String) -> void:
	(screen.get_node("%" + field) as LineEdit).text = text


func _visible_page() -> AccountScreen.Page:
	var visible: Array[AccountScreen.Page] = []
	for page: AccountScreen.Page in screen._pages:
		if screen._pages[page].visible:
			visible.append(page)
	assert_eq(visible.size(), 1, "exactly one page shows")
	return visible[0]


func _pass_gate() -> void:
	var gate: ParentGate = screen.get_node("%Gate")
	for digit in str(gate._question.a * gate._question.b):
		gate.press(digit)
	gate.press(ParentGate.OK)


func _go_to_create() -> void:
	_press("CreateChoiceButton")
	_pass_gate()


func test_guest_sees_the_two_choices() -> void:
	assert_eq(_visible_page(), AccountScreen.Page.GUEST)
	assert_false(screen.get_node("%Message").visible)
	assert_false(screen.get_node("%ShowPassword").visible)


func test_logged_in_sees_the_account_page_with_the_username() -> void:
	screen.free()
	_open(true)

	assert_eq(_visible_page(), AccountScreen.Page.ACCOUNT)
	assert_eq(_text("Title"), FakeServices.USERNAME)


func test_create_needs_the_parental_gate() -> void:
	_press("CreateChoiceButton")

	assert_eq(_visible_page(), AccountScreen.Page.GATE)
	_pass_gate()
	assert_eq(_visible_page(), AccountScreen.Page.CREATE)
	assert_true(Username.is_valid(_text("NewName")))


func test_shuffle_gives_another_valid_name() -> void:
	_go_to_create()
	var first := _text("NewName")

	_press("ShuffleButton")

	assert_ne(_text("NewName"), first)
	assert_true(Username.is_valid(_text("NewName")))


func test_create_registers_and_shows_the_account_card() -> void:
	_go_to_create()
	var username := _text("NewName")
	_type("NewPassword", "password1")

	_press("CreateButton")

	assert_eq(services.account.username(), username)
	assert_eq(_visible_page(), AccountScreen.Page.CARD)
	assert_eq(_text("CardName"), username)
	assert_eq(_text("Message"), AccountScreen.CARD_MESSAGE)
	assert_eq(_text("NewPassword"), "", "the typed password is cleared")
	_press("CardOkButton")
	assert_eq(_visible_page(), AccountScreen.Page.ACCOUNT)


func test_create_with_short_password_explains_and_sends_nothing() -> void:
	_go_to_create()
	_type("NewPassword", "short")

	_press("CreateButton")

	assert_eq(_visible_page(), AccountScreen.Page.CREATE)
	assert_eq(_text("Message"), AccountScreen.MESSAGES[AuthGateway.Status.WEAK_PASSWORD])
	assert_eq(services.gateway.calls, 0)


func test_create_with_taken_name_offers_a_new_one() -> void:
	_go_to_create()
	var taken := _text("NewName")
	services.gateway.passwords[taken.to_lower()] = "someone else"
	_type("NewPassword", "password1")

	_press("CreateButton")

	assert_eq(_visible_page(), AccountScreen.Page.CREATE)
	assert_ne(_text("NewName"), taken)
	assert_eq(_text("Message"), AccountScreen.MESSAGES[AuthGateway.Status.USERNAME_TAKEN])
	assert_false(services.account.is_signed_in())


func test_log_in_shows_the_account_page() -> void:
	services.gateway.passwords["happycat27"] = "password1"
	_press("LoginChoiceButton")
	_type("LoginName", "happycat27")
	_type("LoginPassword", "password1")

	_press("LoginButton")

	assert_eq(_visible_page(), AccountScreen.Page.ACCOUNT)
	assert_eq(_text("Title"), "HappyCat27")


func test_failed_log_in_shows_a_kid_safe_message_for_every_status() -> void:
	_press("LoginChoiceButton")
	for status: AuthGateway.Status in AccountScreen.MESSAGES:
		services.gateway.failure = status
		_type("LoginName", "HappyCat27")
		_type("LoginPassword", "password1")

		_press("LoginButton")

		assert_eq(_visible_page(), AccountScreen.Page.LOGIN)
		assert_eq(_text("Message"), AccountScreen.MESSAGES[status])


func test_every_failure_status_has_a_message() -> void:
	for status: AuthGateway.Status in AuthGateway.Status.values():
		if status != AuthGateway.Status.OK:
			assert_true(AccountScreen.MESSAGES.has(status), str(status))


func test_show_password_reveals_the_password_fields() -> void:
	_press("LoginChoiceButton")
	var field: LineEdit = screen.get_node("%LoginPassword")
	var toggle: CheckBox = screen.get_node("%ShowPassword")

	assert_true(toggle.visible)
	assert_true(field.secret)
	toggle.button_pressed = true
	assert_false(field.secret)
	toggle.button_pressed = false
	assert_true(field.secret)


func test_password_fields_are_capped() -> void:
	for field in ["NewPassword", "LoginPassword", "ConfirmPassword"]:
		assert_eq((screen.get_node("%" + field) as LineEdit).max_length, Password.MAX_LENGTH, field)


func test_log_out_returns_to_the_guest_page() -> void:
	screen.free()
	_open(true)

	_press("LogOutButton")

	assert_false(services.account.is_signed_in())
	assert_eq(_visible_page(), AccountScreen.Page.GUEST)


func test_log_out_with_unsaved_progress_asks_first() -> void:
	screen.free()
	_open(true)
	services.cloud.pull_result = ProgressCloud.Result.OFFLINE

	_press("LogOutButton")

	assert_true(services.account.is_signed_in())
	assert_eq(_visible_page(), AccountScreen.Page.CONFIRM)
	assert_eq(_text("Message"), AccountScreen.UNSAVED_MESSAGE)
	assert_false(screen.get_node("%ConfirmPassword").visible)


func test_unsaved_log_out_no_keeps_the_login() -> void:
	screen.free()
	_open(true)
	services.cloud.pull_result = ProgressCloud.Result.OFFLINE
	_press("LogOutButton")

	_press("NoButton")

	assert_true(services.account.is_signed_in())
	assert_eq(_visible_page(), AccountScreen.Page.ACCOUNT)


func test_unsaved_log_out_yes_logs_out() -> void:
	screen.free()
	_open(true)
	services.cloud.pull_result = ProgressCloud.Result.OFFLINE
	_press("LogOutButton")

	_press("YesButton")

	assert_false(services.account.is_signed_in())
	assert_eq(_visible_page(), AccountScreen.Page.GUEST)


func test_delete_needs_the_gate_and_the_password() -> void:
	screen.free()
	_open(true)

	_press("DeleteButton")
	assert_eq(_visible_page(), AccountScreen.Page.GATE)
	_pass_gate()

	assert_eq(_visible_page(), AccountScreen.Page.CONFIRM)
	assert_eq(_text("Message"), AccountScreen.DELETE_MESSAGE)
	assert_true(screen.get_node("%ConfirmPassword").visible)
	assert_true(services.account.is_signed_in())


func test_delete_with_wrong_password_keeps_the_account() -> void:
	screen.free()
	_open(true)
	_press("DeleteButton")
	_pass_gate()
	_type("ConfirmPassword", "password2")

	_press("YesButton")

	assert_true(services.account.is_signed_in())
	assert_eq(_visible_page(), AccountScreen.Page.CONFIRM)
	assert_eq(_text("Message"), AccountScreen.MESSAGES[AuthGateway.Status.WRONG_CREDENTIALS])
	assert_eq(services.gateway.deleted_tokens.size(), 0)


func test_delete_with_right_password_deletes_and_says_so() -> void:
	screen.free()
	_open(true)
	services.http.reply(200, {})
	_press("DeleteButton")
	_pass_gate()
	_type("ConfirmPassword", FakeServices.PASSWORD)

	_press("YesButton")

	assert_false(services.account.is_signed_in())
	assert_eq(services.gateway.deleted_tokens.size(), 1)
	assert_eq(_visible_page(), AccountScreen.Page.GUEST)
	assert_eq(_text("Message"), AccountScreen.DELETED_MESSAGE)


func test_back_from_a_home_page_leaves_the_screen() -> void:
	_press("BackButton")

	assert_signal_emitted(screen, "exit_requested")


func test_back_from_an_inner_page_returns_home() -> void:
	_press("LoginChoiceButton")

	_press("BackButton")

	assert_signal_not_emitted(screen, "exit_requested")
	assert_eq(_visible_page(), AccountScreen.Page.GUEST)


func test_buttons_are_blocked_while_a_request_is_running() -> void:
	screen.free()
	_open(true)
	services.cloud.hold = true

	_press("LogOutButton")
	assert_true(screen.get_node("%Blocker").visible)
	services.cloud.release()

	assert_false(screen.get_node("%Blocker").visible)
