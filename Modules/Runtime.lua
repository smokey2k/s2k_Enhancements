-- =========================================================
-- Lightweight runtime refresh helpers
-- =========================================================

function MarkWeakAurasDirty()
    local flags = State.runtimeFlags
    if not flags or not flags.weakAuras then return end
    State.weakAuraDirty = true
    State.weakAuraBarGroupsDirty = true
end

function RefreshWeakAurasRuntime(markScaffold)
    local flags = State.runtimeFlags
    if not flags or not flags.weakAuras then return end

    if markScaffold and MarkWeakAuraScaffoldDirty then
        MarkWeakAuraScaffoldDirty()
    end
    MarkWeakAurasDirty()
    if UpdateWeakAurasBinding then UpdateWeakAurasBinding() end
end

function MarkAuraDirty(unit)
    local flags = State.runtimeFlags
    if flags and flags.auras and unit and IsNameplateUnit(unit) then
        State.auraDirtyUnits[unit] = true
    end
end

function FlushDirtyAuras()
    local flags = State.runtimeFlags
    if not flags or not flags.auras then return end

    local dirty = State.auraDirtyUnits
    if not dirty or not next(dirty) then return end

    for unit in pairs(dirty) do
        dirty[unit] = nil
        if UnitExists(unit) then
            local ctx = State.plates[unit] or GetContext(unit)
            if ctx and ctx.root and ctx.root:IsShown() then
                if flags.debuffs then
                    PositionAuraFrame(ctx, "DEBUFF")
                    UpdateAuraFrame(ctx, "DEBUFF")
                end
                if flags.buffs then
                    PositionAuraFrame(ctx, "BUFF")
                    UpdateAuraFrame(ctx, "BUFF")
                end
            end
        end
    end
end

function UpdateTargetRuntimeOnly()
    local flags = State.runtimeFlags
    if not flags or not flags.targetRuntime then return nil end

    local ctx = GetTargetContextCached()
    if not (ctx and ctx.unit and UnitExists(ctx.unit) and ctx.root and ctx.root:IsShown()) then
        return nil
    end

    if flags.targetRuntimeHealth then UpdateHealth(ctx) end
    if flags.playerCastOverlay then UpdatePlayerCastOverlay(ctx, true) end
    return ctx
end

function UpdateVisibleCastRuntimeOnly()
    local flags = State.runtimeFlags
    if not flags or not flags.castRuntime then return end

    local active = State.activeCastUnits
    if not active or not next(active) then return end

    for unit, ctx in pairs(active) do
        if not UnitExists(unit) or not ctx or not ctx.root or not ctx.root:IsShown() then
            active[unit] = nil
        else
            UpdateCast(ctx) -- UpdateCast removes completed/interrupted casts from the cache.
        end
    end
end

function UpdateTargetPlayerCastOverlayOnly()
    local ctx = GetTargetContextCached()
    if ctx then UpdatePlayerCastOverlay(ctx, true) end
end