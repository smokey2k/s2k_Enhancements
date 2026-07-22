-- =========================================================
-- s2k:Enhancements - Module manager
-- Runtime feature switches and event/OnUpdate subscriptions.
-- =========================================================

-- User-facing runtime switches. Healthbar, castbar, buffs, debuffs and
-- Blizzard visual replacement are virtual modules controlled by the single
-- Custom Nameplates master switch (CFG.enabled).
S2KNP_MODULE_DEFS = {
    { key = "customNameplates",    label = "Custom Nameplates",          cvar = "enabled",                           default = true  },
    { key = "targetRuntimeHealth", label = "Target health runtime tick", defaultName = "targethealthruntime", cvar = "moduleTargetRuntimeHealthEnabled", default = true },
    { key = "names",               label = "Unit name overlay",          cvar = "showNames",                         default = false },
    { key = "hpRatio",             label = "HP ratio overlay",           cvar = "hpRatioText",                       default = true  },
    { key = "levelOverlay",        label = "Unit level overlay",         cvar = "levelOverlayEnabled",               default = false },
    { key = "hpMarker",            label = "HP threshold marker",        cvar = "hpMarkerEnabled",                   default = false },
    { key = "playerCastOverlay",   label = "Player Cast overlay",        cvar = "playerCastOverlayEnabled",          default = true  },
    { key = "weakAuras",           label = "WeakAuras integration",       cvar = "moduleWeakAurasEnabled",            default = true  },
}

-- Healthbar, castbar and aura frames no longer have independent runtime-module
-- switches. Overlay module entries above directly use their functional visibility
-- settings, so each overlay has one authoritative on/off value.
S2KNP_CUSTOM_NAMEPLATE_VIRTUAL_MODULES = {
    health = true,
    castbar = true,
    buffs = true,
    debuffs = true,
    blizzardVisuals = true,
}

S2KNP_MODULE_DEFS_BY_KEY = {}
for _, def in ipairs(S2KNP_MODULE_DEFS) do
    S2KNP_MODULE_DEFS_BY_KEY[def.key] = def
end

S2KNP_MODULE_ALIASES = {
    custom = "customNameplates",
    customnameplate = "customNameplates",
    customnameplates = "customNameplates",
    nameplate = "customNameplates",
    nameplates = "customNameplates",
    hp = "health",
    healthbar = "health",
    targetruntime = "targetRuntimeHealth",
    targethealth = "targetRuntimeHealth",
    targethealthruntime = "targetRuntimeHealth",
    name = "names",
    names = "names",
    hpratio = "hpRatio",
    ratio = "hpRatio",
    level = "levelOverlay",
    leveloverlay = "levelOverlay",
    marker = "hpMarker",
    hpmarker = "hpMarker",
    cast = "castbar",
    castbar = "castbar",
    playercast = "playerCastOverlay",
    overlay = "playerCastOverlay",
    playercastoverlay = "playerCastOverlay",
    buff = "buffs",
    buffs = "buffs",
    debuff = "debuffs",
    debuffs = "debuffs",
    aura = "auras",
    auras = "auras",
    wa = "weakAuras",
    weakaura = "weakAuras",
    weakauras = "weakAuras",
    blizzard = "blizzardVisuals",
    blizzardvisuals = "blizzardVisuals",
}

S2KNP_MODULE_EVENTS = {
    "UNIT_MAXHEALTH", "UNIT_HEALTH", "UNIT_AURA", "UNIT_NAME_UPDATE",
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_UPDATE",
}

function S2KNP_NormalizeModuleKey(key)
    key = tostring(key or ""):gsub("%s+", ""):gsub("[%-%_]", ""):lower()
    if key == "" then return nil end
    return S2KNP_MODULE_ALIASES[key]
end

function S2KNP_ModuleEnabled(key)
    local enabled = CFG and CFG.enabled ~= false
    if key == "customNameplates" then return enabled end
    if not enabled then return false end
    if key == "auras" then
        return (CFG.buffFrameEnabled ~= false) or (CFG.debuffFrameEnabled ~= false)
    end
    if S2KNP_CUSTOM_NAMEPLATE_VIRTUAL_MODULES[key] then return true end

    local def = S2KNP_MODULE_DEFS_BY_KEY[key]
    return def and (not def.cvar or CFG[def.cvar] ~= false) or false
end

