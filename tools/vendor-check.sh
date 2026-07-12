#!/bin/bash
# Every vendored engine file in examples/ must still match its upstream,
# modulo the "-- vendored from ..." header and the snip markers the book
# adds. The engines get fixed under us; this catches the drift.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLEET="$(cd "$ROOT/.." && pwd)"
fail=0
for f in "$ROOT"/examples/*/source/*.lua; do
    src=$(sed -n '1s/^-- vendored from \(.*\) (MIT)$/\1/p' "$f")
    [ -n "$src" ] || continue
    up="$FLEET/$src"
    if [ ! -f "$up" ]; then
        echo "MISSING upstream: $src"; fail=1; continue
    fi
    strip() { grep -vE '^\s*-- (snip: |endsnip$)|^-- vendored from ' "$1"; }
    if ! diff -q <(strip "$f") <(strip "$up") >/dev/null; then
        echo "DRIFT: $(basename "$(dirname "$(dirname "$f")")")/$(basename "$f") vs $src"
        diff <(strip "$f") <(strip "$up") | head -6
        fail=1
    fi
done
[ "$fail" -eq 0 ] && echo "vendor-check: all vendored files match upstream"
exit "$fail"
