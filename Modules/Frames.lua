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

    -- Healthbar border must be above the StatusBar texture, but below all
    -- text/aura layers. If the border is above the ratio text it can draw a
    -- black line through the HP ratio on 7.3.5/private-server clients.
    if ctx.border and ctx.border.SetFrameLevel then
        ctx.border:SetFrameLevel(base + 25)
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

function CreateNameplateContext(unit, plate)
    local ctx = {
        unit = unit,
        plate = plate,
    }

    local plateName = plate and plate.GetName and plate:GetName()
    local rootName = plateName and (plateName .. "S2KRoot") or nil
    local healthName = plateName and (plateName .. "S2KHealthBar") or nil
    local castName = plateName and (plateName .. "S2KCastBar") or nil

    -- Keep the visual root under UIParent so its configured frame strata is not
    -- clamped by the Blizzard nameplate parent. PositionRoot still anchors it
    -- to the recycled Blizzard healthbar/nameplate.
    local root = CreateFrame("Frame", rootName, UIParent)
    root:SetFrameStrata(GetNameplateFrameStrata(ctx))
    root:SetFrameLevel((plate.GetFrameLevel and plate:GetFrameLevel() or 0) + 100)
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
