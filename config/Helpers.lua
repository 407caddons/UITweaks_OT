local addonName, addonTable = ...

-- TWW's ChatConfigCheckButtonTemplate ships a $parentText FontString whose
-- font/size/draw-layer state is unreliable for adjacent label use, so we
-- create our own OVERLAY FontString with an explicit font object and hide the
-- template's broken one. Cached on the button as _lunaLabel so repeated calls
-- (e.g. on locale change) reuse the same FontString.
local function SetCheckButtonLabel(cb, text)
    if not cb._lunaLabel then
        local label = cb:CreateFontString(nil, "OVERLAY")
        label:SetFontObject("GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 2, 1)
        label:SetJustifyH("LEFT")
        label:SetTextColor(1, 1, 1, 1)
        cb._lunaLabel = label

        local name = cb:GetName()
        local templateText = (name and _G[name .. "Text"]) or cb.Text or cb.text
        if templateText and templateText ~= label then
            templateText:SetText("")
            templateText:Hide()
        end
    end
    cb._lunaLabel:SetText(text)
    cb._lunaLabel:Show()
    return cb._lunaLabel
end

-- If LunaUITweaks is loaded, use its helpers instead of this minimal set.
if LunaUITweaksAPI and LunaUITweaksAPI.Helpers then
    addonTable.ConfigHelpers = LunaUITweaksAPI.Helpers
    -- Main addon's helpers may pre-date this function; inject if missing so
    -- TrackerPanel.lua can call it unconditionally.
    if not addonTable.ConfigHelpers.SetCheckButtonLabel then
        addonTable.ConfigHelpers.SetCheckButtonLabel = SetCheckButtonLabel
    end
    return
end

addonTable.ConfigHelpers = {}
local Helpers = addonTable.ConfigHelpers
Helpers.SetCheckButtonLabel = SetCheckButtonLabel

-- ============================================================
-- Shared Utilities
-- ============================================================

function Helpers.DeepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = Helpers.DeepCopy(v)
    end
    return copy
end

function Helpers.ApplyFrameBackdrop(frame, showBorder, borderColor, showBackground, backgroundColor)
    if showBorder or showBackground then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        if showBackground then
            local c = backgroundColor or { r = 0, g = 0, b = 0, a = 0.8 }
            frame:SetBackdropColor(c.r, c.g, c.b, c.a)
        else
            frame:SetBackdropColor(0, 0, 0, 0)
        end
        if showBorder then
            local bc = borderColor or { r = 1, g = 1, b = 1, a = 1 }
            frame:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
        else
            frame:SetBackdropBorderColor(0, 0, 0, 0)
        end
    else
        frame:SetBackdrop(nil)
    end
end

--- Helper: Update Visuals based on enabled state
function Helpers.UpdateModuleVisuals(panel, tab, enabled)
    tab.isDisabled = not enabled
    if not enabled then
        if tab.Text then
            tab.Text:SetTextColor(1, 0.2, 0.2)
        elseif tab:GetFontString() then
            tab:GetFontString():SetTextColor(1, 0.2, 0.2)
        end
    else
        if tab.Text then
            tab.Text:SetTextColor(1, 0.82, 0)
        elseif tab:GetFontString() then
            tab:GetFontString():SetTextColor(1, 0.82, 0)
        end
    end
end

--- Helper: Create a "Reset to Defaults" button
function Helpers.CreateResetButton(panel, dbKey, label)
    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(120, 22)
    btn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
    btn:SetText(label or "Reset Defaults")

    btn:SetScript("OnClick", function()
        StaticPopup_Show("LUNA_OT_RESET_CONFIRM", dbKey, nil, dbKey)
    end)

    return btn
end

if not StaticPopupDialogs["LUNA_OT_RESET_CONFIRM"] then
    StaticPopupDialogs["LUNA_OT_RESET_CONFIRM"] = {
        text = "Reset tracker settings to defaults?\n\nThis will reload the UI.",
        button1 = "Reset & Reload",
        button2 = "Cancel",
        OnAccept = function(self, data)
            local defaults = addonTable.Core and addonTable.Core.DEFAULTS and addonTable.Core.DEFAULTS.tracker
            if defaults and addonTable.db then
                wipe(addonTable.db)
                local function DeepCopyInto(target, source)
                    for k, v in pairs(source) do
                        if type(v) == "table" then
                            target[k] = {}
                            DeepCopyInto(target[k], v)
                        else
                            target[k] = v
                        end
                    end
                end
                DeepCopyInto(addonTable.db, defaults)
            end
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

--- Helper: Create Section Header
function Helpers.CreateSectionHeader(parent, text, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 16, yOffset)
    header:SetText(text)
    header:SetTextColor(1, 0.82, 0)

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    line:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    line:SetHeight(1)
    line:SetColorTexture(0.5, 0.5, 0.5, 0.5)

    return header
end

--- Build font list
local function BuildFontList()
    local fonts = {}
    local knownFonts = {
        { name = "Friz Quadrata",            path = "Fonts\\FRIZQT__.TTF" },
        { name = "Arial Narrow",             path = "Fonts\\ARIALN.TTF" },
        { name = "Skurri",                   path = "Fonts\\skurri.ttf" },
        { name = "Morpheus",                 path = "Fonts\\MORPHEUS.TTF" },
        { name = "Friz Quadrata (Cyrillic)", path = "Fonts\\FRIZQT___CYR.TTF" },
        { name = "Morpheus (Cyrillic)",      path = "Fonts\\MORPHEUS_CYR.TTF" },
        { name = "Skurri (Cyrillic)",        path = "Fonts\\SKURRI_CYR.TTF" },
        { name = "K Damage",                 path = "Fonts\\K_Damage.TTF" },
        { name = "K Pagetext",               path = "Fonts\\K_Pagetext.TTF" },
        { name = "2002",                     path = "Fonts\\2002.ttf" },
        { name = "2002 Bold",               path = "Fonts\\2002B.ttf" },
        { name = "NIM",                      path = "Fonts\\NIM_____.ttf" },
    }

    for _, font in ipairs(knownFonts) do
        table.insert(fonts, font)
    end

    -- Try to discover additional fonts dynamically
    local success, dynamicFonts = pcall(GetFonts)
    if success and dynamicFonts then
        local knownPaths = {}
        for _, font in ipairs(fonts) do
            knownPaths[font.path:upper()] = true
        end
        for _, fontObjectName in ipairs(dynamicFonts) do
            local fontObj = _G[fontObjectName]
            if fontObj and type(fontObj) == "table" and fontObj.GetFont then
                local ok, fontPath = pcall(fontObj.GetFont, fontObj)
                if ok and fontPath and type(fontPath) == "string" and fontPath ~= "" then
                    if not knownPaths[fontPath:upper()] then
                        table.insert(fonts, { name = fontObjectName, path = fontPath })
                        knownPaths[fontPath:upper()] = true
                    end
                end
            end
        end
    end

    table.sort(fonts, function(a, b) return a.name < b.name end)
    return fonts
end

Helpers.fonts = BuildFontList()

local fontObjectCache = {}

--- Helper: Create Font Dropdown with visual font preview
function Helpers.CreateFontDropdown(parent, name, labelText, currentFontPath, onSelectFunc, xOffset, yOffset)
    xOffset = xOffset or 20

    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", xOffset, yOffset)
    label:SetText(labelText)

    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -15, -10)

    local function OnClick(self)
        UIDropDownMenu_SetSelectedID(dropdown, self:GetID())
        if onSelectFunc then
            onSelectFunc(self.value, self.fontName)
        end
    end

    local function Initialize(self, level)
        for i, fontData in ipairs(Helpers.fonts) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = fontData.name
            info.value = fontData.path
            info.fontName = fontData.name
            info.func = OnClick

            local fontObj = fontObjectCache[fontData.path]
            if not fontObj then
                fontObj = CreateFont("LunaOTFontPreview_" .. i)
                local ok = pcall(fontObj.SetFont, fontObj, fontData.path, 12, "")
                if ok then
                    fontObjectCache[fontData.path] = fontObj
                else
                    fontObj = nil
                end
            end
            if fontObj then
                info.fontObject = fontObj
            end

            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dropdown, Initialize)

    local selectedName = "Select Font"
    for _, f in ipairs(Helpers.fonts) do
        if f.path == currentFontPath then
            selectedName = f.name
            break
        end
    end
    UIDropDownMenu_SetText(dropdown, selectedName)

    return dropdown
end
