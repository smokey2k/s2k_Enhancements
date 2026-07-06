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

    questReputationFrame:Hide()
    return questReputationFrame
end

function S2K_QuestReputationTemplateElement()
    if not CFG or CFG.questReputationEnabled == false then
        if questReputationFrame then questReputationFrame:Hide() end
        return nil
    end

    local lines = S2K_GetQuestReputationRewardLines()
    if #lines == 0 then
        if questReputationFrame then questReputationFrame:Hide() end
        return nil
    end

    local frame = EnsureQuestReputationFrame()
    frame:ClearAllPoints()
    frame.title:SetText(REPUTATION or "Reputation")
    frame.text:SetText(table_concat(lines, "\n"))

    if QuestInfoRewardsHeader and QuestInfoRewardsHeader.GetTextColor then
        frame.title:SetTextColor(QuestInfoRewardsHeader:GetTextColor())
    end
    if QuestInfoDescriptionText and QuestInfoDescriptionText.GetTextColor then
        frame.text:SetTextColor(QuestInfoDescriptionText:GetTextColor())
    end

    local titleHeight = frame.title:GetStringHeight() or 18
    local textHeight = frame.text:GetStringHeight() or (#lines * 14)
    frame:SetHeight(titleHeight + textHeight + 9)
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
    API.RefreshQuestReputationDisplay = RefreshQuestReputationDisplay
end
