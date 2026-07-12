-- =========================================================
-- Events and throttled runtime updates
-- =========================================================

function S2KNP_InitializeLoadedAddon(addonName)
    local name = tostring(addonName or ""):lower()
    if name == "blizzard_questui" and InitializeQuestReputation then
        InitializeQuestReputation()
    elseif name == "weakauras" or name:match("^weakauras[%-%_%.]?") then
        RefreshWeakAurasRuntime(true)
    elseif name == "dominos" then
        State.dominosActionBarCount = nil
        if ScheduleDominosIntegrationApply then ScheduleDominosIntegrationApply() end
    end

    if RefreshAddonsOptionsAvailability then
        RefreshAddonsOptionsAvailability()
    end
end

function S2KNP_InitializeDatabaseRuntime()
    if DB then return end
    EnsureDatabase()
    RebuildFontOptions()
    RememberConfiguredFontPaths()
    SyncProfilerState()
    S2KNP_ApplyModuleState()
end

function S2KNP_OnEvent(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            EnsureDatabase()
            if ApplySpellActivationOverlaySetting then ApplySpellActivationOverlaySetting() end
            if InitializeS2KBroker then InitializeS2KBroker() end
            if InitializeS2KMinimapIcon then InitializeS2KMinimapIcon() end
            RebuildFontOptions()
            RememberConfiguredFontPaths()
            SyncProfilerState()
            if InitializeQuestReputation then InitializeQuestReputation() end
            S2KNP_ApplyModuleState()
        else
            S2KNP_InitializeLoadedAddon(arg1)
        end
        return
    end

    S2KNP_InitializeDatabaseRuntime()
    local flags = State.runtimeFlags

    if event == "PLAYER_REGEN_ENABLED" then
        if State.pendingOptionsApply then
            ApplyOptionsNow()
        elseif State.pendingCVarApply then
            ApplyNameplateCVarSettings()
        end
        if State.pendingDominosApply and ApplyDominosIntegration then
            ApplyDominosIntegration(false)
        end
        S2KNP_ApplyModuleState()
        return
    end

    if event == "PLAYER_LOGIN" then
        if ApplySpellActivationOverlaySetting then ApplySpellActivationOverlaySetting() end
        if InitializeS2KBroker then InitializeS2KBroker() end
        if InitializeS2KMinimapIcon then InitializeS2KMinimapIcon() end
        if InitializeQuestReputation then InitializeQuestReputation() end
        RebuildFontOptions()
        RebuildStatusBarTextureOptions()
        RememberConfiguredFontPaths()
        RememberConfiguredStatusBarTexturePaths()
        S2KNP_ApplyModuleState()
        SyncProfilerState()
        if ScheduleDominosIntegrationApply then ScheduleDominosIntegrationApply() end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        if ApplySpellActivationOverlaySetting then ApplySpellActivationOverlaySetting() end
        ApplyNameplateCVarSettings()
        S2KNP_ApplyModuleState()
        UpdateAll(true)
        ScheduleNameplateScaleStabilization()
        ClearWeakAuraGroupChildrenCache()
        RefreshWeakAurasRuntime(true)
        DelayedRefreshVisibleTextFonts()
        DelayedRefreshVisibleStatusBarTextures()
        if ScheduleDominosIntegrationApply then ScheduleDominosIntegrationApply() end
        return
    end

    if event == "NAME_PLATE_UNIT_ADDED" then
        ClearTargetContextCache()
        UpdateUnit(arg1, true)
        ScheduleNameplateScaleStabilization()
        RefreshWeakAurasRuntime(false)
        return
    end

    if event == "NAME_PLATE_UNIT_REMOVED" then
        ClearTargetContextCache()
        HideUnit(arg1)
        RefreshWeakAurasRuntime(false)
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        ClearTargetContextCache()
        UpdateAll(false)
        ScheduleNameplateScaleStabilization()
        RefreshWeakAurasRuntime(false)
        return
    end

    if event == "UNIT_HEALTH" then
        if flags.health and IsNameplateUnit(arg1) then
            local ctx = State.plates[arg1] or GetContext(arg1)
            if ctx then UpdateHealth(ctx) end
        end
        return
    end

    if event == "UNIT_MAXHEALTH" then
        if arg1 == "player" then
            if flags.hpRatio then
                for unit, ctx in pairs(State.plates) do
                    if UnitExists(unit) and ctx.root and ctx.root:IsShown() then
                        UpdateHPRatio(ctx)
                    end
                end
            end
        elseif IsNameplateUnit(arg1) then
            local ctx = State.plates[arg1] or GetContext(arg1)
            if ctx then
                if flags.health then UpdateHealth(ctx) end
                if flags.hpRatio then UpdateHPRatio(ctx) end
                if flags.hpMarker then UpdateHPThresholdMarker(ctx) end
            end
        end
        return
    end

    if event == "UNIT_AURA" then
        if flags.auras and IsNameplateUnit(arg1) then MarkAuraDirty(arg1) end
        return
    end

    if event == "UNIT_NAME_UPDATE" then
        if flags.names and IsNameplateUnit(arg1) then
            local ctx = State.plates[arg1] or GetContext(arg1)
            if ctx then UpdateName(ctx) end
        end
        return
    end

    if event and event:match("^UNIT_SPELLCAST") then
        if arg1 == "player" then
            if flags.playerCastOverlay then UpdateTargetPlayerCastOverlayOnly() end
        elseif IsNameplateUnit(arg1) then
            local ctx = State.plates[arg1] or GetContext(arg1)
            if ctx then
                if flags.castbar then UpdateCast(ctx) end
                if flags.weakAuras and IsTargetUnit(arg1) then MarkWeakAurasDirty() end
            end
        end
        return
    end
end

function S2KNP_OnUpdate(self, elapsed)
    local flags = State.runtimeFlags
    if not flags or not flags.enabled then return end

    local profileStart = State.profilerActive and debugprofilestop()


    if flags.targetRuntime then
        State.smoothElapsed = State.smoothElapsed + elapsed
        if State.smoothElapsed >= (CFG.targetRuntimeThrottle or 0.033) then
            State.smoothElapsed = 0
            UpdateTargetRuntimeOnly()
        end
    end

    if flags.castRuntime and next(State.activeCastUnits) then
        State.castRuntimeElapsed = State.castRuntimeElapsed + elapsed
        if State.castRuntimeElapsed >= (CFG.castRuntimeThrottle or 0.05) then
            State.castRuntimeElapsed = 0
            UpdateVisibleCastRuntimeOnly()
        end
    end

    if flags.auras and next(State.auraDirtyUnits) then
        State.auraDirtyElapsed = State.auraDirtyElapsed + elapsed
        if State.auraDirtyElapsed >= (CFG.auraUpdateThrottle or 0.08) then
            State.auraDirtyElapsed = 0
            FlushDirtyAuras()
        end
    end

    if flags.weakAuraAnchorStats then
        UpdateWeakAuraAnchorStatsPanel(elapsed)
    end



    if flags.weakAuras then
        State.weakAuraSlowElapsed = State.weakAuraSlowElapsed + elapsed
        if State.weakAuraDirty or State.weakAuraSlowElapsed >= 0.20 then
            State.weakAuraDirty = false
            State.weakAuraSlowElapsed = 0
            if UpdateWeakAurasBinding then UpdateWeakAurasBinding() end
        end
    end

    if profileStart then ProfilerAdd("OnUpdate", profileStart) end
end

A:SetScript("OnEvent", S2KNP_OnEvent)
S2KNP_RegisterBaseEvents()
S2KNP_ApplyModuleRuntimeScript()
