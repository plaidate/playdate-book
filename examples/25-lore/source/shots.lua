-- Figure script: the tour is a PLAYTHROUGH, not four screens.
-- Frames 1-149 walk the chunked overworld east across a chunk
-- seam; 150 starts the story coroutine (dialog -> choice ->
-- battle); 460 opens the pause menu and drills into it; 620 arms
-- the stick and spawns a field foe to charge and swing at. The
-- gates in config.lua hold each window open long enough to
-- photograph. No `script` function here: this example's autopilot
-- lives in input.lua, on the seam a shipped Lore game uses.
Shots = {
    seed = 1,
    last = 800,
    shots = {
        ["lore-chunks"] = 120,
        ["lore-dialog"] = 230,
        ["lore-battle"] = 330,
        ["lore-menu"] = 540,
        ["lore-charge"] = 680,
        ["lore-swing"] = 701,
    },
}
