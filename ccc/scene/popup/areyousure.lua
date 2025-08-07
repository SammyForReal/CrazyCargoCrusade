local scene = require "scene.init"
local const = require "const"
local gui = require "gui"
local lang  = require "lang"
local strings = require "cc.strings"

---@class screen.popup.areyousure.self : scene
local self = scene.new()

function self.init(state)
    local w, h = state.win.getSize()
    self.oldW = w
    self.oldH = h

    self.halfWidth = 21
    self.halfHeight = 4

    self.bg = state.win.getBackgroundColor()
end

function self.tick(state, deltaTime)
    if #state.mouseEvents > 0 then
        local w, h = term.getSize()
        local xCenter = math.floor(w/2 + 1)
        local yCenter = math.floor(h/2 + 1)
        local width = self.halfWidth * 2 - 2

        local labelYes = lang.translatable("popup.btn.yes")
        local labelNo = lang.translatable("popup.btn.no")
        
        local xleftYes = xCenter - self.halfWidth + width-1-#labelYes
        local xLeftNo = xCenter - self.halfWidth + width-4-#labelNo-#labelYes

        for i=1, #state.mouseEvents do
            local event = state.mouseEvents[1]
            table.remove(state.mouseEvents, 1)

            local x = xCenter - self.halfWidth + width-6
            if event[2] == 1 then
                if event[3] >= xleftYes and event[3] <= xleftYes+#labelYes+1 and event[4] == yCenter + self.halfHeight - 1 then
                    scene.switchTo(state, state.scenes.game)
                elseif event[3] >= xLeftNo and event[3] <= xLeftNo+#labelNo+1 and event[4] == yCenter + self.halfHeight - 1 then
                    scene.switchTo(state, self.previousScr or state.scenes.title)
                end
            end
        end
    end

    if state.pressed[keys["n"]] or state.pressed[keys["backspace"]] then
        scene.switchTo(state, self.previousScr or state.scenes.title)
    elseif state.pressed[keys["y"]] or state.pressed[keys["enter"]] then
        scene.switchTo(state, state.scenes.game)
    end
end

function self.render(state, term, deltaTime)
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
        lang.translatable("popup.areyousure.title"),
        true
    )

    local width = self.halfWidth * 2 - 2

    local label = lang.translatable("popup.areyousure.desc")
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

    local labelYes = lang.translatable("popup.btn.yes")
    local labelNo = lang.translatable("popup.btn.no")
    term:btnSubtle(xCenter - self.halfWidth + width-1-#labelYes, yCenter + self.halfHeight - 1, colors.gray, colors.black, labelYes)
    term:btnSubtle(xCenter - self.halfWidth + width-4-#labelNo-#labelYes, yCenter + self.halfHeight - 1, colors.gray, colors.black, labelNo)
end

return self