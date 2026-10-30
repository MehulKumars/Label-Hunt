# Credits and licenses

Every third-party asset and tool that ships in Jarful, or that is used to build it, is listed below with its
license. The same list will appear in-game under Settings → Credits (added in M2).

## Code and tools
| What | Source | License |
|---|---|---|
| Godot Engine 4.7.2 | https://godotengine.org | MIT |
| GUT 9.7.1 (tests only; not in exports) | https://github.com/bitwes/Gut | MIT |

## Fonts
| Font | Used for | Source | License |
|---|---|---|---|
| Atkinson Hyperlegible Next (variable) | Cards, buttons, body text | https://github.com/googlefonts/atkinson-hyperlegible-next (via Google Fonts) | SIL Open Font License 1.1 (`assets/fonts/OFL-AtkinsonHyperlegibleNext.txt`) |
| Gochi Hand | Solved labels, the wordmark, celebration lines | https://github.com/google/fonts/tree/main/ofl/gochihand (Huerta Tipográfica) | SIL Open Font License 1.1 (`assets/fonts/OFL-GochiHand.txt`) |

## Audio
All current sound effects are synthesised for this game with ffmpeg by `tools/make_sfx.sh` (sine partials, filtered
noise, envelopes). No third-party audio is used yet. Recorded foley from Mehul will replace some of them later.

## Art
All art is original and made for this game: jars, cards, lids, corks, shelves, labels, the cabinet, the hand pointer,
the jar-plus icon and the app icon. They are built as SVG in code (`src/ui/art/materials.gd`) or written as SVG
(`assets/icon/*.svg`, `assets/icons/jar-plus.svg`).

| Icons | Source | License |
|---|---|---|
| Phosphor Icons 2.1.1 (bold and fill weights): pause, play, undo, eye, magic wand, gear, question, house, x and others in `assets/icons/` | https://github.com/phosphor-icons/core | MIT (`assets/icons/LICENSE-phosphor.txt`) |
