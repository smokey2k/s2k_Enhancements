-- =========================================================
-- Debug / internal profiler
-- =========================================================

S2KNP_PROFILE_FUNCTION_NAMES = S2KNP_PROFILE_FUNCTION_NAMES or {
    "UpdateHealth",
    "UpdateName",
    "UpdateHPRatio",
    "UpdateUnitLevelOverlay",
    "UpdateHPThresholdMarker",
    "UpdateAuraFrame",
    "UpdateCast",
    "UpdatePlayerCastOverlay",
    "UpdateContext",
    "UpdateUnit",
    "UpdateAll",
    "UpdateTargetRuntimeOnly",
    "UpdateVisibleCastRuntimeOnly",
    "UpdateTargetPlayerCastOverlayOnly",
    "UpdateWAAnchors",
    "UpdateWeakAuraBarGroups",
    "FlushDirtyAuras",
    "ApplyBlizzardVisualState",
    "ApplyBlizzardCastbarVisualStateOnly",
    "ApplyCustomPlateScale",
    "ApplyOptionsNow",
    "RefreshVisibleTextFonts",
    "RefreshVisibleStatusBarTextures",
    "ApplyNameplateCVarSettings",
}

function ProfilerIsEnabled()
    return State.profilerActive == true
end

function ProfilerReset()
    State.profilerData = {}
    State.profilerStartedAt = debugprofilestop and debugprofilestop() or 0
end

function ProfilerAdd(name, startTime)
    if not startTime or not ProfilerIsEnabled() then
        return
    end

    local elapsed = debugprofilestop() - startTime
    local data = State.profilerData
    local d = data[name]

    if not d then
        d = { calls = 0, total = 0, max = 0 }
        data[name] = d
    end

    d.calls = d.calls + 1
    d.total = d.total + elapsed
    if elapsed > d.max then
        d.max = elapsed
    end
end

function InstallProfilerWrappers()
    if State.profilerWrapped then
        return
    end

    State.profilerOriginals = State.profilerOriginals or {}

    for _, name in ipairs(S2KNP_PROFILE_FUNCTION_NAMES or {}) do
        local original = _G[name]

        if type(original) == "function" and not State.profilerOriginals[name] then
            State.profilerOriginals[name] = original

            _G[name] = function(...)
                local startTime = debugprofilestop()
                local r1, r2, r3, r4, r5, r6, r7, r8, r9, r10 = original(...)
                ProfilerAdd(name, startTime)
                return r1, r2, r3, r4, r5, r6, r7, r8, r9, r10
            end
        end
    end

    State.profilerWrapped = true
    if not State.profilerStartedAt then
        ProfilerReset()
    end
end

function UninstallProfilerWrappers()
    if not State.profilerWrapped then
        return
    end

    for name, original in pairs(State.profilerOriginals or {}) do
        if type(original) == "function" then
            _G[name] = original
        end
    end

    State.profilerOriginals = {}
    State.profilerWrapped = false
end

function SyncProfilerState()
    State.profilerActive = CFG and CFG.debugProfilerEnabled == true and debugprofilestop ~= nil
    if State.profilerActive then
        InstallProfilerWrappers()
        if not State.profilerStartedAt then ProfilerReset() end
    else
        UninstallProfilerWrappers()
    end
end

function SetProfilerEnabled(enabled)
    SetBool("debugProfilerEnabled", enabled and true or false)
    SyncProfilerState()

    if State.profilerActive then
        ProfilerReset()
        print("s2k:Enhancements profiler: enabled and reset")
    else
        print("s2k:Enhancements profiler: disabled")
    end
end

