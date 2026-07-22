-- =========================================================
-- Chat enhancements (WoW 7.3.5 / Interface 70300)
-- =========================================================

CHAT_POSITION_OPTIONS = {
    { key = "TOP", label = "Top" },
    { key = "BOTTOM", label = "Bottom" },
}

CHAT_ALIGN_OPTIONS = {
    { key = "LEFT", label = "Left" },
    { key = "RIGHT", label = "Right" },
}

CHAT_EDITBOX_BORDER_OPTIONS = {
    { key = "BLIZZARD", label = "Blizzard" },
    { key = "NONE", label = "None" },
    { key = "THIN", label = "Thin" },
    { key = "TOOLTIP", label = "Tooltip" },
    { key = "DIALOG", label = "Dialog" },
}

local chatOriginals = setmetatable({}, { __mode = "k" })
local chatTextureCoords = setmetatable({}, { __mode = "k" })
local chatSideButtonState = setmetatable({}, { __mode = "k" })
local chatSideButtonHooked = setmetatable({}, { __mode = "k" })
local chatEditBoxTextureAlpha = setmetatable({}, { __mode = "k" })
local chatEditBoxBorderFrames = setmetatable({}, { __mode = "k" })
local chatEditBoxBackgroundTextures = setmetatable({}, { __mode = "k" })

local function CapturePoints(object)
    local points = {}
    if not object or not object.GetNumPoints then return points end
    for i = 1, object:GetNumPoints() do
        points[i] = { object:GetPoint(i) }
    end
    return points
end

local function RestorePoints(object, points)
    if not object or not object.ClearAllPoints or not points then return end
    object:ClearAllPoints()
    for _, point in ipairs(points) do object:SetPoint(unpack(point)) end
end

local function GetChatObjects(frame)
    if not frame or not frame.GetName then return end
    local name = frame:GetName()
    return _G[name .. "EditBox"], _G[name .. "Tab"],
        _G[name .. "ButtonFrame"], _G[name .. "ResizeButton"]
end

local function SetChatManagedObjectShown(object, shown, forceShow)
    if not object then return end
    local state = chatSideButtonState[object]
    if not shown then
        if not state or not state.hiddenByS2K then
            state = state or {}
            state.shown = object:IsShown()
            state.alpha = object:GetAlpha()
            state.mouseEnabled = object.IsMouseEnabled and object:IsMouseEnabled()
            state.hiddenByS2K = true
            chatSideButtonState[object] = state
        end
        object:SetAlpha(0)
        if object.EnableMouse then object:EnableMouse(false) end
        object:Hide()
    else
        if state and state.hiddenByS2K then
            state.hiddenByS2K = false
            object:SetAlpha(state.alpha or 1)
            if object.EnableMouse then object:EnableMouse(state.mouseEnabled ~= false) end
            if state.shown or forceShow then object:Show() else object:Hide() end
        elseif forceShow then
            object:SetAlpha(1)
            if object.EnableMouse then object:EnableMouse(true) end
            object:Show()
        end
    end
end

local function GetButtonFrameParts(frame)
    if not frame then return end
    local prefix = frame:GetName() .. "ButtonFrame"
    return _G[prefix], _G[prefix .. "UpButton"], _G[prefix .. "DownButton"],
        _G[prefix .. "BottomButton"], _G[prefix .. "Background"] or _G[prefix .. "BackGround"],
        _G[prefix .. "RightTexture"] or _G[prefix .. "RightTexure"],
        _G[prefix .. "TopTexture"], _G[prefix .. "TopRightTexture"],
        _G[prefix .. "BottomTexture"], _G[prefix .. "BottomRightTexture"],
        _G[prefix .. "LeftTexture"], _G[prefix .. "TopLeftTexture"],
        _G[prefix .. "BottomLeftTexture"]
end

local function IsPointerOverChatFrame(frame)
    if not frame then return false end
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent and UIParent:GetEffectiveScale() or 1
    cursorX, cursorY = cursorX / scale, cursorY / scale
    local function IsInside(object)
        if not object or not object:IsShown() then return false end
        local left, right, top, bottom = object:GetLeft(), object:GetRight(), object:GetTop(), object:GetBottom()
        return left and right and top and bottom
            and cursorX >= left and cursorX <= right
            and cursorY >= bottom and cursorY <= top
    end
    local editBox, tab = GetChatObjects(frame)
    local buttonFrame, up, down, bottom = GetButtonFrameParts(frame)
    local objects = { frame, tab, editBox, buttonFrame, up, down, bottom }
    for _, object in ipairs(objects) do
        if IsInside(object) then return true end
    end
    return false
end

