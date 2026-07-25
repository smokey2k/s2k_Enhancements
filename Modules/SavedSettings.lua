-- =========================================================
-- Saved settings / profiles
-- =========================================================


CVAR_OPTION_DEFS = {
    nameplateGlobalScale       = { cvar = "nameplateGlobalScale",       default = 1.00,  min = 0.50, max = 2.00, step = 0.05 },
    nameplateSelectedScale     = { cvar = "nameplateSelectedScale",     default = 1.00,  min = 0.50, max = 2.50, step = 0.05 },
    nameplateLargeBottomInset  = { cvar = "nameplateLargeBottomInset",  default = 0.15,  min = 0.00, max = 1.00, step = 0.01 },
    nameplateLargerScale       = { cvar = "nameplateLargerScale",       default = 1.20,  min = 0.50, max = 2.50, step = 0.05 },
    nameplateLargeTopInset     = { cvar = "nameplateLargeTopInset",     default = 0.15,  min = 0.00, max = 1.00, step = 0.01 },
    nameplateMaxDistance       = { cvar = "nameplateMaxDistance",       default = 60.00, min = 0.00,  max = 60.00,  step = 1.00 },
    nameplateMotion            = { cvar = "nameplateMotion",            default = 0,     min = 0,    max = 2,    step = 1, integer = true },
    nameplateMotionSpeed       = { cvar = "nameplateMotionSpeed",       default = 0.025, min = 0.00, max = 1.00, step = 0.005 },
    nameplateOtherBottomInset  = { cvar = "nameplateOtherBottomInset",  default = 0.08,  min = 0.00, max = 1.00, step = 0.01 },
    nameplateOtherTopInset     = { cvar = "nameplateOtherTopInset",     default = 0.08,  min = 0.00, max = 1.00, step = 0.01 },
    nameplateOverlapH          = { cvar = "nameplateOverlapH",          default = 0.80,  min = 0.00, max = 3.00, step = 0.05 },
    nameplateOverlapV          = { cvar = "nameplateOverlapV",          default = 1.10,  min = 0.00, max = 3.00, step = 0.05 },
}

NAMEPLATE_BOOLEAN_CVAR_DEFS = {
    nameplateShowSelf            = { cvar = "nameplateShowSelf",            default = true  },
    nameplateResourceOnTarget    = { cvar = "nameplateResourceOnTarget",    default = false },
    nameplateShowAll             = { cvar = "nameplateShowAll",             default = false },
    nameplateShowEnemies         = { cvar = "nameplateShowEnemies",         default = true  },
    nameplateShowEnemyMinions    = { cvar = "nameplateShowEnemyMinions",    default = false },
    nameplateShowEnemyMinus      = { cvar = "nameplateShowEnemyMinus",      default = true  },
    nameplateShowFriends         = { cvar = "nameplateShowFriends",         default = false },
    nameplateShowFriendlyMinions = { cvar = "nameplateShowFriendlyMinions", default = false },
}

NAMEPLATE_CVAR_KEYS_BY_NAME = {}
for key, def in pairs(CVAR_OPTION_DEFS) do
    NAMEPLATE_CVAR_KEYS_BY_NAME[tostring(def.cvar):lower()] = { key = key, numeric = true }
end
for key, def in pairs(NAMEPLATE_BOOLEAN_CVAR_DEFS) do
    NAMEPLATE_CVAR_KEYS_BY_NAME[tostring(def.cvar):lower()] = { key = key, boolean = true }
end
NAMEPLATE_CVAR_KEYS_BY_NAME.nameplateotheratbase = { key = "nameplateAtBase", atBase = true }

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

