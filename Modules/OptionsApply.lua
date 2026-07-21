-- =========================================================
-- Options UI
-- =========================================================

UpdateWeakAurasBinding = nil


function NormalizeSpellActivationOverlayValue(value)
    if type(value) == "boolean" then
        return value
    end
    if type(value) == "number" then
        return value ~= 0
    end

    local text = tostring(value or ""):lower()
    if text == "" then return nil end
    if text == "0" or text == "false" or text == "off" or text == "no" then return false end
    if text == "1" or text == "true" or text == "on" or text == "yes" then return true end

    local number = tonumber(text)
    if number ~= nil then
        return number ~= 0
    end
    return nil
end

function ReadSpellActivationOverlayCVar()
    if GetCVarBool then
        local ok, value = pcall(GetCVarBool, "displaySpellActivationOverlays")
        if ok and type(value) == "boolean" then
            return value
        end
    end

    if GetCVar then
        local ok, value = pcall(GetCVar, "displaySpellActivationOverlays")
        if ok then
            return NormalizeSpellActivationOverlayValue(value)
        end
    end
    return nil
end

function EnsureSpellActivationOverlaySetting()
    local stored = DBRoot and DBRoot.spellActivationOverlaysEnabled
    if stored == nil then
        stored = ReadSpellActivationOverlayCVar()
        if stored == nil then stored = true end
        if DBRoot then
            DBRoot.spellActivationOverlaysEnabled = stored and true or false
        end
    end
    return stored and true or false
end

function RefreshBlizzardSpellActivationOverlayControl(enabled)
    local value = enabled and "1" or "0"
    local control = _G.InterfaceOptionsCombatPanelDisplaySpellActivationOverlays
        or _G.InterfaceOptionsCombatPanelDisplaySpellAlerts

    if control then
        if control.SetChecked then control:SetChecked(enabled) end
        control.value = value
        control.oldValue = value
    end
end

function ApplySpellActivationOverlaySetting()
    local enabled = EnsureSpellActivationOverlaySetting()
    local value = enabled and "1" or "0"

    if SetCVar then
        pcall(SetCVar, "displaySpellActivationOverlays", value)
    end

    local actual = ReadSpellActivationOverlayCVar()
    if actual ~= enabled and C_CVar and type(C_CVar.SetCVar) == "function" then
        pcall(C_CVar.SetCVar, "displaySpellActivationOverlays", value)
        actual = ReadSpellActivationOverlayCVar()
    end

    -- Some 7.3.5/private-server clients expose the CVar through the console
    -- more reliably than through SetCVar. Use it only as a readback fallback.
    if actual ~= enabled and ConsoleExec then
        pcall(ConsoleExec, "displaySpellActivationOverlays " .. value)
    end

    RefreshBlizzardSpellActivationOverlayControl(enabled)

    -- Disabling the CVar prevents future overlays, but an already active
    -- proc graphic would otherwise remain until its normal hide event.
    if not enabled
    and SpellActivationOverlayFrame
    and SpellActivationOverlay_HideAllOverlays
    then
        pcall(SpellActivationOverlay_HideAllOverlays, SpellActivationOverlayFrame)
    end

    return enabled
end

function IsSpellActivationOverlaysEnabled()
    return EnsureSpellActivationOverlaySetting()
end

function SetSpellActivationOverlaysEnabled(enabled)
    enabled = enabled and true or false
    if DBRoot then
        DBRoot.spellActivationOverlaysEnabled = enabled
    end

    ApplySpellActivationOverlaySetting()

    -- Blizzard or server-side startup code can rewrite CVars shortly after a
    -- UI action/login. Reapply twice without keeping a permanent OnUpdate.
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, ApplySpellActivationOverlaySetting)
        C_Timer.After(0.50, ApplySpellActivationOverlaySetting)
    end
end

function ApplyOptionsNow()
    State.pendingOptionsApply = false
    SyncProfilerState()
    ApplyNameplateCVarSettings()
    if S2KNP_ApplyModuleState then S2KNP_ApplyModuleState() end
    UpdateAll(true)
    if ScheduleNameplateScaleStabilization then
        ScheduleNameplateScaleStabilization()
    end
    if UpdateWeakAurasBinding then
        UpdateWeakAurasBinding()
    end
    if RefreshQuestReputationDisplay then
        RefreshQuestReputationDisplay()
    end
    if ApplyChatSettings then
        ApplyChatSettings()
    end
end

function RequestApply()
    -- UI changes are saved immediately, but the expensive/live application of
    -- options is deferred while in combat. Runtime combat updates continue to
    -- use the already active layout, avoiding accidental protected-frame work
    -- from the standalone configuration window.
    if IsInCombat() then
        State.pendingOptionsApply = true
        State.pendingCVarApply = true
        return
    end

    ApplyOptionsNow()
end

function RequestStatusBarTextureRefresh()
    if IsInCombat() then
        State.pendingOptionsApply = true
        return
    end

    RebuildStatusBarTextureOptions()
    RebuildBorderTextureOptions()
    RememberConfiguredStatusBarTexturePaths()
    RememberConfiguredBorderTexturePaths()
    UpdateAll(true)
    ScheduleVisibleStatusBarTextureRefreshes(true)
end
