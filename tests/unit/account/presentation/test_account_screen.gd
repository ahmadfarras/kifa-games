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
	assert_eq(_text("NewName"), "")
	assert_eq(_text("Message"), AccountScreen.CREATE_HINT, "nudges away from a real name")


func test_create_registers_the_typed_name_and_shows_the_account_card() -> void:
	_go_to_create()
	_type("NewName", "Budi7")
	_type("NewPassword", "password1")

	_press("CreateButton")

	assert_eq(services.account.username(), "Budi7")
	assert_eq(_visible_page(), AccountScreen.Page.CARD)
	assert_eq(_text("CardName"), "Budi7")
	assert_eq(_text("Message"), AccountScreen.CARD_MESSAGE)
	assert_eq(_text("NewPassword"), "", "the typed password is cleared")
	_press("CardOkButton")
	assert_eq(_visible_page(), AccountScreen.Page.ACCOUNT)


func test_create_with_a_name_that_is_not_allowed_explains_and_sends_nothing() -> void:
	_go_to_create()
	_type("NewName", "Budi Santoso")
	_type("NewPassword", "password1")

	_press("CreateButton")

	assert_eq(_visible_page(), AccountScreen.Page.CREATE)
	assert_eq(_text("Message"), AccountScreen.MESSAGES[AuthGateway.Status.INVALID_USERNAME])
	assert_eq(_text("NewName"), "Budi Santoso", "kept so it can be corrected")
	assert_eq(services.gateway.calls, 0)


func test_create_with_short_password_explains_and_sends_nothing() -> void:
	_go_to_create()
	_type("NewName", "Budi7")
	_type("NewPassword", "short")

	_press("CreateButton")

	assert_eq(_visible_page(), AccountScreen.Page.CREATE)
	assert_eq(_text("Message"), AccountScreen.MESSAGES[AuthGateway.Status.WEAK_PASSWORD])
	assert_eq(services.gateway.calls, 0)


func test_create_with_taken_name_asks_for_another() -> void:
	services.gateway.passwords["budi7"] = "someone else"
	_go_to_create()
	_type("NewName", "BUDI7")
	_type("NewPassword", "password1")

	_press("CreateButton")

	assert_eq(_visible_page(), AccountScreen.Page.CREATE)
	assert_eq(_text("Message"), AccountScreen.MESSAGES[AuthGateway.Status.USERNAME_TAKEN])
	assert_false(services.account.is_signed_in())


func test_create_page_starts_empty_every_time() -> void:
	_go_to_create()
	_type("NewName", "Budi7")
	_press("BackButton")

	_go_to_create()

	assert_eq(_text("NewName"), "")


func test_log_in_shows_the_account_page() -> void:
	services.gateway.passwords["happycat27"] = "password1"
	_press("LoginChoiceButton")
	_type("LoginName", "happycat27")
	_type("LoginPassword", "password1")

	_press("LoginButton")

	assert_eq(_visible_page(), AccountScreen.Page.ACCOUNT)
	assert_eq(_text("Title"), "happycat27")


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


func test_caret_is_forced_only_for_the_focused_field() -> void:
	_press("LoginChoiceButton")
	var name_field: LineEdit = screen.get_node("%LoginName")
	var password_field: LineEdit = screen.get_node("%LoginPassword")

	name_field.grab_focus()
	assert_true(name_field.caret_force_displayed, "stays visible while the phone keyboard is open")
	assert_false(password_field.caret_force_displayed)
	password_field.grab_focus()

	assert_false(name_field.caret_force_displayed)
	assert_true(password_field.caret_force_displayed)


func test_name_fields_are_capped() -> void:
	for field in ["NewName", "LoginName"]:
		assert_eq((screen.get_node("%" + field) as LineEdit).max_length, Username.MAX_LENGTH, field)


func test_text_fields_show_a_visible_blinking_caret() -> void:
	for field in ["NewName", "NewPassword", "LoginName", "LoginPassword", "ConfirmPassword"]:
		var line: LineEdit = screen.get_node("%" + field)
		var caret := line.get_theme_color("caret_color")
		var background: Color = (line.get_theme_stylebox("normal") as StyleBoxFlat).bg_color

		assert_true(line.caret_blink, field)
		assert_gt(absf(caret.get_luminance() - background.get_luminance()), 0.3, field + " caret stands out")
		assert_gte(line.get_theme_constant("caret_width"), 3, field)


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


func test_privacy_is_reachable_for_guests_and_accounts_and_back_returns() -> void:
	assert_true(screen.get_node("%PrivacyButton").visible)

	_press("PrivacyButton")
	assert_eq(_visible_page(), AccountScreen.Page.PRIVACY)
	assert_false(screen.get_node("%PrivacyButton").visible)
	_press("BackButton")

	assert_eq(_visible_page(), AccountScreen.Page.GUEST)
	screen.free()
	_open(true)
	assert_true(screen.get_node("%PrivacyButton").visible)


func test_privacy_button_is_hidden_on_inner_pages() -> void:
	_press("LoginChoiceButton")

	assert_false(screen.get_node("%PrivacyButton").visible)


func test_privacy_text_names_what_is_stored_and_how_to_delete_it() -> void:
	var text := _text("PrivacyText")

	for expected in ["nickname", "password", "progress", "Delete account", "no ads"]:
		assert_string_contains(text, expected)
