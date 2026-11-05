# Jarful: notes for future sessions

Game 3 for Mehul: a word ball-sort puzzle, built with Godot 4.7.2 and GDScript, Android first, portrait.

- **Design:** `docs/DESIGN.md`. The full approved plan was written outside the repo; the design doc is the source
  of truth.
- **Repo:** `MehulKumars/jarful` (private).
- **Package:** `com.mehulkumars.jarful`. The final name is Mehul's call before any Play upload.

## Skills: use them without being asked
Mehul wants these consulted automatically, every session (they live in `.claude/skills/`). Load the skill **before**
deciding, even mid-code. Jarful is a **mobile game** (portrait phone, thumbs, touch, haptics, Back button), not a
website: translate any web-flavoured advice (hover, cursor, page scroll, breakpoints) into phone terms.

| Work | Skill |
|---|---|
| Any design decision: rules, difficulty, progression, rewards, onboarding, menus, HUD, flow, "is it fun" | `game-design` |
| The look: art direction, colour, type, layout, style frames, critiquing screenshots | `frontend-design` |
| Feedback and juice: animation, easing, event sounds, haptics | `game-feel` |
| Godot Control layout, themes, containers | `godot-ui-control` |
| Tweens and motion code | `tween-animation` |

Never run `/game-design wire`: it edits settings and adds a Node hook, and there's no Node here.

## Commands (Git Bash; `godot.cmd` wraps Godot 4.7.2)

**On the Linux machine (Fedora):** type `godot` (the system 4.7.2 package) wherever a command says `godot.cmd`. Export
templates, the Android SDK (`~/Android/Sdk`) and JDK 17 (`~/.local/opt/jdk-17`) are already set in the editor
settings. The release keystore for test APKs is `~/.local/share/godot/keystores/debug.keystore`. That key is not the
Windows one, so an APK built here can't update an install built on Windows: uninstall first, or copy the Windows
keystore over.

| Task | Command |
|---|---|
| Import (after adding a `class_name`) | `godot.cmd --headless --path . --import` |
| Rebuild `main.tscn` | `godot.cmd --headless --path . -s res://tools/make_scenes.gd` |
| Tests (GUT 9.7.1) | `godot.cmd --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json` |
| Run the game (desktop window = a 20:9 phone fitted to the monitor) | `godot.cmd --path . [-- --phone=1080x2520]` |

