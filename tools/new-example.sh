#!/bin/bash
# Scaffold a new example from the 03-modes template.
#
#   tools/new-example.sh 07-camera Camera
set -eu

SLUG="${1:?usage: tools/new-example.sh <NN-slug> <PdxName>}"
NAME="${2:?usage: tools/new-example.sh <NN-slug> <PdxName>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/examples/03-modes"
DST="$ROOT/examples/$SLUG"

[ -d "$SRC" ] || { echo "template 03-modes missing" >&2; exit 1; }
[ -e "$DST" ] && { echo "$DST already exists" >&2; exit 1; }

cp -r "$SRC" "$DST"
printf 'NAME := %s\ninclude ../../example.mk\n' "$NAME" > "$DST/Makefile"
BUNDLE="com.sdwfrost.book.$(echo "$SLUG" | tr -d '-')"
sed -i '' -e "s/^name=.*/name=$NAME/" -e "s/^bundleID=.*/bundleID=$BUNDLE/" "$DST/source/pdxinfo"
echo "created examples/$SLUG (bundleID $BUNDLE)"
