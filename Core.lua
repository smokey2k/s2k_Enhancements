-- =========================================================
-- s2k:Enhancements (s2k Enhancements)
-- WoW 7.3.5
-- v1.32.0
-- Note: top-level helper functions are intentionally non-local to stay under the Lua 5.1 chunk-local limit.
--
-- Custom Blizzard-nameplate driven skin system.
-- The Blizzard nameplate is used only as the unit/position driver.
-- The addon draws its own healthbar, castbar, name, HP-ratio text,
-- buff frame and debuff frame.
--
-- No CompactUnitFrame global hooks.
-- No Blizzard BuffFrame repositioning.
-- No Blizzard healthBar resizing.
-- No Blizzard aura icon resizing.
-- =========================================================

ADDON_NAME = ...
A = CreateFrame("Frame")

_G.s2k_Enhancements = _G.s2k_Enhancements or {}
API = _G.s2k_Enhancements
-- Backward-compatible API alias for integrations written for the old addon name.
_G.s2k_Nameplates = API
API.version = "1.32.0"


DEFAULTS = {
    -- Master switch exposed as Modules > Custom Nameplates.
    enabled = true,
    hideBlizzardVisuals = true,

    -- Runtime feature switches. Core nameplate frames are governed by the
    -- Custom Nameplates master switch; overlays and integrations remain granular.
    moduleTargetRuntimeHealthEnabled = true,
    moduleWeakAurasEnabled = true,

    -- Quest enhancements.
    questReputationEnabled = true,
    questCurrencyRewardsEnabled = true,
    questAutoAcceptEnabled = false,
    questAutoTurnInEnabled = false,
    questLevelDisplayEnabled = false,
    questObjectiveTooltipEnabled = false,
    questAutoAcceptShareEnabled = false,
    cameraDistanceMaxZoomFactor = 2.6,
    spellQueueWindow = 400,
    addonLocale = "AUTO",
    -- Chat enhancements. Disabled by default to preserve Blizzard behavior.
    chatEnabled = false,
    chatAltInviteEnabled = true,
    chatCopyEnabled = true,
    chatEditBoxPosition = "BOTTOM",
    chatEditBoxOffset = 2,
    chatEditBoxHorizontalOffset = -5,
    chatEditBoxWidth = 0,
    chatEditBoxBorderStyle = "BLIZZARD",
    chatEditBoxBackgroundColorR = 0.00,
    chatEditBoxBackgroundColorG = 0.00,
    chatEditBoxBackgroundColorB = 0.00,
    chatEditBoxBackgroundColorA = 0.75,
    chatEditBoxBorderThickness = 4,
    chatEditBoxBorderInset = 0,
    chatEditBoxBackgroundInset = 0,
    chatFontKey = "FRIZQT",
    chatFontPath = "Fonts\\FRIZQT__.TTF",
    chatFontOutlineKey = "NONE",
    chatTextAlign = "LEFT",
    chatButtonAlign = "LEFT",
    chatQuickJoinButtonEnabled = true,
    chatMenuButtonEnabled = true,
    chatButtonFrameEnabled = true,
    chatButtonFrameSmart = false,
    chatQuickJoinLDBEnabled = false,
    chatMenuLDBEnabled = false,

    -- Dominos integration. Disabled by default so existing Dominos layouts are
    -- never changed until the player explicitly enables the integration.
    dominosIntegrationEnabled = false,
    dominosLayoutMode = "LOCKED", -- LOCKED restores Dominos; EDITABLE temporarily arranges selected bars
    dominosEditableDirection = "HORIZONTAL", -- HORIZONTAL or VERTICAL
    dominosBars = {
        [1] = { anchored = false },
        [2] = { anchored = false },
        [3] = { anchored = false },
        [4] = { anchored = false },
        [5] = { anchored = false },
        [6] = { anchored = false },
        [7] = { anchored = false },
        [8] = { anchored = false },
        [9] = { anchored = false },
        [10] = { anchored = false },
    },
    -- Temporary per-profile snapshot used only while Editable mode is active.
    -- The action-bar count itself is queried from Dominos at runtime.
    dominosEditSession = { active = false, bars = {} },

    -- Main custom nameplate
    plateWidth = 110,
    plateHeight = 12,
    plateYOffset = 0, -- legacy saved-variable compatibility
    nameplateHitboxWidth = 110,
    nameplateHitboxHeight = 45,
    healthbarHitboxXOffset = 0,
    healthbarHitboxYOffset = 0,
    healthbarFrameStrata = "HIGH",
    healthTexture = "Interface\\TargetingFrame\\UI-StatusBar", -- legacy/custom fallback path
    healthTextureKey = "BLIZZARD_STATUSBAR",
    healthTexturePath = "Interface\\TargetingFrame\\UI-StatusBar",
    -- Healthbar color
    -- If healthUseReactionColor is true, the bar uses unit reaction colors.
    -- Otherwise it uses the custom RGBA color below.
    healthUseReactionColor = true,
    healthColorKey = "REACTION", -- legacy saved-variable compatibility
    healthColorR = 0.85,
    healthColorG = 0.10,
    healthColorB = 0.10,
    healthColorA = 1.00,
    healthBackgroundAlpha = 0.65,
    healthBackdropTextureKey = 'FLAT_WHITE',
    healthBackdropTexturePath = 'Interface/Buttons/WHITE8X8',
    healthBackdropColorR = 0.00,
    healthBackdropColorG = 0.00,
    healthBackdropColorB = 0.00,
    healthBackdropColorA = 0.65,

    -- Healthbar border
    healthBorder = true, -- legacy SavedVariables compatibility
    borderStyleKey = "THIN",
    borderTextureKey = 'S2K_SOLID',
    borderTexturePath = 'Interface\\Buttons\\WHITE8X8',
    borderSize = 1,
    borderInset = 0,
    borderOffset = 1,
    borderColorKey = "BLACK", -- legacy saved-variable compatibility
    borderColorR = 0.00,
    borderColorG = 0.00,
    borderColorB = 0.00,
    borderColorA = 1.00,
    targetBorderOverride = false,
    targetHealthbarOverride = false,
    targetPlateWidth = 110,
    targetPlateHeight = 12,
    targetPlateYOffset = 0,
    targetHealthbarFrameStrata = "HIGH",
    targetHealthTextureKey = 'BLIZZARD_STATUSBAR',
    targetHealthTexturePath = 'Interface/TargetingFrame/UI-StatusBar',
    targetHealthUseReactionColor = true,
    targetHealthColorR = 0.85,
    targetHealthColorG = 0.10,
    targetHealthColorB = 0.10,
    targetHealthColorA = 1.00,
    targetHealthBackdropTextureKey = 'FLAT_WHITE',
    targetHealthBackdropTexturePath = 'Interface/Buttons/WHITE8X8',
    targetHealthBackdropColorR = 0.00,
    targetHealthBackdropColorG = 0.00,
    targetHealthBackdropColorB = 0.00,
    targetHealthBackdropColorA = 0.65,
    targetBorderStyleKey = "THIN",
    targetBorderTextureKey = 'S2K_SOLID',
    targetBorderTexturePath = 'Interface\\Buttons\\WHITE8X8',
    targetBorderSize = 1,
    targetBorderInset = 0,
    targetBorderOffset = 1,
    targetBorderColorKey = "WHITE", -- legacy saved-variable compatibility
    targetBorderColorR = 1.00,
    targetBorderColorG = 1.00,
    targetBorderColorB = 1.00,
    targetBorderColorA = 1.00,

    -- Name text
    showNames = false,
    nameFontSize = 10,
    nameYOffset = 4,
    nameFontKey = "FRIZQT",
    nameFontPath = "Fonts\\FRIZQT__.TTF",
    nameFontOutlineKey = "OUTLINE",
    nameOverlayFrameLevel = 36,

    -- HP ratio text
    hpRatioText = true,
    hpRatioOnlyGreaterThanPlayer = true,
    -- HP ratio is intentionally simple: if the nameplate unit exists and has max HP, draw it.
    -- Do not gate this by UnitIsVisible/line-of-sight; private 7.3.5 servers can report that unreliably.
    hpRatioFontSize = 10,
    hpRatioYOffset = 0,
    hpRatioFrameLevel = 60,
    hpRatioFontKey = "FRIZQT",
    hpRatioFontPath = "Fonts\\FRIZQT__.TTF",
    hpRatioFontOutlineKey = "OUTLINE",
    hpRatioColorR = 1.00,
    hpRatioColorG = 1.00,
    hpRatioColorB = 1.00,
    hpRatioColorA = 1.00,

    -- Castbar
    showCastbar = true,
    castbarHeight = 6,
    castbarYOffset = -2,
    castbarTexture = "Interface\\TargetingFrame\\UI-StatusBar", -- legacy/custom fallback path
    castbarTextureKey = "BLIZZARD_STATUSBAR",
    castbarTexturePath = "Interface\\TargetingFrame\\UI-StatusBar",
    castbarColorKey = "CAST_DEFAULT", -- legacy saved-variable compatibility
    castbarColorR = 1.00,
    castbarColorG = 0.70,
    castbarColorB = 0.10,
    castbarColorA = 1.00,
    castbarBackdropTextureKey = 'FLAT_WHITE',
    castbarBackdropTexturePath = 'Interface/Buttons/WHITE8X8',
    castbarBackdropColorR = 0.00,
    castbarBackdropColorG = 0.00,
    castbarBackdropColorB = 0.00,
    castbarBackdropColorA = 0.75,
    castbarBorder = true,
    castbarBorderStyleKey = "THIN",
    castbarBorderTextureKey = 'S2K_SOLID',
    castbarBorderTexturePath = 'Interface\\Buttons\\WHITE8X8',
    castbarBorderSize = 1,
    castbarBorderInset = 0,
    castbarBorderOffset = 1,
    castbarBorderColorR = 0.00,
    castbarBorderColorG = 0.00,
    castbarBorderColorB = 0.00,
    castbarBorderColorA = 1.00,
    showCastbarSpellName = true,
    castbarSpellNameFontSize = 10,
    castbarSpellNameFontKey = "FRIZQT",
    castbarSpellNameFontPath = "Fonts\\FRIZQT__.TTF",
    castbarSpellNameFontOutlineKey = "OUTLINE",
    castbarSpellNameColorR = 1.00,
    castbarSpellNameColorG = 1.00,
    castbarSpellNameColorB = 1.00,
    castbarSpellNameColorA = 1.00,
    showCastbarIcon = false,
    castbarIconSize = 18,
    castbarIconGap = 2,

    -- Player cast overlay on target healthbar
    playerCastOverlayEnabled = true,
    playerCastOverlayColorR = 0.20,
    playerCastOverlayColorG = 0.55,
    playerCastOverlayColorB = 1.00,
    playerCastOverlayColorA = 0.55,
    playerCastOverlayFrameLevel = 20,
    playerCastOverlaySparkEnabled = true,
    playerCastOverlaySparkWidth = 2,
    playerCastOverlaySparkTextureKey = "FLAT_WHITE",
    playerCastOverlaySparkTexturePath = "Interface\\Buttons\\WHITE8X8",
    playerCastOverlaySparkColorR = 1.00,
    playerCastOverlaySparkColorG = 1.00,
    playerCastOverlaySparkColorB = 1.00,
    playerCastOverlaySparkColorA = 1.00,

    -- Unit level overlay
    levelOverlayEnabled = false,
    levelOverlayXOffset = 0,
    levelOverlayYOffset = 16,
    levelOverlayFontSize = 10,
    levelOverlayFontKey = "FRIZQT",
    levelOverlayFontPath = "Fonts\\FRIZQT__.TTF",
    levelOverlayFontOutlineKey = "OUTLINE",
    levelOverlayAlign = "CENTER",
    levelOverlayColorR = 1.00,
    levelOverlayColorG = 0.82,
    levelOverlayColorB = 0.00,
    levelOverlayColorA = 1.00,
    levelOverlayFrameLevel = 45,

    -- HP threshold marker overlay
    hpMarkerEnabled = false,
    hpMarkerOnlyTarget = false,
    hpMarkerOnlyEnemy = false,
    hpMarkerPercent = 35,
    hpMarkerWidth = 2,
    hpMarkerWidthMode = "LINE",
    hpMarkerUseBorderColor = false,
    hpMarkerColorR = 1.00,
    hpMarkerColorG = 1.00,
    hpMarkerColorB = 1.00,
    hpMarkerColorA = 1.00,
    hpMarkerFrameLevel = 30,

    -- Buff frame
    buffFrameEnabled = true,
    showBuffFrameOnTarget = true,
    buffAnchorTo = "HEALTH",     -- HEALTH, DEBUFF
    buffAnchorSide = "TOP",      -- TOP, BOTTOM, LEFT, RIGHT
    buffYOffset = 3,             -- distance from the selected anchor side; horizontal when side is LEFT/RIGHT
    buffHorizontalOrigin = "CENTER", -- legacy: LEFT, CENTER, RIGHT; used by non-centered horizontal layouts
    buffGrowth = "CENTER_HORIZONTAL", -- RIGHT, LEFT, UP, DOWN, CENTER_HORIZONTAL, CENTER_VERTICAL
    buffIconWidth = 18,
    buffIconHeight = 18,
    buffIconSpacing = 2,
    buffMaxIcons = 8,
    buffIconsPerLine = 8,
    buffWrapDirection = "UP",    -- UP/DOWN for horizontal growth, LEFT/RIGHT for vertical growth
    buffOnlyPlayerCast = false,
    buffOnlyDispellable = false,
    buffOnlyStealable = false,

    -- Debuff frame
    debuffFrameEnabled = true,
    showDebuffFrameOnTarget = true,
    debuffAnchorTo = "HEALTH",    -- HEALTH, BUFF
    debuffAnchorSide = "TOP",     -- TOP, BOTTOM, LEFT, RIGHT
    debuffYOffset = 2,            -- distance from the selected anchor side; horizontal when side is LEFT/RIGHT
    debuffHorizontalOrigin = "CENTER", -- legacy: LEFT, CENTER, RIGHT; used by non-centered horizontal layouts
    debuffGrowth = "CENTER_HORIZONTAL", -- RIGHT, LEFT, UP, DOWN, CENTER_HORIZONTAL, CENTER_VERTICAL
    debuffIconWidth = 18,
    debuffIconHeight = 18,
    debuffIconSpacing = 2,
    debuffMaxIcons = 8,
    debuffIconsPerLine = 8,
    debuffWrapDirection = "UP",   -- UP/DOWN for horizontal growth, LEFT/RIGHT for vertical growth
    debuffOnlyPlayerCast = false,

    -- Blizzard CVar: 0 above head/default, 2 at unit base/feet.
    nameplateAtBase = false,

    -- Blizzard nameplate CVars and matching custom nameplate scaling.
    -- The first time a profile is created, these values are initialized from
    -- the player's current CVars when available.
    nameplateGlobalScale = 1.00,
    nameplateSelectedScale = 1.00,
    nameplateMaxDistance = 60,
    nameplateMotion = 0,
    nameplateMotionSpeed = 0.025,
    nameplateOtherBottomInset = 0.08,
    nameplateOtherTopInset = 0.08,
    nameplateOverlapH = 0.80,
    nameplateOverlapV = 1.10,
    nameplateShowSelf = true,
    nameplateResourceOnTarget = false,
    nameplateShowAll = false,
    nameplateShowEnemies = true,
    nameplateShowEnemyMinions = false,
    nameplateShowEnemyMinus = true,
    nameplateShowFriends = false,
    nameplateShowFriendlyMinions = false,

    -- WeakAuras integration.
    -- The addon can directly place a named WeakAura region on the current target
    -- custom healthbar. This avoids running SetPoint/SetParent from WeakAuras
    -- custom code, which can trigger WeakAuras forbidden-function warnings.
    weakAurasEnabled = false,
    weakAuraAutoCreate = true,
    weakAuraAnchorGroupId = "s2k_NP",
    weakAuraTargetEnabled = true,
    weakAuraTargetId = "s2k_NP_Target",
    weakAuraFallbackEnabled = true,
    weakAuraFallbackId = "s2k_NP_Fallback",

    -- Optional PlateX progress/bar group width management.
    -- Progress bar groups are now dynamic. WeakAuras itself decides where each
    -- group is attached (for example to PX_Target); this addon only keeps the
    -- configured group widths in sync with the target/fallback anchor region.
    weakAuraManageBarGroups = false,
    weakAuraProgressBarGroups = { "s2k_NP_BT", "s2k_NP_BB" },

    -- Legacy saved-variable compatibility. These are migrated into
    -- weakAuraProgressBarGroups and no longer shown as fixed top/bottom fields.
    weakAuraTopGroupId = "s2k_NP_BT",
    weakAuraBottomGroupId = "s2k_NP_BB",



    maxNameplates = 40,

    -- Performance tuning: target WA/cast follow rate and non-target cast update rate.
    targetRuntimeThrottle = 0.033,
    castRuntimeThrottle = 0.05,
    auraUpdateThrottle = 0.08,

    -- Debug / internal profiler. When disabled, profiler wrappers are removed
    -- and the runtime path does not collect profiler data.
    debugProfilerEnabled = false,
    debugProfilerMaxRows = 30,
    debugBenchmarkSeconds = 60,
    debugWeakAuraAnchorStatsEnabled = false,
}

