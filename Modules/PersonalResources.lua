-- =========================================================
-- Addon-owned Personal Resource Display bars (Legion 7.3.5)
-- =========================================================

local function GetPersonalContext()
    for _, ctx in pairs(State.plates or {}) do
        if ctx and ctx.unit and GetNameplateDimensionGroup(ctx.unit) == "personal" then
            return ctx
        end
    end
end

local function EnsureManagedPersonalPowerBar(ctx)
    if not ctx or not ctx.root then return end
    if not ctx.s2kPersonalResourceBar then
        ctx.s2kPersonalResourceBar = CreatePersonalResourceStatusBar(ctx.root)
    end
    ctx.personalResourceBar = ctx.s2kPersonalResourceBar
    return ctx.s2kPersonalResourceBar
end

local function EnsureManagedPersonalClassResource(ctx)
    if not ctx or not ctx.root then return end
    if not ctx.s2kPersonalClassResource then
        ctx.s2kPersonalClassResource = CreatePersonalClassResourceFrame(ctx.root, 6)
    end
    ctx.personalClassResource = ctx.s2kPersonalClassResource
    return ctx.s2kPersonalClassResource
end

local CLASS_POWER_TYPES = {
    ROGUE = 4,
    DRUID = 4,
    WARLOCK = 7,
    PALADIN = 9,
    MONK = 12,
    MAGE = 16,
}

local function GetPersonalClassResourceValue()
    local _, class = UnitClass("player")
    if class == "DEATHKNIGHT" and GetRuneCooldown then
        local ready = 0
        for index = 1, 6 do
            local _, _, runeReady = GetRuneCooldown(index)
            if runeReady then ready = ready + 1 end
        end
        return ready, 6
    end
    local powerType = CLASS_POWER_TYPES[class]
    if not powerType then return 0, 0 end
    local maximum = tonumber(UnitPowerMax("player", powerType)) or 0
    local current = tonumber(UnitPower("player", powerType)) or 0
    return math.max(0, math.min(maximum, current)), math.max(0, maximum)
end

function RefreshPersonalResourcePowerValue(skipLayoutRefresh)
    if not CFG or CFG.enabled == false then return end
    local ctx = GetPersonalContext()
    local powerBar = EnsureManagedPersonalPowerBar(ctx)
    if not powerBar then
        if not skipLayoutRefresh and ApplyPersonalResourceDisplaySettings then
            ApplyPersonalResourceDisplaySettings()
        end
        return
    end
    local powerType = UnitPowerType and UnitPowerType("player")
    local maximum = UnitPowerMax and UnitPowerMax("player", powerType) or 0
    local current = UnitPower and UnitPower("player", powerType) or 0
    maximum = math.max(1, tonumber(maximum) or 1)
    current = math.max(0, math.min(maximum, tonumber(current) or 0))
    if powerBar.SetMinMaxValues then powerBar:SetMinMaxValues(0, maximum) end
    if powerBar.SetValue then powerBar:SetValue(current) end
    local wasShown = powerBar.IsShown and powerBar:IsShown()
    local shouldShow = CFG.personalResourceBarEnabled ~= false and current > 0
    if shouldShow then
        powerBar:Show()
    else
        powerBar:Hide()
    end
    if wasShown ~= shouldShow and not skipLayoutRefresh
    and RefreshPersonalResourceAuraAnchors then
        RefreshPersonalResourceAuraAnchors()
    end
end

function RefreshPersonalClassResourceValue(skipLayoutRefresh)
    if not CFG or CFG.enabled == false then return end
    local ctx = GetPersonalContext()
    local frame = EnsureManagedPersonalClassResource(ctx)
    if not frame then return end
    local current, maximum = GetPersonalClassResourceValue()
    frame.s2kResourceValue = current
    frame.s2kResourceMaximum = maximum
    for index, point in ipairs(frame.points or {}) do
        if index <= maximum then
            point:Show()
            if point.s2kManagedFill then
                if index <= current then point.s2kManagedFill:Show() else point.s2kManagedFill:Hide() end
            end
        else
            point:Hide()
        end
    end
    local wasShown = frame.IsShown and frame:IsShown()
    local shouldShow = CFG.personalClassResourceEnabled ~= false and maximum > 0 and current > 0
    if shouldShow then frame:Show() else frame:Hide() end
    if wasShown ~= shouldShow and not skipLayoutRefresh
    and RefreshPersonalResourceAuraAnchors then
        RefreshPersonalResourceAuraAnchors()
    end
end

