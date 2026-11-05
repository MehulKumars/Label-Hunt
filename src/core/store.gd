## Diamond packs (autoload "Store"). Playtest builds use a mock store that grants after a short pause; other builds
## have none until Play Billing (Gradle build, Mehul's Play Console) plugs in behind these calls, so the Shop stays
## hidden there (Build.shop_open). Every purchase is recorded by token, so a real provider can acknowledge and restore
## without a save change. `--no-shop` on the command line forces "none" (to see the Play build's screens).
extends Node

const MOCK_SECONDS := 1.0

## "mock" or "none"
var provider := "mock" if Build.playtest() and not OS.get_cmdline_user_args().has("--no-shop") else "none"


func available() -> bool:
	return provider != "none"


func products() -> Array:
	return Economy.PACKS if available() else []


## The price to show. The mock shows the USD base; a real store returns the localised price.
func price_text(id: String) -> String:
	var p := Economy.pack(id)
	return "$" + str(p.get("usd", "?"))


## Buys a pack and grants its diamonds. Await it; false if it failed or was cancelled.
func purchase(id: String) -> bool:
	var p := Economy.pack(id)
	if p.is_empty() or not available():
		return false
	await get_tree().create_timer(MOCK_SECONDS).timeout
	var tokens: Array = Save.data["purchases"]["tokens"]
	tokens.append("%s:%s:%d" % [provider, id, Time.get_unix_time_from_system()])
	if tokens.size() > SaveSchema.MAX_TOKENS:
		tokens.pop_front()
	Wallet.grant({"diamonds": int(p["diamonds"])})
	return true
