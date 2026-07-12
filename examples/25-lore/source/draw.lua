-- The field's draw pass. The house frame order: camera on, chunks,
-- painter-sorted actors, the canopy layer (walk-behind), laction's
-- overlays, popups, marker, camera off, HUD. Screen one adds the
-- chunk-boundary overlay and the cache readout.

local gfx = playdate.graphics

Draw = {}

-- snip: demo-frame
function Draw.frame()
    Cam.apply()
    Map.draw(Cam.x, Cam.y)          -- 1-4 blits, any world size
    Cache.frame(Cam.x, Cam.y)       -- the model, for the readout
    Act.drawAll()                   -- y-sorted, stable
    Map.drawOverhead(Cam.x, Cam.y)  -- canopy over the actors
    Action.draw()                   -- telegraphs, HP bars, the arc
    if Game.showCache then Draw.chunkGrid() end
    Draw.chargeRing()
    UI.drawPopups()
    Kit.marker(G.player.x, G.player.y - 16, G.t)
    Cam.done()
    Draw.hud()
end
-- endsnip

-- world space: the chunk lattice the camera is reading from
function Draw.chunkGrid()
    local c0x, c1x, c0y, c1y = Cache.range(Cam.x, Cam.y)
    gfx.setLineWidth(3)
    for cy = c0y, c1y do
        for cx = c0x, c1x do
            local x, y = cx * Map.CPW, cy * Map.CPH
            gfx.setColor(gfx.kColorWhite)
            gfx.drawRect(x + 1, y + 1, Map.CPW - 2, Map.CPH - 2)
            local tag = "c" .. cx .. "," .. cy
            local w = gfx.getTextSize(tag)
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(x + 6, y + 6, w + 8, 20)
            Gfx.text(tag, x + 10, y + 8)
        end
    end
    gfx.setLineWidth(1)
    gfx.setColor(gfx.kColorBlack)
end

-- world space: the SoM charge meter as a ring on the player
function Draw.chargeRing()
    local c = Action.charge01
    if c <= 0 then return end
    local x = math.floor(G.player.x)
    local y = math.floor(G.player.y)
    gfx.setLineWidth(3)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawCircleAtPoint(x, y, 16)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawArc(x, y, 16, 0, 360 * c)
    gfx.setLineWidth(1)
    gfx.setColor(gfx.kColorBlack)
end

-- screen space: title row, purse, stack depth, cache panel
function Draw.hud()
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 400, 16)
    Kit.text("*lore*", 4, 0)
    Kit.text("STACK " .. #Kit.stack, 150, 0)
    local g = UI.goldStr()
    Kit.text(g, 396 - gfx.getTextSize(g), 0)
    local m = Party.member(1)
    if Action.weapon and m then
        UI.hpBar(4, 226, 60, m.hp, m.maxhp)
    end
    if not Game.showCache then return end
    Kit.panel(4, 20, 126, 152)
    Kit.text("LRU SLOTS", 12, 24)
    for i = 1, Map.POOL do
        local r = Cache.slots[i]
        local tag = "-"
        if r.key >= 0 then
            tag = "c" .. (r.key % 4096) .. ","
                .. math.floor(r.key / 4096)
        end
        Kit.text(i .. "  " .. tag, 12, 26 + i * 14)
    end
    Kit.panel(4, 176, 126, 58)
    Kit.text("BLITS  " .. Cache.blits, 12, 180)
    Kit.text("BUILDS " .. Cache.builds, 12, 196)
    Kit.text("MAP    " .. Map.builds
        .. (Cache.ok and "" or " !!"), 12, 212)
end