function UpdateSmartChatButtons(frame)
    local buttonFrame, up, down, bottom, background, rightTexture,
        topTexture, topRightTexture, bottomTexture, bottomRightTexture,
        leftTexture, topLeftTexture, bottomLeftTexture = GetButtonFrameParts(frame)
    SetChatManagedObjectShown(background, false)
    SetChatManagedObjectShown(rightTexture, false)
    SetChatManagedObjectShown(topTexture, false)
    SetChatManagedObjectShown(topRightTexture, false)
    SetChatManagedObjectShown(bottomTexture, false)
    SetChatManagedObjectShown(bottomRightTexture, false)
    SetChatManagedObjectShown(leftTexture, false)
    SetChatManagedObjectShown(topLeftTexture, false)
    SetChatManagedObjectShown(bottomLeftTexture, false)

    local enabled = CFG and CFG.chatEnabled and CFG.chatButtonFrameEnabled ~= false
    SetChatManagedObjectShown(buttonFrame, enabled, enabled)
    if not enabled then
        SetChatManagedObjectShown(up, false)
        SetChatManagedObjectShown(down, false)
        SetChatManagedObjectShown(bottom, false)
        return
    end

    local smart = CFG.chatButtonFrameSmart == true
    local hovering = not smart or IsPointerOverChatFrame(frame)
    SetChatManagedObjectShown(up, hovering, hovering)
    SetChatManagedObjectShown(down, hovering, hovering)
    local scrolledUp = frame.AtBottom and not frame:AtBottom()
    SetChatManagedObjectShown(bottom, hovering and (not smart or scrolledUp), hovering and (not smart or scrolledUp))
    if SetSmartChatWatcherActive then SetSmartChatWatcherActive(frame, smart and hovering) end
end

local function ScheduleSmartChatButtonsUpdate(frame)
    if not frame or frame.s2kSmartUpdatePending then return end
    frame.s2kSmartUpdatePending = true
    local function Update()
        frame.s2kSmartUpdatePending = nil
        UpdateSmartChatButtons(frame)
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Update) else Update() end
end

function SetSmartChatWatcherActive(frame, active)
    if not frame then return end
    local watcher = State.chatSmartWatchers[frame]
    if not active then
        if watcher then watcher:SetScript("OnUpdate", nil); watcher:Hide() end
        return
    end
    if not watcher then
        watcher = CreateFrame("Frame", nil, UIParent)
        watcher.s2kElapsed = 0
        State.chatSmartWatchers[frame] = watcher
    end
    watcher:SetScript("OnUpdate", function(self, elapsed)
        self.s2kElapsed = self.s2kElapsed + elapsed
        if self.s2kElapsed < 0.05 then return end
        self.s2kElapsed = 0
        if not CFG.chatEnabled or not CFG.chatButtonFrameEnabled or not CFG.chatButtonFrameSmart then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            return
        end
        if not IsPointerOverChatFrame(frame) then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            UpdateSmartChatButtons(frame)
        end
    end)
    watcher:Show()
end

local function StopAllSmartChatWatchers()
    for _, watcher in pairs(State.chatSmartWatchers or {}) do
        watcher:SetScript("OnUpdate", nil)
        watcher:Hide()
    end
end

local function HookSmartHoverObject(object, frame)
    if not object or chatSideButtonHooked[object] then return end
    chatSideButtonHooked[object] = true
    object:HookScript("OnEnter", function() UpdateSmartChatButtons(frame) end)
    object:HookScript("OnLeave", function() ScheduleSmartChatButtonsUpdate(frame) end)
end

function ApplyChatSideButtonsVisibility()
    SetChatManagedObjectShown(_G.QuickJoinToastButton, not (CFG.chatEnabled and CFG.chatQuickJoinButtonEnabled == false), false)
    SetChatManagedObjectShown(_G.ChatFrameMenuButton, not (CFG.chatEnabled and CFG.chatMenuButtonEnabled == false), false)
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local frame = _G["ChatFrame" .. i]
        if frame then UpdateSmartChatButtons(frame) end
    end
end

local function RestoreAllChatManagedObjects()
    for object, state in pairs(chatSideButtonState) do
        if object and state and state.hiddenByS2K then SetChatManagedObjectShown(object, true, false) end
    end
end

local function CaptureChatFrame(frame)
    if chatOriginals[frame] then return chatOriginals[frame] end
    local editBox, tab, buttonFrame, resizeButton = GetChatObjects(frame)
    local fontPath, fontSize, fontFlags = frame:GetFont()
    local original = {
        fontPath = fontPath,
        fontSize = fontSize,
        fontFlags = fontFlags,
        justify = frame:GetJustifyH(),
        editJustify = editBox and editBox:GetJustifyH(),
        editPoints = CapturePoints(editBox),
        buttonPoints = CapturePoints(buttonFrame),
        resizePoints = CapturePoints(resizeButton),
        buttonAlpha = buttonFrame and buttonFrame:GetAlpha(),
        buttonShown = buttonFrame and buttonFrame:IsShown(),
    }
    if frame.GetClampRectInsets then
        original.clampInsets = { frame:GetClampRectInsets() }
    end
    if frame.IsClampedToScreen then
        original.clampedToScreen = frame:IsClampedToScreen()
    end
    if editBox then
        original.editFontPath, original.editFontSize, original.editFontFlags = editBox:GetFont()
    end
    chatOriginals[frame] = original
    return original
end

