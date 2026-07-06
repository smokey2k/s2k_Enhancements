-- =========================================================
-- s2k:Enhancements - Dominos 7.3.5 integration
--
-- The integration has two deliberately asymmetric states:
--   LOCKED   - Dominos owns the normal action-bar positions and show states.
--   EDITABLE - selected action bars are temporarily arranged in screen-aware
--              rows or columns, and their Dominos show states are cleared.
--
-- When EDITABLE is entered, the current Dominos position, docking information
-- and show state of every selected bar are captured. Returning to LOCKED (or
-- disabling the integration) restores those values exactly. Protected frames
-- are never modified during combat; requested changes are applied afterwards.
-- =========================================================

DOMINOS_FALLBACK_ACTION_BAR_COUNT = 10
DOMINOS_MAX_ACTION_BAR_COUNT = 60

DOMINOS_LAYOUT_MODE_OPTIONS = {
    { key = "LOCKED", label = "Dominos" },
    { key = "EDITABLE", label = "Editable" },
}

DOMINOS_EDIT_DIRECTION_OPTIONS = {
    { key = "HORIZONTAL", label = "Side by side" },
    { key = "VERTICAL", label = "One below another" },
}

function GetDominosAddonObject()
    if _G.Dominos and type(_G.Dominos) == "table" then
        return _G.Dominos
    end

    if LibStub then
        local aceAddon = LibStub("AceAddon-3.0", true)
        if aceAddon and aceAddon.GetAddon then
            local ok, addon = pcall(aceAddon.GetAddon, aceAddon, "Dominos", true)
            if ok and type(addon) == "table" then
                return addon
            end
        end
    end

    return nil
end

function GetDominosActionBarFrame(index)
    index = tonumber(index)
    if not index then return nil end

    local frame = _G["DominosFrame" .. tostring(index)]
    if frame then
        return frame
    end

    local addon = GetDominosAddonObject()
    if addon and addon.Frame and addon.Frame.Get then
        local ok, result = pcall(addon.Frame.Get, addon.Frame, index)
        if ok and result then
            return result
        end
    end

    return nil
end

function GetDominosActionBarCount(forceRefresh)
    if not forceRefresh and State.dominosActionBarCount then
        return State.dominosActionBarCount
    end

    local addon = GetDominosAddonObject()
    local configuredCount
    local highestFrame = 0

    if addon and addon.db and addon.db.profile and addon.db.profile.ab then
        configuredCount = tonumber(addon.db.profile.ab.count)
    end

    if addon and addon.Frame and addon.Frame.GetAll then
        local ok, iterator, state, first = pcall(addon.Frame.GetAll, addon.Frame)
        if ok and type(iterator) == "function" then
            for id in iterator, state, first do
                local numericId = tonumber(id)
                if numericId and numericId > highestFrame and numericId == math.floor(numericId) then
                    highestFrame = numericId
                end
            end
        end
    end

    -- Some Dominos builds do not expose the AceDB profile until OnEnable has
    -- completed. The named frames are a safe fallback once they exist.
    if highestFrame == 0 then
        for i = 1, DOMINOS_MAX_ACTION_BAR_COUNT do
            if _G["DominosFrame" .. tostring(i)] then
                highestFrame = i
            end
        end
    end

    local count = math.max(tonumber(configuredCount) or 0, highestFrame)
    if count < 1 then
        count = DOMINOS_FALLBACK_ACTION_BAR_COUNT
    end

    count = math.floor(count)
    if count > DOMINOS_MAX_ACTION_BAR_COUNT then
        count = DOMINOS_MAX_ACTION_BAR_COUNT
    end

    State.dominosActionBarCount = count
    return count
end

function GetDominosCompatibilityStatus()
    local loaded = false
    if IsAddOnLoaded then
        loaded = IsAddOnLoaded("Dominos") and true or false
    end

    local addon = GetDominosAddonObject()
    if not loaded and addon then
        loaded = true
    end

    if not loaded then
        return false, "Dominos was not detected; this integration is disabled."
    end

    local count = GetDominosActionBarCount(true)
    local frame
    for i = 1, count do
        frame = GetDominosActionBarFrame(i)
        if frame then break end
    end

    if not frame then
        return false, "Dominos is loaded, but its action-bar frames are not ready; this integration is disabled until Dominos finishes loading."
    end

    local supportsStates = frame.SetShowStates
        or frame.SetUserDisplayConditions
        or (frame.sets and frame.UpdateShowStates)

    if not supportsStates then
        return false, "Dominos was detected, but this version does not expose a compatible show-state API."
    end

    return true, "Dominos detected and compatible."
