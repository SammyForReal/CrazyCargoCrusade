local gui = require "gui"
local const = require "const"
local scene = require "scene.init"
local palette = require "palette"
local tiler = require "tiler"
local lang  = require "lang"
local savestate = require "savestate"

palette.apply(term)

local w, h = term.getSize()
local win = gui.apply(
    window.create(term.current(), 1, 1, w, h, false)
)

-- Ensure system meets requirements

if w < 51 or h < 19 then
    local crashScr = require "scene.crash"

    win.unfreeze()
    crashScr(win, lang.translatable("crash.minimum.size.title"), lang.translatable("crash.minimum.size.text"), lang.translatable("crash.minimum.size.data",
        w, h,
        51, 19
    ))
    palette.undo(term)

    return
elseif not term.isColor() then
    local crashScr = require "scene.crash"

    win.unfreeze()
    crashScr(win, lang.translatable("crash.minimum.color.title"), lang.translatable("crash.minimum.color.text"), "")
    palette.undo(term)

    return
end

-- Prepare State

local function crash(co, name, err)
    local traceback = debug.traceback(co, nil, 1)

    palette.undo(term)
    local crashScr = require "scene.crash"
    crashScr(win, ("An unexpected error occured on the %s thread."):format(name), err, traceback)

    win.setCursorPos(1,h)
    win.setBackgroundColor(colors.black)
    win.setTextColor(colors.white)

    win.unfreeze()
end

---@class state
local state = {
    ---@type scene
    currentScr = nil,
    ---@type scene|nil
    nextScr = nil,
    field = tiler.emptyField(),
    pressed = {},
    mouseEvents = {},
    scenes = {
        title = require "scene.title",
        planner = require "scene.planner",
        game = require "scene.game"
    },
    rootPath = fs.combine(shell.getRunningProgram(), ".."),
    win = win,
    language = "en_us",
    saved = true,
    running = true,
    gamemode = "none",
    ---@type savestate
    savestate = {},
    seed = 0,
}

lang.select(state, state.language)
scene.switchTo(state, state.scenes.title)
savestate.load(state)

-- Gamelogic

local function events()
    while true do
        local event = { os.pullEventRaw() }

        if event[1] == "term_resize" then
            w, h = term.getSize()
            win.reposition(1, 1, w, h)
        elseif event[1] == "terminate" then
            break
        elseif event[1] == "key" then
            state.pressed[event[2]] = true
        elseif event[1] == "key_up" then
            state.pressed[event[2]] = nil
        elseif event[1]:find("mouse") then
            table.insert(state.mouseEvents, event)
        end
    end
end

local function tick()
    local lastTime = os.clock()

    while state.running do
        local currentTime = os.clock()
        local deltaTime = currentTime - lastTime
        lastTime = currentTime

        if state.currentScr then
            state.currentScr.tick(state, deltaTime)
        end

        local elapsedTime = os.clock() - currentTime
        local sleepTime = (1/const.tickrate) - elapsedTime
        if sleepTime >= 0 then
            sleep(sleepTime)
        end
    end
end

local function render()
    local lastTime = os.clock()
    local t = 0

    while true do
        local currentTime = os.clock()
        local deltaTime = (currentTime - lastTime)

        -- Render frame
        if state.currentScr then
            win.freeze()
            state.currentScr.render(state, win, deltaTime)
            win.unfreeze()
        end

        palette.fadeFor(win, colors.cyan, palette.GNOME.cyan, 0x1F717D, math.abs(t-1))
        t = (t+0.02) % 2

        lastTime = currentTime

        sleep(0)
    end
end

-- Runtime starts here

local threads = {
    { name = "events", co = coroutine.create(events), func = events },
    { name = "tick", co = coroutine.create(tick), func = tick },
    { name = "render", co = coroutine.create(render), func = render },
}

local event = { n = 0 }
while true do
    -- Run threads
    for i, thread in ipairs(threads) do
        local ok, err = coroutine.resume(thread.co, table.unpack(event, 1, event.n))

        if not ok then
            if type(thread.lastFailed) == "nil" or (os.clock() - thread.lastFailed) > 3 then
                -- Give it another try
                thread.failed = (thread.failed or 0) + 1
                thread.lastFailed = os.clock()
                thread.co = coroutine.create(thread.func)

                goto continue
            end

            return crash(thread.co, thread.name, err)
        end
        ::continue::

        if coroutine.status(thread.co) == "dead" then goto exit end
        if thread.lastFailed and (os.clock() - thread.lastFailed) > 3 then thread.failed = 0 end
    end

    event = table.pack( os.pullEventRaw() )

    local scr = state.nextScr
    if type(scr) ~= "nil" then
        state.pressed = {}
        state.mouseEvents = {}
        if state.currentScr and state.currentScr.previousScr then
            state.currentScr.previousScr.continue(state)
        end
        scr.init(state)
        state.currentScr = scr
        state.nextScr = nil
    end
end

-- Game is finished

::exit::

-- Scroll out the screen

win.setBackgroundColor(colors.black)
win.setTextColor(colors.white)
win.unfreeze()

local frameDelay = 0.05
local totalFrames = 0.5 / frameDelay

local scrollLines = math.max(h, 19) - 1
local scrollsPerFrame = math.max(1, math.ceil(scrollLines / totalFrames))
local remainingScrolls = scrollLines

term.scroll(1)
term.setCursorPos(1, h)

if not state.saved then
    local msg = "Canceled without saving."
    local textColor = gui.blit[colors.red]:rep(#msg)
    local bgColor = gui.blit[colors.black]:rep(#msg)

    term.blit(msg, textColor, bgColor)
    term.scroll(1)
    remainingScrolls = remainingScrolls - 1
end

term.setCursorPos(1, h)
term.blit(">", gui.blit[colors.yellow], gui.blit[colors.black])

while remainingScrolls > 0 do
    local lines = math.min(scrollsPerFrame, remainingScrolls)
    term.scroll(lines)
    remainingScrolls = remainingScrolls - lines
    sleep(frameDelay)
end

term.setCursorPos(1, not state.saved and 2 or 1)

palette.undo(term)