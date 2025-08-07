local scene = require "scene.init"
local const = require "const"
local gui = require "gui"
local lang  = require "lang"
local strings = require "cc.strings"
local palette = require "palette"

---@class screen.popup.scoreboard.self : scene
local self = scene.new()

function self.init(state)
    local w, h = state.win.getSize()
    self.oldW = w
    self.oldH = h

    self.transition = nil

    self.halfWidth = 22
    self.halfHeight = 6

    self.bg = state.win.getBackgroundColor()
end

function self.tick(state, deltaTime)
    if self.transition and self.transition <= -0.5 then
        scene.switchTo(state, state.scenes.title)
        return
    end

    if state.pressed[keys["enter"]] then
        self.transition = 1
    end

    if #state.mouseEvents > 0 then
        local w, h = term.getSize()
        local xCenter = math.floor(w/2 + 1)
        local yCenter = math.floor(h/2 + 1)
        local width = self.halfWidth * 2 - 2

        for i=1, #state.mouseEvents do
            local event = state.mouseEvents[1]
            table.remove(state.mouseEvents, 1)

            local label = lang.translatable("title.btn.exit")
            local x = xCenter - self.halfWidth + width-1-#label
            if event[2] == 1 then
                if event[3] >= x and event[3] <= x+#label+1 and event[4] == yCenter + self.halfHeight - 1 then
                    self.transition = 1
                end
            end
        end
    end
end

local function toTime(seconds)
    local minutes = math.floor(seconds / 60)
    seconds = seconds % 60
    local remainingSeconds = math.floor(seconds)
    local milliseconds = math.floor((seconds - remainingSeconds) * 1000)

    return ("%02d:%02d:%02d"):format(minutes, remainingSeconds, milliseconds):sub(1,8)
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

    if w ~= self.oldW or h ~= self.oldH and self.previousScr then
        self.previousScr.render(state, term, deltaTime)
        self.bg = term.getBackgroundColor()
        self.oldW = w
        self.oldH = h
    end

    term.setBackgroundColor(self.bg)

    local w, h = term.getSize()
    local xCenter = math.floor(w/2 + 1)
    local yCenter = math.floor(h/2 + 1)

    term:fill(
        xCenter - self.halfWidth,
        yCenter - self.halfHeight,
        xCenter + self.halfWidth,
        yCenter + self.halfHeight,
        colors.lightGray,
        colors.black,
        ' '
    )

    local height = yCenter + self.halfHeight - 3
    term:fill(
        xCenter - self.halfWidth + 1,
        yCenter - self.halfHeight + 4,
        xCenter + self.halfWidth - 2,
        height,
        colors.black,
        colors.green,
        ' '
    )

    term:frame(
        xCenter - self.halfWidth - 1,
        yCenter - self.halfHeight - 1,
        self.halfWidth * 2 + 2,
        self.halfHeight * 2 + 2,
        colors.blue,
        colors.black
    )

    term.setBackgroundColor(colors.lightGray)

    term:label(
        xCenter - self.halfWidth + 1,
        yCenter - self.halfHeight + 1,
        colors.black,
        lang.translatable("popup.scoreboard.title"),
        true
    )

    local width = self.halfWidth * 2 - 2

    local label = lang.translatable("popup.scoreboard.desc")
    local lines = strings.wrap(label, width)

    for i, line in ipairs(lines) do
        if i >= self.halfHeight * 2 - 4 and #lines > i then
            line = line:sub(1, width-1) .. "\187"
        end
        term:label(
            xCenter - self.halfWidth + 1,
            yCenter - self.halfHeight + 2 + i,
            colors.gray,
            line,
            false
        )
        if i >= self.halfHeight * 2 - 4 then break end
    end

    term.setBackgroundColor(colors.black)
    for i,score in ipairs(state.savestate.randomizer[""..state.seed]) do
        if i > height then break end
        term:label(
            xCenter - self.halfWidth + 1,
            yCenter - self.halfHeight + 3 + i,
            colors.green,
            toTime(score),
            false
        )
    end

    term.setBackgroundColor(colors.lightGray)
    term:label(
        xCenter - self.halfWidth + 1,
        yCenter + self.halfHeight - 2,
        colors.gray,
        lang.translatable("popup.scoreboard.map", lang.translatable("popup.scoreboard.randomizer", ""..state.seed)):sub(1, width),
        false
    )

    local label = lang.translatable("title.btn.exit")
    term:btnSubtle(xCenter - self.halfWidth + width-1-#label, yCenter + self.halfHeight - 1, colors.gray, colors.black, label)
end

return self