class_name AccountSession
extends RefCounted

## Who is logged in on this device. The refresh token is the only credential kept on the device;
## the password is never stored. Treat as read-only: a new token means a new AccountSession.

var uid: String
var username: String
var refresh_token: String


func _init(account_uid: String, account_username: String, account_refresh_token: String) -> void:
	uid = account_uid
	username = account_username
	refresh_token = account_refresh_token
