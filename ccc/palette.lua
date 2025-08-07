local palette = {}

---@alias RGB number[]
---@alias color ccTweaked.colors.color

palette.GNOME = {
    ["black"]     = 0x171421,
    ["blue"]      = 0x2A7BDE,
    ["brown"]     = 0xA2734C,
    ["cyan"]      = 0x2AA1B3,
    ["gray"]      = 0x5E5C64,
    ["green"]     = 0x26A269,
    ["lightBlue"] = 0x33C7DE,
    ["lightGray"] = 0xD0CFCC,
    ["lime"]      = 0x33D17A,
    ["magenta"]   = 0xC061CB,
    ["orange"]    = 0xCB9161,
    ["pink"]      = 0xF66151,
    ["purple"]    = 0xA347BA,
    ["red"]       = 0xC01C28,
    ["white"]     = 0xFFFFFF,
    ["yellow"]    = 0xF3F03E
}

---Applies the GNOME color palette and remembers the previous colors for later undoing.
---@param term term
function palette.apply(term)
    for color, code in pairs(palette.GNOME) do
        term.setPaletteColor(colors[color], code)
    end
end

---Undos the current palette to the native one.
---@param term term
function palette.undo(term)
    for color, _ in pairs(palette.GNOME) do
        local r,g,b = term.nativePaletteColor(colors[color])
        term.setPaletteColor(colors[color], r,g,b)
    end
end

---Gives the color a mix of the given RGB values depending on t.
---@param color color
---@param rgb1 RGB|color
---@param rgb2 RGB|color
---@param t number 0 to 1
function palette.fadeFor(term, color, rgb1, rgb2, t)
    t = math.max(0, math.min(1, t))

    if type(rgb1) == "number" then rgb1 = { colors.unpackRGB(rgb1)} end
    if type(rgb2) == "number" then rgb2 = { colors.unpackRGB(rgb2)} end

    local r = rgb1[1] + (rgb2[1] - rgb1[1]) * t
    local g = rgb1[2] + (rgb2[2] - rgb1[2]) * t
    local b = rgb1[3] + (rgb2[3] - rgb1[3]) * t

    term.setPaletteColor(color, colors.packRGB(r,g,b))
end

return palette