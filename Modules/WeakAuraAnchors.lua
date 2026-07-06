-- =========================================================
-- WeakAuras-safe absolute anchor API
-- =========================================================

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

function PositionAbsoluteUIParentFrame(anchor, source)
    if not anchor then
        return false
    end

    -- Hot path: this runs every rendered frame while WeakAura smooth-follow is
    -- enabled. The source frames are our own custom frames, so avoid pcall() and
    -- the generic FrameIsVisible() helper here.
    if not source or not source.GetObjectType or not IsFrameShownFast(source) then
        HideFrameIfShownFast(anchor)
        anchor.s2kAbsCache = nil
        return false
    end

    local left, bottom, width, height

    if source.GetRect then
        left, bottom, width, height = source:GetRect()
    end

    if not left or not bottom or not width or not height or width <= 0 or height <= 0 then
        if source.GetCenter and source.GetWidth and source.GetHeight then
            local cx, cy = source:GetCenter()
            local w, h = source:GetWidth(), source:GetHeight()
            if cx and cy and w and h and w > 0 and h > 0 then
                width, height = w, h
                left = cx - (w / 2)
                bottom = cy - (h / 2)
            end
        end
    end

    if not left or not bottom or not width or not height or width <= 0 or height <= 0 then
        HideFrameIfShownFast(anchor)
        anchor.s2kAbsCache = nil
        return false
    end

    -- Convert to UIParent coordinates. This avoids making the WA region itself
    -- SetPoint() to a nameplate-child frame.
    local sourceScale = (source.GetEffectiveScale and source:GetEffectiveScale()) or 1
    local uiScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    local scale = sourceScale / uiScale

    left = left * scale
    bottom = bottom * scale
    width = width * scale
    height = height * scale

    local cache = anchor.s2kAbsCache
    local epsilon = 0.005

    if cache
    and math.abs((cache.left or 0) - left) <= epsilon
    and math.abs((cache.bottom or 0) - bottom) <= epsilon
    and math.abs((cache.width or 0) - width) <= epsilon
    and math.abs((cache.height or 0) - height) <= epsilon
    then
        if not IsFrameShownFast(anchor) then
            anchor:Show()
        end
        return true
    end

    if not cache then
        cache = {}
        anchor.s2kAbsCache = cache
    end

    local sizeChanged = (not cache.width)
        or math.abs((cache.width or 0) - width) > epsilon
        or math.abs((cache.height or 0) - height) > epsilon

    cache.left = left
    cache.bottom = bottom
    cache.width = width
    cache.height = height

    anchor:ClearAllPoints()
    anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    if sizeChanged then
        anchor:SetSize(width, height)
    end
    if not IsFrameShownFast(anchor) then
        anchor:Show()
    end

    return true
end

function UpdateWAAnchors(ctx)
    if not ctx or not ctx.root or not IsFrameShownFast(ctx.root) then
        HideWAAnchors(ctx)
        return false
    end

    local healthOk = PositionAbsoluteUIParentFrame(ctx.waHealthAnchor, ctx.health)

    if ctx.cast and IsFrameShownFast(ctx.cast) then
        PositionAbsoluteUIParentFrame(ctx.waCastAnchor, ctx.cast)
    else
        HideFrameIfShownFast(ctx.waCastAnchor)
        if ctx.waCastAnchor then
            ctx.waCastAnchor.s2kAbsCache = nil
        end
    end

    return healthOk
end

function API.GetContextForUnit(unit)
    return GetExistingContextForUnit(unit or "target")
end

function API.GetWAHealthAnchorForUnit(unit)
    local ctx = GetExistingContextForUnit(unit or "target")
    if not ctx then return nil end
    UpdateWAAnchors(ctx)
    if ctx.waHealthAnchor and FrameIsVisible(ctx.waHealthAnchor) then
        return ctx.waHealthAnchor
    end
    return nil
end

function API.GetWACastAnchorForUnit(unit)
    local ctx = GetExistingContextForUnit(unit or "target")
    if not ctx then return nil end
    UpdateWAAnchors(ctx)
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
