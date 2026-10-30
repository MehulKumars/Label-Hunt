---
paths: ["**/*.gd", "**/*.svg", "**/*.json", "**/*.csv", "assets/**", "docs/**"]
---
Jarful is a portrait mobile game played with thumbs, not a website.
- Before committing a value that encodes a design decision (a number, curve, rule, reward, layout or flow), load the
  `game-design` skill and reason from it.
- Before changing how something looks, load `frontend-design`.
- Before changing how something animates, sounds or vibrates, load `game-feel` (and `tween-animation` for tween code).
- For Control layout or theme code, load `godot-ui-control`.
- Then check the result in a phone-sized screenshot (`tools/shots`), never by assumption.
