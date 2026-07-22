-- =========================================================
-- s2k:Enhancements - Quest reputation rewards
-- WoW 7.3.5
--
-- Adds a reputation section to Blizzard quest detail, quest-log detail and
-- quest-completion panels. The feature is self-contained and does not require
-- Factionizer, RepHelper or another reputation addon.
-- =========================================================

local math_floor = math.floor
local math_ceil = math.ceil
local table_insert = table.insert
local table_concat = table.concat
local tostring = tostring
local tonumber = tonumber
local type = type
local pairs = pairs
local select = select

local questReputationFrame
local insertedTemplates = setmetatable({}, { __mode = "k" })

-- Known reputation modifiers available in the 7.3.5 client. The faction value
-- is 0 for a global modifier or a specific faction ID for faction-only buffs.
local QUEST_REPUTATION_AURA_BONUSES = {
    [61849]  = { bonus = 0.10, faction = 0 },    -- Spirit of Sharing
    [24705]  = { bonus = 0.10, faction = 0 },
    [95987]  = { bonus = 0.10, faction = 0 },
    [39913]  = { bonus = 0.10, faction = 947 },  -- Thrallmar
    [39911]  = { bonus = 0.10, faction = 946 },  -- Honor Hold
    [39953]  = { bonus = 0.10, faction = 1031 }, -- The Sha'tar
    [46668]  = { bonus = 0.10, faction = 0 },    -- Darkmoon Faire
    [136583] = { bonus = 0.10, faction = 0 },    -- Darkmoon Faire
}

local function RoundSigned(value)
    value = tonumber(value) or 0
    if value < 0 then
        return math_ceil(value - 0.5)
    end
    return math_floor(value + 0.5)
end

local function GetKnownAuraBonus(factionID)
    if not UnitAura then return 0 end

    local bonus = 0
    for index = 1, 40 do
        local spellID = select(11, UnitAura("player", index, "HELPFUL"))
        if not spellID then break end

        local info = QUEST_REPUTATION_AURA_BONUSES[spellID]
        if info and (info.faction == 0 or info.faction == factionID) then
            bonus = bonus + (tonumber(info.bonus) or 0)
        end
    end
    return bonus
end

local function NormalizeQuestReputationAmount(rawAmount, factionID)
    -- GetQuestLogRewardFactionInfo returns hundredths of a reputation point on
    -- the 7.3.5 API, therefore 250 reputation is reported as 25000.
    local amount = (tonumber(rawAmount) or 0) / 100

    -- A few legacy factions use an older internal scale. Blizzard's historical
    -- quest UI and established RepReward implementations apply these factors.
    if factionID == 609 or factionID == 576 or factionID == 529 then
        amount = amount * 2
    elseif factionID == 59 then
        amount = amount * 4
    end

    return RoundSigned(amount)
end

local function CalculateDisplayedQuestReputation(baseAmount, factionID, hasBonusRepGain)
    local bonusPercent = 0

    if UnitRace then
        local _, raceToken = UnitRace("player")
        if raceToken == "Human" then
            bonusPercent = bonusPercent + 0.10
        end
    end

    bonusPercent = bonusPercent + GetKnownAuraBonus(factionID)

    local total = baseAmount * (1 + bonusPercent)
    if hasBonusRepGain then
        total = total * 2
    end

    total = RoundSigned(total)
    return total, total - baseAmount
end

