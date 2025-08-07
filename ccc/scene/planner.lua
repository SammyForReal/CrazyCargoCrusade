local scene = require "scene.init"
local gui = require "gui"
local const = require "const"
local tiler = require "tiler"
local lang  = require "lang"
local palette = require "palette"

---@class screen.draw.self : scene
local self = scene.new()

---Draws the 2D field representation in its current state.
---@param field field
---@param term ExTerm
---@param x number
---@param y number
local function field(field, term, x, y, transparent)
    local time = os.epoch("utc")

    for fieldX=1, #field do
        for fieldY=1, #field[fieldX] do
            local tile = field[fieldX][fieldY]

            if tile ~= const.tile._UNDECIDED or not transparent then
                local blit = { tiler.tileToSymbol(tile) }

                if tiler.matchesCategory(tile, const.tile.CATEGORY_CURSOR) then
                   blit[2] = (time % 500 <= 250) and gui.blit[colors.white] or blit[2]
                elseif tiler.matchesCategory(tile, const.tile.GOAL_WAREHOUSE) then
                    blit[3] = (time % 500 <= 250) and gui.blit[colors.yellow] or blit[3]
                end

                term.setCursorPos(x + fieldX - 1, y + fieldY - 1)
                term.blit(blit[1], blit[2], blit[3])
            end
        end
    end
end

function self.init(state)
    self.id = "planner"
    state.gamemode = "randomizer"
    if self.existing then
        self.existing = false
        return
    end

    palette.apply(state.win)
    
    if self.seed and #self.seed > 0 then
        state.seed = tonumber(self.seed) or os.time(os.date("*t"))
    else
        state.seed = os.time(os.date("*t"))
    end
    math.randomseed(state.seed)

    self.seedLast = math.huge
    self.seed = ""

    self.transition = nil

    state.field = tiler.emptyField()
    self.generator = {
        co = tiler.fillField(state.field),
    }
    self.done = false

    self.rep = 2 / const.tickrate
    self.lastStep = os.clock() - self.rep

    ---@class screen.draw.cursor
    self.cursor = {
        x = const.playfield.start.x,
        y = const.playfield.start.y,
        history = {},
    }

    ---@class screen.draw.btn
    self.btn = {
        undo = false,
        done = false,
        reg = false
    }
end

