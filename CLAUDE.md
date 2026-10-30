# Jarful: notes for future sessions

Game 3 for Mehul: a word ball-sort puzzle, built with Godot 4.7.2 and GDScript, Android first, portrait.

- **Design:** `docs/DESIGN.md`. The full approved plan was written outside the repo; the design doc is the source
  of truth.
- **Repo:** `MehulKumars/jarful` (private).
- **Package:** `com.mehulkumars.jarful`. The final name is Mehul's call before any Play upload.

## Commands (Git Bash; `godot.cmd` wraps Godot 4.7.2)

| Task | Command |
|---|---|
| Import (after adding a `class_name`) | `godot.cmd --headless --path . --import` |
| Rebuild `main.tscn` | `godot.cmd --headless --path . -s res://tools/make_scenes.gd` |
| Tests (GUT 9.7.1) | `godot.cmd --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json` |
| Run the game | `godot.cmd --path .` |
| Check hand-made levels (deal seeded boards, unique cover, solvable) | `godot.cmd --headless --path . -s res://tools/check_levels.gd` |
| Bot sims + bake benchmark → `reports/sim_*.md/csv` | `godot.cmd --headless --path . -s res://tools/sim.gd -- --n=200` |
| Trace one bot game | `godot.cmd --headless --path . -s res://tools/trace_bot.gd -- --level=m01 --profile=average --seed=1` |
| Screenshots (needs a window) | `godot.cmd --path . -- --shots=shots/m1 --size=1080x2400 [--only=t01,win] [--safe=60,40]` |
| App icons from SVG | `godot.cmd --headless --path . -s res://tools/make_icons.gd` |
| Placeholder SFX | `bash tools/make_sfx.sh` |
| Test APK (arm64, release template, debug key) | set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH=C:/Users/lordi/AppData/Roaming/Godot/keystores/debug.keystore`, `_USER=androiddebugkey`, `_PASSWORD=android`, then `godot.cmd --headless --path . --export-release "Android" build/jarful-X.Y.Z-arm64.apk` |

## Decisions (facts, not rules)
- **No Python or Node on this machine.** All tooling is headless GDScript in `tools/`.
- **UI is built in code.** Godot saves the only scene (`main.tscn`) via `tools/make_scenes.gd`. Never hand-write
  `.tscn` files or `uid://` values.
- **Code layout:**
  - `src/rules` and `src/gen` are pure: no autoloads, so tools and tests can use them.
  - `src/gen` is excluded from the export.
  - `src/daily` must stay game-agnostic, with no Jarful imports.
- **Levels** are baked offline into `data/levels/*.json`. The runtime never generates shipped levels.
- **Off limits:** don't read or copy `../godot-mobile-template`, `../halves` or `../sushi-loop`. Leave every
  other folder in `GameDev` untouched.

- **Bot:** about 5 ms per game. A full bake (515 levels) is about 28 min on one process, about 5 min on 6.
  Post-aha busywork on 5-group boards runs 5–18 moves, above the ≤8 target. Tidy up only appears when the
  board *proves* every group, which is rare.
- **Sounds:** `kenney.nl` blocks scripted downloads, so the placeholder SFX are synthesised. Kenney packs must be
  downloaded by hand.

## Gotchas
- `class_name Popup` clashes with the built-in Popup class. Our popup base is `Sheet`.
- Tweens created on BoardView outlive cards from the previous level. Card flights use `cv.create_tween()`, and
  board tweens go through `_track()`, which kills them on `setup()`.
- A label with autowrap has no valid minimum height until it has a width. `Sheet` sizes itself again one frame
  after it opens.
- Windows lets `DisplayServer.window_set_size()` go larger than the screen, so screenshots come out at true sizes
  such as 1080×2400.
- Godot's JSON parser returns every number as a float. Cast to int when loading save data or levels.
- Headless Godot renders nothing. Screenshots need a windowed run (`tools/shots.gd`).
- PowerShell 5.1 has no `&&` and drops quotes on native arguments. Use Git Bash for those.
- `godot --doctool <dir>` dumps the exact 4.7.2 API. Use it before trusting your memory of an API.
