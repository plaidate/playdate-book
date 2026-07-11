#!/bin/bash
# Build one example, run it headless in the Playdate Simulator, and collect
# its named shots into figures/<slug>/ at 2x nearest-neighbor scale.
#
#   tools/shoot.sh <example-slug>          e.g. tools/shoot.sh 01-hello
#
# Shooting doubles as the smoke test: the run fails on any runtime error
# (err.json) or if the harness never reports done. The Simulator is
# single-instance, so callers must run this serially (the Makefile does).
set -u

SLUG="${1:?usage: tools/shoot.sh <example-slug>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EX="$ROOT/examples/$SLUG"
[ -d "$EX" ] || { echo "shoot: no such example: $SLUG" >&2; exit 1; }

BUNDLE="com.sdwfrost.book.$(echo "$SLUG" | tr -d '-')"
DATA="$HOME/Developer/PlaydateSDK/Disk/Data/$BUNDLE"
SIM="$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app"
FIG="$ROOT/figures/$SLUG"
NAME="$(sed -n 's/^NAME[[:space:]]*:*=[[:space:]]*//p' "$EX/Makefile" | head -1)"
[ -n "$NAME" ] && PDX="$ROOT/build/$SLUG/book/${NAME}Book.pdx" \
    || { echo "shoot: no NAME in $EX/Makefile" >&2; exit 1; }

echo "shoot: $SLUG (build)"
make -C "$EX" book >/dev/null || { echo "shoot: BUILD FAILED: $SLUG" >&2; exit 1; }

# 3.0.6 sim: launch by explicit path with --args and WITHOUT -g;
# background/by-name launches load the pdx but never start the game.
pkill -9 -f "Playdate Simulator" 2>/dev/null
rm -rf "$DATA" "$FIG/raw"
mkdir -p "$FIG/raw"
open "$SIM" --args "$PDX"

ok=""
for i in $(seq 1 45); do
    sleep 2
    if [ -s "$DATA/err.json" ]; then
        echo "shoot: RUNTIME ERROR in $SLUG:" >&2
        cat "$DATA/err.json" >&2
        pkill -9 -f "Playdate Simulator" 2>/dev/null
        exit 1
    fi
    if grep -q '"done":true' "$DATA/smoke.json" 2>/dev/null; then ok=1; break; fi
done
pkill -9 -f "Playdate Simulator" 2>/dev/null

if [ -z "$ok" ]; then
    echo "shoot: TIMEOUT in $SLUG (no done marker). Last heartbeat:" >&2
    cat "$DATA/smoke.json" 2>/dev/null >&2 || echo "  (none)" >&2
    exit 1
fi
rm -rf "$DATA"   # test data must not leak into real saves

shopt -s nullglob
raws=("$FIG"/raw/*.png)
if [ ${#raws[@]} -eq 0 ]; then
    echo "shoot: $SLUG produced no shots (Shots.shots empty?)" >&2
    exit 1
fi
for f in "${raws[@]}"; do
    # 2x nearest-neighbor, plus a thin frame so white screens read as
    # screenshots on the white page of the PDF.
    magick "$f" -filter point -resize 200% \
        -bordercolor black -border 2 "$FIG/$(basename "$f")"
done
rm -rf "$FIG/raw"
touch "$FIG/.stamp"
echo "shoot: $SLUG OK — ${#raws[@]} figure(s): $(cd "$FIG" && ls *.png | tr '\n' ' ')"
