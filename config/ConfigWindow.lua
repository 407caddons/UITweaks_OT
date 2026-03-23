local addonName, addonTable = ...

-- If LunaUITweaks is loaded, the tracker panel is registered via LunaUITweaksAPI.
-- This standalone config window is only used when running without LunaUITweaks.

addonTable.Config = {}

local configWindow

function addonTable.Config.Initialize()
    if configWindow then return end

    configWindow = CreateFrame("Frame", "LunaObjTrackerConfigWindow", UIParent, "BasicFrameTemplateWithInset")
    configWindow:SetSize(680, 670)
    configWindow:SetPoint("CENTER")
    configWindow:SetMovable(true)
    configWindow:EnableMouse(true)
    configWindow:SetFrameStrata("DIALOG")
    tinsert(UISpecialFrames, "LunaObjTrackerConfigWindow")
    configWindow:RegisterForDrag("LeftButton")
    configWindow:SetScript("OnDragStart", configWindow.StartMoving)
    configWindow:SetScript("OnDragStop", configWindow.StopMovingOrSizing)

    configWindow:SetScript("OnHide", function()
        -- Auto-lock tracker on config close
        if addonTable.db then
            addonTable.db.locked = true
            if addonTable.ObjectiveTracker and addonTable.ObjectiveTracker.UpdateSettings then
                addonTable.ObjectiveTracker.UpdateSettings()
            end
        end
    end)
    configWindow:Hide()

    configWindow.TitleText:SetText("Luna's Objective Tracker")

    -- Content area with scroll
    local scrollFrame = CreateFrame("ScrollFrame", "LunaObjTrackerConfigScroll", configWindow,
        "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1400)
    scrollFrame:SetScrollChild(scrollChild)

    -- Dummy tab for UpdateModuleVisuals compatibility
    local dummyTab = CreateFrame("Frame")
    dummyTab.Text = dummyTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    -- Run panel setup
    if addonTable.ConfigSetup and addonTable.ConfigSetup.Tracker then
        addonTable.ConfigSetup.Tracker(scrollChild, dummyTab, configWindow)
    end

    -- Register with Blizzard Settings
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local settingsFrame = CreateFrame("Frame")
        settingsFrame:SetScript("OnShow", function(self)
            self:Hide()
            HideUIPanel(SettingsPanel)
            addonTable.Config.ToggleWindow()
        end)
        local category = Settings.RegisterCanvasLayoutCategory(settingsFrame, "Luna's Objective Tracker")
        category.ID = addonName
        Settings.RegisterAddOnCategory(category)
    end
end

function addonTable.Config.ToggleWindow()
    if not configWindow then
        addonTable.Config.Initialize()
    end
    if configWindow:IsShown() then
        configWindow:Hide()
    else
        configWindow:Show()
    end
end

-- Global function for slash command
function LunaObjectiveTracker_OpenConfig()
    if addonTable.Config then
        addonTable.Config.ToggleWindow()
    end
end

-- Slash commands (standalone mode only)
local slashRegistered = false
local function RegisterSlashCommands()
    if slashRegistered then return end
    slashRegistered = true

    -- Only register standalone slash if LunaUITweaks is NOT loaded
    -- (when integrated, use /luit instead)
    SLASH_LUNAOBJTRACKER1 = "/luitracker"
    SLASH_LUNAOBJTRACKER2 = "/lot"
    SlashCmdList["LUNAOBJTRACKER"] = function()
        addonTable.Config.ToggleWindow()
    end
end

-- Register on PLAYER_LOGIN so we know if LunaUITweaks loaded
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    RegisterSlashCommands()
    -- Initialize config lazily on first use, but register with Blizzard Settings now
    if not (LunaUITweaksAPI and UIThingsDB and UIThingsDB.tracker) then
        -- Standalone mode: initialize settings panel integration
        addonTable.Config.Initialize()
    end
    self:UnregisterAllEvents()
end)
