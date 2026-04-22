local addonName, addonTable = ...

addonTable.Core = {}
addonTable.ObjectiveTracker = {}

-- ============================================================
-- Key Binding display names
-- Uses the same binding names as the main addon for keybind compatibility.
-- ============================================================
BINDING_HEADER_LUNAOBJTRACKER = "Luna's Objective Tracker"
_G["BINDING_NAME_CLICK LunaQuestItemButton:LeftButton"] = "Use Quest Item (Super Tracked)"
_G["BINDING_NAME_LUNAUITWEAKS_TOGGLE_TRACKER"] = "Toggle Objective Tracker"

-- ============================================================
-- Utilities
-- ============================================================

function addonTable.Core.SafeAfter(delay, func)
    if not func then return end
    if C_Timer and C_Timer.After then
        pcall(C_Timer.After, delay, func)
    end
end

function addonTable.Core.Log(module, msg, level)
    level = level or 1
    if level < 1 then return end
    local colors = { [0] = "888888", [1] = "00FF00", [2] = "FFFF00", [3] = "FF0000" }
    local prefix = string.format("|cFF%s[Luna %s]|r", colors[level] or "FFFFFF", module or "Tracker")
    print(prefix .. " " .. tostring(msg))
end

-- ============================================================
-- Defaults
-- ============================================================

local DEFAULTS = {
    locked = true,
    enabled = true,
    width = 300,
    height = 500,
    font = "Fonts\\FRIZQT__.TTF",
    fontSize = 12,
    headerFont = "Fonts\\FRIZQT__.TTF",
    headerFontSize = 14,
    detailFont = "Fonts\\FRIZQT__.TTF",
    detailFontSize = 12,
    sectionHeaderFont = "Fonts\\FRIZQT__.TTF",
    sectionHeaderFontSize = 14,
    sectionHeaderColor = { r = 1, g = 0.82, b = 0, a = 1 },
    questPadding = 2,
    sectionSpacing = 10,
    itemSpacing = 5,
    sectionOrderList = {
        "scenarios",
        "tempObjectives",
        "travelersLog",
        "worldQuests",
        "quests",
        "achievements"
    },
    onlyActiveWorldQuests = false,
    activeQuestColor = { r = 0, g = 1, b = 0, a = 1 },
    x = -20,
    y = -250,
    point = "TOPRIGHT",
    showBorder = false,
    borderColor = { r = 0, g = 0, b = 0, a = 1 },
    showBackground = false,
    hideInCombat = false,
    hideInMPlus = false,
    hideInRaid = false,
    autoTrackQuests = false,
    rightClickSuperTrack = true,
    shiftClickUntrack = true,
    clickOpenQuest = true,
    shiftClickLink = true,
    middleClickShare = true,
    backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 },
    strata = "LOW",
    showWorldQuestTimer = true,
    showQuestCountdown = true,
    hideCompletedSubtasks = false,
    groupQuestsByZone = false,
    groupQuestsByCampaign = false,
    worldQuestSortBy = "time",
    showQuestDistance = true,
    sortQuestsByDistance = false,
    showTooltipPreview = true,
    hideHeader = false,
    questNameColor = { r = 1, g = 1, b = 1, a = 1 },
    objectiveColor = { r = 0.8, g = 0.8, b = 0.8, a = 1 },
    completedObjectiveCheckmark = true,
    highlightCampaignQuests = true,
    campaignQuestColor = { r = 0.9, g = 0.7, b = 0.2, a = 1 },
    showQuestTypeIndicators = true,
    showQuestLineProgress = true,
    questCompletionSound = true,
    questCompletionSoundID = 6199,
    objectiveCompletionSound = false,
    objectiveCompletionSoundID = 6197,
    showWQRewardIcons = true,
    distanceUpdateInterval = 0,
    soundChannel = "Master",
    muteDefaultQuestSounds = false,
    restoreSuperTrack = true,
    collapsed = {}
}

addonTable.Core.DEFAULTS = { tracker = DEFAULTS }

local function ApplyDefaults(db, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" and not value.r then
            db[key] = db[key] or {}
            ApplyDefaults(db[key], value)
        elseif db[key] == nil then
            db[key] = value
        end
    end
end

-- ============================================================
-- Integration detection & settings binding
-- ============================================================

-- db is the live settings table used by all modules. Set on ADDON_LOADED.
addonTable.db = nil

local function OnEvent(self, event, loadedName)
    if event ~= "ADDON_LOADED" or loadedName ~= addonName then return end

    -- Always use our own saved variable — main LunaUITweaks no longer owns the
    -- tracker DB. Settings migrated from main's old UIThingsDB.tracker persist
    -- here from prior sessions (they were continuously synced in older versions).
    LunaObjectiveTrackerDB = LunaObjectiveTrackerDB or {}
    ApplyDefaults(LunaObjectiveTrackerDB, DEFAULTS)
    addonTable.db = LunaObjectiveTrackerDB

    -- If the LunaUITweaks config API is available, inject our panel as a tab
    -- in the main config window. Works the same way as the Chat History and
    -- Unit Frames companions.
    if LunaUITweaksAPI and LunaUITweaksAPI.RegisterConfigPanel
       and addonTable.ConfigSetup and addonTable.ConfigSetup.Tracker then
        LunaUITweaksAPI.RegisterConfigPanel(
            "tracker",
            "Tracker",
            "Interface\\Icons\\Inv_Misc_Book_09",
            addonTable.ConfigSetup.Tracker
        )
    end

    self:UnregisterEvent("ADDON_LOADED")
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", OnEvent)
