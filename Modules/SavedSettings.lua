-- =========================================================
-- Saved settings / profiles
-- =========================================================


CVAR_OPTION_DEFS = {
    nameplateGlobalScale       = { cvar = "nameplateGlobalScale",       default = 1.00,  min = 0.50, max = 2.00, step = 0.05 },
    nameplateSelectedScale     = { cvar = "nameplateSelectedScale",     default = 1.00,  min = 0.50, max = 2.50, step = 0.05 },
    nameplateLargeBottomInset  = { cvar = "nameplateLargeBottomInset",  default = 0.15,  min = 0.00, max = 1.00, step = 0.01 },
    nameplateLargerScale       = { cvar = "nameplateLargerScale",       default = 1.20,  min = 0.50, max = 2.50, step = 0.05 },
    nameplateLargeTopInset     = { cvar = "nameplateLargeTopInset",     default = 0.15,  min = 0.00, max = 1.00, step = 0.01 },
    nameplateMaxDistance       = { cvar = "nameplateMaxDistance",       default = 60.00, min = 10.00, max = 100.00, step = 1.00 },
    nameplateMotion            = { cvar = "nameplateMotion",            default = 0,     min = 0,    max = 2,    step = 1, integer = true },
    nameplateMotionSpeed       = { cvar = "nameplateMotionSpeed",       default = 0.025, min = 0.00, max = 1.00, step = 0.005 },
    nameplateOtherBottomInset  = { cvar = "nameplateOtherBottomInset",  default = 0.08,  min = 0.00, max = 1.00, step = 0.01 },
    nameplateOtherTopInset     = { cvar = "nameplateOtherTopInset",     default = 0.08,  min = 0.00, max = 1.00, step = 0.01 },
    nameplateOverlapH          = { cvar = "nameplateOverlapH",          default = 0.80,  min = 0.00, max = 3.00, step = 0.05 },
    nameplateOverlapV          = { cvar = "nameplateOverlapV",          default = 1.10,  min = 0.00, max = 3.00, step = 0.05 },
}

function GetNumericCVar(cvarName, fallback)
    if not GetCVar or not cvarName then
        return fallback
    end

    local value = tonumber(GetCVar(cvarName))
    if value == nil then
        return fallback
    end

    return value
end

WEAKAURAS_MIN_VERSION = { 2, 5, 12 }
WEAKAURAS_REQUIRED_WOW_VERSION = "7.3.5"

FIXED_WA_ANCHOR_GROUP_ID = "s2k_NP"
FIXED_WA_TARGET_ID = "s2k_NP_Target"
FIXED_WA_FALLBACK_ID = "s2k_NP_Fallback"
FIXED_WA_TOP_GROUP_ID = "s2k_NP_BT"
FIXED_WA_BOTTOM_GROUP_ID = "s2k_NP_BB"
FIXED_WA_TEXTURE = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_White"

WA_STRING_DEFAULT_KEYS = {
    weakAuraAnchorGroupId = true,
    weakAuraTargetId = true,
    weakAuraFallbackId = true,
}

function CopySavedValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for k, v in pairs(value) do
        copy[k] = CopySavedValue(v)
    end
    return copy
end

function ApplyFixedWeakAuraNamesToDB()
    if type(DB) ~= "table" then
        return
    end

    -- v1.14.10: the WA scaffold names are intentionally fixed.  Older
    -- development builds allowed these fields to be edited, so force them
    -- back to the supported names while keeping the booleans/profile settings.
    DB.weakAuraAnchorGroupId = FIXED_WA_ANCHOR_GROUP_ID
    DB.weakAuraTargetId = FIXED_WA_TARGET_ID
    DB.weakAuraFallbackId = FIXED_WA_FALLBACK_ID
    DB.weakAuraTopGroupId = FIXED_WA_TOP_GROUP_ID
    DB.weakAuraBottomGroupId = FIXED_WA_BOTTOM_GROUP_ID
    DB.weakAuraProgressBarGroups = { FIXED_WA_TOP_GROUP_ID, FIXED_WA_BOTTOM_GROUP_ID }
end


function NormalizeDominosSettingsOnDB()
    if type(DB) ~= "table" then
        return
    end

    if type(DB.dominosBars) ~= "table" then
        DB.dominosBars = {}
    end

    -- DominosIntegration.lua expands this table to the actual number of action
    -- bars after Dominos has loaded. Ten entries remain the safe 7.3.5 fallback
    -- while SavedVariables are initialized before optional dependencies.
    for i = 1, 10 do
        if type(DB.dominosBars[i]) ~= "table" then
            DB.dominosBars[i] = {}
        end
        DB.dominosBars[i].anchored = DB.dominosBars[i].anchored and true or false
        DB.dominosBars[i].showStates = nil
    end

    local mode = tostring(DB.dominosLayoutMode or "LOCKED"):upper()
    if mode ~= "LOCKED" and mode ~= "EDITABLE" then
        mode = "LOCKED"
    end
    DB.dominosLayoutMode = mode

    local direction = tostring(DB.dominosEditableDirection or "HORIZONTAL"):upper()
    if direction ~= "HORIZONTAL" and direction ~= "VERTICAL" then
        direction = "HORIZONTAL"
    end
    DB.dominosEditableDirection = direction

    DB.dominosIntegrationEnabled = DB.dominosIntegrationEnabled and true or false
    if type(DB.dominosEditSession) ~= "table" then
        DB.dominosEditSession = { active = false, bars = {} }
    end
    if type(DB.dominosEditSession.bars) ~= "table" then
        DB.dominosEditSession.bars = {}
    end
    DB.dominosEditSession.active = DB.dominosEditSession.active and true or false
