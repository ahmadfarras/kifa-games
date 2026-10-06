class_name FirebaseConfig
extends RefCounted

## Which Firebase project the game talks to, read from `res://firebase.env` (git-ignored; copy
## `firebase.env.example`). The file is packed into every export, so its values are not secret from
## players: what an account may do is decided on the server by firestore.rules, and the key must be
## restricted in the Google Cloud console. Real secrets (service accounts) never go into this file.
## Without the file the game still runs; accounts and cloud saves just answer "try again".

const PATH := "res://firebase.env"
const PROJECT_ID_KEY := "FIREBASE_PROJECT_ID"
const API_KEY_KEY := "FIREBASE_API_KEY"

var project_id := ""
var api_key := ""


func _init(path: String = PATH) -> void:
	var values := parse(FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "")
	project_id = values.get(PROJECT_ID_KEY, "")
	api_key = values.get(API_KEY_KEY, "")


## Reads `NAME=value` lines; blank lines and lines starting with # are skipped.
static func parse(text: String) -> Dictionary[String, String]:
	var values: Dictionary[String, String] = {}
	for line in text.split("\n"):
		var entry := line.strip_edges()
		var separator := entry.find("=")
		if entry.begins_with("#") or separator <= 0:
			continue
		values[entry.left(separator).strip_edges()] = entry.substr(separator + 1).strip_edges()
	return values
