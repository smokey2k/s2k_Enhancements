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

function CreatePersonalResourceStatusBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.bg:SetColorTexture(0, 0, 0, .7)
    bar.border = CreateBorder(bar)
    bar.s2kManagedBackdrop = bar.bg
    bar.s2kManagedBorder = bar.border
    bar.s2kAddonOwnedPersonalResource = true
    return bar
end

function CreatePersonalClassResourceFrame(parent, segmentCount)
    local frame = CreateFrame("Frame", nil, parent)
    frame.points = {}
    for index = 1, (tonumber(segmentCount) or 6) do
        local point = CreateFrame("Frame", nil, frame)
        point.bg = point:CreateTexture(nil, "BACKGROUND")
        point.bg:SetAllPoints(point)
        point.fill = point:CreateTexture(nil, "ARTWORK")
        point.fill:SetAllPoints(point)
        point.s2kManagedBackdrop = point.bg
        point.s2kManagedFill = point.fill
        point.s2kManagedBorder = CreateBorder(point)
        point.s2kManagedBorder.s2kPersonalResourceDecoration = true
        frame.points[index] = point
    end
    frame.s2kAddonOwnedPersonalResource = true
    return frame
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
        ctx.castBorder:SetFrameLevel(base + (tonumber(CFG.castbarBorderFrameLevel) or 5))
    end

    -- Player cast overlay is drawn over the custom healthbar.
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

    if ctx.border and ctx.border.SetFrameLevel then
        local group = GetNameplateDesignGroup(ctx.unit)
        if ctx.designGroup then group = ctx.designGroup end
        ctx.border:SetFrameLevel(base + (tonumber(CFG[group .. "BorderFrameLevel"]) or 3))
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
    local strata = tostring(GetNameplateDimensionValue(ctx, "HealthbarFrameStrata", "HIGH")):upper()
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

            local priorities = { personal = 1, friendly = 1, enemy = 1, focus = 2, target = 3 }
            local aPriority = priorities[GetNameplateDesignGroup(a.unit)] or 1
            local bPriority = priorities[GetNameplateDesignGroup(b.unit)] or 1
            if aPriority ~= bPriority then return aPriority < bPriority end

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

local function CreateNameplateVisualTree(root, names)
    names = names or {}
    local visual = { root = root }
    visual.border = CreateBorder(root)
    visual.background = root:CreateTexture(nil, "BACKGROUND"); visual.background:SetAllPoints(root)
    visual.health = CreateFrame("StatusBar", names.health, root); visual.health:SetAllPoints(root); visual.health:SetMinMaxValues(0, 1); visual.health:SetValue(1)
    visual.playerCastOverlay = CreateFrame("StatusBar", nil, root); visual.playerCastOverlay:SetAllPoints(root); visual.playerCastOverlay:SetMinMaxValues(0, 1); visual.playerCastOverlay:SetValue(0); visual.playerCastOverlay:Hide()
    visual.playerCastOverlaySpark = CreateFrame("Frame", nil, root); visual.playerCastOverlaySpark.texture = visual.playerCastOverlaySpark:CreateTexture(nil, "OVERLAY"); visual.playerCastOverlaySpark.texture:SetAllPoints(); visual.playerCastOverlaySpark:Hide()
    visual.hpMarker = CreateFrame("Frame", nil, root); visual.hpMarker.texture = visual.hpMarker:CreateTexture(nil, "ARTWORK"); visual.hpMarker.texture:SetAllPoints(); visual.hpMarker:Hide()
    for _, key in ipairs({ "level", "name", "ratio" }) do visual[key.."Layer"] = CreateFrame("Frame", nil, root); visual[key.."Layer"]:SetAllPoints(root) end
    visual.levelText = visual.levelLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    visual.name = visual.nameLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    visual.ratio = visual.ratioLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    visual.cast = CreateFrame("StatusBar", names.cast, root); visual.cast:SetMinMaxValues(0, 1); visual.cast:SetValue(0); visual.cast.bg = visual.cast:CreateTexture(nil, "BACKGROUND"); visual.cast.bg:SetAllPoints(); visual.cast:Hide()
    visual.castBorder = CreateBorder(visual.cast); visual.castBorder:Hide()
    visual.castText = visual.cast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    visual.castIconFrame = CreateFrame("Frame", nil, root); visual.castIconFrame.icon = visual.castIconFrame:CreateTexture(nil, "ARTWORK"); visual.castIconFrame.icon:SetAllPoints(); visual.castIconFrame.icon:SetTexCoord(.08, .92, .08, .92); visual.castIconFrame.border = CreateBorder(visual.castIconFrame); visual.castIconFrame:Hide()
    visual.debuffFrame = CreateFrame("Frame", nil, root); visual.debuffFrame.buttons = {}
    visual.buffFrame = CreateFrame("Frame", nil, root); visual.buffFrame.buttons = {}
    return visual
