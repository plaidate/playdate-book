# Playdate Game Development in Lua

A book-length guide to building [Playdate](https://play.date) games in Lua —
six parts, twenty chapters, five appendices. Every chapter has a runnable
example project, and every screenshot in the book is captured automatically
from the very example it illustrates.

Built with [Quarto](https://quarto.org): renders to a chaptered HTML site and
a print-ready PDF from the same Markdown source.

## Build

```sh
make render    # HTML site + PDF into _book/ (uses committed figures)
make figures   # rebuild + re-shoot examples whose sources changed
make book      # figures + render
make check     # force re-shoot everything (full headless smoke pass)
make lint      # listing/figure cross-checks
```

Requirements: Quarto ≥ 1.4, the Playdate SDK (`pdc` on PATH, Simulator for
`make figures`), ImageMagick. See Appendix C for the headless-simulator
prerequisites.

## Layout

- `chapters/` — the book text (Quarto `.qmd`)
- `examples/NN-slug/` — one runnable pdx project per chapter
  (`make -C examples/NN-slug run` builds and opens it in the Simulator)
- `figures/` — committed screenshots, auto-captured at 2x by `tools/shoot.sh`
- `examples/_shared/bookharness.lua` — the capture/test harness
  (documented in Chapter 18 and Appendix D)
- `_extensions/snip/` — listings are extracted from the example sources at
  render time; a listing that drifts from the code fails the build

All code listings shown in the book compile and run; the figure pipeline
doubles as a smoke test (any runtime error in any example fails
`make figures`).

## License

The book's text and figures are [CC BY 4.0](LICENSE-CC-BY-4.0); all code
(the examples, tools, the snip extension, and the listings in the text)
is [MIT](LICENSE). Playdate is a registered trademark of Panic Inc.;
this book is not affiliated with or endorsed by Panic.
