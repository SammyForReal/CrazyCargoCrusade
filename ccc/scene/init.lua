local scene = {}

---Returns a new scene object
---@return scene
function scene.new()
    ---@class scene
    local tmp = {
        ---@type Color
        shadow = colors.black,
        ---@type scene|nil
        previousScr = nil,
        ---@type string
        id = "none",

        ---Renders a frame
        ---@param state state
        ---@param term ExTerm
        ---@param deltaTime number
        render = function(state, term, deltaTime)
        
        end,

        ---Renders a frame
        ---@param state state
        ---@param deltaTime number
        tick = function(state, deltaTime)

        end,

        ---Called after switching to this scene.
        ---@param state state
        init = function(state)

        end,

        ---Called when this scene is going to be paused.
        ---@param state state
        pause = function(state)

        end,

        ---Called when the scene was paused, before it will run again.
        ---@param state state
        continue = function(state)

        end
    }

    return tmp
end

---Switches to a different scene.
---@param state state
---@param newScr scene
function scene.switchTo(state, newScr)
    newScr.previousScr = state.currentScr
    state.nextScr = newScr
end

return scene