## What the Android Back button does, as a pure decision over the app's state, so every case is tested.
## ctx: {screen: "home"|"play"|"tutorial"|"room", sheet: ""|"utility"|"result"|"blocking", lifted: bool}
class_name BackPolicy
extends RefCounted


static func decide(ctx: Dictionary) -> StringName:
	match str(ctx.get("sheet", "")):
		"utility":
			return &"close_sheet"   # pause, settings, rules, the skip prompt: Back = ×
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
	return &"home"
