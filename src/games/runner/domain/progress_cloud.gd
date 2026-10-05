@abstract
class_name ProgressCloud
extends RefCounted

## Port: the cloud save, the copy of Runner progress kept on a server for a logged-in account.
## Both calls go over the network, so callers await them.

enum Result { OK, NOT_SIGNED_IN, OFFLINE, FAILED }


class Pull:
	extends RefCounted

	var result: Result
	## null when the account has no cloud save yet (or the pull failed).
	var progress: Progress

	func _init(pull_result: Result, pulled: Progress = null) -> void:
		result = pull_result
		progress = pulled


@abstract func pull() -> Pull


@abstract func push(progress: Progress) -> Result
