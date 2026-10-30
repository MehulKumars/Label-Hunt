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

Sound effects and music are CC0 (public domain) recordings from OpenGameArt, trimmed, faded and
peak-normalised by `tools/import_sfx.sh`. Each licence was checked on the download page (and in the zip where
there was one). Only `frost.wav` is still synthesised for this game by `tools/make_sfx.sh`.

| Used as | Source | Author | Licence |
|---|---|---|---|
| Card lift, card place | https://opengameart.org/content/54-casino-sound-effects-cards-dice-chips | Kenney | CC0 |
| Glass drop clinks, refusal tock, pencil tick, UI tap, screen whoosh | https://opengameart.org/content/interface-sounds | Kenney | CC0 |
| Jar onto shelf | https://opengameart.org/content/50-rpg-sound-effects | Kenney | CC0 |
| Win jingle | https://opengameart.org/content/85-short-music-jingles | Kenney | CC0 |
| Glass clink (variant) | https://opengameart.org/content/100-cc0-sfx-2 | rubberduck | CC0 |
| Slip knocks | https://opengameart.org/content/100-cc0-metal-and-wood-sfx, https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx | rubberduck | CC0 |
| Lid seat | https://opengameart.org/content/glass-bottle-open-close | sinny | CC0 |
| Label writing (pencil) | https://opengameart.org/content/pencil-sounds | AntumDeluge | CC0 |
| Pair chime | https://opengameart.org/content/4-metal-dingsrings | StarNinjas | CC0 |
| Lid ratchet | https://opengameart.org/content/mechanical-sounds | BMacZero | CC0 |
| Gold-lid bell | https://opengameart.org/content/bell-dingschimes | PWL | CC0 |
| Music: "Catmint" | https://opengameart.org/content/catmint | Music by Kistol | CC0 |

## Art
All art is original and made for this game: jars, cards, lids, corks, shelves, labels, the cabinet, the hand pointer,
the jar-plus icon and the app icon. They are built as SVG in code (`src/ui/art/materials.gd`) or written as SVG
(`assets/icon/*.svg`, `assets/icons/jar-plus.svg`).

| Icons | Source | License |
|---|---|---|
| Phosphor Icons 2.1.1 (bold and fill weights): pause, play, undo, eye, magic wand, gear, question, house, x and others in `assets/icons/` | https://github.com/phosphor-icons/core | MIT (`assets/icons/LICENSE-phosphor.txt`) |
