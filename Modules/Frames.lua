-- =========================================================
-- Frame creation
-- =========================================================

function CreateBorder(parent)
    -- Real 1px border made from four line textures.
    -- Earlier versions used one full black texture on a high frame level;
    -- that could cover the custom healthbar/HP-ratio text and looked like a
    -- large black bar. This frame only draws the four edges.
    local border = CreateFrame("Frame", nil, parent)
    border.s2kParent = parent
    border:SetPoint("TOPLEFT", parent, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 1, -1)

    local function Line()
        local t = border:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(0, 0, 0, 1)
        return t
    end

    border.top = Line()
    border.top:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 0)
    border.top:SetHeight(1)

    border.bottom = Line()
    border.bottom:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
    border.bottom:SetHeight(1)

    border.left = Line()
    border.left:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0)
    border.left:SetWidth(1)

    border.right = Line()
    border.right:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
    border.right:SetWidth(1)

    return border
end

function ApplyBorderVisual(border, textureKey, texturePath, size, inset, offset, r, g, b, a)
    if not border then
        return
    end

    textureKey = tostring(textureKey or 'S2K_SOLID')
    if textureKey == 'NONE' then
        border:Hide()
        return
    end
    size = math.max(1, math.min(64, tonumber(size) or 1))
    inset = math.max(-32, math.min(32, tonumber(inset) or 0))
    offset = math.max(0, math.min(32, tonumber(offset) or 0))
    local parent = border.s2kParent or border:GetParent()
    if parent then
        if inset > 0 and parent.GetWidth and parent.GetHeight then
            local halfSize = math.min(parent:GetWidth() or 0, parent:GetHeight() or 0) / 2
            inset = math.min(inset, math.max(0, halfSize - 1))
        end
        local extent = offset - inset
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", parent, "TOPLEFT", -extent, extent)
        border:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", extent, -extent)
    end

    r = r or 0
    g = g or 0
    b = b or 0
    a = a == nil and 1 or a
    local pieces = { border.top, border.bottom, border.left, border.right }
    if textureKey == 'S2K_SOLID' then
        border:SetBackdrop(nil)
        for _, piece in ipairs(pieces) do
            piece:SetColorTexture(r, g, b, a)
            piece:Show()
        end
        border.top:SetHeight(size); border.bottom:SetHeight(size)
        border.left:SetWidth(size); border.right:SetWidth(size)
    else
        for _, piece in ipairs(pieces) do piece:Hide() end
        -- Legion can retain stale edge geometry when a backdrop is replaced
        -- while its parent nameplate is hidden or being recycled.
        border:SetBackdrop(nil)
        border:SetBackdrop({edgeFile=texturePath, edgeSize=size})
        border:SetBackdropBorderColor(r, g, b, a)
    end

    border:Show()
end

function SyncCustomFrameLevels(ctx)
    if not ctx or not ctx.root or not ctx.root.GetFrameLevel then
        return
    end

    local base = ctx.root:GetFrameLevel() or 0

    -- Keep the StatusBar below all custom text and aura layers.
    if ctx.health and ctx.health.SetFrameLevel then
        ctx.health:SetFrameLevel(base + 2)
    end

    if ctx.cast and ctx.cast.SetFrameLevel then
        ctx.cast:SetFrameLevel(base + 3)
    end

    if ctx.castBorder and ctx.castBorder.SetFrameLevel then
        ctx.castBorder:SetFrameLevel(base + 5)
    end

    -- Player cast overlay is drawn over the custom healthbar, but below
    -- HP ratio/name/aura layers. The healthbar border stays above the overlay.
    local overlayFrameLevel = tonumber(CFG.playerCastOverlayFrameLevel) or 20
    if ctx.playerCastOverlay and ctx.playerCastOverlay.SetFrameLevel then
        ctx.playerCastOverlay:SetFrameLevel(base + overlayFrameLevel)
    end
    if ctx.playerCastOverlaySpark and ctx.playerCastOverlaySpark.SetFrameLevel then
        ctx.playerCastOverlaySpark:SetFrameLevel(base + overlayFrameLevel + 1)
    end

    if ctx.hpMarker and ctx.hpMarker.SetFrameLevel then
        ctx.hpMarker:SetFrameLevel(base + (tonumber(CFG.hpMarkerFrameLevel) or 30))
    end

    if ctx.levelLayer and ctx.levelLayer.SetFrameLevel then
        ctx.levelLayer:SetFrameLevel(base + (tonumber(CFG.levelOverlayFrameLevel) or 45))
    end

    if ctx.castIconFrame and ctx.castIconFrame.SetFrameLevel then
        ctx.castIconFrame:SetFrameLevel(base + 4)
    end

    if ctx.castText and ctx.castText.SetDrawLayer then
        ctx.castText:SetDrawLayer("OVERLAY", 7)
    end

    -- Keep the border immediately above its own StatusBar. A large offset here
    -- lets one UIParent-parented nameplate border interleave with the healthbar
    -- of another nameplate, which looks like a translucent border bleeding
    -- through stacked plates.
    if ctx.border and ctx.border.SetFrameLevel then
        ctx.border:SetFrameLevel(base + 3)
    end

    -- Text layers must be above both the StatusBar and the border.
    if ctx.ratioLayer and ctx.ratioLayer.SetFrameLevel then
        ctx.ratioLayer:SetFrameLevel(base + (tonumber(CFG.hpRatioFrameLevel) or 60))
    end

    if ctx.nameLayer and ctx.nameLayer.SetFrameLevel then
        ctx.nameLayer:SetFrameLevel(base + (tonumber(CFG.nameOverlayFrameLevel) or 36))
    end

    if ctx.debuffFrame and ctx.debuffFrame.SetFrameLevel then
        ctx.debuffFrame:SetFrameLevel(base + 40)
    end

    if ctx.buffFrame and ctx.buffFrame.SetFrameLevel then
        ctx.buffFrame:SetFrameLevel(base + 41)
    end
end