DBRoot = nil
DB = nil
CFG = {}

State = {
    plates = {},
    activeCastUnits = {},
    runtimeFlags = {},
    configFrame = nil,
    nameplatePreviewFrame = nil,
    nameplatePreviewRequested = false,
    brokerInitialized = false,
    fontOptions = {},
    fontOptionsByKey = {},
    statusbarTextureOptions = {},
    statusbarTextureOptionsByKey = {},
    smoothElapsed = 0,
    weakAuraDirty = true,
    weakAuraBarGroupsDirty = true,
    weakAuraGroupChildrenCache = {},
    weakAuraSlowElapsed = 0,
    weakAuraLastMode = nil,
    weakAuraLastTargetRegion = nil,
    weakAuraScaffoldDirty = true,
    weakAuraAnchorStats = {},
    weakAuraAnchorStatsPanel = nil,
    weakAuraAnchorStatsElapsed = 0,
    auraDirtyUnits = {},
    auraDirtyElapsed = 0,
    castRuntimeElapsed = 0,
    blizzardVisualHooks = setmetatable({}, { __mode = "k" }),
    blizzardVisualCache = setmetatable({}, { __mode = "k" }),
    pendingCVarApply = false,
    applyingNameplateCVars = false,
    pendingNameplateCVarRuntimeRefresh = false,
    pendingOptionsApply = false,
    pendingMediaRefreshFonts = false,
    pendingMediaRefreshTextures = false,
    pendingDominosApply = false,
    mediaRefreshGeneration = 0,
    mediaRefreshFonts = false,
    mediaRefreshTextures = false,
    dominosRuntimeEditSession = nil,
    dominosStatusText = nil,
    dominosStatusError = false,
    cachedTargetContext = nil,
    chatInitialized = false,
    chatCopyWindow = nil,
    chatHookedFrames = {},
    chatSmartWatchers = {},

    profilerActive = false,
    profilerWrapped = false,
    profilerOriginals = {},
    profilerData = {},
    profilerStartedAt = nil,
}

