-- =========================================================
-- Blizzard visual hiding
-- =========================================================

function SetFrameAlpha(frame, alpha)
    if HasMethod(frame, "SetAlpha") then
        SafeCall(function() frame:SetAlpha(alpha) end)
    end
end

function HookBlizzardVisualFrame(frame)
    if not IsFrameObject(frame) or State.blizzardVisualHooks[frame] then
        return
    end

    if HasMethod(frame, "HookScript") then
        State.blizzardVisualHooks[frame] = true
        frame:HookScript("OnShow", function(self)
            if CFG and State.runtimeFlags and State.runtimeFlags.enabled and CFG.hideBlizzardVisuals then
                SetFrameAlpha(self, 0)
            end
        end)
    end
end

function HideFontStringsInFrame(frame, alpha, depth, seen, skipFrame)
    if not IsFrameObject(frame) or depth <= 0 then
        return
    end

    if skipFrame and frame == skipFrame then
        return
    end

    seen = seen or {}
    if seen[frame] then
        return
    end
    seen[frame] = true

    if HasMethod(frame, "GetRegions") then
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            if HasMethod(region, "GetObjectType") and region:GetObjectType() == "FontString" then
                SetFrameAlpha(region, alpha)
                HookBlizzardVisualFrame(region)
            end
        end
    end

    if HasMethod(frame, "GetChildren") then
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            if not skipFrame or child ~= skipFrame then
                HideFontStringsInFrame(child, alpha, depth - 1, seen, skipFrame)
            end
        end
    end
end

function HideVisualTree(frame, alpha, depth, seen, skipFrame)
    if not IsFrameObject(frame) or depth <= 0 then
        return
    end

    if skipFrame and frame == skipFrame then
        return
    end

    seen = seen or {}
    if seen[frame] then
        return
    end
    seen[frame] = true

    SetFrameAlpha(frame, alpha)
    HookBlizzardVisualFrame(frame)

    if HasMethod(frame, "GetRegions") then
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            if HasMethod(region, "SetAlpha") then
                SetFrameAlpha(region, alpha)
                HookBlizzardVisualFrame(region)
            end
        end
    end

    if HasMethod(frame, "GetChildren") then
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            if not skipFrame or child ~= skipFrame then
                HideVisualTree(child, alpha, depth - 1, seen, skipFrame)
            end
        end
    end
end


CASTBAR_FIELD_NAMES = {
    "Icon", "icon",
    "SpellIcon", "spellIcon",
    "CastIcon", "castIcon",
    "CastingIcon", "castingIcon",
    "Texture", "texture",
    "Border", "border",
    "BorderShield", "borderShield",
    "Shield", "shield",
    "Spark", "spark",
    "Flash", "flash",
    "Text", "text",
    "Name", "name",
}

UNITFRAME_CAST_VISUAL_FIELDS = {
    "castBar", "CastBar", "castbar",
    "CastingBar", "castingBar",
    "spellBar", "SpellBar",
    "castIcon", "CastIcon",
    "spellIcon", "SpellIcon",
    "CastingIcon", "castingIcon",
}

function HideObjectIfFrameLike(obj, alpha, depth, seen, skipFrame)
    if not IsFrameObject(obj) or obj == skipFrame then
        return false
    end

    if HasMethod(obj, "GetObjectType") then
        local objectType = obj:GetObjectType()

        if objectType == "Frame" or objectType == "Button" or objectType == "StatusBar" then
            HideVisualTree(obj, alpha, depth or 3, seen, skipFrame)
            return true
        end
    end

    if HasMethod(obj, "SetAlpha") then
        SetFrameAlpha(obj, alpha)
        HookBlizzardVisualFrame(obj)
        return true
    end

    return false
end

function HideKnownCastbarFields(container, alpha, depth, seen, skipFrame, fields)
    if not IsFrameObject(container) then
        return
    end

    for _, key in ipairs(fields or CASTBAR_FIELD_NAMES) do
        local obj = container[key]

        if obj and obj ~= container then
            HideObjectIfFrameLike(obj, alpha, depth or 3, seen, skipFrame)
        end
    end
