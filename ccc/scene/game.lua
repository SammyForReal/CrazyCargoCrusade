local scene = require "scene.init"
local gui = require "gui"
local const = require "const"
local tiler = require "tiler"
local lang  = require "lang"
local savestate = require "savestate"
local palette   = require "palette"

---@class screen.game.self : scene
local self = scene.new()

function self.create3DScreen(state)
    local w, h = state.win.getSize()
    self.oldW = w
    self.oldH = h

    local previous = term.redirect(state.win)
    self.ThreeDFrame = self.Pine3D.newFrame(2, 4, w-2, h-5)
    term.redirect(previous)

    self.ThreeDFrame:setCamera(self.camera)
    self.ThreeDFrame:setFoV(self.fov)
end

function self.init(state)
    self.id = state.gamemode

    if self.existing then
        self.existing = false
        return
    end

    palette.apply(state.win)

    state.saved = false
    self.Pine3D = require("Pine3D")

    self.fov = 45

    self.cameraSpeed = 6
    self.fovSpeedEffect = 20
    self.cameraFovSpeed = 10
    self.cameraFovSpeedThreshold = 2

    self.debug = false
    self.debugPressed = false

    local x = (const.playfield.start.x-1) * 2 + 1
    local z = (const.playfield.start.y-1) * 2 + 1
    ---@class screen.game.player
    self.player = {
        x = x,
        y = 0,
        z = z,
        rotY = 0,
        velocity = 0,
        speed = 1,
        maxSpeed = 2.5,
        maxOffroadSpeed = 1.2,
        distanceTo = {
            road = 0,
            goal = 32
        },
        valid = {
            x = x,
            z = z
        }
    }

        ---@as PineCamera
    self.camera = {
        x = 0,
        y = 0.6,
        z = 0,
        rotX = 0,
        rotY = math.deg(self.player.rotY),
        rotZ = 0,
        target = {
            x = 0,
            y = 0.6,
            z = 0,
            rotY = 0
        }
    }

    self.finished = false

    self.create3DScreen(state)

    ---@type PineObject[]
    self.objects = {
        self.ThreeDFrame:newObject(fs.combine(state.rootPath, "models/vehicle"),
            self.player.x, self.player.y, self.player.z,
            nil, (-self.player.rotY + math.rad(180)), nil
        )
    }

    -- Field

    local function add(model, rot, fieldX, fieldZ)
        if model then
            local obj = self.ThreeDFrame:newObject(
                fs.combine(state.rootPath, model),
                (fieldX-1) * 2 + 1, 0, (fieldZ-1) * 2 + 1,
               nil, rot * (math.pi / 180), nil
            )

           table.insert(self.objects, obj)
        end
    end

    for fieldX=1, const.playfield.x do
        for fieldZ=1, const.playfield.y do
            local tile = state.field[fieldX][fieldZ]
            if tile == const.tile.GOAL_WAREHOUSE then
                for xd=-1,1 do
                    for yd=-1,1 do
                        if not (xd == 0 and yd == 0) then
                            state.field[fieldX+xd][fieldZ+yd] = const.tile.GOAL_PARKINGLOT
                        end
                    end
                end
            end
        end
    end

    for fieldX=1, const.playfield.x do
        for fieldZ=1, const.playfield.y do
            if not state.field[fieldX][fieldZ] then state.field[fieldX][fieldZ] = const.tile.FLOOR_EMPTY end
            local tile = state.field[fieldX][fieldZ]
            local model, rot = tiler.tileToModel(tile)

            add(model, rot, fieldX, fieldZ)

            if tiler.matchesCategory(tile, const.tile.CATEGORY_CURSOR) then
                model, rot = tiler.tileToModel(const.tile.FLOOR_EMPTY)
                if model then
                    add(model, rot, fieldX, fieldZ)
                end
                state.field[fieldX][fieldZ] = const.tile.FLOOR_EMPTY
            end

            if tile >= const.tile.STREET_STRAIGHT_V and tile <= const.tile.STREET_CORNER_NW then -- TODO: Use separate layer
                model, rot = tiler.tileToModel(const.tile.FLOOR_EMPTY)
                if model then
                    add(model, rot, fieldX, fieldZ)
                end
            end
        end
    end

    for fieldX=-1, const.playfield.x+2 do
        for fieldZ=-1, const.playfield.y+2 do
            if (fieldX < 1 or fieldX > const.playfield.x)
            or (fieldZ < 1 or fieldZ > const.playfield.y) then
                if not state.field[fieldX] then state.field[fieldX] = {} end
                state.field[fieldX][fieldZ] = const.tile._UNDECIDED
            end
        end
    end

    for fieldX=-3, const.playfield.x+4 do
        -- Cliff / Sea
        table.insert(self.objects, self.ThreeDFrame:newObject(
            fs.combine(state.rootPath, "models/sea"),
            (fieldX-1) * 2 + 1, 0, const.playfield.y * 2 + 1,
           nil, 180 * (math.pi / 180), nil
        ))
        table.insert(self.objects, self.ThreeDFrame:newObject(
            fs.combine(state.rootPath, "models/cliff/"..math.random(1,3)),
            (fieldX-1) * 2 + 1, 0, -1,
           nil, 180 * (math.pi / 180), nil
        ))
    end

    -- Walls left and right
    for fieldZ=1, const.playfield.y do
        for i=1, 2 do
            table.insert(self.objects, self.ThreeDFrame:newObject(
                fs.combine(state.rootPath, (fieldZ == const.playfield.start.y and i==1) and "models/gate" or "models/wall"),
                i==1 and -1 or const.playfield.x * 2 + 1, 0, (fieldZ-1) * 2 + 1,
               nil, 0 * (math.pi / 180), nil
            ))

            local model, rot  = tiler.tileToModel(const.tile.FLOOR_EMPTY)
            add(model, rot, i==1 and 0 or const.playfield.x + 1, fieldZ)
        end
    end

    self.timer = os.clock()