local VALID_NAMEPLATE_FRAME_STRATA = {
    BACKGROUND = true,
    LOW = true,
    MEDIUM = true,
    HIGH = true,
    DIALOG = true,
    FULLSCREEN = true,
    FULLSCREEN_DIALOG = true,
    TOOLTIP = true,
}

function GetNameplateFrameStrata(ctx)
    local key = IsTargetUnit(ctx and ctx.unit) and "targetHealthbarFrameStrata" or "healthbarFrameStrata"
    local strata = tostring(CFG[key] or "HIGH"):upper()
    return VALID_NAMEPLATE_FRAME_STRATA[strata] and strata or "HIGH"
end

function SyncCustomFrameStrata(ctx)
    if not ctx or not ctx.root or not ctx.root.SetFrameStrata then return end

    local strata = GetNameplateFrameStrata(ctx)
    if ctx.s2kLastFrameStrata ~= strata then
        ctx.root:SetFrameStrata(strata)
        if ctx.waHealthAnchor and ctx.waHealthAnchor.SetFrameStrata then
            ctx.waHealthAnchor:SetFrameStrata(strata)
        end
        if ctx.waCastAnchor and ctx.waCastAnchor.SetFrameStrata then
            ctx.waCastAnchor:SetFrameStrata(strata)
        end
        ctx.s2kLastFrameStrata = strata
    end
end

local CUSTOM_NAMEPLATE_LEVEL_BASE = 100
local CUSTOM_NAMEPLATE_LEVEL_STRIDE = 128
local customNameplateCreationOrder = 0

local function GetBlizzardNameplateOrder(ctx)
    local plate = ctx and ctx.plate
    local unitFrame = plate and GetUnitFrameFromPlate(plate)
    local level = 0
    if plate and plate.GetFrameLevel then
        level = math.max(level, tonumber(plate:GetFrameLevel()) or 0)
    end
    if unitFrame and unitFrame.GetFrameLevel then
        level = math.max(level, tonumber(unitFrame:GetFrameLevel()) or 0)
    end
    return level
end

