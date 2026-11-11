-- Standalone regression tests. Run from the addon root with Lua 5.1+.
-- Mocks exercise value/lockdown boundaries, not WoW's actual taint engine.
unpack = unpack or table.unpack
local addon = {}
local secret = setmetatable({}, {
    __tostring = function() error("secret stringification") end,
    __concat = function() error("secret concatenation") end,
    __lt = function() error("secret comparison") end,
})
function canaccessvalue(value) return not rawequal(value, secret) end
assert(loadfile("utils/Secret.lua"))("test", addon)
local S = addon.Secret
local original = { text = "2/5", nested = { done = false } }
local copy, accessible = S.Snapshot(original)
assert(accessible and copy ~= original and copy.nested ~= original.nested)
assert(copy.nested.done == false)
assert(select(2, S.Snapshot({ finished = secret })) == false)
assert(select(2, S.Snapshot({ [secret] = "unsafe key" })) == false)
local cycle = {}; cycle.self = cycle
assert(select(2, S.Snapshot(cycle)) == false)
assert(select(2, S.Snapshot(0 / 0)) == false)
local a, b, c = S.WrapQuery(function() return nil, 7, false end)()
assert(a == nil and b == 7 and c == false, "nil tuple slots must be preserved")
assert(S.WrapQuery(function() return secret end, 0)() == 0)
assert(S.WrapQuery(function() error("restricted API") end, 0)() == 0)
assert(S.WrapQuery(nil) == nil)
local api = { GetData = function() return original end, SetData = function() end }
local facade = S.QueryAPI(api)
assert(facade ~= api and facade.SetData == api.SetData and facade.GetData ~= api.GetData)
assert(facade.GetData().text == "2/5")
local partial = S.QueryRows(function()
    return { { text = secret, finished = false }, { text = "2/5", finished = false, numFulfilled = secret } }
end, { "text", "finished", "numFulfilled" })()
assert(partial[1].text == nil and partial[1].finished == false)
assert(partial[2].text == "2/5" and partial[2].numFulfilled == nil)
print("PASS: secret snapshots, query fallbacks, tuple preservation, no global replacement")

