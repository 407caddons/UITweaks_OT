local addonName, addonTable = ...
if addonTable.disabledByEllesmere then return end

-- This config window owns the tracker's settings UI. The shared-DB integration
-- with LunaUITweaks (UIThingsDB.tracker) is handled in Core.lua; the panel itself
-- is always served from here.

addonTable.Config = {}

local configWindow

function addonTable.Config.Initialize()
    if configWindow then return end

    configWindow = CreateFrame("Frame", "LunaObjTrackerConfigWindow", UIParent)
    configWindow:SetSize(900, 650)
    local function FitToScreen()
        local width, height = UIParent:GetSize()
        if width and height and width > 0 and height > 0 then
            configWindow:SetScale(math.min(1, (width - 24) / 900, (height - 24) / 650))
        end
    end
    configWindow:HookScript("OnShow", FitToScreen)
    configWindow:RegisterEvent("DISPLAY_SIZE_CHANGED")
    configWindow:RegisterEvent("UI_SCALE_CHANGED")
    configWindow:SetScript("OnEvent", FitToScreen)
    FitToScreen()
    configWindow:SetClampedToScreen(true)
    addonTable.ConfigTheme.Window(configWindow)
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

    configWindow.TitleText:SetText("LUNA  /  OBJECTIVE TRACKER")

    -- Individual category pages replace the old nested scroll frames.
    local content = CreateFrame("Frame", nil, configWindow)
    content:SetPoint("TOPLEFT", 12, -52)
    content:SetPoint("BOTTOMRIGHT", -12, 18)

    -- Dummy tab for UpdateModuleVisuals compatibility
    local dummyTab = CreateFrame("Frame")
    dummyTab.Text = dummyTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    -- Run panel setup
    if addonTable.ConfigSetup and addonTable.ConfigSetup.Tracker then
        addonTable.ConfigSetup.Tracker(content, dummyTab, configWindow)
    end
    addonTable.ConfigTheme.SkinTree(configWindow)

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
    SLASH_LUNAOBJTRACKERNATIVE1 = "/lotnative"
    SlashCmdList["LUNAOBJTRACKERNATIVE"] = function(message)
        local mode = (message or ""):lower():match("^%s*(%S+)")
        if mode == "on" or mode == "off" then
            addonTable.db.debugNativeTracker = mode == "on"
            print("Luna: native tracker diagnostic " .. mode .. ". Run /reload to apply.")
        else
            print("Luna: /lotnative on leaves Blizzard's tracker untouched after /reload; /lotnative off restores suppression after /reload.")
        end
    end
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
    -- Always register the Blizzard Settings category. The main addon no longer
    -- hosts a tracker panel, so this addon owns its own config window in both
    -- standalone and shared-DB modes.
    addonTable.Config.Initialize()
    self:UnregisterAllEvents()
end)
