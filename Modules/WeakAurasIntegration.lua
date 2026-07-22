-- =========================================================
-- WeakAuras region integration
-- =========================================================

function ParseWeakAuraVersion(versionText)
    versionText = tostring(versionText or "")
    local major, minor, patch = versionText:match("(%d+)%.(%d+)%.(%d+)")
    return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
end

function WeakAuraVersionAtLeast(versionText, reqMajor, reqMinor, reqPatch)
    local major, minor, patch = ParseWeakAuraVersion(versionText)

    if major ~= reqMajor then
        return major > reqMajor
    end

    if minor ~= reqMinor then
        return minor > reqMinor
    end

    return patch >= reqPatch
end

function FindWeakAurasAddonName()
    -- Do not assume the folder is exactly "WeakAuras". Some 7.3.5/private
    -- server packages keep versioned folder names or localized titles. The
    -- real runtime signal is the global WeakAuras table, but this helper lets
    -- us query metadata from whatever addon entry looks like the WA core.
    if not GetNumAddOns or not GetAddOnInfo then
        return nil
    end

    local exactLoaded = nil
    local weakLoaded = nil
    local weakAny = nil

    for i = 1, GetNumAddOns() do
        local name, title = GetAddOnInfo(i)
        name = tostring(name or "")
        title = tostring(title or "")

        local lname = name:lower()
        local ltitle = title:lower()
        local looksLikeWeakAuras = false

        if lname == "weakauras" then
            looksLikeWeakAuras = true
        elseif lname:match("^weakauras[%-%_%.]?") and not lname:find("options") and not lname:find("companion") then
            looksLikeWeakAuras = true
        elseif ltitle:find("weakauras", 1, true) and not ltitle:find("options", 1, true) and not ltitle:find("companion", 1, true) then
            looksLikeWeakAuras = true
        end

        if looksLikeWeakAuras then
            weakAny = weakAny or name
            if IsAddOnLoaded and IsAddOnLoaded(name) then
                weakLoaded = weakLoaded or name
                if lname == "weakauras" then
                    exactLoaded = name
                end
            end
        end
    end

    return exactLoaded or weakLoaded or weakAny
end

