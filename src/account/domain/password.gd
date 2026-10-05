class_name Password
extends RefCounted

## Password rule: length only, so a grown-up can pick something they will remember.
## The server enforces the same minimum; MAX_LENGTH bounds what the game sends.

const MIN_LENGTH := 8
const MAX_LENGTH := 64


static func is_valid(text: String) -> bool:
	return text.length() >= MIN_LENGTH and text.length() <= MAX_LENGTH
