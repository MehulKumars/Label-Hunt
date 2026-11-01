## What the Android Back button does, as a pure decision over the app's state, so every case is tested.
## ctx: {screen: "home"|"play"|"tutorial"|"levels"|"room"|"profile", sheet: ""|"utility"|"result"|"blocking",
##       lifted: bool, origin: where a room was opened from ("home" or "levels")}
class_name BackPolicy
extends RefCounted


static func decide(ctx: Dictionary) -> StringName:
	match str(ctx.get("sheet", "")):
		"utility":
			return &"close_sheet"   # pause, settings, rules, the Shop, the skip prompt: Back = ×
		"result":
			return &"home"          # Win and Lose need a choice; Back is the quiet way out
		"blocking":
			return &"ignore"        # an ad "playing"
	if ctx.get("lifted", false):
		return &"drop_card"
	match str(ctx.get("screen", "home")):
		"play":
			return &"pause"
		"tutorial":
			return &"skip_prompt"
		"home":
			return &"background"
		"room":
			return &"levels" if str(ctx.get("origin", "home")) == "levels" else &"home"
	return &"home"