end

local function AdoptNameplateVisualTree(target, visual)
    for key, value in pairs(visual) do target[key] = value end
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

    local visual = CreateNameplateVisualTree(root, { health = healthName, cast = castName })
    AdoptNameplateVisualTree(ctx, visual)
    ApplyStatusBarBackdropTexture(ctx.background, GetHealthBackdropTexturePath(ctx), GetHealthBackdropColor(ctx))
    ApplyStatusBarTexture(ctx.health, GetHealthTexturePath(ctx)); ctx.health.s2kNameplateContext = ctx
    ApplyStatusBarTexture(ctx.playerCastOverlay, GetHealthTexturePath(ctx))
    ctx.playerCastOverlaySpark:SetSize(tonumber(CFG.playerCastOverlaySparkWidth) or 2, tonumber(GetNameplateDimensionValue(unit, "PlateHeight", 12)) or 12)
    ApplyTexturePath(ctx.playerCastOverlaySpark.texture, GetPlayerCastOverlaySparkTexturePath()); ctx.playerCastOverlaySpark.texture:SetVertexColor(GetPlayerCastOverlaySparkColor())
    if ctx.levelText.SetDrawLayer then ctx.levelText:SetDrawLayer("OVERLAY", 7) end
    ctx.levelText:SetPoint("CENTER", ctx.levelLayer, "CENTER", CFG.levelOverlayXOffset or 0, CFG.levelOverlayYOffset or 16); ctx.levelText:SetJustifyH("CENTER"); ctx.levelText:SetJustifyV("MIDDLE"); ctx.levelText:SetTextColor(GetLevelOverlayColor()); ctx.levelText:SetShadowColor(0, 0, 0, 1); ctx.levelText:SetShadowOffset(1, -1); ctx.levelText:Hide()
    if ctx.name.SetDrawLayer then ctx.name:SetDrawLayer("OVERLAY", 7) end
    ctx.name:SetPoint("BOTTOM", root, "TOP", 0, CFG.nameYOffset or 4); ctx.name:SetJustifyH("CENTER")
    if ctx.ratio.SetDrawLayer then ctx.ratio:SetDrawLayer("OVERLAY", 7) end
    ctx.ratio:SetPoint("CENTER", ctx.ratioLayer, "CENTER", 0, CFG.hpRatioYOffset or 0); ctx.ratio:SetJustifyH("CENTER"); ctx.ratio:SetJustifyV("MIDDLE"); ctx.ratio:SetTextColor(1, 1, 1, 1); ctx.ratio:SetShadowColor(0, 0, 0, 1); ctx.ratio:SetShadowOffset(1, -1)
    ApplyStatusBarTexture(ctx.cast, GetCastbarTexturePath()); ctx.cast:SetStatusBarColor(1, 0.7, 0.1, 1); ApplyStatusBarBackdropTexture(ctx.cast.bg, GetCastbarBackdropTexturePath(), GetCastbarBackdropColor()); ctx.cast.s2kNameplateContext = ctx

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

    local castText = ctx.castText
    castText:SetPoint("CENTER", ctx.cast, "CENTER", 0, 0); castText:SetJustifyH("CENTER"); castText:SetJustifyV("MIDDLE")
    ApplyFontStringFont(castText, CFG.castbarSpellNameFontKey, CFG.castbarSpellNameFontSize, CFG.castbarSpellNameFontOutlineKey, CFG.castbarSpellNameFontPath)
    castText:SetTextColor(GetCastbarSpellNameColor()); castText:SetShadowColor(0, 0, 0, 1); castText:SetShadowOffset(1, -1); castText:Hide()

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
    if ctx.s2kPersonalResourceBar then ctx.s2kPersonalResourceBar:Hide() end
    if ctx.s2kPersonalClassResource then ctx.s2kPersonalClassResource:Hide() end
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

local function PreviewTexture(group, backdrop)
    local suffix = backdrop and "HealthBackdropTexture" or "HealthTexture"
    local key, pathKey = group .. suffix .. "Key", group .. suffix .. "Path"
    local option = GetStatusBarTextureOption(CFG[key], CFG[pathKey])
    return (option and option.path) or CFG[pathKey] or "Interface\\Buttons\\WHITE8X8"
end

local function PreviewHealthColor(group)
    if CFG[group .. "HealthUseReactionColor"] then
        if group == "friendly" then return .1, .85, .15, 1 end
        return .85, .1, .1, 1
    end
    return GetCustomColor(group .. "HealthColor", .85, .1, .1, 1)
end

local function NewPreviewAura(parent, icon)
    local button = CreateAuraButton(parent)
    button.icon:SetTexture(icon)
    return button
end

