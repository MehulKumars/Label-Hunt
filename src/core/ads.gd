## Every ad goes through here (autoload "Ads"). M2 ships only the mock provider, a short stand-in that always
## grants. A real provider (AdMob, which needs the Gradle build and Mehul's accounts) plugs in behind these calls.
extends Node

const MOCK_SECONDS := 1.5

## "mock" or "none"
var provider := "mock"


func rewarded_ready(_placement: String) -> bool:
	return provider == "mock"


## Plays a rewarded ad and returns whether the reward was earned. Await it.
func show_rewarded(placement: String) -> bool:
	if not rewarded_ready(placement):
		return false
	await get_tree().create_timer(MOCK_SECONDS).timeout
	return true
