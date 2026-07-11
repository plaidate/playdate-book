#!/bin/bash
# Book lint: every snip target resolves, every generated figure is referenced
# by some chapter, and every referenced figure exists.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0

# 1. snip targets exist (file level; missing regions already fail the render)
while IFS= read -r ref; do
    f="examples/$(echo "$ref" | awk '{print $1}')"
    [ -f "$f" ] || { echo "lint: snip target missing: $f"; fail=1; }
done < <(grep -rhoE '\{\{< snip [^>]+>\}\}' index.qmd chapters/*.qmd 2>/dev/null \
         | sed -E 's/\{\{< snip //; s/ *>\}\}//')

# 2. referenced figures exist
while IFS= read -r img; do
    p="${img#../}"
    [ -f "$p" ] || { echo "lint: referenced figure missing: $p"; fail=1; }
done < <(grep -rhoE '\]\((\.\./)?figures/[^)]+\)' index.qmd chapters/*.qmd 2>/dev/null \
         | sed -E 's/^\]\(//; s/\)$//')

# 3. generated figures all referenced
for png in figures/*/*.png; do
    [ -e "$png" ] || continue
    grep -rq "$(basename "$(dirname "$png")")/$(basename "$png")" chapters/*.qmd index.qmd 2>/dev/null \
        || { echo "lint: unreferenced figure: $png"; fail=1; }
done

[ "$fail" -eq 0 ] && echo "lint: OK"
exit "$fail"