local function ApplyChatFrameClampInsets(frame, editBox)
    if not frame or not frame.SetClampRectInsets then return end

    local offset = tonumber(CFG.chatEditBoxOffset) or 0
    local editBoxHeight = editBox and editBox.GetHeight and editBox:GetHeight() or 0
    local editBoxExtent = math.max(0, editBoxHeight + offset)
    local topInset, bottomInset = 0, 0

    if CFG.chatEditBoxPosition == "TOP" then
        topInset = editBoxExtent
    else
        bottomInset = -editBoxExtent
    end

    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:SetClampRectInsets(0, 0, topInset, bottomInset)
end

local function CaptureObjectTextures(object)
    if not object then return end
    local regions = { object:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.IsObjectType and region:IsObjectType("Texture") and not chatTextureCoords[region] then
            chatTextureCoords[region] = { region:GetTexCoord() }
        end
    end
end

local function ApplyHorizontalTextureFlip(object, flipped)
    if not object then return end
    CaptureObjectTextures(object)
    local regions = { object:GetRegions() }
    for _, region in ipairs(regions) do
        local coord = chatTextureCoords[region]
        if coord and #coord >= 8 then
            if flipped then
                region:SetTexCoord(coord[5], coord[6], coord[7], coord[8], coord[1], coord[2], coord[3], coord[4])
            else
                region:SetTexCoord(unpack(coord))
            end
        end
    end
end

local function RestoreChatEditBoxBorder(editBox)
    if not editBox then return end
    local regions = { editBox:GetRegions() }
    for _, region in ipairs(regions) do
        local alpha = chatEditBoxTextureAlpha[region]
        if alpha ~= nil then region:SetAlpha(alpha) end
    end
    local border = chatEditBoxBorderFrames[editBox]
    if border then border:Hide() end
    local background = chatEditBoxBackgroundTextures[editBox]
    if background then background:Hide() end
end

local function ApplyChatEditBoxBackground(editBox, style, border, borderInset)
    local background = chatEditBoxBackgroundTextures[editBox]
    if style == "BLIZZARD" then
        if background then background:Hide() end
        return
    end
    if not background then
        background = editBox:CreateTexture(nil, "BACKGROUND", nil, 7)
        chatEditBoxBackgroundTextures[editBox] = background
    end
    local _, fontSize = editBox:GetFont()
    fontSize = tonumber(fontSize) or 14
    background:ClearAllPoints()
    if border then
        local automaticInset = math.max(1, math.ceil((tonumber(borderInset) or 1) / 2))
        local insetOffset = tonumber(CFG.chatEditBoxBackgroundInset) or 0
        borderInset = math.max(0, automaticInset + insetOffset)
        background:SetPoint("TOPLEFT", border, "TOPLEFT", borderInset, -borderInset)
        background:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -borderInset, borderInset)
    else
        background:SetPoint("LEFT", editBox, "LEFT", 0, 0)
        background:SetPoint("RIGHT", editBox, "RIGHT", 0, 0)
        background:SetHeight(math.max(16, math.floor(fontSize + 6.5)))
    end
    background:SetColorTexture(
        tonumber(CFG.chatEditBoxBackgroundColorR) or 0,
        tonumber(CFG.chatEditBoxBackgroundColorG) or 0,
        tonumber(CFG.chatEditBoxBackgroundColorB) or 0,
        tonumber(CFG.chatEditBoxBackgroundColorA) or 0
    )
    background:Show()
end

local function ApplyChatEditBoxBorder(editBox)
    if not editBox then return end
    local style = tostring(CFG.chatEditBoxBorderStyle or "BLIZZARD"):upper()
    if style == "BLIZZARD" then ApplyChatEditBoxBackground(editBox, style, nil) end
    local regions = { editBox:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region ~= chatEditBoxBackgroundTextures[editBox]
        and region.IsObjectType and region:IsObjectType("Texture") then
            if chatEditBoxTextureAlpha[region] == nil then chatEditBoxTextureAlpha[region] = region:GetAlpha() end
            region:SetAlpha(style == "BLIZZARD" and chatEditBoxTextureAlpha[region] or 0)
        end
    end

    local border = chatEditBoxBorderFrames[editBox]
    if style == "BLIZZARD" or style == "NONE" then
        if border then border:Hide() end
        if style == "NONE" then ApplyChatEditBoxBackground(editBox, style, nil) end
        return
    end

    if not border then
        border = CreateFrame("Frame", nil, editBox)
        border:SetFrameLevel(editBox:GetFrameLevel() + 5)
        border:EnableMouse(false)
        chatEditBoxBorderFrames[editBox] = border
    end

    local _, fontSize = editBox:GetFont()
    fontSize = tonumber(fontSize) or 14
    local thickness = math.max(1, math.min(16, tonumber(CFG.chatEditBoxBorderThickness) or 4))
    local borderInset = math.max(-16, math.min(16, tonumber(CFG.chatEditBoxBorderInset) or 0))
    local borderHeight = math.max(4, math.floor(fontSize + 12.5 - (borderInset * 2)))
    local horizontalInset = math.ceil(thickness / 2) + 1 + borderInset
    border:ClearAllPoints()
    border:SetPoint("LEFT", editBox, "LEFT", horizontalInset, 0)
    border:SetPoint("RIGHT", editBox, "RIGHT", -horizontalInset, 0)
    border:SetHeight(borderHeight)

    if style == "THIN" then
        border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = thickness })
        border:SetBackdropBorderColor(0, 0, 0, 1)
    elseif style == "DIALOG" then
        border:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = thickness })
        border:SetBackdropBorderColor(1, 1, 1, 1)
    else
        border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = thickness })
        border:SetBackdropBorderColor(1, 1, 1, 1)
    end
    border:Show()
    ApplyChatEditBoxBackground(editBox, style, border, thickness)