end


GLOBAL_CASTBAR_VISUAL_SUFFIXES = {
    "CastBarIcon",
    "castBarIcon",
    "CastIcon",
    "castIcon",
    "SpellIcon",
    "spellIcon",
    "CastingIcon",
    "castingIcon",
    "Icon",
    "icon",
}

function HideGlobalCastbarVisualCandidate(name, alpha, depth, seen, skipFrame)
    if not name or name == "" then
        return false
    end

    local obj = _G and _G[name]
    if not obj or obj == skipFrame then
        return false
    end

    if HideObjectIfFrameLike(obj, alpha, depth or 3, seen, skipFrame) then
        return true
    end

    if HasMethod(obj, "SetAlpha") then
        SetFrameAlpha(obj, alpha)
        HookBlizzardVisualFrame(obj)
        return true
    end

    return false
end

function HideGlobalCastbarVisualsByBase(baseName, alpha, depth, seen, skipFrame)
    if not baseName or baseName == "" then
        return
    end

    for _, suffix in ipairs(GLOBAL_CASTBAR_VISUAL_SUFFIXES) do
        HideGlobalCastbarVisualCandidate(baseName .. suffix, alpha, depth or 3, seen, skipFrame)
    end

    -- Common Legion/private-server nameplate global patterns.
    HideGlobalCastbarVisualCandidate(baseName .. "UnitFrameCastBarIcon", alpha, depth or 3, seen, skipFrame)
    HideGlobalCastbarVisualCandidate(baseName .. "UnitFrameCastIcon", alpha, depth or 3, seen, skipFrame)
    HideGlobalCastbarVisualCandidate(baseName .. "UnitFrameSpellIcon", alpha, depth or 3, seen, skipFrame)
    HideGlobalCastbarVisualCandidate(baseName .. "UnitFrameCastingIcon", alpha, depth or 3, seen, skipFrame)
end

function HideGlobalCastbarVisualsForObjects(alpha, seen, skipFrame, ...)
    local objects = { ... }

    for _, obj in ipairs(objects) do
        if HasMethod(obj, "GetName") then
            local ok, name = pcall(obj.GetName, obj)
            if ok and name then
                HideGlobalCastbarVisualsByBase(tostring(name), alpha, 4, seen, skipFrame)
            end
        end
    end
end

function ObjectNameLooksLikeCastbarVisual(obj)
    if not HasMethod(obj, "GetName") then
        return false
    end

    local name = obj:GetName()
    if not name then
        return false
    end

    name = tostring(name):lower()

    return name:find("cast", 1, true)
        or name:find("casting", 1, true)
        or name:find("spell", 1, true)
end

function HideNamedCastbarVisuals(frame, alpha, depth, seen, skipFrame)
    if not frame or depth <= 0 then
        return
    end

    if skipFrame and frame == skipFrame then
        return
    end

    seen = seen or {}
    if seen[frame] then
        return
    end
    seen[frame] = true

    if ObjectNameLooksLikeCastbarVisual(frame) then
        HideVisualTree(frame, alpha, 4, seen, skipFrame)
        return
    end

    if HasMethod(frame, "GetRegions") then
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region ~= skipFrame and ObjectNameLooksLikeCastbarVisual(region) then
                SetFrameAlpha(region, alpha)
                HookBlizzardVisualFrame(region)
            end
        end
    end

    if HasMethod(frame, "GetChildren") then
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            if not skipFrame or child ~= skipFrame then
                HideNamedCastbarVisuals(child, alpha, depth - 1, seen, skipFrame)
            end
        end
    end
end

