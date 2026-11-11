local addon, frame = ...
assert(loadfile("config/Dropdown.lua"))("test", addon)

-- These globals must never be invoked by our selectors, even in shared-helper mode.
for _, name in ipairs({ "UIDropDownMenu_Initialize", "UIDropDownMenu_CreateInfo", "UIDropDownMenu_AddButton",
    "UIDropDownMenu_SetText", "UIDropDownMenu_SetSelectedValue", "UIDropDownMenu_SetSelectedID" }) do
    _G[name] = function() error("legacy dropdown API used: " .. name) end
end
UIDROPDOWNMENU_MENU_LEVEL = "sentinel"
local scroll = CreateFrame("ScrollFrame", nil, UIParent)
local parent = CreateFrame("Frame", nil, scroll)
local options = {}
for i = 1, 20 do options[i] = { text = "Option " .. i, value = i } end
local selection
local selector = addon.ConfigDropdown.Create(parent, nil, options, 3, function(value) selection = value end)
selector:Show()
assert(selector.Text.text == "Option 3" and selector.Popup == nil, "popup must be lazy")
selector.scripts.OnClick(selector)
local popup = selector.Popup
assert(popup.shown and popup.events.GLOBAL_MOUSE_DOWN)
assert(popup.height == 8 * 24 + 12, "long lists must have bounded height")
local menuScroll = popup.children[1]
menuScroll.scripts.OnMouseWheel(menuScroll, -1)
assert(menuScroll:GetVerticalScroll() == 24)
local row = menuScroll.child.children[5]
row.scripts.OnClick(row)
assert(selection == 5 and selector.selectedValue == 5 and selector.Text.text == "Option 5")
assert(not popup.shown and not next(popup.events))
selector.scripts.OnClick(selector)
local other = addon.ConfigDropdown.Create(parent, nil, options, 1)
other:Show()
other.scripts.OnClick(other)
assert(not popup.shown and other.Popup.shown, "opening another menu must close the previous one")
other.Popup.scripts.OnEvent(other.Popup, "GLOBAL_MOUSE_DOWN")
assert(not other.Popup.shown)
selector.scripts.OnClick(selector)
scroll:SetVerticalScroll(30)
assert(not popup.shown, "scrolling the settings page must close its floating menu")
selector.scripts.OnClick(selector)
selector:Hide()
assert(not popup.shown, "hidden selector must not leave an orphaned popup")
selector:Show()
selector.scripts.OnClick(selector)
popup.scripts.OnEvent(popup, "PLAYER_REGEN_DISABLED")
assert(not popup.shown)
assert(UIDROPDOWNMENU_MENU_LEVEL == "sentinel")
print("PASS: addon-owned dropdown selection, scrolling, bounded menus and popup cleanup")

-- Standalone helper and integrated helper must both use our selector.
StaticPopupDialogs = {}
assert(loadfile("config/Helpers.lua"))("test", addon)
local standalone = addon.ConfigHelpers.CreateFontDropdown(parent, nil, "Font", "Fonts\\FRIZQT__.TTF", nil, 20, -20)
assert(standalone.Text.text == "Friz Quadrata")
local shared = { fonts = { { name = "Shared Font", path = "shared.ttf" } },
    CreateFontDropdown = function() error("base legacy font helper used") end }
LunaUITweaksAPI = { Helpers = shared }
assert(loadfile("config/Helpers.lua"))("test", addon)
assert(addon.ConfigHelpers ~= shared and shared.SetCheckButtonLabel == nil)
local selectedFont
local integrated = addon.ConfigHelpers.CreateFontDropdown(parent, nil, "Font", "shared.ttf", function(path)
    selectedFont = path
end, 20, -20)
integrated.scripts.OnClick(integrated)
local fontScroll = integrated.Popup.children[1]
fontScroll.child.children[1].scripts.OnClick()
assert(selectedFont == "shared.ttf" and UIDROPDOWNMENU_MENU_LEVEL == "sentinel")
print("PASS: standalone/shared font selectors without base-helper mutation or legacy APIs")

-- Closing a locked config is a no-op; closing an unlocked one requests only
-- deferred work, never runs native visibility/layout inline from OnHide.
local requested, inline = 0, 0
local configAddon = {
    db = { locked = true }, Core = addon.Core,
    ConfigTheme = {
        Window = function(window) window.TitleText = frame() end,
        SkinTree = function() end,
    },
    ObjectiveTracker = {
        RequestSettingsUpdate = function() requested = requested + 1 end,
        UpdateSettings = function() inline = inline + 1 end,
    },
}
UIParent = frame()
UISpecialFrames = {}
tinsert = table.insert
assert(loadfile("config/ConfigWindow.lua"))("test", configAddon)
configAddon.Config.Initialize()
local window = _G.LunaObjTrackerConfigWindow
window:Show()
window:Hide()
assert(requested == 0 and inline == 0)
window:Show()
configAddon.db.locked = false
window:Hide()
assert(configAddon.db.locked and requested == 1 and inline == 0)
window:Show(); window:Hide()
assert(requested == 1 and UISpecialFrames[1] == "LunaObjTrackerConfigWindow")
print("PASS: config close only requests relocking when needed and preserves Escape registration")