end

local function PositionChatFrameParts(frame)
    local editBox, tab, buttonFrame, resizeButton = GetChatObjects(frame)
    if editBox then
        local editBoxOffset = tonumber(CFG.chatEditBoxOffset) or 0
        local horizontalOffset = tonumber(CFG.chatEditBoxHorizontalOffset)
        if horizontalOffset == nil then horizontalOffset = -5 end
        local editBoxWidth = math.max(0, tonumber(CFG.chatEditBoxWidth) or 0)
        local alignRight = CFG.chatTextAlign == "RIGHT"
        editBox:ClearAllPoints()
        if CFG.chatEditBoxPosition == "TOP" then
            if alignRight then
                editBox:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -horizontalOffset, editBoxOffset)
                if editBoxWidth > 0 then
                    editBox:SetWidth(editBoxWidth)
                else
                    editBox:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -5, editBoxOffset)
                end
            else
                editBox:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", horizontalOffset, editBoxOffset)
                if editBoxWidth > 0 then
                    editBox:SetWidth(editBoxWidth)
                else
                    editBox:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 5, editBoxOffset)
                end
            end
        else
            if alignRight then
                editBox:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -horizontalOffset, -editBoxOffset)
                if editBoxWidth > 0 then
                    editBox:SetWidth(editBoxWidth)
                else
                    editBox:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -5, -editBoxOffset)
                end
            else
                editBox:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", horizontalOffset, -editBoxOffset)
                if editBoxWidth > 0 then
                    editBox:SetWidth(editBoxWidth)
                else
                    editBox:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 5, -editBoxOffset)
                end
            end
        end
        ApplyChatEditBoxBorder(editBox)
    end
    ApplyChatFrameClampInsets(frame, editBox)

    if buttonFrame then
        buttonFrame:ClearAllPoints()
        if CFG.chatButtonAlign == "RIGHT" then
            buttonFrame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 2, 0)
            buttonFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 2, 0)
        else
            buttonFrame:SetPoint("TOPRIGHT", frame, "TOPLEFT", -2, 0)
            buttonFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -2, 0)
        end
    end

    if resizeButton then
        resizeButton:ClearAllPoints()
        if CFG.chatTextAlign == "RIGHT" then
            resizeButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -3, -3)
        else
            resizeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -3)
        end
        ApplyHorizontalTextureFlip(resizeButton, CFG.chatTextAlign == "RIGHT")
    end

end

local function RestoreChatFrame(frame)
    local original = chatOriginals[frame]
    if not original then return end
    local editBox, tab, buttonFrame, resizeButton = GetChatObjects(frame)
    frame:SetFont(original.fontPath, original.fontSize, original.fontFlags)
    frame:SetJustifyH(original.justify or "LEFT")
    if editBox then
        editBox:SetFont(original.editFontPath, original.editFontSize, original.editFontFlags)
        editBox:SetJustifyH(original.editJustify or "LEFT")
    end
    RestorePoints(editBox, original.editPoints)
    RestoreChatEditBoxBorder(editBox)
    RestorePoints(buttonFrame, original.buttonPoints)
    RestorePoints(resizeButton, original.resizePoints)
    ApplyHorizontalTextureFlip(resizeButton, false)
    if original.clampInsets and frame.SetClampRectInsets then
        frame:SetClampRectInsets(unpack(original.clampInsets))
    end
    if original.clampedToScreen ~= nil and frame.SetClampedToScreen then
        frame:SetClampedToScreen(original.clampedToScreen)
    end
    if buttonFrame then
        buttonFrame:SetAlpha(original.buttonAlpha or 1)
        buttonFrame:EnableMouse(true)
        if original.buttonShown then buttonFrame:Show() else buttonFrame:Hide() end
    end
end

local function ChatCopyWindowScroll(delta)
    local window = State.chatCopyWindow
    if not window then return end
    local scroll = window.scroll
    local value = math.max(0, math.min(scroll:GetVerticalScrollRange() or 0, (scroll:GetVerticalScroll() or 0) + delta))
    scroll:SetVerticalScroll(value)
    window.editBox:SetFocus()
end

local function UpdateChatCopyContentHeight(window)
    local width = math.max(100, window.scroll:GetWidth() - 24)
    window.editBox:SetWidth(width)
    window.measure:SetWidth(width - 8)
    window.measure:SetText(window.editBox:GetText() or "")
    window.editBox:SetHeight(math.max(window.scroll:GetHeight(), window.measure:GetStringHeight() + 24))
end

local function SaveChatCopyWindowGeometry(window)
    if not DB or not window then return end
    DB.chatCopyWindowWidth = math.floor(window:GetWidth() + 0.5)
    DB.chatCopyWindowHeight = math.floor(window:GetHeight() + 0.5)
    local centerX, centerY = window:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    DB.chatCopyWindowX = (tonumber(centerX) or parentX) - parentX
    DB.chatCopyWindowY = (tonumber(centerY) or parentY) - parentY
