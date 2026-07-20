-- =========================================================
-- s2k:Enhancements - LibDataBroker launcher and minimap icon
-- =========================================================

local S2K_MINIMAP_DEFAULT_POSITION = 225
local S2K_MINIMAP_ICON_PATH = "Interface\\Icons\\Ability_Racial_BearForm"

local function GetS2KLauncherMouseButton(firstArg, secondArg)
    if type(secondArg) == "string" then
        return secondArg
    end

    -- LibDataBroker display addons are not perfectly consistent here: some
    -- call OnClick(frame, button), while others pass only the button string.
    if type(firstArg) == "string" then
        return firstArg
    end

    return secondArg
end

function HandleS2KLauncherClick(firstArg, secondArg)
    local mouseButton = GetS2KLauncherMouseButton(firstArg, secondArg)

    if mouseButton == "RightButton" then
        if ToggleDominosLayoutMode then
            ToggleDominosLayoutMode("launcher")
        elseif S2KPrint then
            S2KPrint("Dominos layout switching is not available.")
        end
        return
    end

    if mouseButton == nil or mouseButton == "LeftButton" then
        if ToggleS2KConfig then
            ToggleS2KConfig("general", "general")
        end
    end
end

function PopulateS2KLauncherTooltip(tooltip)
    if not tooltip or not tooltip.AddLine then return end

    tooltip:AddLine("s2k:Enhancements", 1, 0.82, 0)
    tooltip:AddLine(S2K_LF("Version %s", tostring(API and API.version or "")), 0.65, 0.65, 0.65)
    tooltip:AddLine(" ")
    tooltip:AddLine(S2K_L("Left-click: open or close configuration"), 1, 1, 1)

    if CanToggleDominosLayoutFromLauncher then
        local available, mode = CanToggleDominosLayoutFromLauncher()
        if available then
            local current = GetDominosLayoutDisplayName and GetDominosLayoutDisplayName(mode)
                or (mode == "EDITABLE" and "Editable" or "Dominos")
            local target = mode == "EDITABLE" and "Dominos" or "Editable"
            tooltip:AddLine(S2K_LF("Dominos layout: %s", tostring(current)), 0.45, 0.85, 1)
            tooltip:AddLine(S2K_LF("Right-click: switch to %s", target), 1, 1, 1)
        end
    end

    local owner = tooltip.GetOwner and tooltip:GetOwner()
    if State and State.minimapButton and owner == State.minimapButton then
        tooltip:AddLine(S2K_L("Drag: reposition minimap icon"), 0.8, 0.8, 0.8)
    end
end

local function EnsureS2KMinimapSettings()
    if type(DBRoot) ~= "table" then
        return nil
    end

    if type(DBRoot.minimapIcon) ~= "table" then
        DBRoot.minimapIcon = {}
    end

    local db = DBRoot.minimapIcon
    if db.hide == nil then
        db.hide = false
    else
        db.hide = db.hide and true or false
    end

    db.minimapPos = tonumber(db.minimapPos) or S2K_MINIMAP_DEFAULT_POSITION
    return db
end

local function GetS2KMinimapPosition(angle)
    angle = math.rad(tonumber(angle) or S2K_MINIMAP_DEFAULT_POSITION)
    local x = math.cos(angle)
    local y = math.sin(angle)
    local radiusX = ((Minimap and Minimap:GetWidth()) or 140) / 2 + 5
    local radiusY = ((Minimap and Minimap:GetHeight()) or 140) / 2 + 5
    return x * radiusX, y * radiusY
end

local function PositionS2KMinimapButton(button)
    if not button or not Minimap then return end
    local db = EnsureS2KMinimapSettings()
    local x, y = GetS2KMinimapPosition(db and db.minimapPos)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function UpdateS2KMinimapDrag(button)
    if not button or not Minimap then return end
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale() or 1
    px, py = px / scale, py / scale

    local angle = math.deg(math.atan2(py - my, px - mx)) % 360
    local db = EnsureS2KMinimapSettings()
    if db then
        db.minimapPos = angle
    end
    PositionS2KMinimapButton(button)
end

local function CreateS2KMinimapButton()
    if State.minimapButton or not Minimap then
        return State.minimapButton
    end

    local button = CreateFrame("Button", "s2k_EnhancementsMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("anyUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture(S2K_MINIMAP_ICON_PATH)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    button:SetScript("OnClick", HandleS2KLauncherClick)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        PopulateS2KLauncherTooltip(GameTooltip)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", UpdateS2KMinimapDrag)
        GameTooltip:Hide()
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
        PositionS2KMinimapButton(self)
    end)

    State.minimapButton = button
    PositionS2KMinimapButton(button)
    return button
end

function IsS2KMinimapIconShown()
    local db = EnsureS2KMinimapSettings()
    return not (db and db.hide)
end

function SetS2KMinimapIconShown(shown)
    local db = EnsureS2KMinimapSettings()
    if not db then return end

    db.hide = not (shown and true or false)
    UpdateS2KMinimapIcon()
end

function UpdateS2KMinimapIcon()
    local db = EnsureS2KMinimapSettings()
    if not db then return end

    local button = CreateS2KMinimapButton()
    if not button then return end

    PositionS2KMinimapButton(button)
    if db.hide then
        button:Hide()
    else
        button:Show()
    end
end

function InitializeS2KMinimapIcon()
    UpdateS2KMinimapIcon()
end

function InitializeS2KBroker()
    if State.brokerInitialized then return end

    local ldb = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not ldb then
        return
    end

    local object = ldb:GetDataObjectByName("s2k:Enhancements")
    if not object then
        object = ldb:NewDataObject("s2k:Enhancements", {
            type = "launcher",
            label = "s2k:Enhancements",
            text = "s2k:Enhancements",
            icon = S2K_MINIMAP_ICON_PATH,
            iconCoords = { 0.08, 0.92, 0.08, 0.92 },
        })
    end

    if not object then return end

    State.brokerInitialized = true

    object.type = "launcher"
    object.label = "s2k:Enhancements"
    object.text = "s2k:Enhancements"
    object.icon = S2K_MINIMAP_ICON_PATH
    object.iconCoords = { 0.08, 0.92, 0.08, 0.92 }

    object.OnClick = HandleS2KLauncherClick
    object.OnTooltipShow = PopulateS2KLauncherTooltip

    API.broker = object
    API.OpenConfig = OpenS2KConfig
    API.CloseConfig = CloseS2KConfig
    API.ToggleConfig = ToggleS2KConfig
    API.SetMinimapIconShown = SetS2KMinimapIconShown
    API.IsMinimapIconShown = IsS2KMinimapIconShown
end

InitializeS2KBroker()
