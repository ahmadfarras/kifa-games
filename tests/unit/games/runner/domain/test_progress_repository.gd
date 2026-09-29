extends GutTest

const FakeProgressRepository := preload("res://tests/unit/games/runner/fake_progress_repository.gd")


func test_fake_implements_port() -> void:
	var repository: ProgressRepository = FakeProgressRepository.new()
	var progress := Progress.fresh()

	repository.save_progress(progress)

	assert_eq(repository.load_progress(), progress)