end

local function CreateChatCopyWindow()
    if State.chatCopyWindow then return State.chatCopyWindow end
    local window = CreateFrame("Frame", "s2k_ChatCopyWindow", UIParent)
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:SetResizable(true)
    window:SetMinResize(320, 240)
    window:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SaveChatCopyWindowGeometry(self) end)
    window:SetScript("OnSizeChanged", function(self) if self.scroll then UpdateChatCopyContentHeight(self) end end)
    window:Hide()

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText(S2K_L("Chat Copy"))
    window.title = title

    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() window:Hide() end)

    local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -42)
    scroll:SetPoint("BOTTOMRIGHT", -42, 48)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) ChatCopyWindowScroll(delta > 0 and -48 or 48) end)
    window.scroll = scroll

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetTextInsets(4, 4, 4, 4)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnTextChanged", function() UpdateChatCopyContentHeight(window) end)
    local function StopSelectionAutoScroll(self)
        self.s2kSelecting = false
        self.s2kScrollElapsed = 0
        self:SetScript("OnUpdate", nil)
    end
    local function SelectionAutoScroll(self, elapsed)
        if not self.s2kSelecting or not IsMouseButtonDown("LeftButton") then
            StopSelectionAutoScroll(self)
            return
        end
        self.s2kScrollElapsed = (self.s2kScrollElapsed or 0) + elapsed
        if self.s2kScrollElapsed < 0.03 then return end
        self.s2kScrollElapsed = 0
        local _, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        y = y / scale
        local top, bottom = scroll:GetTop(), scroll:GetBottom()
        if top and y > top - 18 then ChatCopyWindowScroll(-18)
        elseif bottom and y < bottom + 18 then ChatCopyWindowScroll(18) end
    end
    editBox:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.s2kSelecting = true
            self.s2kScrollElapsed = 0
            self:SetScript("OnUpdate", SelectionAutoScroll)
        end
    end)
    editBox:SetScript("OnMouseUp", StopSelectionAutoScroll)
    editBox:SetScript("OnHide", StopSelectionAutoScroll)
    scroll:SetScrollChild(editBox)
    window.editBox = editBox

    local measure = window:CreateFontString(nil, "ARTWORK")
    measure:SetFontObject(ChatFontNormal)
    measure:SetJustifyH("LEFT")
    measure:SetJustifyV("TOP")
    measure:Hide()
    window.measure = measure

    local up = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    up:SetSize(88, 24)
    up:SetPoint("BOTTOMLEFT", 18, 16)
    up:SetText(S2K_L("Scroll Up"))
    up:SetScript("OnClick", function() ChatCopyWindowScroll(-96) end)

    local down = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    down:SetSize(88, 24)
    down:SetPoint("LEFT", up, "RIGHT", 8, 0)
    down:SetText(S2K_L("Scroll Down"))
    down:SetScript("OnClick", function() ChatCopyWindowScroll(96) end)

    local resize = CreateFrame("Button", nil, window)
    resize:SetSize(20, 20)
    resize:SetPoint("BOTTOMRIGHT", -8, 8)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then window:StartSizing("BOTTOMRIGHT") end end)
    resize:SetScript("OnMouseUp", function() window:StopMovingOrSizing(); SaveChatCopyWindowGeometry(window) end)

    State.chatCopyWindow = window
    return window
end

