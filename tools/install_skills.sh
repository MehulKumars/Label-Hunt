#!/usr/bin/env bash
# Installs the vetted Claude Code skills into .claude/skills/, pinned to the exact commits that were reviewed on
# 2026-10-30 (Markdown only: no scripts, hooks or network calls). Git Bash; needs only git.
#   bash tools/install_skills.sh            # recommended set
#   bash tools/install_skills.sh --extra    # also the Godot tween and UI references
# Then start a new Claude Code session so the skills load.
# Never run "/game-design wire": it would edit CLAUDE.md and .claude/settings.json and add a Node hook.
set -euo pipefail
cd "$(dirname "$0")/.."
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

fetch() { # owner/repo full-sha dir
	git init -q "$T/$3"
	git -C "$T/$3" fetch -q --depth 1 "https://github.com/$1.git" "$2"
	git -C "$T/$3" checkout -q FETCH_HEAD
}

fetch anthropics/skills ca45fc496a3436251f191354091d557da31c15b5 an
fetch saschb2b/skills 31a6a1364b73ff24f388f9e35c6e3ccd9baa7d89 sb
fetch gamedev-skills/awesome-gamedev-agent-skills 19d93f97c9c1ea0f8b306e77aa81e0d3e352d3e9 gd

mkdir -p .claude/skills
install_skill() { # source-dir name license-files...
	local src=$1 name=$2
	shift 2
	rm -rf ".claude/skills/$name"
	cp -r "$src" ".claude/skills/$name"
	for f in "$@"; do cp "$f" ".claude/skills/$name/"; done
	echo "installed $name"
}

# Visual design method: token plan first, anti-template calibration, screenshot self-critique (Apache-2.0).
install_skill "$T/an/skills/frontend-design" frontend-design
# Game UX: onboarding, menus and screens, transitions, feedback, accessibility (MIT).
install_skill "$T/sb/skills/productivity/game-design" game-design "$T/sb/LICENSE"
rm -f .claude/skills/game-design/CARD.* # signing metadata only
# Feedback tiers and easing for juice (Apache-2.0).
install_skill "$T/gd/skills/disciplines/game-feel" game-feel "$T/gd/LICENSE" "$T/gd/NOTICE"

if [[ "${1:-}" == "--extra" ]]; then
	fetch jame581/GodotPrompter d7b26cdb5fae14d4ef7b713c5bf259395e75c3c6 gp
	install_skill "$T/gd/skills/godot/godot-ui-control" godot-ui-control "$T/gd/LICENSE" "$T/gd/NOTICE"
	install_skill "$T/gp/skills/tween-animation" tween-animation "$T/gp/LICENSE"
fi
echo "done: start a new Claude Code session to load them"
