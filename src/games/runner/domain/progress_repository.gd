@abstract
class_name ProgressRepository
extends RefCounted

## Port: where Runner progress is kept between app launches.


@abstract func load_progress() -> Progress


@abstract func save_progress(progress: Progress) -> void
