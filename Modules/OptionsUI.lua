-- =========================================================
-- Custom scrollable dropdown helpers
-- =========================================================

-- =========================================================
-- Standalone configuration window
-- =========================================================

S2K_CONFIG_DEFAULT_WIDTH = 930
S2K_CONFIG_DEFAULT_HEIGHT = 650
S2K_CONFIG_MIN_WIDTH = 720
S2K_CONFIG_MIN_HEIGHT = 500
S2K_CONFIG_CONTENT_MIN_WIDTH = 410
S2K_CONFIG_RESIZE_LAYOUT_INTERVAL = 0.04
S2K_CONFIG_LAYOUT_EPSILON = 0.75

function GetSavedS2KConfigWindowSize()
    local width = S2K_CONFIG_DEFAULT_WIDTH
    local height = S2K_CONFIG_DEFAULT_HEIGHT

    if type(DBRoot) == "table" then
        width = tonumber(DBRoot.configWindowWidth) or width
        height = tonumber(DBRoot.configWindowHeight) or height
    end

    width = math.max(S2K_CONFIG_MIN_WIDTH, width)
    height = math.max(S2K_CONFIG_MIN_HEIGHT, height)

    local maxWidth = UIParent and UIParent.GetWidth and math.max(S2K_CONFIG_MIN_WIDTH, (UIParent:GetWidth() or width) - 20) or width
    local maxHeight = UIParent and UIParent.GetHeight and math.max(S2K_CONFIG_MIN_HEIGHT, (UIParent:GetHeight() or height) - 20) or height

    return math.min(width, maxWidth), math.min(height, maxHeight)
end

function SaveS2KConfigWindowSize(frame)
    if not frame or type(DBRoot) ~= "table" then
        return
    end

    DBRoot.configWindowWidth = math.floor((frame:GetWidth() or S2K_CONFIG_DEFAULT_WIDTH) + 0.5)
    DBRoot.configWindowHeight = math.floor((frame:GetHeight() or S2K_CONFIG_DEFAULT_HEIGHT) + 0.5)
end

function RegisterS2KResponsiveItem(container, object, options)
    if not container or not object then
        return object
    end

    container.s2kResponsiveItems = container.s2kResponsiveItems or {}
    container.s2kResponsiveObjectMap = container.s2kResponsiveObjectMap or {}
    if container.s2kResponsiveObjectMap[object] then
        return object
    end
    container.s2kResponsiveObjectMap[object] = true
    options = options or {}

    local baseWidth = tonumber(options.baseWidth)
    if not baseWidth and object.GetWidth then
        baseWidth = tonumber(object:GetWidth())
    end

    container.s2kResponsiveItems[#container.s2kResponsiveItems + 1] = {
        object = object,
        left = tonumber(options.left) or 0,
        right = tonumber(options.right) or 22,
        minWidth = tonumber(options.minWidth) or 120,
        baseWidth = baseWidth or 0,
        baseHeight = object.GetStringHeight and tonumber(object:GetStringHeight()) or (object.GetHeight and tonumber(object:GetHeight()) or 0),
        expand = options.expand and true or false,
    }

    return object
end