local function GetChatFrameText(frame)
    local lines = {}
    local count = frame and frame.GetNumMessages and frame:GetNumMessages() or 0
    for i = 1, count do
        local text = frame:GetMessageInfo(i)
        if text then
            text = tostring(text)
            text = text:gsub("|H.-|h(.-)|h", "%1")
            text = text:gsub("|T.-|t", "")
            text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
            text = text:gsub("|r", "")
            text = text:gsub("||", "|")
            lines[#lines + 1] = text
        end
    end
    return table.concat(lines, "\n")
end

function ShowChatCopyWindow(frame)
    if not CFG.chatEnabled or not CFG.chatCopyEnabled or not frame then return end
    local window = CreateChatCopyWindow()
    local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
    local width = tonumber(DB.chatCopyWindowWidth) or frame:GetWidth()
    local height = tonumber(DB.chatCopyWindowHeight) or (screenHeight * 0.80)
    width = math.max(320, math.min(width, screenWidth - 40))
    height = math.max(240, math.min(height, screenHeight - 40))
    window:SetSize(width, height)
    window:ClearAllPoints()
    if DB.chatCopyWindowX and DB.chatCopyWindowY then
        window:SetPoint("CENTER", UIParent, "CENTER", DB.chatCopyWindowX, DB.chatCopyWindowY)
    else
        window:SetPoint("CENTER")
    end
    local chatName = frame.name
    if not chatName and FCF_GetChatWindowInfo and frame.GetID then chatName = FCF_GetChatWindowInfo(frame:GetID()) end
    window.title:SetText((chatName or S2K_L("Chat")) .. " - " .. S2K_L("Chat Copy"))
    window.editBox:SetText(GetChatFrameText(frame))
    window.editBox:SetCursorPosition(0)
    window.scroll:SetVerticalScroll(0)
    UpdateChatCopyContentHeight(window)
    window:Show()
    window.editBox:SetFocus()
end

local function HookChatFrame(frame)
    if not frame or State.chatHookedFrames[frame] then return end
    State.chatHookedFrames[frame] = true
    CaptureChatFrame(frame)
    local _, tab = GetChatObjects(frame)
    if tab then
        tab:HookScript("OnClick", function(_, button)
            if button == "LeftButton" and IsShiftKeyDown() then ShowChatCopyWindow(frame) end
        end)
    end
    local editBox, _, buttonFrame = GetChatObjects(frame)
    local _, up, down, bottom, background, rightTexture,
        topTexture, topRightTexture, bottomTexture, bottomRightTexture,
        leftTexture, topLeftTexture, bottomLeftTexture = GetButtonFrameParts(frame)
    local hoverObjects = { frame, tab, editBox, buttonFrame, up, down, bottom }
    for _, object in ipairs(hoverObjects) do HookSmartHoverObject(object, frame) end
    frame:HookScript("OnMouseWheel", function()
        ScheduleSmartChatButtonsUpdate(frame)
        if C_Timer and C_Timer.After then
            C_Timer.After(0.05, function() UpdateSmartChatButtons(frame) end)
        end
    end)
    for _, button in ipairs({ up, down, bottom }) do
        if button then
            button:HookScript("OnClick", function() ScheduleSmartChatButtonsUpdate(frame) end)
            button:HookScript("OnShow", function() UpdateSmartChatButtons(frame) end)
        end
    end
    if buttonFrame then buttonFrame:HookScript("OnShow", function() UpdateSmartChatButtons(frame) end) end
    if background then SetChatManagedObjectShown(background, false) end
    if rightTexture then SetChatManagedObjectShown(rightTexture, false) end
    if topTexture then SetChatManagedObjectShown(topTexture, false) end
    if topRightTexture then SetChatManagedObjectShown(topRightTexture, false) end
    if bottomTexture then SetChatManagedObjectShown(bottomTexture, false) end
    if bottomRightTexture then SetChatManagedObjectShown(bottomRightTexture, false) end
    if leftTexture then SetChatManagedObjectShown(leftTexture, false) end
    if topLeftTexture then SetChatManagedObjectShown(topLeftTexture, false) end
    if bottomLeftTexture then SetChatManagedObjectShown(bottomLeftTexture, false) end
end

local function HookGlobalChatButtonToggle(button, settingKey)
    if not button or button.s2kChatToggleHooked then return end
    button.s2kChatToggleHooked = true
    button:HookScript("OnShow", function(self)
        if CFG and CFG.chatEnabled and CFG[settingKey] == false then self:Hide() end
    end)
end

local function GetChatButtonBrokerIcon(button, fallback)
    local texture = button and button.GetNormalTexture and button:GetNormalTexture()
    local path = texture and texture.GetTexture and texture:GetTexture()
    return path or fallback
end

local function ClickChatButtonFromBroker(button, firstArg, secondArg)
    if not button or not button.Click then return end
    local mouseButton = type(secondArg) == "string" and secondArg
        or (type(firstArg) == "string" and firstArg or "LeftButton")
    button:Click(mouseButton)
end

local function GetChatMenuFrameRect(frame)
    if not frame or not frame.GetLeft then return end
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or not bottom then return end
    local parentScale = UIParent:GetEffectiveScale() or 1
    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or parentScale
    local scale = frameScale / parentScale
    return left * scale, right * scale, top * scale, bottom * scale
end

local function PlaceChatMenuBeside(menu, anchor, parentMenu)
    if not menu or not menu:IsShown() or not anchor then return end
    local anchorLeft, anchorRight, anchorTop, anchorBottom = GetChatMenuFrameRect(anchor)
    if not anchorLeft then return end

    local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
    local parentScale = UIParent:GetEffectiveScale() or 1
    local menuScale = menu.GetEffectiveScale and menu:GetEffectiveScale() or parentScale
    local scale = menuScale / parentScale
    local menuWidth = (menu:GetWidth() or 0) * scale
    local menuHeight = (menu:GetHeight() or 0) * scale
    if menuWidth <= 0 or menuHeight <= 0 then return end

    local gap = 4
    local boundaryLeft, boundaryRight = anchorLeft, anchorRight
    if parentMenu then
        local parentLeft, parentRight = GetChatMenuFrameRect(parentMenu)
        if parentLeft then boundaryLeft, boundaryRight = parentLeft, parentRight end
    end

    local rightSpace = screenWidth - boundaryRight - gap
    local leftSpace = boundaryLeft - gap
    local x
    if rightSpace >= menuWidth or rightSpace >= leftSpace then
        x = boundaryRight + gap
    else
        x = boundaryLeft - menuWidth - gap
    end

    local y = math.min(screenHeight, math.max(menuHeight, anchorTop))
    x = math.max(0, math.min(screenWidth - menuWidth, x))

    -- If neither side can hold the root menu, place it above or below the LDB icon.
    if not parentMenu and rightSpace < menuWidth and leftSpace < menuWidth then
        x = math.max(0, math.min(screenWidth - menuWidth, anchorLeft))
        local spaceAbove = screenHeight - anchorTop - gap
        local spaceBelow = anchorBottom - gap
        if spaceBelow >= menuHeight or spaceBelow >= spaceAbove then
            y = anchorBottom - gap
        else
            y = anchorTop + gap + menuHeight
        end
        y = math.min(screenHeight, math.max(menuHeight, y))
    end

    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

local function PositionChatMenuLevel(level)
    local menu = _G["DropDownList" .. level]
    local brokerAnchor = State.chatMenuBrokerAnchor
    if not menu or not brokerAnchor or not menu:IsShown() then return end

    if level == 1 then
        PlaceChatMenuBeside(menu, brokerAnchor)
        return
    end

    local _, relativeTo = menu:GetPoint(1)
    local parentMenu = _G["DropDownList" .. (level - 1)]
    PlaceChatMenuBeside(menu, relativeTo or parentMenu, parentMenu)
end

local function HookChatMenuDropDowns()
    local maximumLevel = tonumber(UIDROPDOWNMENU_MAXLEVELS) or 2
    for level = 1, maximumLevel do
        local menuLevel = level
        local menu = _G["DropDownList" .. level]
        if menu and not menu.s2kChatMenuPositionHooked then
            menu.s2kChatMenuPositionHooked = true
            menu:HookScript("OnShow", function()
                if State.chatMenuBrokerAnchor and C_Timer and C_Timer.After then
                    C_Timer.After(0, function() PositionChatMenuLevel(menuLevel) end)
                elseif State.chatMenuBrokerAnchor then
                    PositionChatMenuLevel(menuLevel)
                end
            end)
            if menuLevel == 1 then
                menu:HookScript("OnHide", function() State.chatMenuBrokerAnchor = nil end)
            end
        end
    end
end

local CHAT_SUBMENU_NAMES = { "EmoteMenu", "LanguageMenu", "VoiceMacroMenu" }

local function PositionBlizzardChatMenu(menu, parentMenu)
    if not menu or not menu:IsShown() or not State.chatMenuBrokerAnchor then return end
    if not parentMenu then
        PlaceChatMenuBeside(menu, State.chatMenuBrokerAnchor)
        return
    end

    local _, relativeTo = menu:GetPoint(1)
    PlaceChatMenuBeside(menu, relativeTo or parentMenu, parentMenu)
end

local function HookBlizzardChatMenus()
    local rootMenu = _G.ChatMenu
    if ChatFrameMenu_UpdateAnchorPoint and not State.chatMenuAnchorFunctionHooked then
        State.chatMenuAnchorFunctionHooked = true
        hooksecurefunc("ChatFrameMenu_UpdateAnchorPoint", function()
            if State.chatMenuBrokerAnchor and _G.ChatMenu and _G.ChatMenu:IsShown() then
                PositionBlizzardChatMenu(_G.ChatMenu)
            end
        end)
    end
    if rootMenu and not rootMenu.s2kChatMenuPositionHooked then
        rootMenu.s2kChatMenuPositionHooked = true
        rootMenu:HookScript("OnShow", function(self)
            if not State.chatMenuBrokerAnchor then return end
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function() PositionBlizzardChatMenu(self) end)
            else
                PositionBlizzardChatMenu(self)
            end
        end)
        rootMenu:HookScript("OnHide", function() State.chatMenuBrokerAnchor = nil end)
    end

    for _, menuName in ipairs(CHAT_SUBMENU_NAMES) do
        local menu = _G[menuName]
        if menu and not menu.s2kChatMenuPositionHooked then
            menu.s2kChatMenuPositionHooked = true
            menu:HookScript("OnShow", function(self)
                if not State.chatMenuBrokerAnchor then return end
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function() PositionBlizzardChatMenu(self, _G.ChatMenu) end)
                else
                    PositionBlizzardChatMenu(self, _G.ChatMenu)
                end
            end)
        end
    end