end

function self.pause(state)
    self.paused = os.clock()
end

function self.continue(state)
    self.timer = self.timer + (os.clock() - self.paused)
    self.paused = nil
end

local function openHelp(state)
    self.existing = true
    self.pause(state)
    scene.switchTo(state, require "scene.popup.help")
end

local function scoreboard(state)
    self.pause(state)
    scene.switchTo(state, require "scene.popup.scoreboard")
end

---Check for hitboxes around the player
---@return boolean whenever it intersects with something
local function checkHitboxesAroundPlayer(state, stepX, stepZ)
    local subPosX = (self.player.x)/2+1
    local subPosZ = (self.player.z)/2+1

    local start = { x = subPosX, y = subPosZ }
    local target = { x = subPosX + stepX/2, y = subPosZ + stepZ/2 }

    -- Check surrounding fields (including current field)
    for dx = -1, 1 do
        for dy = -1, 1 do
            local checkX = math.floor(subPosX) + dx
            local checkY = math.floor(subPosZ) + dy

            if state.field[checkX] and state.field[checkX][checkY] then
                local tileID = state.field[checkX][checkY]
                local hitlines = const.hitlines[tileID] or {}

                for _, line in ipairs(hitlines) do
                    local lineStart = { x = line[1].x + checkX, y = line[1].y + checkY }
                    local lineEnd = { x = line[2].x + checkX, y = line[2].y + checkY }

                    if tiler.isIntersecting(start, target, lineStart, lineEnd) then
                        return true
                    end
                end
            end
        end
    end

    return false
end