function S2KNP_RebuildRuntimeFlags()
    local flags = State.runtimeFlags or {}
    local enabled = DB ~= nil and CFG and CFG.enabled ~= false

    flags.enabled = enabled
    flags.health = enabled
    flags.names = enabled and CFG.showNames ~= false
    flags.hpRatio = enabled and CFG.hpRatioText ~= false
    flags.levelOverlay = enabled and CFG.levelOverlayEnabled ~= false
    flags.hpMarker = enabled and CFG.hpMarkerEnabled ~= false
    flags.castbar = enabled and CFG.showCastbar ~= false
    flags.buffs = enabled and CFG.buffFrameEnabled ~= false
    flags.debuffs = enabled and CFG.debuffFrameEnabled ~= false
    flags.auras = flags.buffs or flags.debuffs
    flags.playerCastOverlay = enabled and CFG.playerCastOverlayEnabled ~= false
    flags.targetRuntimeHealth = enabled and CFG.moduleTargetRuntimeHealthEnabled ~= false
    flags.weakAurasModule = enabled and CFG.moduleWeakAurasEnabled ~= false
    flags.weakAuras = flags.weakAurasModule and CFG.weakAurasEnabled == true
    flags.weakAuraAnchorStats = enabled and CFG.debugWeakAuraAnchorStatsEnabled == true
    flags.targetRuntime = flags.targetRuntimeHealth
        or flags.playerCastOverlay
    flags.castRuntime = flags.castbar
    flags.healthEvents = enabled
    flags.spellEvents = flags.castbar or flags.playerCastOverlay
    flags.onUpdate = flags.weakAuras or flags.targetRuntime or flags.castRuntime or flags.auras or flags.weakAuraAnchorStats

    State.runtimeFlags = flags
    return flags
end

function S2KNP_OnUpdateNeeded()
    local flags = State.runtimeFlags
    return flags and flags.onUpdate or false
end

function S2KNP_ApplyModuleRuntimeScript()
    if not A or not A.SetScript then return end
    if S2KNP_OnUpdateNeeded() and type(S2KNP_OnUpdate) == "function" then
        A:SetScript("OnUpdate", S2KNP_OnUpdate)
    else
        A:SetScript("OnUpdate", nil)
    end
end

function S2KNP_RegisterBaseEvents()
    if not A or not A.RegisterEvent then return end
    A:RegisterEvent("ADDON_LOADED")
    A:RegisterEvent("PLAYER_LOGIN")
    A:RegisterEvent("PLAYER_ENTERING_WORLD")
    A:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    A:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    A:RegisterEvent("PLAYER_TARGET_CHANGED")
    A:RegisterEvent("PLAYER_REGEN_ENABLED")
    A:RegisterEvent("QUEST_DETAIL")
    A:RegisterEvent("QUEST_PROGRESS")
    A:RegisterEvent("QUEST_COMPLETE")
    A:RegisterEvent("QUEST_ACCEPT_CONFIRM")
    A:RegisterEvent("QUEST_LOG_UPDATE")
end

function S2KNP_ApplyModuleEventSubscriptions()
    if not A or not A.RegisterEvent then return end

    for _, event in ipairs(S2KNP_MODULE_EVENTS) do
        A:UnregisterEvent(event)
    end

    local flags = State.runtimeFlags or S2KNP_RebuildRuntimeFlags()
    if flags.healthEvents then
        A:RegisterEvent("UNIT_MAXHEALTH")
        A:RegisterEvent("UNIT_HEALTH")
    end
    if flags.auras then A:RegisterEvent("UNIT_AURA") end
    if flags.names then A:RegisterEvent("UNIT_NAME_UPDATE") end
    if flags.spellEvents then
        A:RegisterEvent("UNIT_SPELLCAST_START")
        A:RegisterEvent("UNIT_SPELLCAST_STOP")
        A:RegisterEvent("UNIT_SPELLCAST_FAILED")
        A:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        A:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
        A:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
        A:RegisterEvent("UNIT_SPELLCAST_DELAYED")
        A:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    end
end

