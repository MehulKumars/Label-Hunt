# Jarful: design

**Pitch:** Sort word cards into glass jars by a hidden category. Only the top card moves, and a wrong drop
bounces back but shows you part of the label. When four cards belong together, the lid screws on and the label
types in.

Jarful is built from Mehul's *Word Jars* concept card. The closest game on the market is Tripledot's
*Bubble Word Sort*, which has hidden groups of 4 in pipes. Jarful differs in five ways:
1. **Strict jar rules.** Only the top card moves, and each drop is checked against the top card. A wrong drop is a *slip*.
2. **Labels you earn.** Slips, pairs you build and Peeks each reveal the label one step at a time, like hangman.
3. **Lids and a Pantry.** Every category you solve becomes a labelled jar on your shelves.
4. **Jar types:** frosted, labelled and corked.
5. **Jar of the Day**, with a streak and a share string.

## Rules
- **Moving.** Tap a jar to lift its top card, then tap another jar to drop it. Drag works too. You can drop on an
  empty jar, or on a top card of the same hidden group.
- **Slips.** A wrong drop is a slip: the card bounces home, you lose one slip, and the card gets a tag that links it
  to its group's slot in the **label rail**. That label moves one step on.
- **Building pairs.** The first time you stack two cards of one group, the label also moves one step.
- **Label steps.** The rail shows each label in steps:
  1. blank;
  2. the context words plus the length of the key word ("Things with ▢▢▢▢");
  3. the key word's first letter;
  4. the full label, once the lid is on.
- **Lids.** Four cards of one group in one jar → the lid goes on. Lids are permanent and always correct.
- **No free information is punished.** A drop the board already proves wrong is refused for free. "Stuck" is
  judged only from what the player can know.
- **Undo** is free back to the last lid; knowledge stays. Once every remaining card's group is proven, **Tidy up**
  finishes the board for you.
- **Fail state.** From level 11, each level has a slip budget set by a fixed table: chapter × group count. Running
  out means **Retry** (one tap) or an optional **Continue** for +2 slips. Levels 1–10 can't be failed.
  After 2 fails on the same level, the next try gives a free Peek and +1 slip.
  *Open:* budget or stars-only. Mehul decides after playing M1; it's a dev toggle.
- **Fair deals.** No two cards of the same group start next to each other, and there are always 2 empty jars.

## First 60 seconds
1. Tap the icon. The splash shows, then level 1 starts with no menu.
2. Level 1 has 3 jars and 2 obvious groups (fruit, colours). *Apple* glows and a hand pointer shows tap → tap.
3. First move at about 8 s.
4. First lid and label at about 30 s.
5. Level done at about 50 s, then **Next**.

Captions only appear the first time something happens: first slip, first pair, first stuck. Each is three words
or fewer.

## Progression and meta
- **150 levels in 5 chapters ("pantry rooms") of 30.**
- **Sawtooth in packs of 10:** levels 1–4 rise, 5 is *tricky*, 6 is a rest level that brings in the next idea,
  7–9 rise, 10 is *hard*.
- **When new ideas arrive:**

  | Level | New idea |
  |---|---|
  | L11 | slip budget |
  | L16 | 4 groups |
  | L26 | herrings |
  | L36 | abstract categories |
  | L46 | 5 groups |
  | L66 | frosted jars |
  | L96 | labelled jars |
  | L106 | 6 groups |
  | L126 | corked jars |
  | L136 | wordplay |

- **Pantry (Home).** Your shelves of solved categories, with one big **Play · Level N** button in the bottom third.
- **Jar of the Day.**
  - One baked puzzle per date, from Monday (easy) to Sunday (hard).
  - No fail state and no ads. Your score is the slips you used.
  - Streak with earnable freezes, a spoiler-free share string and an archive.
  - The code is a game-agnostic module.
- **Coins.**
  - You earn them from wins (a bonus for every unused slip), the daily and clearing a chapter.
  - You spend them on Peek, +Jar and Continue.
  - No energy, no timers, no paywalls.

## Difficulty and the level pipeline
- **Category bank.** About 450 categories drafted by Claude, each with a key word, tier, domain tags and
  per-word obscurity. Only region-neutral English ships.
- **Fairness gates for every level:**
  - **Unique cover:** there is exactly one way to split the cards into the level's groups.
  - **No phantom groups:** a bank category outside the level must not hold 3 or more of its cards.
  - **Reviewed pairs only:** two categories share a level only after that pair has been reviewed.
  - **Lint:** duplicates, clashes, contested words, card fit at ≥34 px.