end

local function ClickChatMenuFromBroker(button, brokerFrame, mouseButton)
    if not button or not button.Click then return end

    local anchor = brokerFrame
    if not anchor or not anchor.GetLeft then
        anchor = GetMouseFocus and GetMouseFocus() or nil
    end
    while anchor and (not anchor.GetLeft or not anchor:GetLeft()) and anchor.GetParent do
        anchor = anchor:GetParent()
    end
    if not anchor or not anchor.GetLeft or anchor == button then
        ClickChatButtonFromBroker(button, brokerFrame, mouseButton)
        return
    end

    HookChatMenuDropDowns()
    HookBlizzardChatMenus()
    State.chatMenuBrokerAnchor = anchor
    button:Click(type(mouseButton) == "string" and mouseButton or "LeftButton")
    local rootMenu = _G.ChatMenu or _G.DropDownList1
    State.chatMenuBrokerAnchor = rootMenu and rootMenu:IsShown() and anchor or nil
    if rootMenu == _G.ChatMenu then
        PositionBlizzardChatMenu(rootMenu)
    else
        PositionChatMenuLevel(1)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if rootMenu == _G.ChatMenu then
                PositionBlizzardChatMenu(rootMenu)
            else
                PositionChatMenuLevel(1)
            end
        end)
    end
