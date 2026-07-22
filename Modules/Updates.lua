-- =========================================================
-- Updates
-- =========================================================

function UpdateHealth(ctx)
    local unit = ctx.unit
    if not unit or not UnitExists(unit) then return end

    local maxHP = UnitHealthMax(unit) or 1
    local hp = UnitHealth(unit) or 0
    if maxHP <= 0 then maxHP = 1 end

    -- perf2b: keep perf1 cast/runtime behavior, but avoid pushing identical
    -- health values/colors into the StatusBar on every throttled target tick.
    -- UNIT_HEALTH still updates immediately; this only skips redundant Set* calls.
    if ctx.s2kLastHealthMax ~= maxHP then
        ctx.health:SetMinMaxValues(0, maxHP)
        ctx.s2kLastHealthMax = maxHP
    end

    if ctx.s2kLastHealthValue ~= hp then
        ctx.health:SetValue(hp)
        ctx.s2kLastHealthValue = hp
    end

    local r, g, b, a = GetHealthbarColor(unit)
    if ctx.s2kLastHealthR ~= r
    or ctx.s2kLastHealthG ~= g
    or ctx.s2kLastHealthB ~= b
    or ctx.s2kLastHealthA ~= a
    then
        ctx.health:SetStatusBarColor(r, g, b, a)
        ctx.s2kLastHealthR = r
        ctx.s2kLastHealthG = g
        ctx.s2kLastHealthB = b
        ctx.s2kLastHealthA = a
    end
end

function UpdateName(ctx)
    if not (State.runtimeFlags and State.runtimeFlags.names) then
        ctx.name:SetText("")
        ctx.name:Hide()
        return
    end

    ApplyFontStringFont(ctx.name, CFG.nameFontKey, CFG.nameFontSize, CFG.nameFontOutlineKey, CFG.nameFontPath)
    if ctx.nameLayer and ctx.nameLayer.SetFrameLevel and ctx.root and ctx.root.GetFrameLevel then
        ctx.nameLayer:SetFrameLevel((ctx.root:GetFrameLevel() or 0) + (tonumber(CFG.nameOverlayFrameLevel) or 36))
        ctx.nameLayer:Show()
    end
    if ctx.name.SetDrawLayer then
        ctx.name:SetDrawLayer("OVERLAY", 7)
    end
    ctx.name:ClearAllPoints()
    ctx.name:SetPoint("BOTTOM", ctx.root, "TOP", 0, CFG.nameYOffset or 4)
    ctx.name:SetText(UnitName(ctx.unit) or "")
    ctx.name:Show()
end

function FormatHPRatioNumber(value)
    value = tonumber(value) or 0
    if value < 0 then value = 0 end

    if value < 1000 then
        local text = string.format('%.1f', value)
        return text:gsub('%.0$', '')
    end

    local divisor = 1000
    local suffix = "K"
    if value >= 1000000 then
        divisor = 1000000
        suffix = "M"
    end

    local shortValue = value / divisor
    local text = string.format("%.1f", shortValue)
    text = text:gsub("%.0$", "")
    return text .. suffix
end

function UpdateHPRatio(ctx)
    local text = ctx.ratio
    if not (State.runtimeFlags and State.runtimeFlags.hpRatio) then
        text:SetText("")
        text:Hide()
        return
    end

    -- Draw the ratio on the custom nameplate whenever the nameplate unit exists
    -- and has max HP. Do NOT gate this by UnitIsVisible / line-of-sight; on this
    -- 7.3.5 private-server environment that check is unreliable and caused the
    -- ratio to appear mostly on non-LOS nameplates.
    if not ctx.root or not ctx.root:IsShown() or not ctx.unit or not UnitExists(ctx.unit) then
        text:SetText("")
        text:Hide()
        return
    end

    ApplyFontStringFont(text, CFG.hpRatioFontKey, CFG.hpRatioFontSize, CFG.hpRatioFontOutlineKey, CFG.hpRatioFontPath)
    text:SetTextColor(GetHPRatioColor())
    if ctx.ratioLayer and ctx.ratioLayer.SetFrameLevel and ctx.root and ctx.root.GetFrameLevel then
        ctx.ratioLayer:SetFrameLevel((ctx.root:GetFrameLevel() or 0) + (tonumber(CFG.hpRatioFrameLevel) or 60))
        ctx.ratioLayer:Show()
    end
    if text.SetDrawLayer then
        text:SetDrawLayer("OVERLAY", 7)
    end
    text:ClearAllPoints()
    text:SetPoint("CENTER", ctx.ratioLayer or ctx.root, "CENTER", 0, CFG.hpRatioYOffset or 0)

    local playerMax = tonumber(UnitHealthMax("player") or 0) or 0
    local unitMax = tonumber(UnitHealthMax(ctx.unit) or 0) or 0

    if playerMax <= 0 or unitMax <= 0 then
        text:SetText("")
        text:Hide()
        return
    end

    if CFG.hpRatioOnlyGreaterThanPlayer and unitMax <= playerMax then
        text:SetText("")
        text:Hide()
        return
    end

    text:SetText(FormatHPRatioNumber(unitMax / playerMax))
    text:Show()