- **Offline, deterministic bake** (`tools/bake.gd`):
  1. Pick categories and words in level order, respecting reuse caps.
  2. Deal at random with constraints.
  3. A weighted A* solver proves the level solvable.
  4. A human-like bot plays 300 times to measure pass rate, slips, moves after the "aha" and time.
  5. Exploit bots (random prober, Peek-all) act as gates.
  6. Near-duplicates are filtered out.
- **Reports.** Each bake writes `reports/bake_vN.csv`, `.md` and `curve_vN.svg`, plotting pass rate against the
  target bands.
- **Pass-rate targets** (average bot, first try):

  | Levels | Target |
  |---|---|
  | L1–10 | ≥97% |
  | Each pack | rising from ~92% to ~80% |
  | Tricky levels | ~70% |
  | Rest levels | ≥92% |
  | Hard levels | 55–65% (never below 50%) |
  | Daily | median slips from ~1 on Monday to ~3 on Sunday |

- **Calibration.** Mehul's playtest log and stranger tests calibrate the bot. Until it ranks levels the way people
  do (ρ ≥ 0.6), Mehul's flags win.

## Screens
- **Main screens:**
  - **Home (Pantry):** shelves, the Daily card, coins, settings, and the big Play button.
  - **Play:** the top bar holds pause, the level number, coins and the slip meter. Below it sits the label rail,
    then the board in the lower part (3 columns, within thumb reach). The bottom bar has Undo, Peek, +Jar and Tidy up.
- **Popups:** Win, Lose, Pause, Settings (music, sound, haptics, reduce motion; Credits, Privacy, How to play,
  dev menu), Daily result, Boosters, Chapter complete. The **Daily** screen has today's puzzle and the archive.
- **Launch:** the first launch (or until L3 is done) goes straight into the level. After that, the app opens on
  Home. A level interrupted when the app is killed resumes exactly.
- **Back button:**
  1. Puts down a lifted card.
  2. Closes the open popup.
  3. In Play, opens Pause.
  4. On another screen, goes to Home.
  5. On Home, moves the app to the background.

## Art, sound, feel
- **Look.** Mehul's palette: Paper `#FFF8EC`, Ink `#3D2C2E`, Paprika `#A9432C`, Glass teal `#3B6E6E`, and
  Apricot `#F28F3B` for decoration. Jars, lids, cards, shelves and icons are drawn in code or hand-made SVG.
  Fonts are Atkinson Hyperlegible Next plus one typewriter face, both OFL.
- **Feel.** Calm, with a flourish when you solve something. Juice goes on success only:
  - lift: 80 ms;
  - drop: a 150 ms glide and a glass clink;
  - slip: a ±3° wobble and a knock, with no buzz;
  - lid: a 300 ms screw-on with a ratchet;
  - label: typed in, then a shine sweep;
  - jar to shelf: sparkles;
  - win: the jars hop in a wave and confetti falls.
- **Reduce motion** removes the wobble, the hops and the confetti.
- **Sound.**
  - Kenney CC0 effects and a soft CC0/CC-BY music bed. Mehul's recorded foley replaces the effects later.
  - Pitch varies ±3–8%.
  - Nothing is timed to audio.
- **Haptics:** 8–50 ms ticks.

## Monetisation (mock in v1)
- Every ad goes through an `AdService` with a mock provider.
- **Rewarded ads**, always opt-in: Continue, ×2 coins, Peek, +Jar.
- **Interstitials** only when the results screen opens after a win. Never in session 1, never before L10, at least
  2 wins and 120 s apart, and never around the daily.
- Real AdMob, consent, IAP and analytics backends come later. They need accounts, so they're Mehul's call.

## Scope of v1
Included:
- 150 levels, all passing the gates, and up to 365 dailies (at least 180).
- Home and Pantry, daily, settings, save and resume, mock ads.
- Our own art and sound.
- An Android APK, with the AAB as part of the M4 release prep.

Left for later: real ads/IAP, localisation, leaderboards, notifications.

**Milestones:**

| Milestone | Version | Contents |
|---|---|---|
| M1 | v0.1 | Find the fun: grey-box + toggles + bot |
| M2 | v0.2 | Home, tutorial, Room 1 progression, the art direction (style frames, SVG materials). See `docs/plan-m2.md` |
| M2b | v0.2.x | Jar of the Day (daily module) and coins/boosters |
| M3a | v0.3 | Content: bank, full pipeline, rooms 2–5, dailies |
| M3b | v0.4 | Sound and music pass, remaining rooms' art, juice pass |
| M4 | v1.0-rc | Polish, performance, store kit |