function AutoRegisterS2KResponsiveContent(content)
    if not content then
        return
    end

    -- Scanning every region and child on every resize tick was one of the
    -- largest CPU costs in the first responsive implementation.  Once the
    -- options tree has finished building, the set of responsive objects is
    -- stable and only needs to be discovered once.
    if content.s2kResponsiveScanComplete then
        return
    end

    content.s2kResponsiveItems = content.s2kResponsiveItems or {}
    content.s2kResponsiveObjectMap = content.s2kResponsiveObjectMap or {}

    local regions = { content:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            local width = tonumber(region:GetWidth()) or 0
            if width >= 300 then
                local _, relativeTo, _, xOffset = region:GetPoint(1)
                if not relativeTo or relativeTo == content then
                    RegisterS2KResponsiveItem(content, region, {
                        left = tonumber(xOffset) or 0,
                        right = 24,
                        minWidth = 220,
                        baseWidth = width,
                        expand = true,
                    })
                end
            end
        end
    end

    local children = { content:GetChildren() }
    for _, child in ipairs(children) do
        if child and child.GetWidth then
            local width = tonumber(child:GetWidth()) or 0
            if width >= 400 then
                local _, relativeTo, _, xOffset = child:GetPoint(1)
                if not relativeTo or relativeTo == content then
                    RegisterS2KResponsiveItem(content, child, {
                        left = tonumber(xOffset) or 0,
                        right = 24,
                        minWidth = 260,
                        baseWidth = width,
                        expand = false,
                    })
                end
            end
        end
    end

    if State and State.optionsBuildComplete then
        content.s2kResponsiveScanComplete = true
    end
end

function CaptureS2KContentAnchors(content)
    if not content then
        return
    end

    if content.s2kAnchorScanComplete then
        return
    end

    content.s2kAnchorItems = content.s2kAnchorItems or {}
    content.s2kAnchorObjectMap = content.s2kAnchorObjectMap or {}

    local objects = { content:GetRegions() }
    local children = { content:GetChildren() }
    for _, child in ipairs(children) do
        objects[#objects + 1] = child
    end

    for _, object in ipairs(objects) do
        if object and not content.s2kAnchorObjectMap[object] and object.GetPoint then
            local numPoints = object.GetNumPoints and object:GetNumPoints() or 1
            if numPoints == 1 then
                local point, relativeTo, relativePoint, xOffset, yOffset = object:GetPoint(1)
                if point == "TOPLEFT" and (not relativeTo or relativeTo == content) then
                    local captured = {
                        object = object,
                        point = point,
                        relativePoint = relativePoint or point,
                        x = tonumber(xOffset) or 0,
                        y = tonumber(yOffset) or 0,
                    }
                    content.s2kAnchorObjectMap[object] = captured
                    content.s2kAnchorItems[#content.s2kAnchorItems + 1] = captured
                end
            end
        end
    end

    if State and State.optionsBuildComplete then
        content.s2kAnchorScanComplete = true
    end
end
function ReflowS2KContentForWrappedText(content)
    if not content or content.s2kReflowBusy then
        return
    end

    content.s2kReflowBusy = true
    CaptureS2KContentAnchors(content)

    local deltas = {}
    local totalExtra = 0

    for _, item in ipairs(content.s2kResponsiveItems or {}) do
        local object = item.object
        if item.expand and object and object.IsObjectType and object:IsObjectType("FontString") then
            local currentHeight = object.GetStringHeight and tonumber(object:GetStringHeight()) or tonumber(object:GetHeight()) or 0
            if (item.baseHeight or 0) <= 0 then
                item.baseHeight = currentHeight
            end
            local extra = math.max(0, currentHeight - (item.baseHeight or currentHeight))
            if extra > 0 then
                local captured = content.s2kAnchorObjectMap and content.s2kAnchorObjectMap[object]
                local textY = captured and captured.y
                if textY then
                    deltas[#deltas + 1] = { y = textY, amount = extra }
                    totalExtra = totalExtra + extra
                end
            end
        end
    end

    for _, captured in ipairs(content.s2kAnchorItems or {}) do
        local shift = 0
        for _, delta in ipairs(deltas) do
            if captured.y < delta.y then
                shift = shift + delta.amount
            end
        end

        local object = captured.object
        if object and object.ClearAllPoints and object.SetPoint and captured.lastShift ~= shift then
            captured.lastShift = shift
            object:ClearAllPoints()
            object:SetPoint(
                captured.point,
                content,
                captured.relativePoint,
                captured.x,
                captured.y - shift
            )
        end
    end

    local currentHeight = tonumber(content:GetHeight()) or 0
    local previousExtra = tonumber(content.s2kReflowExtra) or 0
    local lastAppliedHeight = tonumber(content.s2kLastReflowHeight)
    local baseHeight

    if lastAppliedHeight and math.abs(currentHeight - lastAppliedHeight) < 0.5 then
        baseHeight = math.max(1, currentHeight - previousExtra)
    else
        -- A builder or a dynamic control changed the scroll-child height since
        -- the previous responsive pass. Treat that as the new unwrapped base.
        baseHeight = math.max(1, currentHeight)
    end

    content.s2kReflowExtra = totalExtra
    content.s2kLastReflowHeight = baseHeight + totalExtra
    if math.abs((tonumber(content:GetHeight()) or 0) - content.s2kLastReflowHeight) > S2K_CONFIG_LAYOUT_EPSILON then
        content:SetHeight(content.s2kLastReflowHeight)
    end
    content.s2kReflowBusy = nil
end

function ApplyS2KResponsiveItems(container, force)
    if not container then
        return
    end

    AutoRegisterS2KResponsiveContent(container)

    local containerWidth = tonumber(container:GetWidth()) or 0
    if containerWidth <= 0 then
        return
    end

    if not force and container.s2kLastResponsiveWidth and math.abs(containerWidth - container.s2kLastResponsiveWidth) <= S2K_CONFIG_LAYOUT_EPSILON then
        return
    end
    container.s2kLastResponsiveWidth = containerWidth

    local widthChanged = false
    for _, item in ipairs(container.s2kResponsiveItems or {}) do
        local object = item.object
        if object and object.SetWidth then
            local available = math.max(item.minWidth or 120, containerWidth - (item.left or 0) - (item.right or 22))
            local width

            if item.expand then
                width = available
            elseif (item.baseWidth or 0) > 0 then
                width = math.min(item.baseWidth, available)
            else
                width = available
            end

            local currentWidth = tonumber(object:GetWidth()) or 0
            if force or math.abs(currentWidth - width) > S2K_CONFIG_LAYOUT_EPSILON then
                object:SetWidth(width)
                if object.s2kOnResponsiveWidthChanged then
                    object:s2kOnResponsiveWidthChanged(force)
                end
                widthChanged = true
            end
        end
    end

    if force or widthChanged then
        ReflowS2KContentForWrappedText(container)
    end
end

function LayoutS2KScrollPanel(panel, force)
    if not panel or not panel.s2kScroll or not panel.s2kContent then
        return
    end

    local scrollWidth = tonumber(panel.s2kScroll:GetWidth()) or 0
    if scrollWidth <= 1 then
        scrollWidth = math.max(S2K_CONFIG_CONTENT_MIN_WIDTH, (tonumber(panel:GetWidth()) or 0) - 30)
    end

    local contentWidth = math.max(S2K_CONFIG_CONTENT_MIN_WIDTH, scrollWidth - 4)
    if not force and panel.s2kLastContentWidth and math.abs(contentWidth - panel.s2kLastContentWidth) <= S2K_CONFIG_LAYOUT_EPSILON then
        return
    end

    panel.s2kLastContentWidth = contentWidth
    if force or math.abs((tonumber(panel.s2kContent:GetWidth()) or 0) - contentWidth) > S2K_CONFIG_LAYOUT_EPSILON then
        panel.s2kContent:SetWidth(contentWidth)
    end
    ApplyS2KResponsiveItems(panel.s2kContent, force)
end

function UpdateS2KSubPageAnchors(containerPanel, force)
    if not containerPanel then
        return
    end

    local tabRows = containerPanel.s2kTabRowCount or 1
    local extraTop = tonumber(containerPanel.s2kPageExtraTop) or 0
    local topOffset = -72 - ((tabRows - 1) * 28) - extraTop

    for key, page in pairs(containerPanel.s2kPages or {}) do
        if force or page.s2kLastTopOffset ~= topOffset then
            page.s2kLastTopOffset = topOffset
            page:ClearAllPoints()
            page:SetPoint("TOPLEFT", containerPanel, "TOPLEFT", 0, topOffset)
            page:SetPoint("BOTTOMRIGHT", containerPanel, "BOTTOMRIGHT", 0, 0)
        end

        if key == containerPanel.s2kSelectedTab and page:IsShown() then
            LayoutS2KScrollPanel(page, force)
        end
    end

    if containerPanel.s2kCompatibilityScroll then
        local statusScroll = containerPanel.s2kCompatibilityScroll
        statusScroll:ClearAllPoints()
        statusScroll:SetPoint(
            "TOPLEFT",
            containerPanel,
            "TOPLEFT",
            20,
            -50 - (tabRows * 28)
        )
        statusScroll:SetWidth(math.max(240, (containerPanel:GetWidth() or 0) - 44))

        local statusContent = containerPanel.s2kCompatibilityContent
        if statusContent then
            local reserve = containerPanel.s2kCompatibilityNeedsScroll and 20 or 2
            statusContent:SetWidth(math.max(200, (statusScroll:GetWidth() or 240) - reserve))
            for _, row in ipairs(containerPanel.s2kCompatibilityRows or {}) do
                row:SetWidth(statusContent:GetWidth())
            end
        end
    elseif containerPanel.s2kCompatibilityStatus then
        containerPanel.s2kCompatibilityStatus:ClearAllPoints()
        containerPanel.s2kCompatibilityStatus:SetPoint(
            "TOPLEFT",
            containerPanel,
            "TOPLEFT",
            20,
            -50 - (tabRows * 28)
        )
        containerPanel.s2kCompatibilityStatus:SetWidth(math.max(240, (containerPanel:GetWidth() or 0) - 44))
    end
end

function LayoutS2KInternalTabs(panel, force)
    if not panel or not panel.s2kTabs then
        return
    end

    local tabCount = #panel.s2kTabs
    if tabCount < 1 then
        return
    end

    local availableWidth = math.max(220, (tonumber(panel:GetWidth()) or 0) - 32)
    local gap = 8
    local preferredButtonWidth = 112
    local minButtonWidth = 82
    local columns = math.floor((availableWidth + gap) / (preferredButtonWidth + gap))
    columns = math.max(1, math.min(tabCount, columns))

    while columns > 1 do
        local candidate = math.floor((availableWidth - ((columns - 1) * gap)) / columns)
        if candidate >= minButtonWidth then
            break
        end
        columns = columns - 1
    end

    local buttonWidth = math.floor((availableWidth - ((columns - 1) * gap)) / columns)
    buttonWidth = math.max(minButtonWidth, math.min(140, buttonWidth))
    local rowCount = math.max(1, math.ceil(tabCount / columns))
    local signature = tostring(columns) .. ":" .. tostring(buttonWidth) .. ":" .. tostring(rowCount)

    if not force and panel.s2kLastTabLayoutSignature == signature then
        local selectedPage = panel.s2kPages and panel.s2kPages[panel.s2kSelectedTab]
        if selectedPage and selectedPage:IsShown() then
            LayoutS2KScrollPanel(selectedPage, false)
        end
        return
    end

    panel.s2kLastTabLayoutSignature = signature
    panel.s2kTabRowCount = rowCount

    for index, tab in ipairs(panel.s2kTabs) do
        local button = panel.s2kTabButtons and panel.s2kTabButtons[tab.key]
        if button then
            local zeroIndex = index - 1
            local row = math.floor(zeroIndex / columns)
            local column = zeroIndex % columns
            button:ClearAllPoints()
            button:SetSize(buttonWidth, 22)
            button:SetPoint(
                "TOPLEFT",
                panel,
                "TOPLEFT",
                16 + (column * (buttonWidth + gap)),
                -44 - (row * 28)
            )
        end
    end

    UpdateS2KSubPageAnchors(panel, force)
end

function LayoutAllS2KConfigContent(force)
    if State.configLayoutBusy then
        return
    end

    if UpdateS2KConfigNavLayout then
        UpdateS2KConfigNavLayout()
    end

    State.configLayoutBusy = true
    for _, panel in pairs(State.configPanels or {}) do
        if panel and panel.s2kTabs then
            LayoutS2KInternalTabs(panel, force)
            for _, page in pairs(panel.s2kPages or {}) do
                LayoutS2KScrollPanel(page, force)
            end
        elseif panel then
            LayoutS2KScrollPanel(panel, force)
        end
    end
    State.configLayoutBusy = nil
end

function LayoutVisibleS2KConfigContent(force)
    if State.configLayoutBusy then
        return
    end

    if UpdateS2KConfigNavLayout then
        UpdateS2KConfigNavLayout()
    end

    local panel = State.configPanels and State.configPanels[State.configSelectedPanel]
    if not panel or not panel:IsShown() then
        return
    end

    State.configLayoutBusy = true
    if panel.s2kTabs then
        LayoutS2KInternalTabs(panel, force)
        local page = panel.s2kPages and panel.s2kPages[panel.s2kSelectedTab]
        if page and page:IsShown() then
            LayoutS2KScrollPanel(page, force)
        end
    else
        LayoutS2KScrollPanel(panel, force)
    end
    State.configLayoutBusy = nil
end

function ScheduleS2KConfigLayout(force)
    local frame = State and State.configFrame
    if not frame or not frame:IsShown() then
        return
    end

    frame.s2kLayoutPending = true
    if force then
        frame.s2kLayoutForce = true
    end

    if frame.s2kLayoutTickerActive then
        return
    end

    frame.s2kLayoutTickerActive = true
    frame.s2kLayoutElapsed = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.s2kLayoutElapsed = (self.s2kLayoutElapsed or 0) + elapsed
        local interval = State.configResizing and S2K_CONFIG_RESIZE_LAYOUT_INTERVAL or 0
        if self.s2kLayoutElapsed < interval then
            return
        end

        self.s2kLayoutElapsed = 0
        local runForce = self.s2kLayoutForce and true or false
        self.s2kLayoutForce = nil
        self.s2kLayoutPending = nil
        LayoutVisibleS2KConfigContent(runForce)

        if not self.s2kLayoutPending then
            self.s2kLayoutTickerActive = nil
            self:SetScript("OnUpdate", nil)
        end
    end)
end

function EnsureS2KConfigWindow()
    if State.configFrame then
        return State.configFrame
    end

    local frame = CreateFrame("Frame", "s2k_EnhancementsConfigFrame", UIParent)
    local initialWidth, initialHeight = GetSavedS2KConfigWindowSize()
    frame:SetSize(initialWidth, initialHeight)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetMinResize then frame:SetMinResize(S2K_CONFIG_MIN_WIDTH, S2K_CONFIG_MIN_HEIGHT) end
    if frame.SetMaxResize and UIParent and UIParent.GetWidth and UIParent.GetHeight then
        frame:SetMaxResize(
            math.max(S2K_CONFIG_MIN_WIDTH, (UIParent:GetWidth() or 1600) - 20),
            math.max(S2K_CONFIG_MIN_HEIGHT, (UIParent:GetHeight() or 1200) - 20)
        )
    end
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    frame:SetScript("OnHide", function(self)
        self:StopMovingOrSizing()
        State.configResizing = nil
        self.s2kLayoutPending = nil
        self.s2kLayoutForce = nil
        self.s2kLayoutTickerActive = nil
        self:SetScript("OnUpdate", nil)
        CloseOpenDropdownPopups()
    end)
    frame:SetScript("OnSizeChanged", function(self, width, height)
        width = tonumber(width) or tonumber(self:GetWidth()) or 0
        height = tonumber(height) or tonumber(self:GetHeight()) or 0

        if self.s2kLastScheduledWidth and self.s2kLastScheduledHeight
            and math.abs(width - self.s2kLastScheduledWidth) <= S2K_CONFIG_LAYOUT_EPSILON
            and math.abs(height - self.s2kLastScheduledHeight) <= S2K_CONFIG_LAYOUT_EPSILON then
            return
        end

        self.s2kLastScheduledWidth = width
        self.s2kLastScheduledHeight = height
        ScheduleS2KConfigLayout(false)
    end)

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetBackdropColor(0.03, 0.03, 0.03, 0.97)

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
    -- Leave the close-button hit area outside the draggable title bar.  In
    -- WoW 7.3.5 overlapping mouse-enabled frames can intercept the click
    -- even when the close-button texture is drawn on top.
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -48, -12)
    titleBar:SetHeight(38)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)

    local title = titleBar:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
    title:SetText("s2k:Enhancements")

    local version = titleBar:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    version:SetPoint("LEFT", title, "RIGHT", 10, -1)
    version:SetText("v" .. tostring(API and API.version or ""))

    local close = CreateFrame("Button", "s2k_EnhancementsConfigCloseButton", frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -7, -7)
    close:SetSize(32, 32)
    close:SetFrameLevel(frame:GetFrameLevel() + 20)
    close:EnableMouse(true)
    close:RegisterForClicks("LeftButtonUp")
    close:SetScript("OnClick", function()
        frame:Hide()
    end)

    local resizeGrip = CreateFrame("Button", "s2k_EnhancementsConfigResizeGrip", frame)
    resizeGrip:SetSize(24, 24)
    resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -9, 9)
    resizeGrip:SetFrameLevel(frame:GetFrameLevel() + 20)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight", "ADD")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            CloseOpenDropdownPopups()
            State.configResizing = true
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        State.configResizing = nil
        SaveS2KConfigWindowSize(frame)
        LayoutVisibleS2KConfigContent(true)
    end)
    resizeGrip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Drag to resize", 1, 1, 1)
        GameTooltip:Show()
    end)
    resizeGrip:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local nav = CreateFrame("Frame", nil, frame)
    nav:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -56)
    nav:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 46)
    nav:SetWidth(178)
    nav:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    nav:SetBackdropColor(0, 0, 0, 0.48)
    nav:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.85)

    local navScroll = CreateFrame("ScrollFrame", "s2k_EnhancementsConfigNavScrollFrame", nav, "UIPanelScrollFrameTemplate")
    navScroll:SetPoint("TOPLEFT", nav, "TOPLEFT", 12, -12)
    navScroll:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", -8, 12)

    local navContent = CreateFrame("Frame", "s2k_EnhancementsConfigNavContent", navScroll)
    navContent:SetSize(154, 1)
    navScroll:SetScrollChild(navContent)
    navScroll:EnableMouseWheel(true)
    navScroll:SetScript("OnMouseWheel", function(self, delta)
        local current = tonumber(self:GetVerticalScroll()) or 0
        local childHeight = navContent:GetHeight() or 0
        local viewportHeight = self:GetHeight() or 0
        local maximum = math.max(0, childHeight - viewportHeight)
        self:SetVerticalScroll(math.max(0, math.min(maximum, current - (delta * 31))))
    end)
    navScroll:SetScript("OnSizeChanged", function()
        if UpdateS2KConfigNavLayout then
            UpdateS2KConfigNavLayout()
        end
    end)

    local contentHost = CreateFrame("Frame", nil, frame)
    contentHost:SetPoint("TOPLEFT", nav, "TOPRIGHT", 14, 0)
    contentHost:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 46)

    local footer = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 21)
    footer:SetText("Settings are applied immediately. Open this window from an LDB display or with /s2ke.")

    State.configFrame = frame
    State.configNav = nav
    State.configNavScroll = navScroll
    State.configNavContent = navContent
    State.configContentHost = contentHost
    State.configResizeGrip = resizeGrip
    State.configPanels = {}
    State.configNavButtons = {}
    State.configSelectedPanel = nil

    if UISpecialFrames then
        local found = false
        for _, name in ipairs(UISpecialFrames) do
            if name == frame:GetName() then
                found = true
                break
            end
        end
        if not found then
            UISpecialFrames[#UISpecialFrames + 1] = frame:GetName()
        end
    end

    frame:Hide()
    return frame
end

function RegisterS2KConfigPanel(key, label, panel, order)
    EnsureS2KConfigWindow()
    if not key or not panel then return end

    panel:SetParent(State.configContentHost)
    panel:ClearAllPoints()
    panel:SetAllPoints(State.configContentHost)
    panel:Hide()

    State.configPanels[key] = panel

    local button = CreateFrame("Button", "s2k_EnhancementsConfigNav" .. tostring(key), State.configNavContent or State.configNav, "UIPanelButtonTemplate")
    button:SetSize(154, 26)
    button:SetText(label or key)
    button.s2kPanelKey = key
    button.s2kNavOrder = order or 1
    button:SetScript("OnClick", function(self)
        SelectS2KConfigPanel(self.s2kPanelKey)
    end)
    State.configNavButtons[key] = button
    if UpdateS2KConfigNavLayout then
        UpdateS2KConfigNavLayout()
    end
end

function SelectS2KConfigPanel(key, subPage)
    EnsureS2KConfigWindow()
    local panel = State.configPanels and State.configPanels[key]
    if not panel then
        key = "general"
        panel = State.configPanels and State.configPanels[key]
    end
    if not panel then return end

    CloseOpenDropdownPopups()
    State.configSelectedPanel = key

    for panelKey, otherPanel in pairs(State.configPanels or {}) do
        if panelKey == key then
            otherPanel:Show()
        else
            otherPanel:Hide()
        end
    end

    for panelKey, button in pairs(State.configNavButtons or {}) do
        if panelKey == key then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end

    if subPage and panel.SelectS2KTab then
        panel:SelectS2KTab(subPage)
    end

    LayoutVisibleS2KConfigContent(true)
end

function OpenS2KConfig(panelKey, subPage)
    BuildOptionsPanel()
    local frame = EnsureS2KConfigWindow()
    frame:Show()
    frame:Raise()
    SelectS2KConfigPanel(panelKey or State.configSelectedPanel or "general", subPage)
end

function CloseS2KConfig()
    if State.configFrame then
        State.configFrame:Hide()
    end
end

function ToggleS2KConfig(panelKey, subPage)
    if State.configFrame and State.configFrame:IsShown() then
        CloseS2KConfig()
    else
        OpenS2KConfig(panelKey, subPage)
    end
end

function CloseOpenDropdownPopups(except)
    if type(State.openDropdownPopups) ~= "table" then
        State.openDropdownPopups = {}
        return
    end

    for popup in pairs(State.openDropdownPopups) do
        if popup and popup ~= except and popup.Hide then
            popup:Hide()
        end
    end
end

function RegisterOpenDropdownPopup(popup)
    State.openDropdownPopups = State.openDropdownPopups or {}
    State.openDropdownPopups[popup] = true
end

function UnregisterOpenDropdownPopup(popup)
    if State.openDropdownPopups then
        State.openDropdownPopups[popup] = nil
    end
end

function ApplyDropdownBackdrop(popup)
    if not popup or not popup.SetBackdrop then
        return
    end

    -- Use a Blizzard dialog/dropdown-like border rather than the old flat tooltip border.
    popup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    popup:SetBackdropColor(0, 0, 0, 0.95)
end

function GetScrollFrameParts(scroll)
    if not scroll then
        return nil, nil, nil
    end

    local bar = scroll.ScrollBar or _G[scroll:GetName() .. "ScrollBar"]
    local up = bar and (bar.ScrollUpButton or _G[bar:GetName() .. "ScrollUpButton"])
    local down = bar and (bar.ScrollDownButton or _G[bar:GetName() .. "ScrollDownButton"])

    return bar, up, down
end

function SetDropdownScrollVisible(scroll, visible)
    local bar, up, down = GetScrollFrameParts(scroll)

    if bar then
        if visible then bar:Show() else bar:Hide() end
    end

    if up then
        if visible then up:Show() else up:Hide() end
    end

    if down then
        if visible then down:Show() else down:Hide() end
    end

    if scroll and scroll.EnableMouseWheel then
        scroll:EnableMouseWheel(visible and true or false)
    end
end

function UpdateS2KConfigNavLayout()
    local scroll = State and State.configNavScroll
    local content = State and State.configNavContent
    if not scroll or not content then
        return
    end

    local ordered = {}
    for _, button in pairs(State.configNavButtons or {}) do
        ordered[#ordered + 1] = button
    end
    table.sort(ordered, function(a, b)
        local ao = tonumber(a.s2kNavOrder) or 999
        local bo = tonumber(b.s2kNavOrder) or 999
        if ao == bo then
            return tostring(a.s2kPanelKey or "") < tostring(b.s2kPanelKey or "")
        end
        return ao < bo
    end)

    local rowHeight = 31
    local paddingBottom = 10
    local contentHeight = math.max(1, (#ordered * rowHeight) + paddingBottom)
    local viewportHeight = tonumber(scroll:GetHeight()) or 0
    local needsScroll = viewportHeight > 1 and contentHeight > viewportHeight + 1
    local viewportWidth = tonumber(scroll:GetWidth()) or 154
    local contentWidth = math.max(112, viewportWidth - (needsScroll and 20 or 2))

    content:SetWidth(contentWidth)
    content:SetHeight(math.max(contentHeight, viewportHeight))

    for index, button in ipairs(ordered) do
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((index - 1) * rowHeight))
        button:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -((index - 1) * rowHeight))
        button:SetHeight(26)
    end

    SetDropdownScrollVisible(scroll, needsScroll)
    if not needsScroll then
        scroll:SetVerticalScroll(0)
    end
end

function GetDropdownMaxHeight(fraction, minHeight, hardMax)
    local screenH = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 768
    local maxHeight = math.floor(screenH * (fraction or 0.65))

    minHeight = minHeight or 120
    hardMax = hardMax or 520

    if maxHeight < minHeight then maxHeight = minHeight end
    if maxHeight > hardMax then maxHeight = hardMax end

    return maxHeight
end

function PositionDropdownPopup(popup, button, maxHeight)
    if not popup or not button then
        return
    end

    popup:ClearAllPoints()

    local screenH = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 768
    local _, buttonY = button:GetCenter()
    buttonY = buttonY or (screenH / 2)

    local buttonBottom = button:GetBottom() or buttonY
    local buttonTop = button:GetTop() or buttonY
    local spaceBelow = buttonBottom
    local spaceAbove = screenH - buttonTop

    if spaceBelow >= maxHeight or spaceBelow >= spaceAbove then
        popup:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    else
        popup:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 2)
    end
end

function HookDropdownAutoClose()
    if State.dropdownCloseHooked then
        return
    end

    State.dropdownCloseHooked = true
    EnsureS2KConfigWindow()

    if State.configFrame and State.configFrame.HookScript then
        State.configFrame:HookScript("OnHide", function()
            CloseOpenDropdownPopups()
        end)
    end

    if GameMenuFrame and GameMenuFrame.HookScript then
        GameMenuFrame:HookScript("OnShow", function()
            CloseOpenDropdownPopups()
        end)
    end
end

function MakeDropdown(parent, suffix, label, key, optionsOrGetter, x, y, width)
    HookDropdownAutoClose()

    local name = parent:GetName() .. suffix

    local labelText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    labelText:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    labelText:SetText(label)

    local button = CreateFrame("Button", name .. "Button", parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", 0, -4)
    button:SetSize(width or 180, 22)

    local popup = CreateFrame("Frame", name .. "Popup", UIParent)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(1000)
    popup:SetToplevel(true)
    popup:EnableMouse(true)
    popup:EnableKeyboard(true)
    popup:Hide()
    if popup.SetClampedToScreen then popup:SetClampedToScreen(true) end
    ApplyDropdownBackdrop(popup)

    local scroll = CreateFrame("ScrollFrame", name .. "ScrollFrame", popup, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, -12)
    scroll:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -12, 12)

    local content = CreateFrame("Frame", name .. "ScrollContent", scroll)
    scroll:SetScrollChild(content)

    local rows = {}
    local rowHeight = 18
    local baseWidth = width or 180

    local function GetOptions()
        if type(optionsOrGetter) == "function" then return optionsOrGetter() or {} end
        return optionsOrGetter or {}
    end

    local function GetLabel(value)
        for _, opt in ipairs(GetOptions()) do
            if tostring(opt.key) == tostring(value) then return opt.label end
        end
        local opts = GetOptions()
        return opts[1] and opts[1].label or tostring(value or "")
    end

    local function SetText(value)
        button:SetText(GetLabel(value))
    end

    local function ClosePopup()
        popup:Hide()
    end

    local function ApplySelected(optionKey, optionPath)
        SetStr(key, optionKey)
        if key == "hpRatioFontKey" then
            SetStr("hpRatioFontPath", optionPath or "")
        elseif key == "nameFontKey" then
            SetStr("nameFontPath", optionPath or "")
        elseif key == "levelOverlayFontKey" then
            SetStr("levelOverlayFontPath", optionPath or "")
        elseif key == "healthTextureKey" then
            SetStr("healthTexturePath", optionPath or "")
        elseif key == "castbarTextureKey" then
            SetStr("castbarTexturePath", optionPath or "")
        elseif key == "playerCastOverlaySparkTextureKey" then
            SetStr("playerCastOverlaySparkTexturePath", optionPath or "")
        end

        SetText(optionKey)
        ClosePopup()

        if key == "hpRatioFontKey" or key == "hpRatioFontOutlineKey" or key == "nameFontKey" or key == "nameFontOutlineKey" or key == "levelOverlayFontKey" or key == "levelOverlayFontOutlineKey" then
            RequestTextFontRefresh()
        elseif key == "healthTextureKey" or key == "castbarTextureKey" or key == "playerCastOverlaySparkTextureKey" then
            RequestStatusBarTextureRefresh()
        elseif key == "dominosLayoutMode" or key == "dominosEditableDirection" then
            if RequestDominosApply then RequestDominosApply() end
        else
            RequestApply()
        end
    end

    local function BuildRows()
        local options = GetOptions()
        local count = #options
        local maxPopupHeight = GetDropdownMaxHeight(0.65, 120, 520)
        local wantedHeight = math.max(rowHeight, count * rowHeight)
        local scrollNeeded = (wantedHeight + 24) > maxPopupHeight
        local popupHeight = scrollNeeded and maxPopupHeight or (wantedHeight + 24)
        local popupWidth = baseWidth + (scrollNeeded and 34 or 24)
        local contentWidth = popupWidth - (scrollNeeded and 46 or 24)

        popup:SetSize(popupWidth, popupHeight)
        content:SetSize(contentWidth, wantedHeight)
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, -12)
        scroll:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", scrollNeeded and -34 or -12, 12)
        scroll:SetVerticalScroll(0)
        SetDropdownScrollVisible(scroll, scrollNeeded)

        for i = 1, math.max(count, #rows) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Button", name .. "Row" .. i, content)
                row:SetHeight(rowHeight)
                row:SetPoint("LEFT", content, "LEFT", 0, 0)
                row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
                row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
                row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                row.text:SetJustifyH("LEFT")
                row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
                rows[i] = row
            end

            if i <= count then
                local opt = options[i]
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((i - 1) * rowHeight))
                row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
                local prefix = (tostring(CFG[key]) == tostring(opt.key)) and "|cffFFD200• |r" or "  "
                row.text:SetText(prefix .. tostring(opt.label or opt.key or ""))
                row.optionKey = opt.key
                row.optionPath = opt.path
                row:SetScript("OnClick", function(self)
                    ApplySelected(self.optionKey, self.optionPath)
                end)
                row:Show()
            else
                row:Hide()
            end
        end

        PositionDropdownPopup(popup, button, popupHeight)
    end

    button:SetScript("OnClick", function()
        if popup:IsShown() then
            popup:Hide()
        else
            CloseOpenDropdownPopups(popup)
            BuildRows()
            popup:Show()
        end
    end)

    popup:SetScript("OnShow", function(self)
        RegisterOpenDropdownPopup(self)
    end)

    popup:SetScript("OnHide", function(self)
        UnregisterOpenDropdownPopup(self)
        SetText(CFG[key])
    end)

    popup:SetScript("OnKeyDown", function(self, keyPressed)
        if keyPressed == "ESCAPE" then
            self:Hide()
        end
    end)

    button.Refresh = function(self)
        SetText(CFG[key])
        if popup:IsShown() then
            BuildRows()
        end
    end

    return button