end

function ApplyLevelOverlayAnchor(text, anchor, xOffset, yOffset)
    if not text or not anchor then return end

    local align = tostring(CFG.levelOverlayAlign or "CENTER")
    if text.SetWidth then text:SetWidth(80) end
    text:ClearAllPoints()

    if align == "LEFT_TO_RIGHT" then
        text:SetJustifyH("LEFT")
        text:SetPoint("LEFT", anchor, "CENTER", xOffset or 0, yOffset or 0)
    elseif align == "RIGHT_TO_LEFT" then
        text:SetJustifyH("RIGHT")
        text:SetPoint("RIGHT", anchor, "CENTER", xOffset or 0, yOffset or 0)
    else
        text:SetJustifyH("CENTER")
        text:SetPoint("CENTER", anchor, "CENTER", xOffset or 0, yOffset or 0)
    end
end

function UpdateUnitLevelOverlay(ctx)
    local text = ctx and ctx.levelText
    if not text then return end

    if not (State.runtimeFlags and State.runtimeFlags.levelOverlay) or not ctx.root or not ctx.root:IsShown() or not ctx.unit or not UnitExists(ctx.unit) then
        text:SetText("")
        text:Hide()
        return
    end

    local level = UnitLevel(ctx.unit)
    if not level or level == 0 then
        text:SetText("")
        text:Hide()
        return
    end

    if level < 0 then
        level = "??"
    else
        level = tostring(level)
    end

    ApplyFontStringFont(text, CFG.levelOverlayFontKey, CFG.levelOverlayFontSize, CFG.levelOverlayFontOutlineKey, CFG.levelOverlayFontPath)
    text:SetTextColor(GetLevelOverlayColor())
    if ctx.levelLayer and ctx.levelLayer.SetFrameLevel and ctx.root and ctx.root.GetFrameLevel then
        ctx.levelLayer:SetFrameLevel((ctx.root:GetFrameLevel() or 0) + (tonumber(CFG.levelOverlayFrameLevel) or 45))
        ctx.levelLayer:Show()
    end
    if text.SetDrawLayer then text:SetDrawLayer("OVERLAY", 7) end
    ApplyLevelOverlayAnchor(text, ctx.levelLayer or ctx.root, CFG.levelOverlayXOffset or 0, CFG.levelOverlayYOffset or 16)
    text:SetText(level)
    text:Show()
end

