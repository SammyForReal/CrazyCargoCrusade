local blit = {[1]='0',[2]='1',[4]='2',[8]='3',[16]='4',[32]='5',[64]='6',[128]='7',[256]='8',[512]='9',[1024]='a',[2048]='b',[4096]='c',[8192]='d',[16384]='e',[32768]='f' }
local gui = {
    blit = blit
}

local fonts = require "morefonts"
local times9k = fonts.loadFont(fs.combine(shell.getRunningProgram(), "..", "bitmap", "font"))

---@class GUI
local method = {}

---@alias ExTerm ccTweaked.Window|GUI A temrinal extended with GUI methods.
---@alias Color integer A number defined in the colors API.

---Applies GUI methods to an object that supports the Term API.
---@param term ccTweaked.Window
---@return ExTerm
function gui.apply(term)
    for k,v in pairs(method) do
        term[k] = v
    end

    local setVisible = term.setVisible
    term.setVisible = function () end

    -- Because Pine3D wants to take control over visibility as well, we need a small workaround

    ---@diagnostic disable-next-line: inject-field
    term.freeze = function ()
        setVisible(false)
    end
    ---@diagnostic disable-next-line: inject-field
    term.unfreeze = function ()
        setVisible(true)
    end

    return term
end

---Freezes the window
function method.freeze() end
---Unfreezes the window
function method.unfreeze() end

---Writes text but big using the Times9k font.
---@param term ExTerm
---@param str string
---@param x number
---@param y number
---@param fontOptions FontOptions
function method.writeBig(term, str, x, y, fontOptions)
    fontOptions.font = times9k
    fonts.writeOn(term, str, x, y, fontOptions)
end

---Calculate text width and height in teletext pixels
---
---Also returns information about how the text is divided over multiple lines
---@param str string
---@param fontOptions FontOptions
---@return integer width (in teletext pixels)
---@return integer height (in teletext pixels)
---@return string[] lines the text to print on everyline (based on newlines and automatic wrapping)
---@return integer[] lineWidths the width of every individual line (in teletext pixels)
function method.calculateBigFont(str, fontOptions)
    fontOptions.font = times9k
    return fonts.calculateTextSize(str, fontOptions)
end

---Draws a frame with a dropshadow
---@param term ExTerm
---@param x number
---@param y number
---@param w number
---@param h number
---@param fgColor Color
---@param fgShadow Color
function method.frame(term, x, y, w, h, fgColor, fgShadow)
    local bg = term.getBackgroundColor()

    -- Top
    term.setCursorPos(x, y)
    term.blit(
        ("\131"):rep(w),
        blit[bg]:rep(w),
        blit[fgColor]:rep(w)
    )

    -- Bottom
    term.setCursorPos(x, y + h-1)
    term.blit(
        ("\143"):rep(w) .. "\149",
        blit[fgColor]:rep(w) .. blit[fgShadow],
        blit[bg]:rep(1) .. blit[fgShadow]:rep(w-1) .. blit[bg]
    )

    -- Sides
    for y=y+1, y+h-2, 1 do
        -- Left
        term.setCursorPos(x, y)
        term.blit(" ", blit[bg], blit[fgColor])

        -- Right
        term.setCursorPos(x + w-1, y)
        term.blit(" \149", blit[fgColor] .. blit[fgShadow], blit[fgColor] .. blit[bg])
    end
end

---Draws a card border
---@param term any
---@param x1 any
---@param y1 any
---@param x2 any
---@param y2 any
---@param fgColor any
---@param transparent boolean?
function method.border(term, x1, y1, x2, y2, fgColor, transparent)
    local bg = term.getBackgroundColor()

    if not type(transparent) == "boolean" or not transparent then
        term:fill(x1,y1, x2,y2, fgColor, fgColor, " ")
    end
    
    term.setCursorPos(x1, y1)
    term.blit('\129', gui.blit[bg], gui.blit[fgColor])

    term.setCursorPos(x2, y1)
    term.blit('\130', gui.blit[bg], gui.blit[fgColor])

    term.setCursorPos(x1, y2)
    term.blit('\144', gui.blit[bg], gui.blit[fgColor])

    term.setCursorPos(x2, y2)
    term.blit('\159', gui.blit[fgColor], gui.blit[bg])
end

---Draws a filled rectangle with a given color and fill character.
---@param term ExTerm
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param bgColor Color
---@param fgColor Color
---@param char string
function method.fill(term, x1, y1, x2, y2, bgColor, fgColor, char)
    local w = x2-x1+1
    for y=y1, y2 do
        term.setCursorPos(x1, y)
        term.blit(
            char:rep(w):sub(1,w),
            blit[fgColor]:rep(w),
            blit[bgColor]:rep(w)
        )
    end
end

---Sets the current background and text color.
---@param bg Color
---@param fg Color
function method.color(bg, fg)
    term.setBackgroundColor(bg)
    term.setTextColor(fg)
end

---Draws a subtle button with a label.
---@param term ExTerm
---@param x number
---@param y number
---@param bgDarkenedColor Color
---@param fgColor Color
---@param label string
function method.btnSubtle(term, x, y, bgDarkenedColor, fgColor, label)
    local bg = term.getBackgroundColor()

    term.setCursorPos(x, y)
    term.blit(
        ("[%s]"):format(label),
        blit[bgDarkenedColor] .. blit[fgColor]:rep(#label) .. blit[bgDarkenedColor],
        blit[bg]:rep(#label + 2)
    )
end

---Draws a big button with a label.
---@param term ExTerm
---@param x number
---@param y number
---@param bgColor Color
---@param bgSelectedColor Color
---@param bgShadowColor Color
---@param fgColor Color
---@param label string
---@param active boolean
function method.btnNormal(term, x, y, bgColor, bgSelectedColor, bgShadowColor, fgColor, label, active)
    local bg = term.getBackgroundColor()

    term.setCursorPos(x, y)

    if active then
        -- Active shape only
        term.blit(
            "\151" .. ("\131"):rep(#label+2),
            blit[bg]:rep(#label+3),
            blit[bgSelectedColor]:rep(#label+3)
        )
    else
        -- Label with normal shape
        term.blit(
            ' ' .. label .. ' ',
            blit[fgColor]:rep(#label+2),
            blit[bgColor]:rep(#label+2)
        )
    end

    local color = active and bgSelectedColor or bgShadowColor

    -- Shadow
    term.setCursorPos(x+#label+2, y)
    term.blit("\148", blit[color], blit[bg])
    term.setCursorPos(x, y+1)
    term.blit(
        "\130" .. ("\131"):rep(#label+1) .. "\129",
        blit[color]:rep(#label+3),
        blit[bg]:rep(#label+3)
    )
end

---Draws a label.
---@param term ExTerm
---@param x number
---@param y number
---@param fgColor Color
---@param label string
---@param isTitle boolean
---@param lineColor Color?
function method.label(term, x, y, fgColor, label, isTitle, lineColor)
    local bg = term.getBackgroundColor()

    term.setCursorPos(x, y)
    term.blit(
        label,
        blit[fgColor]:rep(#label),
        blit[bg]:rep(#label)
    )

    if isTitle then
        term.setCursorPos(x+1, y+1)
        term.blit(
            ("\131"):rep(#label-2) .. ("\130"):rep(2),
            blit[lineColor or fgColor]:rep(#label),
            blit[bg]:rep(#label)
        )
    end
end

return gui