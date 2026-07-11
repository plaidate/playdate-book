-- The lab's page framework, plus the material pages 2-4 exhibit:
-- a class() hierarchy, a plain-table critter, and two traps.

-- snip: gfxconst
local gfx <const> = playdate.graphics
-- endsnip

-- snip: class
class("Critter").extends()   -- needs import "CoreLibs/object"

function Critter:init(name)
    Critter.super.init(self)
    self.name = name
end

function Critter:speak()
    return self.name .. " says ..."
end

class("Hound").extends(Critter)

function Hound:speak()       -- override: calls dispatch dynamically
    return self.name .. " says WOOF"
end
-- endsnip

-- snip: plaintable
-- The same critter without class(): a table and a constructor.
local function newCritter(name)
    local c = { name = name }
    function c:speak()
        return self.name .. " says ..."
    end
    return c
end
-- endsnip

local any <const> = Critter("Any")
local rex <const> = Hound("Rex")
local flat <const> = newCritter("Flat")

-- snip: assertleak
-- assert returns ALL of its arguments on success, so the message
-- becomes a surprise second element in the table constructor.
local speed = 4
local leaky = { assert(speed, "speed missing") }
-- #leaky == 2, and leaky[2] == "speed missing"
-- endsnip

-- pdc adds compound assignment to the language.
local opsDemo = 10
opsDemo += 5

Lab = { page = 1, pages = 4 }

function Lab.turn(d)
    Lab.page = math.max(1, math.min(Lab.pages, Lab.page + d))
end

local function line(i, text)
    gfx.drawText(text, 16, 44 + i * 24)
end

local function title(text)
    gfx.drawText("*" .. text .. "*", 16, 12)
    gfx.drawLine(16, 34, 384, 34)
end

local pages = {}

-- snip: page-shared
pages[1] = function()
    title("1. ONE GLOBAL WORLD")
    line(0, 'SHARED = "' .. SHARED .. '"')
    line(1, Beta.report())
    line(2, Alpha.report() .. "  (imported twice, ran once)")
    line(3, "_G.secret = " .. tostring(_G.secret)
        .. "  (locals stay file-private)")
end
-- endsnip

-- snip: page-sandbox
pages[2] = function()
    title("2. THE SANDBOX, AND THE ADDITIONS")
    line(0, "type(require) = " .. type(require))
    line(1, "type(os) = " .. type(os)
        .. "   type(io) = " .. type(io))
    line(2, "type(playdate.file.open) = "
        .. type(playdate.file.open))
    line(3, "type(table.create) = " .. type(table.create))
    line(4, "opsDemo = 10; opsDemo += 5  -->  " .. opsDemo)
end
-- endsnip

pages[3] = function()
    title("3. CLASS() VS PLAIN TABLES")
    line(0, "any:speak()  -->  " .. any:speak())
    line(1, "rex:speak()  -->  " .. rex:speak())
    line(2, "rex:isa(Critter)  -->  " .. tostring(rex:isa(Critter)))
    line(3, "flat:speak()  -->  " .. flat:speak())
end

-- snip: page-traps
pages[4] = function()
    title("4. TRAPS")
    line(0, 'leaky = { assert(speed, "speed missing") }')
    line(1, "#leaky = " .. #leaky
        .. "   leaky[2] = " .. tostring(leaky[2]))
    line(2, "missing glyphs:  [ · ]  [ — ]")
    line(3, "present glyphs:  [ - ]  [ Ⓐ ]  [ Ⓑ ]")
end
-- endsnip

function Lab.draw()
    gfx.clear(gfx.kColorWhite)
    pages[Lab.page]()
    gfx.drawTextAligned("page " .. Lab.page .. "/" .. Lab.pages
        .. "   flip with the d-pad", 200, 218, kTextAlignment.center)
end
