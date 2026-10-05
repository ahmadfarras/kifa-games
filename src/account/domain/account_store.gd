@abstract
class_name AccountStore
extends RefCounted

## Port: where the logged-in session is kept between app launches.


## Returns null when nobody is logged in on this device (guest).
@abstract func load_session() -> AccountSession


@abstract func save_session(session: AccountSession) -> void


@abstract func clear() -> void