function S2KNP_ApplyCustomNameplatesState(refreshEnabled)
    if not State or type(State.plates) ~= "table" then return end

    if not CFG or CFG.enabled == false then
        for _, ctx in pairs(State.plates) do
            if ctx then
                if ApplyBlizzardVisualState then ApplyBlizzardVisualState(ctx) end
                if ResetNameplateContextVisuals then
                    ResetNameplateContextVisuals(ctx, true)
                elseif ctx.root then
                    ctx.root:Hide()
                end
            end
        end
        for unit in pairs(State.activeCastUnits or {}) do State.activeCastUnits[unit] = nil end
        for unit in pairs(State.auraDirtyUnits or {}) do State.auraDirtyUnits[unit] = nil end
        return
    end

    if refreshEnabled and UpdateAll then
        UpdateAll(true)
    end
end

function S2KNP_ApplyModuleState()
    S2KNP_RebuildRuntimeFlags()
    S2KNP_ApplyModuleEventSubscriptions()
    S2KNP_ApplyModuleRuntimeScript()
    S2KNP_ApplyCustomNameplatesState(false)
end

function S2KNP_SetModuleEnabled(key, enabled)
    key = S2KNP_NormalizeModuleKey(key)
    if key == "auras" or S2KNP_CUSTOM_NAMEPLATE_VIRTUAL_MODULES[key] then
        -- These are governed by Custom Nameplates and/or their own feature
        -- settings, not independent runtime-module switches.
        return false
    end

    local def = S2KNP_MODULE_DEFS_BY_KEY[key]
    if not def or not def.cvar then
        return false
    end

    if SetBool then
        SetBool(def.cvar, enabled and true or false)
    elseif DB and CFG then
        DB[def.cvar] = enabled and true or false
        CFG[def.cvar] = DB[def.cvar]
    end

    S2KNP_ApplyModuleState()
    if HideDisabledModuleVisuals then
        HideDisabledModuleVisuals()
    end
    if key == "customNameplates" then
        S2KNP_ApplyCustomNameplatesState(true)
    end
    return true
end

function HideDisabledModuleVisuals()
    if not State or type(State.plates) ~= "table" then return end
    if not S2KNP_ModuleEnabled("customNameplates") then
        S2KNP_ApplyCustomNameplatesState(false)
        return
    end

    for _, ctx in pairs(State.plates) do
        if ctx then
            if not S2KNP_ModuleEnabled("names") and ctx.name then ctx.name:SetText(""); ctx.name:Hide() end
            if not S2KNP_ModuleEnabled("hpRatio") and ctx.ratio then ctx.ratio:SetText(""); ctx.ratio:Hide() end
            if not S2KNP_ModuleEnabled("levelOverlay") and ctx.levelText then ctx.levelText:SetText(""); ctx.levelText:Hide() end
            if not S2KNP_ModuleEnabled("hpMarker") and ctx.hpMarker then ctx.hpMarker:Hide() end
            if not S2KNP_ModuleEnabled("playerCastOverlay") and HidePlayerCastOverlay then HidePlayerCastOverlay(ctx) end
            if not S2KNP_ModuleEnabled("weakAuras") and HideWAAnchors then HideWAAnchors(ctx) end
        end
    end
end

function S2KNP_PrintModuleList()
    print("---- s2k:Enhancements modules ----")
    for _, def in ipairs(S2KNP_MODULE_DEFS or {}) do
        local on = S2KNP_ModuleEnabled(def.key) and "ON " or "OFF"
        print(string.format("%s  %-22s  %s", on, def.key, def.label or ""))
    end
    print("Commands: /s2kemod list | /s2kemod off names | /s2kemod on weakauras")
end

SLASH_S2KNPMODULE1 = "/s2kemod"
SLASH_S2KNPMODULE2 = "/s2knpmod"
SlashCmdList["S2KNPMODULE"] = function(msg)
    msg = tostring(msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local lower = msg:lower()
    if lower == "" or lower == "list" or lower == "help" or lower == "?" then
        S2KNP_PrintModuleList()
        return
    end
    local action, name = lower:match("^(on)%s+(.+)$")
    if not action then action, name = lower:match("^(off)%s+(.+)$") end
    if not action then action, name = lower:match("^(enable)%s+(.+)$") end
    if not action then action, name = lower:match("^(disable)%s+(.+)$") end
    if action and name then
        local enabled = (action == "on" or action == "enable")
        if S2KNP_SetModuleEnabled(name, enabled) then
            print("s2k:Enhancements module " .. tostring(name) .. ": " .. (enabled and "ON" or "OFF"))
            return
        end
    end
    print("s2k:Enhancements: unknown or master-controlled module. Use /s2kemod list")
end