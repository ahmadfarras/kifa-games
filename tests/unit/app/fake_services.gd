extends RefCounted

## The app's services built on in-memory fakes, for tests of the app layer: no network, no files.

const FakeAuthGateway := preload("res://tests/unit/account/fake_auth_gateway.gd")
const FakeAccountStore := preload("res://tests/unit/account/fake_account_store.gd")
const FakeProgressRepository := preload("res://tests/unit/games/runner/fake_progress_repository.gd")
const FakeProgressCloud := preload("res://tests/unit/games/runner/fake_progress_cloud.gd")
const FakeJsonHttp := preload("res://tests/unit/shared/fake_json_http.gd")

const USERNAME := "HappyCat27"
const PASSWORD := "password1"

var gateway := FakeAuthGateway.new()
var store := FakeAccountStore.new()
var repository := FakeProgressRepository.new()
var cloud := FakeProgressCloud.new()
## Only cloud save deletions go through here (the cloud save itself is the fake above).
var http := FakeJsonHttp.new()
var account: AccountService
var cloud_saves: CloudSaves
var now := 1000.0


func _init(signed_in := false) -> void:
	if signed_in:
		gateway.passwords[USERNAME.to_lower()] = PASSWORD
		store.stored = AccountSession.new("uidhappycat27", USERNAME, "refresh-happycat27-0")
	account = AccountService.new(gateway, store, clock)
	var documents := FirestoreDocuments.new(http, "test-project", account.id_token, account.uid)
	cloud_saves = CloudSaves.new(account, repository, ProgressSync.new(repository, cloud), documents, clock)


func clock() -> float:
	return now
