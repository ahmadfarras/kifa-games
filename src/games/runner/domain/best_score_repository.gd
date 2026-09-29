@abstract
class_name BestScoreRepository
extends RefCounted

## Port: where the best score is kept between app launches.


@abstract func load_best() -> int


@abstract func save_best(score: int) -> void
