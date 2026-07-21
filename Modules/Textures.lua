-- =========================================================
-- Status-bar texture registry and application
-- =========================================================

STATUSBAR_PATH_SETTINGS = {
    { 'healthBackdropTextureKey', 'healthBackdropTexturePath' },
    { 'castbarBackdropTextureKey', 'castbarBackdropTexturePath' },
    { 'targetHealthTextureKey', 'targetHealthTexturePath' },
    { 'targetHealthBackdropTextureKey', 'targetHealthBackdropTexturePath' },
    { "healthTextureKey", "healthTexturePath" },
    { "castbarTextureKey", "castbarTexturePath" },
    { "playerCastOverlaySparkTextureKey", "playerCastOverlaySparkTexturePath" },
}

BORDER_PATH_SETTINGS = {
    {'borderTextureKey', 'borderTexturePath'},
    {'targetBorderTextureKey', 'targetBorderTexturePath'},
    {'castbarBorderTextureKey', 'castbarBorderTexturePath'},
}

BUILTIN_BORDER_OPTIONS = {
    {key='S2K_SOLID', label='Solid', path='Interface\\Buttons\\WHITE8X8'},
    {key='BLIZZARD_TOOLTIP', label='Blizzard Tooltip', path='Interface\\Tooltips\\UI-Tooltip-Border'},
    {key='BLIZZARD_DIALOG', label='Blizzard Dialog', path='Interface\\DialogFrame\\UI-DialogBox-Border'},
    {key='BLIZZARD_GOLD', label='Blizzard Gold Dialog', path='Interface\\DialogFrame\\UI-DialogBox-Gold-Border'},
    {key='BLIZZARD_PARTY', label='Blizzard Party', path='Interface\\CharacterFrame\\UI-Party-Border'},
    {key='BLIZZARD_ACHIEVEMENT', label='Blizzard Achievement Wood', path='Interface\\AchievementFrame\\UI-Achievement-WoodBorder'},
}

function RebuildStatusBarTextureOptions()
    local list, byKey = BuildMediaOptions("statusbar", BUILTIN_STATUSBAR_TEXTURE_OPTIONS)
    State.statusbarTextureOptions = list
    State.statusbarTextureOptionsByKey = byKey
    return list
end

function GetStatusBarTextureOptions()
    if not State.statusbarTextureOptions or #State.statusbarTextureOptions == 0 then
        RebuildStatusBarTextureOptions()
    end
    return State.statusbarTextureOptions
end

function RebuildBorderTextureOptions()
    local list, byKey = BuildMediaOptions('border', BUILTIN_BORDER_OPTIONS)
    local none = {key='NONE', label='None', path='Interface\\Buttons\\WHITE8X8'}
    table.insert(list, 1, none)
    byKey.NONE = none
    State.borderTextureOptions, State.borderTextureOptionsByKey = list, byKey
    return list
end

function GetBorderTextureOptions()
    if not State.borderTextureOptions or #State.borderTextureOptions == 0 then RebuildBorderTextureOptions() end
    return State.borderTextureOptions
end

function GetBorderTextureOption(key, savedPath)
    if not State.borderTextureOptionsByKey then RebuildBorderTextureOptions() end
    return State.borderTextureOptionsByKey[key] or (savedPath and {key=key,label=tostring(key),path=savedPath}) or State.borderTextureOptionsByKey.S2K_SOLID
end

function GetStatusBarTextureOption(key, savedPath)
    if not State.statusbarTextureOptionsByKey or not next(State.statusbarTextureOptionsByKey) then
        RebuildStatusBarTextureOptions()
    end

    local option = State.statusbarTextureOptionsByKey[key]
    if option then return option end

    -- Keep the last saved path usable while its LibSharedMedia provider loads.
    if savedPath and savedPath ~= "" then
        return { key = key, label = tostring(key or "Saved texture"), path = savedPath }
    end

    return State.statusbarTextureOptionsByKey.BLIZZARD_STATUSBAR or State.statusbarTextureOptions[1]
end

function RememberStatusBarTexturePath(optionKey, dbPathKey)
    if not optionKey or not dbPathKey then return end
    if not State.statusbarTextureOptionsByKey or not next(State.statusbarTextureOptionsByKey) then
        RebuildStatusBarTextureOptions()
    end

    local option = State.statusbarTextureOptionsByKey[CFG[optionKey]]
    if option and option.path then
        CFG[dbPathKey] = option.path
        if DB then DB[dbPathKey] = option.path end
    end
end

function RememberConfiguredStatusBarTexturePaths()
    for _, setting in ipairs(STATUSBAR_PATH_SETTINGS) do
        RememberStatusBarTexturePath(setting[1], setting[2])
    end
end

function RememberConfiguredBorderTexturePaths()
    if not State.borderTextureOptionsByKey then RebuildBorderTextureOptions() end
    for _, setting in ipairs(BORDER_PATH_SETTINGS) do
        local option = State.borderTextureOptionsByKey[CFG[setting[1]]]
        if option then
            CFG[setting[2]], DB[setting[2]] = option.path, option.path
        end
    end
end

function GetConfiguredBorderTexturePath(key, pathKey)
    local option = GetBorderTextureOption(CFG[key], CFG[pathKey])
    return option and option.path or 'Interface\\Buttons\\WHITE8X8'
end