| Check a level file (deal seeded boards, unique cover, solvable, no pre-built pairs) | `godot.cmd --headless --path . -s res://tools/check_levels.gd -- --file=res://data/levels/room2.json` |
| Room specs from the difficulty curve (`data/rooms/curve.json`) → `data/rooms/roomN_spec.json` | `godot.cmd --headless --path . -s res://tools/make_specs.gd` |
| Pick categories for rooms (global reuse ledger; `--dry` = shortfall report only) → `data/rooms/picks/`, `reports/pick.md` | `godot.cmd --headless --path . -s res://tools/room_gen.gd -- --pick --rooms=1,3-17 [--dry] [--only=1,2]` |
| Deal, measure and budget one room (run several at once) → `data/levels/roomN.json`, `index.json`, report | `godot.cmd --headless --path . -s res://tools/room_gen.gd -- --settle --room=3 [--only=1,2]` |
| Re-settle budgets and gold of baked levels | `godot.cmd --headless --path . -s res://tools/room_gen.gd -- --rebudget --room=2 --levels=1-10` |
| Merge bank drafts (`data/bank/drafts/*.txt`), then lint the bank → `reports/bank_merge.md`, `reports/lint_bank.md` | `-s res://tools/merge_bank.gd [-- --dry]`, then `-s res://tools/lint_bank.gd` |
| Re-check every baked level against the bank (phantoms, clashes, cover, a Hint-only walk) → `reports/audit_content.md` | `godot.cmd --headless --path . -s res://tools/audit_content.gd [-- --rooms=1-3 --no-hints]` |
| Difficulty curve over all levels: floors missed and levels out of shape (a hard level under its room's normal, a slip limit above 8) → `reports/curve.md` | `godot.cmd --headless --path . -s res://tools/curve_report.gd` |
| Star rates by room (average bot under each budget; slip histograms, so `--merge` re-checks new offsets without replaying) → `reports/stars.md/csv` (economy_sim reads the csv) | `godot.cmd --headless --path . -s res://tools/star_report.gd -- --n=60 --rooms=1-8` (several at once), then `-- --merge` |
| Coin economy over all levels (free, ad and one-purchase players) → `reports/economy.md` | `godot.cmd --headless --path . -s res://tools/economy_sim.gd` |
| Bot sims + bake benchmark → `reports/sim_*.md/csv` | `godot.cmd --headless --path . -s res://tools/sim.gd -- --n=200` |
| Trace one bot game | `godot.cmd --headless --path . -s res://tools/trace_bot.gd -- --level=l1-01 --profile=average --seed=1` |
| Screenshots (needs a window; fitted to the monitor, same layout as the phone) | `godot.cmd --path . -- --shots=shots/m1 --size=1080x2400 [--only=home,win] [--safe=60,40] [--true-size]` |
| Record video + audio of a scenario (Movie Maker), then a contact sheet | `godot.cmd --path . --write-movie shots/movie/win.avi --fixed-fps 60 -- --shots=shots/movie --only=win --with-audio` |
| Material art preview PNG (headless) / type lab (window) | `-s res://tools/art_preview.gd` / `-s res://tools/type_lab.gd -- --fonts=<dir>` |
| App icons from SVG | `godot.cmd --headless --path . -s res://tools/make_icons.gd` |
| Sounds from the CC0 packs (sources in CREDITS.md) | `bash tools/import_sfx.sh <folder of unzipped packs>` |
| Test APK (arm64, release template, debug key) | set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH=C:/Users/lordi/AppData/Roaming/Godot/keystores/debug.keystore`, `_USER=androiddebugkey`, `_PASSWORD=android`, then `godot.cmd --headless --path . --export-release "Android" build/jarful-X.Y.Z-arm64.apk` |
| Audit an APK (permissions, debuggable, files that must not ship) | `bash tools/audit_apk.sh build/jarful-X.Y.Z-arm64.apk` |

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

- **Bot:** about 5 ms per game on small boards. Baking is slower on late rooms: rooms 11-17 (210 levels, 5-6 groups) took about 18 min on 6 processes.
  Post-aha busywork on 5-group boards runs 5–18 moves, above the ≤8 target. Tidy up only appears when the
  board *proves* every group, which is rare.
- **Stars and diamonds** (v0.5): stars count slips only; limits = each level's baked `gold` + `Economy.STAR_OFFSETS` by room, capped below the budget. Coins are per star (`STAR_COIN_RATES` by room) and never sold; diamonds are bought or from the shop ad. Tune offsets against `tools/star_report.gd` bands, coin rates against `tools/economy_sim.gd` gates.
- **The Shop switch:** `Build.shop_open()` (a store or ad provider is available) shows the Shop, the diamond pill and every diamond price. The Play testing build has no providers, so it shows coins only. `--no-shop` on a debug run previews that.
- **Sounds:** real CC0 effects (Kenney and others, listed in CREDITS.md), imported by `tools/import_sfx.sh` from packs
  downloaded by hand (`kenney.nl` blocks scripted downloads). Only `frost.wav` is still synthesised (`tools/make_sfx.sh`).

## Gotchas
- `class_name Popup` clashes with the built-in Popup class. Our popup base is `Sheet`.
- Tweens created on BoardView outlive cards from the previous level. Card flights use `cv.create_tween()`, and
  board tweens go through `_track()`, which kills them on `setup()`.
- A label with autowrap has no valid minimum height until it has a width. `Sheet` sizes itself again one frame
  after it opens.
- Desktop runs go through `PhoneWindow`: the window keeps the phone's aspect but is scaled to 88% of the monitor's
  height (Mehul's is 2560×1440). Layout depends only on the aspect. `--true-size` gives real pixels but overflows the screen.
- Godot's JSON parser returns every number as a float. Cast to int when loading save data or levels.
- Headless Godot renders nothing. Screenshots need a windowed run (`tools/shots.gd`).
- PowerShell 5.1 has no `&&` and drops quotes on native arguments. Use Git Bash for those.
- `godot --doctool <dir>` dumps the exact 4.7.2 API. Use it before trusting your memory of an API.
- Godot imports any `.csv` as a translation table (and makes `.translation` files that would ship). The bank is
  `data/bank/categories.txt` in CSV format for that reason. `reports/` and `docs/screenshots/` carry a `.gdignore`,
  so Godot skips them (tools still write there with `FileAccess`).
- JSON numbers are floats, and `[1.0].has(1)` is false: cast before `has`, `find` or `erase` (bit the room spec).
- A SceneTree tool script can't define `_finalize()`: it's a MainLoop virtual.
- Material art is SVG built in code (`src/ui/art/materials.gd`) and rasterised at device scale by `Art`; nothing
  imports it. Icons are raw Phosphor SVGs, shipped as text via the export `include_filter`.
- Screenshot runs use their own fresh save (`user://shots_save.json`) and mute audio unless `--with-audio`.
- Level ids are stable and opaque: `r1-NN` is the v0.2 room, now Room 2 ("The Kitchen"); new levels are `l<room>-NN`.
  Never reuse an id for different content (saves and playtest logs key on it).
- `Levels` loads the files listed in `data/levels/index.json` (room_gen rewrites it). A new level file must be listed.
- A var named `ready` on a Control clashes with Node's `ready` signal ("could not resolve external class member").
- A Session's `log` replays the attempt (`Session.replay`); every rule that changes an attempt must append to it.
- Room looks live in `src/ui/art/themes.gd`; RoomArt textures must put the room in their `Art.tex` key.
- Prices, rewards, XP and the gift ladder are one table: `src/rules/economy.gd`. The Wallet autoload writes at once.
- `data/bank/wordplay_targets.txt` holds the rule of each checkable wordplay category (`hidden`, `anagram`, `palindrome`, `reverse`, `y_only`, `double2`, `roman`; see `Bank.trips`). A test checks every member obeys its own rule.
- `data/bank/hard_words.txt` lists rare vocabulary. Spec levels marked `familiar` (Rooms 1 and 3, the two re-made Kitchen levels, every rest level) leave those words out.
- GUT and headless tool runs boot the autoloads, so they load (and can migrate) the real desktop save in `user://save.json`.
- A runtime error inside a tool's `_init` skips `quit()`, so Godot hangs forever with no output when piped. Run tools with `timeout` and write the output to a file.