end

SIDE_OPTIONS = {
    { key = "TOP", label = "Top" },
    { key = "BOTTOM", label = "Bottom" },
    { key = "LEFT", label = "Left" },
    { key = "RIGHT", label = "Right" },
}

ORIGIN_OPTIONS = {
    { key = "LEFT", label = "Left edge" },
    { key = "CENTER", label = "Center" },
    { key = "RIGHT", label = "Right edge" },
}

GROWTH_OPTIONS = {
    { key = "RIGHT", label = "Right" },
    { key = "LEFT", label = "Left" },
    { key = "UP", label = "Up" },
    { key = "DOWN", label = "Down" },
    { key = "CENTER_HORIZONTAL", label = "Center horizontal" },
    { key = "CENTER_VERTICAL", label = "Center vertical" },
}

WRAP_DIRECTION_OPTIONS = {
    { key = "UP", label = "New row upward" },
    { key = "DOWN", label = "New row downward" },
    { key = "LEFT", label = "New column left" },
    { key = "RIGHT", label = "New column right" },
}


NAMEPLATE_MOTION_OPTIONS = {
    { key = "0", label = "Overlapping / default" },
    { key = "1", label = "Stacking" },
    { key = "2", label = "Spread" },
}

BUFF_ANCHOR_OPTIONS = {
    { key = "HEALTH", label = "Healthbar" },
    { key = "DEBUFF", label = "Debuff frame" },
}

DEBUFF_ANCHOR_OPTIONS = {
    { key = "HEALTH", label = "Healthbar" },
    { key = "BUFF", label = "Buff frame" },
}

function CreateOptionsScrollPanel(frameName, displayName, parentCategoryName)
    EnsureS2KConfigWindow()
    local panel = CreateFrame("Frame", frameName, State.configContentHost)
    panel.name = displayName
    if parentCategoryName then
        panel.parent = parentCategoryName
    end

    local scroll = CreateFrame("ScrollFrame", frameName .. "ScrollFrame", panel, "UIPanelScrollFrameTemplate")
    -- Keep the stock Legion scrollbar inside the standalone configuration
    -- content area. There is no Blizzard Interface Options button bar below it.
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -12)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", frameName .. "Content", scroll)
    content:SetSize(S2K_CONFIG_CONTENT_MIN_WIDTH, 760)
    scroll:SetScrollChild(content)

    panel.s2kScroll = scroll
    panel.s2kContent = content
    panel.s2kRefreshables = {}
    State.optionsPanels[#State.optionsPanels + 1] = panel

    panel:SetScript("OnShow", function(self)
        CloseOpenDropdownPopups()
        State.optionsRefreshing = true
        for _, child in ipairs(self.s2kRefreshables or {}) do
            if child and child.Refresh then child:Refresh() end
        end
        State.optionsRefreshing = false
    end)

    panel:SetScript("OnHide", function()
        CloseOpenDropdownPopups()
    end)

    panel:SetScript("OnSizeChanged", function(self)
        if self:IsShown() then
            ScheduleS2KConfigLayout(false)
        end
    end)

    return panel, content
end

-- Nameplates and Addons keep their existing internal tab layout inside the
-- standalone configuration window. This preserves the compact, tested control
-- organization while removing the Blizzard Interface Options dependency.
function CreateInternalTabbedOptionsPanel(frameName, displayName, parentCategoryName, tabs)
    EnsureS2KConfigWindow()
    local panel = CreateFrame("Frame", frameName, State.configContentHost)
    panel.name = displayName
    if parentCategoryName then
        panel.parent = parentCategoryName
    end

    panel.s2kPages = {}
    panel.s2kTabButtons = {}
    panel.s2kTabs = tabs or {}
    panel.s2kSelectedTab = tabs and tabs[1] and tabs[1].key or nil
    panel.s2kTabRowCount = 1

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText(displayName)

    for index, tab in ipairs(tabs or {}) do
        local button = CreateFrame("Button", frameName .. "Tab" .. index, panel, "UIPanelButtonTemplate")
        button:SetSize(108, 22)
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -44)
        button:SetText(tab.label or tab.key)
        button.s2kTabKey = tab.key
        button:SetScript("OnClick", function(self)
            panel:SelectS2KTab(self.s2kTabKey)
        end)
        panel.s2kTabButtons[tab.key] = button
    end

    function panel:SelectS2KTab(tabKey)
        if not tabKey or not self.s2kPages[tabKey] then
            tabKey = tabs and tabs[1] and tabs[1].key or nil
        end
        if not tabKey then
            return
        end

        CloseOpenDropdownPopups()
        self.s2kSelectedTab = tabKey

        for key, page in pairs(self.s2kPages) do
            if key == tabKey then
                page:Show()
            else
                page:Hide()
            end
        end

        for key, button in pairs(self.s2kTabButtons) do
            if key == tabKey then
                button:LockHighlight()
            else
                button:UnlockHighlight()
            end
        end

        if self:IsShown() then
            LayoutVisibleS2KConfigContent(true)
        end
    end

    panel:SetScript("OnShow", function(self)
        LayoutS2KInternalTabs(self)
        self:SelectS2KTab(self.s2kSelectedTab)
        if self.RefreshS2KAvailability then
            self:RefreshS2KAvailability()
        end
    end)

    panel:SetScript("OnHide", function()
        CloseOpenDropdownPopups()
    end)

    panel:SetScript("OnSizeChanged", function(self)
        if self:IsShown() then
            ScheduleS2KConfigLayout(false)
        end
    end)

    LayoutS2KInternalTabs(panel, true)
    return panel
end

