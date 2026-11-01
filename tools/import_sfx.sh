#!/usr/bin/env bash
# Builds assets/audio from the CC0 packs listed in CREDITS.md (downloaded by hand into one folder; see the source URLs
# there). Each clip: leading silence trimmed, capped in length, faded out, mono 44.1 kHz, peak-normalised to its
# tier (UI quietest, celebrations loudest; plan-m2 section 12). The music bed is loudness-normalised OGG.
#   bash tools/import_sfx.sh <folder with the unzipped packs>
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="${1:?usage: bash tools/import_sfx.sh <packs folder>}"
OUT=assets/audio/sfx
mkdir -p "$OUT" assets/audio/music

# dest            source (relative to SRC)                                  max_s  peak_dBFS
MAP="
lift_1            kenney_casino/x/Audio/card-slide-5.ogg                    0.30   -13
lift_2            kenney_casino/x/Audio/card-slide-6.ogg                    0.30   -13
drop_1            kenney_interface/x/Audio/glass_002.ogg                    0.25   -10
drop_2            kenney_interface/x/Audio/glass_005.ogg                    0.25   -10
drop_3            rubberduck_100sfx2/x/sfx100v2_glass_04.ogg                0.25   -11
place             kenney_casino/x/Audio/card-place-2.ogg                    0.35   -12
slip_1            rubberduck_woodmetal/x/wood_hit_06.ogg                    0.30   -10
slip_2            rubberduck_breaking/x/bfh1_wood_hit_01.ogg                0.30   -10
refuse            kenney_interface/x/Audio/bong_001.ogg                     0.20   -16
write             antumdeluge_pencil/x/ogg/pencil_write.ogg                 0.45   -15
type              kenney_interface/x/Audio/scratch_003.ogg                  0.15   -18
chime             starninja_dings/x/ding.4.ogg                              0.70   -14
ratchet           bmaczero_mechanical/mechanical2.wav                       0.45   -12
seat              sinny_glassbottle/glass_bottle_close.mp3                  0.25   -9
shelf             kenney_rpg/x/OGG/bookPlace2.ogg                           0.40   -10
bell              pwl_bells/bell_ding1.wav                                  1.40   -12
tap               kenney_interface/x/Audio/click_001.ogg                    0.12   -15
whoosh            kenney_interface/x/Audio/minimize_003.ogg                 0.25   -20
win               kenney_jingles/x/OGG/jingles_PIZZA/jingles_PIZZA07.ogg    2.00   -6
coin              kenney_rpg/x/OGG/handleCoins2.ogg                         0.60   -11
levelup           kenney_jingles/x/OGG/jingles_PIZZA/jingles_PIZZA03.ogg    1.60   -8
gift              kenney_interface/x/Audio/open_002.ogg                     0.45   -12
"

peak() { ffmpeg -hide_banner -nostats -i "$1" -af volumedetect -f null - 2>&1 | sed -n 's/.*max_volume: \(-\{0,1\}[0-9.]*\) dB.*/\1/p'; }

echo "$MAP" | while read -r dest src max target; do
	[ -z "${dest:-}" ] && continue
	tmp="$OUT/.$dest.tmp.wav"
	fade_at=$(awk "BEGIN{print $max - 0.04}")
	ffmpeg -hide_banner -loglevel error -y -i "$SRC/$src" \
		-af "silenceremove=start_periods=1:start_threshold=-45dB,atrim=0:$max,afade=t=out:st=$fade_at:d=0.04" \
		-ac 1 -ar 44100 -c:a pcm_s16le "$tmp"
	gain=$(awk "BEGIN{print $target - ($(peak "$tmp"))}")
	ffmpeg -hide_banner -loglevel error -y -i "$tmp" -af "volume=${gain}dB" -c:a pcm_s16le "$OUT/$dest.wav"
	rm -f "$tmp"
	echo "$dest  <- $src  (peak $target dBFS)"
done

ffmpeg -hide_banner -loglevel error -y -i "$SRC/music_kistol_catmint/catmint_in_c_major_looped.ogg" \
	-af "loudnorm=I=-20:TP=-2:LRA=11" -ar 44100 -c:a libvorbis -q:a 3 assets/audio/music/catmint.ogg
echo "music: catmint.ogg (Kistol, CC0) at -20 LUFS"