function GetBooleanCVar(cvarName, fallback)
    local value = GetNumericCVar(cvarName, nil)
    if value == nil then
        return fallback and true or false
    end
    return value ~= 0
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
        local strata = DB.dominosBars[i].frameStrata
        DB.dominosBars[i].frameStrata = type(strata) == 'string' and strata:upper() or nil
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

    if not DB.borderMediaV1Migrated then
        local sizes = {NONE=0, THIN=1, THICK=2, HEAVY=3}
        local function Migrate(styleKey, textureKey, pathKey, sizeKey, offsetKey)
            local size = sizes[tostring(DB[styleKey] or 'THIN'):upper()] or 1
            DB[textureKey] = size <= 0 and 'NONE' or 'S2K_SOLID'
            DB[pathKey] = 'Interface\\Buttons\\WHITE8X8'
            DB[sizeKey], DB[offsetKey] = math.max(1, size), math.max(1, size)
        end
        Migrate('borderStyleKey', 'borderTextureKey', 'borderTexturePath', 'borderSize', 'borderOffset')
        Migrate('targetBorderStyleKey', 'targetBorderTextureKey', 'targetBorderTexturePath', 'targetBorderSize', 'targetBorderOffset')
        Migrate('castbarBorderStyleKey', 'castbarBorderTextureKey', 'castbarBorderTexturePath', 'castbarBorderSize', 'castbarBorderOffset')
        DB.borderMediaV1Migrated = true
    end

    if not DB.targetHealthbarV1Migrated then
        DB.targetPlateWidth = DB.plateWidth
        DB.targetPlateHeight = DB.plateHeight
        DB.targetPlateYOffset = DB.plateYOffset
        DB.targetHealthTextureKey = DB.healthTextureKey
        DB.targetHealthTexturePath = DB.healthTexturePath
        DB.targetHealthUseReactionColor = DB.healthUseReactionColor
        DB.targetHealthColorR, DB.targetHealthColorG = DB.healthColorR, DB.healthColorG
        DB.targetHealthColorB, DB.targetHealthColorA = DB.healthColorB, DB.healthColorA
        DB.targetHealthBackdropTextureKey = DB.healthBackdropTextureKey
        DB.targetHealthBackdropTexturePath = DB.healthBackdropTexturePath
        DB.targetHealthBackdropColorR, DB.targetHealthBackdropColorG = DB.healthBackdropColorR, DB.healthBackdropColorG
        DB.targetHealthBackdropColorB, DB.targetHealthBackdropColorA = DB.healthBackdropColorB, DB.healthBackdropColorA
        DB.targetHealthbarOverride = DB.targetBorderOverride and true or false
        DB.targetHealthbarV1Migrated = true
    end

    if not DB.unifiedHealthbarSizeV1Migrated then
        local generalWidth = tonumber(DB.plateWidth) or tonumber(DEFAULTS.plateWidth) or 110
        local targetWidth = tonumber(DB.targetPlateWidth) or generalWidth
        local generalHeight = tonumber(DB.plateHeight) or tonumber(DEFAULTS.plateHeight) or 12
        local targetHeight = tonumber(DB.targetPlateHeight) or generalHeight

        DB.plateWidth = generalWidth
        DB.plateHeight = generalHeight
        DB.nameplateHitboxWidth = tonumber(DB.nameplateHitboxWidth) or math.max(generalWidth, targetWidth)
        DB.nameplateHitboxHeight = tonumber(DB.nameplateHitboxHeight) or math.max(45, generalHeight, targetHeight)
        DB.healthbarHitboxXOffset = tonumber(DB.healthbarHitboxXOffset) or 0
        DB.healthbarHitboxYOffset = tonumber(DB.healthbarHitboxYOffset) or tonumber(DB.plateYOffset) or 0
        DB.unifiedHealthbarSizeV1Migrated = true
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
            local booleanCVarDef = NAMEPLATE_BOOLEAN_CVAR_DEFS[k]
            if cvarDef then
                DB[k] = GetNumericCVar(cvarDef.cvar, cvarDef.default or v)
            elseif booleanCVarDef then
                DB[k] = GetBooleanCVar(booleanCVarDef.cvar, booleanCVarDef.default)
            elseif k == "largeNameplates" then
                DB[k] = GetNumericCVar("NamePlateVerticalScale", 1) > 1.001
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

    -- Retain the legacy SavedVariables key, but make the Custom Nameplates
    -- master switch the sole authority for Blizzard visual replacement.
    DB.hideBlizzardVisuals = DB.enabled ~= false
    CFG.hideBlizzardVisuals = DB.hideBlizzardVisuals
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