end

function CopyDefaults()
    if type(DB) ~= "table" then
        return
    end

    -- Rebuild CFG from the active profile every time. Do not leave stale values
    -- from the previously active profile in memory. This matters when older
    -- profiles do not contain a key that newer builds added later.
    for k in pairs(CFG or {}) do
        CFG[k] = nil
    end

    for k, v in pairs(DEFAULTS) do
        if DB[k] == nil then
            local cvarDef = CVAR_OPTION_DEFS[k]
            if cvarDef then
                DB[k] = GetNumericCVar(cvarDef.cvar, cvarDef.default or v)
            else
                DB[k] = CopySavedValue(v)
            end
        end

        -- Earlier development builds could save the WeakAura region names as
        -- empty strings while still internally falling back to defaults. That
        -- made the Interface panel look blank even though the addon behaved as
        -- if default IDs were present. Keep user custom names, but repair empty
        -- values so the edit boxes show the real active IDs after reload.
        if WA_STRING_DEFAULT_KEYS[k]
        and type(v) == "string"
        and (DB[k] == nil or tostring(DB[k]) == "")
        then
            DB[k] = v
        end
    end

    ApplyFixedWeakAuraNamesToDB()
    NormalizeDominosSettingsOnDB()

    for k in pairs(DEFAULTS) do
        CFG[k] = DB[k]
    end
end

function SetBool(key, value)
    DB[key] = value and true or false
    CFG[key] = DB[key]
end

function SetNum(key, value)
    value = tonumber(value) or 0
    DB[key] = value
    CFG[key] = value
end

function SetStr(key, value)
    value = tostring(value or "")
    DB[key] = value
    CFG[key] = value
end


function CopyProfileTable(src)
    local dst = {}

    if type(src) == "table" then
        for k, v in pairs(src) do
            if k ~= "profiles" and k ~= "currentProfile" and k ~= "profileVersion" then
                dst[k] = CopySavedValue(v)
            end
        end
    end

    return dst
end

function EnsureDatabase()
    -- First s2k:Enhancements launch migrates the old s2k_NameplatesDB table by reference,
    -- preserving profiles and settings. Both globals then point to the same DB
    -- so older macros/integrations continue to work.
    if type(_G.s2k_EnhancementsDB) ~= "table" then
        if type(_G.s2k_NameplatesDB) == "table" then
            _G.s2k_EnhancementsDB = _G.s2k_NameplatesDB
        else
            _G.s2k_EnhancementsDB = {}
        end
    end

    _G.s2k_NameplatesDB = _G.s2k_EnhancementsDB
    DBRoot = _G.s2k_EnhancementsDB

    if type(DBRoot.profiles) ~= "table" then
        local oldFlatSettings = CopyProfileTable(DBRoot)
        DBRoot.profiles = {}
        DBRoot.currentProfile = tostring(DBRoot.currentProfile or "Default")
        if DBRoot.currentProfile == "" then
            DBRoot.currentProfile = "Default"
        end
        DBRoot.profiles[DBRoot.currentProfile] = oldFlatSettings
    end

    if type(DBRoot.currentProfile) ~= "string" or DBRoot.currentProfile == "" then
        DBRoot.currentProfile = "Default"
    end

    if type(DBRoot.profiles[DBRoot.currentProfile]) ~= "table" then
        DBRoot.profiles[DBRoot.currentProfile] = {}
    end

    DB = DBRoot.profiles[DBRoot.currentProfile]
    CopyDefaults()
end

function GetCurrentProfileName()
    if DBRoot and type(DBRoot.currentProfile) == "string" and DBRoot.currentProfile ~= "" then
        return DBRoot.currentProfile
    end

    return "Default"
end

function GetProfileOptions()
    local options = {}
    local profiles = DBRoot and DBRoot.profiles

    if type(profiles) == "table" then
        for name in pairs(profiles) do
            options[#options + 1] = {
                key = tostring(name),
                label = tostring(name),
            }
        end
    end

    table.sort(options, function(a, b)
        return tostring(a.label):lower() < tostring(b.label):lower()
    end)

    if #options == 0 then
        options[1] = { key = "Default", label = "Default" }
    end

    return options
end
