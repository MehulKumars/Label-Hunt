## Star rates by level, room and tier: plays the average bot N times on each room level under its slip budget and
## keeps the slip counts of its wins. The stars come from those counts with the current Economy.star_limits, so the
## star offsets can be tuned and re-checked with --merge alone, without playing again. Bots never take a Hint, so
## people who use Hints will score a little higher. Checks each tier's share of 3-star wins against its band.
## Play: writes reports/stars_part_<first room>.csv (raw: win rate and the slip histogram of wins); run several
## processes on different --rooms at once. Merge: reads every part, writes reports/stars.csv (per level, with p3/p2/p1;
## tools/economy_sim.gd reads it) and reports/stars.md.
## Run: godot --headless --path . -s res://tools/star_report.gd -- --n=60 --rooms=1-8   (then)   -- --merge
extends SceneTree

const LEVELS := preload("res://src/core/levels.gd")
## [first room, lowest, highest] share of the average bot's wins that earn 3 stars (docs/DESIGN.md, Stars).
const BANDS := [[1, 0.75, 1.0], [5, 0.45, 0.70], [14, 0.25, 0.50]]
const HIST := 16
const RAW_HEADER := "id,games,win,hist"
const HEADER := "id,room,number,kind,budget,gold,l3,l2,games,win,p3,p2,p1"


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var cat := Catalog.from_files(LEVELS.files())
	if args.has("merge"):
		_write_report(cat, _read_parts())
		quit()
		return
	var n := int(args.get("n", "60"))
	var rooms := _rooms(str(args.get("rooms", "1-17")))
	var rows: Array[String] = []
	var t0 := Time.get_ticks_msec()
	for id in cat.play_order():
		if not rooms.has(int(cat.entry(id)["room"])):
			continue
		var lvl := cat.level(id)
		var hist: Array[int] = []
		hist.resize(HIST)
		hist.fill(0)
		var wins := 0
		for g in n:
			var r := Bot.play(lvl, "average", hash([id, "stars", g]))
			if r["won"]:
				wins += 1
				hist[mini(int(r["slips"]), HIST - 1)] += 1
		rows.append("%s,%d,%.3f,%s" % [id, n, float(wins) / n, "|".join(hist.map(func(x: int) -> String: return str(x)))])
	print("star_report: %d levels in %.1f s" % [rows.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	_write("res://reports/stars_part_%02d.csv" % rooms.min(), RAW_HEADER + "\n" + "\n".join(rows) + "\n")
	quit()


## Raw rows by level id from every part file.
func _read_parts() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at("res://reports"):
		if f.begins_with("stars_part_") and f.ends_with(".csv"):
			for l in FileAccess.get_file_as_string("res://reports/" + f).split("\n", false).slice(1):
				out[l.split(",")[0]] = l
	return out


func _write_report(cat: Catalog, raw: Dictionary) -> void:
	var rows: Array[String] = []
	var by_room := {}
	for id in cat.play_order():
		if not raw.has(id):
			continue
		var f: PackedStringArray = (raw[id] as String).split(",")
		var e := cat.entry(id)
		var room := int(e["room"])
		var lim := Economy.entry_limits(e)
		var c := [0, 0, 0, 0]
		var hist := f[3].split("|")
		for s in hist.size():
			c[Economy.stars_for(s, lim)] += int(hist[s])
		var wins := maxi(c[1] + c[2] + c[3], 1)
		var p := [float(c[3]) / wins, float(c[2]) / wins, float(c[1]) / wins]
		rows.append("%s,%d,%d,%s,%d,%d,%d,%d,%s,%s,%.3f,%.3f,%.3f" % [id, room, cat.order_index(id) + 1, e["kind"],
			int(e["data"].get("budget", 0)), int(e["gold"]), lim.x, lim.y, f[1], f[2], p[0], p[1], p[2]])
		var acc: Array = by_room.get(room, [0, 0.0, 0.0, 0.0, 0.0])
		acc[0] += 1
		acc[1] += float(f[2])
		for k in 3:
			acc[k + 2] += p[k]
		by_room[room] = acc
	_write("res://reports/stars.csv", HEADER + "\n" + "\n".join(rows) + "\n")
	var md: Array[String] = ["# Star rates (average bot, no Hints)", "",
		"Share of the bot's wins at 3, 2 and 1 stars, and its win rate under the slip budget, with the star offsets " +
		"%s (Economy.STAR_OFFSETS: [first room, offset]). Bands for 3 stars: rooms 1-4 at least 75%%, rooms 5-13 45-70%%, " % [
			str(Economy.STAR_OFFSETS)] + "rooms 14-17 25-50%. People who use Hints will score higher.", "",
		"| room | name | levels | win | 3 stars | 2 stars | 1 star |", "|---|---|---|---|---|---|---|"]
	var tiers := {}
	for room in by_room.keys():
		var a: Array = by_room[room]
		var lv := float(a[0])
		md.append("| %d | %s | %d | %d%% | %d%% | %d%% | %d%% |" % [room, cat.room_name(room), a[0], roundi(100 * a[1] / lv),
			roundi(100 * a[2] / lv), roundi(100 * a[3] / lv), roundi(100 * a[4] / lv)])
		var t := _band(room)
		var ta: Array = tiers.get(t, [0, 0.0])
		ta[0] += a[0]
		ta[1] += a[2]
		tiers[t] = ta
	md.append_array(["", "## Gates", ""])
	var ok := true
	for t: int in tiers.keys():
		var b: Array = BANDS[t]
		var share: float = tiers[t][1] / float(tiers[t][0])
		var met := share >= float(b[1]) - 0.005 and share <= float(b[2]) + 0.005
		ok = ok and met
		var to := 17 if t == BANDS.size() - 1 else int(BANDS[t + 1][0]) - 1
		md.append("- %s rooms %d-%d: %d%% of wins earn 3 stars (band %d-%d%%)" % ["PASS" if met else "FAIL", int(b[0]), to,
			roundi(100 * share), roundi(100 * float(b[1])), roundi(100 * float(b[2]))])
	_write("res://reports/stars.md", "\n".join(md) + "\n")
	print("star_report: %d levels, gates %s" % [rows.size(), "PASS" if ok else "FAIL"])
	for l in md.slice(md.size() - tiers.size()):
		print(l)


static func _band(room: int) -> int:
	var t := 0
	for i in BANDS.size():
		if room >= int(BANDS[i][0]):
			t = i
	return t


static func _rooms(spec: String) -> Array[int]:
	var out: Array[int] = []
	for part in spec.split(",", false):
		var ab := part.split("-")
		for r in range(int(ab[0]), int(ab[-1]) + 1):
			out.append(r)
	return out


static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
