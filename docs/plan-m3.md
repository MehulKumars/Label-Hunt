# Jarful M3 plan: coins, hints, 510 levels, rooms, profile and streaks (draft 2, reviewed)

## Context
Mehul played v0.2.0-alpha and asked for the full meta layer and real content scale (2026-10-31):
- **Coins** earned by playing and optional ads (also buyable). They're spent on a cheap **Hint** (shows the next
  move) and on a very costly booster that **completes a category** chosen from the labels.
- **About 500 levels:**
  - L1–30: a new *medium* start that still rises;
  - L31–60: the current 30 levels;
  - then a long medium-to-hard stretch;
  - the last ~100 *very hard*;
  - later, up to ~700 *super hard*.
- **Streak and daily coins**, with a bonus for keeping the streak.
- **A fuller Home:** a Levels button and a map in 30-level chunks, plus a **profile** with player level, XP and
  friends' levels.
- **Rooms:** a different background and jar style per 30-level room. Good from the first 100 levels, richer later.
- **Keep:** the current gameplay, interaction and music.
- **A sound economy** for ads and coin prices.

**Mehul's answers (2026-10-31):**
- Ads, purchases and friends use **mock providers now**. Real AdMob, Play Billing and Play Games come when he sets
  up the Play Console.
- The currency is **coins**.
- **Optional ads only**: no forced between-level ads.
- **Peek folds into Hint.**
- **The daily gift opens after the day's first win.**

Also folded in: his level 4 feedback (Map and Lock are weak "Things with keys" members).

**Review.** An independent review checked draft 1 against the code. Its findings are fixed below:
- Complete broke Solver, Tidy and stuck detection.
- The bank couldn't cover 510 levels.
- The bake estimate was 3–5× too low.
- Special jars weren't in the generator.
- Hint leaked labels.
- The migration reset players.
- Economy and UX gaps.

The original plan is condensed in `docs/DESIGN.md`, and M2 is in `docs/plan-m2.md`. This plan supersedes DESIGN's
150-level chapter table and its coin section. It also replaces M2's "no login calendars" rule with a humane play
streak (§4), because Mehul asked for streaks. The "Jar of the Day" daily puzzle stays deferred; when it comes, a
daily win counts toward the same streak.

## 1. Design stance (game-design skill)
- **The core dialectic stays "guess or know".** Boosters add a third answer, "pay to know", and must never replace
  the aha:
  - Hint and Complete withhold the gold lid, and so does Continue (as today);
  - levels are tuned with booster-free bots, and difficulty is never tuned to sell boosters;
  - Retry is free and unlimited, with no energy, lives or timers.
- **Current free play is unchanged.** +Jar stays free once per level and Undo stays free. The stuck caption
  ("Undo or +Jar") never becomes an upsell.
- **Hoarder trap** (consumables nobody uses): Hints are cheap, and each booster arrives with free samples when it's
  introduced.
