## How a group's label reads at each reveal step.
## 0: nothing; 1: context words + key word as blanks; 2: key word's first letter; 3: the full label.
class_name LabelText
extends RefCounted

const BLANK := "_"


static func at_step(label: String, key: String, step: int) -> String:
	if step <= 0:
		return ""
	if step >= Knowledge.FULL_STEP:
		return label
	var at := label.findn(key)
	if at < 0:
		return label
	var masked := ""
	for i in key.length():
		var ch := key[i]
		if ch == " ":
			masked += "  "
		elif step >= 2 and i == 0:
			masked += ch
		else:
			masked += BLANK
		if i < key.length() - 1 and ch != " ":
			masked += " "
	return label.substr(0, at) + masked + label.substr(at + key.length())


## Lint helper: true if the key word appears in its label.
static func key_in_label(label: String, key: String) -> bool:
	return label.findn(key) >= 0
