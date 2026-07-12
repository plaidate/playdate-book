# Authoring guide (for the book's writers)

The contract for writing chapters of *Playdate Game Development in Lua*. Read
this whole file before touching a chapter.

## What this book is

An O'Reilly-caliber guide to building Playdate games in Lua. The reader is a
competent programmer who has never touched a Playdate. The examples are real,
buildable pdx projects; the figures are captured from them automatically; the
case studies come from more than sixty shipped games in `~/Projects/playdate/`.

## Voice

- Clear, direct, complete sentences. Explain *why*, not just *what*.
- Confident and concrete; light wit is fine, hype is not.
- Every API introduced gets: what it does, when to reach for it, and what
  goes wrong when you misuse it (the gotcha).
- Never invent APIs. Verify names against the SDK reference:
  `~/Developer/PlaydateSDK/Inside Playdate.html` (SDK 3.0.6). Grep it.
- No placeholders, no "TODO", no "left as an exercise".

## Chapter anatomy

1. **Opening** (2-3 paragraphs): what the reader will build and learn, and why
   it matters on this hardware.
2. **Sections** teaching the topic incrementally, each anchored in the
   chapter's example project. Code first, explanation after.
3. **Case-study sidebars** quoting the real games (see below).
4. **Gotcha callouts**: `::: {.callout-warning}` for traps,
   `::: {.callout-note}` for asides. Give callouts a `## title`.
5. **Closing summary**: "What you know now" — a short bulleted recap plus one
   sentence pointing to the next chapter.

Target 3,500–6,000 words, 4–8 figures, 6–12 listings. Chapter files are
`chapters/NN-slug.qmd` with the H1 carrying `{#sec-slug}`. Cross-reference
with `@sec-...` and `@fig-...`.

## Example projects

Each chapter has `examples/NN-slug/`:

```
examples/10-crank/
├── Makefile            # two lines: NAME := Crank / include ../../example.mk
└── source/
    ├── main.lua        # imports: CoreLibs, then "shots", then "bookharness"
    ├── shots.lua       # figure script (below)
    ├── pdxinfo         # bundleID=com.sdwfrost.book.10crank  (slug minus dashes)
    └── …               # more modules if the chapter teaches them
```

Conventions (they mirror the shipped games — teach them as you use them):

- 400x240, 1-bit, 30 fps, fixed `DT = 1/30`.
- Multi-file examples use module-per-concern **globals** (`Input`, `Draw`,
  `Game` …) because `import` shares one global environment.
- Keep code lines ≤ 70 chars (PDF width). Comment like the shipped games:
  sparse, load-bearing.
- **Import order matters**: `import "shots"` then `import "bookharness"`
  (the harness reads `Shots` at load time to seed the RNG).

### The harness seam

All input flows through one place, and the bot is consulted first:

```lua
local bot = Harness.input(frame)          -- nil for human play
local left = bot and bot.left or playdate.buttonIsPressed(playdate.kButtonLeft)
```

The bot table's keys are whatever your `shots.lua` script returns — name them
for the example's needs (`left`, `aPressed`, `crank`, …). Count interesting
events with `Harness.count("kills")`.

`main.lua` ends with the standard wrapper:

```lua
local realUpdate = playdate.update
function playdate.update()
    frame = frame + 1
    Harness.frame(frame, realUpdate)
end
```

### shots.lua

```lua
Shots = {
    seed = 1,                      -- fixed RNG seed: figures are deterministic
    last = 240,                    -- frames to run before reporting done
    shots = {                      -- figure-name -> frame captured AFTER draw
        ["crank-aim"] = 90,
        ["crank-fire"] = 200,
    },
    script = function(frame)       -- synthetic input for this frame
        return { crank = frame * 3, aPressed = (frame == 180) }
    end,
}
```

Figure names become `figures/NN-slug/<name>.png` (800x480). Reference them
from the chapter as:

```markdown
![Caption.](../figures/10-crank/crank-aim.png){#fig-crank-aim}
```

The names in `shots.lua` and the chapter MUST match exactly. Choose shot
frames so each figure clearly shows what the prose claims.

## Listings: the snip shortcode

All runnable code shown in a chapter is extracted from the example source:

```
{{< snip 10-crank/source/input.lua crank-aim >}}     ← marked region
{{< snip 10-crank/source/shots.lua >}}               ← whole file
```

Mark regions in the source:

```lua
-- snip: crank-aim
...code...
-- endsnip
```

A missing region fails the render. Inline fenced ```lua blocks are allowed
ONLY for (a) deliberately-broken anti-patterns (say so in prose) and
(b) quotes from the real games, which must carry a first-line comment with
their origin, e.g. `-- whine/source/draw.lua:24`.

## Case studies

Quote the shipped games where the topic was battle-tested. Keep excerpts
short (≤ 12 lines), attribute with `repo/path.lua:line`, and tell the story:
what the game needed, what broke, what the pattern solved. Good sources per
topic are listed in the chapter briefs.

## Build & verify (what YOU run)

```
make -C examples/NN-slug book     # MUST pass — pdc catches syntax errors
```

Do **NOT** run `tools/shoot.sh`, the Playdate Simulator, or `quarto render` —
the simulator is single-instance and the orchestrator runs those serially
after your work lands. Your definition of done: example compiles with pdc,
chapter qmd written, snip regions exist, figure names consistent between
shots.lua and the chapter.

## Fact-Forcing Gate

If a tool call fails with "[Fact-Forcing Gate]", state the requested facts in
plain text (callers/importers, schemas, the user's instruction) and then
retry the exact same call. It always passes on the retry.
