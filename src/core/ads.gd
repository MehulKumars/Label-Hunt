## Every ad goes through here (autoload "Ads"). Rewarded ads only, always opt-in, capped by AdPolicy through
## Wallet. Playtest builds use the mock provider (a short stand-in that always grants); other builds have none
## until a real provider (AdMob, which needs the Gradle build and Mehul's accounts) plugs in behind these calls.
extends Node

const MOCK_SECONDS := 1.5

## "mock" or "none"
var provider := "mock" if Build.playtest() else "none"


func available() -> bool:
	return provider != "none"


## True if an ad for this placement may be offered right now (provider ready, under the caps, past the cooldown).
func rewarded_ready(placement: String) -> bool:
	return available() and Wallet.can_watch(placement)


## Plays a rewarded ad and returns whether the reward was earned. Await it.
func show_rewarded(placement: String) -> bool:
	if not rewarded_ready(placement):
		return false
	await get_tree().create_timer(MOCK_SECONDS).timeout
	Wallet.ad_watched(placement)
	return true