function GetHealthTexturePath(ctx)
    if ctx and CFG.targetHealthbarOverride and IsTargetUnit(ctx.unit) then
        local targetOption = GetStatusBarTextureOption(CFG.targetHealthTextureKey, CFG.targetHealthTexturePath)
        return targetOption and targetOption.path or CFG.targetHealthTexturePath or 'Interface/TargetingFrame/UI-StatusBar'
    end
    local option = GetStatusBarTextureOption(CFG.healthTextureKey, CFG.healthTexturePath or CFG.healthTexture)
    return option and option.path or CFG.healthTexturePath or CFG.healthTexture or "Interface\\TargetingFrame\\UI-StatusBar"
end

function GetCastbarTexturePath()
    local option = GetStatusBarTextureOption(CFG.castbarTextureKey, CFG.castbarTexturePath or CFG.castbarTexture)
    return option and option.path or CFG.castbarTexturePath or CFG.castbarTexture or "Interface\\TargetingFrame\\UI-StatusBar"
end

function GetHealthBackdropTexturePath(ctx)
    if ctx and CFG.targetHealthbarOverride and IsTargetUnit(ctx.unit) then
        local targetOption = GetStatusBarTextureOption(CFG.targetHealthBackdropTextureKey, CFG.targetHealthBackdropTexturePath)
        return targetOption and targetOption.path or CFG.targetHealthBackdropTexturePath or 'Interface/Buttons/WHITE8X8'
    end
    local option = GetStatusBarTextureOption(CFG.healthBackdropTextureKey, CFG.healthBackdropTexturePath)
    return option and option.path or CFG.healthBackdropTexturePath or 'Interface/Buttons/WHITE8X8'
end

function GetCastbarBackdropTexturePath()
    local option = GetStatusBarTextureOption(CFG.castbarBackdropTextureKey, CFG.castbarBackdropTexturePath)
    return option and option.path or CFG.castbarBackdropTexturePath or 'Interface/Buttons/WHITE8X8'
end

function GetPlayerCastOverlaySparkTexturePath()
    local option = GetStatusBarTextureOption(CFG.playerCastOverlaySparkTextureKey, CFG.playerCastOverlaySparkTexturePath)
    return option and option.path or CFG.playerCastOverlaySparkTexturePath or "Interface\\Buttons\\WHITE8X8"
end

function ApplyTexturePath(texture, path)
    if not texture or not texture.SetTexture or not path or path == "" then
        return false
    end

    local function Try(pathToUse)
        if not pathToUse or pathToUse == "" then return false end
        local ok = pcall(texture.SetTexture, texture, pathToUse)
        return ok and true or false
    end

    path = tostring(path)
    if Try(path) then return true end

    local alt1 = path:gsub("/", "\\")
    if alt1 ~= path and Try(alt1) then return true end

    local alt2 = path:gsub("\\", "/")
    if alt2 ~= path and Try(alt2) then return true end

    return false
end

function ApplyStatusBarTexture(statusbar, path)
    if not statusbar or not statusbar.SetStatusBarTexture or not path or path == "" then
        return false
    end

    local function Try(pathToUse)
        if not pathToUse or pathToUse == "" then return false end
        local ok = pcall(statusbar.SetStatusBarTexture, statusbar, pathToUse)
        return ok and true or false
    end

    path = tostring(path)
    if Try(path) then return true end

    local alt1 = path:gsub("/", "\\")
    if alt1 ~= path and Try(alt1) then return true end

    local alt2 = path:gsub("\\", "/")
    if alt2 ~= path and Try(alt2) then return true end

    return false
end

function ApplyStatusBarBackdropTexture(texture, path, r, g, b, a)
    if not ApplyTexturePath(texture, path) then return false end
    texture:SetVertexColor(r or 0, g or 0, b or 0, a == nil and 1 or a)
    return true
end

function ApplyContextStatusBarTextures(ctx)
    if not ctx then return end
    ApplyStatusBarTexture(ctx.health, GetHealthTexturePath(ctx))
    ApplyStatusBarTexture(ctx.cast, GetCastbarTexturePath())
    if ctx.background then
        ApplyStatusBarBackdropTexture(ctx.background, GetHealthBackdropTexturePath(ctx), GetHealthBackdropColor(ctx))
    end
    if ctx.cast and ctx.cast.bg then
        ApplyStatusBarBackdropTexture(ctx.cast.bg, GetCastbarBackdropTexturePath(), GetCastbarBackdropColor())
    end
    if ctx.playerCastOverlay then
        ApplyStatusBarTexture(ctx.playerCastOverlay, GetHealthTexturePath())
    end
    if ctx.playerCastOverlaySpark and ctx.playerCastOverlaySpark.texture then
        ApplyTexturePath(ctx.playerCastOverlaySpark.texture, GetPlayerCastOverlaySparkTexturePath())
    end
end

function ApplyFontStringFont(text, fontKey, size, outlineKey, savedPath)
    if not text or not text.SetFont then return false end

    local font = GetFontOption(fontKey, savedPath)
    if not font or not font.path then return false end

    local fontSize = tonumber(size) or 10
    local flags = GetFontFlags(outlineKey)

    local function TrySetFont(path)
        if not path or path == "" then return false end
        local ok, applied = pcall(text.SetFont, text, path, fontSize, flags)
        -- In most clients SetFont returns 1/true on success. Some older/private clients
        -- return nil despite applying the font, so a clean pcall still counts as usable.
        -- A hard false is treated as failure so we can try path variants.
        return ok and applied ~= false
    end

    local path = tostring(font.path)
    if TrySetFont(path) then return true end

    -- Some 7.3.5/private-server clients are picky about slash direction in font paths.
    -- Try normalized variants before giving up.
    local alt1 = path:gsub("/", "\\")
    if alt1 ~= path and TrySetFont(alt1) then return true end

    local alt2 = path:gsub("\\", "/")
    if alt2 ~= path and TrySetFont(alt2) then return true end

    return false
end
