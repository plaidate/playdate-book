#!/usr/bin/env python3
"""Re-vendor a Part VII example file from its upstream engine source.

    tools/revendor.py examples/24-dither/source/light.lua

A vendored file is:

    -- vendored from dither/core/light.lua (MIT)     <- line 1, the header
    <upstream, byte for byte>
    ... with `-- snip: name` / `-- endsnip` marker lines inserted ...

tools/vendor-check.sh strips the header and the markers before diffing,
so the markers may sit anywhere — but when upstream moves, the markers
have to move with it or a snip quotes the wrong lines. Doing that by
hand is how a chapter ends up quoting a function that no longer exists.

This re-anchors them: each marker remembers the CONTENT lines it sits
against (three lines of context, ignoring blanks), and is re-inserted
at the same anchor in the new upstream. It refuses to guess — an anchor
that is missing or ambiguous in the new file is reported, not placed.

The header names the upstream path, so that is where it reads from,
relative to the sibling checkout root (../ by default, $FLEET to
override).
"""
import os
import re
import sys

FLEET = os.environ.get("FLEET", os.path.join(os.path.dirname(__file__), "..", ".."))
MARKER = re.compile(r"^\s*--\s*(snip:\s*\S+|endsnip)\s*$")
HEADER = re.compile(r"^--\s*vendored from (\S+)")
CONTEXT = 3


def anchors(lines, idx, back):
    """The `CONTEXT` non-blank content lines before/after position idx."""
    out, step = [], -1 if back else 1
    i = idx + step
    while 0 <= i < len(lines) and len(out) < CONTEXT:
        if lines[i].strip():
            out.append(lines[i])
        i += step
    return out


def find(hay, needle, back):
    """Indices in `hay` where the run of lines `needle` sits."""
    hits = []
    for i in range(len(hay)):
        # only start on a content line: starting on a blank one matches
        # the same run again and reads as a false ambiguity
        if not hay[i].strip():
            continue
        j, k = i, 0
        while j < len(hay) and k < len(needle):
            if hay[j].strip():
                if hay[j] != needle[k]:
                    break
                k += 1
            j += 1
        if k == len(needle):
            hits.append(i if not back else j)
    return hits


def main(path):
    with open(path) as f:
        old = f.read().split("\n")

    m = HEADER.match(old[0])
    if not m:
        sys.exit(f"{path}: line 1 is not a `-- vendored from` header")
    src = os.path.normpath(os.path.join(FLEET, m.group(1)))
    with open(src) as f:
        new = f.read().split("\n")

    # split the old file into content + markers anchored to that content
    content, marks = [], []
    for line in old[1:]:
        if MARKER.match(line):
            marks.append({"text": line, "at": len(content)})
        else:
            content.append(line)

    def place(mk, back):
        """Where mk goes, anchored to the content on one side of it, or
        None if that side's context is gone or no longer unique."""
        # forward: the context STARTS at content[at] (the first line
        # after the marker). backward: it ENDS at content[at-1] (the
        # last line before it). anchors() steps off `idx`, so the two
        # cases seed it differently.
        ctx = anchors(content, mk["at"] - (0 if back else 1), back)
        if not ctx:
            return None
        if back:
            ctx = list(reversed(ctx))
        hits = find(new, ctx, back)
        return hits[0] if len(hits) == 1 else None

    for mk in marks:
        # a `snip:` opens before the following content; `endsnip` closes
        # after the preceding content. When the upstream edit landed ON
        # that side — the common case, since a marker brackets exactly
        # the code being revised — anchor from the other side instead.
        back = "endsnip" in mk["text"]
        at = place(mk, back)
        if at is None:
            at = place(mk, not back)
        if at is None:
            sys.exit(f"{path}: {mk['text'].strip()} cannot be anchored in "
                     f"{src} from either side — place it by hand")
        mk["new"] = at

    out = [old[0]]
    marks.sort(key=lambda k: k["new"])
    prev = 0
    for mk in marks:
        out.extend(new[prev:mk["new"]])
        out.append(mk["text"])
        prev = mk["new"]
    out.extend(new[prev:])

    with open(path, "w") as f:
        f.write("\n".join(out))
    print(f"re-vendored {path} from {src} "
          f"({len(content)} -> {len(new)} lines, {len(marks)} markers)")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    for p in sys.argv[1:]:
        main(p)