function SyncCustomNameplateFrameOrder()
    local groups = {}
    for _, ctx in pairs((State and State.plates) or {}) do
        if ctx and ctx.root and ctx.root:IsShown() and ctx.plate and FrameIsVisible(ctx.plate) then
            local strata = GetNameplateFrameStrata(ctx)
            groups[strata] = groups[strata] or {}
            groups[strata][#groups[strata] + 1] = ctx
        end
    end

    for _, contexts in pairs(groups) do
        table.sort(contexts, function(a, b)
            local aLevel = GetBlizzardNameplateOrder(a)
            local bLevel = GetBlizzardNameplateOrder(b)
            if aLevel ~= bLevel then return aLevel < bLevel end

            local aTarget = IsTargetUnit(a.unit) and 1 or 0
            local bTarget = IsTargetUnit(b.unit) and 1 or 0
            if aTarget ~= bTarget then return aTarget < bTarget end

            return (a.s2kCreationOrder or 0) < (b.s2kCreationOrder or 0)
        end)

        for index, ctx in ipairs(contexts) do
            local base = CUSTOM_NAMEPLATE_LEVEL_BASE + ((index - 1) * CUSTOM_NAMEPLATE_LEVEL_STRIDE)
            if ctx.root.SetFrameLevel then ctx.root:SetFrameLevel(base) end
            if ctx.waHealthAnchor and ctx.waHealthAnchor.SetFrameLevel then
                ctx.waHealthAnchor:SetFrameLevel(base + 110)
            end
            if ctx.waCastAnchor and ctx.waCastAnchor.SetFrameLevel then
                ctx.waCastAnchor:SetFrameLevel(base + 111)
            end
            SyncCustomFrameLevels(ctx)
        end
    end
end
function CreateAuraButton(parent)
    local btn = CreateFrame("Frame", nil, parent)

    -- Important:
    -- Do NOT use one full black texture as the aura border. On Legion/7.3.5
    -- that child frame can render above the icon texture and it looks like a
    -- solid black rectangle instead of a spell icon. Draw the border with four
    -- 1px line textures, just like the healthbar border.
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(btn)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    btn.border = CreateBorder(btn)
    if btn.border and btn.border.SetFrameLevel and btn.GetFrameLevel then
        btn.border:SetFrameLevel((btn:GetFrameLevel() or 0) + 2)
    end

    btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    btn.count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
    btn.count:SetTextColor(1, 1, 1, 1)
    btn.count:SetShadowOffset(1, -1)
    if btn.count.SetDrawLayer then
        btn.count:SetDrawLayer("OVERLAY", 7)
    end

    btn:Hide()
    return btn
end

function EnsureAuraButtons(frame, maxIcons)
    frame.buttons = frame.buttons or {}
    for i = #frame.buttons + 1, maxIcons do
        frame.buttons[i] = CreateAuraButton(frame)
    end
end

function CleanupHiddenNameplateContext(plate)
    local ctx = plate and plate.s2kNameplateContext
    if not ctx then return end

    local unit = ctx.unit
    if unit then
        if State.plates and State.plates[unit] == ctx then
            State.plates[unit] = nil
        end
        if State.activeCastUnits and State.activeCastUnits[unit] == ctx then
            State.activeCastUnits[unit] = nil
        end
        if State.auraDirtyUnits then
            State.auraDirtyUnits[unit] = nil
        end
    end

    ResetNameplateContextVisuals(ctx, true)
    ctx.unit = nil

    if ClearTargetContextCache then ClearTargetContextCache() end
    if MarkWeakAurasDirty then MarkWeakAurasDirty() end
end

function CreateNameplateContext(unit, plate)
    local ctx = {
        unit = unit,
        plate = plate,
    }
    customNameplateCreationOrder = customNameplateCreationOrder + 1
    ctx.s2kCreationOrder = customNameplateCreationOrder

    local plateName = plate and plate.GetName and plate:GetName()
    local rootName = plateName and (plateName .. "S2KRoot") or nil
    local healthName = plateName and (plateName .. "S2KHealthBar") or nil
    local castName = plateName and (plateName .. "S2KCastBar") or nil

    -- Keep the visual root under UIParent so its configured frame strata is not
    -- clamped by the Blizzard nameplate parent. PositionRoot still anchors it
    -- to the recycled Blizzard healthbar/nameplate.
    local root = CreateFrame("Frame", rootName, UIParent)
    root:SetFrameStrata(GetNameplateFrameStrata(ctx))
    root:SetFrameLevel(CUSTOM_NAMEPLATE_LEVEL_BASE)
    root:Hide()
    ctx.root = root
    root.s2kNameplateContext = ctx

    local border = CreateBorder(root)
    ctx.border = border

    local bg = root:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(root)
    ApplyStatusBarBackdropTexture(bg, GetHealthBackdropTexturePath(ctx), GetHealthBackdropColor(ctx))
    ctx.background = bg

    local health = CreateFrame("StatusBar", healthName, root)
    health:SetAllPoints(root)
    ApplyStatusBarTexture(health, GetHealthTexturePath(ctx))
    health:SetMinMaxValues(0, 1)
    health:SetValue(1)
    ctx.health = health
    health.s2kNameplateContext = ctx

    local playerCastOverlay = CreateFrame("StatusBar", nil, root)
    playerCastOverlay:SetAllPoints(root)
    ApplyStatusBarTexture(playerCastOverlay, GetHealthTexturePath())
    playerCastOverlay:SetMinMaxValues(0, 1)
    playerCastOverlay:SetValue(0)
    playerCastOverlay:Hide()
    ctx.playerCastOverlay = playerCastOverlay

    local playerCastOverlaySpark = CreateFrame("Frame", nil, root)
    playerCastOverlaySpark:SetSize(tonumber(CFG.playerCastOverlaySparkWidth) or 2, CFG.plateHeight or 12)
    playerCastOverlaySpark.texture = playerCastOverlaySpark:CreateTexture(nil, "OVERLAY")
    playerCastOverlaySpark.texture:SetAllPoints(playerCastOverlaySpark)
    ApplyTexturePath(playerCastOverlaySpark.texture, GetPlayerCastOverlaySparkTexturePath())
    playerCastOverlaySpark.texture:SetVertexColor(GetPlayerCastOverlaySparkColor())
    playerCastOverlaySpark:Hide()
    ctx.playerCastOverlaySpark = playerCastOverlaySpark

    local hpMarker = CreateFrame("Frame", nil, root)
    hpMarker.texture = hpMarker:CreateTexture(nil, "ARTWORK")
    hpMarker.texture:SetAllPoints(hpMarker)
    hpMarker:Hide()
    ctx.hpMarker = hpMarker

    local levelLayer = CreateFrame("Frame", nil, root)
    levelLayer:SetAllPoints(root)
    ctx.levelLayer = levelLayer

    local levelText = levelLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if levelText.SetDrawLayer then levelText:SetDrawLayer("OVERLAY", 7) end
    levelText:SetPoint("CENTER", levelLayer, "CENTER", CFG.levelOverlayXOffset or 0, CFG.levelOverlayYOffset or 16)
    levelText:SetJustifyH("CENTER")
    levelText:SetJustifyV("MIDDLE")
    levelText:SetTextColor(GetLevelOverlayColor())
    levelText:SetShadowColor(0, 0, 0, 1)
    levelText:SetShadowOffset(1, -1)
    levelText:Hide()
    ctx.levelText = levelText

    local nameLayer = CreateFrame("Frame", nil, root)
    nameLayer:SetAllPoints(root)
    ctx.nameLayer = nameLayer

    local name = nameLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if name.SetDrawLayer then name:SetDrawLayer("OVERLAY", 7) end
    name:SetPoint("BOTTOM", root, "TOP", 0, CFG.nameYOffset or 4)
    name:SetJustifyH("CENTER")
    ctx.name = name

    local ratioLayer = CreateFrame("Frame", nil, root)
    ratioLayer:SetAllPoints(root)
    ctx.ratioLayer = ratioLayer

    local ratio = ratioLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if ratio.SetDrawLayer then ratio:SetDrawLayer("OVERLAY", 7) end
    ratio:SetPoint("CENTER", ratioLayer, "CENTER", 0, CFG.hpRatioYOffset or 0)
    ratio:SetJustifyH("CENTER")
    ratio:SetJustifyV("MIDDLE")
    ratio:SetTextColor(1, 1, 1, 1)
    ratio:SetShadowColor(0, 0, 0, 1)
    ratio:SetShadowOffset(1, -1)
    ctx.ratio = ratio

    local cast = CreateFrame("StatusBar", castName, root)
    ApplyStatusBarTexture(cast, GetCastbarTexturePath())
    cast:SetMinMaxValues(0, 1)
    cast:SetValue(0)
    cast:SetStatusBarColor(1, 0.7, 0.1, 1)
    cast.bg = cast:CreateTexture(nil, "BACKGROUND")
    cast.bg:SetAllPoints(cast)
    ApplyStatusBarBackdropTexture(cast.bg, GetCastbarBackdropTexturePath(), GetCastbarBackdropColor())
    cast:Hide()
    ctx.cast = cast
    cast.s2kNameplateContext = ctx

    local castBorder = CreateBorder(cast)
    castBorder:Hide()
    ctx.castBorder = castBorder

    -- UIParent-based absolute anchor frames for WeakAuras / external addons.
    -- WeakAuras 2.5.x can warn/block when a WA region is anchored directly to
    -- a nameplate-child frame. These anchors are normal UIParent children and
    -- are positioned by this addon to match the custom health/cast bars.
    local waHealthAnchorName = plateName and (plateName .. "S2KWAHealthAnchor") or nil
    local waCastAnchorName = plateName and (plateName .. "S2KWACastAnchor") or nil

    local waHealthAnchor = CreateFrame("Frame", waHealthAnchorName, UIParent)
    waHealthAnchor:SetFrameStrata(GetNameplateFrameStrata(ctx))
    waHealthAnchor:SetFrameLevel(900)
    waHealthAnchor:Hide()
    waHealthAnchor.s2kNameplateContext = ctx
    ctx.waHealthAnchor = waHealthAnchor

    local waCastAnchor = CreateFrame("Frame", waCastAnchorName, UIParent)
    waCastAnchor:SetFrameStrata(GetNameplateFrameStrata(ctx))
    waCastAnchor:SetFrameLevel(901)
    waCastAnchor:Hide()
    waCastAnchor.s2kNameplateContext = ctx
    ctx.waCastAnchor = waCastAnchor

    local castText = cast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    castText:SetPoint("CENTER", cast, "CENTER", 0, 0)
    castText:SetJustifyH("CENTER")
    castText:SetJustifyV("MIDDLE")
    ApplyFontStringFont(castText, CFG.castbarSpellNameFontKey, CFG.castbarSpellNameFontSize, CFG.castbarSpellNameFontOutlineKey, CFG.castbarSpellNameFontPath)
    castText:SetTextColor(GetCastbarSpellNameColor())
    castText:SetShadowColor(0, 0, 0, 1)
    castText:SetShadowOffset(1, -1)
    castText:Hide()
    ctx.castText = castText

    local castIconFrame = CreateFrame("Frame", nil, root)
    castIconFrame.icon = castIconFrame:CreateTexture(nil, "ARTWORK")
    castIconFrame.icon:SetAllPoints(castIconFrame)
    castIconFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    castIconFrame.border = CreateBorder(castIconFrame)
    castIconFrame:Hide()
    ctx.castIconFrame = castIconFrame

    local debuffFrame = CreateFrame("Frame", nil, root)
    debuffFrame.buttons = {}
    ctx.debuffFrame = debuffFrame

    local buffFrame = CreateFrame("Frame", nil, root)
    buffFrame.buttons = {}
    ctx.buffFrame = buffFrame

    SyncCustomFrameLevels(ctx)
    SyncCustomFrameStrata(ctx)

    plate.s2kNameplateContext = ctx
    plate.s2kCustomRoot = root
    plate.s2kCustomHealthBar = health
    plate.s2kCustomCastBar = cast
    State.plates[unit] = ctx

    -- The custom visual root is parented to UIParent so it can use an
    -- independent frame strata. It therefore does not inherit the Blizzard
    -- nameplate's hidden state. Clean it up directly when the recycled
    -- Blizzard plate hides, even if NAME_PLATE_UNIT_REMOVED is missed.
    if plate.HookScript and not plate.s2kHideCleanupHooked then
        plate.s2kHideCleanupHooked = true
        plate:HookScript("OnHide", function(self)
            CleanupHiddenNameplateContext(self)
        end)
    end
    return ctx
end

function ResetNameplateContextVisuals(ctx, resetScale)
    if not ctx then return end

    for _, text in ipairs({ ctx.ratio, ctx.name, ctx.levelText, ctx.castText }) do
        if text then
            if text.SetText then text:SetText("") end
            if text.Hide then text:Hide() end
        end
    end

    for _, auraFrame in ipairs({ ctx.buffFrame, ctx.debuffFrame }) do
        for _, button in ipairs((auraFrame and auraFrame.buttons) or {}) do
            button:Hide()
        end
        if auraFrame then auraFrame:Hide() end
    end

    if HideCastbar then HideCastbar(ctx) end
    if HidePlayerCastOverlay then HidePlayerCastOverlay(ctx) end
    if ctx.hpMarker then ctx.hpMarker:Hide() end
    if HideWAAnchors then HideWAAnchors(ctx) end

    ctx.s2kLastHealthMax = nil
    ctx.s2kLastHealthValue = nil
    ctx.s2kLastHealthR, ctx.s2kLastHealthG, ctx.s2kLastHealthB, ctx.s2kLastHealthA = nil, nil, nil, nil
    ctx.s2kLastCastTotal, ctx.s2kLastCastName, ctx.s2kLastCastIcon = nil, nil, nil
    ctx.s2kLastSafeLocalScale = nil

    if resetScale and ctx.root then
        if ctx.root.SetScale then ctx.root:SetScale(1) end
        ctx.root:Hide()
    end
end

function GetContext(unit)
    local plate = GetPlate(unit)
    if not plate then return nil end

    local ctx = plate.s2kNameplateContext
    if ctx then
        if ctx.unit and ctx.unit ~= unit then
            if State.activeCastUnits then State.activeCastUnits[ctx.unit] = nil end
            State.plates[ctx.unit] = nil
            ResetNameplateContextVisuals(ctx, true)
        end

        ctx.unit = unit
        ctx.plate = plate
        plate.s2kNameplateContext = ctx
        plate.s2kCustomRoot = ctx.root
        plate.s2kCustomHealthBar = ctx.health
        plate.s2kCustomCastBar = ctx.cast
        State.plates[unit] = ctx
        return ctx
    end

    return CreateNameplateContext(unit, plate)
end

function SameUnitOrGUID(unitA, unitB)
    if not unitA or not unitB then
        return false
    end

    if UnitIsUnit then
        local ok, same = pcall(UnitIsUnit, unitA, unitB)
        if ok and same then
            return true
        end
    end

    if UnitGUID then
        local guidA = UnitGUID(unitA)
        local guidB = UnitGUID(unitB)
        return guidA and guidB and guidA == guidB
    end

    return false
end

function GetExistingContextForUnit(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end

    local plate = GetPlate(unit)
    local ctx = plate and plate.s2kNameplateContext

    if ctx then
        if ctx.unit == unit or SameUnitOrGUID(ctx.unit, unit) then
            return ctx
        end
    end

    -- C_NamePlate.GetNamePlateForUnit("target") can return the same Blizzard
    -- plate that was originally created through a nameplateN token. In that
    -- case ctx.unit is usually "nameplateN", not "target". Scan visible
    -- nameplate tokens by GUID and return/create the matching custom context.
    for i = 1, CFG.maxNameplates or 40 do
        local token = "nameplate" .. i
        if UnitExists(token) and SameUnitOrGUID(token, unit) then
            return GetContext(token)
        end
    end

    return nil
end


function ClearTargetContextCache()
    State.cachedTargetContext = nil
end

function GetTargetContextCached()
    if not UnitExists("target") then
        ClearTargetContextCache()
        return nil
    end

    local ctx = State.cachedTargetContext

    -- Fast path for the per-frame WeakAura follow code.
    -- PLAYER_TARGET_CHANGED / NAME_PLATE_UNIT_ADDED / NAME_PLATE_UNIT_REMOVED clear
    -- this cache, so once we have the target context there is no need to run
    -- UnitIsUnit/GUID comparison on every rendered frame.
    if ctx and ctx.unit and UnitExists(ctx.unit) and ctx.root and ctx.root.IsShown and ctx.root:IsShown() then
        return ctx
    end

    ctx = GetExistingContextForUnit("target")
    State.cachedTargetContext = ctx
    return ctx
end

-- S2K_NAMEPLATE_PREVIEW
local PREVIEW_ICONS = {
    "Interface\\Icons\\Spell_Holy_PowerWordShield", "Interface\\Icons\\Spell_Nature_LightningShield",
    "Interface\\Icons\\Spell_Shadow_ShadowWordPain", "Interface\\Icons\\Spell_Fire_Fireball02",
}

local function PreviewTexture(isTarget, backdrop)
    if isTarget and CFG.targetHealthbarOverride then
        local key = backdrop and CFG.targetHealthBackdropTextureKey or CFG.targetHealthTextureKey
        local path = backdrop and CFG.targetHealthBackdropTexturePath or CFG.targetHealthTexturePath
        local option = GetStatusBarTextureOption(key, path)
        return (option and option.path) or path or (backdrop and GetHealthBackdropTexturePath() or GetHealthTexturePath())
    end
    return backdrop and GetHealthBackdropTexturePath() or GetHealthTexturePath()
end

local function PreviewHealthColor(isTarget)
    if isTarget and CFG.targetHealthbarOverride and not CFG.targetHealthUseReactionColor then return GetCustomColor("targetHealthColor", .85, .1, .1, 1) end
    if not isTarget and not CFG.healthUseReactionColor then return GetCustomColor("healthColor", .85, .1, .1, 1) end
    return .85, .1, .1, 1
end

local function NewPreviewAura(parent, icon)
    local button = CreateAuraButton(parent)
    button.icon:SetTexture(icon)
    return button
end

local function NewPreviewPlate(parent, isTarget)
    local p = {isTarget=isTarget}
    p.hitbox = CreateFrame("Frame", nil, parent)
    p.hitbox.bg = p.hitbox:CreateTexture(nil,"BACKGROUND"); p.hitbox.bg:SetAllPoints(); p.hitbox.bg:SetColorTexture(1,.82,.05,.13)
    p.hitboxBorder = CreateBorder(p.hitbox)
    p.hitboxLabel = p.hitbox:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); p.hitboxLabel:SetPoint("TOPLEFT",4,-3); p.hitboxLabel:SetTextColor(1,.85,.15)
    p.root = CreateFrame("Frame",nil,p.hitbox); p.root:SetFrameLevel(100)
    p.border = CreateBorder(p.root)
    p.background = p.root:CreateTexture(nil,"BACKGROUND"); p.background:SetAllPoints()
    p.health = CreateFrame("StatusBar",nil,p.root); p.health:SetAllPoints(); p.health:SetMinMaxValues(0,1); p.health:SetValue(isTarget and .64 or .82)
    p.playerCastOverlay = CreateFrame("StatusBar",nil,p.root); p.playerCastOverlay:SetAllPoints(); p.playerCastOverlay:SetMinMaxValues(0,1); p.playerCastOverlay:SetValue(.56)
    p.playerCastOverlaySpark = CreateFrame("Frame",nil,p.root); p.playerCastOverlaySpark.texture=p.playerCastOverlaySpark:CreateTexture(nil,"OVERLAY"); p.playerCastOverlaySpark.texture:SetAllPoints()
    p.hpMarker=CreateFrame("Frame",nil,p.root); p.hpMarker.texture=p.hpMarker:CreateTexture(nil,"ARTWORK"); p.hpMarker.texture:SetAllPoints()
    p.levelLayer=CreateFrame("Frame",nil,p.root); p.levelLayer:SetAllPoints(); p.levelText=p.levelLayer:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); p.levelText:SetText(isTarget and "110+" or "110")
    p.nameLayer=CreateFrame("Frame",nil,p.root); p.nameLayer:SetAllPoints(); p.name=p.nameLayer:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    p.ratioLayer=CreateFrame("Frame",nil,p.root); p.ratioLayer:SetAllPoints(); p.ratio=p.ratioLayer:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); p.ratio:SetText(isTarget and "291.2" or "84.6")
    p.cast=CreateFrame("StatusBar",nil,p.root); p.cast:SetMinMaxValues(0,1); p.cast:SetValue(isTarget and .68 or .42); p.cast.bg=p.cast:CreateTexture(nil,"BACKGROUND"); p.cast.bg:SetAllPoints()
    p.castBorder=CreateBorder(p.cast); p.castText=p.cast:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); p.castText:SetText(S2K_L("Spell cast"))
    p.castIconFrame=CreateFrame("Frame",nil,p.root); p.castIconFrame.icon=p.castIconFrame:CreateTexture(nil,"ARTWORK"); p.castIconFrame.icon:SetAllPoints(); p.castIconFrame.icon:SetTexture(PREVIEW_ICONS[4]); p.castIconFrame.icon:SetTexCoord(.08,.92,.08,.92); p.castIconFrame.border=CreateBorder(p.castIconFrame)
    p.buffFrame=CreateFrame("Frame",nil,p.root); p.buffFrame.buttons={}; p.debuffFrame=CreateFrame("Frame",nil,p.root); p.debuffFrame.buttons={}
    for i=1,4 do p.buffFrame.buttons[i]=NewPreviewAura(p.buffFrame,PREVIEW_ICONS[i]); p.debuffFrame.buttons[i]=NewPreviewAura(p.debuffFrame,PREVIEW_ICONS[5-i]) end
    return p
