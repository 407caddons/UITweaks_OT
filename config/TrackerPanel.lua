local addonName, addonTable = ...
if addonTable.disabledByEllesmere then return end

-- Create setup table if it doesn't exist
addonTable.ConfigSetup = addonTable.ConfigSetup or {}

-- Get helpers
local Helpers = addonTable.ConfigHelpers

-- Keep labels inside their column in both standalone and shared-helper mode.
-- Do not mutate the base addon's helper table.
local function SetCheckButtonLabel(button, text)
    local label = Helpers.SetCheckButtonLabel(button, text)
    if label then
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", button, "TOPRIGHT", 2, -2)
        local function FitLabel()
            label:SetWidth(math.max(80, button:GetParent():GetWidth() - 64))
        end
        FitLabel()
        button:GetParent():HookScript("OnSizeChanged", FitLabel)
        label:SetWordWrap(true)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("TOP")
    end
    return label
end

-- Blizzard's slider template draws its title and min/max captions with regions
-- that can end up hidden or covered. Replace them with addon-owned font strings,
-- published under the same globals so the existing `_G[name .. "Text"]` code keeps working.
local function CreateLabeledSlider(name, parent)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    -- The template's captions may be reachable only through parentKeys (slider.Low)
    -- rather than the globals, so blank every font string it created.
    for _, region in ipairs({ slider:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            region:SetText("")
            region:Hide()
        end
    end
    for _, key in ipairs({ "Text", "Low", "High" }) do
        local region = slider[key]
        if type(region) == "table" and region.SetText then region:SetText(""); region:Hide() end
    end
    local function Replace(suffix, point, relPoint, x, y, template)
        local original = _G[name .. suffix]
        if original then original:SetText(""); original:Hide() end
        local label = parent:CreateFontString(nil, "OVERLAY", template)
        label:SetPoint(point, slider, relPoint, x, y)
        _G[name .. suffix] = label
        return label
    end
    Replace("Text", "BOTTOMLEFT", "TOPLEFT", 0, 4, "GameFontHighlight")
    Replace("Low", "TOPLEFT", "BOTTOMLEFT", 0, -2, "GameFontNormalSmall")
    Replace("High", "TOPRIGHT", "BOTTOMRIGHT", 0, -2, "GameFontNormalSmall")
    return slider
end

-- Define the setup function for Tracker panel
function addonTable.ConfigSetup.Tracker(panel, tab, configWindow)
    Helpers.CreateResetButton(panel, "tracker")
    local fonts = Helpers.fonts

    local function UpdateTracker()
        if addonTable.ObjectiveTracker then
            if addonTable.ObjectiveTracker.UpdateSettings then
                addonTable.ObjectiveTracker.UpdateSettings()
            end
            if addonTable.ObjectiveTracker.UpdateContent then
                addonTable.Core.SafeAfter(0.05, addonTable.ObjectiveTracker.UpdateContent)
            end
        end
    end

    local root = panel
    local Theme = addonTable.ConfigTheme
    local scroll = CreateFrame("ScrollFrame", nil, root, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -38)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(600, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, width)
        content:SetWidth(math.max(1, width))
    end)
    local sections = {}
    local sectionOffset = 0
    local function CreatePage(title, description)
        local heights = {
            General = 180, ["Sorting & Filtering"] = 690, Display = 410,
            Behavior = 480, Sounds = 370, ["Size & Position"] = 470,
            Fonts = 550, Colors = 450,
        }
        local page = CreateFrame("Frame", nil, content)
        page:SetPoint("TOPLEFT", 0, -sectionOffset)
        page:SetPoint("RIGHT", content, "RIGHT")
        page:SetHeight(heights[title])
        table.insert(sections, page)
        sectionOffset = sectionOffset + heights[title]
        local heading = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        heading:SetPoint("TOPLEFT", 16, -10)
        heading:SetText(title)
        heading:SetTextColor(.35, .9, .76)
        local line = page:CreateTexture(nil, "ARTWORK")
        line:SetPoint("TOPLEFT", 16, -32)
        line:SetPoint("TOPRIGHT", -16, -32)
        line:SetHeight(1)
        line:SetColorTexture(.3, .35, .37, .65)
        local body = CreateFrame("Frame", nil, page)
        body:SetPoint("TOPLEFT", 0, -40)
        body:SetPoint("BOTTOMRIGHT")
        return body
    end

    -------------------------------------------------------------
    -- SECTION: General (-10)
    -------------------------------------------------------------
    panel = CreatePage("General", "Enable the tracker and control its header and position lock.")

    local enableTrackerBtn = CreateFrame("CheckButton", "UIThingsTrackerEnableCheck", panel,
        "ChatConfigCheckButtonTemplate")
    enableTrackerBtn:SetPoint("TOPLEFT", 20, -10)
    SetCheckButtonLabel(enableTrackerBtn, "Enable Objective Tracker Tweaks")
    enableTrackerBtn:SetChecked(addonTable.db.enabled)
    enableTrackerBtn:SetScript("OnClick", function(self)
        local enabled = not not self:GetChecked()
        addonTable.db.enabled = enabled
        UpdateTracker()
        Helpers.UpdateModuleVisuals(panel, tab, enabled)
    end)
    Helpers.UpdateModuleVisuals(panel, tab, addonTable.db.enabled)

    local lockBtn = CreateFrame("CheckButton", "UIThingsLockCheck", panel, "ChatConfigCheckButtonTemplate")
    lockBtn:SetPoint("TOPLEFT", 20, -42)
    SetCheckButtonLabel(lockBtn, "Lock Position")
    lockBtn:SetChecked(addonTable.db.locked)
    lockBtn:SetScript("OnClick", function(self)
        local locked = not not self:GetChecked()
        if LunaUITweaksAPI and LunaUITweaksAPI.SetLayoutMode then
            LunaUITweaksAPI.SetLayoutMode(not locked)
            self:SetChecked(not LunaUITweaksAPI.IsLayoutModeActive())
        else
            addonTable.db.locked = locked
            UpdateTracker()
        end
    end)

    if LunaUITweaksAPI and LunaUITweaksAPI.RegisterLayoutParticipant then
        LunaUITweaksAPI.RegisterLayoutParticipant("ObjectiveTrackerConfig",function(active)
            lockBtn:SetChecked(not active)
        end)
    end

    local hideHeaderBtn = CreateFrame("CheckButton", "UIThingsHideHeaderCheck", panel, "ChatConfigCheckButtonTemplate")
    hideHeaderBtn:SetPoint("TOPLEFT", 20, -74)
    SetCheckButtonLabel(hideHeaderBtn, "Hide Header")
    hideHeaderBtn:SetChecked(addonTable.db.hideHeader)
    hideHeaderBtn:SetScript("OnClick", function(self)
        addonTable.db.hideHeader = not not self:GetChecked()
        UpdateTracker()
    end)

    -------------------------------------------------------------
    -- SECTION: Sorting & Filtering (-70)
    -------------------------------------------------------------
    panel = CreatePage("Sorting & Filtering", "Choose section order, quest grouping and distance updates.")

    local orderLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    orderLabel:SetPoint("TOPLEFT", 20, -10)
    orderLabel:SetText("Section Order: (top to bottom)")

    if not addonTable.db.sectionOrderList then
        addonTable.db.sectionOrderList = {
            "scenarios",
            "tempObjectives",
            "travelersLog",
            "worldQuests",
            "quests",
            "achievements"
        }
    else
        -- Migration: Add travelersLog if it doesn't exist
        local hasTravelersLog = false
        for _, key in ipairs(addonTable.db.sectionOrderList) do
            if key == "travelersLog" then
                hasTravelersLog = true
                break
            end
        end
        if not hasTravelersLog then
            local insertPos = 3
            for i, key in ipairs(addonTable.db.sectionOrderList) do
                if key == "tempObjectives" then
                    insertPos = i + 1
                    break
                end
            end
            table.insert(addonTable.db.sectionOrderList, insertPos, "travelersLog")
        end
    end

    local sectionNames = {
        scenarios = "Scenarios",
        tempObjectives = "Temporary Objectives",
        travelersLog = "Traveler's Log",
        worldQuests = "World Quests",
        campaignQuests = "Campaign Quests",
        quests = "Quests",
        achievements = "Achievements"
    }

    local orderItems = {}
    local yPos = -45

    local function UpdateOrderDisplay()
        for i, sectionKey in ipairs(addonTable.db.sectionOrderList) do
            if orderItems[i] then
                orderItems[i].text:SetText(string.format("%d. %s", i, sectionNames[sectionKey]))
                orderItems[i].upBtn:SetEnabled(i > 1)
                orderItems[i].downBtn:SetEnabled(i < #addonTable.db.sectionOrderList)
            end
        end
        UpdateTracker()
    end

    for i = 1, 7 do
        local item = CreateFrame("Frame", nil, panel)
        item:SetPoint("TOPLEFT", 20, yPos)
        item:SetSize(250, 24)

        item.text = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        item.text:SetPoint("LEFT", 5, 0)
        item.text:SetTextColor(.8, .85, .9)

        item.upBtn = CreateFrame("Button", nil, item)
        item.upBtn:SetSize(24, 24)
        item.upBtn:SetPoint("RIGHT", -30, 0)
        item.upBtn:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
        item.upBtn:SetScript("OnClick", function()
            if i > 1 then
                local temp = addonTable.db.sectionOrderList[i]
                addonTable.db.sectionOrderList[i] = addonTable.db.sectionOrderList[i - 1]
                addonTable.db.sectionOrderList[i - 1] = temp
                UpdateOrderDisplay()
            end
        end)

        item.downBtn = CreateFrame("Button", nil, item)
        item.downBtn:SetSize(24, 24)
        item.downBtn:SetPoint("RIGHT", 0, 0)
        item.downBtn:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
        item.downBtn:SetScript("OnClick", function()
            if i < #addonTable.db.sectionOrderList then
                local temp = addonTable.db.sectionOrderList[i]
                addonTable.db.sectionOrderList[i] = addonTable.db.sectionOrderList[i + 1]
                addonTable.db.sectionOrderList[i + 1] = temp
                UpdateOrderDisplay()
            end
        end)

        orderItems[i] = item
        yPos = yPos - 36
    end

    UpdateOrderDisplay()

    local zoneGroupCheckbox = CreateFrame("CheckButton", "UIThingsTrackerZoneGroupCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    zoneGroupCheckbox:SetPoint("TOPLEFT", 20, -300)
    zoneGroupCheckbox:SetHitRectInsets(0, -130, 0, 0)
    SetCheckButtonLabel(zoneGroupCheckbox, "Group Quests by Zone")
    zoneGroupCheckbox:SetChecked(addonTable.db.groupQuestsByZone)
    zoneGroupCheckbox:SetScript("OnClick", function(self)
        addonTable.db.groupQuestsByZone = self:GetChecked()
        UpdateTracker()
    end)

    local campaignGroupCheckbox = CreateFrame("CheckButton", "UIThingsTrackerCampaignGroupCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    campaignGroupCheckbox:SetPoint("TOPLEFT", 20, -332)
    campaignGroupCheckbox:SetHitRectInsets(0, -130, 0, 0)
    SetCheckButtonLabel(campaignGroupCheckbox, "Group Quests by Campaign")
    campaignGroupCheckbox:SetChecked(addonTable.db.groupQuestsByCampaign)
    campaignGroupCheckbox:SetScript("OnClick", function(self)
        addonTable.db.groupQuestsByCampaign = self:GetChecked()
        UpdateTracker()
    end)

    local showDistCheckbox = CreateFrame("CheckButton", "UIThingsTrackerShowDistCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    showDistCheckbox:SetPoint("TOPLEFT", 20, -364)
    showDistCheckbox:SetHitRectInsets(0, -130, 0, 0)
    SetCheckButtonLabel(showDistCheckbox, "Show Distance on Quests")
    showDistCheckbox:SetChecked(addonTable.db.showQuestDistance)
    showDistCheckbox:SetScript("OnClick", function(self)
        addonTable.db.showQuestDistance = self:GetChecked()
        UpdateTracker()
    end)

    local showXPCheckbox = CreateFrame("CheckButton", "UIThingsTrackerShowXPCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    showXPCheckbox:SetPoint("TOPLEFT", 300, -364)
    showXPCheckbox:SetHitRectInsets(0, -130, 0, 0)
    SetCheckButtonLabel(showXPCheckbox, "Show XP on Quests")
    showXPCheckbox:SetChecked(addonTable.db.showQuestXP)
    showXPCheckbox:SetScript("OnClick", function(self)
        addonTable.db.showQuestXP = self:GetChecked()
        UpdateTracker()
    end)

    local questDistCheckbox = CreateFrame("CheckButton", "UIThingsTrackerQuestDistCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    questDistCheckbox:SetPoint("TOPLEFT", 20, -396)
    questDistCheckbox:SetHitRectInsets(0, -130, 0, 0)
    SetCheckButtonLabel(questDistCheckbox, "Sort Quests by Distance")
    questDistCheckbox:SetChecked(addonTable.db.sortQuestsByDistance)
    questDistCheckbox:SetScript("OnClick", function(self)
        addonTable.db.sortQuestsByDistance = self:GetChecked()
        UpdateTracker()
    end)

    local distIntervalSlider = CreateLabeledSlider("UIThingsTrackerDistIntervalSlider", panel)
    distIntervalSlider:SetPoint("TOPLEFT", 20, -450)
    distIntervalSlider:SetMinMaxValues(0, 30)
    distIntervalSlider:SetValueStep(1)
    distIntervalSlider:SetObeyStepOnDrag(true)
    distIntervalSlider:SetWidth(180)
    local distVal = addonTable.db.distanceUpdateInterval or 0
    _G[distIntervalSlider:GetName() .. 'Text']:SetText(
        distVal == 0 and "Distance Refresh: Off" or string.format("Distance Refresh: %ds", distVal))
    _G[distIntervalSlider:GetName() .. 'Low']:SetText("Off")
    _G[distIntervalSlider:GetName() .. 'High']:SetText("30s")
    distIntervalSlider:SetValue(distVal)
    distIntervalSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        addonTable.db.distanceUpdateInterval = value
        _G[self:GetName() .. 'Text']:SetText(
            value == 0 and "Distance Refresh: Off" or string.format("Distance Refresh: %ds", value))
        UpdateTracker()
    end)

    local wqActiveCheckbox = CreateFrame("CheckButton", "UIThingsTrackerWQActiveCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    wqActiveCheckbox:SetPoint("TOPLEFT", 20, -490)
    wqActiveCheckbox:SetHitRectInsets(0, -130, 0, 0)
    SetCheckButtonLabel(wqActiveCheckbox, "Only In-Progress World Quests")
    wqActiveCheckbox:SetChecked(addonTable.db.onlyActiveWorldQuests)
    wqActiveCheckbox:SetScript("OnClick", function(self)
        addonTable.db.onlyActiveWorldQuests = self:GetChecked()
        UpdateTracker()
    end)

    local wqSortLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    wqSortLabel:SetPoint("TOPLEFT", 20, -535)
    wqSortLabel:SetText("Sort World Quests:")

    local wqSortOptions = {
        { text = "By Time",     value = "time" },
        { text = "By Distance", value = "distance" },
    }

    local wqSortDropdown = addonTable.ConfigDropdown.Create(panel, "UIThingsTrackerWQSortDropdown",
        wqSortOptions, addonTable.db.worldQuestSortBy or "time", function(value)
        addonTable.db.worldQuestSortBy = value
        UpdateTracker()
    end)
    wqSortDropdown:SetPoint("TOPLEFT", wqSortLabel, "BOTTOMLEFT", 0, -6)

    -------------------------------------------------------------
    -- SECTION: Display (-310)
    -------------------------------------------------------------
    panel = CreatePage("Display", "Choose which details appear beside your quests.")

    local wqTimerCheckbox = CreateFrame("CheckButton", "UIThingsTrackerWQTimerCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    wqTimerCheckbox:SetPoint("TOPLEFT", 20, -10)
    wqTimerCheckbox:SetHitRectInsets(0, -130, 0, 0)
    SetCheckButtonLabel(wqTimerCheckbox, "Show World Quest Timer")
    wqTimerCheckbox:SetChecked(addonTable.db.showWorldQuestTimer)
    wqTimerCheckbox:SetScript("OnClick", function(self)
        addonTable.db.showWorldQuestTimer = self:GetChecked()
        UpdateTracker()
    end)

    local countdownCheckbox = CreateFrame("CheckButton", "UIThingsTrackerCountdownCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    countdownCheckbox:SetPoint("TOPLEFT", 20, -42)
    countdownCheckbox:SetHitRectInsets(0, -180, 0, 0)
    SetCheckButtonLabel(countdownCheckbox, "Show Quest Countdown (MM:SS)")
    countdownCheckbox:SetChecked(addonTable.db.showQuestCountdown)
    countdownCheckbox:SetScript("OnClick", function(self)
        addonTable.db.showQuestCountdown = self:GetChecked()
        UpdateTracker()
    end)

    local wqRewardCheckbox = CreateFrame("CheckButton", "UIThingsTrackerWQRewardCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    wqRewardCheckbox:SetPoint("TOPLEFT", 20, -74)
    wqRewardCheckbox:SetHitRectInsets(0, -160, 0, 0)
    SetCheckButtonLabel(wqRewardCheckbox, "Show WQ Reward Icons")
    wqRewardCheckbox:SetChecked(addonTable.db.showWQRewardIcons)
    wqRewardCheckbox:SetScript("OnClick", function(self)
        addonTable.db.showWQRewardIcons = self:GetChecked()
        UpdateTracker()
    end)

    local hideCompletedCheckbox = CreateFrame("CheckButton", "UIThingsTrackerHideCompletedCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    hideCompletedCheckbox:SetPoint("TOPLEFT", 20, -106)
    hideCompletedCheckbox:SetHitRectInsets(0, -130, 0, 0)
    SetCheckButtonLabel(hideCompletedCheckbox, "Hide Completed Objectives")
    hideCompletedCheckbox:SetChecked(addonTable.db.hideCompletedSubtasks)
    hideCompletedCheckbox:SetScript("OnClick", function(self)
        addonTable.db.hideCompletedSubtasks = self:GetChecked()
        UpdateTracker()
    end)

    local checkmarkCheckbox = CreateFrame("CheckButton", "UIThingsTrackerCheckmarkCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    checkmarkCheckbox:SetPoint("TOPLEFT", 20, -138)
    checkmarkCheckbox:SetHitRectInsets(0, -180, 0, 0)
    SetCheckButtonLabel(checkmarkCheckbox, "Checkmark on Completed Objectives")
    checkmarkCheckbox:SetChecked(addonTable.db.completedObjectiveCheckmark)
    checkmarkCheckbox:SetScript("OnClick", function(self)
        addonTable.db.completedObjectiveCheckmark = self:GetChecked()
        UpdateTracker()
    end)

    local campaignCheckbox = CreateFrame("CheckButton", "UIThingsTrackerCampaignCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    campaignCheckbox:SetPoint("TOPLEFT", 20, -170)
    campaignCheckbox:SetHitRectInsets(0, -160, 0, 0)
    SetCheckButtonLabel(campaignCheckbox, "Highlight Campaign Quests")
    campaignCheckbox:SetChecked(addonTable.db.highlightCampaignQuests)
    campaignCheckbox:SetScript("OnClick", function(self)
        addonTable.db.highlightCampaignQuests = self:GetChecked()
        UpdateTracker()
    end)

    local questTypeCheckbox = CreateFrame("CheckButton", "UIThingsTrackerQuestTypeCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    questTypeCheckbox:SetPoint("TOPLEFT", 20, -202)
    questTypeCheckbox:SetHitRectInsets(0, -180, 0, 0)
    SetCheckButtonLabel(questTypeCheckbox, "Show Daily/Weekly Indicators")
    questTypeCheckbox:SetChecked(addonTable.db.showQuestTypeIndicators)
    questTypeCheckbox:SetScript("OnClick", function(self)
        addonTable.db.showQuestTypeIndicators = self:GetChecked()
        UpdateTracker()
    end)

    local questLineCheckbox = CreateFrame("CheckButton", "UIThingsTrackerQuestLineCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    questLineCheckbox:SetPoint("TOPLEFT", 20, -234)
    questLineCheckbox:SetHitRectInsets(0, -180, 0, 0)
    SetCheckButtonLabel(questLineCheckbox, "Show Questline Progress")
    questLineCheckbox:SetChecked(addonTable.db.showQuestLineProgress)
    questLineCheckbox:SetScript("OnClick", function(self)
        addonTable.db.showQuestLineProgress = self:GetChecked()
        UpdateTracker()
    end)

    local questLevelCheckbox = CreateFrame("CheckButton", "UIThingsTrackerQuestLevelCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    questLevelCheckbox:SetPoint("TOPLEFT", 20, -266)
    questLevelCheckbox:SetHitRectInsets(0, -180, 0, 0)
    SetCheckButtonLabel(questLevelCheckbox, "Show Quest Level After Name")
    questLevelCheckbox:SetChecked(addonTable.db.showQuestLevel)
    questLevelCheckbox:SetScript("OnClick", function(self)
        addonTable.db.showQuestLevel = self:GetChecked()
        UpdateTracker()
    end)

    local questRepCheckbox = CreateFrame("CheckButton", "UIThingsTrackerQuestRepCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    questRepCheckbox:SetPoint("TOPLEFT", 20, -298)
    questRepCheckbox:SetHitRectInsets(0, -180, 0, 0)
    SetCheckButtonLabel(questRepCheckbox, "Show Reputation Rewards")
    questRepCheckbox:SetChecked(addonTable.db.showQuestReputation)
    questRepCheckbox:SetScript("OnClick", function(self)
        addonTable.db.showQuestReputation = self:GetChecked()
        UpdateTracker()
    end)

    local untrackedCheckbox = CreateFrame("CheckButton", "UIThingsTrackerUntrackedCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    untrackedCheckbox:SetPoint("TOPLEFT", 300, -298)
    untrackedCheckbox:SetHitRectInsets(0, -150, 0, 0)
    SetCheckButtonLabel(untrackedCheckbox, "Show Untracked Quests")
    untrackedCheckbox:SetChecked(addonTable.db.showUntrackedQuests)
    untrackedCheckbox:SetScript("OnClick", function(self)
        addonTable.db.showUntrackedQuests = self:GetChecked()
        UpdateTracker()
    end)

    local tooltipCheckbox = CreateFrame("CheckButton", "UIThingsTrackerTooltipCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    tooltipCheckbox:SetPoint("TOPLEFT", 20, -330)
    tooltipCheckbox:SetHitRectInsets(0, -130, 0, 0)
    local tooltipLabel = SetCheckButtonLabel(tooltipCheckbox, "Tooltip Preview (temporarily unavailable)")
    tooltipCheckbox:SetChecked(false)
    tooltipCheckbox:Disable()
    if tooltipLabel then tooltipLabel:SetTextColor(.48, .53, .59) end
    tooltipCheckbox:SetScript("OnClick", function(self)
        addonTable.db.showTooltipPreview = self:GetChecked()
        UpdateTracker()
    end)

    -------------------------------------------------------------
    -- SECTION: Behavior (-435)
    -------------------------------------------------------------
    panel = CreatePage("Behavior", "Control visibility, automatic tracking and mouse shortcuts.")

    local autoTrackCheckbox = CreateFrame("CheckButton", "UIThingsTrackerAutoTrackCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    autoTrackCheckbox:SetPoint("TOPLEFT", 20, -10)
    autoTrackCheckbox:SetHitRectInsets(0, -110, 0, 0)
    SetCheckButtonLabel(autoTrackCheckbox, "Auto Track Quests")
    autoTrackCheckbox:SetChecked(addonTable.db.autoTrackQuests)
    autoTrackCheckbox:SetScript("OnClick", function(self)
        addonTable.db.autoTrackQuests = self:GetChecked()
    end)

    local combatHideCheckbox = CreateFrame("CheckButton", "UIThingsTrackerCombatHideCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    combatHideCheckbox:SetPoint("TOPLEFT", 20, -74)
    combatHideCheckbox:SetHitRectInsets(0, -90, 0, 0)
    SetCheckButtonLabel(combatHideCheckbox, "Hide in Combat")
    combatHideCheckbox:SetChecked(addonTable.db.hideInCombat)
    combatHideCheckbox:SetScript("OnClick", function(self)
        addonTable.db.hideInCombat = self:GetChecked()
        UpdateTracker()
    end)

    local mplusHideCheckbox = CreateFrame("CheckButton", "UIThingsTrackerMPlusHideCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    mplusHideCheckbox:SetPoint("TOPLEFT", 20, -106)
    mplusHideCheckbox:SetHitRectInsets(0, -70, 0, 0)
    SetCheckButtonLabel(mplusHideCheckbox, "Hide in M+")
    mplusHideCheckbox:SetChecked(addonTable.db.hideInMPlus)
    mplusHideCheckbox:SetScript("OnClick", function(self)
        addonTable.db.hideInMPlus = self:GetChecked()
        UpdateTracker()
    end)

    local raidHideCheckbox = CreateFrame("CheckButton", "UIThingsTrackerRaidHideCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    raidHideCheckbox:SetPoint("TOPLEFT", 20, -138)
    raidHideCheckbox:SetHitRectInsets(0, -70, 0, 0)
    SetCheckButtonLabel(raidHideCheckbox, "Hide in Raid")
    raidHideCheckbox:SetChecked(addonTable.db.hideInRaid)
    raidHideCheckbox:SetScript("OnClick", function(self)
        addonTable.db.hideInRaid = self:GetChecked()
        UpdateTracker()
    end)

    local restoreSuperTrackCheckbox = CreateFrame("CheckButton", "UIThingsTrackerRestoreSuperTrackCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    restoreSuperTrackCheckbox:SetPoint("TOPLEFT", 20, -42)
    restoreSuperTrackCheckbox:SetHitRectInsets(0, -200, 0, 0)
    SetCheckButtonLabel(restoreSuperTrackCheckbox, "Restore Super-Track After World Quest")
    restoreSuperTrackCheckbox:SetChecked(addonTable.db.restoreSuperTrack)
    restoreSuperTrackCheckbox:SetScript("OnClick", function(self)
        addonTable.db.restoreSuperTrack = self:GetChecked()
    end)

    -- Mouse Interactions sub-label
    local mouseLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mouseLabel:SetPoint("TOPLEFT", 20, -185)
    mouseLabel:SetText("Mouse Interactions:")

    local clickOpenCheckbox = CreateFrame("CheckButton", "UIThingsTrackerClickOpenCheck", panel,
        "ChatConfigCheckButtonTemplate")
    clickOpenCheckbox:SetPoint("TOPLEFT", 20, -215)
    clickOpenCheckbox:SetHitRectInsets(0, -180, 0, 0)
    SetCheckButtonLabel(clickOpenCheckbox, "Click: Open Quest Log")
    clickOpenCheckbox:SetChecked(addonTable.db.clickOpenQuest)
    clickOpenCheckbox:SetScript("OnClick", function(self)
        addonTable.db.clickOpenQuest = self:GetChecked()
    end)

    local shiftLinkCheckbox = CreateFrame("CheckButton", "UIThingsTrackerShiftLinkCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    shiftLinkCheckbox:SetPoint("TOPLEFT", 20, -247)
    shiftLinkCheckbox:SetHitRectInsets(0, -160, 0, 0)
    SetCheckButtonLabel(shiftLinkCheckbox, "Shift-Click: Link in Chat")
    shiftLinkCheckbox:SetChecked(addonTable.db.shiftClickLink)
    shiftLinkCheckbox:SetScript("OnClick", function(self)
        addonTable.db.shiftClickLink = self:GetChecked()
    end)

    local ctrlUntrackCheckbox = CreateFrame("CheckButton", "UIThingsTrackerCtrlUntrackCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    ctrlUntrackCheckbox:SetPoint("TOPLEFT", 20, -279)
    ctrlUntrackCheckbox:SetHitRectInsets(0, -160, 0, 0)
    SetCheckButtonLabel(ctrlUntrackCheckbox, "Ctrl-Click: Untrack Quest")
    ctrlUntrackCheckbox:SetChecked(addonTable.db.shiftClickUntrack)
    ctrlUntrackCheckbox:SetScript("OnClick", function(self)
        addonTable.db.shiftClickUntrack = self:GetChecked()
    end)

    local rightClickCheckbox = CreateFrame("CheckButton", "UIThingsTrackerRightClickCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    rightClickCheckbox:SetPoint("TOPLEFT", 20, -311)
    rightClickCheckbox:SetHitRectInsets(0, -160, 0, 0)
    SetCheckButtonLabel(rightClickCheckbox, "Right-Click: Super Track")
    rightClickCheckbox:SetChecked(addonTable.db.rightClickSuperTrack)
    rightClickCheckbox:SetScript("OnClick", function(self)
        addonTable.db.rightClickSuperTrack = self:GetChecked()
    end)

    local middleShareCheckbox = CreateFrame("CheckButton", "UIThingsTrackerMiddleShareCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    middleShareCheckbox:SetPoint("TOPLEFT", 20, -343)
    middleShareCheckbox:SetHitRectInsets(0, -160, 0, 0)
    SetCheckButtonLabel(middleShareCheckbox, "Middle-Click: Share Quest")
    middleShareCheckbox:SetChecked(addonTable.db.middleClickShare)
    middleShareCheckbox:SetScript("OnClick", function(self)
        addonTable.db.middleClickShare = self:GetChecked()
    end)

    -------------------------------------------------------------
    -- SECTION: Sounds (-635)
    -------------------------------------------------------------
    panel = CreatePage("Sounds", "Choose completion sounds and the playback channel.")

    local questSoundCheckbox = CreateFrame("CheckButton", "UIThingsTrackerQuestSoundCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    questSoundCheckbox:SetPoint("TOPLEFT", 20, -10)
    questSoundCheckbox:SetHitRectInsets(0, -160, 0, 0)
    SetCheckButtonLabel(questSoundCheckbox, "Sound on Quest Complete")
    questSoundCheckbox:SetChecked(addonTable.db.questCompletionSound)
    questSoundCheckbox:SetScript("OnClick", function(self)
        addonTable.db.questCompletionSound = self:GetChecked()
    end)

    local questSoundIDLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    questSoundIDLabel:SetPoint("TOPLEFT", 20, -48)
    questSoundIDLabel:SetText("Sound ID:")

    local questSoundIDBox = CreateFrame("EditBox", "UIThingsTrackerQuestSoundIDBox", panel, "InputBoxTemplate")
    questSoundIDBox:SetSize(60, 20)
    questSoundIDBox:SetPoint("LEFT", questSoundIDLabel, "RIGHT", 8, 0)
    questSoundIDBox:SetAutoFocus(false)
    questSoundIDBox:SetNumeric(true)
    questSoundIDBox:SetMaxLetters(6)
    questSoundIDBox:SetText(tostring(addonTable.db.questCompletionSoundID or 6199))
    questSoundIDBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val > 0 then
            addonTable.db.questCompletionSoundID = val
        end
        self:ClearFocus()
    end)
    questSoundIDBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local questSoundTestBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    questSoundTestBtn:SetSize(40, 20)
    questSoundTestBtn:SetPoint("LEFT", questSoundIDBox, "RIGHT", 5, 0)
    questSoundTestBtn:SetText("Test")
    questSoundTestBtn:SetScript("OnClick", function()
        local val = tonumber(questSoundIDBox:GetText())
        if val and val > 0 then PlaySound(val, addonTable.db.soundChannel or "Master") end
    end)

    local objSoundCheckbox = CreateFrame("CheckButton", "UIThingsTrackerObjSoundCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    objSoundCheckbox:SetPoint("TOPLEFT", 20, -105)
    objSoundCheckbox:SetHitRectInsets(0, -180, 0, 0)
    SetCheckButtonLabel(objSoundCheckbox, "Sound on Objective Complete")
    objSoundCheckbox:SetChecked(addonTable.db.objectiveCompletionSound)
    objSoundCheckbox:SetScript("OnClick", function(self)
        addonTable.db.objectiveCompletionSound = self:GetChecked()
    end)

    local objSoundIDLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    objSoundIDLabel:SetPoint("TOPLEFT", 20, -143)
    objSoundIDLabel:SetText("Sound ID:")

    local objSoundIDBox = CreateFrame("EditBox", "UIThingsTrackerObjSoundIDBox", panel, "InputBoxTemplate")
    objSoundIDBox:SetSize(60, 20)
    objSoundIDBox:SetPoint("LEFT", objSoundIDLabel, "RIGHT", 8, 0)
    objSoundIDBox:SetAutoFocus(false)
    objSoundIDBox:SetNumeric(true)
    objSoundIDBox:SetMaxLetters(6)
    objSoundIDBox:SetText(tostring(addonTable.db.objectiveCompletionSoundID or 6197))
    objSoundIDBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val > 0 then
            addonTable.db.objectiveCompletionSoundID = val
        end
        self:ClearFocus()
    end)
    objSoundIDBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local objSoundTestBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    objSoundTestBtn:SetSize(40, 20)
    objSoundTestBtn:SetPoint("LEFT", objSoundIDBox, "RIGHT", 5, 0)
    objSoundTestBtn:SetText("Test")
    objSoundTestBtn:SetScript("OnClick", function()
        local val = tonumber(objSoundIDBox:GetText())
        if val and val > 0 then PlaySound(val, addonTable.db.soundChannel or "Master") end
    end)

    local channelLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    channelLabel:SetPoint("TOPLEFT", 20, -205)
    channelLabel:SetText("Sound Channel:")

    local channelOptions = {}
    for _, channel in ipairs({ "Master", "SFX", "Music", "Ambience", "Dialog" }) do
        channelOptions[#channelOptions + 1] = { text = channel, value = channel }
    end
    local channelDropdown = addonTable.ConfigDropdown.Create(panel, "UIThingsTrackerSoundChannelDropdown",
        channelOptions, addonTable.db.soundChannel or "Master", function(value)
        addonTable.db.soundChannel = value
    end, 130)
    channelDropdown:SetPoint("LEFT", channelLabel, "RIGHT", 10, 0)

    local muteDefaultCheckbox = CreateFrame("CheckButton", "UIThingsTrackerMuteDefaultCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    muteDefaultCheckbox:SetPoint("TOPLEFT", 20, -265)
    muteDefaultCheckbox:SetHitRectInsets(0, -180, 0, 0)
    SetCheckButtonLabel(muteDefaultCheckbox, "Mute Default Quest Sounds")
    muteDefaultCheckbox:SetChecked(addonTable.db.muteDefaultQuestSounds)
    muteDefaultCheckbox:SetScript("OnClick", function(self)
        addonTable.db.muteDefaultQuestSounds = self:GetChecked()
        UpdateTracker()
    end)

    -------------------------------------------------------------
    -- SECTION: Size & Position (-620)
    -------------------------------------------------------------
    panel = CreatePage("Size & Position", "Adjust tracker dimensions, spacing and frame layer.")

    local widthSlider = CreateLabeledSlider("UIThingsWidthSlider", panel)
    widthSlider:SetPoint("TOPLEFT", 20, -35)
    widthSlider:SetMinMaxValues(100, 600)
    widthSlider:SetValueStep(10)
    widthSlider:SetObeyStepOnDrag(true)
    widthSlider:SetWidth(180)
    _G[widthSlider:GetName() .. 'Text']:SetText(string.format("Width: %d", addonTable.db.width))
    _G[widthSlider:GetName() .. 'Low']:SetText("100")
    _G[widthSlider:GetName() .. 'High']:SetText("600")
    widthSlider:SetValue(addonTable.db.width)
    widthSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 10) * 10
        addonTable.db.width = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Width: %d", value))
        UpdateTracker()
    end)

    local heightSlider = CreateLabeledSlider("UIThingsHeightSlider", panel)
    heightSlider:SetPoint("TOPLEFT", 20, -105)
    heightSlider:SetMinMaxValues(100, 1000)
    heightSlider:SetValueStep(10)
    heightSlider:SetObeyStepOnDrag(true)
    heightSlider:SetWidth(180)
    _G[heightSlider:GetName() .. 'Text']:SetText(string.format("Height: %d", addonTable.db.height))
    _G[heightSlider:GetName() .. 'Low']:SetText("100")
    _G[heightSlider:GetName() .. 'High']:SetText("1000")
    heightSlider:SetValue(addonTable.db.height)
    heightSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 10) * 10
        addonTable.db.height = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Height: %d", value))
        UpdateTracker()
    end)

    local paddingSlider = CreateLabeledSlider("UIThingsTrackerPaddingSlider", panel)
    paddingSlider:SetPoint("TOPLEFT", 20, -175)
    paddingSlider:SetMinMaxValues(0, 20)
    paddingSlider:SetValueStep(1)
    paddingSlider:SetObeyStepOnDrag(true)
    paddingSlider:SetWidth(120)
    _G[paddingSlider:GetName() .. 'Text']:SetText(string.format("Objective Line Gap: %d", addonTable.db
        .questPadding))
    _G[paddingSlider:GetName() .. 'Low']:SetText("0")
    _G[paddingSlider:GetName() .. 'High']:SetText("20")
    paddingSlider:SetValue(addonTable.db.questPadding)
    paddingSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        addonTable.db.questPadding = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Objective Line Gap: %d", value))
        UpdateTracker()
    end)

    local sectionSpacingSlider = CreateLabeledSlider("UIThingsTrackerSectionSpacingSlider", panel)
    sectionSpacingSlider:SetPoint("TOPLEFT", 20, -245)
    sectionSpacingSlider:SetMinMaxValues(0, 30)
    sectionSpacingSlider:SetValueStep(1)
    sectionSpacingSlider:SetObeyStepOnDrag(true)
    sectionSpacingSlider:SetWidth(120)
    _G[sectionSpacingSlider:GetName() .. 'Text']:SetText(string.format("Group Gap: %d",
        addonTable.db.sectionSpacing or 10))
    _G[sectionSpacingSlider:GetName() .. 'Low']:SetText("0")
    _G[sectionSpacingSlider:GetName() .. 'High']:SetText("30")
    sectionSpacingSlider:SetValue(addonTable.db.sectionSpacing or 10)
    sectionSpacingSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        addonTable.db.sectionSpacing = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Group Gap: %d", value))
        UpdateTracker()
    end)

    local itemSpacingSlider = CreateLabeledSlider("UIThingsTrackerItemSpacingSlider", panel)
    itemSpacingSlider:SetPoint("TOPLEFT", 20, -315)
    itemSpacingSlider:SetMinMaxValues(0, 20)
    itemSpacingSlider:SetValueStep(1)
    itemSpacingSlider:SetObeyStepOnDrag(true)
    itemSpacingSlider:SetWidth(120)
    _G[itemSpacingSlider:GetName() .. 'Text']:SetText(string.format("Quest Gap: %d",
        addonTable.db.itemSpacing or 5))
    _G[itemSpacingSlider:GetName() .. 'Low']:SetText("0")
    _G[itemSpacingSlider:GetName() .. 'High']:SetText("20")
    itemSpacingSlider:SetValue(addonTable.db.itemSpacing or 5)
    itemSpacingSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        addonTable.db.itemSpacing = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Quest Gap: %d", value))
        UpdateTracker()
    end)

    local trackerStrataLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    trackerStrataLabel:SetPoint("TOPLEFT", 20, -360)
    trackerStrataLabel:SetText("Strata:")

    local strataOptions = {}
    for _, strata in ipairs({ "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "TOOLTIP" }) do
        strataOptions[#strataOptions + 1] = { text = strata, value = strata }
    end
    local trackerStrataDropdown = addonTable.ConfigDropdown.Create(panel, "UIThingsTrackerStrataDropdown",
        strataOptions, addonTable.db.strata or "LOW", function(value)
        addonTable.db.strata = value
        UpdateTracker()
    end)
    trackerStrataDropdown:SetPoint("TOPLEFT", trackerStrataLabel, "BOTTOMLEFT", 0, -6)

    -------------------------------------------------------------
    -- SECTION: Fonts (-745)
    -------------------------------------------------------------
    panel = CreatePage("Fonts", "Choose separate fonts and sizes for each text level.")

    Helpers.CreateFontDropdown(
        panel,
        "UIThingsTrackerHeaderFontDropdown",
        "Quest Name Font:",
        addonTable.db.headerFont,
        function(fontPath, fontName)
            addonTable.db.headerFont = fontPath
            UpdateTracker()
        end,
        20,
        -37
    )

    local headerSizeSlider = CreateLabeledSlider("UIThingsTrackerHeaderSizeSlider", panel)
    headerSizeSlider:SetPoint("TOPLEFT", 20, -100)
    headerSizeSlider:SetMinMaxValues(8, 32)
    headerSizeSlider:SetValueStep(1)
    headerSizeSlider:SetObeyStepOnDrag(true)
    headerSizeSlider:SetWidth(150)
    _G[headerSizeSlider:GetName() .. 'Text']:SetText(string.format("Size: %d", addonTable.db.headerFontSize))
    _G[headerSizeSlider:GetName() .. 'Low']:SetText("8")
    _G[headerSizeSlider:GetName() .. 'High']:SetText("32")
    headerSizeSlider:SetValue(addonTable.db.headerFontSize)
    headerSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        addonTable.db.headerFontSize = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Size: %d", value))
        UpdateTracker()
    end)

    Helpers.CreateFontDropdown(
        panel,
        "UIThingsTrackerDetailFontDropdown",
        "Quest Detail Font:",
        addonTable.db.detailFont,
        function(fontPath, fontName)
            addonTable.db.detailFont = fontPath
            UpdateTracker()
        end,
        20,
        -187
    )

    local detailSizeSlider = CreateLabeledSlider("UIThingsTrackerDetailSizeSlider", panel)
    detailSizeSlider:SetPoint("TOPLEFT", 20, -250)
    detailSizeSlider:SetMinMaxValues(8, 32)
    detailSizeSlider:SetValueStep(1)
    detailSizeSlider:SetObeyStepOnDrag(true)
    detailSizeSlider:SetWidth(150)
    _G[detailSizeSlider:GetName() .. 'Text']:SetText(string.format("Size: %d", addonTable.db.detailFontSize))
    _G[detailSizeSlider:GetName() .. 'Low']:SetText("8")
    _G[detailSizeSlider:GetName() .. 'High']:SetText("32")
    detailSizeSlider:SetValue(addonTable.db.detailFontSize)
    detailSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        addonTable.db.detailFontSize = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Size: %d", value))
        UpdateTracker()
    end)

    Helpers.CreateFontDropdown(
        panel,
        "UIThingsTrackerSectionFontDropdown",
        "Section Header Font:",
        addonTable.db.sectionHeaderFont,
        function(fontPath, fontName)
            addonTable.db.sectionHeaderFont = fontPath
            UpdateTracker()
        end,
        20,
        -337
    )

    local sectionSizeSlider = CreateLabeledSlider("UIThingsTrackerSectionSizeSlider", panel)
    sectionSizeSlider:SetPoint("TOPLEFT", 20, -400)
    sectionSizeSlider:SetMinMaxValues(8, 32)
    sectionSizeSlider:SetValueStep(1)
    sectionSizeSlider:SetObeyStepOnDrag(true)
    sectionSizeSlider:SetWidth(150)
    _G[sectionSizeSlider:GetName() .. 'Text']:SetText(string.format("Size: %d", addonTable.db.sectionHeaderFontSize))
    _G[sectionSizeSlider:GetName() .. 'Low']:SetText("8")
    _G[sectionSizeSlider:GetName() .. 'High']:SetText("32")
    sectionSizeSlider:SetValue(addonTable.db.sectionHeaderFontSize)
    sectionSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        addonTable.db.sectionHeaderFontSize = value
        _G[self:GetName() .. 'Text']:SetText(string.format("Size: %d", value))
        UpdateTracker()
    end)

    -------------------------------------------------------------
    -- SECTION: Colors (-965)
    -------------------------------------------------------------
    panel = CreatePage("Colors", "Customize tracker text, border and background colours.")

    -- Row 1: Section Header, Active Quest, Campaign
    local sectionColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sectionColorLabel:SetPoint("TOPLEFT", 20, -15)
    sectionColorLabel:SetText("Section Header:")

    local sectionColorSwatch = CreateFrame("Button", nil, panel)
    sectionColorSwatch:SetSize(20, 20)
    sectionColorSwatch:SetPoint("LEFT", sectionColorLabel, "RIGHT", 5, 0)

    sectionColorSwatch.tex = sectionColorSwatch:CreateTexture(nil, "OVERLAY")
    sectionColorSwatch.tex:SetAllPoints()
    local shc = addonTable.db.sectionHeaderColor or { r = 1, g = 0.82, b = 0, a = 1 }
    sectionColorSwatch.tex:SetColorTexture(shc.r, shc.g, shc.b, shc.a)

    Mixin(sectionColorSwatch, BackdropTemplateMixin)
    sectionColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    sectionColorSwatch:SetBackdropBorderColor(1, 1, 1)

    sectionColorSwatch:SetScript("OnClick", function(self)
        local info = {}
        local prevR, prevG, prevB, prevA = shc.r, shc.g, shc.b, shc.a
        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = true
        info.opacityFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            shc.r, shc.g, shc.b, shc.a = r, g, b, a
            sectionColorSwatch.tex:SetColorTexture(r, g, b, a)
            addonTable.db.sectionHeaderColor = shc
            UpdateTracker()
        end
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            shc.r, shc.g, shc.b, shc.a = r, g, b, a
            sectionColorSwatch.tex:SetColorTexture(r, g, b, a)
            addonTable.db.sectionHeaderColor = shc
            UpdateTracker()
        end
        info.cancelFunc = function(previousValues)
            shc.r, shc.g, shc.b, shc.a = prevR, prevG, prevB, prevA
            sectionColorSwatch.tex:SetColorTexture(shc.r, shc.g, shc.b, shc.a)
            addonTable.db.sectionHeaderColor = shc
            UpdateTracker()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    local activeColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    activeColorLabel:SetPoint("TOPLEFT", 20, -55)
    activeColorLabel:SetText("Active Quest:")

    local activeColorSwatch = CreateFrame("Button", nil, panel)
    activeColorSwatch:SetSize(20, 20)
    activeColorSwatch:SetPoint("LEFT", activeColorLabel, "RIGHT", 10, 0)

    activeColorSwatch.tex = activeColorSwatch:CreateTexture(nil, "OVERLAY")
    activeColorSwatch.tex:SetAllPoints()
    local ac = addonTable.db.activeQuestColor or { r = 0, g = 1, b = 0, a = 1 }
    activeColorSwatch.tex:SetColorTexture(ac.r, ac.g, ac.b, ac.a)

    Mixin(activeColorSwatch, BackdropTemplateMixin)
    activeColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    activeColorSwatch:SetBackdropBorderColor(1, 1, 1)

    activeColorSwatch:SetScript("OnClick", function(self)
        local info = {}
        local prevR, prevG, prevB, prevA = ac.r, ac.g, ac.b, ac.a
        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = true
        info.opacityFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            ac.r, ac.g, ac.b, ac.a = r, g, b, a
            activeColorSwatch.tex:SetColorTexture(r, g, b, a)
            addonTable.db.activeQuestColor = ac
            UpdateTracker()
        end
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            ac.r, ac.g, ac.b, ac.a = r, g, b, a
            activeColorSwatch.tex:SetColorTexture(r, g, b, a)
            addonTable.db.activeQuestColor = ac
            UpdateTracker()
        end
        info.cancelFunc = function(previousValues)
            ac.r, ac.g, ac.b, ac.a = prevR, prevG, prevB, prevA
            activeColorSwatch.tex:SetColorTexture(ac.r, ac.g, ac.b, ac.a)
            addonTable.db.activeQuestColor = ac
            UpdateTracker()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    local campaignColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    campaignColorLabel:SetPoint("TOPLEFT", 20, -95)
    campaignColorLabel:SetText("Campaign:")

    local cqc = addonTable.db.campaignQuestColor or { r = 0.9, g = 0.7, b = 0.2, a = 1 }
    local campaignColorSwatch = CreateFrame("Button", nil, panel)
    campaignColorSwatch:SetSize(20, 20)
    campaignColorSwatch:SetPoint("LEFT", campaignColorLabel, "RIGHT", 10, 0)
    campaignColorSwatch.tex = campaignColorSwatch:CreateTexture(nil, "OVERLAY")
    campaignColorSwatch.tex:SetAllPoints()
    campaignColorSwatch.tex:SetColorTexture(cqc.r, cqc.g, cqc.b, cqc.a)
    Mixin(campaignColorSwatch, BackdropTemplateMixin)
    campaignColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    campaignColorSwatch:SetBackdropBorderColor(1, 1, 1)
    campaignColorSwatch:SetScript("OnClick", function(self)
        local info = {}
        local prevR, prevG, prevB, prevA = cqc.r, cqc.g, cqc.b, cqc.a
        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = true
        local function applyColor()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            cqc.r, cqc.g, cqc.b, cqc.a = r, g, b, a
            campaignColorSwatch.tex:SetColorTexture(r, g, b, a)
            addonTable.db.campaignQuestColor = cqc
            UpdateTracker()
        end
        info.opacityFunc = applyColor
        info.swatchFunc = applyColor
        info.cancelFunc = function()
            cqc.r, cqc.g, cqc.b, cqc.a = prevR, prevG, prevB, prevA
            campaignColorSwatch.tex:SetColorTexture(cqc.r, cqc.g, cqc.b, cqc.a)
            addonTable.db.campaignQuestColor = cqc
            UpdateTracker()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    -- Row 2: Quest Name, Objective
    local questNameColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    questNameColorLabel:SetPoint("TOPLEFT", 20, -135)
    questNameColorLabel:SetText("Quest Name:")

    local qnc = addonTable.db.questNameColor or { r = 1, g = 1, b = 1, a = 1 }
    local questNameColorSwatch = CreateFrame("Button", nil, panel)
    questNameColorSwatch:SetSize(20, 20)
    questNameColorSwatch:SetPoint("LEFT", questNameColorLabel, "RIGHT", 10, 0)
    questNameColorSwatch.tex = questNameColorSwatch:CreateTexture(nil, "OVERLAY")
    questNameColorSwatch.tex:SetAllPoints()
    questNameColorSwatch.tex:SetColorTexture(qnc.r, qnc.g, qnc.b, qnc.a)
    Mixin(questNameColorSwatch, BackdropTemplateMixin)
    questNameColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    questNameColorSwatch:SetBackdropBorderColor(1, 1, 1)
    questNameColorSwatch:SetScript("OnClick", function(self)
        local info = {}
        local prevR, prevG, prevB, prevA = qnc.r, qnc.g, qnc.b, qnc.a
        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = true
        local function applyColor()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            qnc.r, qnc.g, qnc.b, qnc.a = r, g, b, a
            questNameColorSwatch.tex:SetColorTexture(r, g, b, a)
            addonTable.db.questNameColor = qnc
            UpdateTracker()
        end
        info.opacityFunc = applyColor
        info.swatchFunc = applyColor
        info.cancelFunc = function()
            qnc.r, qnc.g, qnc.b, qnc.a = prevR, prevG, prevB, prevA
            questNameColorSwatch.tex:SetColorTexture(qnc.r, qnc.g, qnc.b, qnc.a)
            addonTable.db.questNameColor = qnc
            UpdateTracker()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    local objColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    objColorLabel:SetPoint("TOPLEFT", 20, -175)
    objColorLabel:SetText("Objective:")

    local occ = addonTable.db.objectiveColor or { r = 0.8, g = 0.8, b = 0.8, a = 1 }
    local objColorSwatch = CreateFrame("Button", nil, panel)
    objColorSwatch:SetSize(20, 20)
    objColorSwatch:SetPoint("LEFT", objColorLabel, "RIGHT", 10, 0)
    objColorSwatch.tex = objColorSwatch:CreateTexture(nil, "OVERLAY")
    objColorSwatch.tex:SetAllPoints()
    objColorSwatch.tex:SetColorTexture(occ.r, occ.g, occ.b, occ.a)
    Mixin(objColorSwatch, BackdropTemplateMixin)
    objColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    objColorSwatch:SetBackdropBorderColor(1, 1, 1)
    objColorSwatch:SetScript("OnClick", function(self)
        local info = {}
        local prevR, prevG, prevB, prevA = occ.r, occ.g, occ.b, occ.a
        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = true
        local function applyColor()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            occ.r, occ.g, occ.b, occ.a = r, g, b, a
            objColorSwatch.tex:SetColorTexture(r, g, b, a)
            addonTable.db.objectiveColor = occ
            UpdateTracker()
        end
        info.opacityFunc = applyColor
        info.swatchFunc = applyColor
        info.cancelFunc = function()
            occ.r, occ.g, occ.b, occ.a = prevR, prevG, prevB, prevA
            objColorSwatch.tex:SetColorTexture(occ.r, occ.g, occ.b, occ.a)
            addonTable.db.objectiveColor = occ
            UpdateTracker()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    -- Row 3: Border + color, Background + color
    local borderCheckbox = CreateFrame("CheckButton", "UIThingsTrackerBorderCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    borderCheckbox:SetPoint("TOPLEFT", 20, -225)
    borderCheckbox:SetHitRectInsets(0, -80, 0, 0)
    SetCheckButtonLabel(borderCheckbox, "Show Border")
    borderCheckbox:SetChecked(addonTable.db.showBorder)
    borderCheckbox:SetScript("OnClick", function(self)
        addonTable.db.showBorder = self:GetChecked()
        UpdateTracker()
    end)

    local borderColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    borderColorLabel:SetPoint("TOPLEFT", 20, -265)
    borderColorLabel:SetText("Color:")

    local borderColorSwatch = CreateFrame("Button", nil, panel)
    borderColorSwatch:SetSize(20, 20)
    borderColorSwatch:SetPoint("LEFT", borderColorLabel, "RIGHT", 5, 0)

    borderColorSwatch.tex = borderColorSwatch:CreateTexture(nil, "OVERLAY")
    borderColorSwatch.tex:SetAllPoints()
    local bc = addonTable.db.borderColor or { r = 0, g = 0, b = 0, a = 1 }
    borderColorSwatch.tex:SetColorTexture(bc.r, bc.g, bc.b, bc.a)

    Mixin(borderColorSwatch, BackdropTemplateMixin)
    borderColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    borderColorSwatch:SetBackdropBorderColor(1, 1, 1)

    borderColorSwatch:SetScript("OnClick", function(self)
        local info = {}
        local prevR, prevG, prevB, prevA = bc.r, bc.g, bc.b, bc.a
        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = true
        info.opacityFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            bc.r, bc.g, bc.b, bc.a = r, g, b, a
            borderColorSwatch.tex:SetColorTexture(r, g, b, a)
            addonTable.db.borderColor = bc
            UpdateTracker()
        end
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            bc.r, bc.g, bc.b, bc.a = r, g, b, a
            borderColorSwatch.tex:SetColorTexture(r, g, b, a)
            addonTable.db.borderColor = bc
            UpdateTracker()
        end
        info.cancelFunc = function(previousValues)
            bc.r, bc.g, bc.b, bc.a = prevR, prevG, prevB, prevA
            borderColorSwatch.tex:SetColorTexture(bc.r, bc.g, bc.b, bc.a)
            addonTable.db.borderColor = bc
            UpdateTracker()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    local bgCheckbox = CreateFrame("CheckButton", "UIThingsTrackerBgCheckbox", panel,
        "ChatConfigCheckButtonTemplate")
    bgCheckbox:SetPoint("TOPLEFT", 20, -315)
    bgCheckbox:SetHitRectInsets(0, -110, 0, 0)
    SetCheckButtonLabel(bgCheckbox, "Show Background")
    bgCheckbox:SetChecked(addonTable.db.showBackground)
    bgCheckbox:SetScript("OnClick", function(self)
        addonTable.db.showBackground = self:GetChecked()
        UpdateTracker()
    end)

    local bgColorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bgColorLabel:SetPoint("TOPLEFT", 20, -355)
    bgColorLabel:SetText("Color:")

    local bgColorSwatch = CreateFrame("Button", nil, panel)
    bgColorSwatch:SetSize(20, 20)
    bgColorSwatch:SetPoint("LEFT", bgColorLabel, "RIGHT", 5, 0)

    bgColorSwatch.tex = bgColorSwatch:CreateTexture(nil, "OVERLAY")
    bgColorSwatch.tex:SetAllPoints()
    local c = addonTable.db.backgroundColor or { r = 0, g = 0, b = 0, a = 0.5 }
    bgColorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)

    Mixin(bgColorSwatch, BackdropTemplateMixin)
    bgColorSwatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    bgColorSwatch:SetBackdropBorderColor(1, 1, 1)

    bgColorSwatch:SetScript("OnClick", function(self)
        local info = {}
        local prevR, prevG, prevB, prevA = c.r, c.g, c.b, c.a
        info.r, info.g, info.b, info.opacity = prevR, prevG, prevB, prevA
        info.hasOpacity = true
        info.opacityFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            c.r, c.g, c.b, c.a = r, g, b, a
            bgColorSwatch.tex:SetColorTexture(r, g, b, a)
            addonTable.db.backgroundColor = c
            UpdateTracker()
        end
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            c.r, c.g, c.b, c.a = r, g, b, a
            bgColorSwatch.tex:SetColorTexture(r, g, b, a)
            addonTable.db.backgroundColor = c
            UpdateTracker()
        end
        info.cancelFunc = function(previousValues)
            c.r, c.g, c.b, c.a = prevR, prevG, prevB, prevA
            bgColorSwatch.tex:SetColorTexture(c.r, c.g, c.b, c.a)
            addonTable.db.backgroundColor = c
            UpdateTracker()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
    content:SetHeight(sectionOffset)
    content:SetWidth(math.max(1, scroll:GetWidth()))
    Theme.SkinTree(root)

end