function ProfilerPrintReport()
    if not State.profilerData then
        print("s2k:Enhancements profiler: no data")
        return
    end

    local rows = {}
    local grandTotal = 0

    for name, d in pairs(State.profilerData) do
        if d and (d.calls or 0) > 0 then
            rows[#rows + 1] = { name = name, calls = d.calls or 0, total = d.total or 0, max = d.max or 0 }
            grandTotal = grandTotal + (d.total or 0)
        end
    end

    table.sort(rows, function(a, b)
        return (a.total or 0) > (b.total or 0)
    end)

    local elapsed = 0
    if State.profilerStartedAt and debugprofilestop then
        elapsed = debugprofilestop() - State.profilerStartedAt
    end

    print("---- s2k:Enhancements profiler ----")
    print(string.format("sample=%.1f sec  measured=%.3f ms  avg=%.3f ms/s", elapsed / 1000, grandTotal, elapsed > 0 and (grandTotal / (elapsed / 1000)) or 0))

    local limit = tonumber(CFG.debugProfilerMaxRows) or 30
    if limit < 1 then limit = 30 end

    for i = 1, math.min(limit, #rows) do
        local r = rows[i]
        local avg = r.calls > 0 and (r.total / r.calls) or 0
        local pct = grandTotal > 0 and ((r.total / grandTotal) * 100) or 0
        print(string.format("%02d. %s  calls=%d  total=%.3f  avg=%.4f  max=%.3f  %.1f%%", i, r.name, r.calls, r.total, avg, r.max, pct))
    end
end

function GetAddonCPUUsageSnapshot()
    if type(UpdateAddOnCPUUsage) ~= "function" or type(GetAddOnCPUUsage) ~= "function" then
        return nil, "WoW CPU profiling API is not available"
    end

    local okUpdate = pcall(UpdateAddOnCPUUsage)
    if not okUpdate then
        return nil, "UpdateAddOnCPUUsage() failed"
    end

    local ok, value = pcall(GetAddOnCPUUsage, ADDON_NAME)
    if not ok or value == nil then
        return nil, "GetAddOnCPUUsage(" .. tostring(ADDON_NAME) .. ") failed"
    end

    return tonumber(value) or 0, nil
end

function PrintAddonCPUUsageSnapshot()
    local value, err = GetAddonCPUUsageSnapshot()
    if value == nil then
        print("s2k:Enhancements CPU: " .. tostring(err or "unavailable"))
        print("Tip: WoW addon CPU usage usually requires /console scriptProfile 1 and then /reload.")
        return
    end

    local scriptProfile = GetCVar and tostring(GetCVar("scriptProfile") or "?") or "?"
    print(string.format("s2k:Enhancements WoW CPU total: %.3f ms  scriptProfile=%s", value, scriptProfile))
end

function FinishCPUBenchmark(serial)
    if serial ~= State.benchmarkSerial or not State.benchmarkActive then
        return
    end

    State.benchmarkActive = false

    local now = debugprofilestop and debugprofilestop() or 0
    local elapsedMs = now - (State.benchmarkStartedAt or now)
    local elapsedSec = elapsedMs > 0 and (elapsedMs / 1000) or 0
    local cpuEnd = nil
    local cpuErr = nil
    cpuEnd, cpuErr = GetAddonCPUUsageSnapshot()

    print("---- s2k:Enhancements CPU benchmark ----")
    print(string.format("sample=%.1f sec  internalProfiler=%s", elapsedSec, State.benchmarkWithProfiler and "on" or "off"))

    if cpuEnd ~= nil and State.benchmarkCpuStart ~= nil and elapsedSec > 0 then
        local delta = cpuEnd - State.benchmarkCpuStart
        if delta < 0 then delta = 0 end
        print(string.format("WoW AddOnCPUUsage delta=%.3f ms  avg=%.3f ms/s", delta, delta / elapsedSec))
    else
        print("WoW AddOnCPUUsage unavailable: " .. tostring(cpuErr or "no baseline"))
        print("Tip: enable with /console scriptProfile 1 and then /reload.")
    end

    if State.benchmarkWithProfiler then
        ProfilerPrintReport()
    end
end

function StartCPUBenchmark(seconds, withProfiler)
    seconds = tonumber(seconds) or tonumber(CFG.debugBenchmarkSeconds) or 60
    if seconds < 5 then seconds = 5 end
    if seconds > 300 then seconds = 300 end

    State.benchmarkSerial = (State.benchmarkSerial or 0) + 1
    local serial = State.benchmarkSerial
    State.benchmarkActive = true
    State.benchmarkWithProfiler = withProfiler and true or false
    State.benchmarkStartedAt = debugprofilestop and debugprofilestop() or 0
    State.benchmarkCpuStart = nil

    local cpuStart = GetAddonCPUUsageSnapshot()
    if cpuStart ~= nil then
        State.benchmarkCpuStart = cpuStart
    end

    if withProfiler then
        SetProfilerEnabled(true)
    else
        -- The WoW CPU benchmark should measure the addon without the extra
        -- wrapper overhead of the internal function profiler.
        if CFG.debugProfilerEnabled then
            SetProfilerEnabled(false)
        end
    end

    print(string.format("s2k:Enhancements benchmark started: %.0f sec, internalProfiler=%s", seconds, withProfiler and "on" or "off"))

    if C_Timer and C_Timer.After then
        C_Timer.After(seconds, function()
            FinishCPUBenchmark(serial)
        end)
    else
        print("s2k:Enhancements benchmark: C_Timer.After is not available; use /s2ke cpu and /s2ke prof print manually.")
    end
end



function EnsureWeakAuraAnchorStatsPanel()
    if State.weakAuraAnchorStatsPanel then
        return State.weakAuraAnchorStatsPanel
    end

    local panel = CreateFrame("Frame", "s2k_WeakAuraAnchorStatsPanel", UIParent)
    panel:SetSize(260, 138)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(950)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(panel)
    bg:SetColorTexture(0, 0, 0, 0.78)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    title:SetText("WA anchor engine")
    panel.title = title

    panel.lines = {}
    for i = 1, 7 do
        local line = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8 - (i * 16))
        line:SetJustifyH("LEFT")
        line:SetText("")
        panel.lines[i] = line
    end

    panel:Hide()
    State.weakAuraAnchorStatsPanel = panel
    return panel
end

function SetWeakAuraAnchorStatsPanelEnabled(enabled)
    SetBool("debugWeakAuraAnchorStatsEnabled", enabled and true or false)
    if enabled then
        ResetWeakAuraAnchorStats()
        EnsureWeakAuraAnchorStatsPanel():Show()
    elseif State.weakAuraAnchorStatsPanel then
        State.weakAuraAnchorStatsPanel:Hide()
    end
    if S2KNP_ApplyModuleState then S2KNP_ApplyModuleState() end
end

function UpdateWeakAuraAnchorStatsPanel(elapsed)
    if not CFG or CFG.debugWeakAuraAnchorStatsEnabled ~= true then
        if State.weakAuraAnchorStatsPanel then State.weakAuraAnchorStatsPanel:Hide() end
        return
    end

    State.weakAuraAnchorStatsElapsed = (State.weakAuraAnchorStatsElapsed or 0) + (elapsed or 0)
    if State.weakAuraAnchorStatsElapsed < 0.20 then
        return
    end
    State.weakAuraAnchorStatsElapsed = 0

    local panel = EnsureWeakAuraAnchorStatsPanel()
    if not panel:IsShown() then panel:Show() end

    local stats = State.weakAuraAnchorStats
    if type(stats) ~= "table" or not stats.startedAt then
        ResetWeakAuraAnchorStats()
        stats = State.weakAuraAnchorStats
    end

    local now = debugprofilestop and debugprofilestop() or (stats.startedAt or 0)
    local elapsedMs = now - (stats.startedAt or now)
    local elapsedSec = elapsedMs > 0 and (elapsedMs / 1000) or 0
    local calls = stats.calls or 0
    local avg = calls > 0 and ((stats.total or 0) / calls) or 0
    local ups = elapsedSec > 0 and (calls / elapsedSec) or 0
    local deltaAvg = (stats.deltaCount or 0) > 0 and ((stats.deltaTotal or 0) / (stats.deltaCount or 1)) or 0

    panel.title:SetText("WA anchor engine: " .. tostring(stats.engine or GetWeakAuraAnchorEngine()))
    panel.lines[1]:SetText(string.format("mode=%s  unit=%s", tostring(stats.mode or "none"), tostring(stats.unit or "")))
    panel.lines[2]:SetText(string.format("updates/sec=%.1f  calls=%d", ups, calls))
    panel.lines[3]:SetText(string.format("cpu avg=%.4f ms  max=%.4f ms", avg, stats.max or 0))
    panel.lines[4]:SetText(string.format("delta avg=%.2f ms  max=%.2f ms", deltaAvg, stats.deltaMax or 0))
    panel.lines[5]:SetText(string.format("ok=%d  fail=%d", stats.ok or 0, stats.fail or 0))
    panel.lines[6]:SetText(string.format("relinks=%d  fallbacks=%d", stats.relinks or 0, stats.fallbacks or 0))
    panel.lines[7]:SetText("drag to move")
end
function ProfilerPrintHelp()
    print("---- s2k:Enhancements commands ----")
    print("/s2ke               - open or close configuration")
    print("/s2ke config        - open configuration")
    print("/s2ke help          - show this command list")
    print("/s2ke dominos       - toggle Dominos / Editable layout mode")
    print("/s2ke ?             - show this command list")
    print("/s2ke prof on       - enable internal profiler and reset data")
    print("/s2ke prof off      - disable internal profiler")
    print("/s2ke prof reset    - reset collected profiler data")
    print("/s2ke prof print    - print profiler report")
    print("/s2ke prof          - same as /s2ke prof print")
    print("/s2ke cpu           - print WoW AddOnCPUUsage total")
    print("/s2ke wastats on    - show WA anchor stats panel")
    print("/s2ke wastats off   - hide WA anchor stats panel")
    print("/s2ke bench 60      - 60 sec WoW CPU benchmark, profiler OFF")
    print("/s2ke benchprof 60  - 60 sec benchmark plus internal function profiler")
    print("Aliases: profile on/off/reset/print also work.")
end

SLASH_S2KNAMEPLATES1 = "/s2ke"
SLASH_S2KNAMEPLATES2 = "/s2knp"
SlashCmdList["S2KNAMEPLATES"] = function(msg)
    msg = tostring(msg or ""):lower()
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "" then
        ToggleS2KConfig("general", "general")
        return
    end

    if msg == "config" or msg == "options" or msg == "settings" then
        OpenS2KConfig("general", "general")
        return
    end

    if msg == "help" or msg == "?" or msg == "commands" then
        ProfilerPrintHelp()
        return
    end

    if msg == "dominos" then
        if ToggleDominosLayoutMode then
            ToggleDominosLayoutMode("slash")
        else
            print("s2k:Enhancements: Dominos integration is not available.")
        end
        return
    end

    if msg == "prof on" or msg == "profile on" then
        SetProfilerEnabled(true)
        return
    end

    if msg == "prof off" or msg == "profile off" then
        SetProfilerEnabled(false)
        return
    end

    if msg == "prof reset" or msg == "profile reset" then
        ProfilerReset()
        print("s2k:Enhancements profiler: reset")
        return
    end

    if msg == "prof print" or msg == "profile print" or msg == "prof" or msg == "profile" then
        ProfilerPrintReport()
        return
    end

    if msg == "cpu" or msg == "usage" then
        PrintAddonCPUUsageSnapshot()
        return
    end

    if msg == "wastats on" or msg == "wa stats on" then
        SetWeakAuraAnchorStatsPanelEnabled(true)
        return
    end

    if msg == "wastats off" or msg == "wa stats off" then
        SetWeakAuraAnchorStatsPanelEnabled(false)
        return
    end

    if msg == "wastats reset" or msg == "wa stats reset" then
        ResetWeakAuraAnchorStats()
        return
    end

    do
        local secs = msg:match("^bench%s+(%d+)$")
        if msg == "bench" or secs then
            StartCPUBenchmark(tonumber(secs) or CFG.debugBenchmarkSeconds or 60, false)
            return
        end
    end

    do
        local secs = msg:match("^benchprof%s+(%d+)$") or msg:match("^bench prof%s+(%d+)$")
        if msg == "benchprof" or msg == "bench prof" or secs then
            StartCPUBenchmark(tonumber(secs) or CFG.debugBenchmarkSeconds or 60, true)
            return
        end
    end

    print("s2k:Enhancements: unknown command: " .. tostring(msg))
    ProfilerPrintHelp()
end