end

function CopyDominosFrameSnapshot(snapshot)
    if type(snapshot) ~= "table" then return nil end
    return {
        point = snapshot.point,
        x = snapshot.x,
        y = snapshot.y,
        anchor = snapshot.anchor,
        showStates = snapshot.showStates,
    }
end

function EnsureDominosSettingsTables(forceCountRefresh)
    if type(DB) ~= "table" or type(CFG) ~= "table" then return 0 end

    if type(DB.dominosBars) ~= "table" then
        DB.dominosBars = {}
    end

    local count = GetDominosActionBarCount(forceCountRefresh)
    for i = 1, count do
        local settings = DB.dominosBars[i]
        if type(settings) ~= "table" then
            settings = {}
            DB.dominosBars[i] = settings
        end
        settings.anchored = settings.anchored and true or false
    end

    -- Remove fields created by the abandoned 1.17.0 show-state editor once.
    if not DB.dominosLegacyInputsRemoved then
        for _, settings in pairs(DB.dominosBars) do
            if type(settings) == "table" then settings.showStates = nil end
        end
        DB.dominosLegacyInputsRemoved = true
    end

    local mode = tostring(DB.dominosLayoutMode or "LOCKED"):upper()
    if mode ~= "LOCKED" and mode ~= "EDITABLE" then
        mode = "LOCKED"
    end
    DB.dominosLayoutMode = mode

    local direction = tostring(DB.dominosEditableDirection or "HORIZONTAL"):upper()
    if direction ~= "HORIZONTAL" and direction ~= "VERTICAL" then
        direction = "HORIZONTAL"
    end
    DB.dominosEditableDirection = direction
    DB.dominosIntegrationEnabled = DB.dominosIntegrationEnabled and true or false

    if type(DB.dominosEditSession) ~= "table" then
        DB.dominosEditSession = { active = false, bars = {} }
    end
    if type(DB.dominosEditSession.bars) ~= "table" then
        DB.dominosEditSession.bars = {}
    end
    DB.dominosEditSession.active = DB.dominosEditSession.active and true or false

    -- One-time migration from the original 1.17.0 implementation. Its
    -- dominosOriginalFrames table already contains the values needed to undo
    -- the accidentally inverted/stacked layout, so adopt it as an active edit
    -- session. LOCKED mode will restore it on the first apply.
    if not DB.dominosWorkflowV2Migrated then
        if type(DB.dominosOriginalFrames) == "table" and next(DB.dominosOriginalFrames) then
            DB.dominosEditSession.active = true
            DB.dominosEditSession.bars = {}
            for index, snapshot in pairs(DB.dominosOriginalFrames) do
                local numericIndex = tonumber(index)
                if numericIndex and type(snapshot) == "table" then
                    DB.dominosEditSession.bars[numericIndex] = CopyDominosFrameSnapshot(snapshot)
                end
            end
        end

        DB.dominosOriginalFrames = nil
        DB.dominosAnchorParent = nil
        DB.dominosWorkflowV2Migrated = true
    end

    CFG.dominosBars = DB.dominosBars
    CFG.dominosLayoutMode = DB.dominosLayoutMode
    CFG.dominosEditableDirection = DB.dominosEditableDirection
    CFG.dominosIntegrationEnabled = DB.dominosIntegrationEnabled
    CFG.dominosEditSession = DB.dominosEditSession
    CFG.dominosActionBarCount = count
    return count
end

function GetDominosBarSettings(index)
    if not CFG.dominosBars then EnsureDominosSettingsTables() end
    index = tonumber(index)
    if not index or not CFG or type(CFG.dominosBars) ~= "table" then
        return nil
    end
    return CFG.dominosBars[index]
end

