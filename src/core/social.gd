## Friends (autoload "Social"). Playtest builds show clearly marked sample friends so the profile can be judged;
## other builds hide the section until Google Play Games (Mehul's Play Console, Gradle build) plugs in here.
extends Node

## "mock" or "none"
var provider := "mock" if Build.playtest() and not OS.get_cmdline_user_args().has("--no-shop") else "none"

const SAMPLE := [
	{"name": "Asha", "level": 64, "avatar": "avocado"},
	{"name": "Leo", "level": 41, "avatar": "pepper"},
	{"name": "Mira", "level": 23, "avatar": "lemon"},
	{"name": "Tom", "level": 9, "avatar": "carrot"},
]


func available() -> bool:
	return provider != "none"


## [{name, level (game level reached), avatar}] — sample data in playtest builds.
func friends() -> Array:
	return SAMPLE if provider == "mock" else []
