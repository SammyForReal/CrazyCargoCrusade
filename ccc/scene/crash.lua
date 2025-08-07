local gui = require "gui"
local strings = require "cc.strings"

---Renders an error
---@param term ExTerm
---@param message string
---@param error any
---@param stacktrace string
local function render(term, message, error, stacktrace)
    local w, h = term.getSize()

    -- Background & Frame

    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)
    term.clear()

    term.setBackgroundColor(colors.black)
    term:frame(1, 1, w, h, colors.black, colors.black)
    term.setBackgroundColor(colors.white)

    local offset = 0
    do -- Upper text
        local lines = strings.wrap(message, w-4)

        for i=1, #lines do
            term.setCursorPos(3, 2+i)
            term.write(lines[i])
        end
        offset = offset + #lines
    end

    term.setCursorPos(3, 3+offset)
    term.blit(
        ('\127'):rep(w-4),
        gui.blit[colors.lightGray] .. gui.blit[colors.gray]:rep(w-6) .. gui.blit[colors.lightGray],
        gui.blit[colors.white]:rep(w-4)
    )

    do -- Error text
        term.setTextColor(colors.gray)
        local lines = strings.wrap("  \171 "..error.." \187", w-4)

        for i=1, #lines do
            local fgColor = gui.blit[colors.gray]:rep(#lines[i])
            if i == 1 then
                fgColor = gui.blit[colors.lightGray]:rep(4) .. fgColor:sub(5)
            end
            if i == #lines then
                fgColor = fgColor:sub(1, math.max(0, #fgColor-1)) .. gui.blit[colors.lightGray]:rep(1)
            end

            term.setCursorPos(3, 3+i+offset)
            term.blit(
                lines[i],
                fgColor,
                gui.blit[colors.white]:rep(#lines[i])
            )
        end

        offset = offset + #lines
    end

    -- Window containing more details

    ---@diagnostic disable-next-line: param-type-mismatch
    local win = window.create(term, 3, 5+offset, w-4, h - (5+offset + 1), true)
    local _, winH = win.getSize()

    win.setBackgroundColor(colors.black)
    win.clear()

    local y = 1
    for line in stacktrace:gmatch("[^\r\n]+") do
        if y > winH then break end

        if y == 2 then y = y + 1 end
        if y > 1 then line = "+" .. line end

        local subLines = strings.wrap(line, w-4)
        for i, line in ipairs(subLines) do
            if i > 1 then line = "|  " .. line end

            local fgColor = y > winH-1 and colors.gray
                or y > winH-2 and colors.lightGray
                or colors.white

            win.setCursorPos(1, y)
            win.blit(
                line,
                gui.blit[y == 1 and fgColor or colors.lightGray]:rep(2) .. gui.blit[fgColor]:rep(#line-2),
                gui.blit[colors.black]:rep(#line)
            )
            y = y + 1
        end
    end
end

return render