function S2K_GetQuestReputationRewardLines()
    local lines = {}
    if not CFG or CFG.questReputationEnabled == false then
        return lines
    end
    if not GetNumQuestLogRewardFactions or not GetQuestLogRewardFactionInfo or not GetFactionInfoByID then
        return lines
    end

    local count = tonumber(GetNumQuestLogRewardFactions()) or 0
    local seen = {}

    for index = 1, count do
        local factionID, rawAmount = GetQuestLogRewardFactionInfo(index)
        factionID = tonumber(factionID)

        if factionID then
            local factionName, _, _, _, _, _, _, _, isHeader, _, hasRep, _, _, _, hasBonusRepGain = GetFactionInfoByID(factionID)
            local dedupeKey = tostring(factionID) .. ":" .. tostring(rawAmount)

            if factionName and (not isHeader or hasRep) and not seen[dedupeKey] then
                seen[dedupeKey] = true

                local baseAmount = NormalizeQuestReputationAmount(rawAmount, factionID)
                local totalAmount, bonusAmount = CalculateDisplayedQuestReputation(baseAmount, factionID, hasBonusRepGain)
                local amountText = totalAmount >= 0 and ("+" .. tostring(totalAmount)) or tostring(totalAmount)

                if totalAmount < 0 then
                    amountText = "|cffff4400" .. amountText .. "|r"
                elseif bonusAmount > 0 then
                    amountText = "|cff40c040" .. amountText .. "|r"
                end

                if bonusAmount ~= 0 then
                    lines[#lines + 1] = tostring(factionName) .. ": " .. amountText
                        .. " |cff777777(" .. tostring(baseAmount) .. " base, "
                        .. (bonusAmount > 0 and "+" or "") .. tostring(bonusAmount) .. " bonus)|r"
                else
                    lines[#lines + 1] = tostring(factionName) .. ": " .. amountText
                end
            end
        end
    end

    return lines
end

function S2K_GetQuestCurrencyRewardLines()
    local lines = {}
    if not CFG or CFG.questCurrencyRewardsEnabled == false then return lines end
    if not GetNumQuestLogRewardCurrencies or not GetQuestLogRewardCurrencyInfo then return lines end

    local count = tonumber(GetNumQuestLogRewardCurrencies()) or 0
    local seen = {}
    for index = 1, count do
        local name, texture, quantity, currencyID = GetQuestLogRewardCurrencyInfo(index)
        quantity = tonumber(quantity) or 0
        currencyID = tonumber(currencyID)
        if (not name or name == "") and currencyID and GetCurrencyInfo then
            local currencyName, _, currencyTexture = GetCurrencyInfo(currencyID)
            name = currencyName
            texture = texture or currencyTexture
        end
        local key = currencyID or name
        if name and name ~= "" and not seen[key] then
            seen[key] = true
            local icon = texture and ("|T" .. tostring(texture) .. ":16:16:0:0|t ") or ""
            local amount = quantity >= 0 and ("+" .. tostring(quantity)) or tostring(quantity)
            lines[#lines + 1] = icon .. tostring(name) .. ": " .. amount
        end
    end
    return lines
end

local function EnsureQuestReputationFrame()
    if questReputationFrame then
        return questReputationFrame
    end

    questReputationFrame = CreateFrame("Frame", "s2k_EnhancementsQuestReputationFrame", UIParent)
    questReputationFrame:SetWidth(288)

    questReputationFrame.title = questReputationFrame:CreateFontString(nil, "ARTWORK", "QuestFont_Shadow_Huge")
    questReputationFrame.title:SetPoint("TOPLEFT", questReputationFrame, "TOPLEFT", 0, 0)
    questReputationFrame.title:SetWidth(288)
    questReputationFrame.title:SetJustifyH("LEFT")
    questReputationFrame.title:SetJustifyV("TOP")

    questReputationFrame.text = questReputationFrame:CreateFontString(nil, "ARTWORK", "QuestFontNormalSmall")
    questReputationFrame.text:SetPoint("TOPLEFT", questReputationFrame.title, "BOTTOMLEFT", 0, -5)
    questReputationFrame.text:SetWidth(288)
    questReputationFrame.text:SetJustifyH("LEFT")
    questReputationFrame.text:SetJustifyV("TOP")

    questReputationFrame.currencyTitle = questReputationFrame:CreateFontString(nil, "ARTWORK", "QuestFont_Shadow_Huge")
    questReputationFrame.currencyTitle:SetWidth(288)
    questReputationFrame.currencyTitle:SetJustifyH("LEFT")
    questReputationFrame.currencyTitle:SetJustifyV("TOP")

    questReputationFrame.currencyText = questReputationFrame:CreateFontString(nil, "ARTWORK", "QuestFontNormalSmall")
    questReputationFrame.currencyText:SetWidth(288)
    questReputationFrame.currencyText:SetJustifyH("LEFT")
    questReputationFrame.currencyText:SetJustifyV("TOP")

    questReputationFrame:Hide()
    return questReputationFrame
end

function S2K_QuestReputationTemplateElement()
    if not CFG or (CFG.questReputationEnabled == false and CFG.questCurrencyRewardsEnabled == false) then
        if questReputationFrame then questReputationFrame:Hide() end
        return nil
    end

    local lines = S2K_GetQuestReputationRewardLines()
    local currencyLines = S2K_GetQuestCurrencyRewardLines()
    if #lines == 0 and #currencyLines == 0 then
        if questReputationFrame then questReputationFrame:Hide() end
        return nil
    end

    local frame = EnsureQuestReputationFrame()
    frame:ClearAllPoints()
    frame.title:ClearAllPoints()
    frame.text:ClearAllPoints()
    frame.currencyTitle:ClearAllPoints()
    frame.currencyText:ClearAllPoints()

    local height = 0
    if #lines > 0 then
        frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -height)
        frame.title:SetText(REPUTATION or "Reputation")
        frame.text:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -5)
        frame.text:SetText(table_concat(lines, "\n"))
        frame.title:Show()
        frame.text:Show()
        height = height + (frame.title:GetStringHeight() or 18) + (frame.text:GetStringHeight() or (#lines * 14)) + 9
    else
        frame.title:Hide()
        frame.text:Hide()
    end

    if #currencyLines > 0 then
        frame.currencyTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -height)
        frame.currencyTitle:SetText(S2K_L and S2K_L("Currency rewards") or "Currency rewards")
        frame.currencyText:SetPoint("TOPLEFT", frame.currencyTitle, "BOTTOMLEFT", 0, -5)
        frame.currencyText:SetText(table_concat(currencyLines, "\n"))
        frame.currencyTitle:Show()
        frame.currencyText:Show()
        height = height + (frame.currencyTitle:GetStringHeight() or 18) + (frame.currencyText:GetStringHeight() or (#currencyLines * 14)) + 9
    else
        frame.currencyTitle:Hide()
        frame.currencyText:Hide()
    end

    if QuestInfoRewardsHeader and QuestInfoRewardsHeader.GetTextColor then
        frame.title:SetTextColor(QuestInfoRewardsHeader:GetTextColor())
        frame.currencyTitle:SetTextColor(QuestInfoRewardsHeader:GetTextColor())
    end
    if QuestInfoDescriptionText and QuestInfoDescriptionText.GetTextColor then
        frame.text:SetTextColor(QuestInfoDescriptionText:GetTextColor())
        frame.currencyText:SetTextColor(QuestInfoDescriptionText:GetTextColor())
    end

    frame:SetHeight(height)
    frame:Show()
    return frame
end
local function InsertQuestReputationElement(template)
    if type(template) ~= "table" or type(template.elements) ~= "table" then
        return false
    end
    if insertedTemplates[template] then
        return true
    end

    local elements = template.elements
    local insertAt = #elements + 1

    -- Place the section immediately before the last Blizzard spacer, matching
    -- the layout used by the historical RepReward implementation.
    if QuestInfo_ShowSpacer then
        for index = #elements - 2, 1, -3 do
            if elements[index] == QuestInfo_ShowSpacer then
                insertAt = index
                break
            end
        end
    end

    table_insert(elements, insertAt, S2K_QuestReputationTemplateElement)
    table_insert(elements, insertAt + 1, 0)
    table_insert(elements, insertAt + 2, -8)
    insertedTemplates[template] = true
    return true
end

function InitializeQuestReputation()
    if not QuestInfo_Display then
        return false
    end

    local initialized = false
    local templateNames = {
        "QUEST_TEMPLATE_LOG",
        "QUEST_TEMPLATE_DETAIL",
        "QUEST_TEMPLATE_DETAIL2",
        "QUEST_TEMPLATE_REWARD",
    }
    local visited = {}

    for _, templateName in pairs(templateNames) do
        local template = _G[templateName]
        if template and not visited[template] then
            visited[template] = true
            if InsertQuestReputationElement(template) then
                initialized = true
            end
        end
    end

    return initialized
end

function RefreshQuestReputationDisplay()
    -- The element reads CFG every time Blizzard rebuilds the quest panel. This
    -- helper mainly ensures that late-loaded Blizzard_QuestUI templates are
    -- patched after the option is toggled.
    InitializeQuestReputation()
end

if API then
    API.GetQuestReputationRewardLines = S2K_GetQuestReputationRewardLines
    API.GetQuestCurrencyRewardLines = S2K_GetQuestCurrencyRewardLines
    API.RefreshQuestReputationDisplay = RefreshQuestReputationDisplay
end

-- =========================================================
-- Optional quest workflow and tooltip tweaks (WoW 7.3.5)
-- =========================================================

local questTooltipHooksInitialized = false
local questInfoHookInitialized = false
local questLogHookInitialized = false

local function GetQuestLevelText(level)
    level = tonumber(level)
    if not level or level == 0 then return nil end
    if level < 0 then return "??" end
    return tostring(level)
end

local function GetCurrentQuestLogIndex()
    local questID = GetQuestID and tonumber(GetQuestID())
    if questID and questID > 0 and GetQuestLogIndexByID then
        local index = tonumber(GetQuestLogIndexByID(questID))
        if index and index > 0 then return index end
    end
    if GetQuestLogSelection then
        local index = tonumber(GetQuestLogSelection())
        if index and index > 0 then return index end
    end
end

local function AddLevelToCurrentQuestTitle()
    if not CFG or not CFG.questLevelDisplayEnabled or not QuestInfoTitleHeader or not GetQuestLogTitle then return end
    local index = GetCurrentQuestLogIndex()
    local title, level
    if index then
        title, level = GetQuestLogTitle(index)
    else
        title = QuestInfoTitleHeader:GetText()
        title = title and title:gsub("^%[[^%]]+%]%s*", "")
        level = GetQuestLevel and GetQuestLevel()
    end
    local levelText = GetQuestLevelText(level)
    if title and levelText then QuestInfoTitleHeader:SetText("[" .. levelText .. "] " .. title) end
end

local function UpdateClassicQuestLogLevels()
    if not CFG or not CFG.questLevelDisplayEnabled or not GetQuestLogTitle then return end
    local offset = 0
    if QuestLogListScrollFrame and FauxScrollFrame_GetOffset then offset = FauxScrollFrame_GetOffset(QuestLogListScrollFrame) or 0 end
    local displayed = tonumber(QUESTS_DISPLAYED) or 25
    for row = 1, displayed do
        local text = _G["QuestLogTitle" .. row]
        local index = offset + row
        if text then
            local title, level, _, isHeader = GetQuestLogTitle(index)
            local levelText = not isHeader and GetQuestLevelText(level) or nil
            if title and levelText then text:SetText("[" .. levelText .. "] " .. title) end
        end
    end
end

local function NormalizeObjectiveMatchText(text)
    text = tostring(text or ""):lower()
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text:gsub("[%p%c]", " "):gsub("%s+", " ")
end

local function AddMatchingQuestObjectivesToTooltip(tooltip, subjectName)
    if not CFG or not CFG.questObjectiveTooltipEnabled or not tooltip or not subjectName then return end
    if not GetNumQuestLogEntries or not GetQuestLogTitle or not GetNumQuestLeaderBoards or not GetQuestLogLeaderBoard then return end
    local subject = NormalizeObjectiveMatchText(subjectName)
    if subject == "" then return end
    if tooltip.s2kQuestObjectiveSubject == subject then return end
    tooltip.s2kQuestObjectiveSubject = subject
    local added = 0
    for questIndex = 1, tonumber(GetNumQuestLogEntries()) or 0 do
        local questTitle, _, _, isHeader, isCollapsed = GetQuestLogTitle(questIndex)
        if questTitle and not isHeader and not isCollapsed then
            for objectiveIndex = 1, tonumber(GetNumQuestLeaderBoards(questIndex)) or 0 do
                local description, _, finished = GetQuestLogLeaderBoard(objectiveIndex, questIndex)
                if description and NormalizeObjectiveMatchText(description):find(subject, 1, true) then
                    if added == 0 then tooltip:AddLine(S2K_L("Quest objectives"), 1, 0.82, 0, true) end
                    local r, g, b = 1, 0.82, 0
                    if finished then r, g, b = 0.25, 1, 0.25 end
                    tooltip:AddLine(tostring(questTitle) .. ": " .. tostring(description), r, g, b, true)
                    added = added + 1
                    if added >= 8 then break end
                end
            end
        end
        if added >= 8 then break end
    end
    if added > 0 then tooltip:Show() end
end

local function QuestTooltipUnit(tooltip)
    local name = tooltip and tooltip.GetUnit and select(1, tooltip:GetUnit())
    if name then AddMatchingQuestObjectivesToTooltip(tooltip, name) end
end

local function QuestTooltipItem(tooltip)
    local name = tooltip and tooltip.GetItem and select(1, tooltip:GetItem())
    if name then AddMatchingQuestObjectivesToTooltip(tooltip, name) end
end

function InitializeQuestTweaks()
    if hooksecurefunc then
        if QuestInfo_Display and not questInfoHookInitialized then
            hooksecurefunc("QuestInfo_Display", AddLevelToCurrentQuestTitle)
            questInfoHookInitialized = true
        end
        if QuestLog_Update and not questLogHookInitialized then
            hooksecurefunc("QuestLog_Update", UpdateClassicQuestLogLevels)
            questLogHookInitialized = true
        end
    end
    if not questTooltipHooksInitialized and GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetUnit", QuestTooltipUnit)
        GameTooltip:HookScript("OnTooltipSetItem", QuestTooltipItem)
        GameTooltip:HookScript("OnTooltipCleared", function(self) self.s2kQuestObjectiveSubject = nil end)
        if ItemRefTooltip and ItemRefTooltip.HookScript then
            ItemRefTooltip:HookScript("OnTooltipSetItem", QuestTooltipItem)
            ItemRefTooltip:HookScript("OnTooltipCleared", function(self) self.s2kQuestObjectiveSubject = nil end)
        end
        questTooltipHooksInitialized = true
    end
    return true
end

function RefreshQuestTweaksDisplay()
    InitializeQuestTweaks()
    if QuestLog_Update then QuestLog_Update() end
    AddLevelToCurrentQuestTitle()
end

function S2K_HandleQuestTweakEvent(event)
    if not CFG then return end
    if event == "QUEST_DETAIL" and CFG.questAutoAcceptEnabled then
        if AcceptQuest then AcceptQuest() end
    elseif event == "QUEST_PROGRESS" and CFG.questAutoTurnInEnabled then
        if IsQuestCompletable and IsQuestCompletable() and CompleteQuest then CompleteQuest() end
    elseif event == "QUEST_COMPLETE" and CFG.questAutoTurnInEnabled then
        local choices = GetNumQuestChoices and tonumber(GetNumQuestChoices()) or 0
        if choices == 0 and GetQuestReward then GetQuestReward(1) end
    elseif event == "QUEST_ACCEPT_CONFIRM" and CFG.questAutoAcceptShareEnabled then
        if ConfirmAcceptQuest then ConfirmAcceptQuest() end
        if StaticPopup_Hide then StaticPopup_Hide("QUEST_ACCEPT") end
    elseif event == "QUEST_LOG_UPDATE" and CFG.questLevelDisplayEnabled then
        UpdateClassicQuestLogLevels()
    end
end