function self.tick(state, deltaTime)
    -- Mouse events
    if #state.mouseEvents > 0 then
        local w, h = state.win.getSize()
        for i=1, #state.mouseEvents do
            local event = state.mouseEvents[1]
            table.remove(state.mouseEvents, 1)
            
            if event[2] == 1 and event[3] >= w-5 and event[3] <= w-2 and event[4] == 1 then
                openHelp(state)
                return
            end
        end
    end

    if state.pressed[keys["f1"]] then
        openHelp(state)
        return
    elseif state.pressed[keys["numPad9"]] and not self.debugPressed then
        if not self.debugPressed then
            self.debug = not self.debug
        end
    end
    self.debugPressed = state.pressed[keys["numPad9"]]

    -- Get distance
    local subPosX = (self.player.x)/2+1
    local subPosZ = (self.player.z)/2+1
    
    local tilePlayerX = math.floor(subPosX)
    local tilePlayerY = math.floor(subPosZ)

    if tiler.matchesCategory((state.field[tilePlayerX] or {})[tilePlayerY] or const.tile.STREET_STRAIGHT_H, const.tile.GOAL_PARKINGLOT) then
        self.finished = os.clock()
        if not state.savestate.randomizer then
            state.savestate.randomizer = {}
        end
        if not state.savestate.randomizer[""..state.seed] then
            state.savestate.randomizer[""..state.seed] = {}
        end

        table.insert(state.savestate.randomizer[""..state.seed], self.finished - self.timer)
        table.sort(state.savestate.randomizer[""..state.seed], function(a,b) return a < b end)
        savestate.save(state)

        scoreboard(state)
        return
    end

    tileX, tileY = tiler.findClosestTile(self.player.x/2, self.player.z/2, state, const.tile.GOAL_PARKINGLOT)
    self.player.distanceTo.goal = (tileX and tileY) and tiler.distanceBetween(self.player.x, self.player.z, (tileX-1)*2, (tileY-1)*2) * 2 or math.huge

    -- Vehicle movement
    do
        local speed = self.player.speed * deltaTime

        if state.pressed[keys["w"]] or state.pressed[keys["s"]]
        or state.pressed[keys["up"]] or state.pressed[keys["down"]] then
            if state.pressed[keys["s"]] or state.pressed[keys["down"]] then
                speed = -speed
            end

            self.player.velocity = self.player.velocity + speed
        else
            if self.player.velocity > 0 then
                self.player.velocity = math.max(0, self.player.velocity - speed)
            elseif self.player.velocity < 0 then
                self.player.velocity = math.min(0, self.player.velocity + speed)
            end
        end

        -- Speed cap
        local maxSpeed = tiler.matchesCategory((state.field[tilePlayerX] or {})[tilePlayerY] or const.tile.STREET_STRAIGHT_H, const.tile.CATEGORY_STREET) and self.player.maxSpeed or self.player.maxOffroadSpeed
    
        if self.player.velocity > maxSpeed then
            self.player.velocity = maxSpeed
        elseif self.player.velocity < -maxSpeed then
            self.player.velocity = -maxSpeed
        end

        -- Handle rotation
        if self.player.velocity ~= 0 then
            local rotationDirection = self.player.velocity < 0 and -1 or 1

            if state.pressed[keys["a"]] or state.pressed[keys["left"]] then
                self.player.rotY = self.player.rotY - rotationDirection * math.rad(65) * deltaTime
            elseif state.pressed[keys["d"]] or state.pressed[keys["right"]] then
                self.player.rotY = self.player.rotY + rotationDirection * math.rad(65) * deltaTime
            end
        end

        -- Velocity

        local rot = self.player.rotY

        local forwardX = math.cos(rot)
        local forwardZ = math.sin(rot)

        -- Normalize
        local length = math.sqrt(forwardX^2 + forwardZ^2)
        if length > 0 then
            forwardX = forwardX / length
            forwardZ = forwardZ / length
        end

        local stepX = (forwardX * self.player.velocity * deltaTime)
        local stepZ = (forwardZ * self.player.velocity * deltaTime)

        -- Check hitboxes
        if checkHitboxesAroundPlayer(state, stepX, stepZ) then
            self.player.x = self.player.valid.x
            self.player.z = self.player.valid.z
        else
            -- Apply velocity if no collision
            self.player.x = self.player.x + stepX
            self.player.z = self.player.z + stepZ
            self.player.valid.x = self.player.x
            self.player.valid.z = self.player.z
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

local function positionCamera(x, z, rotY)
    local dx = 0.1 * math.cos(rotY)
    local dz = 0.1 * math.sin(rotY)
    x = x + dx
    z = z + dz

    self.camera.target.x = x
    self.camera.target.y = self.player.y
    self.camera.target.z = z

    self.camera.target.rotY = math.deg(rotY or 0)

    local dx = -0.69 * math.cos(math.rad(self.camera.rotY))
    local dz = -0.69 * math.sin(math.rad(self.camera.rotY))
    local pointX = self.camera.target.x + dx
    local pointZ = self.camera.target.z + dz

    self.camera.target.x = pointX + dx
    self.camera.target.z = pointZ + dz

    self.camera.y = 0.4
    self.camera.rotZ = -8
end

local function smoothTransition(cur, target, factor, minSpeed, threshold)
    local step = math.min(factor * math.abs(cur - target), minSpeed)
    if cur > target then
        cur = cur - step
    elseif cur < target then
        cur = cur + step
    end

    local diff = math.abs(cur - target)
    if diff < threshold then
        cur = target
    end

    return cur
end

