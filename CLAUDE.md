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

## Gotchas
- Godot's JSON parser returns every number as a float. Cast to int when loading save data or levels.
- Headless Godot renders nothing. Screenshots need a windowed run (`tools/shots.gd`).
- PowerShell 5.1 has no `&&` and drops quotes on native arguments. Use Git Bash for those.
- `godot --doctool <dir>` dumps the exact 4.7.2 API. Use it before trusting your memory of an API.