function GetWeakAurasInstalledVersionText(addonName)
    local candidates = {}

    local function add(value)
        value = tostring(value or "")
        if value ~= "" then
            candidates[#candidates + 1] = value
        end
    end

    local WA = _G.WeakAuras
    if WA then
        add(WA.versionString)
        add(WA.version)
        add(WA.Version)
        add(WA.revision)
        add(WA.build)
    end

    if GetAddOnMetadata then
        addonName = addonName or FindWeakAurasAddonName() or "WeakAuras"
        add(GetAddOnMetadata(addonName, "Version"))
        add(GetAddOnMetadata(addonName, "X-WeakAuras-Version"))
        add(GetAddOnMetadata(addonName, "X-Curse-Packaged-Version"))
        add(GetAddOnMetadata(addonName, "Title"))
        add(addonName)
    end

    for _, value in ipairs(candidates) do
        if ParseWeakAuraVersion(value) >= 2 then
            return value
        end
    end

    return candidates[1] or ""
end

function GetWeakAurasCompatibilityStatus()
    local wowVersion = GetBuildInfo and tostring((select(1, GetBuildInfo()))) or ""
    if wowVersion ~= WEAKAURAS_REQUIRED_WOW_VERSION then
        return false, "This module is locked to WoW " .. WEAKAURAS_REQUIRED_WOW_VERSION .. ". Current client: " .. (wowVersion ~= "" and wowVersion or "unknown") .. "."
    end

    local addonName = FindWeakAurasAddonName()
    local hasLoadedAddon = false

    if IsAddOnLoaded then
        if addonName and IsAddOnLoaded(addonName) then
            hasLoadedAddon = true
        elseif IsAddOnLoaded("WeakAuras") then
            hasLoadedAddon = true
        end
    end

    -- Prefer the actual runtime global over the exact addon folder name. On some
    -- 7.3.5 builds the addon can be installed in/versioned as something other
    -- than the literal "WeakAuras" key, while _G.WeakAuras is still valid.
    if not _G.WeakAuras then
        if addonName and hasLoadedAddon then
            return false, "WeakAuras addon entry is loaded, but the WeakAuras runtime table is not ready yet. Try /reload after WeakAuras has initialized."
        end
        return false, "WeakAuras 2 addon was not detected as a loaded/running addon."
    end

    local versionText = GetWeakAurasInstalledVersionText(addonName)
    if versionText == "" then
        return false, "WeakAuras is running, but its version could not be detected. Required minimum: 2.5.12."
    end

    if not WeakAuraVersionAtLeast(versionText, WEAKAURAS_MIN_VERSION[1], WEAKAURAS_MIN_VERSION[2], WEAKAURAS_MIN_VERSION[3]) then
        return false, "WeakAuras version is too old: " .. versionText .. ". Required minimum: 2.5.12."
    end

    -- WeakAurasSaved may not exist yet if the saved-variable file was deleted
    -- and WA has not touched it in this login.  Treat the addon as compatible
    -- and create the root table lazily in WeakAuraSavedDisplays().
    return true, "WeakAuras " .. versionText .. " detected" .. (addonName and (" (addon: " .. addonName .. ")") or "") .. "."
end

function IsWeakAurasIntegrationAvailable()
    local ok = GetWeakAurasCompatibilityStatus()
    return ok and true or false
end

function GetWeakAuraRegion(id)
    id = tostring(id or "")
    if id == "" then
        return nil
    end

    local WA = _G.WeakAuras

    if WA and WA.GetRegion then
        local ok, r = pcall(WA.GetRegion, id)
        if ok and r then
            if r.GetObjectType then
                return r
            end
            if r.region and r.region.GetObjectType then
                return r.region
            end
        end
    end

    local b = WA and WA.regions and WA.regions[id]
    if b and b.region and b.region.GetObjectType then
        return b.region
    end

    return nil
end

function SafeShowFrame(frame)
    if frame and frame.Show then
        SafeCall(function() frame:Show() end)
    end
end

function SafeHideFrame(frame)
    if frame and frame.Hide then
        SafeCall(function() frame:Hide() end)
    end
end

function AnchorWeakAuraToTarget(region, ctx)
    if not region or not ctx or not ctx.health or not FrameIsVisible(ctx.health) then
        return false
    end

    -- Prepare addon-owned bridge anchors. They are UIParent children, but are
    -- attached to the custom s2k health/cast frames with SetPoint only.
    local forceAnchors = ctx.s2kWAAnchorRegion ~= region
    UpdateWAAnchors(ctx, forceAnchors)
    ctx.s2kWAAnchorRegion = region

    local healthAnchor = ctx.waHealthAnchor or ctx.health
    local bottomAnchor = healthAnchor

    if ctx.cast and FrameIsVisible(ctx.cast) and ctx.waCastAnchor and FrameIsVisible(ctx.waCastAnchor) then
        bottomAnchor = ctx.waCastAnchor
    end

    SafeCall(function()
        region:SetParent(UIParent)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", healthAnchor, "TOPLEFT", 0, 0)
        region:SetPoint("TOPRIGHT", healthAnchor, "TOPRIGHT", 0, 0)
        region:SetPoint("BOTTOMLEFT", bottomAnchor, "BOTTOMLEFT", 0, 0)
        region:SetPoint("BOTTOMRIGHT", bottomAnchor, "BOTTOMRIGHT", 0, 0)
    end)

    SafeShowFrame(region)
    return true
end

function AnchorWeakAuraToFallback(region)
    if not region then
        return false
    end

    local fallback = GetWeakAuraRegion(CFG.weakAuraFallbackId)
    if not fallback or not FrameIsVisible(fallback) then
        return false
    end

    SafeCall(function()
        region:SetParent(UIParent)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", fallback, "TOPLEFT", 0, 0)
        region:SetPoint("TOPRIGHT", fallback, "TOPRIGHT", 0, 0)
        region:SetPoint("BOTTOMLEFT", fallback, "BOTTOMLEFT", 0, 0)
        region:SetPoint("BOTTOMRIGHT", fallback, "BOTTOMRIGHT", 0, 0)
    end)

    SafeShowFrame(region)
    return true
end


function GetWeakAuraData(id)
    id = tostring(id or "")
    if id == "" then
        return nil
    end

    local WA = _G.WeakAuras

    if WA and WA.GetData then
        local ok, data = pcall(WA.GetData, id)
        if ok and data then
            return data
        end
    end

    if _G.WeakAurasSaved
    and _G.WeakAurasSaved.displays
    and _G.WeakAurasSaved.displays[id]
    then
        return _G.WeakAurasSaved.displays[id]
    end

    return nil
end

function GetWeakAuraDisplayOffset(id, key, defaultValue)
    local data = GetWeakAuraData(id)
    local value = data and data[key]

    if type(value) == "number" then
        return value
    end

    return defaultValue or 0
end

function TrimWeakAuraId(id)
    id = tostring(id or "")
    id = id:gsub("^%s+", ""):gsub("%s+$", "")
    return id
end

function GetWeakAuraTerminatorId(groupId)
    groupId = TrimWeakAuraId(groupId)
    if groupId == "" then
        return ""
    end

    return groupId .. "_Terminator"
end

function GetWeakAuraProgressBarGroupIds()
    return { FIXED_WA_TOP_GROUP_ID, FIXED_WA_BOTTOM_GROUP_ID }
end


function MarkWeakAuraScaffoldDirty()
    State.weakAuraScaffoldDirty = true
end

function WeakAuraSavedDisplays()
    if not IsWeakAurasIntegrationAvailable() then
        return nil
    end

    _G.WeakAurasSaved = _G.WeakAurasSaved or {}
    _G.WeakAurasSaved.displays = _G.WeakAurasSaved.displays or {}
    return _G.WeakAurasSaved.displays
end


function NewWeakAuraUID(id)
    local clean = tostring(id or ""):gsub("[^%w_]", "_")
    return "s2knp_" .. clean .. "_" .. tostring(math.floor((GetTime and GetTime() or 0) * 1000))
end

function NewWeakAuraLoadTable()
    return {
        talent = { multi = {} },
        role = { multi = {} },
        spec = { multi = {} },
        class = { multi = {} },
        race = { multi = {} },
        size = { multi = {} },
        difficulty = { multi = {} },
    }
end

function NewWeakAuraAnimationTable()
    return {
        start = { type = "none", duration_type = "seconds" },
        main = { type = "none", duration_type = "seconds" },
        finish = { type = "none", duration_type = "seconds" },
    }
end

function NewWeakAuraAlwaysActiveTrigger()
    -- WeakAuras 2.5.12 old schema. The exact Conditions trigger field is
    -- use_alwaystrue=true.  Do not write the newer data.triggers table here.
    return {
        type = "status",
        event = "Conditions",
        use_alwaystrue = true,
    }
end

function EnsureWeakAura25TriggerSchema(data)
    if type(data) ~= "table" then
        return false
    end

    local changed = false

    -- Newer WA schemas use data.triggers.  WA 2.5.12's CanGroupShowWithZero()
    -- expects data.numTriggers and the old top-level trigger/untrigger tables.
    if data.triggers ~= nil then
        data.triggers = nil
        changed = true
    end

    if type(data.trigger) ~= "table" then
        data.trigger = NewWeakAuraAlwaysActiveTrigger()
        changed = true
    else
        if data.trigger.type ~= "status" then
            data.trigger.type = "status"
            changed = true
        end
        if data.trigger.event ~= "Conditions" then
            data.trigger.event = "Conditions"
            changed = true
        end
        if data.trigger.use_alwaystrue ~= true then
            data.trigger.use_alwaystrue = true
            changed = true
        end
        if data.trigger.use_always ~= nil then
            data.trigger.use_always = nil
            changed = true
        end
    end

    if type(data.untrigger) ~= "table" then
        data.untrigger = {}
        changed = true
    end

    if data.numTriggers ~= 1 then
        data.numTriggers = 1
        changed = true
    end

    -- WA 2.5.12 pAdd() compares activeTriggerMode with numTriggers for
    -- non-group displays before later default-modernization can fill it.
    -- Missing activeTriggerMode was the source of:
    --   WeakAuras.lua:2431: attempt to compare number with nil
    if type(data.activeTriggerMode) ~= "number" then
        data.activeTriggerMode = 0
        changed = true
    elseif data.activeTriggerMode < 0 or data.activeTriggerMode >= data.numTriggers then
        data.activeTriggerMode = 0
        changed = true
    end

    if type(data.additional_triggers) ~= "table" then
        data.additional_triggers = {}
        changed = true
    end

    if type(data.load) ~= "table" then
        data.load = NewWeakAuraLoadTable()
        changed = true
    end

    if type(data.actions) ~= "table" then
        data.actions = { start = {}, init = {}, finish = {} }
        changed = true
    else
        data.actions.start = data.actions.start or {}
        data.actions.init = data.actions.init or {}
        data.actions.finish = data.actions.finish or {}
    end

    if type(data.animation) ~= "table" then
        data.animation = NewWeakAuraAnimationTable()
        changed = true
    end

    if type(data.conditions) ~= "table" then
        data.conditions = {}
        changed = true
    end

    if data.internalVersion ~= 3 then
        data.internalVersion = 3
        changed = true
    end

    return changed
end

function NewWeakAuraGroupData(id)
    local data = {
        id = id,
        uid = NewWeakAuraUID(id),
        regionType = "group",
        controlledChildren = {},
        load = NewWeakAuraLoadTable(),
        trigger = NewWeakAuraAlwaysActiveTrigger(),
        untrigger = {},
        numTriggers = 1,
        activeTriggerMode = 0,
        additional_triggers = {},
        xOffset = 0,
        yOffset = 0,
        width = 110,
        height = 18,
        anchorFrameType = "SCREEN",
        anchorPoint = "CENTER",
        selfPoint = "CENTER",
        frameStrata = 1,
        border = false,
        borderColor = { 1, 1, 1, 0.5 },
        backdropColor = { 1, 1, 1, 0.5 },
        borderEdge = "None",
        borderOffset = 5,
        borderInset = 11,
        borderSize = 16,
        borderBackdrop = "Blizzard Tooltip",
        expanded = false,
        actions = { start = {}, init = {}, finish = {} },
        animation = NewWeakAuraAnimationTable(),
        conditions = {},
        internalVersion = 3,
    }
    return data
end

function NewWeakAuraProgressGroupData(id, side)
    local data = NewWeakAuraGroupData(id)
    data.regionType = "dynamicgroup"
    data.width = 110
    data.height = 1
    data.anchorFrameType = "SELECTFRAME"
    data.anchorFrameFrame = "WeakAuras:" .. FIXED_WA_TARGET_ID
    data.xOffset = 0
    data.yOffset = 0
    data.grow = (side == "BOTTOM") and "DOWN" or "UP"
    data.space = 1
    data.sort = "none"
    data.animate = true
    data.align = "LEFT"
    data.stagger = 0
    data.constantFactor = "RADIUS"
    data.rotation = 0
    data.radius = 200
    data.background = "None"
    data.backgroundInset = 0

    if side == "BOTTOM" then
        data.selfPoint = "TOPLEFT"
        data.anchorPoint = "BOTTOMLEFT"
    else
        data.selfPoint = "BOTTOMLEFT"
        data.anchorPoint = "TOPLEFT"
    end

    return data
end

function NewWeakAuraInvisibleTextureData(id, parentId, width, height, r, g, b, a)
    a = tonumber(a)
    if a == nil then
        a = 0
    end

    local data = {
        id = id,
        uid = NewWeakAuraUID(id),
        parent = parentId,
        regionType = "texture",
        texture = FIXED_WA_TEXTURE,
        blendMode = "BLEND",
        color = { r or 1, g or 1, b or 1, a },
        alpha = a,
        rotate = false,
        rotation = 0,
        width = width or 1,
        height = height or 1,
        xOffset = 0,
        yOffset = 0,
        anchorFrameType = "SCREEN",
        anchorPoint = "CENTER",
        selfPoint = "CENTER",
        frameStrata = 1,
        load = NewWeakAuraLoadTable(),
        trigger = NewWeakAuraAlwaysActiveTrigger(),
        untrigger = {},
        numTriggers = 1,
        activeTriggerMode = 0,
        additional_triggers = {},
        actions = { start = {}, init = {}, finish = {} },
        animation = NewWeakAuraAnimationTable(),
        conditions = {},
        internalVersion = 3,
    }
    return data
end


function WeakAuraAddChildToGroup(displays, groupId, childId)
    groupId = TrimWeakAuraId(groupId)
    childId = TrimWeakAuraId(childId)

    if groupId == "" or childId == "" then
        return false
    end

    local group = displays and displays[groupId]
    if type(group) ~= "table" then
        return false
    end

    if type(group.controlledChildren) ~= "table" then
        group.controlledChildren = {}
    end

    for _, id in ipairs(group.controlledChildren) do
        if id == childId then
            if type(displays[childId]) == "table" then
                displays[childId].parent = groupId
            end
            return false
        end
    end

    group.controlledChildren[#group.controlledChildren + 1] = childId
    if type(displays[childId]) == "table" then
        displays[childId].parent = groupId
    end
    return true
end

function AddWeakAuraDisplayData(displays, data)
    if type(data) ~= "table" or not data.id or data.id == "" or not displays then
        return false
    end

    EnsureWeakAura25TriggerSchema(data)
    displays[data.id] = data

    -- Do not call WeakAuras.Add() here. WA 2.5.12 can keep partially-created
    -- runtime/options entries when adding nested groups in the same session.
    -- Writing the saved data and asking for a reload is safer and matches how
    -- this scaffold is meant to be created/repair-only, not continuously edited.
    State.weakAuraNeedsReload = true
    return true
end

function EnsureWeakAuraDisplay(displays, id, dataFactory)
    id = TrimWeakAuraId(id)
    if id == "" or not displays then
        return false
    end

    if type(displays[id]) == "table" then
        displays[id].id = id
        return EnsureWeakAura25TriggerSchema(displays[id])
    end

    local data = dataFactory(id)
    return AddWeakAuraDisplayData(displays, data)
end

function ShowWeakAuraReloadPopup()
    if StaticPopupDialogs then
        StaticPopupDialogs["S2K_NAMEPLATES_WA_RELOAD"] = StaticPopupDialogs["S2K_NAMEPLATES_WA_RELOAD"] or {
            text = "s2k:Enhancements WeakAuras scaffold was created or repaired. A UI reload is recommended now so WeakAuras 2.5.12 loads the new group/child structure cleanly.",
            button1 = YES,
            button2 = NO,
            OnAccept = function() ReloadUI() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("S2K_NAMEPLATES_WA_RELOAD")
    else
        S2KPrint("WeakAuras scaffold changed. Please /reload.")
    end
end

function RefreshWeakAurasAfterScaffoldChange()
    -- Deliberately do not call WeakAuras.Add(), ReloadAll(), or ScanAll here.
    -- With WA 2.5.12 nested saved-data creation is much more reliable after a
    -- normal UI reload. The button shows a Yes/No reload popup instead.
    ShowWeakAuraReloadPopup()
    return true
end


S2K_OLD_WA_IDS = {
    "PlateX_TargetFallback",
    "PlateX_Bars_Top",
    "PlateX_Bars_Bottom",
    "PlateX_Bars_Top_Terminator",
    "PlateX_Bars_Bottom_Terminator",
    "PX_Target",
    "PX_Fallback",
}

function RemoveWeakAuraChildReference(displays, childId)
    if type(displays) ~= "table" or not childId then
        return false
    end

    local changed = false
    for _, data in pairs(displays) do
        if type(data) == "table" and type(data.controlledChildren) == "table" then
            local i = 1
            while i <= #data.controlledChildren do
                if data.controlledChildren[i] == childId then
                    table.remove(data.controlledChildren, i)
                    changed = true
                else
                    i = i + 1
                end
            end
        end
    end
    return changed
end

function PurgeLegacyS2KWeakAuras(displays)
    if type(displays) ~= "table" then
        return false
    end

    local changed = false
    for _, id in ipairs(S2K_OLD_WA_IDS) do
        local data = displays[id]
        if type(data) == "table" then
            -- These names were generated by the experimental WA-dynamic builds.
            -- They can crash WA 2.5.12 if they contain a new-style triggers={}
            -- table without numTriggers. Remove them rather than trying to keep
            -- a stale scaffold alive.
            displays[id] = nil
            RemoveWeakAuraChildReference(displays, id)
            changed = true
        end
    end

    if changed then
        State.weakAuraNeedsReload = true
    end
    return changed
end

function SanitizeKnownS2KWeakAuras(displays)
    if type(displays) ~= "table" then
        return false
    end

    local changed = false
    local ids = {
        FIXED_WA_ANCHOR_GROUP_ID,
        FIXED_WA_TARGET_ID,
        FIXED_WA_FALLBACK_ID,
        FIXED_WA_TOP_GROUP_ID,
        FIXED_WA_BOTTOM_GROUP_ID,
        GetWeakAuraTerminatorId(FIXED_WA_TOP_GROUP_ID),
        GetWeakAuraTerminatorId(FIXED_WA_BOTTOM_GROUP_ID),
    }

    for _, id in ipairs(ids) do
        local data = displays[id]
        if type(data) == "table" then
            changed = EnsureWeakAura25TriggerSchema(data) or changed
            if id == FIXED_WA_ANCHOR_GROUP_ID then
                if type(data.controlledChildren) ~= "table" then
                    data.controlledChildren = {}
                    changed = true
                end
                if data.regionType ~= "group" then
                    data.regionType = "group"
                    changed = true
                end
            elseif id == FIXED_WA_TOP_GROUP_ID or id == FIXED_WA_BOTTOM_GROUP_ID then
                if type(data.controlledChildren) ~= "table" then
                    data.controlledChildren = {}
                    changed = true
                end
                if data.regionType ~= "dynamicgroup" then
                    data.regionType = "dynamicgroup"
                    changed = true
                end
                if data.anchorFrameType ~= "SELECTFRAME" then
                    data.anchorFrameType = "SELECTFRAME"
                    changed = true
                end
                local wantFrame = "WeakAuras:" .. FIXED_WA_TARGET_ID
                if data.anchorFrameFrame ~= wantFrame then
                    data.anchorFrameFrame = wantFrame
                    changed = true
                end
            else
                if data.regionType ~= "texture" then
                    data.regionType = "texture"
                    changed = true
                end
                if data.rotate ~= false then
                    data.rotate = false
                    changed = true
                end
                if data.rotation ~= 0 then
                    data.rotation = 0
                    changed = true
                end
            end
        end
    end

    -- Safety net for failed earlier experimental builds: repair any leftover
    -- s2k_NP* display that may have been generated with WA 2.6+/3.x schema
    -- or without activeTriggerMode. This intentionally only touches s2k_NP
    -- names, never the user's unrelated WeakAuras.
    for id, data in pairs(displays) do
        if type(id) == "string" and id:match("^s2k_NP") and type(data) == "table" then
            changed = EnsureWeakAura25TriggerSchema(data) or changed
            if id == FIXED_WA_ANCHOR_GROUP_ID then
                if type(data.controlledChildren) ~= "table" then
                    data.controlledChildren = {}
                    changed = true
                end
                if data.regionType ~= "group" then
                    data.regionType = "group"
                    changed = true
                end
            elseif id == FIXED_WA_TOP_GROUP_ID or id == FIXED_WA_BOTTOM_GROUP_ID then
                if type(data.controlledChildren) ~= "table" then
                    data.controlledChildren = {}
                    changed = true
                end
                if data.regionType ~= "dynamicgroup" then
                    data.regionType = "dynamicgroup"
                    changed = true
                end
                if data.anchorFrameType ~= "SELECTFRAME" then
                    data.anchorFrameType = "SELECTFRAME"
                    changed = true
                end
                local wantFrame = "WeakAuras:" .. FIXED_WA_TARGET_ID
                if data.anchorFrameFrame ~= wantFrame then
                    data.anchorFrameFrame = wantFrame
                    changed = true
                end
            else
                if data.regionType ~= "texture" then
                    data.regionType = "texture"
                    changed = true
                end
                if data.rotate ~= false then
                    data.rotate = false
                    changed = true
                end
                if data.rotation ~= 0 then
                    data.rotation = 0
                    changed = true
                end
            end
        end
    end

    if changed then
        State.weakAuraNeedsReload = true
    end
    return changed
end

function EnsureWeakAuraScaffold(force)
    if not CFG.weakAuraAutoCreate then
        return false
    end

    if not force and not CFG.weakAurasEnabled then
        return false
    end

    if not force and not State.weakAuraScaffoldDirty then
        return false
    end

    local compatible, reason = GetWeakAurasCompatibilityStatus()
    if not compatible then
        if force then
            S2KPrint(reason or "WeakAuras 2.5.12+ for WoW 7.3.5 was not detected.")
        end
        State.weakAuraScaffoldDirty = true
        return false
    end

    if IsInCombat() then
        State.weakAuraScaffoldDirty = true
        return false
    end

    ApplyFixedWeakAuraNamesToDB()
    CFG.weakAuraAnchorGroupId = DB.weakAuraAnchorGroupId
    CFG.weakAuraTargetId = DB.weakAuraTargetId
    CFG.weakAuraFallbackId = DB.weakAuraFallbackId
    CFG.weakAuraTopGroupId = DB.weakAuraTopGroupId
    CFG.weakAuraBottomGroupId = DB.weakAuraBottomGroupId
    CFG.weakAuraProgressBarGroups = DB.weakAuraProgressBarGroups

    local displays = WeakAuraSavedDisplays()
    if not displays then
        if force then
            S2KPrint("WeakAuras is not loaded, so I could not create the WA scaffold yet.")
        end
        return false
    end

    local changed = false

    changed = PurgeLegacyS2KWeakAuras(displays) or changed
    changed = SanitizeKnownS2KWeakAuras(displays) or changed

    local anchorGroupId = FIXED_WA_ANCHOR_GROUP_ID
    local targetId = FIXED_WA_TARGET_ID
    local fallbackId = FIXED_WA_FALLBACK_ID

    changed = EnsureWeakAuraDisplay(displays, anchorGroupId, function(id)
        return NewWeakAuraGroupData(id)
    end) or changed

    changed = EnsureWeakAuraDisplay(displays, targetId, function(id)
        return NewWeakAuraInvisibleTextureData(id, anchorGroupId, 110, 18, 1, 0, 0, 0)
    end) or changed
    changed = WeakAuraAddChildToGroup(displays, anchorGroupId, targetId) or changed

    changed = EnsureWeakAuraDisplay(displays, fallbackId, function(id)
        return NewWeakAuraInvisibleTextureData(id, anchorGroupId, 110, 18, 0, 1, 0, 0)
    end) or changed
    changed = WeakAuraAddChildToGroup(displays, anchorGroupId, fallbackId) or changed

    -- Progress bar scaffolding is optional: if disabled, do not create or
    -- remove anything.  If it already exists, the runtime simply leaves it alone
    -- until this option is enabled again.
    if CFG.weakAuraManageBarGroups then
        changed = EnsureWeakAuraDisplay(displays, FIXED_WA_TOP_GROUP_ID, function(id)
            return NewWeakAuraProgressGroupData(id, "TOP")
        end) or changed

        local topTerminatorId = GetWeakAuraTerminatorId(FIXED_WA_TOP_GROUP_ID)
        changed = EnsureWeakAuraDisplay(displays, topTerminatorId, function(id)
            return NewWeakAuraInvisibleTextureData(id, FIXED_WA_TOP_GROUP_ID, 1, 1, 1, 1, 1, 0)
        end) or changed
        changed = WeakAuraAddChildToGroup(displays, FIXED_WA_TOP_GROUP_ID, topTerminatorId) or changed

        changed = EnsureWeakAuraDisplay(displays, FIXED_WA_BOTTOM_GROUP_ID, function(id)
            return NewWeakAuraProgressGroupData(id, "BOTTOM")
        end) or changed

        local bottomTerminatorId = GetWeakAuraTerminatorId(FIXED_WA_BOTTOM_GROUP_ID)
        changed = EnsureWeakAuraDisplay(displays, bottomTerminatorId, function(id)
            return NewWeakAuraInvisibleTextureData(id, FIXED_WA_BOTTOM_GROUP_ID, 1, 1, 1, 1, 1, 0)
        end) or changed
        changed = WeakAuraAddChildToGroup(displays, FIXED_WA_BOTTOM_GROUP_ID, bottomTerminatorId) or changed
    end

    State.weakAuraScaffoldDirty = false

    if changed then
        RefreshWeakAurasAfterScaffoldChange()
        S2KPrint("WeakAuras scaffold created/repaired. Reload the UI so WeakAuras 2.5.12 loads it cleanly.")
    elseif force then
        S2KPrint("WeakAuras scaffold checked; all fixed s2k_NP auras already exist.")
    end

    return changed
end

function AddUniqueId(list, seen, id)
    id = tostring(id or "")
    if id == "" or seen[id] then
        return
    end

    seen[id] = true
    list[#list + 1] = id
end

function ClearWeakAuraGroupChildrenCache(cacheKey)
    State.weakAuraGroupChildrenCache = State.weakAuraGroupChildrenCache or {}

    if cacheKey then
        State.weakAuraGroupChildrenCache[cacheKey] = nil
    else
        wipe(State.weakAuraGroupChildrenCache)
    end

end

function BuildWeakAuraGroupChildIds(groupId)
    local result = {}
    local seen = {}
    local data = GetWeakAuraData(groupId)

    if data and type(data.controlledChildren) == "table" then
        for _, childId in ipairs(data.controlledChildren) do
            AddUniqueId(result, seen, childId)
        end
    end

    return result
end

function GetCachedWeakAuraGroupChildIds(cacheKey, groupId)
    groupId = tostring(groupId or "")
    if groupId == "" then
        return {}
    end

    State.weakAuraGroupChildrenCache = State.weakAuraGroupChildrenCache or {}

    local cache = State.weakAuraGroupChildrenCache[cacheKey]
    if cache and cache.groupId == groupId and type(cache.ids) == "table" then
        return cache.ids
    end

    local ids = BuildWeakAuraGroupChildIds(groupId)
    State.weakAuraGroupChildrenCache[cacheKey] = {
        groupId = groupId,
        ids = ids,
    }

    return ids
end


function PinWeakAuraChildrenLeftRight(group, childIds)
    if not group or type(childIds) ~= "table" then
        return false
    end

    for _, childId in ipairs(childIds) do
        local child = GetWeakAuraRegion(childId)

        if child and child ~= group then
            -- Do not ClearAllPoints here. The child aura may have its own vertical
            -- anchors/offsets from the WeakAuras Display tab. We only add/refresh
            -- left/right constraints so its width follows the bar group.
            SafeCall(function()
                child:SetPoint("LEFT", group, "LEFT", 0, 0)
                child:SetPoint("RIGHT", group, "RIGHT", 0, 0)
            end)
        end
    end

    return true
end

function AnchorWeakAuraTopGroupToTarget(group, targetRegion, groupId)
    if not group or not targetRegion then
        return false
    end

    local x = GetWeakAuraDisplayOffset(groupId, "xOffset", 0)
    local y = GetWeakAuraDisplayOffset(groupId, "yOffset", 0)

    SafeCall(function()
        group:SetParent(UIParent)
        group:ClearAllPoints()
        group:SetPoint("BOTTOMLEFT", targetRegion, "TOPLEFT", x, y)
        group:SetPoint("BOTTOMRIGHT", targetRegion, "TOPRIGHT", x, y)
    end)

    return true
end

function AnchorWeakAuraBottomGroupToTarget(group, targetRegion, groupId)
    if not group or not targetRegion then
        return false
    end

    local x = GetWeakAuraDisplayOffset(groupId, "xOffset", 0)
    local y = GetWeakAuraDisplayOffset(groupId, "yOffset", 0)

    SafeCall(function()
        group:SetParent(UIParent)
        group:ClearAllPoints()
        group:SetPoint("TOPLEFT", targetRegion, "BOTTOMLEFT", x, y)
        group:SetPoint("TOPRIGHT", targetRegion, "BOTTOMRIGHT", x, y)
    end)

    return true
end

function GetRegionVisualWidth(region)
    if not region then
        return nil
    end

    if region.GetWidth then
        local width = region:GetWidth()
        if width and width > 0 then
            return width
        end
    end

    if region.GetRect then
        local _, _, width = region:GetRect()
        if width and width > 0 then
            return width
        end
    end

    return nil
end

function SyncWeakAuraProgressGroupWidth(group, targetRegion, groupId)
    if not group or not targetRegion then
        return false
    end

    local width = GetRegionVisualWidth(targetRegion)
    if not width or width <= 0 then
        return false
    end

    SafeCall(function()
        if group.SetWidth then
            group:SetWidth(width)
        end
    end)

    if groupId == FIXED_WA_TOP_GROUP_ID then
        AnchorWeakAuraTopGroupToTarget(group, targetRegion, groupId)
    elseif groupId == FIXED_WA_BOTTOM_GROUP_ID then
        AnchorWeakAuraBottomGroupToTarget(group, targetRegion, groupId)
    end

    PinWeakAuraChildrenLeftRight(group, GetCachedWeakAuraGroupChildIds(groupId, groupId))
    SafeShowFrame(group)
    return true
end

function UpdateWeakAuraBarGroups(targetRegion)
    if not CFG.weakAurasEnabled or not CFG.weakAuraManageBarGroups then
        return false
    end

    if not targetRegion or not FrameIsVisible(targetRegion) then
        return false
    end

    local didSomething = false

    for _, groupId in ipairs(GetWeakAuraProgressBarGroupIds()) do
        local group = GetWeakAuraRegion(groupId)
        if group then
            didSomething = SyncWeakAuraProgressGroupWidth(group, targetRegion, groupId) or didSomething
        end
    end

    return didSomething
end

UpdateWeakAurasBinding = function()
    if not CFG.weakAurasEnabled then
        return false
    end

    if not IsWeakAurasIntegrationAvailable() then
        return false
    end

    EnsureWeakAuraScaffold(false)

    if not CFG.weakAuraTargetEnabled then
        State.weakAuraLastMode = "target-disabled"
        return false
    end

    local region = GetWeakAuraRegion(CFG.weakAuraTargetId)
    if not region then
        return false
    end

    local mode = "hidden"
    local ok = false

    local ctx = GetTargetContextCached()
    if ctx and ctx.root and FrameIsVisible(ctx.root) and ctx.health and FrameIsVisible(ctx.health) then
        mode = "target"
        ok = AnchorWeakAuraToTarget(region, ctx)
    elseif CFG.weakAuraFallbackEnabled then
        mode = "fallback"
        if CFG.debugWeakAuraAnchorStatsEnabled == true and State.weakAuraAnchorStats then
            State.weakAuraAnchorStats.fallbacks = (State.weakAuraAnchorStats.fallbacks or 0) + 1
        end
        ok = AnchorWeakAuraToFallback(region)
    end

    if ok then
        local shouldUpdateGroups = State.weakAuraBarGroupsDirty
            or State.weakAuraLastMode ~= mode
            or State.weakAuraLastTargetRegion ~= region

        if shouldUpdateGroups then
            UpdateWeakAuraBarGroups(region)
            State.weakAuraBarGroupsDirty = false
            State.weakAuraLastMode = mode
            State.weakAuraLastTargetRegion = region
        end

        return true
    end

    State.weakAuraLastMode = "hidden"
    -- Last resort: do not leave a stale PX_Target stuck on the previous plate.
    -- If fallback is disabled, we intentionally do not move PX_Target anywhere.
    SafeHideFrame(region)
    return false
end
