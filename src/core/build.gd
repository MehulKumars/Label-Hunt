## Build flavour checks shared by autoloads and screens.
class_name Build
extends RefCounted


## Debug runs and playtest APKs (export preset feature "playtest") show the test menu and use mock providers.
## `--store-build` on a debug run behaves like the Google Play build instead (no mocks, no Shop, no test menu), to
## preview it and to take store screenshots.
static func playtest() -> bool:
	return (OS.is_debug_build() or OS.has_feature("playtest")) and not OS.get_cmdline_user_args().has("--store-build")


## True when something can be bought or watched: the Shop, diamonds and every diamond price appear only then. The
## Play testing build has no providers until real Billing and AdMob plug in, so it shows none of them.
static func shop_open() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var store := tree.root.get_node_or_null("Store")
	var ads := tree.root.get_node_or_null("Ads")
	return (store != null and store.available()) or (ads != null and ads.available())