function UpdateHPThresholdMarker(ctx)
    local marker = ctx and ctx.hpMarker
    if not marker then return end

    if not (State.runtimeFlags and State.runtimeFlags.hpMarker) or not ctx.root or not ctx.root:IsShown() or not ctx.unit or not UnitExists(ctx.unit) then
        marker:Hide()
        marker.s2kMarkerPointMode = nil
        return
    end

    if CFG.hpMarkerOnlyTarget and not IsTargetUnit(ctx.unit) then
        marker:Hide()
        marker.s2kMarkerPointMode = nil
        return
    end

    local unitMax = tonumber(UnitHealthMax(ctx.unit) or 0) or 0
    if unitMax <= 0 then
        marker:Hide()
        marker.s2kMarkerPointMode = nil
        return
    end

    local pct = tonumber(CFG.hpMarkerPercent) or 35
    if pct < 0 then pct = 0 end
    if pct > 100 then pct = 100 end

    local anchor = ctx.health or ctx.root
    local rootW = (anchor.GetWidth and anchor:GetWidth()) or tonumber(CFG.plateWidth) or 110
    if rootW <= 0 then rootW = tonumber(CFG.plateWidth) or 110 end

    local mode = tostring(CFG.hpMarkerWidthMode or "LINE")
    local p = rootW * (pct / 100)
    local width = math.max(1, tonumber(CFG.hpMarkerWidth) or 2)
    local x = nil
    local pointMode = mode

    if mode == "LEFT_TO_ZERO" then
        width = math.max(1, p)
        x = 0
    elseif mode == "RIGHT_TO_END" then
        width = math.max(1, rootW - p)
        x = p
    else
        pointMode = "LINE"
        x = p - (rootW / 2)
    end

    -- Layout cache: UpdateContext can call this repeatedly with unchanged
    -- settings. Avoid ClearAllPoints/SetPoint/SetWidth churn unless something
    -- really changed.
    local frameLevel = (ctx.root.GetFrameLevel and ((ctx.root:GetFrameLevel() or 0) + (tonumber(CFG.hpMarkerFrameLevel) or 30))) or nil
    if marker.s2kMarkerPointMode ~= pointMode
    or marker.s2kMarkerRootWidth ~= rootW
    or marker.s2kMarkerPercent ~= pct
    or marker.s2kMarkerWidth ~= width
    or marker.s2kMarkerX ~= x
    or marker.s2kMarkerFrameLevel ~= frameLevel
    then
        marker:ClearAllPoints()
        if marker.SetWidth then
            marker:SetWidth(width)
        else
            marker:SetSize(width, math.max(1, tonumber(CFG.plateHeight) or 12))
        end

        if pointMode == "LEFT_TO_ZERO" then
            marker:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
            marker:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
        elseif pointMode == "RIGHT_TO_END" then
            marker:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, 0)
            marker:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", x, 0)
        else
            marker:SetPoint("TOP", anchor, "TOP", x, 0)
            marker:SetPoint("BOTTOM", anchor, "BOTTOM", x, 0)
        end

        if frameLevel and marker.SetFrameLevel then
            marker:SetFrameLevel(frameLevel)
        end
        marker.s2kMarkerPointMode = pointMode
        marker.s2kMarkerRootWidth = rootW
        marker.s2kMarkerPercent = pct
        marker.s2kMarkerWidth = width
        marker.s2kMarkerX = x
        marker.s2kMarkerFrameLevel = frameLevel
    end

    if marker.texture then
        local r, g, b, a = GetHPMarkerEffectiveColor(ctx)
        if marker.s2kMarkerR ~= r or marker.s2kMarkerG ~= g or marker.s2kMarkerB ~= b or marker.s2kMarkerA ~= a then
            marker.texture:SetColorTexture(r, g, b, a)
            marker.s2kMarkerR, marker.s2kMarkerG, marker.s2kMarkerB, marker.s2kMarkerA = r, g, b, a
        end
    end

    marker:Show()
end


-- =========================================================
-- Text object recreation / hard font refresh
-- =========================================================

function CreateNameFontString(ctx)
    if not ctx or not ctx.nameLayer or not ctx.root then return nil end

    if ctx.name then
        ctx.name:SetText("")
        ctx.name:Hide()
    end

    local name = ctx.nameLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if name.SetDrawLayer then name:SetDrawLayer("OVERLAY", 7) end
    name:SetPoint("BOTTOM", ctx.root, "TOP", 0, CFG.nameYOffset or 4)
    name:SetJustifyH("CENTER")
    name:SetJustifyV("MIDDLE")
    name:SetTextColor(1, 1, 1, 1)
    name:SetShadowColor(0, 0, 0, 1)
    name:SetShadowOffset(1, -1)
    ApplyFontStringFont(name, CFG.nameFontKey, CFG.nameFontSize, CFG.nameFontOutlineKey, CFG.nameFontPath)

    ctx.name = name
    return name
end

function CreateRatioFontString(ctx)
    if not ctx or not ctx.root then return nil end

    local layer = ctx.ratioLayer or ctx.root

    if ctx.ratio then
        ctx.ratio:SetText("")
        ctx.ratio:Hide()
    end

    local ratio = layer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if ratio.SetDrawLayer then ratio:SetDrawLayer("OVERLAY", 7) end
    ratio:SetPoint("CENTER", layer, "CENTER", 0, CFG.hpRatioYOffset or 0)
    ratio:SetJustifyH("CENTER")
    ratio:SetJustifyV("MIDDLE")
    ratio:SetTextColor(1, 1, 1, 1)
    ratio:SetShadowColor(0, 0, 0, 1)
    ratio:SetShadowOffset(1, -1)
    ApplyFontStringFont(ratio, CFG.hpRatioFontKey, CFG.hpRatioFontSize, CFG.hpRatioFontOutlineKey, CFG.hpRatioFontPath)

    ctx.ratio = ratio
    return ratio
end

function CreateLevelFontString(ctx)
    if not ctx or not ctx.root then return nil end

    local layer = ctx.levelLayer or ctx.root

    if ctx.levelText then
        ctx.levelText:SetText("")
        ctx.levelText:Hide()
    end

    local levelText = layer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if levelText.SetDrawLayer then levelText:SetDrawLayer("OVERLAY", 7) end
    levelText:SetPoint("CENTER", layer, "CENTER", CFG.levelOverlayXOffset or 0, CFG.levelOverlayYOffset or 16)
    levelText:SetJustifyH("CENTER")
    levelText:SetJustifyV("MIDDLE")
    levelText:SetTextColor(GetLevelOverlayColor())
    levelText:SetShadowColor(0, 0, 0, 1)
    levelText:SetShadowOffset(1, -1)
    ApplyFontStringFont(levelText, CFG.levelOverlayFontKey, CFG.levelOverlayFontSize, CFG.levelOverlayFontOutlineKey, CFG.levelOverlayFontPath)

    ctx.levelText = levelText
    return levelText
