local scene = require "scene.init"
local const = require "const"
local gui = require "gui"
local lang  = require "lang"
local strings = require "cc.strings"

---@class screen.popup.help.self : scene
local self = scene.new()

function self.init(state)
    local w, h = state.win.getSize()
    self.oldW = w
    self.oldH = h

    self.halfWidth = 22
    self.halfHeight = 6
    self.listWidth = 10

    self.bg = state.win.getBackgroundColor()

    self.rep = 4 / const.tickrate
    self.lastStep = os.clock() - self.rep

    ---@class popup.help.entry
    ---@field title string
    ---@field text string?

    ---@type popup.help.entry[]
    self.entries = {
        {
            title = "help.interface.category"
        },
        {
            title = "help.interface.planner.title",
            text = "help.interface.planner.desc"
        },
        {
            title = "help.interface.hud.title",
            text = "help.interface.hud.desc"
        },
        {
            title = "help.gameplay.category"
        },
        {
            title = "help.gameplay.randomizer.title",
            text = "help.gameplay.randomizer.desc"
        },
        {
            title = "help.gameplay.obstacles.title",
            text = "help.gameplay.obstacles.desc"
        }
    }

    self.selected = 2

    if self.previousScr then
        local id = self.previousScr.id
        if id == "planner" then
            self.selected = 2
        elseif id == "randomizer" then
            self.selected = 5
        end
    end
end

function self.tick(state, deltaTime)
    if state.pressed[keys["enter"]] then
        local target = self.previousScr or state.scenes.title
        target.continue(state)
        scene.switchTo(state, target)
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
            local x = xCenter + self.halfWidth-3-#label
            if event[2] == 1 then
                if event[3] >= x and event[3] <= x+6 and event[4] == yCenter + self.halfHeight - 1 then
                    local target = self.previousScr or state.scenes.title
                    target.continue(state)
                    scene.switchTo(state, target)
                end
            end
        end
    end

    local cooldown = os.clock() - self.lastStep > self.rep

    if (state.pressed[keys["up"]] or state.pressed[keys["w"]]) and self.selected > 1 then
        if cooldown then 
            local selected = self.selected
            repeat
                selected = selected - 1
            until not self.entries[selected] or self.entries[selected].text

            if not self.entries[selected] or not self.entries[selected].text then
                selected = 1
                while not self.entries[selected].text do
                    selected = selected + 1
                end
            end

            self.selected = selected
            self.lastStep = os.clock()
        end
    elseif (state.pressed[keys["down"]] or state.pressed[keys["s"]]) and self.selected < #self.entries then
        if cooldown then 
            local selected = self.selected

            repeat
                selected = selected + 1
            until not self.entries[selected] or self.entries[selected].text

            if not self.entries[selected] or not self.entries[selected].text then
                selected = #self.entries
                while not self.entries[selected].text do
                    selected = selected - 1
                end
            end

            self.selected = selected
            self.lastStep = os.clock()
        end
    else
        self.lastStep = 0
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

    -- Window

    term.setBackgroundColor(self.bg)

    local w, h = term.getSize()
    local xCenter = math.floor(w/2 + 1)
    local yCenter = math.floor(h/2 + 1)

    term:fill(
        xCenter - self.halfWidth + self.listWidth + 1,
        yCenter - self.halfHeight,
        xCenter + self.halfWidth,
        yCenter + self.halfHeight - 1,
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

    -- Left side (list)

    term:fill(
        xCenter - self.halfWidth,
        yCenter - self.halfHeight,
        xCenter - self.halfWidth + self.listWidth,
        yCenter + self.halfHeight - 1,
        colors.white,
        colors.black,
        ' '
    )

    for i, entry in ipairs(self.entries) do
        local label = lang.translatable(entry.title)
        if #label >= self.listWidth then
            label = label:sub(1, self.listWidth-1) .. "\187"
        end

        local offset = 1
        local color = self.selected == i and colors.white or colors.blue

        if not self.entries[i].text then
            offset = 0
            color = colors.gray
        end

        term.setBackgroundColor(self.selected == i and colors.blue or colors.white)
        term:label(
            xCenter - self.halfWidth + offset,
            yCenter - self.halfHeight + i,
            color,
            label, false
        )
    end

    -- Right side (current desc)

    term.setBackgroundColor(colors.lightGray)

    term:label(
        xCenter - self.halfWidth + self.listWidth + 2,
        yCenter - self.halfHeight + 1,
        colors.black,
        lang.translatable(self.entries[self.selected].title),
        true
    )

    local width = self.halfWidth * 2 - 3 - self.listWidth

    local label = lang.translatable(self.entries[self.selected].text)
    local lines = strings.wrap(label, width)

    for i, line in ipairs(lines) do
        if i >= self.halfHeight * 2 - 4 and #lines > i then
            line = line:sub(1, width-1) .. "\187"
        end
        term:label(
            xCenter - self.halfWidth + self.listWidth + 2,
            yCenter - self.halfHeight + 2 + i,
            colors.gray,
            line,
            false
        )
        if i >= self.halfHeight * 2 - 4 then break end
    end

    -- Exit btn

    local label = lang.translatable("title.btn.exit")
    term:btnSubtle(xCenter + self.halfWidth-3-#label, yCenter + self.halfHeight - 1, colors.gray, colors.black, label)
end

return self