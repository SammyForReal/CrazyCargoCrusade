local const = require "const"

---@class tiler
local tiler = {}

---@alias field table<table<tile>>

---Returns a new empty field.
---@return field
function tiler.emptyField()
    local field = {}

    for x=1, const.playfield.x do
        if type(field[x]) ~= "table" then field[x] = {} end
        for y=1, const.playfield.y do
            field[x][y] = const.tile._UNDECIDED
        end
    end

    return field
end

---Returns the tile relative to the given coords or UNDECIDED, if out of bounds.
---@param field field
---@param x number
---@param y number
---@param dir DIR
---@return tile
function tiler.getRelativeTile(field, x, y, dir)
    x = x + dir[1]
    y = y + dir[2]

    local line = field[x]
    if not line then return const.tile._UNDECIDED end

    local tile = line[y]
    if not tile then return const.tile._UNDECIDED end

    return tile
end

---Chunk-based, simpleTiled, lowest rnytopu and discrete procedural generator,
---aka. some sort of Wave Collapse Algorithm.
---@param field field
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param tileset tileset
---@param strict boolean? true by default; Will regenerate until no tile is undecided.
---@return boolean success Whenever it was successfull or not.
local function wfc(field, x1,y1, x2,y2, tileset, strict)
    if type(strict) == "nil" then strict = true end

    ---Checks what possible tiles could fit in this spot.
    ---@param tileset tileset
    ---@param up tile
    ---@param down tile
    ---@param left tile
    ---@param right tile
    ---@return tile[]
    local function checkConstraints(tileset, up, down, left, right)
        local possibilities = {}

        -- Keep the order predictable so random seeds can be consistently used
        local tiles = {}
        for tile, properties in pairs(tileset) do
            table.insert(tiles, {id = tile, properties = properties})
        end

        table.sort(tiles, function(a, b)
            return a.id < b.id
        end)

        for _, entry in ipairs(tiles) do
            local tile = entry.id
            local properties = entry.properties

            local valids = 0
            for i, name in ipairs({"UP", "DOWN", "LEFT", "RIGHT"}) do
                local canPlace = true

                local whitelist = properties.constraints[const.dir[name]]
                local current = ({up, down, left, right})[i]

                if current ~= const.tile._UNDECIDED then
                    canPlace = false
                    for _, allowed in ipairs(whitelist) do
                        if tiler.matchesCategory(current, allowed) then
                            canPlace = true
                            break
                        end
                    end
                end

                if canPlace then
                    valids = valids + 1
                end
            end

            if valids == 4 then
                table.insert(possibilities, tile)
            end
        end

        return possibilities
    end

    ---Resets the chunk in case it fails to generate.
    local function clear()
        local chunk = {}
        local x, y = 0, 1
        for ix=x1, x2 do
            x = x + 1
            for iy=y1, y2 do
                    if field[ix] and field[ix][iy] then
                    if type(chunk[x]) ~= "table" then chunk[x] = {} end

                    table.insert(chunk[x], const.tile._UNDECIDED)
                    y = y+1
                end
            end
        end

        return chunk
    end

    local ok = false
    local chunk = clear()

    local attempt = 1
    while attempt <= const.MAX_ATTEMPTS do
        -- Scan through field for possible changes we can make

        local undecided = 0

        local lowestEntropy = math.huge
        local results = {}

        for x=1, #chunk do
            results[x] = {}
            for y=1, #chunk[x] do
                if chunk[x][y] ~= const.tile._UNDECIDED then goto continue end

                undecided = undecided + 1

                -- Calculate possibilities for each tile

                local relatives = {}
                for _, name in ipairs({"UP", "DOWN", "LEFT", "RIGHT"}) do
                    local globalTile = tiler.getRelativeTile(field, x+x1-1, y+y1-1, const.dir[name])
                    local tile = tiler.getRelativeTile(chunk, x, y, const.dir[name])
                    table.insert(relatives, (tile == const.tile._UNDECIDED) and globalTile or tile)
                end

                local tiles = checkConstraints(tileset, table.unpack(relatives))

                -- Find lowest entropy

                local totalWeight = 0
                local probabilities = {}

                -- Calculate total weight and probabilities
                for _, tile in ipairs(tiles) do
                    local weight = tileset[tile].weight
                    totalWeight = totalWeight + weight
                    table.insert(probabilities, {id = tile, weight = weight})
                end

                for _, tile in ipairs(probabilities) do
                    tile.p = tile.weight / totalWeight -- Normalize weights to probabilities
                end

                -- Calculate entropy
                local entropy = 0
                for _, tile in ipairs(probabilities) do
                    if tile.p > 0 then  -- Avoid log(0)
                        entropy = entropy - tile.p * math.log(tile.p)
                    end
                end

                -- Save results for later iteration

                lowestEntropy = (entropy < lowestEntropy) and entropy or lowestEntropy
                results[x][y] = {
                    entropy = entropy,
                    probabilities = probabilities,
                    x = x,
                    y = y
                }

                ::continue::
            end
        end

        -- Decide which tiles should be collapsed

        local targets = {}

        for x=1, #chunk do
            for y=1, #chunk[x] do
                local data = results[x][y]

                if data and data.entropy <= lowestEntropy and #data.probabilities > 0 then
                    table.insert(targets, data)
                end
            end
        end

        -- Collapse one random tile from targets list

        if #targets > 0 then
            local index = math.random(1, #targets)
            local target = targets[index]

            local tiles = {}
            for _, entry in ipairs(target.probabilities) do
                for i=1, math.floor(entry.weight) do
                    table.insert(tiles, entry.id)
                end
            end

            local winner = math.random(1, #tiles)
            chunk[target.x][target.y] = tiles[winner]
        else
            -- Reached end?
            if undecided > 0 and strict then
                -- Failure
                attempt = attempt + 1
                chunk = clear()
            else
                -- We are done
                ok = true
                break
            end
        end
    end

    if ok or not strict then
        for x,_ in pairs(chunk) do
            for y,_ in pairs(chunk[x]) do
                field[x + x1 - 1][y + y1 - 1] = chunk[x][y]
            end
        end
    end

    return ok
end

---Takes a field and fills it with content based upon the wave function collapse algorithm.
---Each map starts from the left side and mostly proceeds to the right.
---
---The algorithm works the following way:
---1. Decide where the start is.
---2. Generate multiple reserved possible paths, with start being the root.
---3. Place down the goal at one of the ends of the generated reserved possible paths.
---4. Collapse the remaining undecided tiles around those tiles chunk by chunk (if a chunk fails, regenerate it).
---5. Randomly pick a few tiles and vary them, if possible.
---
---The reserved paths only are being noted down during generation and will not be visible on the final field.
---@param field field
---@return thread generator Will generate the whole field life. Each chunk yields after one cycle with its current status. If a chunk is done, it is being applied to the actual field.
function tiler.fillField(field)
    -- local reserved = tiler.emptyField()

    local function generator()
        -- 1. Select start point
        field[const.playfield.start.x][const.playfield.start.y] = const.tile.FLOOR

        -- 2. Reserve Street
        local goal = math.random(1,2)
        for i=1, 2 do
            local streak = 0
            local cursor = {
                x = const.playfield.start.x,
                y = const.playfield.start.y
            }
            
            while cursor.x < const.playfield.x do
                local dir = math.random(1, 4)
                if streak < 4 then dir = 1  end

                local up, down = const.dir.UP, const.dir.DOWN
                if i==2 then
                    up, down = const.dir.DOWN, const.dir.UP
                end

                if dir == 1 or cursor.y <= 1 or cursor.y >= const.playfield.y then
                    streak = streak + 1
                    cursor.x = cursor.x + const.dir.RIGHT[1]
                    cursor.y = cursor.y + const.dir.RIGHT[2]
                    field[cursor.x][cursor.y] = const.tile.FLOOR
                elseif dir == 2 then
                    streak = 0
                    cursor.x = cursor.x + up[1]
                    cursor.y = cursor.y + up[2]
                    field[cursor.x][cursor.y] = const.tile.FLOOR
                else
                    streak = 0
                    cursor.x = cursor.x + down[1]
                    cursor.y = cursor.y + down[2]
                    field[cursor.x][cursor.y] = const.tile.FLOOR
                end
            end

            -- 3. Decide where goal is
            if goal == i then
                ---@diagnostic disable-next-line: cast-local-type
                goal = { x = cursor.x-2, y = cursor.y }

                for x=-1,1 do
                    for y=-1,1 do
                        field[goal.x+x][goal.y+y] = const.tile.FLOOR
                    end
                end
            end

            coroutine.yield()
        end

        for y=1, const.playfield.y do
            field[const.playfield.x][y] = const.tile.FLOOR
        end

        -- 4. World generation
        for x=1, const.playfield.x, const.playfield.chunk.x-1 do
            for y=1, const.playfield.y, const.playfield.chunk.y-1 do
                local ok = wfc(field, x, y, x+const.playfield.chunk.x-1, y+const.playfield.chunk.y-1, const.tileProperties, true)
                if not ok then
                    -- This chunk failed. Put rock in here
                end
                coroutine.yield()
            end
        end

        -- Apply start / goal
        field[const.playfield.start.x][const.playfield.start.y] = const.tile.CURSOR_O

        for x=-1,1 do
            for y=-1,1 do
                field[goal.x+x][goal.y+y] = const.tile.GOAL_PARKINGLOT
            end
        end
        field[goal.x][goal.y] = const.tile.GOAL_WAREHOUSE
    end

    return coroutine.create(generator)
end

---Returns path to the corresponding model of the tile, or nil for no match.
---@param tile tile
---@return string? path
---@return number rotation
function tiler.tileToModel(tile)
    local entry = const.models[tile]
    if entry then
        return entry.model, entry.rot
    end

    return nil, 0
end

---Returns the blit for the given tile.
---@param tile tile
---@returns string text
---@returns string fgColor
---@returns string bgColor
function tiler.tileToSymbol(tile)
    -- Precise
    for id, blit in pairs(const.symbols) do
        if tile == id then
            return table.unpack(blit)
        end
    end

    -- Unprecise
    for id, blit in pairs(const.symbols) do
        if tiler.matchesCategory(tile, id) then
            return table.unpack(blit)
        end
    end

    return table.unpack(const.symbols[const.tile._UNDECIDED])
end

---Returns the distance between two points.
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return number distance
function tiler.distanceBetween(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

---Checks if the given tile belongs to the given category.
---If no category has been passed but rather another tile, then it only returns true if they are identical.
---@param tile tile
---@param category tile
---@return boolean
function tiler.matchesCategory(tile, category)
    if category % 16 ~= 0 then return category == tile end

    local num = category
    while num >= 16 do
        num = bit32.rshift(num, 4)  -- Shift right by 4 bits (1 hex digit)
    end

    return tile >= num*16 and tile <= num*16+15
end

---Returns the position of the closest given tile.
---@param startX number
---@param startY number
---@param state state
---@param targetTile function|tile Used to compare a tile against the target. In case of a function, the function will get the tile passed and return true if they match.
---@return number? x
---@return number? y
function tiler.findClosestTile(startX, startY, state, targetTile)
    local closestDistance = math.huge
    local tileX, tileY = nil, nil

    for x=1, #state.field do
        for y=1, #state.field[x] do
            local tile = state.field[x][y]
            local matches = type(targetTile) == "function" and targetTile(tile) or targetTile == tile

            if matches then
                local distance = tiler.distanceBetween(startX, startY, x, y)

                if distance < closestDistance then
                    closestDistance = distance
                    tileX = x
                    tileY = y
                end
            end
        end
    end

    return tileX, tileY
end

---@class Point
---@field x number
---@field y number

---Checks if AB line and CD line are intersecting.
---@param a Point
---@param b Point
---@param c Point
---@param d Point
---@return boolean result Whenever they intersect.
function tiler.isIntersecting(a, b, c, d)
    local denominator = ((b.x - a.x) * (d.y - c.y)) - ((b.y - a.y) * (d.x - c.x))
    local numerator1 = ((a.y - c.y) * (d.x - c.x)) - ((a.x - c.x) * (d.y - c.y))
    local numerator2 = ((a.y - c.y) * (b.x - a.x)) - ((a.x - c.x) * (b.y - a.y))

    -- Detect coincident lines (will not work with two coincident likes that don't overlap;
    -- I'm sure speedrunners will like this)
    if denominator == 0 then
       return numerator1 == 0 and numerator2 == 0
    end

    local r = numerator1 / denominator
    local s = numerator2 / denominator

    return  r >= 0 and r <= 1
        and s >= 0 and s <= 1
end

return tiler