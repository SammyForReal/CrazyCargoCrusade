local json = require "json"

local lang = {
    _LOADED = {}
}

---Changes the language, if given local code is available.
---@param state state
---@param localcode string
---@return boolean success Whenever the language could be selected.
---@return string|nil Returns the error code if something went wrong, otherwise nil.
function lang.select(state, localcode)
    local path = fs.combine(state.rootPath, "lang")
    local languages = lang.available(state)

    -- Search for the matching language file
    for _, name in ipairs(languages) do
        if name == localcode then
            local langPath = fs.combine(path, name .. ".json")
            local file = fs.open(langPath, "r")
            if not file then break end

            local content = file.readAll()
            file.close()

            local ok, result = pcall(json.decode, content)
            if not ok then return false, result end

            lang._LOADED = result
            state.language = localcode
            return true
        end
    end

    return false, "Selected localcode has no translated values"
end

---Returns a list of available languages.
---@param state state
---@return string[] Available languages
function lang.available(state)
    local path = fs.combine(state.rootPath, "lang")
    local languages = fs.list(path)

    for i=#languages, 1, -1 do
        local name = languages[i]
        if name:sub(-4) ~= "json" then
            table.remove(languages, i)
        else
            languages[i] = name:sub(1, -6)
        end
    end

    return languages
end

---Returns a translatable of the given id. Any passed arguments will be formatted into the translatable, if supported.
---@param id string
---@param ... any
---@return string
function lang.translatable(id, ...)
    local translated = lang._LOADED[id] or id

    if #({ ... }) > 0 then
        translated = translated:format(...)
    end

    return translated
end

return lang