end

local function UpdateChatButtonBroker(ldb, stateKey, objectName, label, enabled, button, fallbackIcon, isChatMenu)
    local object = State[stateKey]
    if enabled and not object then
        object = ldb:GetDataObjectByName(objectName)
        if not object then
            object = ldb:NewDataObject(objectName, { type = "launcher", label = label, text = label })
        end
        State[stateKey] = object
    end
    if not object then return end

    if enabled then
        object.type = "launcher"
        object.label = S2K_L(label)
        object.text = S2K_L(label)
        object.icon = GetChatButtonBrokerIcon(button, fallbackIcon)
        object.OnClick = function(firstArg, secondArg)
            if isChatMenu and CFG.chatMenuButtonEnabled == false then
                ClickChatMenuFromBroker(button, firstArg, secondArg)
            else
                ClickChatButtonFromBroker(button, firstArg, secondArg)
            end
        end
        object.OnTooltipShow = function(tooltip)
            if tooltip and tooltip.AddLine then
                tooltip:AddLine(S2K_L(label), 1, 0.82, 0)
                tooltip:AddLine(S2K_L("Click to activate the Blizzard chat button."), 1, 1, 1)
            end
        end
    else
        object.type = nil
        object.text = ""
        object.icon = nil
        object.OnClick = nil
        object.OnTooltipShow = nil
    end
end

function InitializeChatButtonBrokers()
    local ldb = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not ldb or not CFG then return end
    local chatEnabled = CFG.chatEnabled == true
    UpdateChatButtonBroker(
        ldb, "chatQuickJoinBroker", "s2k:Quick Join", "Quick Join",
        chatEnabled and CFG.chatQuickJoinLDBEnabled == true,
        _G.QuickJoinToastButton, "Interface\\Icons\\INV_Misc_GroupLooking"
    )
    UpdateChatButtonBroker(
        ldb, "chatMenuBroker", "s2k:Chat Menu", "Chat Menu",
        chatEnabled and CFG.chatMenuLDBEnabled == true,
        _G.ChatFrameMenuButton, "Interface\\ChatFrame\\UI-ChatIcon-Chat-Up", true
    )
end

function ApplyChatSettings()
    if not CFG then return end
    HookGlobalChatButtonToggle(_G.QuickJoinToastButton, "chatQuickJoinButtonEnabled")
    HookGlobalChatButtonToggle(_G.ChatFrameMenuButton, "chatMenuButtonEnabled")
    local font = GetFontOption(CFG.chatFontKey, CFG.chatFontPath)
    local fontPath = font and font.path or CFG.chatFontPath or "Fonts\\FRIZQT__.TTF"
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local frame = _G["ChatFrame" .. i]
        if frame then
            HookChatFrame(frame)
            if CFG.chatEnabled then
                CaptureChatFrame(frame)
                local _, currentFontSize = frame:GetFont()
                frame:SetFont(fontPath, currentFontSize or 14, GetFontFlags(CFG.chatFontOutlineKey))
                frame:SetJustifyH(CFG.chatTextAlign == "RIGHT" and "RIGHT" or "LEFT")
                local editBox = GetChatObjects(frame)
                if editBox then
                    local _, currentEditFontSize = editBox:GetFont()
                    editBox:SetFont(fontPath, currentEditFontSize or currentFontSize or 14, GetFontFlags(CFG.chatFontOutlineKey))
                end
                PositionChatFrameParts(frame)
            else
                RestoreChatFrame(frame)
            end
        end
    end
    if CFG.chatEnabled then
        ApplyChatSideButtonsVisibility()
        InitializeChatButtonBrokers()
    else
        StopAllSmartChatWatchers()
        RestoreAllChatManagedObjects()
        InitializeChatButtonBrokers()
        if State.chatCopyWindow then State.chatCopyWindow:Hide() end
    end
end

local function HandlePlayerLink(link, text, button)
    if not CFG or not CFG.chatEnabled or not CFG.chatAltInviteEnabled then return end
    if button ~= "LeftButton" or not IsAltKeyDown() then return end
    local linkType, playerName = tostring(link or ""):match("^([^:]+):([^:]+)")
    if linkType == "player" and playerName and playerName ~= "" and InviteUnit then
        InviteUnit(playerName)
    end
end

function InitializeChatModule()
    if State.chatInitialized then ApplyChatSettings(); return end
    State.chatInitialized = true
    for i = 1, (NUM_CHAT_WINDOWS or 10) do HookChatFrame(_G["ChatFrame" .. i]) end
    if hooksecurefunc then
        hooksecurefunc("SetItemRef", HandlePlayerLink)
        if FCF_OpenNewWindow then
            hooksecurefunc("FCF_OpenNewWindow", function() ApplyChatSettings() end)
        end
        if FloatingChatFrame_OnMouseScroll then
            hooksecurefunc("FloatingChatFrame_OnMouseScroll", function(frame)
                if frame then ScheduleSmartChatButtonsUpdate(frame) end
            end)
        end
    end
    ApplyChatSettings()
end
