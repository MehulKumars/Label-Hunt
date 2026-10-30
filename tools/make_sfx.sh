#!/usr/bin/env bash
# Synthesises Jarful's placeholder sound effects with ffmpeg, so they are original and need no license.
# Mehul's recorded foley replaces them later. Run from the project root: bash tools/make_sfx.sh
set -euo pipefail
OUT=assets/audio/sfx
mkdir -p "$OUT"

# gen NAME DURATION EXPRESSION [EXTRA_FILTERS]
gen() {
	local filters="${4:-anull}"
	ffmpeg -y -hide_banner -loglevel error -f lavfi -i "aevalsrc='$3':s=44100:d=$2" \
		-af "$filters,alimiter=limit=0.8" -ac 1 -c:a pcm_s16le "$OUT/$1.wav"
}

# Card lift: a short paper swish (3 variants).
gen lift_1 0.09 "(random(0)*2-1)*exp(-t*55)*0.6" "highpass=f=1800,lowpass=f=7000"
gen lift_2 0.09 "(random(1)*2-1)*exp(-t*60)*0.6" "highpass=f=2200,lowpass=f=8000"
gen lift_3 0.09 "(random(2)*2-1)*exp(-t*50)*0.6" "highpass=f=1500,lowpass=f=6000"

# Valid drop: a small glass clink with inharmonic partials (3 variants).
for v in "1 2100" "2 2400" "3 2650"; do
	set -- $v
	gen "drop_$1" 0.5 "0.45*sin(2*PI*$2*t)*exp(-t*22)+0.25*sin(2*PI*$2*2.76*t)*exp(-t*30)+0.12*sin(2*PI*$2*5.4*t)*exp(-t*40)+0.2*(random(0)*2-1)*exp(-t*300)" "afade=t=out:st=0.35:d=0.15"
done

# Slip: a dull wooden knock, no buzz.
gen slip_1 0.3 "0.9*sin(2*PI*140*t)*exp(-t*28)+0.4*sin(2*PI*290*t)*exp(-t*45)+0.35*(random(0)*2-1)*exp(-t*90)" "lowpass=f=1200"
gen slip_2 0.3 "0.9*sin(2*PI*125*t)*exp(-t*26)+0.4*sin(2*PI*262*t)*exp(-t*42)+0.35*(random(3)*2-1)*exp(-t*90)" "lowpass=f=1100"

# Refused for free (already proven wrong): two muted ticks.
gen refuse 0.2 "(lt(t,0.05)*sin(2*PI*600*t)*exp(-t*90)+gte(t,0.09)*sin(2*PI*480*(t-0.09))*exp(-(t-0.09)*90))*0.5"

# Lid: a ratchet of clicks, then a rising pop.
gen lid 0.6 "lt(t,0.21)*lt(mod(t,0.035),0.006)*(random(0)*2-1)*0.7+gte(t,0.24)*sin(2*PI*(380*(t-0.24)+450*(t-0.24)*(t-0.24)))*exp(-(t-0.24)*22)*0.8" "highpass=f=150"

# Label typing: typewriter ticks (3 variants).
for v in 1 2 3; do
	gen "type_$v" 0.05 "(random($v)*2-1)*exp(-t*400)*0.8+0.3*sin(2*PI*$((1600 + v * 150))*t)*exp(-t*250)" "highpass=f=1000"
done

# Tag reveal: a soft two-partial ding.
gen tag 0.45 "0.3*sin(2*PI*1568*t)*exp(-t*14)+0.15*sin(2*PI*2350*t)*exp(-t*18)"

# Frost wipe: a short glassy squeak.
gen frost 0.25 "(random(0)*2-1)*0.5*sin(PI*t/0.25)" "bandpass=f=3000:width_type=h:w=1500"

# UI button tap.
gen tap 0.06 "sin(2*PI*900*t)*exp(-t*120)*0.5+(random(0)*2-1)*exp(-t*500)*0.2"

# Win: a gentle rising arpeggio (C6 E6 G6 C7).
gen win 1.4 "gte(t,0)*sin(2*PI*1046.5*t)*exp(-t*5)*0.25+gte(t,0.09)*sin(2*PI*1318.5*(t-0.09))*exp(-(t-0.09)*5)*0.25+gte(t,0.18)*sin(2*PI*1568*(t-0.18))*exp(-(t-0.18)*5)*0.25+gte(t,0.3)*sin(2*PI*2093*(t-0.3))*exp(-(t-0.3)*4)*0.28" "afade=t=out:st=1.1:d=0.3"

ls "$OUT"