end

function RecreateNameplatePreviewTextObjects(settingKey)
    local frame = State.nameplatePreviewFrame
    if not frame then return end

    local function Replace(plate, field, parent, fallbackText)
        local previous = plate[field]
        local value = previous and previous:GetText() or fallbackText or ""
        if previous then
            previous:SetText("")
            previous:Hide()
        end
        local replacement = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        replacement:SetText(value)
        plate[field] = replacement
    end

    for _, plate in ipairs({ frame.generalPreview, frame.targetPreview }) do
        if plate then
            if not settingKey or settingKey == "hpRatioFontKey" then Replace(plate, "ratio", plate.ratioLayer, plate.isTarget and "291.2" or "84.6") end
            if not settingKey or settingKey == "nameFontKey" then Replace(plate, "name", plate.nameLayer, plate.isTarget and S2K_L("Target nameplate") or S2K_L("General nameplate")) end
            if not settingKey or settingKey == "levelOverlayFontKey" then Replace(plate, "levelText", plate.levelLayer, plate.isTarget and "110+" or "110") end
            if not settingKey or settingKey == "castbarSpellNameFontKey" then Replace(plate, "castText", plate.cast, S2K_L("Spell cast")) end
        end
    end
end
local function PreviewMarker(p,w)
    if not CFG.hpMarkerEnabled or (CFG.hpMarkerOnlyTarget and not p.isTarget) then p.hpMarker:Hide(); return end
    local pct=math.max(0,math.min(100,tonumber(CFG.hpMarkerPercent) or 35)); local pos=w*pct/100; local mode=tostring(CFG.hpMarkerWidthMode or "LINE")
    p.hpMarker:ClearAllPoints()
    if mode=="LEFT_TO_ZERO" then p.hpMarker:SetPoint("TOPLEFT",p.health,"TOPLEFT"); p.hpMarker:SetPoint("BOTTOMLEFT",p.health,"BOTTOMLEFT"); p.hpMarker:SetWidth(math.max(1,pos))
    elseif mode=="RIGHT_TO_END" then p.hpMarker:SetPoint("TOPLEFT",p.health,"TOPLEFT",pos,0); p.hpMarker:SetPoint("BOTTOMLEFT",p.health,"BOTTOMLEFT",pos,0); p.hpMarker:SetWidth(math.max(1,w-pos))
    else p.hpMarker:SetPoint("TOP",p.health,"TOP",pos-w/2,0); p.hpMarker:SetPoint("BOTTOM",p.health,"BOTTOM",pos-w/2,0); p.hpMarker:SetWidth(math.max(1,tonumber(CFG.hpMarkerWidth) or 2)) end
    local r,g,b,a=GetHPMarkerColor(); if CFG.hpMarkerUseBorderColor then if p.isTarget and CFG.targetHealthbarOverride then r,g,b=GetTargetBorderColor() else r,g,b=GetAllBorderColor() end end
    p.hpMarker.texture:SetColorTexture(r,g,b,a); p.hpMarker:Show()