BUILTIN_FONT_OPTIONS = {
    { key = "FRIZQT",   label = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { key = "ARIALN",   label = "Arial Narrow",   path = "Fonts\\ARIALN.TTF" },
    { key = "MORPHEUS", label = "Morpheus",       path = "Fonts\\MORPHEUS.TTF" },
    { key = "SKURRI",   label = "Skurri",         path = "Fonts\\SKURRI.TTF" },
}

FONT_OUTLINE_OPTIONS = {
    { key = "NONE",                 label = "None",                     flags = "" },
    { key = "OUTLINE",              label = "Outline",                  flags = "OUTLINE" },
    { key = "THICKOUTLINE",         label = "Thick outline",            flags = "THICKOUTLINE" },
    { key = "MONOCHROME",           label = "Monochrome",               flags = "MONOCHROME" },
    { key = "MONOCHROME_OUTLINE",   label = "Monochrome outline",       flags = "MONOCHROME,OUTLINE" },
    { key = "MONOCHROME_THICK",     label = "Monochrome thick outline", flags = "MONOCHROME,THICKOUTLINE" },
}

FRAME_STRATA_OPTIONS = {
    { key = "BACKGROUND",        label = "Background" },
    { key = "LOW",               label = "Low" },
    { key = "MEDIUM",            label = "Medium" },
    { key = "HIGH",              label = "High" },
    { key = "DIALOG",            label = "Dialog" },
    { key = "FULLSCREEN",         label = "Fullscreen" },
    { key = "FULLSCREEN_DIALOG",  label = "Fullscreen dialog" },
    { key = "TOOLTIP",            label = "Tooltip" },
}

LEVEL_OVERLAY_ALIGN_OPTIONS = {
    { key = "CENTER",         label = "Center" },
    { key = "LEFT_TO_RIGHT",  label = "Left edge, grow right" },
    { key = "RIGHT_TO_LEFT",  label = "Right edge, grow left" },
}

HP_MARKER_WIDTH_MODE_OPTIONS = {
    { key = "LINE",         label = "Fixed vertical line" },
    { key = "LEFT_TO_ZERO", label = "Extend left to 0%" },
    { key = "RIGHT_TO_END", label = "Extend right to 100%" },
}

BUILTIN_STATUSBAR_TEXTURE_OPTIONS = {
    { key = "BLIZZARD_STATUSBAR", label = "Blizzard StatusBar", path = "Interface\\TargetingFrame\\UI-StatusBar" },
    { key = "FLAT_WHITE",         label = "Flat / White8x8",    path = "Interface\\Buttons\\WHITE8X8" },
}

-- S2K_SHARED_OPTION_VALUES
SIDE_OPTIONS = {
    { key = "TOP", label = "Top" },
    { key = "BOTTOM", label = "Bottom" },
    { key = "LEFT", label = "Left" },
    { key = "RIGHT", label = "Right" },
}

NAMEPLATE_DESIGN_GROUPS = { "target", "focus", "friendly", "enemy" }
NAMEPLATE_DIMENSION_GROUPS = { "friendly", "enemy" }

local NAMEPLATE_GENERAL_DESIGN_DEFAULTS = {
    HealthTextureKey = "BLIZZARD_STATUSBAR",
    HealthTexturePath = "Interface\\TargetingFrame\\UI-StatusBar",
    HealthUseReactionColor = true,
    HealthColorR = 0.85, HealthColorG = 0.10, HealthColorB = 0.10, HealthColorA = 1.00,
    HealthBackdropTextureKey = "FLAT_WHITE",
    HealthBackdropTexturePath = "Interface\\Buttons\\WHITE8X8",
    HealthBackdropColorR = 0.00, HealthBackdropColorG = 0.00, HealthBackdropColorB = 0.00, HealthBackdropColorA = 0.65,
    BorderTextureKey = "S2K_SOLID",
    BorderTexturePath = "Interface\\Buttons\\WHITE8X8",
    BorderSize = 1, BorderInset = 0, BorderOffset = 1,
    BorderColorR = 0.00, BorderColorG = 0.00, BorderColorB = 0.00, BorderColorA = 1.00,
    ShowNames = false, ShowHPRatio = true, ShowLevelOverlay = false, ShowHPMarker = false,
    HPMarkerColorR = 1.00, HPMarkerColorG = 1.00, HPMarkerColorB = 1.00, HPMarkerColorA = 1.00,
}

for _, group in ipairs(NAMEPLATE_DESIGN_GROUPS) do
    for suffix, value in pairs(NAMEPLATE_GENERAL_DESIGN_DEFAULTS) do
        DEFAULTS[group .. suffix] = value
    end
end
DEFAULTS.targetPlayerCastOverlayEnabled = true

for _, group in ipairs(NAMEPLATE_DIMENSION_GROUPS) do
    DEFAULTS[group .. "PlateWidth"] = 110
    DEFAULTS[group .. "PlateHeight"] = 12
    DEFAULTS[group .. "NameplateHitboxWidth"] = 110
    DEFAULTS[group .. "NameplateHitboxHeight"] = 45
    DEFAULTS[group .. "HealthbarHitboxXOffset"] = 0
    DEFAULTS[group .. "HealthbarHitboxYOffset"] = 0
    DEFAULTS[group .. "HealthbarFrameStrata"] = "HIGH"
end

ORIGIN_OPTIONS = {
    { key = "LEFT", label = "Left edge" },
    { key = "CENTER", label = "Center" },
    { key = "RIGHT", label = "Right edge" },
}

GROWTH_OPTIONS = {
    { key = "RIGHT", label = "Right" },
    { key = "LEFT", label = "Left" },
    { key = "UP", label = "Up" },
    { key = "DOWN", label = "Down" },
    { key = "CENTER_HORIZONTAL", label = "Center horizontal" },
    { key = "CENTER_VERTICAL", label = "Center vertical" },
}

WRAP_DIRECTION_OPTIONS = {
    { key = "UP", label = "New row upward" },
    { key = "DOWN", label = "New row downward" },
    { key = "LEFT", label = "New column left" },
    { key = "RIGHT", label = "New column right" },
}

NAMEPLATE_MOTION_OPTIONS = {
    { key = 0, label = "Overlapping / default" },
    { key = 1, label = "Stacking" },
    { key = 2, label = "Spread" },
}

BUFF_ANCHOR_OPTIONS = {
    { key = "HEALTH", label = "Healthbar" },
    { key = "DEBUFF", label = "Debuff frame" },
}

DEBUFF_ANCHOR_OPTIONS = {
    { key = "HEALTH", label = "Healthbar" },
    { key = "BUFF", label = "Buff frame" },
}
