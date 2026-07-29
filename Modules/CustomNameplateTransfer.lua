-- Custom Nameplates preset import/export.
-- The format is deliberately self-contained and compatible with Lua 5.1.
local TRANSFER_VERSION = "S2KNP1"
local DEFAULT_CONFIG_NAME = "Default"

local function IsCustomNameplateKey(key)
    if key == "enabled" then return true end
    local prefixes = {
        "nameplate", "friendly", "enemy", "target", "focus", "plate", "health",
        "border", "showNames", "nameFont", "nameYOffset", "nameOverlay", "hpRatio",
        "showCastbar", "showBuff", "showDebuff", "castbar",
        "playerCastOverlay", "levelOverlay", "hpMarker", "buff", "debuff",
    }
    for _, prefix in ipairs(prefixes) do
        if key:sub(1, #prefix) == prefix then return true end
    end
    return false
end

local function Field(value)
    value = tostring(value or "")
    return tostring(#value) .. ":" .. value
end

local function ReadField(text, position)
    local colon = text:find(":", position, true)
    if not colon then return nil, position, "Missing field separator." end
    local length = tonumber(text:sub(position, colon - 1))
    if not length or length < 0 or length > 200000 then
        return nil, position, "Invalid field length."
    end
    local first, last = colon + 1, colon + length
    if last > #text then return nil, position, "Truncated field." end
    return text:sub(first, last), last + 1
end

local function HexEncode(text)
    return (text:gsub(".", function(char) return string.format("%02X", char:byte()) end))
end

local function HexDecode(text)
    if #text % 2 ~= 0 or text:find("[^0-9A-Fa-f]") then return nil end
    return (text:gsub("%x%x", function(pair) return string.char(tonumber(pair, 16)) end))
end

local function Checksum(text)
    local a, b = 1, 0
    for index = 1, #text do
        a = (a + text:byte(index)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end

local function GetPresetStore()
    if type(DBRoot) ~= "table" then EnsureDatabase() end
    if type(DBRoot.customNameplateConfigs) ~= "table" then
        DBRoot.customNameplateConfigs = {}
    end
    local defaultSettings = {}
    for key, value in pairs(DEFAULTS) do
        if IsCustomNameplateKey(key) and type(value) ~= "table" then
            defaultSettings[key] = CopySavedValue(value)
        end
    end
    defaultSettings.enabled = true
    DBRoot.customNameplateConfigs[DEFAULT_CONFIG_NAME] = { settings = defaultSettings, builtIn = true }
    return DBRoot.customNameplateConfigs
end

local function CaptureCustomNameplateSettings()
    local settings = {}
    for key, default in pairs(DEFAULTS) do
        if IsCustomNameplateKey(key) and type(default) ~= "table" then
            settings[key] = CopySavedValue(CFG[key])
        end
    end
    return settings
end

local function SerializePreset(name, settings)
    local keys = {}
    for key, value in pairs(settings) do
        local valueType = type(value)
        if valueType == "string" or valueType == "number" or valueType == "boolean" then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)

    local parts = { Field(name), Field(#keys) }
    for _, key in ipairs(keys) do
        local value, valueType = settings[key], type(settings[key])
        local marker = valueType == "boolean" and "B" or valueType == "number" and "N" or "S"
        local serialized = valueType == "boolean" and (value and "1" or "0") or tostring(value)
        parts[#parts + 1] = Field(key)
        parts[#parts + 1] = marker
        parts[#parts + 1] = Field(serialized)
    end
    return table.concat(parts)
end

local function DeserializePreset(payload)
    local position = 1
    local name, countText, err
    name, position, err = ReadField(payload, position)
    if err then return nil, err end
    countText, position, err = ReadField(payload, position)
    if err then return nil, err end
    local count = tonumber(countText)
    if not count or count < 0 or count > 1000 or count ~= math.floor(count) then
        return nil, "Invalid setting count."
    end

    local settings = {}
    for _ = 1, count do
        local key, marker, serialized
        key, position, err = ReadField(payload, position)
        if err then return nil, err end
        marker = payload:sub(position, position)
        position = position + 1
        serialized, position, err = ReadField(payload, position)
        if err then return nil, err end
        if marker == "B" and (serialized == "0" or serialized == "1") then
            settings[key] = serialized == "1"
        elseif marker == "N" and tonumber(serialized) ~= nil then
            settings[key] = tonumber(serialized)
        elseif marker == "S" then
            settings[key] = serialized
        else
            return nil, "Invalid setting value."
        end
    end
    if position ~= #payload + 1 then return nil, "Unexpected data after preset." end
    return { name = name, settings = settings }
end

local function ApplyCustomNameplateSettings()
    CopyDefaults()
    if IsInCombat() then
        if UpdateNameplatePreview then UpdateNameplatePreview() end
        State.pendingOptionsApply = true
        State.pendingCVarApply = true
        State.pendingMediaRefreshFonts = true
        State.pendingMediaRefreshTextures = true
        if RefreshAllOptionsPanels then RefreshAllOptionsPanels() end
        return
    end

    ApplyNameplateCVarSettings()
    if S2KNP_ApplyModuleState then S2KNP_ApplyModuleState() end
    if HideDisabledModuleVisuals then HideDisabledModuleVisuals() end
    RebuildFontOptions()
    RebuildStatusBarTextureOptions()
    RebuildBorderTextureOptions()
    RememberConfiguredFontPaths()
    RememberConfiguredStatusBarTexturePaths()
    RememberConfiguredBorderTexturePaths()
    if RecreateNameplatePreviewTextObjects then RecreateNameplatePreviewTextObjects() end
    if UpdateNameplatePreview then UpdateNameplatePreview() end
    RecreateVisibleTextObjects()
    UpdateAll(true)
    if ApplyPersonalResourceDisplaySettings then ApplyPersonalResourceDisplaySettings() end
    ScheduleVisibleMediaRefreshes(true, true, true)
    if ScheduleNameplateScaleStabilization then ScheduleNameplateScaleStabilization() end
    if RefreshAllOptionsPanels then RefreshAllOptionsPanels() end
end

function GetCustomNameplateConfigOptions()
    local options = {}
    for name in pairs(GetPresetStore()) do
        options[tostring(name)] = name == DEFAULT_CONFIG_NAME
            and S2K_L("Default (Blizzard-like)") or tostring(name)
    end
    return options
end

function GetActiveCustomNameplateConfigName()
    local name = DBRoot and DBRoot.activeCustomNameplateConfig
    if type(name) == "string" and GetPresetStore()[name] then return name end
end

function ActivateCustomNameplateConfig(name)
    name = tostring(name or "")
    local preset = GetPresetStore()[name]
    if type(preset) ~= "table" or type(preset.settings) ~= "table" then return false end

    for key, value in pairs(preset.settings) do
        local default = DEFAULTS[key]
        if default ~= nil and IsCustomNameplateKey(key)
        and type(default) == type(value) and type(value) ~= "table" then
            DB[key] = CopySavedValue(value)
        end
    end
    DBRoot.activeCustomNameplateConfig = name
    ApplyCustomNameplateSettings()
    return true
end

function CanDeleteCurrentCustomNameplateConfig()
    local name = GetActiveCustomNameplateConfigName()
    return name ~= nil and name ~= DEFAULT_CONFIG_NAME
end

function DeleteCurrentCustomNameplateConfig()
    local name = GetActiveCustomNameplateConfigName()
    if name and name ~= DEFAULT_CONFIG_NAME then
        GetPresetStore()[name] = nil
    end
    return ActivateCustomNameplateConfig(DEFAULT_CONFIG_NAME)
end

function ExportCustomNameplateConfig(configName)
    local name = tostring(configName or GetActiveCustomNameplateConfigName() or GetCurrentProfileName() or "Custom Nameplates")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end
    local payload = SerializePreset(name, CaptureCustomNameplateSettings())
    return TRANSFER_VERSION .. ":" .. tostring(Checksum(payload)) .. ":" .. HexEncode(payload)
end

function ImportCustomNameplateConfig(exportString)
    local input = tostring(exportString or ""):gsub("%s+", "")
    if #input > 500000 then return false, S2K_L("The import string is too long.") end
    local checksumText, encoded = input:match("^" .. TRANSFER_VERSION .. ":(%d+):(.+)$")
    local payload = encoded and HexDecode(encoded)
    if not payload or tonumber(checksumText) ~= Checksum(payload) then
        return false, S2K_L("Invalid or damaged Custom Nameplates import string.")
    end

    local preset, err = DeserializePreset(payload)
    if not preset then return false, S2K_L(err) end
    local name = tostring(preset.name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = S2K_L("Imported Custom Nameplates") end
    if name == DEFAULT_CONFIG_NAME then name = DEFAULT_CONFIG_NAME .. " (2)" end
    GetPresetStore()[name] = { settings = preset.settings }
    ActivateCustomNameplateConfig(name)
    return true, name
end

local function GetTransferWindow()
    if State.customNameplateTransferWindow then return State.customNameplateTransferWindow end
    local gui = LibStub and LibStub("AceGUI-3.0", true)
    local widget = gui and gui:Create("S2KTextViewerWindow")
    if not widget then return nil end
    widget.frame:SetSize(640, 420)
    widget.frame:SetPoint("CENTER")
    widget.up:SetText(S2K_L("Scroll Up"))
    widget.down:SetText(S2K_L("Scroll Down"))
    State.customNameplateTransferWindow = widget
    return widget
end

function ShowCustomNameplateExport()
    local window = GetTransferWindow()
    if not window then return end
    window:SetTitle(S2K_L("Export custom nameplates"))
    window:SetNameField(S2K_L("Configuration name"), GetActiveCustomNameplateConfigName() or GetCurrentProfileName())
    window:SetText("")
    window:SetAction(S2K_L("Export"), function()
        local exportString = ExportCustomNameplateConfig(window.nameBox:GetText())
        if not exportString then
            if S2KPrint then S2KPrint(S2K_L("Enter a configuration name.")) end
            window.nameBox:SetFocus()
            return
        end
        window:SetText(exportString)
        window:SetAction()
        window.editBox:SetFocus()
        window.editBox:HighlightText()
    end)
    window.frame:Show()
    window.nameBox:SetFocus()
    window.nameBox:HighlightText()
end

function ShowCustomNameplateImport()
    local window = GetTransferWindow()
    if not window then return end
    window:SetTitle(S2K_L("Import custom nameplates"))
    window:SetNameField()
    window:SetText("")
    window:SetAction(S2K_L("Import"), function(text)
        local ok, result = ImportCustomNameplateConfig(text)
        if ok then
            window.frame:Hide()
            if S2KPrint then
                S2KPrint(S2K_L("Imported and activated Custom Nameplates config:") .. " " .. result)
            end
        elseif S2KPrint then
            S2KPrint(result)
        end
    end)
    window.frame:Show()
    window.editBox:SetFocus()
end