function GetDominosFrameShowStates(frame)
    if not frame then return "" end

    if frame.GetShowStates then
        local ok, value = pcall(frame.GetShowStates, frame)
        if ok then return tostring(value or "") end
    end

    if frame.GetUserDisplayConditions then
        local ok, value = pcall(frame.GetUserDisplayConditions, frame)
        if ok then return tostring(value or "") end
    end

    if frame.sets then
        return tostring(frame.sets.showstates or "")
    end

    return ""
end

function SetDominosFrameShowStates(frame, states)
    if not frame then
        return false, "Dominos frame is unavailable."
    end

    states = tostring(states or "")
    local previous = GetDominosFrameShowStates(frame)
    local ok, err

    if frame.SetShowStates then
        ok, err = pcall(frame.SetShowStates, frame, states)
    elseif frame.SetUserDisplayConditions then
        ok, err = pcall(frame.SetUserDisplayConditions, frame, states)
    elseif frame.sets and frame.UpdateShowStates then
        frame.sets.showstates = states
        ok, err = pcall(frame.UpdateShowStates, frame)
    else
        return false, "This Dominos frame has no compatible show-state API."
    end

    if not ok then
        if frame.sets then
            frame.sets.showstates = previous ~= "" and previous or nil
        end

        if frame.SetShowStates then
            pcall(frame.SetShowStates, frame, previous)
        elseif frame.SetUserDisplayConditions then
            pcall(frame.SetUserDisplayConditions, frame, previous)
        elseif frame.UpdateShowStates then
            pcall(frame.UpdateShowStates, frame)
        end

        return false, tostring(err or "Unknown Dominos show-state error.")
    end

    return true
end

function CaptureDominosFrameSnapshot(index)
    local frame = GetDominosActionBarFrame(index)
    if not frame then return nil end

    local point, x, y = "CENTER", 0, 0
    if frame.GetSavedFramePosition then
        local ok, p, px, py = pcall(frame.GetSavedFramePosition, frame)
        if ok then
            point = tostring(p or "CENTER")
            x = tonumber(px) or 0
            y = tonumber(py) or 0
        end
    else
        local p, _, _, px, py = frame:GetPoint(1)
        point = tostring(p or "CENTER")
        x = tonumber(px) or 0
        y = tonumber(py) or 0
    end

    return {
        point = point,
        x = x,
        y = y,
        anchor = frame.sets and frame.sets.anchor or nil,
        showStates = GetDominosFrameShowStates(frame),
    }
end

function ApplyDominosFrameSnapshot(index, snapshot, restoreShowStates)
    local frame = GetDominosActionBarFrame(index)
    if not frame or type(snapshot) ~= "table" then
        return nil
    end

    if frame.sets then
        frame.sets.point = (snapshot.point and snapshot.point ~= "CENTER") and snapshot.point or nil
        frame.sets.x = (tonumber(snapshot.x) or 0) ~= 0 and tonumber(snapshot.x) or nil
        frame.sets.y = (tonumber(snapshot.y) or 0) ~= 0 and tonumber(snapshot.y) or nil
        frame.sets.anchor = snapshot.anchor
    end

    if frame.Reposition then
        pcall(frame.Reposition, frame)
    else
        frame:ClearAllPoints()
        frame:SetPoint(snapshot.point or "CENTER", UIParent, snapshot.point or "CENTER", tonumber(snapshot.x) or 0, tonumber(snapshot.y) or 0)
    end

    if restoreShowStates then
        SetDominosFrameShowStates(frame, snapshot.showStates or "")
    end

    return frame
end

function RestoreDominosSnapshots(snapshots, restoreShowStates)
    if type(snapshots) ~= "table" then return true end

    local restored = {}
    for index, snapshot in pairs(snapshots) do
        local numericIndex = tonumber(index)
        if numericIndex and type(snapshot) == "table" then
            local frame = ApplyDominosFrameSnapshot(numericIndex, snapshot, restoreShowStates)
            if frame then
                restored[numericIndex] = frame
            end
        end
    end

    -- Recreate Dominos docking only after every selected frame has received its
    -- saved base coordinates. This avoids ordering problems in dock chains.
    for index, frame in pairs(restored) do
        local snapshot = snapshots[index]
        if snapshot and snapshot.anchor and frame.Reanchor then
            pcall(frame.Reanchor, frame)
        end
    end

    return true
