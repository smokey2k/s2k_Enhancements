-- =========================================================
-- Font registry and configured font paths
-- =========================================================

FONT_PATH_SETTINGS = {
    { "hpRatioFontKey", "hpRatioFontPath" },
    { "nameFontKey", "nameFontPath" },
    { "levelOverlayFontKey", "levelOverlayFontPath" },
}

function RebuildFontOptions()
    local list, byKey = BuildMediaOptions("font", BUILTIN_FONT_OPTIONS)
    State.fontOptions = list
    State.fontOptionsByKey = byKey
    return list
end

function GetFontOptions()
    if not State.fontOptions or #State.fontOptions == 0 then RebuildFontOptions() end
    return State.fontOptions
end

function GetFontOption(key, savedPath)
    if not State.fontOptionsByKey or not next(State.fontOptionsByKey) then
        RebuildFontOptions()
    end

    local option = State.fontOptionsByKey[key]
    if option then return option end

    -- Keep the last saved path usable while its LibSharedMedia provider loads.
    if savedPath and savedPath ~= "" then
        return { key = key, label = tostring(key or "Saved font"), path = savedPath }
    end

    return State.fontOptionsByKey.FRIZQT or State.fontOptions[1]
end

function RememberFontPath(optionKey, dbPathKey)
    if not optionKey or not dbPathKey then return end
    if not State.fontOptionsByKey or not next(State.fontOptionsByKey) then
        RebuildFontOptions()
    end

    local option = State.fontOptionsByKey[CFG[optionKey]]
    if option and option.path then
        CFG[dbPathKey] = option.path
        if DB then DB[dbPathKey] = option.path end
    end
end

function RememberConfiguredFontPaths()
    for _, setting in ipairs(FONT_PATH_SETTINGS) do
        RememberFontPath(setting[1], setting[2])
    end
end

local fontFlagsByKey
function GetFontFlags(key)
    if not fontFlagsByKey then
        fontFlagsByKey = {}
        for _, option in ipairs(FONT_OUTLINE_OPTIONS or {}) do
            fontFlagsByKey[option.key] = option.flags or ""
        end
    end
    return fontFlagsByKey[key] or "OUTLINE"
end