- **Treadmill check on XP.** Player level shows mastery and unlocks visible things (avatars, titles), and XP weighs
  hard levels and gold lids. Mastery itself pays in pride and XP, never coins (M2 §10's guardrail).
- **Ethics line:**
  - no loot boxes or random paid rewards; the gift ladder is fixed and shown in advance;
  - no offer timers or fake urgency;
  - no push notifications;
  - the lose sheet offers only Continue (ad, or coins if you already have them) and never links to the Shop;
  - largest coin pack $19.99;
  - streak copy never guilt-trips, and a missed day resets only the gift ladder;
  - prices come from Play.
- **Subtract.** The bar becomes Undo, Hint, +Jar and Complete, plus Tidy when it appears.

## 2. Boosters
| Booster | What it does | Cost | Limits |
|---|---|---|---|
| Undo | as now; back to the last lid or seal | free | none |
| **Hint** (lightbulb) | The right card glows and the hand shows where it goes. Tags **only the moved card**, so the label advances at most one step. Following the move builds the pair as normal. | 50 coins | Charged only when a move is shown and the board hasn't changed since it was computed |
| +Jar | as now | free | 1 per level, 9 jars at most (unchanged) |
| **Complete** (new jar-seal icon in the jar-plus style; Tidy keeps the magic wand) | Tap → a bottom **picker sheet** shows the unsolved labels exactly as the rail shows them, mirrored by glowing rail tags, with no new information. Pick one → "Fill this jar · 250" → its 4 cards lift out of their jars (buried ones too), fly up into the rail tag, and the tag seals with the full label. | 250 coins | Two-step confirm; Back or an outside tap cancels for free. The board ignores input while the picker is open. |
| Continue (lose sheet) | +2 slips | an optional ad, or 150 coins if you already have them | once per try |

- **Inventory first.** Gifted boosters show a count badge; at 0 the badge shows the coin price.
- **Not enough coins** (from Hint or Complete during play) opens a sheet with:
  - "Watch an ad for a free hint" (Hint only, 3 a day);
  - "Get coins" (Shop).
  It never opens from the lose sheet.
- **Mercy rule:** after 2 fails, the next try gets +1 slip and a free Hint (this replaces the free Peek). Gold is
  withheld, as now.
- **Peek leftovers to remove:**
  - the rules text (main.gd:382);
  - the intro caption (play_screen.gd:209);
  - the test-track features (catalog.gd:102);
  - `Session.peek`, which becomes `Session.hint`.

### Rules changes (`src/rules`, pure)
- **`BoardState`:**
  - new `sealed: PackedByteArray`, filled in `from_level` and copied in `copy()`;
  - `sealed_count()`;
  - `is_won()` becomes `lid_count() + sealed_count() >= group_count`.
- **`Session.complete(g)`:**
  - remove cards 4g..4g+3 from any jar (`remove_at`) and set `sealed[g]`;
  - knowledge: union the cards, tag them, set `step[g] = FULL_STEP`, mark frosted cards seen;
  - `history.clear()` (a seal is an undo barrier);
  - uncork all jars, as a lid does;
  - mark the newly exposed tops seen;
  - emit a `seal` event `{group, cards[{card, jar, index}]}`, then `won`.
- **`Session.hint(card)`:** tag the card through `_reveal`, which advances one step at most, and count it in
  `hints`.
- **`Solver`:**
  - goal is `groups = group_count - sealed_count()` (solver.gd:69, :26);
  - keys become compact byte-packed strings instead of hex (solver.gd:153–166);
  - add an optional time budget and a cancel flag.
- **`Session.all_known()`** subtracts sealed groups (session.gd:177).
- **`Knowledge.proven_not_in`** (knowledge.gd:110) returns true when the class tagged g already holds 4 cards and
  c isn't one of them. This fixes free refusals and `is_stuck` for labelled jars of lidded or sealed groups, which
  is a latent bug today.
- **Rail "unsolved"** means not lidded and not sealed. It is not `step`, because labelled groups start at
  `FULL_STEP`.
- **Bot** (src/gen): handles sealed groups, treats unseen frosted cards as unknown (today it reads them), and gets
  a tier-4 knowledge rate per profile (today it clamps tier 4 to 3, bot.gd:98).
- **Action log and exact resume.** This was M2 §16.7 and becomes necessary now that coins are spent mid-level:
  - Session records `{move | undo | hint | jar | complete | continue}`;
  - the save keeps `{id, fingerprint, log}`;
  - resume replays the log through Session;
  - a changed fingerprint drops the board but keeps progress;
  - every grant or spend forces an immediate `Save.write()`.
- **`src/rules/advisor.gd`** picks the next move from the hidden truth:
  1. a move that finishes a lid;
  2. a move onto a jar holding only that card's group (no search needed);
  3. `Solver` at weight 3, within a time budget (about 150 ms on the worker), returning `path[0]`;
  4. otherwise "Undo a few moves" and pulse Undo, with no charge.

  The path is cached while the player follows it, and the next hint is computed in the background when the board
  goes idle. `hit_cap` counts as "unknown", never as "unsolvable".
- **Threading** (play_screen):
  - the Advisor runs on `WorkerThreadPool` with a `BoardState.copy()`;
  - results are dropped if the board fingerprint changed;
  - every task is awaited with `wait_for_task_completion` and cancelled on leave;
  - Tidy uses the same worker.
- **Bug fix:** the board ignores taps while Tidy autoplays (board_view.gd:272 today only checks `is_over`).

### UI
- **`LabelRail`:**
  - `tag_rect(g)` for flight targets and glow;
  - the sealed look: full label plus a small lidded-jar glyph.
- **`BoardView.show_seal(ev)`:**
  - cards lift and fly via `_fly`/`_bezier` to the tag;
  - they shrink and fade;
  - `sync(true)` settles the cards left behind;
  - ratchet, seat, and the lid haptic.
- **Play HUD:** pause | title | coin pill. The slip meter sits under the title, and its mini jars shrink when the
  budget is 8 or more (the width today is budget × 44).
- **Bar:** layout checked at 720 wide with 5 buttons.

## 3. Economy (one currency: coins; numbers in one table in `src/rules/economy.gd`)
**Earning**
| Source | Coins |
|---|---|
| First solve | 10 + 4 per group above 2 (10–26); tricky +4, hard +8 |
| ×2 win coins | optional ad, as a chip in the Win card's coin row |
| Daily gift (§4) | 20, 25, 30, 40, 50, 60, then 100 + 1 Complete on day 7; repeats |
| Free coins (Shop) | +25 per optional ad, 5 a day |
| Player level-up (§5) | 20; every 5th level +2 Hints and an avatar |
| Room complete | 150, plus the room reveal |
| Streak milestones | 7 days: a streak saver; 30 days: 400 + avatar; 100 days: 800 + avatar |

- **No coins** for gold lids or replays; gold gives XP.
- **Starters:** 150 coins after the tutorial; 3 Hints at L6; 1 Complete at L16.
- **Migrating players** get the starters plus back-dated XP.

**Optional ads**
- At most 12 a day, at least 30 s apart.
- Caps by placement: shop coins 5, free hint 3, gift ×2 once, Continue once per try, win ×2 within the total.
- No interstitials; the unused `INTERSTITIALS` flag is removed.

**Coin packs** (USD base; Play sets local prices such as ₹)
| Pack | Price |
|---|---|
| 500 | $0.99 |
| 1,200 | $1.99 |
| 3,500 | $4.99 |
| 8,000 | $9.99 |
| 18,000 | $19.99 |

The starter bundle waits for real billing.

**`tools/economy_sim.gd`** uses the bot's slips and stuck moments over all 510 levels, plus 10 levels a day. It
models three players: "never pays, no ads", "ads when stuck" and "spends $0.99 once".
- **Gates:**
  - a free player can afford a Hint on at least 1 level in 3;
  - nobody needs coins to win;
  - the ad player is never below a Hint's price for more than 3 levels in a row;
  - the median balance of a Hint-using player stays between 100 and 2,000 throughout (no runaway inflation).
- If a gate fails, tune the table, not the levels.

## 4. Play streak and daily gift
- **Streak:**
  - a day counts once you win any level that day; replays count;
  - Home shows a flame and the count;
  - the best streak is kept.
- **Daily gift:**
  - opens after the first win of the day;
  - sits on Home and on the Win card ("Daily gift ready");
  - its size follows the 7-day ladder by streak day;
  - Claim, plus an optional ad to double it.
- **Streak savers:**
  - earned 1 per 7-day run, holding at most 2;
  - each covers one missed day automatically;
  - never sold.
- **A miss with no saver:** "New streak: day 1". The ladder restarts; nothing else is lost.
- **Clock:**
  - local calendar days, one claim per day;
  - if `today < max_seen_day`, nothing new until the clock passes it;
  - if `max_seen_day - today > 2`, re-anchor so a clock that was once far ahead can't lock gifts forever.
- **Code:**
  - `src/daily/day_clock.gd`, `streak.gd` and `gift_ladder.gd` are pure and game-agnostic, with `today` passed in;
  - the reward table lives in Jarful's `economy.gd`.

## 5. Player level, XP, profile, friends
- **XP:**
  - first solve: 10 + 5 per group above 2, plus tricky 5 or hard 10;
  - first gold lid: 15;
  - XP from level n to n+1: 60 + 15(n−1), which reaches about level 45 by L510.
- **Titles:**
  - 1 Apprentice, 5 Jam Maker, 10 Pickler, 15 Preserver;
  - 20 Pantry Keeper, 30 Larder Master, 40 Grand Preserver, 50 Legend of the Larder.
- **Avatars:** 12 at first, Phosphor food icons (MIT, added to `assets/icons`) on coloured lid discs, unlocked by
  level and streak.
- **Profile screen:**
  - avatar (tap to pick);
  - name (tap to rename; 16 printable characters, sanitised);
  - title, plus level and an XP bar;
  - a stats grid: levels solved, gold lids, categories collected, day streak, best streak, rooms completed.
- **Friends:**
  - a `Social` facade with mock and none providers;
  - playtest builds show a small "Friends (test data)" list of sample players and their levels;
  - release builds hide it until Play Games is wired.
  - It's last in the order and the first thing cut.

## 6. Screens and flow
- **Home** (the hero jar and cabinet stay, in the current room's theme). The added items fit the existing rows, so
  there's no new row on 16:9:
  - top: a profile chip (avatar, level, XP ring) on the left; a coin pill (opens the Shop) and the gear on the
    right. How to play moves into Settings.
  - beside the hero jar: a streak flame disc on the left; a gift disc on the right that glows when ready and
    otherwise reads "Win a level to open";
  - bottom row: a Levels disc, the **Play level N** pill, and a Shop disc;
  - tapping the cabinet opens the current room;
  - the cabinet height adapts (it's a fixed 440 u today);
  - checked at 720×1280 and 1080×2400 with insets.
- **Levels map:** a vertical, touch-scrolled list of 17 room cards.
  - Each card shows the room's wall, palette, 3 mini jars in its jar style, its name, "18 / 30" and its gold count.
  - Locked cards are dimmed and say "Unlocks at level 61".
  - The list opens on the current room and ends with "More rooms are being stocked".
- **Room view:**
  - 3 shelves of 10 in the room's theme;
  - `ShelfView` gains a `slot_pressed` signal;
  - a solved slot opens a sheet with its labels, gold state and "Play again";
  - the next slot plays; a locked slot wobbles.
- **Shop:**
  - a Sheet with a scrolling body;
  - free coins (ad, "4 left today") and 5 packs, each with a coin pile that grows with the pack size;
  - the mock shows a "Test purchase" confirmation;
  - packs are hidden when there's no store provider.
- **Scrolling:** kit buttons cancel a press after more than 12 u of finger movement and pass the drag to the
  parent scroll. This applies to the map, the Shop and the test menu.
- **Daily gift sheet:** 7 gift jars (today's highlighted), the streak and saver counts, Claim, and optional ×2.
- **Win card:**
  - stays under the 16:9 sheet cap: one compact row with "+18 coins (×2 chip) · XP bar";
  - a level-up is shown inline, with the reward in the same row;
  - "Daily gift ready" is one line;
  - the sequence is 1.5 s or less and a tap skips it;
  - the playtest flag row stays only in playtest builds.
- **Room complete:** a reveal sheet with the next room's theme preview and +150.
- **Back:**
  - Shop and other sheets close, so you stay in the level;
  - levels and profile go to Home;
  - a room goes back to where it was opened from (map or Home), using a new `origin` in the BackPolicy context and
    tests;
  - the Complete picker closes first.
- **Plumbing:**
  - `main.gd` adds levels, room and profile screens to `_show`, with low-processor mode off the play screen;
  - Home gets new signals;
  - `_rewarded()` moves to a shared helper;
  - `Build.playtest()` moves into `src/core` so autoloads (Ads, Store, Social) can pick mock or none;
  - the test menu's level grid becomes a room picker, then 30 levels.

## 7. Content: 510 levels in 17 rooms of 30 (plus specs to 720)
"Tier 3+" = groups per level whose link is lateral (tier 3) or wordplay (tier 4).

| Room | Levels | Groups | New idea (on its rest level) | Tier 3+ per level | Avg-bot first-try win floor (normal / tricky / hard) |
|---|---|---|---|---|---|
| 1 The Larder (new, medium) | 1–30 | 3, then 4 from L26 | L2 Undo, L4 +Jar, L6 Hint, L7 herring, L11 slip limit, L16 Complete, L21 herrings, L26 four groups | 0–1: only tricky and hard until L17, then most | 0.92 / 0.82 / 0.72 |
| 2 The Kitchen (the current 30) | 31–60 | 3, then 4 | none (old intros removed) | as baked | rebudgeted to ≥ 0.85 / 0.75 / 0.65 |
| 3 Orchard Shed | 61–90 | 4 | L66 abstract categories | 1 | 0.85 / 0.75 / 0.65 |
| 4 Tea Room | 91–120 | 4, then 5 | L96 five groups | 1 | 0.82 / 0.72 / 0.62 |
| 5 Spice Market | 121–150 | 4–5 | L126 double herrings | 1 | 0.80 / 0.70 / 0.60 |
| 6 Bakery | 151–180 | 5 | n/a | 1 | 0.80 / 0.70 / 0.60 |
| 7 Winter Cellar | 181–210 | 5 | L186 frosted jars | 1–2 | 0.78 / 0.68 / 0.58 |
| 8 Greenhouse | 211–240 | 5 | L216 wordplay (tier 4) | 1–2 | 0.78 / 0.68 / 0.58 |
| 9 Apothecary | 241–270 | 5 | L246 labelled jars (replace one empty jar) | 1–2 | 0.75 / 0.65 / 0.55 |
| 10 Honey House | 271–300 | 5, then 6 | L276 six groups | 1–2 | 0.75 / 0.65 / 0.55 |
| 11 Wine Cellar | 301–330 | 5–6 | L306 corked jars | 2 | 0.72 / 0.62 / 0.55 |
| 12–13 Seaside Pantry, Night Market (light walls) | 331–390 | 6 | mixes | 2 | 0.70 / 0.60 / 0.50 |
| 14–17 Chocolatier, Clockmaker's Pantry, Royal Kitchen, Grand Pantry | 391–510 | 6 | **very hard**: 2–3 herrings, special jars | 2 | 0.62 / 0.55 / 0.50 |
| 18–24 (future) | 511–720 | 6 | **super hard** (curve rows only now) | 2–3 | 0.55 / 0.50 / 0.45 |

**How difficulty is set**
- **Budget = the tightest slip limit at which the average bot still meets the room's floor**, never below 2. The
  floors are now the real dial; today budgets come from novice p90.
- **Gold** is the largest slip count that 20–50% of average-bot runs meet, otherwise 0.

**Room 1** is hand-specified to rise from medium to about the start of room 2. Every level has a group that takes
thought (tier 2 or higher). That's gentler than today, where tier 3 starts at L3 and 4 groups at L16.

**Room 2 = the current file, placed second**, keeping its ids r1-01…r1-30, which are stable and already in
saves and playtest logs:
- `room: 2`, name "The Kitchen", `introduces` stripped;
- L31–32 (2-group openers) re-made as 3-group levels with `--regen=1,2`, excluded from the ledger while picking;
- L31–40 get slip limits and gold with `--rebudget=1-10`, keeping words and deals;
- **r1-04: Map and Lock → Piano and Computer.** Typewriter is 10 letters. Accordion would make 3 instruments, a
  phantom group.
- Then rebudget. Re-measured meta won't match the old numbers (bot seeds hash the id), which is expected.

The known dip from L26–30 (4 groups) to L31–40 (3 groups) is a room-start breather. Mehul judges it in play.

**New ids**
- New Room 1 is `l1-01`…`l1-30`; rooms 3–24 are `l3-01`… and so on.
- There's no id migration. Existing players keep their solves, and their next level becomes the new L1.
- Room 3 opens after L60. The map shows their solved Kitchen jars.

**Specs**
- Rooms 3–24 come from `data/rooms/curve.json` via `tools/make_specs.gd`.
- The sawtooth per 10 is: 1–4 rise, 5 tricky, 6 rest with a new idea, 7–9 rise, 10 hard.

### Generator upgrades (`tools/room_gen.gd` and `src/gen`)
- **Two phases:**
  1. **Pick (fast, sequential, global ledger):** categories, words and herrings for every level of every room. A
     `--dry` run over all 510 levels is the **step-1 gate** that measures the real bank shortfall in minutes.
  2. **Settle (parallel, 6 processes, one per room):** deal, measure, budget and gold per level. The bake drops
     from about 4–6 h sequential to about 1 h.

  A level that misses its floor is re-picked in a repair pass checked against the whole ledger.
- **Ledger fixes:**
  - check the minimum distance to *any* use, not `uses.back()` (room_gen.gd:172–174);
  - keep a list of uses per word (:249, :372);
  - global level numbers come from `index.json` order.
- **Reuse:**
  - max uses = clamp(2 × words / 5, 2, 5) (raised from words / 3, max 4, when the dry run showed tier 2 short);
  - at least 60 levels apart (relaxing to 40, then 25);
  - each new use shares at most 2 words with earlier uses;
  - word gap 30;
  - a category pair may repeat after 150 levels.
- **Reproducible:** seed per level and use an rng shuffle everywhere, including `bot.gd:122`.
- **Special jars:** one shared `Dealer.deal_spec(spec, rng)` handles empties, frost, labelled and corked. It's
  moved out of check_levels.gd:50–71 and used by both tools.
- **Target:** takes the global level and the room scale; floors come from `curve.json`.
- **New tools:**
  - `tools/lint_bank.gd`: duplicates, stems and plurals, substring and label clashes, a word containing its own
    key word (e.g. Keyboard), words over 9 characters, word counts, crossings;
  - `tools/audit_content.gd`: re-checks every baked file for phantoms, label clashes, the reuse ledger, cover and
    solvability, and that every level is solvable from its deal.
- **Loading:** `src/core/levels.gd` reads `data/levels/index.json` instead of the hard-coded `FILES`, and so does
  trace_bot. Room names and theme ids go in `data/levels/rooms.json`.

### Category bank: from 139 to about 750
| Tier | Now | Target |
|---|---|---|
| 1 (everyone knows it) | 65 | ~200 |
| 2 (must think; today's bottleneck) | 47 | ~300 |
| 3 (lateral: things with…, words before/after…, abstract concepts) | 27 | ~200 |
| 4 (wordplay: Sounds like letters, Palindromes, Hidden numbers) | 0 | ~50 |

Most categories have 12–16 words. Demand is about 2,630 group slots, including about 700 tier-3+.
- **Drafting:**
  - **8 background agents** draft by domain group into `data/bank/drafts/*.txt`, in the current format;
  - they follow `data/bank/notes.md`: international English, contested words avoided, crossings declared, 9
    characters or fewer, the key word never inside a member;
  - existing categories grow where honest.
- **Merge, then check:**
  1. `lint_bank`;
  2. **3 fresh-eyes fairness reviewers**: each checks "fits two groups", *and* a weak-member audit of every tier-3+
     category ("barely fits its own group": the Map/Lock lesson);
  3. fixes, including `pairs.txt`;
  4. the `--dry` gate.
- **If short:** grow the bank, or lower late tier-3+ counts. The report's reuse histogram shows repeats.

### Ship scope
- **The aim is all 510 levels this round.**
- **The floor is rooms 1–7 (210 levels).** If the gate or the bake runs long, v0.3.0-alpha ships with every room
  that passes its gates, and the rest follows as v0.3.x.
- **Calibration (M2 §16.5) is still open.** The bot alone defines "very hard" until Mehul plays Room 1 and some of
  Room 3.

## 8. Room themes (frontend-design skill)
- **`src/ui/art/themes.gd`** holds a table per room:
  - wall light and shade;
  - a **small tiled pattern texture**: plaster, tiles, slats, floral, brick, stone, hex, panes, stripes, damask or
    marble, at alpha ≤ 0.07;
  - wood tones for planks and the cabinet;
  - jar style: silhouette (mason, jam, squat, caddy, honey, bell, apothecary, amphora), glass tint, rim, and lid
    (enamel, gingham and twine, cork, wax, tin, gold);
  - a prop band (herbs, bunting, window light, lanterns…);
  - the label paper colour.
- **Materials** take a style, and the style goes into every `Art.tex` key (today the keys are literal strings).
  - Silhouettes vary the shoulders, base bulge, rim band and highlights *inside* the jar rect.
  - The card interior and `NECK_RATIO` stay fixed, so layout and layout tests don't change.
  - `Art.clear()` runs on theme change.
- **Readability:** every room has light-to-mid walls, so INK text stays at 4.5:1 or better and cards stay paper on
  glass. There are no dark rooms.
- **Richness:** rooms 1–4 polished and simple; 5–10 add props and light; 11–17 add ornament and gold; 17 is the
  marble finale.
- **Wiring:** `main.gd` keeps `bg` as a member, and `set_room_theme(room)` runs from `_begin` and from Home, the
  map and the room. Planks, cabinet and hero jar read the theme.
- **Process:**
  1. style frames for rooms 1–4 (`tools/art_preview.gd`);
  2. a fresh-eyes critique;
  3. the other 13;
  4. a contact sheet of all 17 boards.

## 9. Save v3, security, performance
- **SaveSchema v3 adds:**
  - `coins`, `inventory{hint, complete}`, `xp`;
  - `profile{name, avatar}`, `avatars{}`;
  - `streak{count, best, last_day, savers}`, `gift{claimed_day}`, `clock{max_day}`;
  - `ads{day, total, by_placement}`;
  - `purchases{tokens[]}`, a ledger ready for real billing;
  - `stats{hints, completes, …}`;
  - `board{id, fingerprint, log}` for resume.
- **Migration v2 → v3:** starters plus back-dated XP. Ids don't change.
- **Sanitising:**
  - coins 0..9,999,999; inventory 0..999;
  - days are ints in range; names are 16 printable characters;
  - ids are filtered against known lists;
  - the replay log is validated by replaying it, and dropped on any illegal step.
- **Purity (CLAUDE.md):**
  - `economy.gd` and `src/daily` are pure functions over dictionaries;
  - a `Wallet` autoload in `src/core` applies them to Save and writes immediately.
- **Facades** in `src/core` (Ads extended, Store, Social) use mock in playtest builds and none otherwise. Grants
  come only from provider callbacks, through `Wallet.grant()`. INTERNET stays off.
- **Performance:**
  - Advisor and Tidy run off the main thread with a time budget;
  - solver keys are byte-packed (cuts memory from the current ~100 MB worst case at a 50k cap);
  - pattern tiles are small and cached; the map uses cached textures;
  - measure the 510-level JSON load (cold start budget under 2 s) and load per room if slow;
  - Advisor p95 ms is measured on Mehul's phone when he plugs it in.

## 10. Sound, haptics, feel (game-feel skill)
- **New sounds** (CC0 packs already on disk in the scratchpad `sfx_src`, mapped via `tools/import_sfx.sh`, credited
  in CREDITS.md and in-game Credits):
  - coin ticks and collect (`kenney_casino`/`kenney_rpg`);
  - level-up and room reveal (`kenney_jingles`);
  - gift open and purchase (`kenney_interface`).
- **Reused sounds:** seal uses the existing ratchet, seat and bell; hint uses the existing chime with a sparkle.
- **Haptics:** coin 15 ms (the floor), seal = lid 35 ms, level-up 20/40/20.
- **Coin flight:** on Win, coins fly to the coin pill (start 300 ms in, ≤ 0.6 s). Reduce motion skips the flight.
- **Music:** unchanged.

## 11. Order of work (branch `m3-meta-content`, small commits, merged to main at the end)
1. **Content pipeline (the long pole, first).**
   - Launch the 8 bank-drafting agents in the background.
   - room_gen: two phases, ledger fixes, reproducible RNG, `Dealer.deal_spec`, bot frost/tier 4, `--dry`,
     `--regen`, `--rebudget`.
   - `make_specs` plus `curve.json`, `lint_bank`, `audit_content`, `index.json`/`rooms.json` loading.
   - Room 2 conversion and the r1-04 fix.
2. **Rules and tests.**
   - `economy.gd`, `src/daily/*`, XP and titles, AdPolicy caps, `Build.playtest`.
   - SaveSchema v3, the action log and resume, `Wallet`.
   - `sealed`, `Session.complete`/`hint`, the Solver, `all_known` and `proven_not_in` fixes, the Advisor.
3. **Bank merge and bake (background).**
   - Lint, then 3 fairness reviewers, then fixes.
   - The `--dry` gate over 510 levels, adjust, then the phase-1 pick.
   - Phase-2 settle in 6 processes (rooms 1, 3–17).
   - As rooms land: check_levels, audit, sims, `reports/curve.md`.
4. **Play screen.** Hint, Complete (picker, seal flight), HUD coin pill, not-enough-coins sheet, coin Continue,
   mercy Hint, the Tidy input fix, Win rewards, level-up, room reveal.
5. **Meta screens.** Home, Levels map, Room view, Profile and avatars, Shop with scrolling, Daily gift, the facades.
6. **Themes.** Table and parametric materials; style frames 1–4, then critique, then all 17; wiring.
7. **Feel.** Sounds and haptics for the new events.
8. **Ship.**
   - `economy_sim`.
   - Docs: DESIGN.md, CLAUDE.md commands and gotchas, CREDITS.
   - Screenshots and a fresh-eyes UX review.
   - APK v0.3.0-alpha and audit, merge, push, GitHub pre-release.

**Cut order if time runs short:** friends, then rooms 8–17 ornament (keep palette and pattern), then avatars beyond
6, then levels beyond the floor (rooms 1–7).

## 12. Verification
- **GUT tests:**
  - economy: tables, inventory first, never negative, Wallet writes;
  - streak and gift: consecutive days, savers, double gaps, rollback and re-anchor, same day, month and year edges;
  - XP curve and one-time rewards;
  - ad caps and cooldown;
  - `Session.complete`: removal, win, undo barrier, frost, uncork, then **Solver and `all_known` after a seal**;
  - **a slip into a labelled jar of a sealed group is refused for free**;
  - **Hint never advances a step twice**;
  - Advisor: legal moves, a stale result is discarded;
  - action-log replay matches live play, and a corrupt log is dropped;
  - save v3 sanitising and idempotence, plus **loading a real v0.2.0 save file**;
  - catalog over 17 rooms: unique ids, titles L1–L510, intros;
  - BackPolicy with origins;
  - layout with 5 bar buttons and a budget-10 meter.
- **Content:**
  - check_levels and audit_content on every room file;
  - `check_levels --hints`: a bot that only follows Hints wins every level;
  - per-room sims plus a 510-level `reports/curve.md` against the floors;
  - `reports/economy.md` meets the §3 gates.
- **Screenshots** at 720×1280 and 1080×2400 with `--safe=60,40` (playtest build):
  - every new screen and sheet;
  - Hint, the Complete picker and the seal mid-flight;
  - Win with coins, XP and a level-up at 16:9;
  - all 17 themes as a contact sheet;
  - then a fresh-eyes design review.
- **Recording:** Movie Maker capture of Complete plus Win with audio, loudness-checked.
- **APK:** audited. Install over 0.2.0-alpha and check progress, starters and resume after a kill.
