local json = require "json"
local savestate = {}

local PATH = "/.dev.kleinbox.ccc.game.json"

function savestate.load(state)
    local file = fs.open(PATH, "r")
    ---@class savestate
    ---@field randomizer table<number, number[]>?
    if not file then return {
        randomizer = {
            -- [seed] = {}
        }
    } end

    local content = file.readAll()
    file.close()

    content = json.decode(content)
    state.savestate = content
end

function savestate.save(state)
    local file = fs.open(PATH, "w")
    if not file then return end

    local content = json.encode(state.savestate)
    file.write(content)
    file.close()

    state.saved = true
end

return savestate