end

local function UpdatePreviewPlate(p,y,scale)
    local hw=math.max(1,tonumber(CFG.nameplateHitboxWidth) or 110); local hh=math.max(1,tonumber(CFG.nameplateHitboxHeight) or 45); local w=math.max(1,tonumber(CFG.plateWidth) or 110); local h=math.max(1,tonumber(CFG.plateHeight) or 12)
    p.hitbox:SetScale(scale); p.hitbox:ClearAllPoints(); p.hitbox:SetPoint("CENTER",p.hitbox:GetParent(),"CENTER",0,y/scale); p.hitbox:SetSize(hw,hh)
    ApplyBorderVisual(p.hitboxBorder,"S2K_SOLID","Interface\\Buttons\\WHITE8X8",1,0,0,1,.82,.05,.9)
    p.hitboxLabel:SetText(p.isTarget and S2K_L("Target nameplate") or S2K_L("General nameplate"))
    p.root:ClearAllPoints(); p.root:SetPoint("CENTER",p.hitbox,"CENTER",tonumber(CFG.healthbarHitboxXOffset) or 0,tonumber(CFG.healthbarHitboxYOffset) or 0); p.root:SetSize(w,h)
    ApplyStatusBarTexture(p.health,PreviewTexture(p.isTarget,false)); p.health:SetStatusBarColor(PreviewHealthColor(p.isTarget))
    local br,bg,bb,ba; local target=p.isTarget and CFG.targetHealthbarOverride
    if target then br,bg,bb,ba=GetCustomColor("targetHealthBackdropColor",0,0,0,.65) else br,bg,bb,ba=GetCustomColor("healthBackdropColor",0,0,0,CFG.healthBackgroundAlpha or .65) end
    ApplyStatusBarBackdropTexture(p.background,PreviewTexture(p.isTarget,true),br,bg,bb,ba)
    local tk=target and "targetBorderTextureKey" or "borderTextureKey"; local tp=target and "targetBorderTexturePath" or "borderTexturePath"; local sz=target and CFG.targetBorderSize or CFG.borderSize; local ins=target and CFG.targetBorderInset or CFG.borderInset; local off=target and CFG.targetBorderOffset or CFG.borderOffset
    if target then br,bg,bb,ba=GetTargetBorderColor() else br,bg,bb,ba=GetAllBorderColor() end
    ApplyBorderVisual(p.border,CFG[tk],GetConfiguredBorderTexturePath(tk,tp),sz,ins,off,br,bg,bb,ba)
    ApplyStatusBarTexture(p.playerCastOverlay,GetHealthTexturePath()); p.playerCastOverlay:SetStatusBarColor(GetPlayerCastOverlayColor()); if p.isTarget and CFG.playerCastOverlayEnabled then p.playerCastOverlay:Show() else p.playerCastOverlay:Hide() end
    p.playerCastOverlaySpark:ClearAllPoints(); p.playerCastOverlaySpark:SetPoint("CENTER",p.root,"LEFT",w*.56,0); p.playerCastOverlaySpark:SetSize(tonumber(CFG.playerCastOverlaySparkWidth) or 2,h); ApplyTexturePath(p.playerCastOverlaySpark.texture,GetPlayerCastOverlaySparkTexturePath()); p.playerCastOverlaySpark.texture:SetVertexColor(GetPlayerCastOverlaySparkColor()); if p.isTarget and CFG.playerCastOverlayEnabled and CFG.playerCastOverlaySparkEnabled then p.playerCastOverlaySpark:Show() else p.playerCastOverlaySpark:Hide() end
    PreviewMarker(p,w)
    p.ratio:ClearAllPoints(); p.ratio:SetPoint("CENTER",p.ratioLayer,"CENTER",0,tonumber(CFG.hpRatioYOffset) or 0); ApplyFontStringFont(p.ratio,CFG.hpRatioFontKey,CFG.hpRatioFontSize,CFG.hpRatioFontOutlineKey,CFG.hpRatioFontPath); p.ratio:SetTextColor(GetHPRatioColor()); if CFG.hpRatioText then p.ratio:Show() else p.ratio:Hide() end
    p.name:SetText(p.isTarget and S2K_L("Target nameplate") or S2K_L("General nameplate")); p.name:ClearAllPoints(); p.name:SetPoint("BOTTOM",p.root,"TOP",0,tonumber(CFG.nameYOffset) or 4); ApplyFontStringFont(p.name,CFG.nameFontKey,CFG.nameFontSize,CFG.nameFontOutlineKey,CFG.nameFontPath); if CFG.showNames then p.name:Show() else p.name:Hide() end
    ApplyFontStringFont(p.levelText,CFG.levelOverlayFontKey,CFG.levelOverlayFontSize,CFG.levelOverlayFontOutlineKey,CFG.levelOverlayFontPath); p.levelText:SetTextColor(GetLevelOverlayColor()); ApplyLevelOverlayAnchor(p.levelText,p.levelLayer,CFG.levelOverlayXOffset or 0,CFG.levelOverlayYOffset or 16); if CFG.levelOverlayEnabled then p.levelText:Show() else p.levelText:Hide() end
    ApplyFontStringFont(p.castText,CFG.castbarSpellNameFontKey,CFG.castbarSpellNameFontSize,CFG.castbarSpellNameFontOutlineKey,CFG.castbarSpellNameFontPath); p.castText:SetTextColor(GetCastbarSpellNameColor()); ApplyStatusBarTexture(p.cast,GetCastbarTexturePath()); ApplyStatusBarBackdropTexture(p.cast.bg,GetCastbarBackdropTexturePath(),GetCastbarBackdropColor()); p.cast:SetStatusBarColor(GetCastbarColor()); PositionCastbar(p); if CFG.showCastbar then p.cast:Show() else p.cast:Hide() end; if CFG.showCastbar and CFG.showCastbarSpellName then p.castText:Show() else p.castText:Hide() end; if CFG.showCastbar and CFG.showCastbarIcon then p.castIconFrame:Show() else p.castIconFrame:Hide() end
    PositionAuraFrame(p,"DEBUFF",4); PositionAuraButtons(p.debuffFrame,"DEBUFF",4); PositionAuraFrame(p,"BUFF",4); PositionAuraButtons(p.buffFrame,"BUFF",4); if CFG.debuffFrameEnabled then p.debuffFrame:Show() else p.debuffFrame:Hide() end; if CFG.buffFrameEnabled then p.buffFrame:Show() else p.buffFrame:Hide() end; for i=1,4 do p.debuffFrame.buttons[i]:Show(); p.buffFrame.buttons[i]:Show() end
    SyncCustomFrameLevels(p)
