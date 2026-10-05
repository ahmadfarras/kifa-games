class_name ProgressSync
extends RefCounted

## Use case: sync Runner progress with the cloud save. Pulls the cloud save, merges it into the device's
## progress (Progress.absorb), saves the result on the device and pushes it back.
## The device is always written first, so a failed sync never loses progress; the next sync catches up.

signal finished(result: ProgressCloud.Result)
## The cloud save changed the device's progress (it was already saved on the device).
signal merged

var _repository: ProgressRepository
var _cloud: ProgressCloud
var _busy := false


func _init(repository: ProgressRepository, cloud: ProgressCloud) -> void:
	_repository = repository
	_cloud = cloud


## One sync runs at a time: a call made during another one waits for it to finish first.
func sync(progress: Progress) -> ProgressCloud.Result:
	while _busy:
		await finished
	_busy = true
	var result: ProgressCloud.Result = await _pull_merge_push(progress)
	_busy = false
	finished.emit(result)
	return result


func _pull_merge_push(progress: Progress) -> ProgressCloud.Result:
	var pull: ProgressCloud.Pull = await _cloud.pull()
	if pull.result != ProgressCloud.Result.OK:
		return pull.result
	if pull.progress != null:
		if progress.absorb(pull.progress):
			_repository.save_progress(progress)
			merged.emit()
		if progress.equals(pull.progress):
			return ProgressCloud.Result.OK
	return await _cloud.push(progress)