end

function RecreateVisibleTextObjects()
    -- Some 7.3.5/private clients do not visually update certain LibSharedMedia
    -- fonts on already-created FontStrings until the nameplate is recycled.
    -- Force a true refresh by replacing our own FontStrings; this does not touch
    -- Blizzard FontStrings, only the custom s2k layers.
    for unit, ctx in pairs(State.plates) do
        if ctx and ctx.unit and UnitExists(ctx.unit) and ctx.root and ctx.root:IsShown() then
            CreateRatioFontString(ctx)
            CreateNameFontString(ctx)
            CreateLevelFontString(ctx)
        end
    end
end

function AuraPassesFilter(caster, onlyPlayer, dispelType, isStealable, onlyDispellable, onlyStealable)
    if onlyPlayer and not (caster == "player" or caster == "pet" or caster == "vehicle") then
        return false
    end

    -- Buff-specific filters. On Legion/7.3.5 UnitAura returns a dispel type
    -- and an isStealable flag for many helpful auras. Private servers may vary,
    -- so the two options are treated as an OR-filter when both are enabled.
    if onlyDispellable or onlyStealable then
        local canDispel = dispelType ~= nil and dispelType ~= ""
        local canSteal = isStealable and true or false
        local pass = false

        if onlyDispellable and canDispel then pass = true end
        if onlyStealable and canSteal then pass = true end

        if not pass then
            return false
        end
    end

    return true
end

function CollectAuras(unit, filter, maxIcons, onlyPlayer, onlyDispellable, onlyStealable)
    local result = {}
    for i = 1, 40 do
        local name, _, icon, count, dispelType, duration, expirationTime, caster, isStealable = UnitAura(unit, i, filter)
        if not name then break end
        if icon and AuraPassesFilter(caster, onlyPlayer, dispelType, isStealable, onlyDispellable, onlyStealable) then
            result[#result + 1] = {
                icon = icon,
                count = count,
                duration = duration,
                expirationTime = expirationTime,
                caster = caster,
                dispelType = dispelType,
                isStealable = isStealable,
            }
            if #result >= maxIcons then break end
        end
    end
    return result
end

function PositionAuraButtons(frame, kind, count)
    local w, h, spacing, maxIcons, iconsPerLine, growth, wrapDirection = GetAuraLayoutSettings(kind)
    count = math.min(math.max(0, tonumber(count) or 0), maxIcons)
    iconsPerLine = math.max(1, math.min(iconsPerLine, math.max(count, 1)))

    local frameW, frameH = GetAuraGridSize(kind, count)
    frame:SetSize(math.max(1, frameW), math.max(1, frameH))

    local horizontal = IsHorizontalAuraGrowth(growth)
    local strideX = w + spacing
    local strideY = h + spacing

    for i = 1, count do
        local btn = frame.buttons[i]
        btn:ClearAllPoints()
        btn:SetSize(w, h)
        if btn.SetFrameLevel and frame.GetFrameLevel then
            btn:SetFrameLevel((frame:GetFrameLevel() or 0) + 1)
        end
        if btn.border and btn.border.SetFrameLevel and btn.GetFrameLevel then
            btn.border:SetFrameLevel((btn:GetFrameLevel() or 0) + 2)
        end

        local zeroIndex = i - 1
        local line = math.floor(zeroIndex / iconsPerLine)
        local slot = zeroIndex % iconsPerLine
        local remaining = count - (line * iconsPerLine)
        local itemsInThisLine = math.min(iconsPerLine, remaining)
        local x, y = 0, 0

        if horizontal then
            local rowW = itemsInThisLine * w + math.max(0, itemsInThisLine - 1) * spacing

            if growth == "LEFT" then
                x = (rowW / 2) - (w / 2) - (slot * strideX)
            elseif growth == "CENTER_OUT" then
                -- Legacy compatibility: alternating from center.
                if slot == 0 then
                    x = 0
                else
                    local n = math.floor((slot + 1) / 2)
                    if (slot + 1) % 2 == 0 then
                        x = n * strideX
                    else
                        x = -n * strideX
                    end
                end
            else
                -- RIGHT and CENTER_HORIZONTAL both lay the row left-to-right;
                -- CENTER_HORIZONTAL centers the whole row/frame on the parent.
                x = -(rowW / 2) + (w / 2) + (slot * strideX)
            end

            if wrapDirection == "DOWN" then
                y = (frameH / 2) - (h / 2) - (line * strideY)
            else
                y = -(frameH / 2) + (h / 2) + (line * strideY)
            end
        else
            local colH = itemsInThisLine * h + math.max(0, itemsInThisLine - 1) * spacing

            if growth == "UP" then
                y = -(colH / 2) + (h / 2) + (slot * strideY)
            else
                -- DOWN and CENTER_VERTICAL both lay the column top-to-bottom;
                -- CENTER_VERTICAL centers the whole column/frame on the parent.
                y = (colH / 2) - (h / 2) - (slot * strideY)
            end

            if wrapDirection == "LEFT" then
                x = (frameW / 2) - (w / 2) - (line * strideX)
            else
                x = -(frameW / 2) + (w / 2) + (line * strideX)
            end
        end

        btn:SetPoint("CENTER", frame, "CENTER", x, y)
    end
