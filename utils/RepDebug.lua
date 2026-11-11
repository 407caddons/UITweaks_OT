-- Debug helper: /lotrep [questID] [select]
-- Prints the raw return values of every quest-reputation API candidate so we can
-- see which ones this client (Retail or Forever) actually supports.
-- Read-only unless "select" is given, which temporarily selects the quest in the
-- quest log (restoring the previous selection afterwards).
local _, addonTable = ...
if addonTable.disabledByEllesmere then return end

local Secret = addonTable.Secret
local function Out(msg) print("|cff00ccff[lotrep]|r " .. msg) end

local function Str(v)
    if Secret and not Secret.CanAccessValue(v) then return "<secret>" end
    if type(v) == "table" then
        local parts = {}
        for k, x in pairs(v) do
            parts[#parts + 1] = tostring(k) .. "=" .. ((Secret and not Secret.CanAccessValue(x)) and "<secret>" or tostring(x))
        end
        table.sort(parts)
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return type(v) .. ":" .. tostring(v)
end

local function Pack(...) return select("#", ...), { ... } end

-- Call fn(...) in pcall and print every return value (including nils).
local function Try(label, fn, ...)
    if type(fn) ~= "function" then Out(label .. " -> MISSING"); return end
    local n, res = Pack(pcall(fn, ...))
    if not res[1] then Out(label .. " -> ERROR " .. tostring(res[2])); return res end
    local out = {}
    for i = 2, n do out[#out + 1] = Str(res[i]) end
    Out(label .. " -> " .. (#out > 0 and table.concat(out, " | ") or "(no returns)"))
    return res
end

local function FactionName(id)
    if type(id) ~= "number" then return end
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, data = pcall(C_Reputation.GetFactionDataByID, id)
        if ok and type(data) == "table" then Out("  faction " .. id .. " = " .. tostring(data.name)); return end
    end
    if GetFactionInfoByID then
        local ok, name = pcall(GetFactionInfoByID, id)
        if ok then Out("  faction " .. id .. " = " .. tostring(name)) end
    end
end

local function Probe(questID, logIndex, tag)
    Out("--- " .. tag .. " ---")
    local numRes = Try("GetNumQuestLogRewardFactions()", GetNumQuestLogRewardFactions)
    if logIndex then Try("GetNumQuestLogRewardFactions(logIndex)", GetNumQuestLogRewardFactions, logIndex) end
    Try("GetNumQuestLogRewardFactions(questID)", GetNumQuestLogRewardFactions, questID)
    local combos = { { "1", 1 }, { "1, questID", 1, questID }, { "questID", questID } }
    if logIndex then
        combos[#combos + 1] = { "logIndex", logIndex }
        combos[#combos + 1] = { "logIndex, 1", logIndex, 1 }
        combos[#combos + 1] = { "1, logIndex", 1, logIndex }
    end
    for _, c in ipairs(combos) do
        local res = Try("GetQuestLogRewardFactionInfo(" .. c[1] .. ")", GetQuestLogRewardFactionInfo, unpack(c, 2))
        if res and res[1] then FactionName(res[2]) end
    end
    local n = numRes and numRes[1] and numRes[2]
    if type(n) == "number" and (not Secret or Secret.CanAccessValue(n)) and n > 1 then
        for i = 2, math.min(n, 6) do
            local res = Try("GetQuestLogRewardFactionInfo(" .. i .. ")", GetQuestLogRewardFactionInfo, i)
            if res and res[1] then FactionName(res[2]) end
        end
    end
end

SLASH_LUNAOBJREPDEBUG1 = "/lotrep"
SlashCmdList["LUNAOBJREPDEBUG"] = function(msg)
    local idStr, mode = (msg or ""):match("^%s*(%d*)%s*(%a*)")
    local questID = tonumber(idStr)
    if not questID and C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        questID = C_SuperTrack.GetSuperTrackedQuestID()
    end
    if (not questID or questID == 0) and C_QuestLog and C_QuestLog.GetQuestIDForQuestWatchIndex then
        questID = C_QuestLog.GetQuestIDForQuestWatchIndex(1)
    end
    if not questID or questID == 0 then
        Out("No quest: pass a questID, or track/super-track a quest. Usage: /lotrep [questID] [select]")
        return
    end
    local _, build, _, interface = GetBuildInfo()
    Out(("client interface=%s build=%s; questID=%d"):format(tostring(interface), tostring(build), questID))
    local logIndex = C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID)
    Out("logIndex = " .. tostring(logIndex) .. (logIndex and "" or " (quest not in log: results may be empty)"))
    Out(("APIs: C_QuestInfoSystem.GetQuestRewardReputations=%s, C_QuestLog.GetSelectedQuest=%s, C_Reputation.GetFactionDataByID=%s, GetFactionInfoByID=%s"):format(
        tostring(C_QuestInfoSystem and C_QuestInfoSystem.GetQuestRewardReputations ~= nil),
        tostring(C_QuestLog and C_QuestLog.GetSelectedQuest ~= nil),
        tostring(C_Reputation and C_Reputation.GetFactionDataByID ~= nil),
        tostring(GetFactionInfoByID ~= nil)))
    if C_QuestInfoSystem and C_QuestInfoSystem.GetQuestRewardReputations then
        Try("C_QuestInfoSystem.GetQuestRewardReputations(questID)", C_QuestInfoSystem.GetQuestRewardReputations, questID)
    end
    Out("selected quest now = " .. tostring(C_QuestLog and C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()))

    Probe(questID, logIndex, "without changing selection")

    if mode:lower() == "select" and C_QuestLog and C_QuestLog.SetSelectedQuest then
        if InCombatLockdown() then Out("In combat: skipping select test."); return end
        local previous = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
        C_QuestLog.SetSelectedQuest(questID)
        Probe(questID, logIndex, "with quest selected")
        if previous and previous ~= 0 then C_QuestLog.SetSelectedQuest(previous) end
        Out("selection restored to " .. tostring(previous))
    else
        Out("Tip: run '/lotrep " .. questID .. " select' to also test with the quest selected.")
    end
end
