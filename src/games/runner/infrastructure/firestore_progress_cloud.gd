class_name FirestoreProgressCloud
extends ProgressCloud

## The Runner cloud save: one Firestore document per account, in the same format as the save file.
## Server data goes through ProgressCodec exactly like a tampered save file would.

const GAME := "runner"
const RESULTS: Dictionary[FirestoreDocuments.Status, Result] = {
	FirestoreDocuments.Status.OK: Result.OK,
	FirestoreDocuments.Status.NOT_FOUND: Result.OK,
	FirestoreDocuments.Status.NOT_SIGNED_IN: Result.NOT_SIGNED_IN,
	FirestoreDocuments.Status.OFFLINE: Result.OFFLINE,
	FirestoreDocuments.Status.FAILED: Result.FAILED,
}

var _documents: FirestoreDocuments


func _init(documents: FirestoreDocuments) -> void:
	_documents = documents


func pull() -> Pull:
	var document: FirestoreDocuments.Document = await _documents.read(GAME)
	if document.status != FirestoreDocuments.Status.OK:
		return Pull.new(RESULTS[document.status])
	var progress := ProgressCodec.from_dictionary(document.data)
	# A cloud save from a newer app must not be overwritten with this app's older format.
	if progress == null:
		return Pull.new(Result.FAILED)
	return Pull.new(Result.OK, progress)


func push(progress: Progress) -> Result:
	return RESULTS[await _documents.write(GAME, ProgressCodec.to_dictionary(progress))]