local function ApplyResourceFrame(frame, enabled, width, height, x, y, anchor, side)
    if not frame or not anchor then return end
    if enabled == false then
        if frame.IsShown and frame:IsShown() then frame:Hide() end
        frame.s2kHiddenByPersonalResources = true
        return
    end

    frame.s2kHiddenByPersonalResources = nil
    -- Geometry is applied while visible; the power refresh makes the final
    -- visibility decision for the addon-owned Personal Resource Bar.
    if frame.Show and (not frame.IsShown or not frame:IsShown()) then frame:Show() end
    if frame.SetAlpha then frame:SetAlpha(1) end
    if frame.ClearAllPoints and frame.SetPoint then
        frame:ClearAllPoints()
        if side == "TOP" then
            frame:SetPoint("BOTTOM", anchor, "TOP", tonumber(x) or 0, tonumber(y) or 0)
        else
            frame:SetPoint("TOP", anchor, "BOTTOM", tonumber(x) or 0, tonumber(y) or 0)
        end
    end
    if frame.SetSize then
        frame:SetSize(math.max(1, tonumber(width) or 1), math.max(1, tonumber(height) or 1))
    end
end

local function ApplyManagedBackdrop(frame, textureKey, texturePath, colorPrefix)
    if not frame or not frame.CreateTexture then return end
    local background = frame.s2kManagedBackdrop
    if not background then
        background = frame:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(frame)
        frame.s2kManagedBackdrop = background
    end
    ApplyStatusBarBackdropTexture(background,
        GetConfiguredStatusBarTexturePath(textureKey, texturePath),
        GetCustomColor(colorPrefix, 0, 0, 0, .7))
end

local function ApplyPersonalPowerBarStyle(frame)
    if not frame then return end
    if frame.SetStatusBarTexture then
        ApplyStatusBarTexture(frame, GetConfiguredStatusBarTexturePath("personalResourceBarTextureKey", "personalResourceBarTexturePath"))
        frame:SetStatusBarColor(GetCustomColor("personalResourceBarColor", .15, .45, 1, 1))
    end
    ApplyManagedBackdrop(frame, "personalResourceBarBackdropTextureKey", "personalResourceBarBackdropTexturePath", "personalResourceBarBackdropColor")
    if not frame.s2kManagedBorder then
        frame.s2kManagedBorder = CreateBorder(frame)
        frame.s2kManagedBorder.s2kPersonalResourceDecoration = true
    end
    ApplyBorderVisual(frame.s2kManagedBorder,
        CFG.personalResourceBarBorderTextureKey,
        GetConfiguredBorderTexturePath("personalResourceBarBorderTextureKey", "personalResourceBarBorderTexturePath"),
        CFG.personalResourceBarBorderSize, CFG.personalResourceBarBorderInset, CFG.personalResourceBarBorderOffset,
        GetCustomColor("personalResourceBarBorderColor", 0, 0, 0, 1))
    if frame.s2kManagedBorder.SetFrameLevel and frame.GetFrameLevel then
        frame.s2kManagedBorder:SetFrameLevel((frame:GetFrameLevel() or 0)
            + (tonumber(CFG.personalResourceBarBorderFrameLevel) or 5))
    end
end

