# Shared rules for the book's example projects. Each example's Makefile sets
# NAME (the pdx name) and includes this file:
#
#     NAME := Hello
#     include ../../example.mk
#
# Targets:
#   book    - instrumented build (SMOKE_BUILD=true, shot capture) for tools/shoot.sh
#   release - clean build in out/<NAME>.pdx, harness disabled
#   run     - build release and open it in the Playdate Simulator
#
# Staging always uses `cp -r`: a bare `cp source/*` silently skips
# subdirectories and pdc will happily build the incomplete bundle.

SDK    := $(HOME)/Developer/PlaydateSDK
ROOT   := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
SLUG   := $(notdir $(CURDIR))
STAGE  := $(ROOT)/build/$(SLUG)
FIGRAW := $(ROOT)/figures/$(SLUG)/raw

book:
	rm -rf $(STAGE)/book
	mkdir -p $(STAGE)/book/source "$(FIGRAW)"
	cp -r source/* $(STAGE)/book/source/
	cp $(ROOT)/examples/_shared/bookharness.lua $(STAGE)/book/source/
	printf 'SMOKE_BUILD = true\nSHOT_PREFIX = "%s/"\n' '$(FIGRAW)' > $(STAGE)/book/source/bookflag.lua
	pdc -q $(STAGE)/book/source $(STAGE)/book/$(NAME)Book.pdx

release:
	rm -rf $(STAGE)/release out
	mkdir -p $(STAGE)/release/source out
	cp -r source/* $(STAGE)/release/source/
	cp $(ROOT)/examples/_shared/bookharness.lua $(STAGE)/release/source/
	printf 'SMOKE_BUILD = false\nSHOT_PREFIX = ""\n' > $(STAGE)/release/source/bookflag.lua
	pdc -q $(STAGE)/release/source out/$(NAME).pdx

run: release
	open "$(SDK)/bin/Playdate Simulator.app" --args "$(CURDIR)/out/$(NAME).pdx"

clean:
	rm -rf $(STAGE) out

.PHONY: book release run clean