function HideBlizzardCastbarVisuals(uf, plate, blizzCastBar, alpha, skipFrame)
    local seen = {}

    if blizzCastBar then
        HideVisualTree(blizzCastBar, alpha, 5, seen, skipFrame)
        HideKnownCastbarFields(blizzCastBar, alpha, 4, seen, skipFrame, CASTBAR_FIELD_NAMES)
    end

    -- On some 7.3.5/private-server builds the spell icon is not parented
    -- directly to UnitFrame.castBar, but is exposed as a sibling field on the
    -- UnitFrame or as a separately named child/region. Hide those too.
    HideKnownCastbarFields(uf, alpha, 4, seen, skipFrame, UNITFRAME_CAST_VISUAL_FIELDS)
    HideNamedCastbarVisuals(uf, alpha, 4, seen, skipFrame)
    HideNamedCastbarVisuals(plate, alpha, 3, seen, skipFrame)

    -- Extra pass for private-server/global-name variants such as
    -- NamePlate1UnitFrameCastBarIcon. This is deliberately candidate-based,
    -- not a full _G scan, so it stays cheap enough to run during cast updates.
    HideGlobalCastbarVisualsForObjects(alpha, seen, skipFrame, blizzCastBar, uf, plate)
end

function ApplyBlizzardCastbarVisualStateOnly(ctx)
    if not (State.runtimeFlags and State.runtimeFlags.enabled) or not CFG.hideBlizzardVisuals or not ctx or not ctx.plate then
        return
    end

    local uf = GetUnitFrameFromPlate(ctx.plate)
    if not uf then
        return
    end

    local blizzCastBar = GetCastBarFromUF(uf)
    SetFrameAlpha(blizzCastBar, 0)
    HideBlizzardCastbarVisuals(uf, ctx.plate, blizzCastBar, 0, ctx.root)
end

function ApplyBlizzardVisualState(ctx)
    if not ctx or not ctx.plate then return end
    local uf = GetUnitFrameFromPlate(ctx.plate)
    if not uf then return end

    local alpha = (State.runtimeFlags and State.runtimeFlags.enabled and CFG.hideBlizzardVisuals) and 0 or 1

    -- Stronger than hiding individual children: the Blizzard UnitFrame contains
    -- the default healthbar, target name, castbar, buff frame and several visual
    -- widgets. The custom s2k root is parented to the nameplate itself, not to
    -- UnitFrame, so it stays visible while the Blizzard visuals disappear.
    SetFrameAlpha(uf, alpha)
    HookBlizzardVisualFrame(uf)

    local blizzCastBar = GetCastBarFromUF(uf)

    SetFrameAlpha(GetHealthBarFromUF(uf), alpha)
    SetFrameAlpha(blizzCastBar, alpha)
    SetFrameAlpha(GetBuffFrameFromUF(uf), alpha)
    SetFrameAlpha(GetNameFrameFromUF(uf), alpha)

    -- Hide the full Blizzard castbar visual subtree, including spell icons
    -- that are exposed as sibling fields or separately named castbar children.
    HideBlizzardCastbarVisuals(uf, ctx.plate, blizzCastBar, alpha, ctx.root)

    HookBlizzardVisualFrame(GetHealthBarFromUF(uf))
    HookBlizzardVisualFrame(blizzCastBar)
    HookBlizzardVisualFrame(GetBuffFrameFromUF(uf))
    HookBlizzardVisualFrame(GetNameFrameFromUF(uf))

    if uf.selectionHighlight then SetFrameAlpha(uf.selectionHighlight, alpha) end
    if uf.threatGlow then SetFrameAlpha(uf.threatGlow, alpha) end
    if uf.ClassificationFrame then SetFrameAlpha(uf.ClassificationFrame, alpha) end

    -- Some Legion/private-server builds recreate or re-alpha the target name
    -- FontString outside the common .name/.NameText fields. Hide all FontStrings
    -- inside the Blizzard UnitFrame as well.
    HideFontStringsInFrame(uf, alpha, 4, nil, ctx.root)

    -- Some target-name FontStrings are direct children/regions of the nameplate
    -- frame rather than UnitFrame fields. Hide Blizzard FontStrings on the plate
    -- too, but skip our own custom root so HP ratio/name remain visible.
    HideFontStringsInFrame(ctx.plate, alpha, 3, nil, ctx.root)
end