end

local function GetPreviewPlateBounds(p)
    local top, bottom
    local objects = {
        p.hitbox, p.hitboxBorder, p.root, p.border, p.cast, p.castBorder,
        p.castIconFrame, p.castIconFrame and p.castIconFrame.border,
        p.buffFrame, p.debuffFrame, p.name, p.levelText,
    }
    for _, object in ipairs(objects) do
        if object and object.IsShown and object:IsShown() and object.GetTop and object.GetBottom then
            local objectTop, objectBottom = object:GetTop(), object:GetBottom()
            if objectTop and objectBottom then
                top = top and math.max(top, objectTop) or objectTop
                bottom = bottom and math.min(bottom, objectBottom) or objectBottom
            end
        end
    end
    return top, bottom
end

local function PositionPreviewPlates(f, scale)
    local general, target = f.generalPreview, f.targetPreview
    UpdatePreviewPlate(general, 0, scale)
    UpdatePreviewPlate(target, 0, scale)

    local generalTop, generalBottom = GetPreviewPlateBounds(general)
    local targetTop, targetBottom = GetPreviewPlateBounds(target)
    local _, canvasCenter = f.canvas:GetCenter()
    if not generalTop or not generalBottom or not targetTop or not targetBottom or not canvasCenter then
        UpdatePreviewPlate(general, 55, scale)
        UpdatePreviewPlate(target, -55, scale)
        return
    end

    local gap = 10
    local generalHeight = generalTop - generalBottom
    local targetHeight = targetTop - targetBottom
    local totalHeight = generalHeight + gap + targetHeight
    local desiredBottom = canvasCenter - totalHeight / 2
    local targetOffset = desiredBottom - targetBottom
    local generalOffset = desiredBottom + targetHeight + gap - generalBottom
    UpdatePreviewPlate(general, generalOffset, scale)
    UpdatePreviewPlate(target, targetOffset, scale)
