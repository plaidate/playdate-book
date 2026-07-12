# Playdate Game Development in Lua — book build.
#
#   make figures   rebuild + re-shoot examples whose sources changed (serial)
#   make check     force re-shoot everything
#   make render    quarto render (HTML + Typst PDF) using committed figures
#   make book      figures + render
#   make lint      snip/figure cross-checks
#
# The Playdate Simulator is single-instance: figure runs are strictly serial.

.NOTPARALLEL:

EXDIRS := $(sort $(wildcard examples/[0-9]*))

figures:
	@for ex in $(EXDIRS); do \
	  slug=$$(basename $$ex); stamp=figures/$$slug/.stamp; \
	  if [ ! -f $$stamp ] || [ -n "$$(find $$ex examples/_shared tools/shoot.sh -newer $$stamp 2>/dev/null | head -1)" ]; then \
	    tools/shoot.sh $$slug || exit 1; \
	  else echo "fresh: $$slug"; fi; \
	done

check:
	rm -f figures/*/.stamp
	$(MAKE) figures

render:
	quarto render

book: figures render

lint:
	tools/lint.sh
	tools/vendor-check.sh

clean:
	rm -rf build _book

.PHONY: figures check render book lint clean
