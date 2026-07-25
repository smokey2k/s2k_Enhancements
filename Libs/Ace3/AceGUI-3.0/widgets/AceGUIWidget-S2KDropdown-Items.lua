local AceGUI = LibStub("AceGUI-3.0")
local ItemBase = LibStub("AceGUI-3.0-DropDown-ItemBase").GetItemBase()
local Type = "S2KDropdown-Item-StatusBar"
local Version = ItemBase.version + 1

local function ParseMediaText(value)
    local path, label = tostring(value or ""):match("^|T(.-):16:48:0:0|t%s*(.*)$")
    return path, label or tostring(value or "")
end

local function Frame_OnClick(frame)
    local self = frame.obj
    if self.disabled then return end
    self:SetValue(not self.value)
    self:Fire("OnValueChanged", self.value)
end

local function SetValue(self, value)
    self.value = value and true or false
    if self.value then self.check:Show() else self.check:Hide() end
end

local function GetValue(self)
    return self.value
end

local function SetText(self, value)
    local path, label = ParseMediaText(value)
    self.mediaPath = path
    self.text:SetText(label)
    if path and path ~= "" then
        self.preview:SetTexture(path)
        self.preview:Show()
    else
        self.preview:Hide()
    end
end

local function OnRelease(self)
    ItemBase.OnRelease(self)
    self:SetValue(false)
    self.preview:Hide()
    self.preview:SetTexture(nil)
    self.preview:SetVertexColor(1, 1, 1, 1)
    self.mediaPath = nil
end

local function Constructor()
    local self = ItemBase.Create(Type)
    self.frame:SetHeight(24)
    self.preview = self.frame:CreateTexture(nil, "ARTWORK")
    self.preview:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 24, -2)
    self.preview:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -4, 2)
    self.text:ClearAllPoints()
    self.text:SetPoint("LEFT", self.frame, "LEFT", 28, 0)
    self.text:SetPoint("RIGHT", self.frame, "RIGHT", -8, 0)
    self.text:SetJustifyH("CENTER")
    self.text:SetTextColor(1, 1, 1, 1)
    self.text:SetShadowColor(0, 0, 0, 1)
    self.text:SetShadowOffset(1, -1)
    self.frame:SetScript("OnClick", Frame_OnClick)
    self.SetText = SetText
    self.SetValue = SetValue
    self.GetValue = GetValue
    self.OnRelease = OnRelease
    return AceGUI:RegisterAsWidget(self)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