end

local function PreviewValue(value)
    local number = tonumber(value) or 0
    if number == math.floor(number) then return tostring(number) end
    return string.format("%.2f", number):gsub("0+$", ""):gsub("%.$", "")
end
local function AnimatePreviewPlayerCast(frame, elapsed)
    local p = frame and frame.targetPreview
    if not p or not CFG.playerCastOverlayEnabled then return end

    p.previewCastProgress = ((p.previewCastProgress or 0) + (tonumber(elapsed) or 0) / 2.5) % 1
    p.playerCastOverlay:SetValue(p.previewCastProgress)
    p.playerCastOverlay:Show()

    local width = math.max(1, tonumber(CFG.plateWidth) or 110)
    p.playerCastOverlaySpark:ClearAllPoints()
    p.playerCastOverlaySpark:SetPoint("CENTER", p.root, "LEFT", width * p.previewCastProgress, 0)
end
function EnsureNameplatePreview()
    if State.nameplatePreviewFrame then return State.nameplatePreviewFrame end
    local gui=LibStub and LibStub("AceGUI-3.0",true)
    if not gui then return nil end
    local widget=gui:Create("S2KFrame")
    if not widget then return nil end
    widget:SetTitle(S2K_L("Nameplate layout preview"))
    widget:SetWidth(560)
    widget:SetHeight(380)
    widget:EnableResize(true)
    widget.frame:ClearAllPoints()
    widget.frame:SetPoint("CENTER",UIParent,"CENTER",0,40)
    widget.frame:SetClampedToScreen(true)

    local f=widget.frame
    local content=widget.content
    local close=CreateFrame("Button",nil,f)
    close:SetSize(32,32)
    close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-8,-8)
    close:SetFrameLevel(f:GetFrameLevel()+60)
    close:RegisterForClicks("LeftButtonUp")
    close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    close:SetHitRectInsets(0,0,0,0)
    close:SetScript("OnClick",function()
        State.nameplatePreviewRequested=false
        widget:Hide()
        if SyncNameplatePreviewToggleControl then SyncNameplatePreviewToggleControl(false) end
    end)

    f.info=content:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    f.info:SetPoint("TOPLEFT",content,"TOPLEFT",8,-8)
    f.info:SetPoint("TOPRIGHT",content,"TOPRIGHT",-8,-8)
    f.info:SetJustifyH("LEFT")
    f.info:SetJustifyV("TOP")
    f.canvas=CreateFrame("Frame",nil,content)
    f.canvas:SetPoint("TOPLEFT",content,"TOPLEFT",8,-70)
    f.canvas:SetPoint("BOTTOMRIGHT",content,"BOTTOMRIGHT",-8,8)
    f.generalPreview=NewPreviewPlate(f.canvas,false)
    f.targetPreview=NewPreviewPlate(f.canvas,true)
    f:SetScript("OnUpdate",AnimatePreviewPlayerCast)
    f:SetScript("OnSizeChanged",function() if UpdateNameplatePreview then UpdateNameplatePreview() end end)
    f:Hide()
    f.s2kPreviewWidget=widget
    f.s2kPreviewCloseWidget=close
    State.nameplatePreviewWidget=widget
    State.nameplatePreviewFrame=f
    return f
