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

    local useTarget = CFG.targetHealthbarOverride and IsTargetUnit(ctx.unit)
    local plateWidth = tonumber(CFG.plateWidth) or 110
    local plateHeight = tonumber(CFG.plateHeight) or 12
    local xOffset = tonumber(CFG.healthbarHitboxXOffset) or 0
    local yOffset = tonumber(CFG.healthbarHitboxYOffset) or 0

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

    if root.SetFrameLevel then
        local level = 0
        if plate and plate.GetFrameLevel then
            level = math.max(level, plate:GetFrameLevel() or 0)
        end
        if uf and uf.GetFrameLevel then
            level = math.max(level, uf:GetFrameLevel() or 0)
        end
        root:SetFrameLevel(level + 100)
    end
    SyncCustomFrameLevels(ctx)

    local textureKey, pathKey = 'borderTextureKey', 'borderTexturePath'
    local sizeKey, insetKey, offsetKey = 'borderSize', 'borderInset', 'borderOffset'
    local br, bg, bb, ba = GetAllBorderColor()

    -- Border visibility is controlled by the selected normal/target border media.
    -- Legacy style keys and healthBorder remain in SavedVariables for compatibility.
    if useTarget then
        textureKey, pathKey = 'targetBorderTextureKey', 'targetBorderTexturePath'
        sizeKey, insetKey, offsetKey = 'targetBorderSize', 'targetBorderInset', 'targetBorderOffset'
        br, bg, bb, ba = GetTargetBorderColor()
    end

    ApplyBorderVisual(ctx.border, CFG[textureKey], GetConfiguredBorderTexturePath(textureKey, pathKey), CFG[sizeKey], CFG[insetKey], CFG[offsetKey], br, bg, bb, ba)
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
end

function PositionCastbar(ctx)
    local cast = ctx.cast
    cast:ClearAllPoints()
    cast:SetPoint("TOPLEFT", ctx.root, "BOTTOMLEFT", 0, CFG.castbarYOffset or -2)
    cast:SetPoint("TOPRIGHT", ctx.root, "BOTTOMRIGHT", 0, CFG.castbarYOffset or -2)
    cast:SetHeight(CFG.castbarHeight or 6)

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

function ResolveAuraAnchor(ctx, kind)
    local anchorTo = kind == "BUFF" and CFG.buffAnchorTo or CFG.debuffAnchorTo

    -- Prevent self-anchor and simple mutual cycles.
    if kind == "BUFF" then
        if anchorTo == "BUFF" then anchorTo = "HEALTH" end
        if anchorTo == "DEBUFF" and CFG.debuffAnchorTo == "BUFF" then anchorTo = "HEALTH" end
    else
        if anchorTo == "DEBUFF" then anchorTo = "HEALTH" end
        if anchorTo == "BUFF" and CFG.buffAnchorTo == "DEBUFF" then anchorTo = "HEALTH" end
    end

    if anchorTo == "BUFF" then return ctx.buffFrame end
    if anchorTo == "DEBUFF" then return ctx.debuffFrame end
    return ctx.root
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
    local side = kind == "BUFF" and CFG.buffAnchorSide or CFG.debuffAnchorSide
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
