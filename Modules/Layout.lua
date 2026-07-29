-- =========================================================
-- Layout
-- =========================================================


function GetCustomPlateScale(ctx)
    local scale = tonumber(CFG.nameplateGlobalScale) or 1

    if ctx and IsTargetUnit(ctx.unit) then
        scale = scale * (tonumber(CFG.nameplateSelectedScale) or 1)
    end

    if scale < 0.10 then scale = 0.10 end
    if scale > 10.00 then scale = 10.00 end

    return scale
end

function GetFrameScaleRelativeToUI(frame)
    if not frame or not frame.GetEffectiveScale or not UIParent or not UIParent.GetEffectiveScale then
        return nil
    end

    local uiScale = tonumber(UIParent:GetEffectiveScale())
    local frameScale = tonumber(frame:GetEffectiveScale())

    if not uiScale or not frameScale or uiScale ~= uiScale or frameScale ~= frameScale or uiScale <= 0 or frameScale <= 0 then
        return nil
    end

    local inherited = frameScale / uiScale
    if inherited ~= inherited or inherited <= 0 then
        return nil
    end

    return inherited
end

function ApplyCustomPlateScale(ctx)
    if not ctx or not ctx.root or not ctx.root.SetScale then
        return
    end

    local desiredScale = GetCustomPlateScale(ctx)

    -- UIParent-parented roots do not inherit the Blizzard nameplate scale.
    -- Their local scale is therefore already the desired effective scale.
    if ctx.root.GetParent and ctx.root:GetParent() == UIParent then
        ctx.s2kLastSafeLocalScale = desiredScale
        ctx.root:SetScale(desiredScale)
        return
    end

    local inheritedScale = GetFrameScaleRelativeToUI(ctx.plate)
    local localScale = nil

    -- Blizzard can briefly report a very small/transitional effective scale
    -- while a plate becomes the current target. Dividing by that transient
    -- value produced a rare 10x custom target plate that remained until the
    -- next layout refresh. Accept only plausible compensation factors and keep
    -- the last stable local scale when the parent is in an animation state.
    if inheritedScale and inheritedScale >= 0.20 and inheritedScale <= 8.00 then
        local candidate = desiredScale / inheritedScale
        if candidate == candidate and candidate >= 0.20 and candidate <= 3.00 then
            localScale = candidate
            ctx.s2kLastSafeLocalScale = candidate
        end
    end

    if not localScale then
        localScale = tonumber(ctx.s2kLastSafeLocalScale) or 1.00
    end

    if localScale < 0.20 then localScale = 0.20 end
    if localScale > 3.00 then localScale = 3.00 end

    ctx.root:SetScale(localScale)
end

function RefreshVisibleNameplateScales()
    if not CFG or not CFG.enabled or not State or not State.plates then
        return
    end

    for unit, ctx in pairs(State.plates) do
        if ctx and ctx.unit and UnitExists(ctx.unit) and ctx.root and ctx.root:IsShown() then
            -- Re-anchor and rebuild the border after Blizzard's nameplate scale
            -- transition settles. On 7.3.5, refreshing only SetScale can leave
            -- backdrop edge pieces using their hidden/recycled dimensions.
            PositionRoot(ctx)
        end
    end
end

function ScheduleNameplateScaleStabilization()
    if not C_Timer or not C_Timer.After then
        RefreshVisibleNameplateScales()
        return
    end

    -- Coalesce bursts of NAME_PLATE_UNIT_ADDED/target events. The previous token
    -- implementation still created two timers per event even though stale timers
    -- did no useful work.
    if State.nameplateScaleRefreshPending then
        State.nameplateScaleRefreshAgain = true
        return
    end

    State.nameplateScaleRefreshPending = true
    C_Timer.After(0.05, RefreshVisibleNameplateScales)
    C_Timer.After(0.20, function()
        RefreshVisibleNameplateScales()
        State.nameplateScaleRefreshPending = nil
        if State.nameplateScaleRefreshAgain then
            State.nameplateScaleRefreshAgain = nil
            ScheduleNameplateScaleStabilization()
        end
    end)
end