local combat, selected = false, 101
local objectives = { { text = "0/5 Enemies", finished = false, numFulfilled = 0, numRequired = 5 } }
local scenario = { name = "Test Delve", currentStage = 1, numStages = 2 }
local step = { weightedProgress = 10, numCriteria = 1, title = "Test Stage", description = "" }
local criterion = { criteriaID = 77, description = "Enemies", quantity = 1, totalQuantity = 10, completed = false }
local achievementAmount = 1
local activityRequirement = { requirementText = "1/5 Activities", completed = false }
local accepted, watched, mutations, timers, frames = {}, {}, {}, {}, {}
local function mutation(name, id)
    assert(not combat, "protected-style action attempted in combat: " .. name)
    mutations[#mutations + 1] = { name, id }
end
function InCombatLockdown() return combat end
function GetLocale() return "enUS" end
function GetTime() return 100 end
function IsInInstance() return false, "none" end
function wipe(t) for k in pairs(t) do t[k] = nil end end
UIParent = {}
Enum = { QuestWatchType = { Automatic = 1 }, ContentTrackingType = { Achievement = 1 },
    WorldElapsedTimerTypes = { ChallengeMode = 1, ProvingGround = 2 } }
C_QuestLog = {
    GetQuestObjectives = function() return objectives end,
    GetNumQuestWatches = function() return 0 end,
    GetNumQuestLogEntries = function() return 0 end,
    IsOnQuest = function(id) return accepted[id] == true end,
    GetQuestWatchType = function(id) return watched[id] end,
    AddQuestWatch = function(id) mutation("watch", id); watched[id] = 1 end,
    IsComplete = function() return false end,
    IsWorldQuest = function() return false end,
    IsQuestTask = function() return false end,
}
C_SuperTrack = {
    GetSuperTrackedQuestID = function() return selected end,
    SetSuperTrackedQuestID = function(id) mutation("track", id); selected = id end,
}
C_Map = { GetBestMapForUnit = function() return nil end }
C_TaskQuest = { GetQuestTimeLeftMinutes = function() return nil end }
C_ScenarioInfo = {
    GetScenarioInfo = function() return scenario end,
    GetScenarioStepInfo = function() return step end,
    GetCriteriaInfo = function(i) if i == 1 then return criterion end end,
}
C_ContentTracking = { GetTrackedIDs = function() return { 700 } end }
function GetAchievementInfo(id) return id, "Test Achievement" end
function GetAchievementNumCriteria() return 1 end
function GetAchievementCriteriaInfo() return "Enemies", 0, false, achievementAmount, 10 end
C_PerksActivities = {
    GetTrackedPerksActivities = function() return { 800 } end,
    GetPerksActivitiesInfo = function()
        return { activities = { { ID = 800, activityName = "Test Activity", requirementsList = { activityRequirement } } } }
    end,
}
C_Timer = { After = function(_, func) timers[#timers + 1] = func end }
local methods = {}
local frame
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:UnregisterAllEvents() self.events = {} end
function methods:SetScript(event, script) self.scripts[event] = script end
function methods:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:Show()
    local wasShown = self.shown
    self.shown = true
    if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:HookScript(event, hook)
    local original = self.scripts[event]
    self.scripts[event] = function(...)
        if original then original(...) end
        hook(...)
    end
end
function methods:IsShown() return self.shown end
function methods:ClearFocus() end
function methods:HasFocus() return false end
function methods:GetText() return self.text or "" end
function methods:IsProtected() return self.protected or false end
function methods:SetAttribute(key, value) mutation("attribute", key); self[key] = value end
function methods:SetAlpha(value) self.alpha = value end
function methods:SetValue(value)
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function methods:SetText(value) self.text = value end
function methods:SetTextColor(...) self.color = { ... } end
function methods:GetTop() return self.top end
function methods:GetBottom() return self.bottom end
function methods:GetRight() return self.right end
function methods:ClearAllPoints() mutation("anchors") end
function methods:SetPoint(...) mutation("anchors"); self.point = { ... } end
function methods:GetFrameLevel() return 1 end
function methods:GetStringHeight() return 14 end
function methods:CreateTexture() return frame() end
function methods:CreateFontString() return frame() end
function methods:GetHighlightTexture() return frame() end
function methods:GetThumbTexture() self.thumb = self.thumb or frame(); return self.thumb end
function methods:GetParent() return self.parent end
function methods:IsObjectType(kind) return self.kind == kind end
function methods:IsMouseOver() return self.mouseOver or false end
function methods:SetScrollChild(child) self.child = child end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:SetVerticalScroll(value)
    self.scroll = value
    if self.scripts.OnVerticalScroll then self.scripts.OnVerticalScroll(self, value) end
end
function methods:SetHeight(value) self.height = value end
function methods:SetWidth(value) self.width = value end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:GetWidth() return self.width or 300 end
function methods:GetSize() return self.width or 300, self.height or 500 end
frame = function()
    return setmetatable({ scripts = {}, events = {}, protected = false, shown = false }, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if key:match("^Set") or key:match("^Get") or key:match("^Register") or key:match("^Enable")
            or key:match("^Hook") or key:match("^Start") or key:match("^Stop") then return function() end end
    end })
end
function CreateFrame(kind, name, parent, template)
    local object = frame()
    object.kind, object.template, object.parent = kind, template, parent
    frames[#frames + 1] = object
    if parent then
        parent.children = parent.children or {}
        parent.children[#parent.children + 1] = object
    end
    if name then _G[name] = object end
    return object
end
addon.db = { enabled = true, autoTrackQuests = true, restoreSuperTrack = true,
    activeQuestColor = { r = 0, g = 1, b = 0 }, completedObjectiveCheckmark = false }
addon.Core = { SafeAfter = C_Timer.After }
assert(loadfile("utils/Deferred.lua"))("test", addon)
assert(loadfile("utils/QuestModel.lua"))("test", addon)
assert(loadfile("utils/QuestFilter.lua"))("test", addon)
assert(loadfile("utils/FilterBar.lua"))("test", addon)

-- Search/zone filter logic: AND terms, case-insensitive, secret-safe, zone modes.
do
    local F = addon.QuestFilter
    local savedDB = addon.db
    addon.db = {}
    function GetRealZoneText() return "Durotar" end
    function GetZoneText() return "Razor Hill" end
    assert(not F.IsActive() and F.Matches({ "anything" }), "empty filter must match everything")
    assert(F.SetQuery("  Boar  durotar ") == true and F.IsSearching() and F.GetQuery() == "Boar  durotar")
    assert(F.SetQuery("Boar  durotar") == false, "unchanged query must not report a change")
    assert(F.Matches({ "Durotar", "Hunt the Boars", "0/8 Boar slain" }), "terms may match different parts")
    assert(not F.Matches({ "Durotar", "Hunt the Wolves", "0/8 Wolf slain" }), "every term must be present")
    assert(F.Matches({ "DUROTAR", "BOAR" }), "matching is case-insensitive")
    assert(F.Matches({ secret, "Boar", "Durotar" }), "unreadable parts are skipped, not fatal")
    assert(not F.Matches({ secret }), "unreadable text never matches")
    assert(F.Matches({ "a.b(c" }) == false and (F.SetQuery("a.b(c") and F.Matches({ "xa.b(cx" })),
        "terms are plain text, not patterns")
    F.SetQuery("")
    assert(not F.IsSearching() and not F.IsActive())
    local here, display = F.GetHereNames()
    assert(here.durotar and here["razor hill"] and display == "Durotar")
    assert(F.GetZoneMode() == "all" and F.ZoneMatches("Elwynn Forest", here))
    F.SetZoneMode("here")
    assert(F.IsActive() and F.ZoneMatches("Durotar", here) and not F.ZoneMatches("Elwynn Forest", here))
    assert(not F.ZoneMatches(secret, here))
    F.SetZoneMode("Elwynn Forest")
    assert(F.ZoneMatches("elwynn forest", here) and not F.ZoneMatches("Durotar", here))
    assert(addon.db.zoneFilter == "Elwynn Forest", "zone choice persists in the DB")
    F.SetZoneMode("all")
    addon.db = savedDB
    print("PASS: search terms, secret-safe matching, zone modes and persistence")
end

-- Search box + zone chips build and update on the frame mock without errors.
do
    local F = addon.QuestFilter
    local changes = 0
    local savedDB = addon.db
    addon.db = {}
    local barFrame = addon.FilterBar.Create({}, frame(), function() changes = changes + 1 end)
    assert(barFrame and addon.FilterBar.Create({}, frame(), function() end) == barFrame, "bar is created once")
    addon.FilterBar.Update({ all = 5, here = 2, hereName = "Durotar",
        zones = { { name = "Elwynn Forest", count = 2 }, { name = "Orgrimmar", count = 1 } } })
    F.SetZoneMode("Stranglethorn")
    addon.FilterBar.Update({ all = 0, here = 0, hereName = "", zones = {} })
    F.SetZoneMode("all")
    addon.db = savedDB
    for i = #mutations, 1, -1 do mutations[i] = nil end -- bar layout is addon-owned, not under test below
    print("PASS: filter bar creation and chip updates")
end

assert(loadfile("ObjectiveTracker.lua"))("test", addon)

local function upvalue(func, name)
    for i = 1, 100 do
        local label, value = debug.getupvalue(func, i)
        if not label then break end
        if label == name then return value, i end
    end
    error("Missing upvalue " .. name)
end
local function setUpvalue(func, name, value)
    local _, index = upvalue(func, name)
    debug.setupvalue(func, index, value)
end
local update = addon.ObjectiveTracker.UpdateContent
local refresh = upvalue(update, "RefreshCombatObjectives")
local pool = upvalue(refresh, "itemPool")
local row = frame()
row.questID, row.objectiveIndex, row.released = 101, 1, false
row.Text, row.ProgressBar = frame(), frame()
row.questTitleColor = { r = 1, g = 1, b = 1 }
pool[1] = row
combat = true
refresh()
assert(row.Text.text == "0/5 Enemies" and row.ProgressBar.shown and row.ProgressBar.value == 0)
objectives[1].text, objectives[1].numFulfilled = "3/5 Enemies", 3
refresh()
assert(row.Text.text == "3/5 Enemies" and row.ProgressBar.value == 60)
selected = 202
refresh()
assert(not row.ProgressBar.shown and row.Text.color[1] == 1, "old quest must lose highlight")
selected = 101
refresh()
assert(row.ProgressBar.shown, "previously hidden progress must appear in combat")
objectives[1].finished = true
refresh()
assert(row.Text.text:find("00FF00") and not row.ProgressBar.shown)
local lastText = row.Text.text
objectives[1].finished = secret
refresh()
assert(row.Text.text == lastText, "inaccessible snapshot must retain last readable text")
objectives[1].finished, objectives[1].text, objectives[1].numFulfilled = false, "4/5 Enemies", secret
refresh()
assert(row.Text.text == "4/5 Enemies" and row.ProgressBar.value == 80,
    "readable text progress must still update when a numeric counter is secret")
selected = secret
local lastColor = row.Text.color
refresh()
assert(row.Text.color == lastColor, "inaccessible selection must not erase highlight")
row.objectiveIndex = nil
row.combatRefresh = function() return "Scenario: 7/10" end
refresh()
assert(row.Text.text == "Scenario: 7/10")
row.combatRefresh = function() return secret end
refresh()
assert(row.Text.text == "Scenario: 7/10")
assert(#mutations == 0, "combat refresh must not change secure attributes or anchors")
print("PASS: combat progress, newly visible bars, completion, highlight changes, last-safe text")

local autoFrame
for _, object in ipairs(frames) do
    local callback = object.scripts.OnEvent
    if callback then
        for i = 1, 30 do
            local name = debug.getupvalue(callback, i)
            if not name then break end
            if name == "AutoTrackQuest" then autoFrame = object end
        end
    end
end
assert(autoFrame)
local queueTracking = upvalue(upvalue(autoFrame.scripts.OnEvent, "AutoTrackQuest"), "QueueTrackingReplay")
local deferred = upvalue(queueTracking, "deferred")
selected = 0
accepted[303] = true
autoFrame.scripts.OnEvent(autoFrame, "QUEST_ACCEPTED", 303)
assert(#mutations == 0, "auto watch must defer during combat")
combat = false
deferred.Flush()
assert(watched[303] and selected == 303)
local count = #mutations
combat = true
accepted[404] = true
autoFrame.scripts.OnEvent(autoFrame, "QUEST_ACCEPTED", 404)
accepted[404] = false
combat = false
deferred.Flush()
assert(#mutations == count, "removed quest must not replay")
combat = true
accepted[505] = true
autoFrame.scripts.OnEvent(autoFrame, "QUEST_ACCEPTED", 505)
addon.db.enabled = false
combat = false
deferred.Flush()
assert(#mutations == count, "disabled addon must discard queued watches")
print("PASS: combat-deferred auto tracking, removed quests, disable cancellation")

local sync = upvalue(update, "SyncQuestItemControls")
local viewport = frame(); viewport.top, viewport.bottom = 300, 100
setUpvalue(sync, "scrollFrame", viewport)
row.itemLink, row.shown, row.top, row.right, row.ItemBtn = "item:123", true, 250, 400, frame()
sync()
assert(row.ItemBtn.shown and row.ItemBtn.point[5] == 250)
row.top = 310
sync()
assert(not row.ItemBtn.shown, "clipped button must be hidden")
row.top = 110
sync()
assert(not row.ItemBtn.shown, "partially clipped button must be hidden")
local changes = #mutations
combat = true
sync()
assert(#mutations == changes, "scroll synchronisation must not move secure buttons in combat")
print("PASS: scroll item-button positioning, viewport clipping, combat guard")

addon.db.enabled = true
combat = false
local replay = upvalue(queueTracking, "ReplayPendingTracking")
local checkRestore = upvalue(replay, "CheckRestoreSuperTrack")
local queuedBefore = #timers
checkRestore()
assert(#timers == queuedBefore + 1)
addon.db.enabled = false
timers[#timers]()
assert(#mutations == changes)
print("PASS: delayed restoration is cancelled when disabled")

addon.db.enabled = true
addon.db.collapsed = {}
combat = false
selected = 0
wipe(pool)
local renderers = upvalue(update, "sectionRenderers")
local addLine = upvalue(renderers.scenarios, "AddLine")
local state = upvalue(addLine, "ucState")
for key, value in pairs({ width = 300, yOffset = -5, indent = 0, sectionHeaderSize = 14,
    detailSize = 12, questNameSize = 14, questPadding = 2,
    sectionHeaderFont = "test", detailFont = "test", questNameFont = "test",
    sectionHeaderColor = { r = 1, g = 1, b = 1 }, questNameColor = { r = 1, g = 1, b = 1 },
    objectiveColor = { r = 1, g = 1, b = 1 } }) do state[key] = value end
renderers.scenarios()
renderers.achievements()
renderers.travelersLog()
local scenarioRow, weightedRow, achievementRow, activityRow
for _, item in ipairs(pool) do
    if item.Text.text == "Enemies (1/10)" then
        if not scenarioRow then scenarioRow = item else achievementRow = item end
    elseif item.Text.text:find("10%% Complete") then weightedRow = item
    elseif item.Text.text == "1/5 Activities" then activityRow = item end
end
assert(scenarioRow and weightedRow and achievementRow and activityRow)
combat = true
criterion.quantity, step.weightedProgress, achievementAmount = 7, 70, 8
activityRequirement.requirementText = "3/5 Activities"
local beforeRefresh = #mutations
refresh()
assert(scenarioRow.Text.text == "Enemies (7/10)")
assert(weightedRow.Text.text:find("70%% Complete"))
assert(achievementRow.Text.text == "Enemies (8/10)")
assert(activityRow.Text.text == "3/5 Activities")
criterion.quantity, step.weightedProgress = secret, secret
refresh()
assert(scenarioRow.Text.text == "Enemies (7/10)" and weightedRow.Text.text:find("70%% Complete"))
scenario.currentStage = 2
criterion.quantity = 9
refresh()
assert(scenarioRow.Text.text == "Enemies (7/10)", "new stage must not overwrite previous-stage row")
assert(#mutations == beforeRefresh, "non-quest combat updates must not change secure layout")
print("PASS: actual scenario, achievement and Traveler's Log combat bindings")

local suppression = upvalue(upvalue(update, "ApplyTrackerState"), "ApplyNativeTrackerSuppression")
ObjectiveTrackerFrame = frame()
function ObjectiveTrackerFrame:GetAlpha() return self.alpha or 1 end
local nativeAlphaWrites = 0
function ObjectiveTrackerFrame:SetAlpha(value)
    assert(not combat, "native alpha must not be rewritten by combat updates")
    nativeAlphaWrites = nativeAlphaWrites + 1
    self.alpha = value
end
function RegisterStateDriver(_, _, state) mutation("driver", state) end
function UnregisterStateDriver() mutation("unregister driver") end
combat = true
suppression(true)
assert(nativeAlphaWrites == 0)
combat = false
deferred.Flush()
assert(nativeAlphaWrites == 1 and ObjectiveTrackerFrame.alpha == 0)
combat = true
suppression(true)
suppression(true)
assert(nativeAlphaWrites == 1, "combat progress must not repeatedly touch native alpha")
suppression(false)
assert(nativeAlphaWrites == 1, "native restoration must wait for combat to end")
combat = false
deferred.Flush()
assert(ObjectiveTrackerFrame.alpha == 1)
print("PASS: native suppression deferral and no repeated alpha writes during combat")

-- The initial secure pool is independent of text/header/objective row count.
local assign = upvalue(addLine, "AssignQuestItemButton")
local reserve = upvalue(assign, "ReserveQuestItemButtons")
local buttons = upvalue(reserve, "questItemButtons")
setUpvalue(reserve, "questItemContainer", frame())
reserve(16)
assert(#buttons == 16)
local rowCount, holders = #pool, {}
for i = 1, 17 do
    holders[i] = frame()
    assign(holders[i], "item:" .. i, i)
end
assert(#buttons == 24 and #pool == rowCount, "secure pool grows separately in batches")
combat = true
reserve(40)
assert(#buttons == 24)
local blocked = frame()
assign(blocked, "item:999", 999)
assert(blocked.ItemBtn == nil, "secure assignments must not change in combat")
combat = false
local release = upvalue(upvalue(update, "ReleaseItems"), "ReleaseQuestItemButtons")
release()
for _, holder in ipairs(holders) do assert(holder.ItemBtn == nil) end
for _, button in ipairs(buttons) do
    assert(button.row == nil and button.item == nil and button.type == nil and not button.shown)
end
assign(holders[1], "item:123", 123)
assert(#buttons == 24 and holders[1].ItemBtn == buttons[1])
release()
print("PASS: separate secure pool preallocation, batch growth, release/reuse and combat guards")

-- Exercise real setup and shutdown through the shared settings queue.
addon.db.width, addon.db.height, addon.db.locked = 300, 500, true
combat = true
addon.ObjectiveTracker.UpdateSettings()
assert(_G.UIThingsTrackerFrame == nil, "setup must wait for combat to end")
combat = false
deferred.Flush()
assert(_G.UIThingsTrackerFrame and _G.UIThingsTrackerBody, "queued setup must create the tracker")
addon.db.enabled = false
combat = true
addon.ObjectiveTracker.UpdateSettings()
combat = false
deferred.Flush()
assert(not _G.UIThingsTrackerFrame.shown)
for _, button in ipairs(buttons) do assert(not button.shown and button.item == nil) end
print("PASS: combat-deferred tracker setup and shutdown with secure pool cleanup")

-- Syntax-check every shipped Lua file without executing configuration code.
assert(loadfile("tests/modules.lua"))(addon, function(value) combat = value end)
assert(loadfile("tests/config.lua"))(addon, frame)
for _, path in ipairs({ "Core.lua", "ObjectiveTracker.lua", "utils/Secret.lua", "utils/MapTaintGuard.lua",
    "utils/Deferred.lua", "utils/QuestModel.lua", "utils/RepDebug.lua", "utils/QuestFilter.lua",
    "utils/FilterBar.lua",
    "config/Dropdown.lua",
    "config/Theme.lua", "config/Helpers.lua", "config/TrackerPanel.lua", "config/ConfigWindow.lua" }) do
    assert(loadfile(path))
end
print("PASS: all addon Lua files compile")
