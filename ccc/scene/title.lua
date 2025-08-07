local scene = require "scene.init"
local const = require "const"
local gui = require "gui"
local lang  = require "lang"
local palette = require "palette"

---@class screen.title.self : scene
local self = scene.new()

local function exit(state)
    state.running = false
end

local function randomizer(state)
    self.transition = 1
end

local function story(state)
    scene.switchTo(state, require "scene.popup.nostory")
end

function self.init(state)
    palette.apply(state.win)

    self.transition = nil

    ---@class screen.title.menu
    self.menu = {
        --[[{
            title = "title.btn.story",
            fgColor = colors.black,
            bgColor = colors.yellow,
            bgClickColor = colors.white,
            state = false,
            func = story
        },
        {
            title = "title.btn.marathon",
            fgColor = colors.white,
            bgColor = colors.blue,
            bgClickColor = colors.lightBlue,
            state = false,
            func = function () end
        },]]
        {
            title = "title.btn.randomizer",
            fgColor = colors.white,
            bgColor = colors.green,
            bgClickColor = colors.lime,
            state = false,
            func = randomizer
        },
        {
            title = "title.btn.exit",
            fgColor = colors.white,
            bgColor = colors.red,
            bgClickColor = colors.magenta,
            state = false,
            func = exit
        }
    }
end

local function yStart(h)
    return math.floor(h/6-1)
end

local function getTitleOptions(w)
    return {
        scale = 1,
        wrapWidth = w*2,
        dx = 2,
        dy = 2,
        textAlign = "center",
        anchorHor = "center",
        anchorVer = "top"
    }
end

local function setBtnState(event)
    if event == "mouse_click" then
        return true
    elseif event == "mouse_up" then
        return false
    end

    return nil
end

local function mouseEvent(state, event, xCenter, yTop)
    for i, entry in ipairs(self.menu) do
        local label = lang.translatable(entry.title)

        local left = xCenter - #label/2
        local top = yTop+(i*2)

        if event[3] >= left and event[3] <= left+#label+1 and event[4] == top then
            local newBool = setBtnState(event[1])
            if type(newBool) ~= "nil" then
                if not newBool and entry.state then
                    entry.func(state)
                end
                entry.state = newBool
            end
        end
    end
end

function self.tick(state, deltaTime)
    if self.transition and self.transition <= -0.5 then
            scene.switchTo(state, state.scenes.planner)
        return
    end

    local w, h = term.getSize()
    local xCenter = math.floor(w/2)
    local _, titleHeight = state.win.calculateBigFont("\159", getTitleOptions(w))
    titleHeight = titleHeight / 3
    local yTop = math.floor(yStart(h) + titleHeight) + 2

    if #state.mouseEvents > 0 then
        for i=1, #state.mouseEvents do
            local event = state.mouseEvents[1]
            table.remove(state.mouseEvents, 1)
            
            if event[2] == 1 then
                mouseEvent(state, event, xCenter, yTop)
            end
        end
    end
end

local function cargoLineColor(i)
    return i % 2 == 0 and colors.orange or colors.brown
end

---Draws the main menu.
---@param term ExTerm
local function renderMenu(term)
    local w, h = term.getSize()
    local xCenter = math.floor(w/2)
    local _, titleHeight = term.calculateBigFont("\159", getTitleOptions(w))
    titleHeight = titleHeight / 3
    local yTop = math.floor(yStart(h) + titleHeight) + 2

    local longestW = 0
    local lengthH = #self.menu
    for _, entry in ipairs(self.menu) do
        local length = #lang.translatable(entry.title)
        if length > longestW then longestW = length end
    end
    longestW = math.floor(longestW/2 + 0.5) + 1

    -- Background

    term:fill(
        xCenter - longestW - 1,
        yTop,
        xCenter + longestW + 2,
        yTop + lengthH*2 + 2,
        colors.black, colors.white,
        " "
    )

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.lightGray)

    -- Corners

    term.setCursorPos(xCenter - longestW - 1, yTop)
    term.write("\183")
    term.setCursorPos(xCenter - longestW - 1, yTop + lengthH*2 + 2)
    term.write("\183")
    term.setCursorPos(xCenter + longestW + 2, yTop)
    term.write("\183")
    term.setCursorPos(xCenter + longestW + 2, yTop + lengthH*2 + 2)
    term.write("\183")

    -- Menu
    for i, entry in ipairs(self.menu) do
        local label = lang.translatable(entry.title)
        term:btnNormal(
            xCenter - #label/2,
            yTop+(i*2),
            entry.bgColor,
            entry.bgClickColor,
            colors.gray,
            entry.fgColor,
            label,
            entry.state
        )
    end
end

function self.render(state, term, deltaTime)
    if self.transition then
        state.water = false
        for name, _ in pairs(palette.GNOME) do
            palette.fadeFor(term, colors[name], palette.GNOME[name], palette.GNOME["black"], 1-math.max(0, self.transition))
        end
        self.transition = math.max(-0.5, self.transition - 0.02)
    else
        state.water = true
    end
    local w, h = term.getSize()

    -- Background
    local options = getTitleOptions(w)

    term.setBackgroundColor(colors.black)
    term:clear()

    for i=2,h-1 do
        term.setBackgroundColor(cargoLineColor(i))
        term.setCursorPos(2, i)
        term.write((" "):rep(w-2))
    end

    -- Color flickering
    local color = (os.clock() % 0.5 < 0.25) and colors.white or colors.yellow

    -- Title

    local label = lang.translatable("title")
    local _, height = term.calculateBigFont(label, options)
    local yStart = yStart(h)

    term.setBackgroundColor(colors.red)
    term.setTextColor(color)

    term:writeBig(
       label,
        w/2,
        yStart,
        options
    )

    for i=1,height do
        local y = yStart + i - 1
        local txt, fg, bg = term.getLine(y)

        fg = fg:gsub(gui.blit[colors.red], gui.blit[cargoLineColor(y)])
        bg = bg:gsub(gui.blit[colors.red], gui.blit[cargoLineColor(y)])

        term.setCursorPos(1, y)
        term.blit(txt, fg, bg)
    end

    -- Widgets
    term.setBackgroundColor(colors.black)

    local version = lang.translatable("version", const.version[1], const.version[2], const.version[3])
    term:label(w-#version+1, h, colors.gray, version, false)

    renderMenu(term)
    term:border(2, 2, w-1, h-1, colors.orange, true)

    --term:btnSubtle(w-6, 1, colors.gray, colors.lightGray, 'cfg')

    term.setBackgroundColor(colors.brown)
end

return self