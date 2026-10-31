## Build flavour checks shared by autoloads and screens.
class_name Build
extends RefCounted


## Debug runs and playtest APKs (export preset feature "playtest") show the test menu and use mock providers.
static func playtest() -> bool:
	return OS.is_debug_build() or OS.has_feature("playtest")
