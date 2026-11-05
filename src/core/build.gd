## Build flavour checks shared by autoloads and screens.
class_name Build
extends RefCounted


## Debug runs and playtest APKs (export preset feature "playtest") show the test menu and use mock providers.
static func playtest() -> bool:
	return OS.is_debug_build() or OS.has_feature("playtest")


## True when something can be bought or watched: the Shop, diamonds and every diamond price appear only then. The
## Play testing build has no providers until real Billing and AdMob plug in, so it shows none of them.
static func shop_open() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var store := tree.root.get_node_or_null("Store")
	var ads := tree.root.get_node_or_null("Ads")
	return (store != null and store.available()) or (ads != null and ads.available())
