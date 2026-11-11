local _, addon = ...
if addon.disabledByEllesmere then return end

-- Entirely addon-owned controls: no shared dropdown lists, menu globals,
-- Blizzard menu callbacks, or modifications to shared font objects.
local Dropdown = {}
addon.ConfigDropdown = Dropdown
local openMenu

local function Backdrop(frame)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(.055, .075, .095, 1)
    frame:SetBackdropBorderColor(.19, .35, .31, 1)
end

function Dropdown.Create(parent, name, options, currentValue, onSelect, width)
    local button = CreateFrame("Button", name, parent, "BackdropTemplate")
    button:SetSize(width or 180, 24)
    Backdrop(button)
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    button:GetHighlightTexture():SetVertexColor(.35, .9, .76, .15)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -24, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetTextColor(.85, .95, .9)
    button.Text = text
    local arrow = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetText("▾")
    arrow:SetTextColor(.35, .9, .76)
    local popup

    function button:SetSelectedValue(value)
        self.selectedValue = value
        local label = value and tostring(value) or "Select…"
        for _, option in ipairs(options) do
            if option.value == value then label = option.text; break end
        end
        text:SetText(label)
    end

    local function BuildPopup()
        -- UIParent avoids clipping by the settings page's scroll frame. Hide
        -- explicitly with the selector/owning window and on outside clicks.
        popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        popup:SetFrameStrata("TOOLTIP")
        popup:SetClampedToScreen(true)
        popup:EnableMouse(true)
        Backdrop(popup)
        popup:Hide()
        local height = math.max(24, math.min(#options, 8) * 24)
        popup:SetSize(button:GetWidth(), height + 12)
        local scroll = CreateFrame("ScrollFrame", nil, popup)
        scroll:SetPoint("TOPLEFT", 4, -6)
        scroll:SetPoint("BOTTOMRIGHT", -16, 6)
        local child = CreateFrame("Frame", nil, scroll)
        child:SetSize(math.max(1, button:GetWidth() - 20), math.max(24, #options * 24))
        scroll:SetScrollChild(child)
        local range = math.max(0, #options * 24 - height)
        local slider = CreateFrame("Slider", nil, popup)
        slider:SetPoint("TOPRIGHT", -3, -6)
        slider:SetPoint("BOTTOMRIGHT", -3, 6)
        slider:SetWidth(8)
        slider:SetOrientation("VERTICAL")
        slider:SetMinMaxValues(0, range)
        slider:SetValueStep(24)
        slider:SetObeyStepOnDrag(true)
        slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
        slider:GetThumbTexture():SetSize(6, 18)
        slider:GetThumbTexture():SetVertexColor(.35, .9, .76)
        slider:SetScript("OnValueChanged", function(_, value) scroll:SetVerticalScroll(value) end)
        slider:SetValue(0)
        if range == 0 then slider:Hide() end
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(_, delta)
            slider:SetValue(math.max(0, math.min(range, scroll:GetVerticalScroll() - delta * 24)))
        end)
        for index, option in ipairs(options) do
            local row = CreateFrame("Button", nil, child)
            row:SetPoint("TOPLEFT", 0, -(index - 1) * 24)
            row:SetSize(math.max(1, button:GetWidth() - 20), 24)
            row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
            row:GetHighlightTexture():SetVertexColor(.35, .9, .76, .2)
            local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            label:SetPoint("LEFT", 6, 0)
            label:SetPoint("RIGHT", -4, 0)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
            label:SetText(option.text)
            label:SetTextColor(.85, .95, .9)
            if option.font then pcall(label.SetFont, label, option.font, 12, "") end
            row:SetScript("OnClick", function()
                button:SetSelectedValue(option.value)
                popup:Hide()
                if onSelect then onSelect(option.value, option.text) end
            end)
        end
        popup:SetScript("OnEvent", function(self, event)
            if event == "PLAYER_REGEN_DISABLED" or (not self:IsMouseOver() and not button:IsMouseOver()) then self:Hide() end
        end)
        popup:SetScript("OnHide", function(self)
            self:UnregisterAllEvents()
            if openMenu == self then openMenu = nil end
        end)
        button.Popup = popup
    end

    button:SetScript("OnClick", function()
        if popup and popup:IsShown() then popup:Hide(); return end
        if openMenu then openMenu:Hide() end
        if not popup then BuildPopup() end
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
        popup:RegisterEvent("GLOBAL_MOUSE_DOWN")
        popup:RegisterEvent("PLAYER_REGEN_DISABLED")
        openMenu = popup
        popup:Show()
    end)
    button:HookScript("OnHide", function() if popup then popup:Hide() end end)
    -- Scrolling can clip a selector without hiding it. Close its popup instead
    -- of leaving an orphaned menu over a different part of the settings page.
    local ancestor = parent
    while ancestor and ancestor ~= UIParent do
        if ancestor:IsObjectType("ScrollFrame") then
            ancestor:HookScript("OnVerticalScroll", function() if popup then popup:Hide() end end)
        end
        ancestor = ancestor:GetParent()
    end
    button:SetSelectedValue(currentValue)
    return button
end

function Dropdown.CreateFont(parent, name, labelText, currentFont, onSelect, x, y, fonts)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", x or 20, y)
    label:SetText(labelText)
    local options = {}
    for _, font in ipairs(fonts or {}) do
        options[#options + 1] = { text = font.name, value = font.path, font = font.path }
    end
    local dropdown = Dropdown.Create(parent, name, options, currentFont, onSelect, 220)
    dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    return dropdown
end