function PositionRoot(ctx)
    local root = ctx.root
    local plate = ctx.plate
    local uf = GetUnitFrameFromPlate(plate)
    local blizzHB = uf and GetHealthBarFromUF(uf)

    local plateWidth = tonumber(GetNameplateDimensionValue(ctx, "PlateWidth", 110)) or 110
    local plateHeight = tonumber(GetNameplateDimensionValue(ctx, "PlateHeight", 12)) or 12
    local xOffset = tonumber(GetNameplateDimensionValue(ctx, "HealthbarHitboxXOffset", 0)) or 0
    local yOffset = tonumber(GetNameplateDimensionValue(ctx, "HealthbarHitboxYOffset", 0)) or 0

    root:ClearAllPoints()
    if plate and plate.GetObjectType then
        root:SetPoint("CENTER", plate, "CENTER", xOffset, yOffset)
    elseif blizzHB and blizzHB.GetObjectType then
        root:SetPoint("CENTER", blizzHB, "CENTER", xOffset, yOffset)
    end

    root:SetSize(plateWidth, plateHeight)
    ApplyStatusBarTexture(ctx.health, GetHealthTexturePath(ctx))
    ApplyCustomPlateScale(ctx)
    SyncCustomFrameStrata(ctx)

    SyncCustomFrameLevels(ctx)

    local group = GetNameplateDesignGroup(ctx.unit)
    local textureKey, pathKey = group .. "BorderTextureKey", group .. "BorderTexturePath"
    local br, bg, bb, ba = GetCurrentNameplateBorderColor(ctx)
    ApplyBorderVisual(ctx.border, CFG[textureKey], GetConfiguredBorderTexturePath(textureKey, pathKey), CFG[group .. "BorderSize"], CFG[group .. "BorderInset"], CFG[group .. "BorderOffset"], br, bg, bb, ba)
    ApplyStatusBarBackdropTexture(ctx.background, GetHealthBackdropTexturePath(ctx), GetHealthBackdropColor(ctx))
end

function ApplyCastbarBorderVisual(ctx)
    if not ctx or not ctx.castBorder then
        return
    end

    if not CFG.castbarBorder then
        ctx.castBorder:Hide()
        return
    end

    local r, g, b, a = GetCastbarBorderColor()
    ApplyBorderVisual(ctx.castBorder, CFG.castbarBorderTextureKey, GetConfiguredBorderTexturePath('castbarBorderTextureKey', 'castbarBorderTexturePath'), CFG.castbarBorderSize, CFG.castbarBorderInset, CFG.castbarBorderOffset, r, g, b, a)
    local base = ctx.root and ctx.root.GetFrameLevel and ctx.root:GetFrameLevel() or 0
    if ctx.castBorder.SetFrameLevel then
        ctx.castBorder:SetFrameLevel(base + (tonumber(CFG.castbarBorderFrameLevel) or 5))
    end
end

local function GetLayoutGroup(ctx)
    if ctx and ctx.designGroup then return ctx.designGroup end
    return GetNameplateDesignGroup(ctx and ctx.unit)
end

function GetLayoutNodeParent(ctx, node)
    local group = GetLayoutGroup(ctx)
    if node == "CAST" then return CFG[group .. "CastbarAnchorTo"] or "HEALTH" end
    if node == "BUFF" then return CFG[group .. "BuffAnchorTo"] or CFG.buffAnchorTo or "HEALTH" end
    if node == "DEBUFF" then return CFG[group .. "DebuffAnchorTo"] or CFG.debuffAnchorTo or "HEALTH" end
    if node == "PERSONAL_RESOURCE" then return CFG.personalResourceBarAnchorTo or "HEALTH" end
    if node == "PERSONAL_CLASS_RESOURCE" then return CFG.personalClassResourceAnchorTo or "HEALTH" end
    return "HEALTH"
end

function GetLayoutNodeSide(ctx, node)
    local group = GetLayoutGroup(ctx)
    local side
    if node == "CAST" then side = CFG[group .. "CastbarAnchorSide"] or "BOTTOM"
    elseif node == "BUFF" then side = CFG[group .. "BuffAnchorSide"] or CFG.buffAnchorSide or "TOP"
    elseif node == "DEBUFF" then side = CFG[group .. "DebuffAnchorSide"] or CFG.debuffAnchorSide or "TOP"
    elseif node == "PERSONAL_RESOURCE" then side = CFG.personalResourceBarAnchorSide or "BOTTOM"
    elseif node == "PERSONAL_CLASS_RESOURCE" then side = CFG.personalClassResourceAnchorSide or "BOTTOM"
    end
    local parent = GetLayoutNodeParent(ctx, node)
    if parent ~= "HEALTH" and side ~= "TOP" and side ~= "BOTTOM" then side = "TOP" end
    return side or "TOP"