-- S2K_PROFILE_ACTIONS
function ApplyProfileSettingsNow()
    if IsInCombat() then
        State.pendingOptionsApply = true
        State.pendingCVarApply = true
        State.pendingMediaRefreshFonts = true
        State.pendingMediaRefreshTextures = true
        return
    end

    ApplyNameplateCVarSettings()
    if ApplyCameraDistanceSetting then ApplyCameraDistanceSetting() end
    if ApplySpellQueueWindowSetting then ApplySpellQueueWindowSetting() end
    if S2KNP_ApplyModuleState then S2KNP_ApplyModuleState() end
    if HideDisabledModuleVisuals then HideDisabledModuleVisuals() end
    RebuildFontOptions()
    RebuildStatusBarTextureOptions()
    RebuildBorderTextureOptions()
    RememberConfiguredFontPaths()
    RememberConfiguredStatusBarTexturePaths()
    RememberConfiguredBorderTexturePaths()
    if RecreateNameplatePreviewTextObjects then RecreateNameplatePreviewTextObjects() end
    if UpdateNameplatePreview then UpdateNameplatePreview() end
    RecreateVisibleTextObjects()
    ClearWeakAuraGroupChildrenCache()
    MarkWeakAurasDirty()
    MarkWeakAuraScaffoldDirty()
    UpdateAll(true)
    if ApplyChatSettings then ApplyChatSettings() end

    if UpdateWeakAurasBinding then
        UpdateWeakAurasBinding()
    end
    if RequestDominosApply then
        RequestDominosApply()
    end

    ScheduleVisibleMediaRefreshes(true, true, true)
    RefreshAllOptionsPanels()
end

function SwitchProfile(profileName)
    profileName = tostring(profileName or "")
    if profileName == "" then
        return
    end

    EnsureDatabase()

    if type(DBRoot.profiles[profileName]) ~= "table" then
        return
    end

    DBRoot.currentProfile = profileName
    DB = DBRoot.profiles[profileName]
    CopyDefaults()
    ApplyProfileSettingsNow()
end

function SaveCurrentProfileAs(profileName, switchAfterSave)
    profileName = tostring(profileName or "")
    profileName = profileName:gsub("^%s+", ""):gsub("%s+$", "")

    if profileName == "" then
        return
    end

    EnsureDatabase()

    -- Important profile semantics:
    -- Saving a profile should create/update a snapshot, but it should NOT
    -- silently switch the active DB pointer. The previous modular build switched
    -- to the newly saved profile here. That made it very easy to overwrite the
    -- profile that was just saved while continuing to tweak settings, so several
    -- non-default profiles could end up looking identical.
    DBRoot.profiles[profileName] = CopyProfileTable(DB)

    if switchAfterSave then
        DBRoot.currentProfile = profileName
        DB = DBRoot.profiles[profileName]
        CopyDefaults()
        ApplyProfileSettingsNow()
    else
        -- Keep the currently active profile untouched; only refresh the UI list.
        RefreshAllOptionsPanels()
    end

    if S2KPrint then
        S2KPrint("Saved profile: " .. profileName .. (switchAfterSave and " and switched to it" or ""))
    end
end

function DeleteCurrentProfile()
    EnsureDatabase()

    local current = GetCurrentProfileName()
    local profiles = DBRoot.profiles
    local count = 0
    local fallback

    for name in pairs(profiles) do
        count = count + 1
        if name ~= current and not fallback then
            fallback = name
        end
    end

    if count <= 1 then
        profiles[current] = {}
        DB = profiles[current]
        CopyDefaults()
        ApplyProfileSettingsNow()
        return
    end

    profiles[current] = nil
    DBRoot.currentProfile = fallback or "Default"

    if type(profiles[DBRoot.currentProfile]) ~= "table" then
        profiles[DBRoot.currentProfile] = {}
    end

    DB = profiles[DBRoot.currentProfile]
    CopyDefaults()
    ApplyProfileSettingsNow()
end

function ResetCurrentProfile()
    EnsureDatabase()

    local current = GetCurrentProfileName()
    DBRoot.profiles[current] = {}
    DB = DBRoot.profiles[current]
    CopyDefaults()
    ApplyProfileSettingsNow()
end

function ResetNameplateCVarSettingsToDefaults()
    EnsureDatabase()

    -- nameplateOtherAtBase is exposed as a checkbox outside CVAR_OPTION_DEFS.
    -- Reset it together with the other Blizzard nameplate CVars.
    SetBool("nameplateAtBase", DEFAULTS.nameplateAtBase and true or false)

    for key, def in pairs(CVAR_OPTION_DEFS) do
        SetNum(key, def.default or DEFAULTS[key] or 0)
    end
    SetBool("largeNameplates", DEFAULTS.largeNameplates and true or false)
    for key, def in pairs(NAMEPLATE_BOOLEAN_CVAR_DEFS) do
        SetBool(key, def.default and true or false)
    end

    ApplyProfileSettingsNow()