function CreateOptionsSubPage(containerPanel, frameName, tabKey)
    local page = CreateFrame("Frame", frameName, containerPanel)
    local tabRows = containerPanel.s2kTabRowCount or 1
    local extraTop = tonumber(containerPanel.s2kPageExtraTop) or 0
    page:SetPoint("TOPLEFT", containerPanel, "TOPLEFT", 0, -72 - ((tabRows - 1) * 28) - extraTop)
    page:SetPoint("BOTTOMRIGHT", containerPanel, "BOTTOMRIGHT", 0, 0)

    local scroll = CreateFrame("ScrollFrame", frameName .. "ScrollFrame", page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", frameName .. "Content", scroll)
    content:SetSize(S2K_CONFIG_CONTENT_MIN_WIDTH, 760)
    scroll:SetScrollChild(content)

    page.s2kScroll = scroll
    page.s2kContent = content
    page.s2kRefreshables = {}
    containerPanel.s2kPages[tabKey] = page
    State.optionsPanels[#State.optionsPanels + 1] = page

    page:SetScript("OnShow", function(self)
        CloseOpenDropdownPopups()
        State.optionsRefreshing = true
        for _, child in ipairs(self.s2kRefreshables or {}) do
            if child and child.Refresh then child:Refresh() end
        end
        State.optionsRefreshing = false
    end)

    page:SetScript("OnHide", function()
        CloseOpenDropdownPopups()
    end)

    page:SetScript("OnSizeChanged", function(self)
        if self:IsShown() then
            ScheduleS2KConfigLayout(false)
        end
    end)

    page:Hide()
    return page, content
end

function AddControl(panel, control)
    if panel and control then
        panel.s2kRefreshables[#panel.s2kRefreshables + 1] = control
    end
    return control
end

function SectionTitle(content, text, y)
    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, y)
    title:SetText(text)
    return y - 34
end


function RefreshAllOptionsPanels()
    local old = State.optionsRefreshing
    State.optionsRefreshing = true

    for _, panel in ipairs(State.optionsPanels or {}) do
        for _, child in ipairs(panel.s2kRefreshables or {}) do
            if child and child.Refresh then
                child:Refresh()
            end
        end
    end

    State.optionsRefreshing = old

    if RefreshNameplatesOptionsAvailability then
        RefreshNameplatesOptionsAvailability()
    end
end

function ApplyProfileSettingsNow()
    if IsInCombat() then
        State.pendingOptionsApply = true
        State.pendingCVarApply = true
        return
    end

    ApplyNameplateCVarSettings()
    if S2KNP_ApplyModuleState then S2KNP_ApplyModuleState() end
    if HideDisabledModuleVisuals then HideDisabledModuleVisuals() end
    RebuildFontOptions()
    RebuildStatusBarTextureOptions()
    RememberConfiguredFontPaths()
    RememberConfiguredStatusBarTexturePaths()
    ClearWeakAuraGroupChildrenCache()
    MarkWeakAurasDirty()
    MarkWeakAuraScaffoldDirty()
    UpdateAll(true)

    if UpdateWeakAurasBinding then
        UpdateWeakAurasBinding()
    end
    if RequestDominosApply then
        RequestDominosApply()
    end

    DelayedRefreshVisibleTextFonts()
    DelayedRefreshVisibleStatusBarTextures()
    RefreshAllOptionsPanels()
end

function SwitchProfile(profileName)
    profileName = tostring(profileName or "")
    if profileName == "" then
        return
    end

    EnsureDatabase()

    if type(DBRoot.profiles[profileName]) ~= "table" then
        return
    end

    DBRoot.currentProfile = profileName
    DB = DBRoot.profiles[profileName]
    CopyDefaults()
    ApplyProfileSettingsNow()
end

function SaveCurrentProfileAs(profileName, switchAfterSave)
    profileName = tostring(profileName or "")
    profileName = profileName:gsub("^%s+", ""):gsub("%s+$", "")

    if profileName == "" then
        return
    end

    EnsureDatabase()

    -- Important profile semantics:
    -- Saving a profile should create/update a snapshot, but it should NOT
    -- silently switch the active DB pointer. The previous modular build switched
    -- to the newly saved profile here. That made it very easy to overwrite the
    -- profile that was just saved while continuing to tweak settings, so several
    -- non-default profiles could end up looking identical.
    DBRoot.profiles[profileName] = CopyProfileTable(DB)

    if switchAfterSave then
        DBRoot.currentProfile = profileName
        DB = DBRoot.profiles[profileName]
        CopyDefaults()
        ApplyProfileSettingsNow()
    else
        -- Keep the currently active profile untouched; only refresh the UI list.
        RefreshAllOptionsPanels()
    end

    if S2KPrint then
        S2KPrint("Saved profile: " .. profileName .. (switchAfterSave and " and switched to it" or ""))
    end
end

function DeleteCurrentProfile()
    EnsureDatabase()

    local current = GetCurrentProfileName()
    local profiles = DBRoot.profiles
    local count = 0
    local fallback

    for name in pairs(profiles) do
        count = count + 1
        if name ~= current and not fallback then
            fallback = name
        end
    end

    if count <= 1 then
        profiles[current] = {}
        DB = profiles[current]
        CopyDefaults()
        ApplyProfileSettingsNow()
        return
    end

    profiles[current] = nil
    DBRoot.currentProfile = fallback or "Default"

    if type(profiles[DBRoot.currentProfile]) ~= "table" then
        profiles[DBRoot.currentProfile] = {}
    end

    DB = profiles[DBRoot.currentProfile]
    CopyDefaults()
    ApplyProfileSettingsNow()
end

function ResetCurrentProfile()
    EnsureDatabase()

    local current = GetCurrentProfileName()
    DBRoot.profiles[current] = {}
    DB = DBRoot.profiles[current]
    CopyDefaults()
    ApplyProfileSettingsNow()
end

function ResetNameplateCVarSettingsToDefaults()
    EnsureDatabase()

    -- nameplateOtherAtBase is exposed as a checkbox outside CVAR_OPTION_DEFS.
    -- Reset it together with the other Blizzard nameplate CVars.
    SetBool("nameplateAtBase", DEFAULTS.nameplateAtBase and true or false)

    for key, def in pairs(CVAR_OPTION_DEFS) do
        SetNum(key, def.default or DEFAULTS[key] or 0)
    end

    ApplyProfileSettingsNow()
end

function CopyProfileToCurrent(profileName)
    profileName = tostring(profileName or "")
    profileName = profileName:gsub("^%s+", ""):gsub("%s+$", "")

    if profileName == "" then
        if S2KPrint then S2KPrint("No source profile selected.") end
        return false
    end

    EnsureDatabase()

    local current = GetCurrentProfileName()
    local source = DBRoot.profiles and DBRoot.profiles[profileName]

    if type(source) ~= "table" then
        if S2KPrint then S2KPrint("Profile not found: " .. tostring(profileName)) end
        return false
    end

    if profileName == current then
        if S2KPrint then S2KPrint("Source profile is already the current profile; nothing copied.") end
        return false
    end

    -- Copy FROM the selected source profile INTO the currently active profile.
    -- Important: keep DBRoot.currentProfile unchanged. Only the current profile's
    -- settings table is replaced by a deep copy of the source settings.
    DBRoot.profiles[current] = CopyProfileTable(source)
    DBRoot.currentProfile = current
    DB = DBRoot.profiles[current]
    CopyDefaults()
    ApplyProfileSettingsNow()

    if S2KPrint then
        S2KPrint("Copied profile '" .. tostring(profileName) .. "' into current profile '" .. tostring(current) .. "'.")
    end

    return true
end

function GetSelectedCopySourceProfileName()
    EnsureDatabase()

    local selected = State.profileCopySourceName
    if type(selected) ~= "string" or selected == "" or not (DBRoot and DBRoot.profiles and DBRoot.profiles[selected]) then
        selected = GetFirstProfileName(true)
        State.profileCopySourceName = selected
    end

    return selected
end

function CopySelectedProfileToCurrent()
    local selected = GetSelectedCopySourceProfileName()
    return CopyProfileToCurrent(selected)
end


function S2KNP_PrintProfileList()
    EnsureDatabase()
    print("---- s2k:Enhancements profiles ----")
    print("Current: " .. tostring(GetCurrentProfileName()))
    for _, option in ipairs(GetProfileOptions()) do
        local name = tostring(option.key or "")
        local mark = (name == GetCurrentProfileName()) and "*" or " "
        print(mark .. " " .. name)
    end
    print("Commands: /s2knpprof list | /s2knpprof load NAME | /s2knpprof save NAME | /s2knpprof save-switch NAME | /s2knpprof copyfrom NAME")
end

SLASH_S2KNPPROFILES1 = "/s2keprof"
SLASH_S2KNPPROFILES2 = "/s2knpprof"
SlashCmdList["S2KNPPROFILES"] = function(msg)
    msg = tostring(msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local lower = msg:lower()

    if lower == "" or lower == "list" or lower == "help" or lower == "?" then
        S2KNP_PrintProfileList()
        return
    end

    local name = msg:match("^[Ll][Oo][Aa][Dd]%s+(.+)$")
    if name then
        SwitchProfile(name)
        S2KNP_PrintProfileList()
        return
    end

    name = msg:match("^[Ss][Aa][Vv][Ee]%s+(.+)$")
    if name then
        SaveCurrentProfileAs(name, false)
        S2KNP_PrintProfileList()
        return
    end

    name = msg:match("^[Ss][Aa][Vv][Ee][%-_ ]?[Ss][Ww][Ii][Tt][Cc][Hh]%s+(.+)$")
    if name then
        SaveCurrentProfileAs(name, true)
        S2KNP_PrintProfileList()
        return
    end

    name = msg:match("^[Cc][Oo][Pp][Yy][Ff][Rr][Oo][Mm]%s+(.+)$") or msg:match("^[Cc][Oo][Pp][Yy]%s+[Ff][Rr][Oo][Mm]%s+(.+)$")
    if name then
        State.profileCopySourceName = tostring(name or "")
        CopyProfileToCurrent(name)
        S2KNP_PrintProfileList()
        return
    end

    print("s2k:Enhancements: unknown profile command. Use /s2knpprof list")
end

function MakeButton(parent, suffix, label, x, y, width, onClick)
    local button = CreateFrame("Button", parent:GetName() .. suffix, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetSize(width or 160, 24)
    button:SetText(label)
    button:SetScript("OnClick", function()
        if type(onClick) == "function" then
            onClick(button)
        end
    end)
    button.Refresh = function() end
    return button
end

-- Generic controls shared by all standalone option pages.
function RequestTextFontRefresh()
    if IsInCombat() then
        State.pendingOptionsApply = true
        return
    end

    -- Scan LibSharedMedia once, then reuse the resolved paths for every delayed
    -- repaint pass. The previous implementation rebuilt and sorted the complete
    -- media registry on every timer callback.
    RebuildFontOptions()
    RememberConfiguredFontPaths()
    RecreateVisibleTextObjects()
    UpdateAll(true)
    ScheduleVisibleTextFontRefreshes(true)
end

function RequestColorRefresh()
    if IsInCombat() then
        State.pendingOptionsApply = true
        return
    end

    UpdateAll(true)
end

function MakeColorButton(parent, suffix, label, prefix, x, y, width)
    local name = parent:GetName() .. suffix

    local labelText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    labelText:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    labelText:SetText(label)

    local button = CreateFrame("Button", name .. "Button", parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", 0, -4)
    button:SetSize(width or 180, 22)
    button:SetText("Choose color")

    -- Keep the color preview OUTSIDE the button. If the swatch is a child of the
    -- button, the selected color sits on top of the button text/skin in the old
    -- WoW options UI. A separate swatch frame to the right is cleaner and also
    -- matches the rest of the panel layout.
    local swatchFrame = CreateFrame("Frame", name .. "SwatchFrame", parent)
    swatchFrame:SetSize(24, 22)
    swatchFrame:SetPoint("LEFT", button, "RIGHT", 8, 0)

    local swatch = swatchFrame:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", swatchFrame, "TOPLEFT", 3, -3)
    swatch:SetPoint("BOTTOMRIGHT", swatchFrame, "BOTTOMRIGHT", -3, 3)

    local border = {}
    for i = 1, 4 do
        border[i] = swatchFrame:CreateTexture(nil, "OVERLAY")
        border[i]:SetColorTexture(0, 0, 0, 1)
    end
    border[1]:SetPoint("TOPLEFT", swatchFrame, "TOPLEFT", 1, -1)
    border[1]:SetPoint("TOPRIGHT", swatchFrame, "TOPRIGHT", -1, -1)
    border[1]:SetHeight(1)
    border[2]:SetPoint("BOTTOMLEFT", swatchFrame, "BOTTOMLEFT", 1, 1)
    border[2]:SetPoint("BOTTOMRIGHT", swatchFrame, "BOTTOMRIGHT", -1, 1)
    border[2]:SetHeight(1)
    border[3]:SetPoint("TOPLEFT", swatchFrame, "TOPLEFT", 1, -1)
    border[3]:SetPoint("BOTTOMLEFT", swatchFrame, "BOTTOMLEFT", 1, 1)
    border[3]:SetWidth(1)
    border[4]:SetPoint("TOPRIGHT", swatchFrame, "TOPRIGHT", -1, -1)
    border[4]:SetPoint("BOTTOMRIGHT", swatchFrame, "BOTTOMRIGHT", -1, 1)
    border[4]:SetWidth(1)

    local function UpdateSwatch()
        local r, g, b, a = GetCustomColor(prefix, 1, 1, 1, 1)
        swatch:SetColorTexture(r, g, b, a)
    end

    local function ApplyColor(r, g, b, a)
        SetCustomColor(prefix, r, g, b, a)
        UpdateSwatch()
        RequestColorRefresh()
    end

    local function OpenColorPicker()
        local r, g, b, a = GetCustomColor(prefix, 1, 1, 1, 1)
        local oldR, oldG, oldB, oldA = r, g, b, a

        local function Callback()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local opacity = 0
            if OpacitySliderFrame and OpacitySliderFrame.GetValue then
                opacity = OpacitySliderFrame:GetValue() or 0
            end
            local na = 1 - opacity
            ApplyColor(nr, ng, nb, na)
        end

        ColorPickerFrame.func = Callback
        ColorPickerFrame.opacityFunc = Callback
        ColorPickerFrame.cancelFunc = function()
            ApplyColor(oldR, oldG, oldB, oldA)
        end
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = 1 - (a or 1)
        ColorPickerFrame.previousValues = { oldR, oldG, oldB, oldA }
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end

    button:SetScript("OnClick", OpenColorPicker)
    swatchFrame:SetScript("OnMouseUp", OpenColorPicker)
    swatchFrame:EnableMouse(true)

    button.Refresh = function(self)
        UpdateSwatch()
    end

    UpdateSwatch()
    return button
end

function ShowCustomNameplatesReloadPopup(checkBox, oldValue, newValue)
    if not StaticPopupDialogs or not StaticPopup_Show then
        S2KPrint("Custom Nameplates changed. Reload the UI with /reload for the change to take effect.")
        return
    end

    StaticPopupDialogs["S2K_ENHANCEMENTS_CUSTOM_NAMEPLATES_RELOAD"] = {
        text = "The UI must be reloaded for the Custom Nameplates change to take effect.",
        button1 = "Reload UI",
        button2 = CANCEL or "Cancel",
        OnAccept = function()
            ReloadUI()
        end,
        OnCancel = function(self, data)
            if data then
                SetBool("enabled", data.oldValue and true or false)
                if data.checkBox and data.checkBox.SetChecked then
                    data.checkBox:SetChecked(data.oldValue and true or false)
                end
                if RefreshAllOptionsPanels then
                    RefreshAllOptionsPanels()
                end
                if RefreshNameplatesOptionsAvailability then
                    RefreshNameplatesOptionsAvailability()
                end
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
    }

    StaticPopup_Show(
        "S2K_ENHANCEMENTS_CUSTOM_NAMEPLATES_RELOAD",
        nil,
        nil,
        {
            checkBox = checkBox,
            oldValue = oldValue and true or false,
            newValue = newValue and true or false,
        }
    )
end

function MakeCheckbox(parent, suffix, label, tip, key, x, y)
    local cb = CreateFrame("CheckButton", parent:GetName() .. suffix, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local text = cb.Text or _G[cb:GetName() .. "Text"]
    if text then text:SetText(label) end
    cb.tooltipText = label
    cb.tooltipRequirement = tip
    cb:SetScript("OnClick", function(self)
        local oldValue = CFG[key] and true or false
        local newValue = self:GetChecked() and true or false
        SetBool(key, newValue)

        if key == "enabled" then
            -- The master switch changes which Blizzard/custom nameplate system
            -- owns the visuals and runtime paths. Persist the new value, but do
            -- not partially apply it in the current session; reload or cancel.
            if RefreshNameplatesOptionsAvailability then
                RefreshNameplatesOptionsAvailability()
            end
            ShowCustomNameplatesReloadPopup(self, oldValue, newValue)
            return
        end

        if key == "dominosIntegrationEnabled" then
            if RequestDominosApply then RequestDominosApply() end
            return
        end

        if key == "weakAurasEnabled"
        or key == "weakAuraAutoCreate"
        or key == "weakAuraTargetEnabled"
        or key == "weakAuraFallbackEnabled"
        or key == "weakAuraManageBarGroups"
        then
            ClearWeakAuraGroupChildrenCache()
            MarkWeakAurasDirty()
            MarkWeakAuraScaffoldDirty()
        end
        RequestApply()
    end)
    cb.Refresh = function(self) self:SetChecked(CFG[key] and true or false) end
    return cb
end

function MakeSlider(parent, suffix, label, key, minValue, maxValue, step, x, y)
    local name = parent:GetName() .. suffix
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    s:SetMinMaxValues(minValue, maxValue)
    s:SetValueStep(step or 1)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    _G[name .. "Low"]:SetText(tostring(minValue))
    _G[name .. "High"]:SetText(tostring(maxValue))
    local function Round(v)
        local st = step or 1
        return math.floor((tonumber(v) or 0) / st + 0.5) * st
    end
    local function SetLabel(v) _G[name .. "Text"]:SetText(label .. ": " .. tostring(v)) end
    s:SetScript("OnValueChanged", function(self, value)
        value = Round(value)
        SetLabel(value)

        -- Refreshing controls after a profile switch must not write back into
        -- the newly loaded profile. Only user-driven slider changes persist.
        if State.optionsRefreshing then
            return
        end

        SetNum(key, value)
        if key == "hpRatioFontSize" or key == "nameFontSize" or key == "levelOverlayFontSize" then
            RequestTextFontRefresh()
        else
            RequestApply()
        end
    end)
    s.Refresh = function(self)
        local v = Round(CFG[key] or minValue)
        local old = State.optionsRefreshing
        State.optionsRefreshing = true
        self:SetValue(v)
        State.optionsRefreshing = old
        SetLabel(v)
    end
    return s
end

function MakeProfileNameEditBox(parent, suffix, label, x, y, width)
    local name = parent:GetName() .. suffix

    local labelText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    labelText:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    labelText:SetText(label)

    local box = CreateFrame("EditBox", name .. "EditBox", parent, "InputBoxTemplate")
    box:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", 6, -6)
    box:SetSize(width or 220, 22)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)

    if box.SetTextInsets then
        box:SetTextInsets(4, 4, 0, 0)
    end

    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            State.profileNameEditText = self:GetText() or ""
        end
    end)

    box:SetScript("OnEnterPressed", function(self)
        State.profileNameEditText = self:GetText() or ""
        self:ClearFocus()
    end)

    box:SetScript("OnEscapePressed", function(self)
        self:SetText(State.profileNameEditText or GetCurrentProfileName())
        self:ClearFocus()
    end)

    box.Refresh = function(self)
        local value = State.profileNameEditText
        if not value or value == "" then
            value = GetCurrentProfileName()
        end
        self:SetText(value)
        if self.SetCursorPosition then
            self:SetCursorPosition(0)
        end
    end

    return box
end

function MakeProfileStatusText(parent, suffix, x, y, width)
    local text = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    text:SetWidth(width or 560)
    text:SetJustifyH("LEFT")
    RegisterS2KResponsiveItem(parent, text, { left = x, right = 24, minWidth = 220, baseWidth = width or 560, expand = true })

    text.Refresh = function(self)
        self:SetText("Current profile: |cffFFD200" .. GetCurrentProfileName() .. "|r")
    end

    text:Refresh()
    return text
end

function MakeProfileListText(parent, suffix, x, y, width)
    local text = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    text:SetWidth(width or 560)
    text:SetJustifyH("LEFT")
    RegisterS2KResponsiveItem(parent, text, { left = x, right = 24, minWidth = 220, baseWidth = width or 560, expand = true })

    text.Refresh = function(self)
        local names = {}
        for _, option in ipairs(GetProfileOptions()) do
            names[#names + 1] = option.label
        end
        self:SetText("Available profiles: " .. table.concat(names, ", "))
    end

    text:Refresh()
    return text
end

function GetFirstProfileName(excludeCurrent)
    local current = GetCurrentProfileName()
    local first

    for _, option in ipairs(GetProfileOptions()) do
        local key = tostring(option.key or "")
        if key ~= "" then
            if not first then
                first = key
            end

            if excludeCurrent and key ~= current then
                return key
            end
        end
    end

    return first or current or "Default"
end

function MakeProfileActionDropdown(parent, suffix, label, x, y, width, action)
    HookDropdownAutoClose()

    local name = parent:GetName() .. suffix

    local labelText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    labelText:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    labelText:SetText(label)

    local button = CreateFrame("Button", name .. "Button", parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", 0, -4)
    button:SetSize(width or 230, 22)

    local popup = CreateFrame("Frame", name .. "Popup", UIParent)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(1000)
    popup:SetToplevel(true)
    popup:EnableMouse(true)
    popup:EnableKeyboard(true)
    popup:Hide()
    if popup.SetClampedToScreen then popup:SetClampedToScreen(true) end
    ApplyDropdownBackdrop(popup)

    local scroll = CreateFrame("ScrollFrame", name .. "ScrollFrame", popup, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, -12)
    scroll:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -12, 12)

    local content = CreateFrame("Frame", name .. "ScrollContent", scroll)
    scroll:SetScrollChild(content)

    local rows = {}
    local rowHeight = 18
    local baseWidth = width or 230

    local function GetSelectedProfileName()
        if action == "load" then
            return GetCurrentProfileName()
        end

        return GetSelectedCopySourceProfileName()
    end

    local function GetLabelForProfile(profileName)
        profileName = tostring(profileName or "")
        if profileName == "" then
            return "Select profile"
        end
        return profileName
    end

    local function SetButtonText()
        button:SetText(GetLabelForProfile(GetSelectedProfileName()))
    end

    local function SelectProfile(profileName)
        profileName = tostring(profileName or "")
        if profileName == "" then
            popup:Hide()
            return
        end

        if action == "load" then
            SwitchProfile(profileName)
        elseif action == "copy" then
            -- Selection only. The actual copy is done by the explicit
            -- "Copy selected into current" button below the dropdown. This avoids
            -- accidental overwrites while merely browsing the source profile list.
            State.profileCopySourceName = profileName
        end

        SetButtonText()
        popup:Hide()
    end

    local function BuildRows()
        local options = GetProfileOptions()
        local count = #options
        local maxPopupHeight = GetDropdownMaxHeight(0.55, 100, 380)
        local wantedHeight = math.max(rowHeight, count * rowHeight)
        local scrollNeeded = (wantedHeight + 24) > maxPopupHeight
        local popupHeight = scrollNeeded and maxPopupHeight or (wantedHeight + 24)
        local popupWidth = baseWidth + (scrollNeeded and 34 or 24)
        local contentWidth = popupWidth - (scrollNeeded and 46 or 24)

        popup:SetSize(popupWidth, popupHeight)
        content:SetSize(contentWidth, wantedHeight)
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, -12)
        scroll:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", scrollNeeded and -34 or -12, 12)
        scroll:SetVerticalScroll(0)
        SetDropdownScrollVisible(scroll, scrollNeeded)

        local selected = GetSelectedProfileName()

        for i = 1, math.max(count, #rows) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Button", name .. "Row" .. i, content)
                row:SetHeight(rowHeight)
                row:SetPoint("LEFT", content, "LEFT", 0, 0)
                row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
                row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
                row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                row.text:SetJustifyH("LEFT")
                row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
                rows[i] = row
            end

            if i <= count then
                local opt = options[i]
                local optKey = tostring(opt.key or "")
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((i - 1) * rowHeight))
                row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
                local prefix = (optKey == tostring(selected)) and "|cffFFD200• |r" or "  "
                row.text:SetText(prefix .. tostring(opt.label or optKey))
                row.optionKey = optKey
                row:SetScript("OnClick", function(self)
                    SelectProfile(self.optionKey)
                end)
                row:Show()
            else
                row:Hide()
            end
        end

        PositionDropdownPopup(popup, button, popupHeight)
    end

    button:SetScript("OnClick", function()
        if popup:IsShown() then
            popup:Hide()
        else
            CloseOpenDropdownPopups(popup)
            SetButtonText()
            BuildRows()
            popup:Show()
        end
    end)

    popup:SetScript("OnShow", function(self)
        RegisterOpenDropdownPopup(self)
    end)

    popup:SetScript("OnHide", function(self)
        UnregisterOpenDropdownPopup(self)
        SetButtonText()
    end)

    popup:SetScript("OnKeyDown", function(self, keyPressed)
        if keyPressed == "ESCAPE" then
            self:Hide()
        end
    end)

    button.Refresh = function(self)
        if action == "copy" then
            GetSelectedCopySourceProfileName()
        end

        SetButtonText()
        if popup:IsShown() then
            BuildRows()
        end
    end

    button:Refresh()
    return button
end



function MakeDominosBarEditor(parent, page, suffix, x, y, width)
    EnsureDominosSettingsTables(true)

    local name = parent:GetName() .. suffix
    local editor = CreateFrame("Frame", name, parent)
    editor:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    editor:SetSize(width or 620, 360)
    editor.rows = {}
    editor.page = page
    editor.content = parent
    editor.baseTop = math.abs(tonumber(y) or 0)
    editor.activeRowCount = 0

    RegisterS2KResponsiveItem(parent, editor, {
        left = x,
        right = 24,
        minWidth = 280,
        baseWidth = width or 620,
        expand = true,
    })

    local header = CreateFrame("Frame", name .. "Header", editor)
    header:SetPoint("TOPLEFT", editor, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", editor, "TOPRIGHT", 0, 0)
    header:SetHeight(28)

    header.action = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    header.anchored = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    header.action:SetText("Action bar")
    header.anchored:SetText("Anchored")

    local function CreateRow(index)
        local row = CreateFrame("Frame", name .. "Row" .. tostring(index), editor)
        row.index = index

        row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.label:SetText("Action Bar " .. tostring(index))
        row.label:SetJustifyH("LEFT")

        row.anchored = CreateFrame("CheckButton", name .. "Row" .. tostring(index) .. "Anchored", row, "ChatConfigCheckButtonTemplate")
        row.anchored:SetSize(24, 24)
        row.anchored.tooltipText = "Anchored"
        row.anchored.tooltipRequirement = "Includes this action bar in the temporary Editable row or column. Dominos mode restores the bar to its normal Dominos position and show state."
        row.anchored:SetScript("OnClick", function(self)
            if State.optionsRefreshing then return end
            SetDominosBarAnchored(index, self:GetChecked() and true or false)
            editor:Refresh()
        end)

        row.Refresh = function(self)
            local bar = GetDominosBarSettings(index)
            local old = State.optionsRefreshing
            State.optionsRefreshing = true
            self.anchored:SetChecked(bar and bar.anchored and true or false)
            State.optionsRefreshing = old
        end

        editor.rows[index] = row
        return row
    end

    function editor:RebuildRows()
        local count = EnsureDominosSettingsTables(true)
        count = math.max(1, math.floor(tonumber(count) or DOMINOS_FALLBACK_ACTION_BAR_COUNT or 10))

        for i = 1, count do
            local row = self.rows[i] or CreateRow(i)
            row:Show()
        end

        for i = count + 1, #self.rows do
            if self.rows[i] then
                self.rows[i]:Hide()
            end
        end

        self.activeRowCount = count
    end

    function editor:LayoutRows(force)
        if self.s2kLayoutBusy then return end

        local editorWidth = math.max(280, tonumber(self:GetWidth()) or 620)
        local roundedWidth = math.floor(editorWidth + 0.5)
        local signature = tostring(roundedWidth) .. ":" .. tostring(self.activeRowCount)
        if not force and self.s2kLastRowLayoutSignature == signature then
            return
        end

        self.s2kLastRowLayoutSignature = signature
        self.s2kLayoutBusy = true
        local rowHeight = 30
        local top = -30

        header.action:ClearAllPoints()
        header.anchored:ClearAllPoints()
        header.action:SetPoint("LEFT", header, "LEFT", 0, 0)
        header.action:SetWidth(math.max(120, editorWidth - 120))
        header.anchored:SetPoint("RIGHT", header, "RIGHT", -18, 0)
        header.anchored:SetWidth(90)

        for i = 1, self.activeRowCount do
            local row = self.rows[i]
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, top - ((i - 1) * rowHeight))
            row:SetPoint("RIGHT", self, "RIGHT", 0, 0)
            row:SetHeight(rowHeight)

            row.label:ClearAllPoints()
            row.anchored:ClearAllPoints()
            row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.label:SetWidth(math.max(120, editorWidth - 120))
            row.anchored:SetPoint("RIGHT", row, "RIGHT", -48, 0)
        end

        local newHeight = 34 + (self.activeRowCount * rowHeight)
        self:SetHeight(newHeight)

        if self.afterLayout then
            self:afterLayout(newHeight)
        end

        self.s2kLayoutBusy = nil
    end

    editor.Refresh = function(self)
        self:RebuildRows()
        for i = 1, self.activeRowCount do
            self.rows[i]:Refresh()
        end
        self:LayoutRows(true)
    end

    editor:SetScript("OnSizeChanged", function(self)
        self:LayoutRows()
    end)

    editor:Refresh()
    return editor
end

function MakeDominosStatusText(parent, suffix, x, y, width)
    local text = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    text:SetWidth(width or 600)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    RegisterS2KResponsiveItem(parent, text, {
        left = x,
        right = 24,
        minWidth = 260,
        baseWidth = width or 600,
        expand = true,
    })

    text.Refresh = function(self)
        self:SetText(GetDominosIntegrationStatusText and GetDominosIntegrationStatusText() or "Dominos integration status is unavailable.")
        if State and State.dominosStatusError then
            self:SetTextColor(1.0, 0.35, 0.25, 1)
        else
            self:SetTextColor(0.85, 0.85, 0.85, 1)
        end
    end

    text:Refresh()
    return text
end

function BuildOptionsPanel()
    if State.optionsBuilt then return end
    EnsureS2KConfigWindow()
    State.optionsBuilt = true

    -- General is the default page of the standalone configuration window.
    -- It contains global addon settings and the existing profile manager as
    -- two internal subpages.
    local generalPanel = CreateInternalTabbedOptionsPanel(
        "s2k_EnhancementsOptionsGeneral",
        "General",
        "s2k:Enhancements",
        {
            { key = "general", label = "General" },
            { key = "profiles", label = "Profiles" },
        }
    )

    State.generalOptionsPanel = generalPanel
    RegisterS2KConfigPanel("general", "General", generalPanel, 1)

    -- General / General
    do
        local page, content = CreateOptionsSubPage(generalPanel, "s2k_EnhancementsOptionsGeneralPage", "general")
        local y = SectionTitle(content, "Minimap", -16)

        local cb = CreateFrame("CheckButton", content:GetName() .. "ShowMinimapIcon", content, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
        local text = cb.Text or _G[cb:GetName() .. "Text"]
        if text then text:SetText("Show minimap icon") end
        cb.tooltipText = "Show minimap icon"
        cb.tooltipRequirement = "Shows or hides the s2k:Enhancements launcher around the minimap. The LibDataBroker launcher remains available in LDB display addons such as StatBlockCore."
        cb:SetScript("OnClick", function(self)
            if SetS2KMinimapIconShown then
                SetS2KMinimapIconShown(self:GetChecked() and true or false)
            end
        end)
        cb.Refresh = function(self)
            local shown = true
            if IsS2KMinimapIconShown then
                shown = IsS2KMinimapIconShown()
            end
            self:SetChecked(shown and true or false)
        end
        AddControl(page, cb)
        y = y - 42

        local note = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        note:SetPoint("TOPLEFT", content, "TOPLEFT", 32, y)
        note:SetWidth(560)
        note:SetJustifyH("LEFT")
        note:SetText("The minimap icon opens the same standalone configuration window as the LibDataBroker launcher. Drag the icon around the minimap to change its position.")
        y = y - 60

        y = SectionTitle(content, "Spell activation overlays", y)

        local spellOverlayCheck = CreateFrame("CheckButton", content:GetName() .. "SpellActivationOverlays", content, "InterfaceOptionsCheckButtonTemplate")
        spellOverlayCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
        local spellOverlayText = spellOverlayCheck.Text or _G[spellOverlayCheck:GetName() .. "Text"]
        if spellOverlayText then spellOverlayText:SetText("Show spell activation overlays") end
        spellOverlayCheck.tooltipText = "Show spell activation overlays"
        spellOverlayCheck.tooltipRequirement = "Enables or disables Blizzard's spell activation overlay effects by changing the displaySpellActivationOverlays CVar."
        spellOverlayCheck:SetScript("OnClick", function(self)
            if SetSpellActivationOverlaysEnabled then
                SetSpellActivationOverlaysEnabled(self:GetChecked() and true or false)
            end
        end)
        spellOverlayCheck.Refresh = function(self)
            local enabled = true
            if IsSpellActivationOverlaysEnabled then
                enabled = IsSpellActivationOverlaysEnabled()
            end
            self:SetChecked(enabled and true or false)
        end
        AddControl(page, spellOverlayCheck)
        y = y - 42

        local spellOverlayNote = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        spellOverlayNote:SetPoint("TOPLEFT", content, "TOPLEFT", 32, y)
        spellOverlayNote:SetWidth(560)
        spellOverlayNote:SetJustifyH("LEFT")
        spellOverlayNote:SetText("Controls Blizzard's spell activation/proc overlay effects. The choice is saved globally and reapplied when the UI loads.")
        y = y - 54

        y = SectionTitle(content, "Quest reputation rewards", y)

        AddControl(page, MakeCheckbox(
            content,
            "QuestReputationEnabled",
            "Show quest reputation rewards",
            "Adds a Reputation section to quest-giver details, quest-log details and quest-completion panels.",
            "questReputationEnabled",
            16,
            y
        )); y = y - 42

        local questNote = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        questNote:SetPoint("TOPLEFT", content, "TOPLEFT", 32, y)
        questNote:SetWidth(560)
        questNote:SetJustifyH("LEFT")
        questNote:SetText("Shows the rewarded faction and reputation amount, including known Human, commendation and supported reputation-buff bonuses.")
        y = y - 54

        content:SetHeight(math.abs(y) + 80)
    end

    -- General / Profiles
    do
        local page, content = CreateOptionsSubPage(generalPanel, "s2k_EnhancementsOptionsProfilesPage", "profiles")
        local y = SectionTitle(content, "Profiles", -16)
        AddControl(page, MakeProfileStatusText(content, "CurrentProfile", 16, y, 560)); y = y - 34
        AddControl(page, MakeProfileListText(content, "ProfileList", 16, y, 560)); y = y - 48

        y = SectionTitle(content, "Create / save", y)
        AddControl(page, MakeProfileNameEditBox(content, "ProfileName", "New profile name", 32, y, 260)); y = y - 62
        AddControl(page, MakeButton(content, "SaveAsProfile", "Save current as profile", 32, y, 190, function()
            -- Save as a snapshot only. Use the Load profile dropdown to activate it.
            SaveCurrentProfileAs(State.profileNameEditText or GetCurrentProfileName(), false)
        end)); y = y - 46

        y = SectionTitle(content, "Load", y)
        AddControl(page, MakeProfileActionDropdown(content, "LoadProfileDropdown", "Load profile", 32, y, 260, "load")); y = y - 64

        y = SectionTitle(content, "Copy into current", y)
        AddControl(page, MakeProfileActionDropdown(content, "CopyProfileDropdown", "Source profile", 32, y, 260, "copy")); y = y - 38
        AddControl(page, MakeButton(content, "CopySelectedProfile", "Copy selected into current", 32, y, 220, function()
            CopySelectedProfileToCurrent()
        end)); y = y - 56

        y = SectionTitle(content, "Current profile actions", y)
        AddControl(page, MakeButton(content, "ResetProfile", "Reset current profile", 32, y, 190, function()
            ResetCurrentProfile()
        end)); y = y - 34
        AddControl(page, MakeButton(content, "DeleteProfile", "Delete current profile", 32, y, 190, function()
            DeleteCurrentProfile()
        end)); y = y - 50

        local profileNote = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        profileNote:SetPoint("TOPLEFT", content, "TOPLEFT", 32, y)
        profileNote:SetWidth(560)
        profileNote:SetJustifyH("LEFT")
        profileNote:SetText("Tip: Save current as profile only creates a snapshot. Load profile switches active profile. Copy into current has two steps: choose a source profile, then press Copy selected into current. It copies FROM the selected source INTO the active profile and keeps the active profile name unchanged.")
        y = y - 70
        content:SetHeight(math.abs(y) + 80)
    end

    generalPanel:SelectS2KTab("general")

    -- Nameplates
    local nameplatesPanel = CreateInternalTabbedOptionsPanel(
        "s2k_NameplatesOptionsNameplates",
        "Nameplates",
        "s2k:Enhancements",
        {
            { key = "general", label = "General" },
            { key = "healthbar", label = "Healthbar" },
            { key = "castbar", label = "Castbar" },
            { key = "overlays", label = "Overlays" },
            { key = "buffs", label = "Buffs" },
            { key = "debuffs", label = "Debuffs" },
        }
    )

    State.nameplatesOptionsPanel = nameplatesPanel
    RegisterS2KConfigPanel("nameplates", "Nameplates", nameplatesPanel, 2)

    function RefreshNameplatesOptionsAvailability()
        local panel = State and State.nameplatesOptionsPanel
        if not panel then return end

        local enabled = CFG and CFG.enabled ~= false
        local featureTabs = { "healthbar", "castbar", "overlays", "buffs", "debuffs" }
        for _, key in ipairs(featureTabs) do
            local button = panel.s2kTabButtons and panel.s2kTabButtons[key]
            if button then
                if enabled then
                    button:Enable()
                else
                    button:Disable()
                end
            end
        end

        if not enabled and panel.s2kSelectedTab ~= "general" then
            panel:SelectS2KTab("general")
        end

        local status = panel.s2kCustomNameplatesStatus
        if status and status.Refresh then
            status:Refresh()
        end
    end

    nameplatesPanel.RefreshS2KAvailability = RefreshNameplatesOptionsAvailability

    -- Nameplates / General
    do
        local page, content = CreateOptionsSubPage(nameplatesPanel, "s2k_NameplatesOptionsNameplatesGeneralPage", "general")
        local y = -16

        AddControl(page, MakeCheckbox(content, "ModuleCustomNameplates", "Custom Nameplates", "Master switch for the entire custom nameplate system. Changing it requires a UI reload; disabling it restores the original Blizzard nameplate visuals after the reload.", "enabled", 16, y)); y = y - 34

        local masterStatus = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        masterStatus:SetPoint("TOPLEFT", content, "TOPLEFT", 32, y)
        masterStatus:SetWidth(580)
        masterStatus:SetJustifyH("LEFT")
        masterStatus.Refresh = function(self)
            if CFG and CFG.enabled == false then
                self:SetText("|cffff6060Custom Nameplates is currently disabled.|r")
                self:Show()
            else
                self:SetText("")
                self:Hide()
            end
        end
        AddControl(page, masterStatus)
        nameplatesPanel.s2kCustomNameplatesStatus = masterStatus
        masterStatus:Refresh()
        y = y - 26

        local cmd = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        cmd:SetPoint("TOPLEFT", content, "TOPLEFT", 32, y)
        cmd:SetWidth(580)
        cmd:SetJustifyH("LEFT")
        cmd:SetText("Slash commands: /s2kemod list, /s2kemod off customnameplates, /s2kemod on customnameplates")
        y = y - 50

        y = SectionTitle(content, "Blizzard nameplate visuals", y)
        AddControl(page, MakeCheckbox(content, "HideBlizzard", "Hide Blizzard visual elements", "Sets Blizzard nameplate health/name/cast/aura visuals alpha to 0. Does not move or resize them.", "hideBlizzardVisuals", 16, y)); y = y - 36
        AddControl(page, MakeCheckbox(content, "NameplateAtBase", "Nameplates at unit feet / base", "Sets nameplateOtherAtBase CVar. In Legion this is global for non-self nameplates.", "nameplateAtBase", 16, y)); y = y - 48

        y = SectionTitle(content, "Scale", y)
        AddControl(page, MakeSlider(content, "NameplateGlobalScale", "Global nameplate scale", "nameplateGlobalScale", 0.50, 2.00, 0.05, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "NameplateSelectedScale", "Selected nameplate scale", "nameplateSelectedScale", 0.50, 2.50, 0.05, 32, y)); y = y - 56

        y = SectionTitle(content, "Blizzard nameplate CVars", y)
        AddControl(page, MakeButton(content, "ResetNameplateCVars", "Reset CVars to defaults", 32, y, 190, function()
            ResetNameplateCVarSettingsToDefaults()
        end)); y = y - 42
        AddControl(page, MakeSlider(content, "NameplateMaxDistance", "Max distance", "nameplateMaxDistance", 10, 100, 1, 32, y)); y = y - 50
        AddControl(page, MakeDropdown(content, "NameplateMotion", "Motion mode", "nameplateMotion", NAMEPLATE_MOTION_OPTIONS, 32, y, 220)); y = y - 62
        AddControl(page, MakeSlider(content, "NameplateMotionSpeed", "Motion speed", "nameplateMotionSpeed", 0.00, 1.00, 0.005, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "NameplateOverlapH", "Horizontal overlap", "nameplateOverlapH", 0.00, 3.00, 0.05, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "NameplateOverlapV", "Vertical overlap", "nameplateOverlapV", 0.00, 3.00, 0.05, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "NameplateLargeTopInset", "Large top inset", "nameplateLargeTopInset", 0.00, 1.00, 0.01, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "NameplateLargeBottomInset", "Large bottom inset", "nameplateLargeBottomInset", 0.00, 1.00, 0.01, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "NameplateLargerScale", "Larger scale", "nameplateLargerScale", 0.50, 2.50, 0.05, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "NameplateOtherTopInset", "Other top inset", "nameplateOtherTopInset", 0.00, 1.00, 0.01, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "NameplateOtherBottomInset", "Other bottom inset", "nameplateOtherBottomInset", 0.00, 1.00, 0.01, 32, y)); y = y - 50

        content:SetHeight(math.abs(y) + 80)
    end

    -- Healthbar and border
    do
        local page, content = CreateOptionsSubPage(nameplatesPanel, "s2k_NameplatesOptionsHealthbarPage", "healthbar")
        local y = SectionTitle(content, "Healthbar", -16)
        AddControl(page, MakeCheckbox(content, "ModuleTargetRuntimeHealth", "Target health runtime tick", "Extra throttled target-health refresh on OnUpdate. Disable it for maximum CPU saving if UNIT_HEALTH works reliably on the server.", "moduleTargetRuntimeHealthEnabled", 16, y)); y = y - 42

        AddControl(page, MakeSlider(content, "PlateWidth", "Healthbar width", "plateWidth", 50, 260, 1, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "PlateHeight", "Healthbar height", "plateHeight", 4, 40, 1, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "PlateYOffset", "Healthbar Y offset", "plateYOffset", -80, 80, 1, 32, y)); y = y - 54
        AddControl(page, MakeDropdown(content, "HealthTexture", "Healthbar texture", "healthTextureKey", GetStatusBarTextureOptions, 32, y, 240)); y = y - 66
        AddControl(page, MakeCheckbox(content, "HealthUseReaction", "Use unit reaction color", "If enabled, healthbar color follows hostile/friendly/dead unit reaction colors. Disable this to use the custom color picker below.", "healthUseReactionColor", 16, y)); y = y - 34
        AddControl(page, MakeColorButton(content, "HealthColor", "Custom healthbar color", "healthColor", 32, y, 200)); y = y - 70

        y = SectionTitle(content, "Border", y)
        AddControl(page, MakeDropdown(content, "BorderStyle", "All nameplates border style", "borderStyleKey", BORDER_STYLE_OPTIONS, 32, y, 220)); y = y - 62
        AddControl(page, MakeColorButton(content, "BorderColor", "All nameplates border color", "borderColor", 32, y, 220)); y = y - 70
        AddControl(page, MakeCheckbox(content, "TargetBorderOverride", "Use separate target border", "If enabled, current target nameplate uses the target border settings below.", "targetBorderOverride", 16, y)); y = y - 34
        AddControl(page, MakeDropdown(content, "TargetBorderStyle", "Target border style", "targetBorderStyleKey", BORDER_STYLE_OPTIONS, 32, y, 220)); y = y - 62
        AddControl(page, MakeColorButton(content, "TargetBorderColor", "Target border color", "targetBorderColor", 32, y, 220)); y = y - 70
        content:SetHeight(math.abs(y) + 80)
    end

    -- Castbar
    do
        local page, content = CreateOptionsSubPage(nameplatesPanel, "s2k_NameplatesOptionsCastbarPage", "castbar")
        local y = SectionTitle(content, "Castbar", -16)
        AddControl(page, MakeCheckbox(content, "ShowCastbar", "Show Castbar", "Draws an animated custom castbar under the custom healthbar.", "showCastbar", 16, y)); y = y - 40
        AddControl(page, MakeSlider(content, "CastbarHeight", "Castbar height", "castbarHeight", 2, 30, 1, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "CastbarYOffset", "Castbar Y offset", "castbarYOffset", -40, 20, 1, 32, y)); y = y - 50
        AddControl(page, MakeDropdown(content, "CastbarTexture", "Castbar texture", "castbarTextureKey", GetStatusBarTextureOptions, 32, y, 240)); y = y - 66
        AddControl(page, MakeColorButton(content, "CastbarColor", "Castbar color", "castbarColor", 32, y, 220)); y = y - 70
        AddControl(page, MakeCheckbox(content, "CastbarBorder", "Show castbar border", "Draws a separate border around the custom castbar.", "castbarBorder", 16, y)); y = y - 32
        AddControl(page, MakeDropdown(content, "CastbarBorderStyle", "Castbar border style", "castbarBorderStyleKey", BORDER_STYLE_OPTIONS, 32, y, 220)); y = y - 62
        AddControl(page, MakeColorButton(content, "CastbarBorderColor", "Castbar border color", "castbarBorderColor", 32, y, 220)); y = y - 70
        AddControl(page, MakeCheckbox(content, "ShowCastbarSpellName", "Show castbar spell name", "Shows the spell name text on the custom castbar.", "showCastbarSpellName", 16, y)); y = y - 32
        AddControl(page, MakeCheckbox(content, "ShowCastbarIcon", "Show custom castbar icon", "Shows the spell icon next to the custom castbar.", "showCastbarIcon", 16, y)); y = y - 40
        AddControl(page, MakeSlider(content, "CastbarIconSize", "Castbar icon size", "castbarIconSize", 8, 40, 1, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "CastbarIconGap", "Castbar icon gap", "castbarIconGap", 0, 20, 1, 32, y)); y = y - 60
        content:SetHeight(math.abs(y) + 80)
    end

    -- Overlays
    do
        local page, content = CreateOptionsSubPage(nameplatesPanel, "s2k_NameplatesOptionsOverlaysPage", "overlays")
        local y = SectionTitle(content, "Overlay modules", -16)
        AddControl(page, MakeCheckbox(content, "ModuleNames", "Unit name overlay", "Shows or hides the custom unit name overlay and its runtime work.", "showNames", 16, y)); y = y - 30
        AddControl(page, MakeCheckbox(content, "ModuleHPRatio", "HP ratio overlay", "Shows or hides the custom HP ratio overlay and its runtime work.", "hpRatioText", 16, y)); y = y - 30
        AddControl(page, MakeCheckbox(content, "ModuleLevelOverlay", "Unit level overlay", "Shows or hides the custom unit level overlay and its runtime work.", "levelOverlayEnabled", 16, y)); y = y - 30
        AddControl(page, MakeCheckbox(content, "ModuleHPMarker", "HP threshold marker", "Shows or hides the healthbar threshold marker and its runtime work.", "hpMarkerEnabled", 16, y)); y = y - 30
        AddControl(page, MakeCheckbox(content, "ModulePlayerCastOverlay", "Player Cast overlay", "Shows or hides player cast progress on the current target healthbar and its runtime work.", "playerCastOverlayEnabled", 16, y)); y = y - 46

        y = SectionTitle(content, "Unit name overlay", y)
        AddControl(page, MakeSlider(content, "NameFontSize", "Name font size", "nameFontSize", 6, 24, 1, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "NameYOffset", "Name Y offset", "nameYOffset", -60, 40, 1, 32, y)); y = y - 55
        AddControl(page, MakeDropdown(content, "NameFont", "Unit name font", "nameFontKey", GetFontOptions, 32, y, 240)); y = y - 62
        AddControl(page, MakeDropdown(content, "NameOutline", "Unit name font outline", "nameFontOutlineKey", FONT_OUTLINE_OPTIONS, 32, y, 240)); y = y - 70

        y = SectionTitle(content, "Player cast overlay", y)
        AddControl(page, MakeColorButton(content, "PlayerCastOverlayColor", "Player cast overlay color", "playerCastOverlayColor", 32, y, 220)); y = y - 70
        AddControl(page, MakeSlider(content, "PlayerCastOverlayFrameLevel", "Player cast overlay frame level", "playerCastOverlayFrameLevel", 1, 100, 1, 32, y)); y = y - 56
        AddControl(page, MakeCheckbox(content, "PlayerCastOverlaySparkEnabled", "Enable player cast overlay spark", "Draws a vertical spark line at the moving edge of the player's cast overlay progress.", "playerCastOverlaySparkEnabled", 32, y)); y = y - 38
        AddControl(page, MakeDropdown(content, "PlayerCastOverlaySparkTexture", "Spark texture", "playerCastOverlaySparkTextureKey", GetStatusBarTextureOptions, 48, y, 240)); y = y - 66
        AddControl(page, MakeColorButton(content, "PlayerCastOverlaySparkColor", "Spark color", "playerCastOverlaySparkColor", 48, y, 220)); y = y - 70
        AddControl(page, MakeSlider(content, "PlayerCastOverlaySparkWidth", "Spark width", "playerCastOverlaySparkWidth", 1, 12, 1, 48, y)); y = y - 56

        y = SectionTitle(content, "HP ratio overlay", y)
        AddControl(page, MakeCheckbox(content, "HPRatioGreater", "Show HP ratio only when unit max HP is greater than player max HP", "Hides ratio if UnitHealthMax(unit) <= UnitHealthMax('player').", "hpRatioOnlyGreaterThanPlayer", 16, y)); y = y - 32
        AddControl(page, MakeSlider(content, "HPRatioFontSize", "HP ratio font size", "hpRatioFontSize", 6, 24, 1, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "HPRatioYOffset", "HP ratio Y offset", "hpRatioYOffset", -40, 40, 1, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "HPRatioFrameLevel", "HP ratio frame level", "hpRatioFrameLevel", 1, 100, 1, 32, y)); y = y - 56
        AddControl(page, MakeDropdown(content, "HPRatioFont", "HP ratio font", "hpRatioFontKey", GetFontOptions, 32, y, 240)); y = y - 62
        AddControl(page, MakeDropdown(content, "HPRatioOutline", "HP ratio font outline", "hpRatioFontOutlineKey", FONT_OUTLINE_OPTIONS, 32, y, 240)); y = y - 62
        AddControl(page, MakeColorButton(content, "HPRatioColor", "HP ratio font color", "hpRatioColor", 32, y, 220)); y = y - 70

        y = SectionTitle(content, "Unit level overlay", y)
        AddControl(page, MakeSlider(content, "LevelOverlayXOffset", "Level X offset", "levelOverlayXOffset", -160, 160, 1, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "LevelOverlayYOffset", "Level Y offset", "levelOverlayYOffset", -80, 80, 1, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "LevelOverlayFontSize", "Level font size", "levelOverlayFontSize", 6, 32, 1, 32, y)); y = y - 50
        AddControl(page, MakeDropdown(content, "LevelOverlayFont", "Level font", "levelOverlayFontKey", GetFontOptions, 32, y, 240)); y = y - 62
        AddControl(page, MakeDropdown(content, "LevelOverlayOutline", "Level font outline", "levelOverlayFontOutlineKey", FONT_OUTLINE_OPTIONS, 32, y, 240)); y = y - 62
        AddControl(page, MakeDropdown(content, "LevelOverlayAlign", "Level align / growth", "levelOverlayAlign", LEVEL_OVERLAY_ALIGN_OPTIONS, 32, y, 240)); y = y - 62
        AddControl(page, MakeColorButton(content, "LevelOverlayColor", "Level color", "levelOverlayColor", 32, y, 220)); y = y - 70
        AddControl(page, MakeSlider(content, "LevelOverlayFrameLevel", "Level overlay frame level", "levelOverlayFrameLevel", 1, 100, 1, 32, y)); y = y - 56

        y = SectionTitle(content, "HP threshold marker", y)
        AddControl(page, MakeCheckbox(content, "HPMarkerOnlyTarget", "Show marker only on current target", "If enabled, the marker is shown only on the current target nameplate. If disabled, it is shown on all custom nameplates.", "hpMarkerOnlyTarget", 16, y)); y = y - 38
        AddControl(page, MakeCheckbox(content, "HPMarkerUseBorderColor", "Use current nameplate border color", "If enabled, the marker RGB follows the current nameplate border color. Marker alpha still comes from the marker color picker.", "hpMarkerUseBorderColor", 16, y)); y = y - 38
        AddControl(page, MakeSlider(content, "HPMarkerPercent", "Marker position percent", "hpMarkerPercent", 0, 100, 1, 32, y)); y = y - 50
        AddControl(page, MakeDropdown(content, "HPMarkerWidthMode", "Marker width mode", "hpMarkerWidthMode", HP_MARKER_WIDTH_MODE_OPTIONS, 32, y, 240)); y = y - 62
        AddControl(page, MakeSlider(content, "HPMarkerWidth", "Fixed line width", "hpMarkerWidth", 1, 20, 1, 32, y)); y = y - 50
        AddControl(page, MakeColorButton(content, "HPMarkerColor", "Marker color / alpha", "hpMarkerColor", 32, y, 220)); y = y - 70
        AddControl(page, MakeSlider(content, "HPMarkerFrameLevel", "Marker frame level", "hpMarkerFrameLevel", 1, 100, 1, 32, y)); y = y - 60

        local note = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        note:SetPoint("TOPLEFT", content, "TOPLEFT", 32, y)
        note:SetWidth(560)
        note:SetJustifyH("LEFT")
        note:SetText("The HP marker is positioned as a percentage of the visual healthbar width. In fixed-line mode the width slider controls the vertical line. In left/right span mode it extends from the marker percentage to 0% or 100%. If border-color mode is enabled, the marker RGB follows the current nameplate border color while the marker alpha remains controlled by the color picker.")
        y = y - 70

        content:SetHeight(math.abs(y) + 80)
    end

    -- Buff frame
    do
        local page, content = CreateOptionsSubPage(nameplatesPanel, "s2k_NameplatesOptionsBuffsPage", "buffs")
        local y = SectionTitle(content, "Buff frame", -16)
        AddControl(page, MakeCheckbox(content, "BuffEnabled", "Enable buff frame", "Draws custom helpful aura icons.", "buffFrameEnabled", 16, y)); y = y - 30
        AddControl(page, MakeCheckbox(content, "BuffOnTarget", "Show buff frame on current target", "If disabled, custom buff frame is hidden on the current target.", "showBuffFrameOnTarget", 16, y)); y = y - 40
        AddControl(page, MakeDropdown(content, "BuffAnchorTo", "Buff frame anchor to", "buffAnchorTo", BUFF_ANCHOR_OPTIONS, 32, y, 180)); y = y - 62
        AddControl(page, MakeDropdown(content, "BuffAnchorSide", "Buff frame anchor side", "buffAnchorSide", SIDE_OPTIONS, 32, y, 180)); y = y - 62
        AddControl(page, MakeSlider(content, "BuffYOffset", "Buff frame offset", "buffYOffset", -60, 60, 1, 32, y)); y = y - 50
        AddControl(page, MakeDropdown(content, "BuffOrigin", "Buff horizontal start", "buffHorizontalOrigin", ORIGIN_OPTIONS, 32, y, 180)); y = y - 62
        AddControl(page, MakeDropdown(content, "BuffGrowth", "Buff growth direction", "buffGrowth", GROWTH_OPTIONS, 32, y, 220)); y = y - 62
        AddControl(page, MakeDropdown(content, "BuffWrapDirection", "Buff wrap direction", "buffWrapDirection", WRAP_DIRECTION_OPTIONS, 32, y, 220)); y = y - 62
        AddControl(page, MakeSlider(content, "BuffIconWidth", "Buff icon width", "buffIconWidth", 8, 64, 1, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "BuffIconHeight", "Buff icon height", "buffIconHeight", 8, 64, 1, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "BuffIconSpacing", "Buff icon spacing", "buffIconSpacing", 0, 20, 1, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "BuffIconsPerLine", "Buff icons per row/column", "buffIconsPerLine", 1, 20, 1, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "BuffMaxIcons", "Maximum buff icons", "buffMaxIcons", 1, 40, 1, 32, y)); y = y - 50
        AddControl(page, MakeCheckbox(content, "BuffOnlyPlayer", "Show only player-cast buffs", "Only show helpful auras cast by player/pet/vehicle.", "buffOnlyPlayerCast", 16, y)); y = y - 32
        AddControl(page, MakeCheckbox(content, "BuffOnlyDispellable", "Show only dispellable buffs", "Only show helpful auras with a dispel type reported by UnitAura. If stealable filtering is also enabled, either condition may pass.", "buffOnlyDispellable", 16, y)); y = y - 32
        AddControl(page, MakeCheckbox(content, "BuffOnlyStealable", "Show only stealable buffs", "Only show helpful auras reported as stealable by UnitAura. If dispellable filtering is also enabled, either condition may pass.", "buffOnlyStealable", 16, y)); y = y - 50
        content:SetHeight(math.abs(y) + 80)
    end

    -- Debuff frame
    do
        local page, content = CreateOptionsSubPage(nameplatesPanel, "s2k_NameplatesOptionsDebuffsPage", "debuffs")
        local y = SectionTitle(content, "Debuff frame", -16)
        AddControl(page, MakeCheckbox(content, "DebuffEnabled", "Enable debuff frame", "Draws custom harmful aura icons.", "debuffFrameEnabled", 16, y)); y = y - 30
        AddControl(page, MakeCheckbox(content, "DebuffOnTarget", "Show debuff frame on current target", "If disabled, custom debuff frame is hidden on the current target.", "showDebuffFrameOnTarget", 16, y)); y = y - 40
        AddControl(page, MakeDropdown(content, "DebuffAnchorTo", "Debuff frame anchor to", "debuffAnchorTo", DEBUFF_ANCHOR_OPTIONS, 32, y, 180)); y = y - 62
        AddControl(page, MakeDropdown(content, "DebuffAnchorSide", "Debuff frame anchor side", "debuffAnchorSide", SIDE_OPTIONS, 32, y, 180)); y = y - 62
        AddControl(page, MakeSlider(content, "DebuffYOffset", "Debuff frame offset", "debuffYOffset", -60, 60, 1, 32, y)); y = y - 50
        AddControl(page, MakeDropdown(content, "DebuffOrigin", "Debuff horizontal start", "debuffHorizontalOrigin", ORIGIN_OPTIONS, 32, y, 180)); y = y - 62
        AddControl(page, MakeDropdown(content, "DebuffGrowth", "Debuff growth direction", "debuffGrowth", GROWTH_OPTIONS, 32, y, 220)); y = y - 62
        AddControl(page, MakeDropdown(content, "DebuffWrapDirection", "Debuff wrap direction", "debuffWrapDirection", WRAP_DIRECTION_OPTIONS, 32, y, 220)); y = y - 62
        AddControl(page, MakeSlider(content, "DebuffIconWidth", "Debuff icon width", "debuffIconWidth", 8, 64, 1, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "DebuffIconHeight", "Debuff icon height", "debuffIconHeight", 8, 64, 1, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "DebuffIconSpacing", "Debuff icon spacing", "debuffIconSpacing", 0, 20, 1, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "DebuffIconsPerLine", "Debuff icons per row/column", "debuffIconsPerLine", 1, 20, 1, 32, y)); y = y - 50
        AddControl(page, MakeSlider(content, "DebuffMaxIcons", "Maximum debuff icons", "debuffMaxIcons", 1, 40, 1, 32, y)); y = y - 50
        AddControl(page, MakeCheckbox(content, "DebuffOnlyPlayer", "Show only player-cast debuffs", "Only show harmful auras cast by player/pet/vehicle.", "debuffOnlyPlayerCast", 16, y)); y = y - 50
        content:SetHeight(math.abs(y) + 80)
    end

    nameplatesPanel:SelectS2KTab("general")
    RefreshNameplatesOptionsAvailability()

    -- Addons
    -- Keep every supported integration visible even when its dependency is not
    -- installed. Missing integrations are dimmed/disabled, while the persistent
    -- status text explains which addon is missing and why the integration is off.
    local addonTabs = {
        { key = "weakauras", label = "WeakAuras" },
        { key = "dominos", label = "Dominos" },
    }

    local addonsPanel = CreateInternalTabbedOptionsPanel(
        "s2k_NameplatesOptionsAddons",
        "Addons",
        "s2k:Enhancements",
        addonTabs
    )

    -- Reserve a compact status area below the integration tabs. It shows at
    -- most four addon rows; when future integrations increase the list beyond
    -- four entries, the status block becomes independently scrollable.
    addonsPanel.s2kPageExtraTop = 42
    State.addonsOptionsPanel = addonsPanel
    RegisterS2KConfigPanel("addons", "Addons", addonsPanel, 3)

    local compatibilityScroll = CreateFrame("ScrollFrame", "s2k_EnhancementsCompatibilityScrollFrame", addonsPanel, "UIPanelScrollFrameTemplate")
    compatibilityScroll:SetPoint("TOPLEFT", addonsPanel, "TOPLEFT", 20, -78)
    compatibilityScroll:SetSize(620, 32)

    local compatibilityContent = CreateFrame("Frame", "s2k_EnhancementsCompatibilityScrollContent", compatibilityScroll)
    compatibilityContent:SetSize(600, 32)
    compatibilityScroll:SetScrollChild(compatibilityContent)
    compatibilityScroll:SetScript("OnMouseWheel", function(self, delta)
        local current = tonumber(self:GetVerticalScroll()) or 0
        local childHeight = compatibilityContent:GetHeight() or 0
        local viewportHeight = self:GetHeight() or 0
        local maximum = math.max(0, childHeight - viewportHeight)
        self:SetVerticalScroll(math.max(0, math.min(maximum, current - (delta * 16))))
    end)

    addonsPanel.s2kCompatibilityScroll = compatibilityScroll
    addonsPanel.s2kCompatibilityContent = compatibilityContent
    addonsPanel.s2kCompatibilityRows = {}
    addonsPanel.s2kCompatibilityNeedsScroll = false

    -- GetDominosCompatibilityStatus is provided by DominosIntegration.lua.

    function RefreshAddonsOptionsAvailability()
        local panel = State and State.addonsOptionsPanel
        if not panel then return end

        local weakAurasCompatible, weakAurasReason = false, nil
        if GetWeakAurasCompatibilityStatus then
            weakAurasCompatible, weakAurasReason = GetWeakAurasCompatibilityStatus()
            weakAurasCompatible = weakAurasCompatible and true or false
        else
            weakAurasReason = "WeakAuras was not detected; this integration is disabled."
        end

        local dominosCompatible, dominosReason = GetDominosCompatibilityStatus()

        local availability = {
            weakauras = weakAurasCompatible,
            dominos = dominosCompatible,
        }

        for key, enabled in pairs(availability) do
            local button = panel.s2kTabButtons and panel.s2kTabButtons[key]
            if button then
                if enabled then
                    button:Enable()
                    button:SetAlpha(1.0)
                else
                    button:Disable()
                    button:SetAlpha(0.55)
                end
            end
        end

        local lines = {}
        if weakAurasCompatible then
            lines[#lines + 1] = "|cff70d070WeakAuras detected.|r"
        else
            local reason = tostring(weakAurasReason or "WeakAuras was not detected.")
            if not reason:lower():find("disabled", 1, true) then
                reason = reason .. " This integration is disabled."
            end
            lines[#lines + 1] = "|cffb0b0b0" .. reason .. "|r"
        end

        if dominosCompatible then
            lines[#lines + 1] = "|cff70d070Dominos detected.|r"
        else
            lines[#lines + 1] = "|cffb0b0b0" .. tostring(dominosReason or "Dominos was not detected; this integration is disabled.") .. "|r"
        end

        local statusEntries = {}
        for index, textValue in ipairs(lines) do
            statusEntries[index] = {
                text = textValue,
                tooltip = textValue:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""),
            }
        end

        local statusScroll = panel.s2kCompatibilityScroll
        local statusContent = panel.s2kCompatibilityContent
        if statusScroll and statusContent then
            local rowHeight = 16
            local visibleRows = math.max(1, math.min(4, #statusEntries))
            local viewportHeight = visibleRows * rowHeight
            local needsScroll = #statusEntries > 4

            panel.s2kCompatibilityNeedsScroll = needsScroll
            panel.s2kPageExtraTop = viewportHeight + 10
            statusScroll:SetHeight(viewportHeight)

            for index, entry in ipairs(statusEntries) do
                local row = panel.s2kCompatibilityRows[index]
                if not row then
                    row = CreateFrame("Button", nil, statusContent)
                    row:SetHeight(rowHeight)
                    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                    row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
                    row.text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                    row.text:SetJustifyH("LEFT")
                    row:SetScript("OnEnter", function(self)
                        if self.s2kTooltip and self.s2kTooltip ~= "" then
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetText(self.s2kTooltip, 1, 1, 1, true)
                            GameTooltip:Show()
                        end
                    end)
                    row:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)
                    panel.s2kCompatibilityRows[index] = row
                end

                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", statusContent, "TOPLEFT", 0, -((index - 1) * rowHeight))
                row:SetWidth(statusContent:GetWidth())
                row.text:SetText(entry.text)
                row.s2kTooltip = entry.tooltip
                row:Show()
            end

            for index = #statusEntries + 1, #(panel.s2kCompatibilityRows or {}) do
                panel.s2kCompatibilityRows[index]:Hide()
            end

            statusContent:SetHeight(math.max(viewportHeight, #statusEntries * rowHeight))
            SetDropdownScrollVisible(statusScroll, needsScroll)
            if not needsScroll then
                statusScroll:SetVerticalScroll(0)
            end
            UpdateS2KSubPageAnchors(panel, true)
        end

        -- If the currently selected integration disappeared or became
        -- incompatible, move to the first usable integration. When none are
        -- usable, show the hidden compatibility-information page while both
        -- supported integration buttons remain visible and disabled above it.
        local selected = panel.s2kSelectedTab
        if selected and not availability[selected] then
            if weakAurasCompatible then
                panel:SelectS2KTab("weakauras")
            elseif dominosCompatible then
                panel:SelectS2KTab("dominos")
            else
                panel:SelectS2KTab("none")
            end
        end
    end

    addonsPanel.RefreshS2KAvailability = RefreshAddonsOptionsAvailability

    -- Addons / WeakAuras integration. The page is always built so it can become
    -- usable immediately if WeakAuras is loaded later in the same session.
    do
        local page, content = CreateOptionsSubPage(addonsPanel, "s2k_NameplatesOptionsWeakAurasPage", "weakauras")
        local y = SectionTitle(content, "WeakAuras", -16)
        AddControl(page, MakeCheckbox(content, "ModuleWeakAuras", "WeakAuras integration", "Runtime switch for the WeakAuras scaffold, target/fallback binding and smooth-follow anchor updates.", "moduleWeakAurasEnabled", 16, y)); y = y - 46
        AddControl(page, MakeCheckbox(content, "WeakAurasEnabled", "Enable WeakAuras anchoring", "Lets this addon position the fixed s2k_NP_Target WeakAura region on the current target custom healthbar.", "weakAurasEnabled", 16, y)); y = y - 38
        AddControl(page, MakeCheckbox(content, "WeakAuraAutoCreate", "Create missing fixed WeakAuras", "Creates missing fixed WA displays only: s2k_NP, s2k_NP_Target, s2k_NP_Fallback, and if progress bars are enabled, s2k_NP_BT/s2k_NP_BB with their _Terminator children. Existing displays are not restyled.", "weakAuraAutoCreate", 16, y)); y = y - 38
        AddControl(page, MakeCheckbox(content, "WeakAuraTargetEnabled", "Enable target nameplate aura", "Moves s2k_NP_Target onto the current target nameplate.", "weakAuraTargetEnabled", 16, y)); y = y - 38
        AddControl(page, MakeCheckbox(content, "WeakAuraFallbackEnabled", "Enable fallback aura", "When no target nameplate is available, moves s2k_NP_Target onto s2k_NP_Fallback. If disabled, no fallback anchoring is attempted.", "weakAuraFallbackEnabled", 16, y)); y = y - 38
        AddControl(page, MakeCheckbox(content, "WeakAuraManageBarGroups", "Enable top/bottom progress bar groups", "Creates and width-syncs only the fixed groups s2k_NP_BT and s2k_NP_BB. WeakAuras owns their layout/style settings, including group spacing; this addon only syncs width.", "weakAuraManageBarGroups", 16, y)); y = y - 38

        local note = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        note:SetPoint("TOPLEFT", content, "TOPLEFT", 32, y)
        note:SetWidth(620)
        note:SetJustifyH("LEFT")
        note:SetText("Fixed scaffold names:\nTarget/fallback group: s2k_NP\nTarget texture: s2k_NP_Target  |  Fallback texture: s2k_NP_Fallback\nTop progress group: s2k_NP_BT  |  Terminator: s2k_NP_BT_Terminator\nBottom progress group: s2k_NP_BB  |  Terminator: s2k_NP_BB_Terminator\n\nThe addon only creates missing displays. It does not reset an existing aura's color, alpha, texture, offsets, or anchors, so you can change alpha/color in WeakAuras for debugging. If progress groups are disabled, the addon does not create or touch s2k_NP_BT/s2k_NP_BB.")
        y = y - 150

        local repair = CreateFrame("Button", content:GetName() .. "CreateFixedWeakAurasButton", content, "UIPanelButtonTemplate")
        repair:SetPoint("TOPLEFT", content, "TOPLEFT", 32, y)
        repair:SetSize(220, 24)
        repair:SetText("Create/repair fixed WA")
        repair:SetScript("OnClick", function()
            local compatible, reason = GetWeakAurasCompatibilityStatus and GetWeakAurasCompatibilityStatus()
            if not compatible then
                S2KPrint(reason or "WeakAuras was not detected; this integration is disabled.")
                return
            end
            MarkWeakAuraScaffoldDirty()
            EnsureWeakAuraScaffold(true)
            RequestApply()
        end)
        AddControl(page, repair)
        y = y - 50

        content:SetHeight(math.abs(y) + 100)
    end

    -- Addons / Dominos integration.
    do
        local page, content = CreateOptionsSubPage(addonsPanel, "s2k_NameplatesOptionsDominosPage", "dominos")
        State.dominosOptionsPage = page

        local y = SectionTitle(content, "Dominos action bars", -16)

        local intro = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        intro:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
        intro:SetWidth(610)
        intro:SetJustifyH("LEFT")
        intro:SetText("Dominos mode leaves the action bars in their normal Dominos positions with their normal Dominos Show States. Editable mode temporarily saves those values, clears the selected bars' Show States, and arranges the checked bars for easy editing.")
        RegisterS2KResponsiveItem(content, intro, { left = 16, right = 24, minWidth = 260, baseWidth = 610, expand = true })
        y = y - 88

        AddControl(page, MakeCheckbox(
            content,
            "DominosIntegrationEnabled",
            "Enable Dominos integration",
            "When disabled, any active Editable layout is closed and the original Dominos positions and Show States are restored.",
            "dominosIntegrationEnabled",
            16,
            y
        )); y = y - 44

        AddControl(page, MakeDropdown(content, "DominosLayoutMode", "Layout state", "dominosLayoutMode", DOMINOS_LAYOUT_MODE_OPTIONS, 32, y, 200)); y = y - 58

        local directionControl = MakeDropdown(content, "DominosEditDirection", "Editable alignment", "dominosEditableDirection", DOMINOS_EDIT_DIRECTION_OPTIONS, 32, y, 220)
        local directionBaseRefresh = directionControl.Refresh
        directionControl.Refresh = function(self)
            if directionBaseRefresh then directionBaseRefresh(self) end
            local enabled = CFG and CFG.dominosIntegrationEnabled and tostring(CFG.dominosLayoutMode or "LOCKED"):upper() == "EDITABLE"
            if enabled then
                self:Enable()
                self:SetAlpha(1.0)
            else
                self:Disable()
                self:SetAlpha(0.55)
            end
        end
        AddControl(page, directionControl); y = y - 64

        local editor = MakeDominosBarEditor(content, page, "DominosBarEditor", 32, y, 620)
        AddControl(page, editor)

        local applyButton = CreateFrame("Button", content:GetName() .. "DominosApplyButton", content, "UIPanelButtonTemplate")
        applyButton:SetSize(150, 24)
        applyButton:SetText("Apply now")
        applyButton:SetScript("OnClick", function()
            if RequestDominosApply then RequestDominosApply() end
        end)
        AddControl(page, applyButton)

        local status = MakeDominosStatusText(content, "DominosStatus", 32, y - 430, 610)
        AddControl(page, status)

        editor.afterLayout = function(self, editorHeight)
            applyButton:ClearAllPoints()
            status:ClearAllPoints()

            applyButton:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -14)
            status:SetPoint("TOPLEFT", applyButton, "BOTTOMLEFT", 0, -16)

            local contentHeight = self.baseTop + editorHeight + 130
            content:SetHeight(math.max(680, contentHeight))
        end

        editor:LayoutRows(true)
        content:SetHeight(math.max(680, editor.baseTop + editor:GetHeight() + 130))
    end

    -- Hidden fallback page used when none of the supported addons is loaded.
    -- It has no tab button; the two disabled compatibility buttons remain visible
    -- above it together with the persistent per-addon status lines.
    do
        local page, content = CreateOptionsSubPage(addonsPanel, "s2k_NameplatesOptionsNoAddonsPage", "none")
        local y = -16

        local note = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        note:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
        note:SetWidth(610)
        note:SetJustifyH("LEFT")
        note:SetText("No compatible addons are currently loaded.\nSupported integrations: WeakAuras and Dominos.")
        y = y - 76
        content:SetHeight(math.abs(y) + 80)
    end

    local initialWeakAuras = GetWeakAurasCompatibilityStatus and select(1, GetWeakAurasCompatibilityStatus())
    local initialDominos = GetDominosCompatibilityStatus()
    if initialWeakAuras then
        addonsPanel:SelectS2KTab("weakauras")
    elseif initialDominos then
        addonsPanel:SelectS2KTab("dominos")
    else
        addonsPanel:SelectS2KTab("none")
    end
    RefreshAddonsOptionsAvailability()


    -- Debug / profiler
    do
        local panel, content = CreateOptionsScrollPanel("s2k_NameplatesOptionsDebug", "Debug", "s2k:Enhancements")
        local y = SectionTitle(content, "Debug / internal profiler", -16)
        local cb = CreateFrame("CheckButton", content:GetName() .. "ProfilerEnabled", content, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
        local text = cb.Text or _G[cb:GetName() .. "Text"]
        if text then text:SetText("Enable internal profiler") end
        cb.tooltipText = "Enable internal profiler"
        cb.tooltipRequirement = "When disabled, profiler wrappers are removed and no timing data is collected. Keep this OFF during normal gameplay."
        cb:SetScript("OnClick", function(self)
            SetProfilerEnabled(self:GetChecked() and true or false)
        end)
        cb.Refresh = function(self)
            self:SetChecked(CFG.debugProfilerEnabled and true or false)
        end
        AddControl(panel, cb); y = y - 42

        AddControl(panel, MakeSlider(content, "ProfilerMaxRows", "Profiler report rows", "debugProfilerMaxRows", 5, 80, 1, 32, y)); y = y - 52

        AddControl(panel, MakeButton(content, "ProfilerReset", "Reset profiler data", 32, y, 180, function()
            ProfilerReset()
            print("s2k:Enhancements profiler: reset")
        end)); y = y - 36

        AddControl(panel, MakeButton(content, "ProfilerPrint", "Print profiler report", 32, y, 180, function()
            ProfilerPrintReport()
        end)); y = y - 42

        y = SectionTitle(content, "WeakAuras anchor stats", y)
        local waStats = CreateFrame("CheckButton", content:GetName() .. "WeakAuraAnchorStatsEnabled", content, "InterfaceOptionsCheckButtonTemplate")
        waStats:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
        local waStatsText = waStats.Text or _G[waStats:GetName() .. "Text"]
        if waStatsText then waStatsText:SetText("Show WeakAuras anchor stats panel") end
        waStats.tooltipText = "Show WeakAuras anchor stats panel"
        waStats.tooltipRequirement = "Shows a small movable panel with anchor engine timing, update cadence and fallback/relink counters."
        waStats:SetScript("OnClick", function(self)
            SetWeakAuraAnchorStatsPanelEnabled(self:GetChecked() and true or false)
        end)
        waStats.Refresh = function(self)
            self:SetChecked(CFG.debugWeakAuraAnchorStatsEnabled and true or false)
        end
        AddControl(panel, waStats); y = y - 42

        AddControl(panel, MakeButton(content, "WeakAuraAnchorStatsReset", "Reset anchor stats", 32, y, 180, function()
            ResetWeakAuraAnchorStats()
        end)); y = y - 48

        y = SectionTitle(content, "CPU benchmark", y)
        AddControl(panel, MakeSlider(content, "BenchmarkSeconds", "Benchmark seconds", "debugBenchmarkSeconds", 5, 300, 5, 32, y)); y = y - 52

        AddControl(panel, MakeButton(content, "CpuSnapshot", "Print WoW CPU total", 32, y, 180, function()
            PrintAddonCPUUsageSnapshot()
        end)); y = y - 36

        AddControl(panel, MakeButton(content, "BenchmarkCPU", "Start CPU benchmark", 32, y, 180, function()
            StartCPUBenchmark(CFG.debugBenchmarkSeconds or 60, false)
        end)); y = y - 36

        AddControl(panel, MakeButton(content, "BenchmarkProfiler", "Start profiler benchmark", 32, y, 180, function()
            StartCPUBenchmark(CFG.debugBenchmarkSeconds or 60, true)
        end)); y = y - 48

        local note = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        note:SetPoint("TOPLEFT", content, "TOPLEFT", 32, y)
        note:SetWidth(590)
        note:SetJustifyH("LEFT")
        note:SetText("Use this only while testing. Suggested flow:\n1. Enable profiler or run /s2ke prof on\n2. Test for 30-60 seconds\n3. Print report or run /s2ke prof print\n4. Disable it again with /s2ke prof off\n\nSlash commands:\n/s2ke help - list all commands\n/s2ke prof on - enable and reset profiler\n/s2ke prof off - disable profiler\n/s2ke prof reset - reset data\n/s2ke prof print - print report\n/s2ke prof - print report")
        y = y - 210

        content:SetHeight(math.abs(y) + 80)
        RegisterS2KConfigPanel("debug", "Debug", panel, 4)
    end

    State.optionsBuildComplete = true
    LayoutAllS2KConfigContent(true)
    SelectS2KConfigPanel("general", "general")
end