end

function GetLayoutNodeOffset(node)
    if node == "CAST" then return tonumber(CFG.castbarYOffset) or -2 end
    if node == "BUFF" then return tonumber(CFG.buffYOffset) or 0 end
    if node == "DEBUFF" then return tonumber(CFG.debuffYOffset) or 0 end
    if node == "PERSONAL_RESOURCE" then return tonumber(CFG.personalResourceBarYOffset) or 0 end
    if node == "PERSONAL_CLASS_RESOURCE" then return tonumber(CFG.personalClassResourceYOffset) or 0 end
    return 0
end

function GetEffectiveLayoutNodeOffset(ctx, node)
    local offset = GetLayoutNodeOffset(node)
    if GetLayoutNodeSide(ctx, node) == "TOP"
    and (node == "CAST" or node == "PERSONAL_RESOURCE" or node == "PERSONAL_CLASS_RESOURCE") then
        return -offset
    end
    return offset
end

function GetLayoutNodeFrame(ctx, node)
    if node == "HEALTH" then return ctx and ctx.root end
    if node == "CAST" then return ctx and ctx.cast end
    if node == "BUFF" then return ctx and ctx.buffFrame end
    if node == "DEBUFF" then return ctx and ctx.debuffFrame end
    if node == "PERSONAL_RESOURCE" then return ctx and ctx.personalResourceBar end
    if node == "PERSONAL_CLASS_RESOURCE" then return ctx and ctx.personalClassResource end
end

local function IsLayoutNodeVisible(ctx, node)
    local frame = GetLayoutNodeFrame(ctx, node)
    return frame and frame.IsShown and frame:IsShown()
end

local function GetSafeLayoutParent(ctx, node)
    local parent = GetLayoutNodeParent(ctx, node)
    local seen = {[node]=true}
    local cursor = parent
    while cursor and cursor ~= "HEALTH" do
        if seen[cursor] then return "HEALTH" end
        seen[cursor] = true
        cursor = GetLayoutNodeParent(ctx, cursor)
    end
    return parent
end

local function AnchorCollapsedNode(ctx, node, anchor)
    local side, offset = GetLayoutNodeSide(ctx, node), GetEffectiveLayoutNodeOffset(ctx, node)
    local holder = GetProgressBarFallbackAnchor(ctx, node, side)
    holder:ClearAllPoints()
    if side == "BOTTOM" then holder:SetPoint("CENTER", anchor, "BOTTOM", 0, offset)
    elseif side == "LEFT" then holder:SetPoint("CENTER", anchor, "LEFT", offset, 0)
    elseif side == "RIGHT" then holder:SetPoint("CENTER", anchor, "RIGHT", offset, 0)
    else holder:SetPoint("CENTER", anchor, "TOP", 0, offset) end
    return holder
end

function ResolveLayoutNodeAnchor(ctx, node, resolving)
    if node == "HEALTH" then return ctx.root end
    resolving = resolving or {}
    if resolving[node] then return ctx.root end
    resolving[node] = true
    local parent = GetSafeLayoutParent(ctx, node)
    local parentAnchor
    if parent == "HEALTH" then
        parentAnchor = ctx.root
    elseif IsLayoutNodeVisible(ctx, parent) then
        parentAnchor = GetLayoutNodeFrame(ctx, parent)
    else
        local ancestor = ResolveLayoutNodeAnchor(ctx, parent, resolving)
        parentAnchor = AnchorCollapsedNode(ctx, parent, ancestor)
    end
    resolving[node] = nil
    return parentAnchor
end

local function AnchorBarFrame(frame, anchor, side, offset, xOffset)
    frame:ClearAllPoints()
    xOffset = tonumber(xOffset) or 0
    if side == "TOP" then frame:SetPoint("BOTTOM", anchor, "TOP", xOffset, offset)
    else frame:SetPoint("TOP", anchor, "BOTTOM", xOffset, offset) end
end

