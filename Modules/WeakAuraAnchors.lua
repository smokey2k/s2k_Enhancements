-- =========================================================
-- WeakAuras bridge anchor API
-- =========================================================

function GetWeakAuraAnchorEngine()
    return "bridge"
end

function ResetWeakAuraAnchorStats()
    State.weakAuraAnchorStats = {
        calls = 0,
        ok = 0,
        fail = 0,
        total = 0,
        max = 0,
        startedAt = debugprofilestop and debugprofilestop() or 0,
        lastAt = nil,
        lastDelta = 0,
        deltaTotal = 0,
        deltaCount = 0,
        deltaMax = 0,
        engine = "bridge",
        mode = "none",
        unit = "",
        relinks = 0,
        fallbacks = 0,
    }
end

function RecordWeakAuraAnchorSample(mode, unit, startTime, ok, relinked)
    if not CFG or CFG.debugWeakAuraAnchorStatsEnabled ~= true then return end
    if not State then return end
    local stats = State.weakAuraAnchorStats
    if type(stats) ~= "table" or not stats.startedAt then
        ResetWeakAuraAnchorStats()
        stats = State.weakAuraAnchorStats
    end

    local now = debugprofilestop and debugprofilestop() or nil
    local elapsed = (now and startTime) and (now - startTime) or 0

    stats.calls = (stats.calls or 0) + 1
    if ok then
        stats.ok = (stats.ok or 0) + 1
    else
        stats.fail = (stats.fail or 0) + 1
    end
    stats.total = (stats.total or 0) + elapsed
    if elapsed > (stats.max or 0) then stats.max = elapsed end

    if now then
        if stats.lastAt then
            local delta = now - stats.lastAt
            stats.lastDelta = delta
            stats.deltaTotal = (stats.deltaTotal or 0) + delta
            stats.deltaCount = (stats.deltaCount or 0) + 1
            if delta > (stats.deltaMax or 0) then stats.deltaMax = delta end
        end
        stats.lastAt = now
    end

    stats.engine = "bridge"
    stats.mode = mode or stats.mode or "none"
    stats.unit = tostring(unit or "")
    if relinked then stats.relinks = (stats.relinks or 0) + 1 end
end

function ResetWeakAuraAnchorEngine()
    State.weakAuraLastTargetRegion = nil
    State.weakAuraBarGroupsDirty = true

    for _, ctx in pairs(State.plates or {}) do
        if ctx then
            if ctx.waHealthAnchor then
                ctx.waHealthAnchor:ClearAllPoints()
                ctx.waHealthAnchor:Hide()
                ctx.waHealthAnchor.s2kBridgeSource = nil
            end
            if ctx.waCastAnchor then
                ctx.waCastAnchor:ClearAllPoints()
                ctx.waCastAnchor:Hide()
                ctx.waCastAnchor.s2kBridgeSource = nil
            end
            ctx.s2kWAAnchorRegion = nil
        end
    end

    if CFG and CFG.debugWeakAuraAnchorStatsEnabled == true then
        ResetWeakAuraAnchorStats()
    end
    if MarkWeakAurasDirty then MarkWeakAurasDirty() end
end

function HideWAAnchors(ctx)
    if not ctx then return end
    if ctx.waHealthAnchor and (not ctx.waHealthAnchor.IsShown or ctx.waHealthAnchor:IsShown()) then
        ctx.waHealthAnchor:Hide()
    end
    if ctx.waCastAnchor and (not ctx.waCastAnchor.IsShown or ctx.waCastAnchor:IsShown()) then
        ctx.waCastAnchor:Hide()
    end
end

function IsFrameShownFast(frame)
    return frame and frame.IsShown and frame:IsShown()
end

function HideFrameIfShownFast(frame)
    if frame and (not frame.IsShown or frame:IsShown()) then
        frame:Hide()
    end
end

function PointBridgeAnchorToSource(anchor, source, force)
    if not anchor then return false, false end

    if not source or not source.GetObjectType or not IsFrameShownFast(source) then
        HideFrameIfShownFast(anchor)
        anchor.s2kBridgeSource = nil
        return false, false
    end

    local relinked = force or anchor.s2kBridgeSource ~= source or not IsFrameShownFast(anchor)
    if relinked then
        anchor:ClearAllPoints()
        anchor:SetPoint("TOPLEFT", source, "TOPLEFT", 0, 0)
        anchor:SetPoint("TOPRIGHT", source, "TOPRIGHT", 0, 0)
        anchor:SetPoint("BOTTOMLEFT", source, "BOTTOMLEFT", 0, 0)
        anchor:SetPoint("BOTTOMRIGHT", source, "BOTTOMRIGHT", 0, 0)
        anchor.s2kBridgeSource = source
    end

    if not IsFrameShownFast(anchor) then
        anchor:Show()
    end
    return true, relinked
end

function UpdateWAAnchors(ctx, force)
    local collectStats = CFG and CFG.debugWeakAuraAnchorStatsEnabled == true
    local startTime = collectStats and debugprofilestop and debugprofilestop() or nil

    if not ctx or not ctx.root or not IsFrameShownFast(ctx.root) then
        HideWAAnchors(ctx)
        if collectStats then
            RecordWeakAuraAnchorSample(State.weakAuraLastMode or "target", ctx and ctx.unit or "", startTime, false, false)
        end
        return false
    end

    local healthOk, healthRelinked = PointBridgeAnchorToSource(ctx.waHealthAnchor, ctx.health, force)
    local castRelinked = false

    if ctx.cast and IsFrameShownFast(ctx.cast) then
        local castOk
        castOk, castRelinked = PointBridgeAnchorToSource(ctx.waCastAnchor, ctx.cast, force)
        if not castOk then
            HideFrameIfShownFast(ctx.waCastAnchor)
        end
    else
        HideFrameIfShownFast(ctx.waCastAnchor)
        if ctx.waCastAnchor then
            ctx.waCastAnchor.s2kBridgeSource = nil
        end
    end

    if collectStats then
        RecordWeakAuraAnchorSample(State.weakAuraLastMode or "target", ctx.unit or "", startTime, healthOk, healthRelinked or castRelinked)
    end
    return healthOk
end

function API.GetContextForUnit(unit)
    return GetExistingContextForUnit(unit or "target")
end

function API.GetWAHealthAnchorForUnit(unit)
    local ctx = GetExistingContextForUnit(unit or "target")
    if not ctx then return nil end
    UpdateWAAnchors(ctx, false)
    if ctx.waHealthAnchor and FrameIsVisible(ctx.waHealthAnchor) then
        return ctx.waHealthAnchor
    end
    return nil
end

function API.GetWACastAnchorForUnit(unit)
    local ctx = GetExistingContextForUnit(unit or "target")
    if not ctx then return nil end
    UpdateWAAnchors(ctx, false)
    if ctx.waCastAnchor and FrameIsVisible(ctx.waCastAnchor) then
        return ctx.waCastAnchor
    end
    return nil
end

function API.GetRootFrameForUnit(unit)
    local ctx = GetExistingContextForUnit(unit or "target")
    return ctx and ctx.root or nil
end

function API.GetHealthFrameForUnit(unit)
    local ctx = GetExistingContextForUnit(unit or "target")
    return ctx and ctx.health or nil
end

function API.GetCastFrameForUnit(unit)
    local ctx = GetExistingContextForUnit(unit or "target")
    return ctx and ctx.cast or nil
end

function API.GetNameplateForUnit(unit)
    local ctx = GetExistingContextForUnit(unit or "target")
    return ctx and ctx.plate or nil
end