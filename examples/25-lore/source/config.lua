-- Tour tunables. Every beat of the scripted playthrough is pinned
-- to a frame, so the figures land on the same pixels every run.

C = {
    DT = 1 / 30,        -- fixed step, s

    WORLD_W = 120,      -- overworld width, tiles  (1920 px)
    WORLD_H = 90,       -- overworld height, tiles (1440 px)
    ROAD_Y = 17,        -- the east-west road the tour walks
    CANOPY_X0 = 44,     -- walk-behind canopy band, tiles
    CANOPY_X1 = 56,
    START_X = 30,       -- player spawn, tiles
    WARDEN_X = 54,      -- the NPC waiting up the road

    PLAYER_SPEED = 70,  -- px/s on speed-1 ground

    -- the playthrough clock (frames)
    WALK_END = 149,     -- screen 1: chunked field + cache readout
    STORY_F = 150,      -- Script.run: say -> ask -> battle
    UI_GO = 250,        -- the bot may answer the dialog/choice
    BATTLE_GO = 360,    -- ... and the battle command window
    MENU_F = 460,       -- screen 3: open the pause menu
    MENU_A = 480,       -- ... pick Items
    LIST_A = 510,       -- ... pick the herb
    CHOOSE_BACK = 560,  -- ... and back out again
    ACTION_F = 620,     -- screen 4: arm the stick, spawn a foe
    CHARGE_F = 630,     -- hold A: the charge ring fills
    SWING_F = 700,      -- release: the arc hitbox lands
    CACHE_OFF = 160,    -- chunk overlay is screen one's furniture
}