local function NewPreviewPlate(parent, group)
    local dimensionGroup = group == "personal" and "personal" or group == "friendly" and "friendly" or "enemy"
    local p = {designGroup=group, dimensionGroup=dimensionGroup, isTarget=group == "target"}
    p.hitbox = CreateFrame("Frame", nil, parent)
    p.hitbox.bg = p.hitbox:CreateTexture(nil,"BACKGROUND"); p.hitbox.bg:SetAllPoints(); p.hitbox.bg:SetColorTexture(1,.82,.05,.13)
    p.hitboxBorder = CreateBorder(p.hitbox)
    p.hitboxLabel = p.hitbox:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); p.hitboxLabel:SetPoint("TOPLEFT",4,-3); p.hitboxLabel:SetTextColor(1,.85,.15)
    p.root = CreateFrame("Frame",nil,p.hitbox); p.root:SetFrameLevel(100)
    AdoptNameplateVisualTree(p, CreateNameplateVisualTree(p.root))
    p.health:SetValue(p.isTarget and .64 or .82); p.playerCastOverlay:SetValue(.56); p.playerCastOverlay:Show(); p.playerCastOverlaySpark:Show(); p.hpMarker:Show()
    p.levelText:SetText(p.isTarget and "110+" or "110"); p.ratio:SetText(p.isTarget and "291.2" or "84.6")
    p.cast:SetValue(p.isTarget and .68 or .42); p.cast:Show(); p.castBorder:Show(); p.castText:SetText(S2K_L("Spell cast")); p.castText:Show()
    p.castIconFrame.icon:SetTexture(PREVIEW_ICONS[4]); p.castIconFrame:Show()
    if group=="personal" then
        p.personalResourceBar=CreatePersonalResourceStatusBar(p.hitbox)
        p.personalResourceBar:SetFrameLevel(160)
        p.personalResourceBar:SetValue(.72)
        p.personalResourceBar:SetStatusBarColor(.15,.45,1,1)
        p.personalClassResource=CreatePersonalClassResourceFrame(p.hitbox,5);p.personalClassResource:SetFrameLevel(160)
        for _,point in ipairs(p.personalClassResource.points)do point.border=point.s2kManagedBorder end
    end
    for i=1,4 do p.buffFrame.buttons[i]=NewPreviewAura(p.buffFrame,PREVIEW_ICONS[i]); p.debuffFrame.buttons[i]=NewPreviewAura(p.debuffFrame,PREVIEW_ICONS[5-i]) end
    return p
end