end

function ClearDominosFrameAnchor(frame)
    if not frame then return end
    if frame.ClearAnchor then
        pcall(frame.ClearAnchor, frame)
    elseif frame.sets then
        frame.sets.anchor = nil
    end
end

function PositionDominosFrame(frame, point, relativeFrame, relativePoint, x, y)
    if not frame or not relativeFrame then return false end
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeFrame, relativePoint, x or 0, y or 0)
    return true
end

function GetSelectedDominosBars()
    EnsureDominosSettingsTables()
    local selected = {}
    local count = GetDominosActionBarCount()

    for i = 1, count do
        local bar = CFG.dominosBars[i]
        if bar and bar.anchored and GetDominosActionBarFrame(i) then
            selected[#selected + 1] = i
        end
    end

    table.sort(selected)
    return selected
end


function GetDominosLayoutDisplayName(mode)
    mode = tostring(mode or (CFG and CFG.dominosLayoutMode) or "LOCKED"):upper()
    return mode == "EDITABLE" and "Editable" or "Dominos"
end

function CanToggleDominosLayoutFromLauncher()
    EnsureDominosSettingsTables()

    local compatible, reason = GetDominosCompatibilityStatus()
    if not compatible then
        return false, reason or "Dominos is unavailable."
    end

    if not CFG or CFG.dominosIntegrationEnabled ~= true then
        return false, "The Dominos integration is disabled."
    end

    local selected = GetSelectedDominosBars()
    if #selected == 0 then
        return false, "No anchored Dominos action bars are selected."
    end

    local mode = tostring(CFG.dominosLayoutMode or "LOCKED"):upper()
    if mode ~= "EDITABLE" then mode = "LOCKED" end
    return true, mode, selected
end

function ToggleDominosLayoutMode(source, silent)
    local available, modeOrReason = CanToggleDominosLayoutFromLauncher()
    if not available then
        if not silent then
            print("s2k:Enhancements: " .. tostring(modeOrReason or "Dominos layout switching is unavailable."))
        end
        return false
    end

    local nextMode = modeOrReason == "EDITABLE" and "LOCKED" or "EDITABLE"
    CFG.dominosLayoutMode = nextMode
    DB.dominosLayoutMode = nextMode

    if RequestDominosApply then
        RequestDominosApply()
    elseif ApplyDominosIntegration then
        ApplyDominosIntegration(false)
    end

    RefreshDominosOptionsControls()

    if not silent then
        local suffix = (State and State.pendingDominosApply) and " (waiting for combat to end)" or ""
        print("s2k:Enhancements Dominos layout: " .. GetDominosLayoutDisplayName(nextMode) .. suffix)
    end

    return true, nextMode
end

if API then
    API.ToggleDominosLayoutMode = ToggleDominosLayoutMode
    API.CanToggleDominosLayoutFromLauncher = CanToggleDominosLayoutFromLauncher
end

function GetDominosPersistentEditSession()
    EnsureDominosSettingsTables()
    return DB and DB.dominosEditSession or nil
end

function ClearDominosSessionStorage(session)
    if type(session) ~= "table" then return end
    session.active = false
    session.bars = {}
end

function GetOrAdoptDominosRuntimeEditSession()
    local persistent = GetDominosPersistentEditSession()
    if not persistent then return nil end

    local runtime = State and State.dominosRuntimeEditSession
    if runtime and runtime.active and runtime.dbRef == DB then
        return runtime
    end

    if persistent.active and type(persistent.bars) == "table" and next(persistent.bars) then
        runtime = {
            active = true,
            bars = persistent.bars,
            dbRef = DB,
        }
        State.dominosRuntimeEditSession = runtime
        return runtime
    end

    return nil
end

function RestoreDominosRuntimeEditSession()
    local runtime = State and State.dominosRuntimeEditSession
    if runtime and runtime.active then
        RestoreDominosSnapshots(runtime.bars, true)
        if runtime.dbRef and type(runtime.dbRef.dominosEditSession) == "table" then
            ClearDominosSessionStorage(runtime.dbRef.dominosEditSession)
        end
        State.dominosRuntimeEditSession = nil
        return true
    end

    local persistent = DB and DB.dominosEditSession
    if persistent and persistent.active then
        RestoreDominosSnapshots(persistent.bars, true)
        ClearDominosSessionStorage(persistent)
        if CFG then CFG.dominosEditSession = persistent end
        return true
    end

    return false
end

function StartDominosEditableSession(selected)
    local persistent = GetDominosPersistentEditSession()
    if not persistent then return nil end

    local runtime = GetOrAdoptDominosRuntimeEditSession()
    if not runtime then
        persistent.active = true
        persistent.bars = {}
        runtime = {
            active = true,
            bars = persistent.bars,
            dbRef = DB,
        }
        State.dominosRuntimeEditSession = runtime
    end

    local selectedMap = {}
    for _, index in ipairs(selected) do
        selectedMap[index] = true
    end

    -- Bars unchecked while EDITABLE is active are immediately returned to
    -- their own Dominos position/show state and removed from the session.
    local toRemove = {}
    for index, snapshot in pairs(runtime.bars) do
        local numericIndex = tonumber(index)
        if numericIndex and not selectedMap[numericIndex] then
            ApplyDominosFrameSnapshot(numericIndex, snapshot, true)
            local frame = GetDominosActionBarFrame(numericIndex)
            if frame and snapshot.anchor and frame.Reanchor then
                pcall(frame.Reanchor, frame)
            end
            toRemove[#toRemove + 1] = index
        end
    end
    for _, index in ipairs(toRemove) do
        runtime.bars[index] = nil
    end

    -- Capture newly selected bars exactly as Dominos currently owns them.
    for _, index in ipairs(selected) do
        if type(runtime.bars[index]) ~= "table" then
            runtime.bars[index] = CaptureDominosFrameSnapshot(index)
        end
    end

    persistent.active = next(runtime.bars) and true or false
    persistent.bars = runtime.bars
    runtime.active = persistent.active
    CFG.dominosEditSession = persistent

    if not runtime.active then
        State.dominosRuntimeEditSession = nil
        return nil
    end

    return runtime
end

function GetDominosScreenSize()
    local width = UIParent and UIParent.GetWidth and tonumber(UIParent:GetWidth()) or 0
    local height = UIParent and UIParent.GetHeight and tonumber(UIParent:GetHeight()) or 0

    if width <= 0 then width = 1920 end
    if height <= 0 then height = 1080 end

    return width, height
end

function GetDominosFrameScreenSize(frame)
    if not frame then return 1, 1 end

    -- GetLeft/GetRight/GetTop/GetBottom are already expressed in UIParent
    -- coordinates and therefore account for the frame's current scale.
    local left = frame.GetLeft and tonumber(frame:GetLeft()) or nil
    local right = frame.GetRight and tonumber(frame:GetRight()) or nil
    local top = frame.GetTop and tonumber(frame:GetTop()) or nil
    local bottom = frame.GetBottom and tonumber(frame:GetBottom()) or nil

    local width = left and right and math.abs(right - left) or nil
    local height = top and bottom and math.abs(top - bottom) or nil

    if not width or width <= 0 or not height or height <= 0 then
        local frameScale = frame.GetEffectiveScale and tonumber(frame:GetEffectiveScale()) or (frame.GetScale and tonumber(frame:GetScale())) or 1
        local parentScale = UIParent and UIParent.GetEffectiveScale and tonumber(UIParent:GetEffectiveScale()) or 1
        if not parentScale or parentScale == 0 then parentScale = 1 end
        local scale = (frameScale or 1) / parentScale

        if not width or width <= 0 then
            width = (frame.GetWidth and tonumber(frame:GetWidth()) or 1) * scale
        end
        if not height or height <= 0 then
            height = (frame.GetHeight and tonumber(frame:GetHeight()) or 1) * scale
        end
    end

    return math.max(1, width or 1), math.max(1, height or 1)
end

function BuildDominosSequentialTracks(items, primaryLimit, primaryField, secondaryField)
    local tracks = {}
    local current
    local totalSecondary = 0
    local oversizedItem = false

    -- Preserve numeric order and fill each row/column with as many consecutive
    -- bars as fit before starting the next one.
    for _, item in ipairs(items) do
        local primary = tonumber(item[primaryField]) or 1
        local secondary = tonumber(item[secondaryField]) or 1

        if not current or (#current.items > 0 and current.primary + primary > primaryLimit + 0.5) then
            current = {
                items = {},
                primary = 0,
                secondary = 0,
            }
            tracks[#tracks + 1] = current
        end

        current.items[#current.items + 1] = item
        current.primary = current.primary + primary
        current.secondary = math.max(current.secondary, secondary)

        if primary > primaryLimit + 0.5 then
            oversizedItem = true
        end
    end

    for _, track in ipairs(tracks) do
        totalSecondary = totalSecondary + track.secondary
    end

    return tracks, totalSecondary, oversizedItem
end

function ClampDominosLayoutValue(value, minimum, maximum)
    value = tonumber(value) or minimum
    if maximum < minimum then return minimum end
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function ArrangeDominosBarsEditable(selected, direction)
    if #selected == 0 then
        return false, "Select at least one action bar in the Anchored column."
    end

    direction = tostring(direction or "HORIZONTAL"):upper()
    local firstFrame = GetDominosActionBarFrame(selected[1])
    if not firstFrame then
        return false, "The first selected Dominos action bar is unavailable."
    end

    local screenWidth, screenHeight = GetDominosScreenSize()
    local items = {}
    local totalWidth = 0
    local totalHeight = 0

    for _, index in ipairs(selected) do
        local frame = GetDominosActionBarFrame(index)
        if frame then
            local width, height = GetDominosFrameScreenSize(frame)
            items[#items + 1] = {
                index = index,
                frame = frame,
                width = width,
                height = height,
            }
            totalWidth = totalWidth + width
            totalHeight = totalHeight + height
        end
    end

    if #items == 0 then
        return false, "The selected Dominos action bars are unavailable."
    end

    local firstLeft = firstFrame.GetLeft and tonumber(firstFrame:GetLeft()) or nil
    local firstTop = firstFrame.GetTop and tonumber(firstFrame:GetTop()) or nil
    local needsWrap

    if direction == "VERTICAL" then
        local projectedTop = firstTop or screenHeight
        local projectedBottom = projectedTop - totalHeight
        needsWrap = totalHeight > screenHeight + 0.5
            or projectedTop > screenHeight + 0.5
            or projectedBottom < -0.5
    else
        local projectedLeft = firstLeft or 0
        local projectedRight = projectedLeft + totalWidth
        needsWrap = totalWidth > screenWidth + 0.5
            or projectedLeft < -0.5
            or projectedRight > screenWidth + 0.5
    end

    if not needsWrap then
        -- When the full row/column fits, preserve the original position of the
        -- first selected bar and append the remaining bars exactly as before.
        local previous = firstFrame
        for position = 2, #items do
            local frame = items[position].frame
            ClearDominosFrameAnchor(frame)
            if direction == "VERTICAL" then
                PositionDominosFrame(frame, "TOP", previous, "BOTTOM", 0, 0)
            else
                PositionDominosFrame(frame, "LEFT", previous, "RIGHT", 0, 0)
            end
            previous = frame
        end

        return true, nil, {
            wrapped = false,
            tracks = 1,
            overflow = false,
        }
    end

    -- Wrapped layouts are anchored to the screen rather than to a Dominos bar.
    -- Horizontal mode starts at the left edge and creates additional rows.
    -- Vertical mode starts at the top edge and creates additional columns.
    local tracks
    local secondarySize
    local oversizedItem
    if direction == "VERTICAL" then
        tracks, secondarySize, oversizedItem = BuildDominosSequentialTracks(items, screenHeight, "height", "width")
    else
        tracks, secondarySize, oversizedItem = BuildDominosSequentialTracks(items, screenWidth, "width", "height")
    end

    for _, item in ipairs(items) do
        ClearDominosFrameAnchor(item.frame)
    end

    local secondaryOverflow
    if direction == "VERTICAL" then
        secondaryOverflow = secondarySize > screenWidth + 0.5

        -- Keep the original horizontal area where possible, but always start
        -- the first bar at the top edge. Clamp the complete column group so it
        -- remains on screen.
        local startLeft = 0
        if secondarySize <= screenWidth then
            startLeft = ClampDominosLayoutValue(firstLeft or 0, 0, screenWidth - secondarySize)
        end

        local columnOffset = 0
        for _, track in ipairs(tracks) do
            local previous
            for position, item in ipairs(track.items) do
                if position == 1 then
                    PositionDominosFrame(item.frame, "TOPLEFT", UIParent, "TOPLEFT", startLeft + columnOffset, 0)
                else
                    PositionDominosFrame(item.frame, "TOPLEFT", previous, "BOTTOMLEFT", 0, 0)
                end
                previous = item.frame
            end
            columnOffset = columnOffset + track.secondary
        end
    else
        secondaryOverflow = secondarySize > screenHeight + 0.5

        -- Start the first bar at the left screen edge. Preserve its original
        -- vertical area when the wrapped group fits, otherwise use the top edge
        -- as the best possible layout origin.
        local startTop = screenHeight
        if secondarySize <= screenHeight then
            startTop = ClampDominosLayoutValue(firstTop or screenHeight, secondarySize, screenHeight)
        end
        local startYOffset = startTop - screenHeight

        local rowOffset = 0
        for _, track in ipairs(tracks) do
            local previous
            for position, item in ipairs(track.items) do
                if position == 1 then
                    PositionDominosFrame(item.frame, "TOPLEFT", UIParent, "TOPLEFT", 0, startYOffset - rowOffset)
                else
                    PositionDominosFrame(item.frame, "TOPLEFT", previous, "TOPRIGHT", 0, 0)
                end
                previous = item.frame
            end
            rowOffset = rowOffset + track.secondary
        end
    end

    return true, nil, {
        wrapped = true,
        tracks = #tracks,
        overflow = oversizedItem or secondaryOverflow,
    }
end

function ApplyDominosEditableMode()
    local selected = GetSelectedDominosBars()
    local runtime = StartDominosEditableSession(selected)

    if #selected == 0 then
        RestoreDominosRuntimeEditSession()
        return false, "Editable mode is selected, but no action bars are checked in the Anchored column."
    end

    if not runtime then
        return false, "The temporary Dominos edit session could not be created."
    end

    -- Always begin from the captured Dominos layout before calculating the row
    -- or column. This prevents cumulative drift when alignment or selections
    -- are changed repeatedly.
    RestoreDominosSnapshots(runtime.bars, true)

    local firstError
    for _, index in ipairs(selected) do
        local frame = GetDominosActionBarFrame(index)
        if frame then
            local ok, err = SetDominosFrameShowStates(frame, "")
            if not ok and not firstError then
                firstError = "Action Bar " .. tostring(index) .. ": " .. tostring(err or "show state could not be cleared")
            end
        end
    end

    local ok, layoutError, layoutInfo = ArrangeDominosBarsEditable(selected, CFG.dominosEditableDirection)
    if not ok then
        return false, layoutError
    end

    if firstError then
        return false, "The editable layout was applied, but a show state could not be cleared: " .. firstError
    end

    return true, layoutInfo
end

function RefreshDominosOptionsControls()
    if State and State.dominosOptionsPage and State.dominosOptionsPage.IsShown and State.dominosOptionsPage:IsShown() then
        local old = State.optionsRefreshing
        State.optionsRefreshing = true
        for _, control in ipairs(State.dominosOptionsPage.s2kRefreshables or {}) do
            if control and control.Refresh then
                control:Refresh()
            end
        end
        State.optionsRefreshing = old
    end

    if RefreshAddonsOptionsAvailability then
        RefreshAddonsOptionsAvailability()
    end
end


function GetDominosIntegrationStatusText()
    local compatible, reason = GetDominosCompatibilityStatus()
    if not compatible then
        return reason or "Dominos is unavailable."
    end

    if not CFG or CFG.dominosIntegrationEnabled ~= true then
        return "Dominos integration is disabled. Dominos positions and show states are left unchanged."
    end

    if State and State.pendingDominosApply then
        return "Dominos changes are waiting for combat to end."
    end

    if State and State.dominosStatusText and State.dominosStatusText ~= "" then
        return State.dominosStatusText
    end

    local mode = tostring(CFG.dominosLayoutMode or "LOCKED")
    if mode == "EDITABLE" then
        return "Editable mode is active. Selected bars are arranged for editing and their Dominos show states are temporarily cleared."
    end

    return "Dominos mode is active. Dominos owns the normal bar positions and show states."
end

function ApplyDominosIntegration(force)
    EnsureDominosSettingsTables()

    if IsInCombat and IsInCombat() then
        State.pendingDominosApply = true
        State.dominosStatusText = "Dominos changes are waiting for combat to end."
        RefreshDominosOptionsControls()
        return false
    end

    local compatible, reason = GetDominosCompatibilityStatus()
    if not compatible then
        State.pendingDominosApply = false
        State.dominosStatusText = reason or "Dominos is unavailable."
        State.dominosStatusError = true
        RefreshDominosOptionsControls()
        return false
    end

    State.pendingDominosApply = false
    State.dominosStatusError = false

    -- A profile may have been changed while the previous profile was in
    -- EDITABLE mode. Restore that runtime session before applying the new DB.
    local runtime = State.dominosRuntimeEditSession
    if runtime and runtime.active and runtime.dbRef ~= DB then
        RestoreDominosRuntimeEditSession()
    end

    if CFG.dominosIntegrationEnabled ~= true then
        RestoreDominosRuntimeEditSession()
        State.dominosStatusText = "Dominos integration is disabled. Dominos positions and show states were restored."
        RefreshDominosOptionsControls()
        return true
    end

    local mode = tostring(CFG.dominosLayoutMode or "LOCKED"):upper()
    if mode == "EDITABLE" then
        local ok, result = ApplyDominosEditableMode()
        local layoutInfo = ok and result or nil
        State.dominosStatusError = not ok or (layoutInfo and layoutInfo.overflow) or false
        if ok then
            local direction = tostring(CFG.dominosEditableDirection or "HORIZONTAL"):upper()
            local arrangement = direction == "VERTICAL" and "one below another" or "side by side"
            State.dominosStatusText = "Editable mode applied. Selected bars are arranged " .. arrangement .. ", and their Dominos show states are temporarily cleared."
            if layoutInfo and layoutInfo.wrapped then
                local unit = direction == "VERTICAL" and "columns" or "rows"
                State.dominosStatusText = State.dominosStatusText .. " The bars were wrapped into " .. tostring(layoutInfo.tracks or 1) .. " " .. unit .. " to keep them on screen."
            end
            if layoutInfo and layoutInfo.overflow then
                State.dominosStatusText = State.dominosStatusText .. " At least one bar or the complete wrapped group is larger than the available screen area, so a fully visible layout is mathematically impossible without resizing the bars."
            end
        else
            State.dominosStatusText = tostring(result or "Dominos editable mode could not be applied.")
        end
        RefreshDominosOptionsControls()
        return ok
    end

    RestoreDominosRuntimeEditSession()
    State.dominosStatusText = "Dominos mode applied. Original Dominos positions and show states were restored."
    State.dominosStatusError = false
    RefreshDominosOptionsControls()
    return true
end

function RequestDominosApply()
    EnsureDominosSettingsTables()
    if IsInCombat and IsInCombat() then
        State.pendingDominosApply = true
        State.dominosStatusText = "Dominos changes are waiting for combat to end."
        RefreshDominosOptionsControls()
        return
    end

    ApplyDominosIntegration(false)
end

function ScheduleDominosIntegrationApply()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if DB then ApplyDominosIntegration(false) end
        end)
        C_Timer.After(0.5, function()
            if DB then ApplyDominosIntegration(false) end
        end)
    else
        ApplyDominosIntegration(false)
    end
end

function SetDominosBarAnchored(index, enabled)
    EnsureDominosSettingsTables()
    index = tonumber(index)
    if not index or not CFG.dominosBars[index] then return end

    CFG.dominosBars[index].anchored = enabled and true or false
    DB.dominosBars[index].anchored = CFG.dominosBars[index].anchored
    RequestDominosApply()
end