end

function UpdateAuraFrame(ctx, kind)
    local unit = ctx.unit
    local isTarget = IsTargetUnit(unit)

    local enabled, showOnTarget, frame, filter, maxIcons, onlyPlayer, onlyDispellable, onlyStealable
    if kind == "BUFF" then
        enabled = State.runtimeFlags and State.runtimeFlags.buffs
        showOnTarget = CFG.showBuffFrameOnTarget
        frame = ctx.buffFrame
        filter = "HELPFUL"
        maxIcons = CFG.buffMaxIcons or 8
        onlyPlayer = CFG.buffOnlyPlayerCast
        onlyDispellable = CFG.buffOnlyDispellable
        onlyStealable = CFG.buffOnlyStealable
    else
        enabled = State.runtimeFlags and State.runtimeFlags.debuffs
        showOnTarget = CFG.showDebuffFrameOnTarget
        frame = ctx.debuffFrame
        filter = "HARMFUL"
        maxIcons = CFG.debuffMaxIcons or 8
        onlyPlayer = CFG.debuffOnlyPlayerCast
        onlyDispellable = false
        onlyStealable = false
    end

    if not enabled or (isTarget and not showOnTarget) then
        frame:Hide()
        for _, btn in ipairs(frame.buttons or {}) do btn:Hide() end
        return
    end

    EnsureAuraButtons(frame, maxIcons)
    local auras = CollectAuras(unit, filter, maxIcons, onlyPlayer, onlyDispellable, onlyStealable)
    PositionAuraFrame(ctx, kind, #auras)
    PositionAuraButtons(frame, kind, #auras)

    for i, btn in ipairs(frame.buttons) do
        local aura = auras[i]
        if aura then
            btn.icon:SetTexture(aura.icon)
            if btn.icon.SetDrawLayer then
                btn.icon:SetDrawLayer("ARTWORK", 0)
            end
            if aura.count and aura.count > 1 then
                btn.count:SetText(tostring(aura.count))
                btn.count:Show()
            else
                btn.count:SetText("")
                btn.count:Hide()
            end
            btn:Show()
        else
            btn:Hide()
        end
    end

    frame:Show()
end

function HideCastbar(ctx)
    if ctx and ctx.unit and State.activeCastUnits then
        State.activeCastUnits[ctx.unit] = nil
    end
    if ctx and ctx.cast then
        ctx.cast:Hide()
    end
    if ctx and ctx.castBorder then
        ctx.castBorder:Hide()
    end
    if ctx and ctx.castIconFrame then
        ctx.castIconFrame:Hide()
    end
    if ctx and ctx.castText then
        ctx.castText:SetText("")
        ctx.castText:Hide()
    end
    if ctx then
        -- The text was cleared above, so invalidate its cache as well.
        -- Otherwise the same spell skips SetText and remains blank.
        ctx.s2kLastCastName = nil
    end
end

function UpdateCast(ctx)
    ApplyBlizzardCastbarVisualStateOnly(ctx)

    local unit = ctx.unit
    local cast = ctx.cast
    if not (State.runtimeFlags and State.runtimeFlags.castbar) then
        HideCastbar(ctx)
        return
    end

    -- WoW 7.3.5 UnitCastingInfo/UnitChannelInfo returns:
    -- name, subText/rank, displayName, icon, startTimeMS, endTimeMS, ...
    -- The previous code read the 4th return as startMS, so the custom castbar
    -- could appear as a static bar instead of animating.
    local name, _, _, icon, startMS, endMS = UnitCastingInfo(unit)
    local channeling = false
    if not name then
        name, _, _, icon, startMS, endMS = UnitChannelInfo(unit)
        channeling = name and true or false
    end

    if not name or not startMS or not endMS then
        HideCastbar(ctx)
        return
    end

    startMS = tonumber(startMS)
    endMS = tonumber(endMS)
    if not startMS or not endMS then
        HideCastbar(ctx)
        return
    end

    local nowMS = GetTime() * 1000
    local total = endMS - startMS
    if total <= 0 then
        HideCastbar(ctx)
        return
    end

    local value
    if channeling then
        value = endMS - nowMS
    else
        value = nowMS - startMS
    end

    if value < 0 then value = 0 end
    if value > total then value = total end

    State.activeCastUnits[unit] = ctx

    if ctx.s2kLastCastTotal ~= total then
        cast:SetMinMaxValues(0, total)
        ctx.s2kLastCastTotal = total
    end
    cast:SetValue(value)

    local r, g, b, a = GetCastbarColor()
    if ctx.s2kLastCastR ~= r or ctx.s2kLastCastG ~= g or ctx.s2kLastCastB ~= b or ctx.s2kLastCastA ~= a then
        cast:SetStatusBarColor(r, g, b, a)
        ctx.s2kLastCastR, ctx.s2kLastCastG, ctx.s2kLastCastB, ctx.s2kLastCastA = r, g, b, a
    end
    if not cast:IsShown() then cast:Show() end
    if ApplyCastbarBorderVisual then ApplyCastbarBorderVisual(ctx) end

    if ctx.castText then
        local textR, textG, textB, textA = GetCastbarSpellNameColor()
        if ctx.s2kLastCastTextR ~= textR or ctx.s2kLastCastTextG ~= textG or ctx.s2kLastCastTextB ~= textB or ctx.s2kLastCastTextA ~= textA then
            ctx.castText:SetTextColor(textR, textG, textB, textA)
            ctx.s2kLastCastTextR, ctx.s2kLastCastTextG = textR, textG
            ctx.s2kLastCastTextB, ctx.s2kLastCastTextA = textB, textA
        end
        if CFG.showCastbarSpellName then
            if ctx.s2kLastCastName ~= name then
                ctx.castText:SetText(name or "")
                ctx.s2kLastCastName = name
            end
            if not ctx.castText:IsShown() then ctx.castText:Show() end
        else
            ctx.castText:SetText("")
            ctx.castText:Hide()
            ctx.s2kLastCastName = nil
        end
    end

    local iconFrame = ctx.castIconFrame
    if iconFrame then
        if CFG.showCastbarIcon and icon then
            if ctx.s2kLastCastIcon ~= icon then
                iconFrame.icon:SetTexture(icon)
                ctx.s2kLastCastIcon = icon
            end
            if not iconFrame:IsShown() then iconFrame:Show() end
        else
            iconFrame:Hide()
            ctx.s2kLastCastIcon = nil
        end
    end
end

function HidePlayerCastOverlaySpark(ctx)
    if ctx and ctx.playerCastOverlaySpark then
        ctx.playerCastOverlaySpark:Hide()
    end
end

function HidePlayerCastOverlay(ctx)
    if ctx and ctx.playerCastOverlay then
        ctx.playerCastOverlay:Hide()
    end
    HidePlayerCastOverlaySpark(ctx)
end

function UpdatePlayerCastOverlaySpark(ctx, value, total)
    local spark = ctx and ctx.playerCastOverlaySpark
    if not spark or not ctx.root then
        return
    end

    if not CFG.playerCastOverlaySparkEnabled then
        if IsFrameShownFast(spark) then
            spark:Hide()
        end
        spark.s2kSparkLastX = nil
        spark.s2kSparkAnchorRoot = nil
        return
    end

    value = tonumber(value) or 0
    total = tonumber(total) or 0
    if total <= 0 then
        if IsFrameShownFast(spark) then
            spark:Hide()
        end
        spark.s2kSparkLastX = nil
        return
    end

    local width = math.max(1, tonumber(CFG.playerCastOverlaySparkWidth) or 2)
    local rootW = (ctx.root.GetWidth and ctx.root:GetWidth()) or tonumber(CFG.plateWidth) or 110
    local rootH = (ctx.root.GetHeight and ctx.root:GetHeight()) or tonumber(CFG.plateHeight) or 12
    if rootW <= 0 then rootW = tonumber(CFG.plateWidth) or 110 end
    if rootH <= 0 then rootH = tonumber(CFG.plateHeight) or 12 end

    local ratio = value / total
    if ratio < 0 then ratio = 0 end
    if ratio > 1 then ratio = 1 end
    local x = (rootW * ratio) - (rootW / 2)

    -- Hot path cache: during a cast this function is called on the throttled
    -- target runtime path. Only x normally changes; texture, color, size and
    -- frame level should not be re-applied every tick.
    if spark.s2kSparkWidth ~= width or spark.s2kSparkHeight ~= rootH then
        spark:SetSize(width, math.max(1, rootH))
        spark.s2kSparkWidth, spark.s2kSparkHeight = width, rootH
    end

    if spark.s2kSparkAnchorRoot ~= ctx.root then
        spark:ClearAllPoints()
        spark:SetPoint("CENTER", ctx.root, "CENTER", x, 0)
        spark.s2kSparkAnchorRoot = ctx.root
        spark.s2kSparkLastX = x
    elseif not spark.s2kSparkLastX or math.abs((spark.s2kSparkLastX or 0) - x) >= 0.10 then
        -- Calling SetPoint with the same point updates the existing anchor on
        -- this client and avoids the old ClearAllPoints churn.
        spark:SetPoint("CENTER", ctx.root, "CENTER", x, 0)
        spark.s2kSparkLastX = x
    end

    if spark.texture then
        local texturePath = GetPlayerCastOverlaySparkTexturePath()
        if spark.texture.s2kTexturePath ~= texturePath then
            ApplyTexturePath(spark.texture, texturePath)
            spark.texture.s2kTexturePath = texturePath
        end
        if spark.texture.s2kAllPointsSpark ~= spark then
            spark.texture:SetAllPoints(spark)
            spark.texture.s2kAllPointsSpark = spark
        end
        local r, g, b, a = GetPlayerCastOverlaySparkColor()
        if spark.texture.s2kR ~= r or spark.texture.s2kG ~= g or spark.texture.s2kB ~= b or spark.texture.s2kA ~= a then
            spark.texture:SetVertexColor(r, g, b, a)
            spark.texture.s2kR, spark.texture.s2kG, spark.texture.s2kB, spark.texture.s2kA = r, g, b, a
        end
    end

    if spark.SetFrameLevel and ctx.root.GetFrameLevel then
        local frameLevel = (ctx.root:GetFrameLevel() or 0) + (tonumber(CFG.playerCastOverlayFrameLevel) or 20) + 1
        if spark.s2kSparkFrameLevel ~= frameLevel then
            spark:SetFrameLevel(frameLevel)
            spark.s2kSparkFrameLevel = frameLevel
        end
    end

    if not IsFrameShownFast(spark) then
        spark:Show()
    end
end

function PlayerHasActiveCast()
    local name, _, _, _, startMS, endMS = UnitCastingInfo("player")
    local channeling = false

    if not name then
        name, _, _, _, startMS, endMS = UnitChannelInfo("player")
        channeling = name and true or false
    end

    if not name or not startMS or not endMS then
        return nil
    end

    startMS = tonumber(startMS)
    endMS = tonumber(endMS)
    if not startMS or not endMS then
        return nil
    end

    local total = endMS - startMS
    if total <= 0 then
        return nil
    end

    local nowMS = GetTime() * 1000
    local value

    if channeling then
        value = endMS - nowMS
    else
        value = nowMS - startMS
    end

    if value < 0 then value = 0 end
    if value > total then value = total end

    return value, total
end

function UpdatePlayerCastOverlay(ctx, knownTarget)
    if not ctx or not ctx.playerCastOverlay then
        return
    end

    if not (State.runtimeFlags and State.runtimeFlags.playerCastOverlay) or (not knownTarget and not IsTargetUnit(ctx.unit)) then
        HidePlayerCastOverlay(ctx)
        return
    end

    local value, total = PlayerHasActiveCast()
    if not value or not total then
        HidePlayerCastOverlay(ctx)
        return
    end

    local bar = ctx.playerCastOverlay
    if bar.s2kAllPointsRoot ~= ctx.root then
        bar:ClearAllPoints()
        bar:SetAllPoints(ctx.root)
        bar.s2kAllPointsRoot = ctx.root
    end
    if bar.s2kLastTotal ~= total then
        bar:SetMinMaxValues(0, total)
        bar.s2kLastTotal = total
    end
    bar:SetValue(value)

    local r, g, b, a = GetPlayerCastOverlayColor()
    if bar.s2kR ~= r or bar.s2kG ~= g or bar.s2kB ~= b or bar.s2kA ~= a then
        bar:SetStatusBarColor(r, g, b, a)
        bar.s2kR, bar.s2kG, bar.s2kB, bar.s2kA = r, g, b, a
    end

    if not IsFrameShownFast(bar) then
        bar:Show()
    end
    UpdatePlayerCastOverlaySpark(ctx, value, total)
end

function UpdateContext(ctx, full)
    if not ctx or not ctx.unit or not UnitExists(ctx.unit) then return end
    if not ctx.plate or not FrameIsVisible(ctx.plate) then
        if ctx.castText then
            ctx.castText:SetText("")
            ctx.castText:Hide()
        end
        if ctx.root then ctx.root:Hide() end
        return
    end

    if full then
        ApplyContextStatusBarTextures(ctx)
    end

    -- Backdrop borders must be laid out while the recycled nameplate root is
    -- visible. Legion can otherwise cache malformed edge geometry until the
    -- next target/layout change.
    ctx.root:Show()
    LayoutAll(ctx)
    ApplyBlizzardVisualState(ctx)
    UpdateHealth(ctx)
    UpdatePlayerCastOverlay(ctx)
    UpdateName(ctx)
    UpdateHPThresholdMarker(ctx)
    UpdateUnitLevelOverlay(ctx)
    UpdateHPRatio(ctx)
    UpdateAuraFrame(ctx, "DEBUFF")
    UpdateAuraFrame(ctx, "BUFF")
    UpdateCast(ctx)
    UpdateWAAnchors(ctx)
end

function UpdateUnit(unit, full)
    if not CFG.enabled or not IsNameplateUnit(unit) or not UnitExists(unit) then return end
    local plate = GetPlate(unit)
    if not plate or not FrameIsVisible(plate) then
        HideUnit(unit)
        return
    end
    local ctx = GetContext(unit)
    if ctx then UpdateContext(ctx, full) end
end

function UpdateAll(full)
    if not CFG.enabled then return end
    for i = 1, CFG.maxNameplates do
        local unit = "nameplate" .. i
        if UnitExists(unit) then
            UpdateUnit(unit, full)
        end
    end
end

function ApplyVisibleTextFonts()
    for _, ctx in pairs(State.plates) do
        if ctx and ctx.unit and UnitExists(ctx.unit) and ctx.root and ctx.root:IsShown() then
            if ctx.ratio then
                ApplyFontStringFont(ctx.ratio, CFG.hpRatioFontKey, CFG.hpRatioFontSize, CFG.hpRatioFontOutlineKey, CFG.hpRatioFontPath)
            end
            if ctx.name then
                ApplyFontStringFont(ctx.name, CFG.nameFontKey, CFG.nameFontSize, CFG.nameFontOutlineKey, CFG.nameFontPath)
            end
            if ctx.castText then
                ApplyFontStringFont(ctx.castText, CFG.castbarSpellNameFontKey, CFG.castbarSpellNameFontSize, CFG.castbarSpellNameFontOutlineKey, CFG.castbarSpellNameFontPath)
                ctx.castText:SetTextColor(GetCastbarSpellNameColor())
            end
            if ctx.levelText then
                ApplyFontStringFont(ctx.levelText, CFG.levelOverlayFontKey, CFG.levelOverlayFontSize, CFG.levelOverlayFontOutlineKey, CFG.levelOverlayFontPath)
            end

            UpdateName(ctx)
            UpdateHPRatio(ctx)
            UpdateUnitLevelOverlay(ctx)
        end
    end
end

function RefreshVisibleTextFonts()
    RebuildFontOptions()
    RememberConfiguredFontPaths()
    ApplyVisibleTextFonts()
end

function ScheduleVisibleTextFontRefreshes(skipImmediate)
    if not skipImmediate then ApplyVisibleTextFonts() end
    if C_Timer and C_Timer.After then
        for _, delay in ipairs({ 0.01, 0.03, 0.08, 0.16, 0.30, 0.60 }) do
            C_Timer.After(delay, ApplyVisibleTextFonts)
        end
    end
end

function DelayedRefreshVisibleTextFonts()
    RebuildFontOptions()
    RememberConfiguredFontPaths()
    ScheduleVisibleTextFontRefreshes()
end

function HideUnit(unit)
    local ctx = State.plates[unit]
    if ctx then ResetNameplateContextVisuals(ctx, true) end
    State.activeCastUnits[unit] = nil
    State.plates[unit] = nil
end


function ApplyVisibleStatusBarTextures()
    for _, ctx in pairs(State.plates) do
        if ctx and ctx.unit and UnitExists(ctx.unit) and ctx.root and ctx.root:IsShown() then
            ApplyContextStatusBarTextures(ctx)
        end
    end
end

function RefreshVisibleStatusBarTextures()
    RebuildStatusBarTextureOptions()
    RebuildBorderTextureOptions()
    RememberConfiguredStatusBarTexturePaths()
    RememberConfiguredBorderTexturePaths()
    ApplyVisibleStatusBarTextures()
end

function ScheduleVisibleStatusBarTextureRefreshes(skipImmediate)
    if not skipImmediate then ApplyVisibleStatusBarTextures() end
    if C_Timer and C_Timer.After then
        for _, delay in ipairs({ 0.03, 0.12, 0.30 }) do
            C_Timer.After(delay, ApplyVisibleStatusBarTextures)
        end
    end
end

function DelayedRefreshVisibleStatusBarTextures()
    RebuildStatusBarTextureOptions()
    RebuildBorderTextureOptions()
    RememberConfiguredStatusBarTexturePaths()
    RememberConfiguredBorderTexturePaths()
    ScheduleVisibleStatusBarTextureRefreshes()
end