local function GetClassResourceSegments(frame)
    local segments = {}
    if frame and frame.points then
        for _, point in ipairs(frame.points) do
            segments[#segments + 1] = point
        end
    end
    return segments
end

local function ApplyClassSegmentStyle(segment)
    if not segment then return end
    if segment.SetStatusBarTexture then
        ApplyStatusBarTexture(segment, GetConfiguredStatusBarTexturePath("personalClassResourceTextureKey", "personalClassResourceTexturePath"))
        segment:SetStatusBarColor(GetCustomColor("personalClassResourceColor", 1, .72, .08, 1))
    elseif segment.CreateTexture then
        if not segment.s2kManagedFill then
            segment.s2kManagedFill = segment:CreateTexture(nil, "ARTWORK")
            segment.s2kManagedFill:SetAllPoints(segment)
        end
        ApplyTexturePath(segment.s2kManagedFill,
            GetConfiguredStatusBarTexturePath("personalClassResourceTextureKey", "personalClassResourceTexturePath"))
        segment.s2kManagedFill:SetVertexColor(GetCustomColor("personalClassResourceColor", 1, .72, .08, 1))
    end
    ApplyManagedBackdrop(segment, "personalClassResourceBackdropTextureKey", "personalClassResourceBackdropTexturePath", "personalClassResourceBackdropColor")
    if not segment.s2kManagedBorder then
        segment.s2kManagedBorder = CreateBorder(segment)
        segment.s2kManagedBorder.s2kPersonalResourceDecoration = true
    end
    if CFG.personalClassResourceBorderEnabled then
        ApplyBorderVisual(segment.s2kManagedBorder, "S2K_SOLID", "Interface\\Buttons\\WHITE8X8", 1, 0, 0,
            GetCustomColor("personalClassResourceBorderColor", 0, 0, 0, 1))
    else
        segment.s2kManagedBorder:Hide()
    end
end

local function ApplyPersonalClassResourceStyle(frame)
    if not frame then return end
    local segments = GetClassResourceSegments(frame)
    local count = math.max(0, math.min(#segments, tonumber(frame.s2kResourceMaximum) or 0))
    local width = math.max(1, tonumber(CFG.personalClassResourceWidth) or 110)
    local height = math.max(1, tonumber(CFG.personalClassResourceHeight) or 10)
    local spacing = math.max(0, tonumber(CFG.personalClassResourceSpacing) or 0)
    local segmentWidth = count > 0
        and math.max(1, (width - spacing * math.max(0, count - 1)) / count)
        or width

    for index, segment in ipairs(segments) do
        if index <= count and segment ~= frame and segment.ClearAllPoints and segment.SetPoint and segment.SetSize then
            segment:ClearAllPoints()
            segment:SetPoint("LEFT", frame, "LEFT", (index - 1) * (segmentWidth + spacing), 0)
            segment:SetSize(segmentWidth, height)
        end
        ApplyClassSegmentStyle(segment)
        if index > count then segment:Hide() end
    end
end

function RefreshPersonalResourceAuraAnchors()
    local ctx = GetPersonalContext()
    if not ctx then return end
    if RefreshCollapsibleNameplateLayout then RefreshCollapsibleNameplateLayout(ctx) end
end

function ApplyPersonalResourceDisplaySettings()
    State.pendingPersonalResourceApply = false

    local ctx = GetPersonalContext()
    local powerBar = EnsureManagedPersonalPowerBar(ctx)
    local classResource = EnsureManagedPersonalClassResource(ctx)
    local anchor = ctx and ctx.root
    if not anchor then return end

    if not CFG or CFG.enabled == false then
        if powerBar then powerBar:Hide() end
        if classResource then classResource:Hide() end
        return
    end

    if ctx then
        ctx.personalResourceBar = powerBar
        ctx.personalClassResource = classResource
    end

    ApplyResourceFrame(powerBar, CFG.personalResourceBarEnabled,
        CFG.personalResourceBarWidth, CFG.personalResourceBarHeight,
        CFG.personalResourceBarXOffset, ctx and GetEffectiveLayoutNodeOffset(ctx, "PERSONAL_RESOURCE") or CFG.personalResourceBarYOffset,
        ctx and ResolveLayoutNodeAnchor(ctx, "PERSONAL_RESOURCE") or anchor,
        ctx and GetLayoutNodeSide(ctx, "PERSONAL_RESOURCE") or CFG.personalResourceBarAnchorSide)
    if powerBar and powerBar.SetFrameStrata then
        local strata = tostring(CFG.personalResourceBarFrameStrata or "HIGH"):upper()
        if strata ~= "BACKGROUND" and strata ~= "LOW" and strata ~= "MEDIUM" and strata ~= "HIGH"
        and strata ~= "DIALOG" and strata ~= "FULLSCREEN" and strata ~= "FULLSCREEN_DIALOG"
        and strata ~= "TOOLTIP" then strata = "HIGH" end
        powerBar:SetFrameStrata(strata)
    end
    ApplyPersonalPowerBarStyle(powerBar)
    -- Apply geometry first; the current power value makes the final
    -- visibility decision so an empty bar remains collapsed.
    RefreshPersonalResourcePowerValue(true)
    ApplyResourceFrame(classResource, CFG.personalClassResourceEnabled,
        CFG.personalClassResourceWidth, CFG.personalClassResourceHeight,
        CFG.personalClassResourceXOffset, ctx and GetEffectiveLayoutNodeOffset(ctx, "PERSONAL_CLASS_RESOURCE") or CFG.personalClassResourceYOffset,
        ctx and ResolveLayoutNodeAnchor(ctx, "PERSONAL_CLASS_RESOURCE") or anchor,
        ctx and GetLayoutNodeSide(ctx, "PERSONAL_CLASS_RESOURCE") or CFG.personalClassResourceAnchorSide)
    RefreshPersonalClassResourceValue(true)
    ApplyPersonalClassResourceStyle(classResource)
    if ctx then
        if ctx.buffFrame then PositionAuraFrame(ctx, "BUFF") end
        if ctx.debuffFrame then PositionAuraFrame(ctx, "DEBUFF") end
    end
end