end

function UpdateNameplatePreview()
    local f=State.nameplatePreviewFrame
    if not f or not f:IsShown() then return end

    local hw=math.max(1,tonumber(CFG.nameplateHitboxWidth) or 110)
    local hh=math.max(1,tonumber(CFG.nameplateHitboxHeight) or 45)
    local healthWidth=math.max(1,tonumber(CFG.plateWidth) or 110)
    local healthHeight=math.max(1,tonumber(CFG.plateHeight) or 12)
    local availableWidth=math.max(1,(f.canvas:GetWidth() or 500)-20)
    local scale=math.min(1,availableWidth/math.max(hw,healthWidth))

    f.info:SetText(string.format(
        "%s: %s x %s    %s: %s x %s    %s: %s, %s    %s: %s / %s\n" ..
        "%s: %s / %s / %s    %s: %s    %s: %s    %s: %s\n" ..
        "%s: %s x %s, %s %s    %s: %s x %s, %s %s",
        S2K_L("Hitbox"),PreviewValue(hw),PreviewValue(hh),
        S2K_L("Healthbar"),PreviewValue(healthWidth),PreviewValue(healthHeight),
        S2K_L("Health offset"),PreviewValue(CFG.healthbarHitboxXOffset),PreviewValue(CFG.healthbarHitboxYOffset),
        S2K_L("Global / selected scale"),PreviewValue(CFG.nameplateGlobalScale),PreviewValue(CFG.nameplateSelectedScale),
        S2K_L("Border size / inset / offset"),PreviewValue(CFG.borderSize),PreviewValue(CFG.borderInset),PreviewValue(CFG.borderOffset),
        S2K_L("Castbar height"),PreviewValue(CFG.castbarHeight),S2K_L("Castbar Y offset"),PreviewValue(CFG.castbarYOffset),
        S2K_L("Icon size"),PreviewValue(CFG.castbarIconSize),
        S2K_L("Buff icons"),PreviewValue(CFG.buffIconWidth),PreviewValue(CFG.buffIconHeight),S2K_L("spacing"),PreviewValue(CFG.buffIconSpacing),
        S2K_L("Debuff icons"),PreviewValue(CFG.debuffIconWidth),PreviewValue(CFG.debuffIconHeight),S2K_L("spacing"),PreviewValue(CFG.debuffIconSpacing)
    ))
    PositionPreviewPlates(f,scale)
end

function SetNameplatePreviewShown(shown) State.nameplatePreviewRequested=shown and true or false; local f=EnsureNameplatePreview(); if not f then return end; if State.nameplatePreviewRequested and State.configFrame and State.configFrame:IsShown() then f:Show(); UpdateNameplatePreview() else f:Hide() end end
function RefreshNameplatePreviewVisibility() local show=State.nameplatePreviewRequested and State.configFrame and State.configFrame:IsShown(); if show then local f=EnsureNameplatePreview(); if not f then return end; f:Show(); UpdateNameplatePreview() elseif State.nameplatePreviewFrame then State.nameplatePreviewFrame:Hide() end end
function HideNameplatePreview() if State.nameplatePreviewFrame then State.nameplatePreviewFrame:Hide() end end