function self.undo(state)
    if #self.cursor.history == 0 then return end
    local step = self.cursor.history[#self.cursor.history]

    state.field[self.cursor.x][self.cursor.y] = step.oldTile
    state.field[step.x][step.y] = step.tile

    self.cursor.x = step.x
    self.cursor.y = step.y

    table.remove(self.cursor.history, #self.cursor.history)
    self.done = false
end

function self.updateCursorHistory(state, oldTile)
    local tile = state.field[self.cursor.x][self.cursor.y]

    table.insert(self.cursor.history, {
        oldTile = oldTile,
        tile = tile,
        x = self.cursor.x,
        y = self.cursor.y,
    })
end

local function setBtnState(event)
    if event == "mouse_click" then
        return true
    elseif event == "mouse_up" then
        return false
    end

    return nil
end

local function xPosRegBtn(label, w)
    return w/2-#label/2
end

local function xPosDoneBtn(label, w)
    return xPosRegBtn(label, w) + #label + 4
end

local function xPosUndoBtn(label, w)
    return xPosRegBtn(label, w) - 4 - 4
end

local function openHelp(state)
    self.existing = true
    scene.switchTo(state, require "scene.popup.help")
end

function self.tick(state, deltaTime)
    if self.transition and self.transition <= -0.5 then
        self.existing = false
        scene.switchTo(state, state.scenes.game)
        return
    end

    -- Mouse Events
    if #state.mouseEvents > 0 then
        local w, h = state.win.getSize()
        for i=1, #state.mouseEvents do
            local event = state.mouseEvents[1]
            table.remove(state.mouseEvents, 1)
            
            if event[2] == 1 then
                local regLabel = #self.seed > 0 and self.seed or lang.translatable("planner.btn.regenerate")
                local undoLabel = lang.translatable("planner.btn.undo")
                local doneLabel = lang.translatable("planner.btn.done")

                local xUndo = xPosUndoBtn(regLabel, w)
                local xDone = xPosDoneBtn(regLabel, w)
                local xReg = xPosRegBtn(regLabel, w)

                if event[3] >= xUndo-1 and event[3] <= xUndo+#undoLabel+1 and event[4] == h-2 and #self.cursor.history > 0 then
                    local newBool = setBtnState(event[1])
                    if type(newBool) ~= "nil" then
                        if not newBool and self.btn.undo then
                            self.undo(state)
                        end
                        self.btn.undo = newBool
                    end
                elseif event[3] >= xDone-1 and event[3] <= xDone+#doneLabel+1 and event[4] == h-2 and type(self.generator) == "nil" then
                    local newBool = setBtnState(event[1])
                    if type(newBool) ~= "nil" then
                        if not newBool and self.btn.done then
                            if not self.done then
                                self.existing = true
                                scene.switchTo(state, require "scene.popup.areyousure")
                            else
                                self.transition = 1
                            end
                        end
                        self.btn.done = newBool
                    end
                elseif event[3] >= xReg-1 and event[3] <= xReg+#regLabel+1 and event[4] == h-2 and type(self.generator) == "nil" then
                    local newBool = setBtnState(event[1])
                    if type(newBool) ~= "nil" then
                        if not newBool and self.btn.reg then
                            self.init(state)
                        end
                        self.btn.reg = newBool
                    end
                else
                    if event[1] == "mouse_up" then
                        for k,_ in pairs(self.btn) do
                            self.btn[k] = false
                        end
                    end
                end

                if event[2] == 1 and event[3] >= w-5 and event[3] <= w-2 and event[4] == 1 then
                    openHelp(state)
                    return
                end
            end
        end
    end

    if state.pressed[keys["f1"]] then
        openHelp(state)
        return
    end

    -- Enter seed
    if os.clock() - self.lastStep > self.rep then
        if state.pressed[keys["one"]] then
            self.seed = self.seed .. "1"
            self.seedLast = os.clock()
            self.lastStep = os.clock() + self.rep
        elseif state.pressed[keys["two"]] then
            self.seed = self.seed .. "2"
            self.seedLast = os.clock()
            self.lastStep = os.clock() + self.rep
        elseif state.pressed[keys["three"]] then
            self.seed = self.seed .. "3"
            self.seedLast = os.clock()
            self.lastStep = os.clock() + self.rep
        elseif state.pressed[keys["four"]] then
            self.seed = self.seed .. "4"
            self.seedLast = os.clock()
            self.lastStep = os.clock() + self.rep
        elseif state.pressed[keys["five"]] then
            self.seed = self.seed .. "5"
            self.seedLast = os.clock()
            self.lastStep = os.clock() + self.rep
        elseif state.pressed[keys["six"]] then
            self.seed = self.seed .. "6"
            self.seedLast = os.clock()
            self.lastStep = os.clock() + self.rep
        elseif state.pressed[keys["seven"]] then
            self.seed = self.seed .. "7"
            self.seedLast = os.clock()
            self.lastStep = os.clock() + self.rep
        elseif state.pressed[keys["eight"]] then
            self.seed = self.seed .. "8"
            self.seedLast = os.clock()
            self.lastStep = os.clock() + self.rep
        elseif state.pressed[keys["nine"]] then
            self.seed = self.seed .. "9"
            self.seedLast = os.clock()
            self.lastStep = os.clock() + self.rep
        elseif state.pressed[keys["zero"]] then
            self.seed = self.seed .. "0"
            self.seedLast = os.clock()
            self.lastStep = os.clock() + self.rep
        else
            self.lastStep = 0
        end
    end

    if os.clock() - self.seedLast > 3 then
        self.init(state)
    end

    -- World generator (blocks key inputs as not needed)

    if self.generator then
        local ok, chunk = coroutine.resume(self.generator.co)
        if coroutine.status(self.generator.co) == "dead" then
            self.generator = nil
        end

        return
    end

    -- Key Events

    if os.clock() - self.lastStep > self.rep and not self.done then
        if state.pressed[keys["up"]] or state.pressed[keys["w"]] then
            if self.cursor.y-1 > 0
            and tiler.matchesCategory(state.field[self.cursor.x][self.cursor.y-1], const.tile.CATEGORY_FLOOR) then
                local oldTile = state.field[self.cursor.x][self.cursor.y-1]
                state.field[self.cursor.x][self.cursor.y-1] = const.tile.CURSOR_N

                if oldTile == const.tile.GOAL_PARKINGLOT then
                    self.done = true
                end

                local tile = state.field[self.cursor.x][self.cursor.y]
                self.updateCursorHistory(state, oldTile)
                state.field[self.cursor.x][self.cursor.y] =
                       (tile == const.tile.CURSOR_O) and const.tile.STREET_CORNER_NW
                    or (tile == const.tile.CURSOR_W) and const.tile.STREET_CORNER_NO
                    or  const.tile.STREET_STRAIGHT_V

                self.cursor.y = self.cursor.y-1
                self.lastStep = os.clock()
            else

            end
        elseif state.pressed[keys["down"]] or state.pressed[keys["s"]] then
            if self.cursor.y+1 <= const.playfield.y
            and tiler.matchesCategory(state.field[self.cursor.x][self.cursor.y+1], const.tile.CATEGORY_FLOOR) then
                local oldTile = state.field[self.cursor.x][self.cursor.y+1]
                state.field[self.cursor.x][self.cursor.y+1] = const.tile.CURSOR_S

                if oldTile == const.tile.GOAL_PARKINGLOT then
                    self.done = true
                end

                local tile = state.field[self.cursor.x][self.cursor.y]
                self.updateCursorHistory(state, oldTile)
                state.field[self.cursor.x][self.cursor.y] =
                       (tile == const.tile.CURSOR_O) and const.tile.STREET_CORNER_SW
                    or (tile == const.tile.CURSOR_W) and const.tile.STREET_CORNER_SO
                    or  const.tile.STREET_STRAIGHT_V

                self.cursor.y = self.cursor.y+1
                self.lastStep = os.clock()
            else

            end
        elseif state.pressed[keys["left"]] or state.pressed[keys["a"]] then
            if self.cursor.x-1 > 0
            and tiler.matchesCategory(state.field[self.cursor.x-1][self.cursor.y], const.tile.CATEGORY_FLOOR) then
                local oldTile = state.field[self.cursor.x-1][self.cursor.y]
                state.field[self.cursor.x-1][self.cursor.y] = const.tile.CURSOR_W

                if oldTile == const.tile.GOAL_PARKINGLOT then
                    self.done = true
                end

                local tile = state.field[self.cursor.x][self.cursor.y]
                self.updateCursorHistory(state, oldTile)
                state.field[self.cursor.x][self.cursor.y] =
                       (tile == const.tile.CURSOR_N) and const.tile.STREET_CORNER_SW
                    or (tile == const.tile.CURSOR_S) and const.tile.STREET_CORNER_NW
                    or  const.tile.STREET_STRAIGHT_H

                self.cursor.x = self.cursor.x-1
                self.lastStep = os.clock()
            else

            end
        elseif state.pressed[keys["right"]] or state.pressed[keys["d"]] then
            if self.cursor.x+1 <= const.playfield.x
            and tiler.matchesCategory(state.field[self.cursor.x+1][self.cursor.y], const.tile.CATEGORY_FLOOR) then
                local oldTile = state.field[self.cursor.x+1][self.cursor.y]
                state.field[self.cursor.x+1][self.cursor.y] = const.tile.CURSOR_O

                if oldTile == const.tile.GOAL_PARKINGLOT then
                    self.done = true
                end

                local tile = state.field[self.cursor.x][self.cursor.y]
                self.updateCursorHistory(state, oldTile)
                state.field[self.cursor.x][self.cursor.y] =
                       (tile == const.tile.CURSOR_N) and const.tile.STREET_CORNER_SO
                    or (tile == const.tile.CURSOR_S) and const.tile.STREET_CORNER_NO
                    or  const.tile.STREET_STRAIGHT_H

                self.cursor.x = self.cursor.x+1
                self.lastStep = os.clock()
            else

            end
        else
            self.lastStep = 0
        end
    end

    if os.clock() - self.lastStep > self.rep then
        if state.pressed[keys["backspace"]] then
            self.undo(state)
            self.lastStep = os.clock() - self.rep
        end
    end

    if state.pressed[keys["enter"]] then
        if not self.done then
            self.existing = true
            scene.switchTo(state, require "scene.popup.areyousure")
        else
            self.transition = 1
        end
    end
end

function self.render(state, term, deltaTime)
    local w, h = term.getSize()

    if self.transition then
        state.water = false
        for name, _ in pairs(palette.GNOME) do
            palette.fadeFor(term, colors[name], palette.GNOME[name], palette.GNOME["black"], 1-math.max(0, self.transition))
        end
        self.transition = math.max(-0.5, self.transition - 0.02)
    else
        state.water = true
    end

    term.setBackgroundColor(colors.black)
    term:clear()

    term:border(2, 2, w-1, h-1, colors.cyan)

    -- Centered playfield grid
    do
        local fieldW = const.playfield.x
        local fieldH = const.playfield.y
        local halfW = math.floor(fieldW/2)
        local halfH = math.floor(fieldH/2)
        local xCentered = math.floor(w/2)
        local yCentered = math.floor(h/2)
        local xLeft = xCentered - halfW
        local xUp = yCentered - halfH

        if not self.generator then
            field(state.field, term, xLeft + 1, xUp + 1, false)
        else
            term.setBackgroundColor(colors.cyan)
            term:fill(xLeft + 1, xUp + 1, xLeft + 1 + const.playfield.x, xUp + 1 + const.playfield.y, colors.white, colors.black, ' ')
            
            local options = {
                scale = 1,
                wrapWidth = const.playfield.x*2,
                dx = 1,
                dy = 2,
                textAlign = "center",
                anchorHor = "center",
                anchorVer = "center"
            }

            local frame = os.clock()%1
            local label = lang.translatable("planner.label.loading")
            local _, height = term.calculateBigFont(label, options)

            term.setBackgroundColor(colors.white)
            term.setTextColor(colors.black)

            term:writeBig(
               label,
                xCentered,
                yCentered,
                options
            )

            local loading =                  (frame < 0.25) and "Ooo"
                         or (frame >= 0.5 and frame < 0.75) and "ooO"
                                                             or "oOo"
            term.setCursorPos(xCentered - 1, yCentered + math.floor(height/2) - 1)
            term.blit(loading, gui.blit[colors.gray]:rep(3), gui.blit[colors.white]:rep(3))

        end

        term.setBackgroundColor(colors.cyan)
        term:frame(xLeft, xUp, fieldW + 2, fieldH + 2, colors.white, self.shadow)
    end

    -- Widgets

    local label = lang.translatable("planner.title")
    term:label(3, 3, colors.white, label, true)

    do -- Buttons
        -- Regenerate btn is centered; Orientate other buttons around this one
        local regLabel = #self.seed > 0 and self.seed or lang.translatable("planner.btn.regenerate")
        local doneRegActive = type(self.generator) == "nil"
        local regState = doneRegActive and self.btn.reg or false
        local reg_label = doneRegActive and regLabel or (" "):rep(#regLabel)
        term:btnNormal(xPosRegBtn(regLabel, w), h-2, doneRegActive and colors.red or colors.gray, colors.pink, self.shadow, colors.white, reg_label, regState)

        local label = lang.translatable("planner.btn.done")
        local doneState = doneRegActive and self.btn.done or false
        local done_label = doneRegActive and label or (" "):rep(#label)
        term:btnNormal(xPosDoneBtn(regLabel, w), h-2, doneRegActive and colors.blue or colors.gray, colors.purple, self.shadow, colors.white, done_label, doneState)

        label = lang.translatable("planner.btn.undo")
        local undoActive = #self.cursor.history > 0
        local undoState = undoActive and self.btn.undo or false
        local undo_label = undoActive and label or (" "):rep(#label)
        term:btnNormal(xPosUndoBtn(regLabel, w), h-2, undoActive and colors.brown or colors.gray, colors.gray, self.shadow, colors.white, undo_label, undoState)
    end

    term.setBackgroundColor(colors.black)

    term:btnSubtle(w-4, 1, colors.gray, colors.lightGray, '?')
    --term:btnSubtle(w-10, 1, colors.gray, colors.lightGray, 'cfg')

    term.setBackgroundColor(colors.cyan)
end

return self