local function EnsurePreviewAuraButtons(frame, count, kind)
    count = math.max(1, math.min(40, tonumber(count) or 1))
    while #frame.buttons < count do
        local index = #frame.buttons + 1
        local iconIndex = kind == "BUFF" and ((index - 1) % #PREVIEW_ICONS) + 1
            or (#PREVIEW_ICONS - ((index - 1) % #PREVIEW_ICONS))
        frame.buttons[index] = NewPreviewAura(frame, PREVIEW_ICONS[iconIndex])
    end
end

local function UpdatePreviewAuraFrame(p, kind)
    local isBuff = kind == "BUFF"
    local frame = isBuff and p.buffFrame or p.debuffFrame
    local maxIcons = math.max(1, math.min(40, tonumber(isBuff and CFG.buffMaxIcons or CFG.debuffMaxIcons) or 8))
    local enabled = isBuff and CFG.buffFrameEnabled or CFG.debuffFrameEnabled
    local showForDesign = CFG[p.designGroup .. (isBuff and "ShowBuffs" or "ShowDebuffs")] ~= false

    EnsurePreviewAuraButtons(frame, maxIcons, kind)
    PositionAuraFrame(p, kind, maxIcons)
    PositionAuraButtons(frame, kind, maxIcons)
    for index, button in ipairs(frame.buttons) do
        if enabled and showForDesign and index <= maxIcons then
            button:Show()
        else
            button:Hide()
        end
    end
    if enabled and showForDesign then frame:Show() else frame:Hide() end
end

local function UpdatePreviewPersonalResources(p)
    if not p.personalResourceBar or not p.personalClassResource then return end
    local resource=p.personalResourceBar
    if CFG.personalResourceBarEnabled then resource:Show() else resource:Hide() end
    local class=p.personalClassResource
    if CFG.personalClassResourceEnabled then class:Show() else class:Hide() end

    resource:ClearAllPoints()
    local resourceAnchor=ResolveLayoutNodeAnchor(p,"PERSONAL_RESOURCE")
    local resourceSide=GetLayoutNodeSide(p,"PERSONAL_RESOURCE")
    local resourceOffset=GetEffectiveLayoutNodeOffset(p,"PERSONAL_RESOURCE")
    if resourceSide=="TOP" then resource:SetPoint("BOTTOM",resourceAnchor,"TOP",tonumber(CFG.personalResourceBarXOffset) or 0,resourceOffset)
    else resource:SetPoint("TOP",resourceAnchor,"BOTTOM",tonumber(CFG.personalResourceBarXOffset) or 0,resourceOffset) end
    resource:SetSize(math.max(1,tonumber(CFG.personalResourceBarWidth) or 110),math.max(1,tonumber(CFG.personalResourceBarHeight) or 8))
    if resource.SetFrameStrata then resource:SetFrameStrata(tostring(CFG.personalResourceBarFrameStrata or "HIGH")) end
    ApplyStatusBarTexture(resource,GetConfiguredStatusBarTexturePath("personalResourceBarTextureKey","personalResourceBarTexturePath"))
    resource:SetStatusBarColor(GetCustomColor("personalResourceBarColor",.15,.45,1,1))
    ApplyStatusBarBackdropTexture(resource.bg,
        GetConfiguredStatusBarTexturePath("personalResourceBarBackdropTextureKey","personalResourceBarBackdropTexturePath"),
        GetCustomColor("personalResourceBarBackdropColor",0,0,0,.7))
    ApplyBorderVisual(resource.border,CFG.personalResourceBarBorderTextureKey,
        GetConfiguredBorderTexturePath("personalResourceBarBorderTextureKey","personalResourceBarBorderTexturePath"),
        CFG.personalResourceBarBorderSize,CFG.personalResourceBarBorderInset,CFG.personalResourceBarBorderOffset,
        GetCustomColor("personalResourceBarBorderColor",0,0,0,1))
    if resource.border.SetFrameLevel then
        resource.border:SetFrameLevel((resource:GetFrameLevel() or 0)
            +(tonumber(CFG.personalResourceBarBorderFrameLevel) or 5))
    end

    local width=math.max(1,tonumber(CFG.personalClassResourceWidth) or 110)
    local height=math.max(1,tonumber(CFG.personalClassResourceHeight) or 10)
    class:ClearAllPoints()
    local classAnchor=ResolveLayoutNodeAnchor(p,"PERSONAL_CLASS_RESOURCE")
    local classSide=GetLayoutNodeSide(p,"PERSONAL_CLASS_RESOURCE")
    local classOffset=GetEffectiveLayoutNodeOffset(p,"PERSONAL_CLASS_RESOURCE")
    if classSide=="TOP" then class:SetPoint("BOTTOM",classAnchor,"TOP",tonumber(CFG.personalClassResourceXOffset) or 0,classOffset)
    else class:SetPoint("TOP",classAnchor,"BOTTOM",tonumber(CFG.personalClassResourceXOffset) or 0,classOffset) end
    class:SetSize(width,height)
    local gap=math.max(0,tonumber(CFG.personalClassResourceSpacing) or 0)
    local pointWidth=math.max(1,(width-gap*4)/5)
    for index,point in ipairs(class.points)do
        point:ClearAllPoints();point:SetPoint("TOPLEFT",class,"TOPLEFT",(index-1)*(pointWidth+gap),0);point:SetSize(pointWidth,height)
        ApplyTexturePath(point.fill,GetConfiguredStatusBarTexturePath("personalClassResourceTextureKey","personalClassResourceTexturePath"))
        point.fill:SetVertexColor(GetCustomColor("personalClassResourceColor",1,.72,.08,1))
        ApplyStatusBarBackdropTexture(point.bg,
            GetConfiguredStatusBarTexturePath("personalClassResourceBackdropTextureKey","personalClassResourceBackdropTexturePath"),
            GetCustomColor("personalClassResourceBackdropColor",0,0,0,.7))
        if CFG.personalClassResourceBorderEnabled then
            ApplyBorderVisual(point.border,"S2K_SOLID","Interface\\Buttons\\WHITE8X8",1,0,0,
                GetCustomColor("personalClassResourceBorderColor",0,0,0,1))
        else
            point.border:Hide()
        end
    end
end

local function UpdatePreviewAuraFrames(p)
    local buffAnchorTo=GetConfiguredAuraAnchorTarget(p,"BUFF")
    local debuffAnchorTo=GetConfiguredAuraAnchorTarget(p,"DEBUFF")
    if debuffAnchorTo == "BUFF" and buffAnchorTo ~= "DEBUFF" then
        UpdatePreviewAuraFrame(p, "BUFF")
        UpdatePreviewAuraFrame(p, "DEBUFF")
    else
        UpdatePreviewAuraFrame(p, "DEBUFF")
        UpdatePreviewAuraFrame(p, "BUFF")
    end
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

    for _, plate in ipairs(frame.previews or {}) do
        if plate then
            if not settingKey or settingKey == "hpRatioFontKey" then Replace(plate, "ratio", plate.ratioLayer, plate.isTarget and "291.2" or "84.6") end
            if not settingKey or settingKey == "nameFontKey" then Replace(plate, "name", plate.nameLayer, S2K_L(plate.designGroup:gsub("^%l", string.upper) .. " nameplate")) end
            if not settingKey or settingKey == "levelOverlayFontKey" then Replace(plate, "levelText", plate.levelLayer, plate.isTarget and "110+" or "110") end
            if not settingKey or settingKey == "castbarSpellNameFontKey" then Replace(plate, "castText", plate.cast, S2K_L("Spell cast")) end
        end
    end
end
local function PreviewMarker(p,w)
    local group=p.designGroup
    if not CFG[group.."ShowHPMarker"] or (CFG.hpMarkerOnlyEnemy and p.dimensionGroup~="enemy") then p.hpMarker:Hide(); return end
    local h=p.health:GetHeight() or 1;local inset=math.max(0,tonumber(CFG.hpMarkerInset) or 0);inset=math.min(inset,math.max(0,math.min(w,h)/2-.5))
    local pct=math.max(0,math.min(100,tonumber(CFG.hpMarkerPercent) or 35)); local pos=w*pct/100; local mode=tostring(CFG.hpMarkerWidthMode or "LINE")
    p.hpMarker:ClearAllPoints()
    if mode=="LEFT_TO_ZERO" then p.hpMarker:SetPoint("TOPLEFT",p.health,"TOPLEFT",inset,-inset); p.hpMarker:SetPoint("BOTTOMLEFT",p.health,"BOTTOMLEFT",inset,inset); p.hpMarker:SetWidth(math.max(1,pos-inset))
    elseif mode=="RIGHT_TO_END" then p.hpMarker:SetPoint("TOPLEFT",p.health,"TOPLEFT",pos,-inset); p.hpMarker:SetPoint("BOTTOMLEFT",p.health,"BOTTOMLEFT",pos,inset); p.hpMarker:SetWidth(math.max(1,w-inset-pos))
    else p.hpMarker:SetPoint("TOP",p.health,"TOP",pos-w/2,-inset); p.hpMarker:SetPoint("BOTTOM",p.health,"BOTTOM",pos-w/2,inset); p.hpMarker:SetWidth(math.max(1,tonumber(CFG.hpMarkerWidth) or 2)) end
    local r,g,b,a=GetCustomColor(group.."HPMarkerColor",1,1,1,1); if CFG.hpMarkerUseBorderColor then r,g,b=GetCustomColor(group.."BorderColor",0,0,0,1) end
    p.hpMarker.texture:SetColorTexture(r,g,b,a); p.hpMarker:Show()
end

local function UpdatePreviewPlate(p,x,y,scale)
    local group,dim=p.designGroup,p.dimensionGroup
    local hw=math.max(1,tonumber(CFG[dim.."NameplateHitboxWidth"]) or 110); local hh=math.max(1,tonumber(CFG[dim.."NameplateHitboxHeight"]) or 45); local w=math.max(1,tonumber(CFG[dim.."PlateWidth"]) or 110); local h=math.max(1,tonumber(CFG[dim.."PlateHeight"]) or 12)
    p.hitbox:SetScale(scale); p.hitbox:ClearAllPoints(); p.hitbox:SetPoint("CENTER",p.hitbox:GetParent(),"CENTER",x/scale,y/scale); p.hitbox:SetSize(hw,hh)
    ApplyBorderVisual(p.hitboxBorder,"S2K_SOLID","Interface\\Buttons\\WHITE8X8",1,0,0,1,.82,.05,.9)
    p.hitboxLabel:SetText(S2K_L(group:gsub("^%l",string.upper).." nameplate"))
    p.root:ClearAllPoints(); p.root:SetPoint("CENTER",p.hitbox,"CENTER",tonumber(CFG[dim.."HealthbarHitboxXOffset"]) or 0,tonumber(CFG[dim.."HealthbarHitboxYOffset"]) or 0); p.root:SetSize(w,h)
    ApplyStatusBarTexture(p.health,PreviewTexture(group,false)); p.health:SetStatusBarColor(PreviewHealthColor(group))
    local br,bg,bb,ba=GetCustomColor(group.."HealthBackdropColor",0,0,0,.65)
    ApplyStatusBarBackdropTexture(p.background,PreviewTexture(group,true),br,bg,bb,ba)
    local tk,tp=group.."BorderTextureKey",group.."BorderTexturePath"
    br,bg,bb,ba=GetCustomColor(group.."BorderColor",0,0,0,1)
    ApplyBorderVisual(p.border,CFG[tk],GetConfiguredBorderTexturePath(tk,tp),CFG[group.."BorderSize"],CFG[group.."BorderInset"],CFG[group.."BorderOffset"],br,bg,bb,ba)
    if PositionPlayerCastOverlay then PositionPlayerCastOverlay(p) end; ApplyStatusBarTexture(p.playerCastOverlay,PreviewTexture(group,false)); p.playerCastOverlay:SetStatusBarColor(GetPlayerCastOverlayColor()); if p.isTarget and CFG.targetPlayerCastOverlayEnabled then p.playerCastOverlay:Show() else p.playerCastOverlay:Hide() end
    local overlayW=p.playerCastOverlay:GetWidth() or w;local overlayH=p.playerCastOverlay:GetHeight() or h;p.playerCastOverlaySpark:ClearAllPoints(); p.playerCastOverlaySpark:SetPoint("CENTER",p.playerCastOverlay,"LEFT",overlayW*.56,0); p.playerCastOverlaySpark:SetSize(tonumber(CFG.playerCastOverlaySparkWidth) or 2,math.max(1,overlayH)); ApplyTexturePath(p.playerCastOverlaySpark.texture,GetPlayerCastOverlaySparkTexturePath()); p.playerCastOverlaySpark.texture:SetVertexColor(GetPlayerCastOverlaySparkColor()); if p.isTarget and CFG.targetPlayerCastOverlayEnabled and CFG.playerCastOverlaySparkEnabled then p.playerCastOverlaySpark:Show() else p.playerCastOverlaySpark:Hide() end
    PreviewMarker(p,w)
    p.ratio:ClearAllPoints(); p.ratio:SetPoint("CENTER",p.ratioLayer,"CENTER",0,tonumber(CFG.hpRatioYOffset) or 0); ApplyFontStringFont(p.ratio,CFG.hpRatioFontKey,CFG.hpRatioFontSize,CFG.hpRatioFontOutlineKey,CFG.hpRatioFontPath); p.ratio:SetTextColor(GetHPRatioColor()); if CFG[group.."ShowHPRatio"] then p.ratio:Show() else p.ratio:Hide() end
    p.name:SetText(S2K_L(group:gsub("^%l",string.upper).." nameplate")); p.name:ClearAllPoints(); p.name:SetPoint("BOTTOM",p.root,"TOP",0,tonumber(CFG.nameYOffset) or 4); ApplyFontStringFont(p.name,CFG.nameFontKey,CFG.nameFontSize,CFG.nameFontOutlineKey,CFG.nameFontPath); if CFG[group.."ShowNames"] then p.name:Show() else p.name:Hide() end
    ApplyFontStringFont(p.levelText,CFG.levelOverlayFontKey,CFG.levelOverlayFontSize,CFG.levelOverlayFontOutlineKey,CFG.levelOverlayFontPath); p.levelText:SetTextColor(GetLevelOverlayColor()); ApplyLevelOverlayAnchor(p.levelText,p.levelLayer,CFG.levelOverlayXOffset or 0,CFG.levelOverlayYOffset or 16); if CFG[group.."ShowLevelOverlay"] then p.levelText:Show() else p.levelText:Hide() end
    ApplyFontStringFont(p.castText,CFG.castbarSpellNameFontKey,CFG.castbarSpellNameFontSize,CFG.castbarSpellNameFontOutlineKey,CFG.castbarSpellNameFontPath); p.castText:SetTextColor(GetCastbarSpellNameColor()); ApplyStatusBarTexture(p.cast,GetCastbarTexturePath()); ApplyStatusBarBackdropTexture(p.cast.bg,GetCastbarBackdropTexturePath(),GetCastbarBackdropColor()); p.cast:SetStatusBarColor(GetCastbarColor()); PositionCastbar(p); if CFG.showCastbar then p.cast:Show() else p.cast:Hide() end; if CFG.showCastbar and CFG.showCastbarSpellName then p.castText:Show() else p.castText:Hide() end; if CFG.showCastbar and CFG.showCastbarIcon then p.castIconFrame:Show() else p.castIconFrame:Hide() end
    UpdatePreviewPersonalResources(p)
    UpdatePreviewAuraFrames(p)
    -- A second dependency pass lets newly shown/hidden dynamic parents collapse
    -- or expand their complete child chain in the same preview refresh.
    PositionCastbar(p)
    UpdatePreviewPersonalResources(p)
    UpdatePreviewAuraFrames(p)
    SyncCustomFrameLevels(p)
end

local function GetPreviewHitboxSize(plate)
    local dimension = plate.dimensionGroup
    return math.max(1,tonumber(CFG[dimension.."NameplateHitboxWidth"]) or 110),
        math.max(1,tonumber(CFG[dimension.."NameplateHitboxHeight"]) or 45)
end

local function BuildPreviewMotionLayout(f)
    local targetW,targetH=GetPreviewHitboxSize(f.targetPreview)
    local focusW,focusH=GetPreviewHitboxSize(f.focusPreview)
    local friendlyW,friendlyH=GetPreviewHitboxSize(f.friendlyPreview)
    local enemyW,enemyH=GetPreviewHitboxSize(f.enemyPreview)
    local overlapH=math.max(0,tonumber(CFG.nameplateOverlapH) or .8)
    local overlapV=math.max(0,tonumber(CFG.nameplateOverlapV) or 1.1)
    local motion=math.floor((tonumber(CFG.nameplateMotion) or 0)+.5)
    local positions={
        {plate=f.targetPreview,x=0,y=0,w=targetW,h=targetH},
        {plate=f.focusPreview,x=0,y=0,w=focusW,h=focusH},
        {plate=f.friendlyPreview,x=0,y=0,w=friendlyW,h=friendlyH},
        {plate=f.enemyPreview,x=0,y=0,w=enemyW,h=enemyH},
    }

    if motion==1 then
        -- Stacking resolves collisions into one vertical stack. Horizontal
        -- overlap is the collision threshold, not the final X separation.
        for index=2,#positions do
            local previous,current=positions[index-1],positions[index]
            current.y=previous.y-((previous.h+current.h)*.5*overlapV)
        end
        local stackTop=positions[1].y+positions[1].h*.5
        local last=positions[#positions]
        local stackBottom=last.y-last.h*.5
        local center=(stackTop+stackBottom)*.5
        for _,entry in ipairs(positions) do entry.y=entry.y-center end
    elseif motion==2 then
        -- Spread uses both collision axes and exposes the requested 2x2 matrix.
        local leftW,rightW=math.max(targetW,friendlyW),math.max(focusW,enemyW)
        local topH,bottomH=math.max(targetH,focusH),math.max(friendlyH,enemyH)
        local columnDistance=((leftW+rightW)*.5)*overlapH
        local rowDistance=((topH+bottomH)*.5)*overlapV
        positions[1].x,positions[1].y=-columnDistance*.5,rowDistance*.5
        positions[2].x,positions[2].y=columnDistance*.5,rowDistance*.5
        positions[3].x,positions[3].y=-columnDistance*.5,-rowDistance*.5
        positions[4].x,positions[4].y=columnDistance*.5,-rowDistance*.5
    end
    -- motion==0 intentionally leaves every synthetic unit anchor at the same
    -- point, demonstrating Blizzard's overlapping/default behavior.
    local minX,maxX,minY,maxY
    for _,entry in ipairs(positions) do
        minX=math.min(minX or entry.x-entry.w*.5,entry.x-entry.w*.5);maxX=math.max(maxX or entry.x+entry.w*.5,entry.x+entry.w*.5)
        minY=math.min(minY or entry.y-entry.h*.5,entry.y-entry.h*.5);maxY=math.max(maxY or entry.y+entry.h*.5,entry.y+entry.h*.5)
    end
    return positions,math.max(1,maxX-minX),math.max(1,maxY-minY)
end

local function PositionPreviewPlates(f)
    local positions,width,height=BuildPreviewMotionLayout(f)
    local availableWidth=math.max(1,(f.canvas:GetWidth() or 500)-20)
    local availableHeight=math.max(1,(f.canvas:GetHeight() or 500)-20)
    local scale=math.min(1,availableWidth/width,availableHeight/height)
    for _,entry in ipairs(positions) do UpdatePreviewPlate(entry.plate,entry.x*scale,entry.y*scale,scale) end
    local personalW,personalH=GetPreviewHitboxSize(f.personalPreview)
    local personalY=(availableHeight-personalH*scale)*.5
    UpdatePreviewPlate(f.personalPreview,0,personalY,scale)
end

local function PreviewValue(value)
    local number = tonumber(value) or 0
    if number == math.floor(number) then return tostring(number) end
    return string.format("%.2f", number):gsub("0+$", ""):gsub("%.$", "")
end
local function AnimatePreviewPlayerCast(frame, elapsed)
    local p = frame and frame.targetPreview
    if not p or not CFG.targetPlayerCastOverlayEnabled then return end

    p.previewCastProgress = ((p.previewCastProgress or 0) + (tonumber(elapsed) or 0) / 2.5) % 1
    p.playerCastOverlay:SetValue(p.previewCastProgress)
    p.playerCastOverlay:Show()

    local width = math.max(1, p.playerCastOverlay:GetWidth() or tonumber(CFG.enemyPlateWidth) or 110)
    p.playerCastOverlaySpark:ClearAllPoints()
    p.playerCastOverlaySpark:SetPoint("CENTER", p.playerCastOverlay, "LEFT", width * p.previewCastProgress, 0)
end
function EnsureNameplatePreview()
    if State.nameplatePreviewFrame then return State.nameplatePreviewFrame end
    local gui=LibStub and LibStub("AceGUI-3.0",true)
    if not gui then return nil end
    local widget=gui:Create("S2KFrame")
    if not widget then return nil end
    widget:SetTitle(S2K_L("Nameplate layout preview"))
    widget:SetWidth(560)
    widget:SetHeight(640)
    widget:EnableResize(true)
    widget.frame:ClearAllPoints()
    widget.frame:SetPoint("CENTER",UIParent,"CENTER",0,40)
    widget.frame:SetClampedToScreen(true)

    local f=widget.frame
    local content=widget.content
    widget:SetHeaderButtons(true,false)
    widget:SetCallback("OnCloseButton",function()
        State.nameplatePreviewRequested=false
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
    f.targetPreview=NewPreviewPlate(f.canvas,"target")
    f.focusPreview=NewPreviewPlate(f.canvas,"focus")
    f.personalPreview=NewPreviewPlate(f.canvas,"personal")
    f.friendlyPreview=NewPreviewPlate(f.canvas,"friendly")
    f.enemyPreview=NewPreviewPlate(f.canvas,"enemy")
    f.previews={f.targetPreview,f.focusPreview,f.personalPreview,f.friendlyPreview,f.enemyPreview}
    f:SetScript("OnUpdate",AnimatePreviewPlayerCast)
    f:SetScript("OnSizeChanged",function() if UpdateNameplatePreview then UpdateNameplatePreview() end end)
    f:Hide()
    f.s2kPreviewWidget=widget
    State.nameplatePreviewWidget=widget
    State.nameplatePreviewFrame=f
    return f
end

function UpdateNameplatePreview()
    local f=State.nameplatePreviewFrame
    if not f or not f:IsShown() then return end

    local friendlyHW=math.max(1,tonumber(CFG.friendlyNameplateHitboxWidth) or 110)
    local friendlyHH=math.max(1,tonumber(CFG.friendlyNameplateHitboxHeight) or 45)
    local friendlyW=math.max(1,tonumber(CFG.friendlyPlateWidth) or 110)
    local friendlyH=math.max(1,tonumber(CFG.friendlyPlateHeight) or 12)
    local enemyHW=math.max(1,tonumber(CFG.enemyNameplateHitboxWidth) or 110)
    local enemyHH=math.max(1,tonumber(CFG.enemyNameplateHitboxHeight) or 45)
    local enemyW=math.max(1,tonumber(CFG.enemyPlateWidth) or 110)
    local enemyH=math.max(1,tonumber(CFG.enemyPlateHeight) or 12)
    local personalHW=math.max(1,tonumber(CFG.personalNameplateHitboxWidth) or 110)
    local personalHH=math.max(1,tonumber(CFG.personalNameplateHitboxHeight) or 45)
    local personalW=math.max(1,tonumber(CFG.personalPlateWidth) or 110)
    local personalH=math.max(1,tonumber(CFG.personalPlateHeight) or 12)
    f.info:SetText(string.format(
        "%s: %s %s x %s, %s %s x %s    %s: %s, %s\n%s: %s %s x %s, %s %s x %s    %s: %s, %s\n%s: %s %s x %s, %s %s x %s    %s: %s, %s\n%s: %s    %s: %s    %s: %s",
        S2K_L("Personal"),S2K_L("Healthbar"),PreviewValue(personalW),PreviewValue(personalH),S2K_L("Hitbox"),PreviewValue(personalHW),PreviewValue(personalHH),S2K_L("Health offset"),PreviewValue(CFG.personalHealthbarHitboxXOffset),PreviewValue(CFG.personalHealthbarHitboxYOffset),
        S2K_L("Friendly"),S2K_L("Healthbar"),PreviewValue(friendlyW),PreviewValue(friendlyH),S2K_L("Hitbox"),PreviewValue(friendlyHW),PreviewValue(friendlyHH),S2K_L("Health offset"),PreviewValue(CFG.friendlyHealthbarHitboxXOffset),PreviewValue(CFG.friendlyHealthbarHitboxYOffset),
        S2K_L("Enemy"),S2K_L("Healthbar"),PreviewValue(enemyW),PreviewValue(enemyH),S2K_L("Hitbox"),PreviewValue(enemyHW),PreviewValue(enemyHH),S2K_L("Health offset"),PreviewValue(CFG.enemyHealthbarHitboxXOffset),PreviewValue(CFG.enemyHealthbarHitboxYOffset),
        S2K_L("Motion mode"),S2K_L((NAMEPLATE_MOTION_OPTIONS[(tonumber(CFG.nameplateMotion) or 0)+1] or {}).label or "Overlapping / default"),S2K_L("Horizontal overlap"),PreviewValue(CFG.nameplateOverlapH),S2K_L("Vertical overlap"),PreviewValue(CFG.nameplateOverlapV)
    ))
    PositionPreviewPlates(f)
end

function SetNameplatePreviewShown(shown) State.nameplatePreviewRequested=shown and true or false; local f=EnsureNameplatePreview(); if not f then return end; if State.nameplatePreviewRequested and State.configFrame and State.configFrame:IsShown() then f:Show(); UpdateNameplatePreview() else f:Hide() end end
function RefreshNameplatePreviewVisibility() local show=State.nameplatePreviewRequested and State.configFrame and State.configFrame:IsShown(); if show then local f=EnsureNameplatePreview(); if not f then return end; f:Show(); UpdateNameplatePreview() elseif State.nameplatePreviewFrame then State.nameplatePreviewFrame:Hide() end end
function HideNameplatePreview() if State.nameplatePreviewFrame then State.nameplatePreviewFrame:Hide() end end
