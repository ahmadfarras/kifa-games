extends GutTest


class FakeProgressRepository:
	extends ProgressRepository

	var stored := Progress.fresh()

	func load_progress() -> Progress:
		return stored

	func save_progress(progress: Progress) -> void:
		stored = progress


func test_fake_implements_port() -> void:
	var repository: ProgressRepository = FakeProgressRepository.new()
	var progress := Progress.fresh()

	repository.save_progress(progress)

	assert_eq(repository.load_progress(), progress)