end

function CopyProfileToCurrent(profileName)
    profileName = tostring(profileName or "")
    profileName = profileName:gsub("^%s+", ""):gsub("%s+$", "")

    if profileName == "" then
        if S2KPrint then S2KPrint("No source profile selected.") end
        return false
    end

    EnsureDatabase()

    local current = GetCurrentProfileName()
    local source = DBRoot.profiles and DBRoot.profiles[profileName]

    if type(source) ~= "table" then
        if S2KPrint then S2KPrint("Profile not found: " .. tostring(profileName)) end
        return false
    end

    if profileName == current then
        if S2KPrint then S2KPrint("Source profile is already the current profile; nothing copied.") end
        return false
    end

    -- Copy FROM the selected source profile INTO the currently active profile.
    -- Important: keep DBRoot.currentProfile unchanged. Only the current profile's
    -- settings table is replaced by a deep copy of the source settings.
    DBRoot.profiles[current] = CopyProfileTable(source)
    DBRoot.currentProfile = current
    DB = DBRoot.profiles[current]
    CopyDefaults()
    ApplyProfileSettingsNow()

    if S2KPrint then
        S2KPrint("Copied profile '" .. tostring(profileName) .. "' into current profile '" .. tostring(current) .. "'.")
    end

    return true
end

local function GetFirstAvailableProfileName(excludeCurrent)
    local current = GetCurrentProfileName()
    local first
    for _, option in ipairs(GetProfileOptions()) do
        local key = tostring(option.key or "")
        if key ~= "" then
            first = first or key
            if excludeCurrent and key ~= current then return key end
        end
    end
    return first or current or "Default"
end

function GetSelectedCopySourceProfileName()
    EnsureDatabase()

    local selected = State.profileCopySourceName
    if type(selected) ~= "string" or selected == "" or not (DBRoot and DBRoot.profiles and DBRoot.profiles[selected]) then
        selected = GetFirstAvailableProfileName(true)
        State.profileCopySourceName = selected
    end

    return selected
end

function CopySelectedProfileToCurrent()
    local selected = GetSelectedCopySourceProfileName()
    return CopyProfileToCurrent(selected)
end


function S2KNP_PrintProfileList()
    EnsureDatabase()
    print("---- s2k:Enhancements profiles ----")
    print("Current: " .. tostring(GetCurrentProfileName()))
    for _, option in ipairs(GetProfileOptions()) do
        local name = tostring(option.key or "")
        local mark = (name == GetCurrentProfileName()) and "*" or " "
        print(mark .. " " .. name)
    end
    print("Commands: /s2knpprof list | /s2knpprof load NAME | /s2knpprof save NAME | /s2knpprof save-switch NAME | /s2knpprof copyfrom NAME")
end

SLASH_S2KNPPROFILES1 = "/s2keprof"
SLASH_S2KNPPROFILES2 = "/s2knpprof"
SlashCmdList["S2KNPPROFILES"] = function(msg)
    msg = tostring(msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local lower = msg:lower()

    if lower == "" or lower == "list" or lower == "help" or lower == "?" then
        S2KNP_PrintProfileList()
        return
    end

    local name = msg:match("^[Ll][Oo][Aa][Dd]%s+(.+)$")
    if name then
        SwitchProfile(name)
        S2KNP_PrintProfileList()
        return
    end

    name = msg:match("^[Ss][Aa][Vv][Ee]%s+(.+)$")
    if name then
        SaveCurrentProfileAs(name, false)
        S2KNP_PrintProfileList()
        return
    end

    name = msg:match("^[Ss][Aa][Vv][Ee][%-_ ]?[Ss][Ww][Ii][Tt][Cc][Hh]%s+(.+)$")
    if name then
        SaveCurrentProfileAs(name, true)
        S2KNP_PrintProfileList()
        return
    end

    name = msg:match("^[Cc][Oo][Pp][Yy][Ff][Rr][Oo][Mm]%s+(.+)$") or msg:match("^[Cc][Oo][Pp][Yy]%s+[Ff][Rr][Oo][Mm]%s+(.+)$")
    if name then
        State.profileCopySourceName = tostring(name or "")
        CopyProfileToCurrent(name)
        S2KNP_PrintProfileList()
        return
    end

    print("s2k:Enhancements: unknown profile command. Use /s2knpprof list")
end