function self.render(state, term, deltaTime)
    local w, h = term.getSize()

    if w ~= self.oldW or h ~= self.oldH then
        self.create3DScreen(state)
    end

    term.setBackgroundColor(colors.black)
    term.clear()

    -- Interpolation

    local vehicle = self.objects[1]
    vehicle[1] = self.player.x
    vehicle[2] = self.player.y
    vehicle[3] = self.player.z
    vehicle[5] = smoothTransition(vehicle[5], (-self.player.rotY + math.rad(180)), math.rad(15), math.rad(5), math.rad(0.5))

    -- Smooth Camera

    positionCamera(vehicle[1], vehicle[3], -vehicle[5] + math.rad(180))

    self.camera.x = self.camera.target.x
    self.camera.z = self.camera.target.z

    self.camera.rotY = smoothTransition(self.camera.rotY, self.camera.target.rotY, self.cameraSpeed / 90, 5, 0.5)

    local speed = self.fovSpeedEffect / self.player.maxSpeed * math.max(0, self.player.velocity)
    local fov = self.ThreeDFrame.FoV
    local fovTarget = self.fov + speed

    local step = 0.5

    if fov > fovTarget then
        fov = fov - (step*2)
        if fov < fovTarget then
            fov = fovTarget
        end
    elseif fov < fovTarget then
        fov = fov + step
        if fov > fovTarget then
            fov = fovTarget
        end
    end

    self.ThreeDFrame:setCamera(self.camera)
    self.ThreeDFrame:setFoV(fov)

    -- 3D environmnt

    self.ThreeDFrame:drawObjects(self.objects)
    self.ThreeDFrame:drawBuffer()

    -- GUI

    local tileX = (self.player.x)/2+1
    local tileY = (self.player.z)/2+1
    local tile = (state.field[math.floor(tileX)] or {})[math.floor(tileY)] or const.tile._UNDECIDED

    -- F3 debug menu
    if self.debug then
        local tx,fg,bg = tiler.tileToSymbol(tile)
        term.setCursorPos(math.floor(w/2-11), h)
        term.blit(tx,fg,bg)
        term.setCursorPos(math.floor(w/2-9), h)
        term.setTextColor(colors.yellow)
        term.write(("Tile: x%05.2f z%05.2f"):format(tileX, tileY))
    end

    local _,_,lineTop = self.ThreeDFrame.buffer.blitWin.getLine(1)
    local _,_,lineBottom = self.ThreeDFrame.buffer.blitWin.getLine(h-5)

    do -- Corners
        term.setCursorPos(2, 4)
        term.blit('\129', gui.blit[colors.black], lineTop:sub(1,1))

        term.setCursorPos(w-1, 4)
        term.blit('\130', gui.blit[colors.black], lineTop:sub(w-2,w-2))
        
        term.setCursorPos(2, h-2)
        term.blit('\144', gui.blit[colors.black], lineBottom:sub(1,1))

        term.setCursorPos(w-1, h-2)
        term.blit('\159', lineBottom:sub(#lineBottom), gui.blit[colors.black])
    end
    
    local title = lang.translatable("game.title")
    term:label(3,2, colors.white, title, true)
    term:label(3,h, colors.green, toTime(os.clock() - self.timer), false)

    term:btnSubtle(w-4, 1, colors.gray, colors.lightGray, '?')

    do -- Distance to goal
        local distance = self.player.distanceTo.goal*2
        local labelFar = lang.translatable("game.label.far")
        local label = distance > 900 and "\24 " .. labelFar .. (" "):rep(4-#labelFar) or ("\24 %03dm"):format(distance)
        term:label((3 + #title) + math.floor((w-1 - #title) / 2 - #label/2), 2, colors.yellow, label, false)
    end

    do
        -- Offroad warning
        local pos = w - 8
        if not tiler.matchesCategory(tile, const.tile.CATEGORY_STREET) then
            term.setCursorPos(pos-1, h)
            term.blit("\19", (os.epoch("utc") % 500 <= 250) and gui.blit[colors.red] or  gui.blit[colors.black], gui.blit[colors.black])
        end

        -- Speed display
        term.setCursorPos(pos+1, h-1)
        term.blit(
            "\135\158\143\146\139",
            gui.blit[colors.black]..gui.blit[colors.yellow]:rep(2)..gui.blit[colors.black]:rep(2),
            gui.blit[colors.white]..gui.blit[colors.black]:rep(2)..gui.blit[colors.pink]:rep(2)
        )
        term.setCursorPos(pos, h)
        term.blit(
            "\130\135",
            gui.blit[colors.white]:rep(2),
            gui.blit[colors.black]:rep(2)
        )
        term.setCursorPos(pos+5, h)
        term.blit(
            "\139\129",
            gui.blit[colors.pink]:rep(2),
            gui.blit[colors.black]:rep(2)
        )

        local speed = math.floor(3 / self.player.maxSpeed * math.abs(self.player.velocity) + 0.2)
        term.setCursorPos(pos+2, h)
        term.blit(
            (speed > 2.75 and " \152\132")
            or (speed > 1 and " \149 ")
            or "\140\144 ",
            gui.blit[colors.red]:rep(3),
            gui.blit[colors.black]:rep(3)
        )
    end

    term.setBackgroundColor(colors.lightBlue)
end

return self