function PositionCastbar(ctx)
    local cast = ctx.cast
    local side = GetLayoutNodeSide(ctx, "CAST")
    local offset = GetEffectiveLayoutNodeOffset(ctx, "CAST")
    local anchor = ResolveLayoutNodeAnchor(ctx, "CAST")
    AnchorBarFrame(cast, anchor, side, offset, CFG.castbarXOffset)
    local healthWidth = ctx.health and ctx.health.GetWidth and ctx.health:GetWidth()
        or ctx.root and ctx.root.GetWidth and ctx.root:GetWidth()
        or 1
    local castWidth = CFG.castbarCustomWidthEnabled
        and tonumber(CFG.castbarWidth)
        or healthWidth
    cast:SetWidth(math.max(1, castWidth or healthWidth))
    cast:SetHeight(CFG.castbarHeight or 6)
    if cast.SetFrameStrata then
        local strata = tostring(CFG.castbarFrameStrata or "HIGH"):upper()
        if strata ~= "BACKGROUND" and strata ~= "LOW" and strata ~= "MEDIUM" and strata ~= "HIGH"
        and strata ~= "DIALOG" and strata ~= "FULLSCREEN" and strata ~= "FULLSCREEN_DIALOG"
        and strata ~= "TOOLTIP" then strata = "HIGH" end
        cast:SetFrameStrata(strata)
    end

    ApplyCastbarBorderVisual(ctx)

    if ctx.castText then
        ctx.castText:ClearAllPoints()
        ctx.castText:SetPoint("CENTER", cast, "CENTER", 0, 0)
    end

    local iconFrame = ctx.castIconFrame
    if iconFrame then
        iconFrame:ClearAllPoints()
        iconFrame:SetSize(CFG.castbarIconSize or 18, CFG.castbarIconSize or 18)
        iconFrame:SetPoint("RIGHT", cast, "LEFT", -(CFG.castbarIconGap or 2), 0)
    end
end

function GetPlayerCastOverlayContentInset(ctx)
    local inset = math.max(0, tonumber(CFG.playerCastOverlayInset) or 0)
    local root = ctx and ctx.root
    local width = root and root.GetWidth and root:GetWidth() or 0
    local height = root and root.GetHeight and root:GetHeight() or 0
    local halfSmallest = math.min(width or 0, height or 0) / 2
    if halfSmallest > 0 then inset = math.min(inset, math.max(0, halfSmallest - .5)) end
    return inset
end

function PositionPlayerCastOverlay(ctx)
    local bar, root = ctx and ctx.playerCastOverlay, ctx and ctx.root
    if not bar or not root then return 0 end
    local margin = GetPlayerCastOverlayContentInset(ctx)
    if bar.s2kContentInset ~= margin or bar.s2kAnchorRoot ~= root then
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", root, "TOPLEFT", margin, -margin)
        bar:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -margin, margin)
        bar.s2kContentInset = margin
        bar.s2kAnchorRoot = root
    end
    return margin
end

function GetConfiguredAuraAnchorTarget(ctx, kind)
    return GetLayoutNodeParent(ctx, kind)
end

function GetProgressBarFallbackAnchor(ctx, key, side)
    if not ctx or not ctx.root then return ctx and ctx.root end
    ctx.s2kProgressBarFallbacks = ctx.s2kProgressBarFallbacks or {}
    local anchor = ctx.s2kProgressBarFallbacks[key]
    if not anchor then
        anchor = CreateFrame("Frame", nil, ctx.root)
        anchor:SetSize(1, 1)
        ctx.s2kProgressBarFallbacks[key] = anchor
    end
    anchor:ClearAllPoints()
    if side == "TOP" then anchor:SetPoint("CENTER", ctx.root, "TOP", 0, 0)
    else anchor:SetPoint("CENTER", ctx.root, "BOTTOM", 0, 0) end
    return anchor
end

function ResolveAuraAnchor(ctx, kind)
    return ResolveLayoutNodeAnchor(ctx, kind)
end

