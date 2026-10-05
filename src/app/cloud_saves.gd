class_name CloudSaves
extends RefCounted

## Decides when the device's progress is synced with the logged-in account's cloud save, and what
## logging out and deleting the account do to the progress on the device.
## Everything is event driven (app start, login, purchase, run end, leaving Runner): nothing polls,
## and a guest never causes a request.

## Run ends are frequent, so they sync at most this often (seconds); the other events always sync.
const RUN_END_INTERVAL := 60.0
## Every game with a cloud save; all of them are removed when the account is deleted.
const GAMES: Array[String] = [FirestoreProgressCloud.GAME]

var _account: AccountService
var _repository: ProgressRepository
var _sync: ProgressSync
var _documents: FirestoreDocuments
## Returns the current time in seconds; injected so tests control it.
var _clock: Callable
## The Runner session being played, if any: its progress is the one to sync.
var _session: RunnerSession
var _last_sync_at := -INF
var _refreshing := false


func _init(
	account: AccountService, repository: ProgressRepository, sync: ProgressSync,
	documents: FirestoreDocuments, clock: Callable
) -> void:
	_account = account
	_repository = repository
	_sync = sync
	_documents = documents
	_clock = clock
	_account.signed_in.connect(_on_signed_in)
	_sync.merged.connect(_on_merged)


## Syncs the progress saved on the device (app start, login).
func sync_device() -> ProgressCloud.Result:
	return await _sync_now(_current_progress())


## Call when Runner opens: purchases and run ends of this session are synced from now on.
func watch(session: RunnerSession) -> void:
	_session = session
	session.progress_changed.connect(_on_progress_changed)
	session.run_ended.connect(_on_run_ended)


## Call when Runner closes: syncs what was earned and stops following the session.
func unwatch() -> void:
	if _session == null:
		return
	var progress := _session.progress
	_session.progress_changed.disconnect(_on_progress_changed)
	_session.run_ended.disconnect(_on_run_ended)
	_session = null
	_sync_now(progress)


## Logs out and resets the device to fresh guest progress, so the next kid on this device does not
## inherit this account's coins. The progress is synced first; when that fails nothing happens and the
## result says why, so the caller can warn and call again with discard_unsaved.
func log_out(discard_unsaved := false) -> ProgressCloud.Result:
	if not discard_unsaved:
		var result: ProgressCloud.Result = await _sync_now(_current_progress())
		if result != ProgressCloud.Result.OK:
			return result
	_reset_device()
	_account.log_out()
	return ProgressCloud.Result.OK


## Deletes the cloud saves and then the account. The password is asked again first, so nothing is
## deleted unless it is right.
func delete_account(password: String) -> AuthGateway.Status:
	var status: AuthGateway.Status = await _account.confirm_password(password)
	if status != AuthGateway.Status.OK:
		return status
	for game in GAMES:
		var deleted: FirestoreDocuments.Status = await _documents.delete(game)
		if deleted == FirestoreDocuments.Status.OFFLINE:
			return AuthGateway.Status.OFFLINE
		if deleted != FirestoreDocuments.Status.OK:
			return AuthGateway.Status.UNKNOWN
	status = await _account.delete_account()
	if status == AuthGateway.Status.OK:
		_reset_device()
	return status


func _sync_now(progress: Progress) -> ProgressCloud.Result:
	if not _account.is_signed_in():
		return ProgressCloud.Result.NOT_SIGNED_IN
	_last_sync_at = _clock.call()
	return await _sync.sync(progress)


func _current_progress() -> Progress:
	return _session.progress if _session != null else _repository.load_progress()


func _reset_device() -> void:
	_repository.save_progress(Progress.fresh())


func _on_signed_in(_username: String) -> void:
	sync_device()


func _on_progress_changed() -> void:
	# A redraw asked by _on_merged is not a new purchase: syncing again would only repeat the pull.
	if not _refreshing:
		_sync_now(_session.progress)


func _on_run_ended(_score: int, _best_score: int, _coins_earned: int) -> void:
	if _clock.call() - _last_sync_at >= RUN_END_INTERVAL:
		_sync_now(_session.progress)


func _on_merged() -> void:
	if _session == null:
		return
	_refreshing = true
	_session.refresh_from_sync()
	_refreshing = false
