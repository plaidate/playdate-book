-- Figure script: watch the scene flat, flip the FX switch just
-- before a bounce so the juiced shot lands mid-shake with live
-- particles, then visit the easing gallery.
Shots = {
    seed = 15,
    last = 220,
    shots = {
        ["scene-plain"] = 62,     -- a collect with FX off
        ["scene-juiced"] = 152,   -- mid-shake, particles alive
        ["easing-gallery"] = 210, -- the curve gallery
    },
    script = function(frame)
        return {
            toggleFx = (frame == 140),
            gallery = (frame == 200),
        }
    end,
}