function GetAuraLayoutSettings(kind)
    local w = kind == "BUFF" and CFG.buffIconWidth or CFG.debuffIconWidth
    local h = kind == "BUFF" and CFG.buffIconHeight or CFG.debuffIconHeight
    local spacing = kind == "BUFF" and CFG.buffIconSpacing or CFG.debuffIconSpacing
    local maxIcons = kind == "BUFF" and CFG.buffMaxIcons or CFG.debuffMaxIcons
    local iconsPerLine = kind == "BUFF" and CFG.buffIconsPerLine or CFG.debuffIconsPerLine
    local growth = kind == "BUFF" and CFG.buffGrowth or CFG.debuffGrowth
    local wrapDirection = kind == "BUFF" and CFG.buffWrapDirection or CFG.debuffWrapDirection

    w = tonumber(w) or 18
    h = tonumber(h) or 18
    spacing = tonumber(spacing) or 2
    maxIcons = math.max(1, tonumber(maxIcons) or 8)
    iconsPerLine = math.max(1, tonumber(iconsPerLine) or maxIcons)
    iconsPerLine = math.min(iconsPerLine, maxIcons)
    growth = tostring(growth or "CENTER_HORIZONTAL")
    wrapDirection = tostring(wrapDirection or "UP")

    return w, h, spacing, maxIcons, iconsPerLine, growth, wrapDirection
end

function IsHorizontalAuraGrowth(growth)
    return growth == "RIGHT" or growth == "LEFT" or growth == "CENTER_HORIZONTAL" or growth == "CENTER_OUT"
end

function GetAuraGridSize(kind, count)
    local w, h, spacing, maxIcons, iconsPerLine, growth = GetAuraLayoutSettings(kind)
    count = math.max(0, tonumber(count) or 0)

    if count <= 0 then
        return w, h, 0, 0, w, h
    end

    count = math.min(count, maxIcons)
    iconsPerLine = math.max(1, math.min(iconsPerLine, count))

    local lines = math.ceil(count / iconsPerLine)
    local horizontal = IsHorizontalAuraGrowth(growth)

    local frameW, frameH
    if horizontal then
        local itemsInWidestRow = math.min(iconsPerLine, count)
        frameW = itemsInWidestRow * w + math.max(0, itemsInWidestRow - 1) * spacing
        frameH = lines * h + math.max(0, lines - 1) * spacing
    else
        local itemsInTallestColumn = math.min(iconsPerLine, count)
        frameW = lines * w + math.max(0, lines - 1) * spacing
        frameH = itemsInTallestColumn * h + math.max(0, itemsInTallestColumn - 1) * spacing
    end

    return frameW, frameH, lines, iconsPerLine, w, h
end

function PositionAuraFrame(ctx, kind, count)
    local frame = kind == "BUFF" and ctx.buffFrame or ctx.debuffFrame
    local anchor = ResolveAuraAnchor(ctx, kind)
    local side = GetLayoutNodeSide(ctx, kind)
    local offset = kind == "BUFF" and CFG.buffYOffset or CFG.debuffYOffset
    local frameW, frameH = GetAuraGridSize(kind, count or 0)

    offset = tonumber(offset) or 0
    side = tostring(side or "TOP")

    frame:ClearAllPoints()
    frame:SetSize(math.max(1, frameW), math.max(1, frameH))

    if side == "BOTTOM" then
        frame:SetPoint("TOP", anchor, "BOTTOM", 0, offset)
    elseif side == "LEFT" then
        frame:SetPoint("RIGHT", anchor, "LEFT", offset, 0)
    elseif side == "RIGHT" then
        frame:SetPoint("LEFT", anchor, "RIGHT", offset, 0)
    else
        frame:SetPoint("BOTTOM", anchor, "TOP", 0, offset)
    end
end

function RefreshCollapsibleNameplateLayout(ctx)
    if not ctx or ctx.s2kRefreshingCollapsibleLayout then return end
    ctx.s2kRefreshingCollapsibleLayout = true
    PositionCastbar(ctx)
    if GetNameplateDimensionGroup(ctx.unit) == "personal" and ApplyPersonalResourceDisplaySettings then
        ApplyPersonalResourceDisplaySettings()
    end
    if ctx.buffFrame then PositionAuraFrame(ctx, "BUFF") end
    if ctx.debuffFrame then PositionAuraFrame(ctx, "DEBUFF") end
    ctx.s2kRefreshingCollapsibleLayout = nil
end

function LayoutAll(ctx)
    PositionRoot(ctx)
    PositionCastbar(ctx)
    if State.runtimeFlags and State.runtimeFlags.debuffs then
        PositionAuraFrame(ctx, "DEBUFF")
    end
    if State.runtimeFlags and State.runtimeFlags.buffs then
        PositionAuraFrame(ctx, "BUFF")
    end
end
