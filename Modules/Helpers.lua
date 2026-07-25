-- =========================================================
-- Helpers
-- =========================================================

function SafeCall(fn)
    if type(fn) ~= "function" then return false end
    return pcall(fn)
end

function S2KPrint(message)
    message = tostring(message or "")
    if message == "" then
        return
    end

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffs2k:Enhancements:|r " .. message)
    end
end

function IsInCombat()
    return InCombatLockdown and InCombatLockdown()
end


-- Builds a de-duplicated media list from built-ins and LibSharedMedia.
function BuildMediaOptions(mediaType, builtins)
    local list, byKey, seenPaths = {}, {}, {}

    local function Add(key, label, path)
        if not key or not label or not path or byKey[key] then return end
        local pathKey = tostring(path):lower()
        if seenPaths[pathKey] and tostring(key):sub(1, 4) == "LSM:" then return end

        local option = { key = key, label = label, path = path }
        list[#list + 1] = option
        byKey[key] = option
        seenPaths[pathKey] = true
    end

    for _, option in ipairs(builtins or {}) do
        Add(option.key, option.label, option.path)
    end

    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if lsm and lsm.List and lsm.Fetch then
        local ok, names = pcall(lsm.List, lsm, mediaType)
        if ok and type(names) == "table" then
            for _, name in ipairs(names) do
                local okFetch, path = pcall(lsm.Fetch, lsm, mediaType, name)
                if okFetch and path then
                    Add("LSM:" .. tostring(name), tostring(name), path)
                end
            end
        end
    end

    table.sort(list, function(a, b)
        return tostring(a.label):lower() < tostring(b.label):lower()
    end)
    return list, byKey
end

-- Frame, color and CVar helpers used by the runtime and options modules.
function IsFrameObject(obj)
    local t = type(obj)
    return (t == "table" or t == "userdata")
end

function HasMethod(obj, methodName)
    if not IsFrameObject(obj) then
        return false
    end

    return type(obj[methodName]) == "function"
end

function IsNameplateUnit(unit)
    return unit and tostring(unit):match("^nameplate%d+$") ~= nil
end

function IsTargetUnit(unit)
    if not unit or not UnitExists(unit) or not UnitExists("target") then return false end
    if UnitIsUnit then
        local ok, same = pcall(UnitIsUnit, unit, "target")
        if ok and same then return true end
    end
    local a = UnitGUID(unit)
    local b = UnitGUID("target")
    return a and b and a == b
end

function FrameIsVisible(frame)
    if not IsFrameObject(frame) then return false end

    -- Private 7.3.5 servers can report frame:IsVisible() strangely for nameplates,
    -- especially around line-of-sight / distance. For nameplate ownership we only
    -- require that the Blizzard nameplate frame exists and is shown.
    if HasMethod(frame, "IsShown") then
        local ok, shown = pcall(frame.IsShown, frame)
        if ok and not shown then return false end
    end

    return true
end

function GetPlate(unit)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok then return plate end
    return nil
end

function GetUnitFrameFromPlate(plate)
    if not IsFrameObject(plate) then return nil end
    return plate.UnitFrame
end

function GetHealthBarFromUF(uf)
    if not IsFrameObject(uf) then return nil end

    local hb = uf.healthBar or uf.HealthBar
    if IsFrameObject(hb) then
        return hb
    end

    return nil
end

function GetCastBarFromUF(uf)
    if not IsFrameObject(uf) then return nil end

    local cb = uf.castBar or uf.CastBar or uf.castbar
    if IsFrameObject(cb) then
        return cb
    end

    return nil
end

function GetBuffFrameFromUF(uf)
    if not IsFrameObject(uf) then return nil end

    local bf = uf.BuffFrame or uf.buffFrame
    if IsFrameObject(bf) then
        return bf
    end

    return nil
end

function GetNameFrameFromUF(uf)
    if not IsFrameObject(uf) then return nil end

    local f = uf.name or uf.Name or uf.nameText or uf.NameText or uf.unitName or uf.UnitName or uf.nameString or uf.NameString
    if HasMethod(f, "SetAlpha") then return f end

    if IsFrameObject(uf.NameFrame) then
        local nf = uf.NameFrame.name or uf.NameFrame.Name or uf.NameFrame.text or uf.NameFrame.Text or uf.NameFrame
        if HasMethod(nf, "SetAlpha") then return nf end
    end

    return nil
end

function GetReactionColor(unit)
    if UnitIsDead(unit) then
        return 0.35, 0.35, 0.35
    end
    if UnitIsFriend("player", unit) then
        return 0.1, 0.85, 0.15
    end
    if UnitCanAttack("player", unit) then
        return 0.85, 0.1, 0.1
    end
    return 0.85, 0.75, 0.1
end

function GetCustomColor(prefix, fallbackR, fallbackG, fallbackB, fallbackA)
    local r = tonumber(CFG[prefix .. "R"]) or fallbackR or 1
    local g = tonumber(CFG[prefix .. "G"]) or fallbackG or 1
    local b = tonumber(CFG[prefix .. "B"]) or fallbackB or 1
    local a = tonumber(CFG[prefix .. "A"]) or fallbackA or 1
    return r, g, b, a
end

function GetHealthbarColor(unit)
    if CFG.targetHealthbarOverride and IsTargetUnit(unit) then
        if CFG.targetHealthUseReactionColor then
            local r, g, b = GetReactionColor(unit)
            return r, g, b, 1
        end
        return GetCustomColor('targetHealthColor', 0.85, 0.10, 0.10, 1)
    end

    if CFG.healthUseReactionColor then
        local r, g, b = GetReactionColor(unit)
        return r, g, b, 1
    end

    return GetCustomColor("healthColor", 0.85, 0.10, 0.10, 1)
end

function GetCastbarColor()
    return GetCustomColor("castbarColor", 1.00, 0.70, 0.10, 1)
end

function GetHealthBackdropColor(ctx)
    if ctx and CFG.targetHealthbarOverride and IsTargetUnit(ctx.unit) then
        return GetCustomColor('targetHealthBackdropColor', 0.00, 0.00, 0.00, 0.65)
    end
    return GetCustomColor('healthBackdropColor', 0.00, 0.00, 0.00, CFG.healthBackgroundAlpha or 0.65)
end

function GetCastbarSpellNameColor()
    return GetCustomColor("castbarSpellNameColor", 1.00, 1.00, 1.00, 1.00)
end

function GetCastbarBackdropColor()
    return GetCustomColor('castbarBackdropColor', 0.00, 0.00, 0.00, 0.75)
end

function GetCastbarBorderColor()
    return GetCustomColor("castbarBorderColor", 0.00, 0.00, 0.00, 1)
end

function GetPlayerCastOverlayColor()
    return GetCustomColor("playerCastOverlayColor", 0.20, 0.55, 1.00, 0.55)
end

function GetPlayerCastOverlaySparkColor()
    return GetCustomColor("playerCastOverlaySparkColor", 1.00, 1.00, 1.00, 1.00)
end

function GetLevelOverlayColor()
    return GetCustomColor("levelOverlayColor", 1.00, 0.82, 0.00, 1.00)
end

function GetHPRatioColor()
    return GetCustomColor("hpRatioColor", 1.00, 1.00, 1.00, 1.00)
end

function GetHPMarkerColor()
    return GetCustomColor("hpMarkerColor", 1.00, 1.00, 1.00, 1.00)
end

function GetAllBorderColor()
    return GetCustomColor("borderColor", 0.00, 0.00, 0.00, 1)
end

function GetTargetBorderColor()
    return GetCustomColor("targetBorderColor", 1.00, 1.00, 1.00, 1)
end

function GetCurrentNameplateBorderColor(ctx)
    if ctx and ctx.unit and CFG.targetHealthbarOverride and IsTargetUnit(ctx.unit) then
        return GetTargetBorderColor()
    end
    return GetAllBorderColor()
end

function GetHPMarkerEffectiveColor(ctx)
    local _, _, _, markerAlpha = GetHPMarkerColor()
    if CFG.hpMarkerUseBorderColor then
        local r, g, b = GetCurrentNameplateBorderColor(ctx)
        return r, g, b, markerAlpha
    end
    return GetHPMarkerColor()
end

function SetCVarIfChanged(cvarName, value)
    if not SetCVar or not cvarName then return false end

    local textValue = tostring(value)
    if GetCVar then
        local ok, currentValue = pcall(GetCVar, cvarName)
        if not ok or currentValue == nil then
            return false
        end

        local current = tostring(currentValue)
        if current == textValue then return false end

        -- Avoid writes for formatting-only differences such as 1 and 1.0.
        local currentNumber, newNumber = tonumber(current), tonumber(textValue)
        if currentNumber and newNumber and math.abs(currentNumber - newNumber) < 0.000001 then
            return false
        end
    end

    SetCVar(cvarName, textValue)
    return true
end

function ApplyNameplateBaseCVar()
    local value = CFG.nameplateAtBase and "2" or "0"
    SetCVarIfChanged("nameplateOtherAtBase", value)
end

function ApplyNameplateHitboxSize()
    if not C_NamePlate then return end

    local width = math.max(1, tonumber(CFG.nameplateHitboxWidth) or 110)
    local height = math.max(1, tonumber(CFG.nameplateHitboxHeight) or 45)

    if C_NamePlate.SetNamePlateEnemySize then
        pcall(C_NamePlate.SetNamePlateEnemySize, width, height)
    end
    if C_NamePlate.SetNamePlateFriendlySize then
        pcall(C_NamePlate.SetNamePlateFriendlySize, width, height)
    end
end

function ApplyNameplateCVarSettings()
    if InCombatLockdown and InCombatLockdown() then
        State.pendingCVarApply = true
        return
    end

    State.pendingCVarApply = false
    State.applyingNameplateCVars = true
    ApplyNameplateBaseCVar()
    ApplyNameplateHitboxSize()

    local large = CFG.largeNameplates == true
    local largeModeChanged = SetCVarIfChanged("NamePlateHorizontalScale", large and 1.4 or 1.0)
    largeModeChanged = SetCVarIfChanged("NamePlateVerticalScale", large and 2.7 or 1.0) or largeModeChanged

    for key, def in pairs(CVAR_OPTION_DEFS) do
        local value = tonumber(CFG[key])
        if value == nil then
            value = def.default or 0
        end

        if def.integer then
            value = math.floor(value + 0.5)
        end

        SetCVarIfChanged(def.cvar, value)
    end

    for key, def in pairs(NAMEPLATE_BOOLEAN_CVAR_DEFS or {}) do
        SetCVarIfChanged(def.cvar, CFG[key] and 1 or 0)
    end

    if largeModeChanged and NamePlateDriverFrame and NamePlateDriverFrame.UpdateNamePlateOptions then
        pcall(NamePlateDriverFrame.UpdateNamePlateOptions, NamePlateDriverFrame)
    end
    State.applyingNameplateCVars = false
end

function SyncNameplateSettingFromCVar(cvarName)
    if State.applyingNameplateCVars or not DB or not CFG then
        return false, false
    end

    local normalized = tostring(cvarName or ""):lower()
    if normalized == "" then
        return false, false
    end

    if normalized == "nameplatehorizontalscale" or normalized == "nameplateverticalscale" then
        local vertical = GetNumericCVar("NamePlateVerticalScale", 1)
        local large = vertical > 1.001
        if CFG.largeNameplates ~= large then
            SetBool("largeNameplates", large)
            return true, true
        end
        return false, false
    end

    local mapping = NAMEPLATE_CVAR_KEYS_BY_NAME and NAMEPLATE_CVAR_KEYS_BY_NAME[normalized]
    if not mapping then
        return false, false
    end

    if mapping.boolean then
        local value = GetBooleanCVar(cvarName, CFG[mapping.key])
        if CFG[mapping.key] ~= value then
            SetBool(mapping.key, value)
            return true, false
        end
    elseif mapping.atBase then
        local value = GetNumericCVar(cvarName, 0) == 2
        if CFG[mapping.key] ~= value then
            SetBool(mapping.key, value)
            return true, false
        end
    elseif mapping.numeric then
        local def = CVAR_OPTION_DEFS[mapping.key]
        local value = GetNumericCVar(cvarName, def and def.default or CFG[mapping.key])
        if def and def.integer then
            value = math.floor(value + 0.5)
        end
        if tonumber(CFG[mapping.key]) ~= value then
            SetNum(mapping.key, value)
            local refreshScale = mapping.key == "nameplateGlobalScale"
                or mapping.key == "nameplateSelectedScale"
                or mapping.key == "nameplateLargerScale"
            return true, refreshScale
        end
    end

    return false, false
end
