-- Figure script: four 90-frame screens. One grid impulse at
-- frame 20 (shot just after, then again as the ripple spreads),
-- the spinning mesh at 150, the wrap field twice (mid-chase and
-- straddling the seam), and the fx pool mid-explosion at 310.
Shots = {
    seed = 1,
    last = 360,
    shots = {
        ["grid-impulse"] = 24,
        ["grid-ripple"] = 40,
        ["wire-mesh"] = 150,
        ["wrap-arrow"] = 206,
        ["wrap-seam"] = 221,
        ["fx-burst"] = 310,
    },
    script = function(frame)
        return {
            push = (frame == 20),
            boom = (frame == 285 or frame == 302),
        }
    end,
}
