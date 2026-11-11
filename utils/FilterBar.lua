-- Always-visible search box and horizontally scrolling zone chips shown above the
-- tracker list. Addon-owned frames only; the tracker supplies the data through
-- FilterBar.Update and is told about changes through the onChange callback.
local _, addonTable = ...
if addonTable.disabledByEllesmere then return end

local Filter = addonTable.QuestFilter
local FilterBar = {}
addonTable.FilterBar = FilterBar

local SEARCH_HEIGHT, CHIP_HEIGHT, GAP, CHIP_SPACING = 22, 18, 4, 4
local SEARCH_DEBOUNCE = 0.15
FilterBar.HEIGHT = SEARCH_HEIGHT + GAP + CHIP_HEIGHT + 2

local bar, box, chipScroll, chipContent, moreRight, moreLeft
local chips = {}
local selectionChanged = false
local searchToken = 0
local onChange

local function After(delay, func)
    local after = (addonTable.Core and addonTable.Core.SafeAfter) or (C_Timer and C_Timer.After)
    if after then after(delay, func) else func() end
end

local function Notify(immediate)
    searchToken = searchToken + 1
    local mine = searchToken
    if immediate then
        if onChange then onChange() end
        return
    end
    After(SEARCH_DEBOUNCE, function()
        if mine == searchToken and onChange then onChange() end
    end)
end

local function UpdateOverflowHints()
    if not chipScroll then return end
    local viewport = chipScroll:GetWidth() or 0
    local content = chipContent:GetWidth() or 0
    local offset = chipScroll:GetHorizontalScroll() or 0
    if content > viewport + 1 and offset < content - viewport - 1 then moreRight:Show() else moreRight:Hide() end
    if offset > 1 then moreLeft:Show() else moreLeft:Hide() end
end

local function AcquireChip(index)
    local chip = chips[index]
    if chip then return chip end
    chip = CreateFrame("Button", nil, chipContent)
    chip:SetHeight(CHIP_HEIGHT)
    chip.bg = chip:CreateTexture(nil, "BACKGROUND")
    chip.bg:SetAllPoints()
    chip.label = chip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chip.label:SetPoint("CENTER")
    chip:SetScript("OnClick", function(self)
        local mode = self.key
        if mode == Filter.GetZoneMode() and mode ~= "all" then mode = "all" end
        Filter.SetZoneMode(mode)
        selectionChanged = true
        Notify(true)
    end)
    chip:SetScript("OnEnter", function(self)
        if self.tip and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(self.tip)
            GameTooltip:Show()
        end
    end)
    chip:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    chips[index] = chip
    return chip
end

-- parent: tracker body, anchor: frame to sit under, callback: re-render request.
function FilterBar.Create(parent, anchor, callback)
    if bar then return bar end
    onChange = callback
    bar = CreateFrame("Frame", nil, parent)
    bar:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 10, -3)
    bar:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", -25, -3)
    bar:SetHeight(FilterBar.HEIGHT)

    box = CreateFrame("EditBox", nil, bar)
    box:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    box:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    box:SetHeight(SEARCH_HEIGHT)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(6, 22, 0, 0)
    box:SetMaxLetters(60)
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.45)
    local underline = box:CreateTexture(nil, "BORDER")
    underline:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
    underline:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    underline:SetHeight(1)
    underline:SetColorTexture(0.35, 0.55, 0.8, 0.8)

    local placeholder = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", box, "LEFT", 6, 0)
    placeholder:SetText("Search quests, zones, objectives...")

    local clear = CreateFrame("Button", nil, box)
    clear:SetSize(16, 16)
    clear:SetPoint("RIGHT", box, "RIGHT", -3, 0)
    local clearText = clear:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clearText:SetPoint("CENTER")
    clearText:SetText("x")
    clear:Hide()

    local function SyncWidgets()
        local hasText = (box:GetText() or "") ~= ""
        if hasText or box:HasFocus() then placeholder:Hide() else placeholder:Show() end
        if hasText then clear:Show() else clear:Hide() end
    end
    box:SetScript("OnTextChanged", function(self)
        SyncWidgets()
        if Filter.SetQuery(self:GetText()) then Notify(false) end
    end)
    box:SetScript("OnEditFocusGained", SyncWidgets)
    box:SetScript("OnEditFocusLost", SyncWidgets)
    box:SetScript("OnEscapePressed", function(self)
        if (self:GetText() or "") ~= "" then self:SetText("") else self:ClearFocus() end
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    clear:SetScript("OnClick", function()
        box:SetText("")
        box:ClearFocus()
    end)
    -- Typing must never swallow movement keys once combat starts.
    bar:RegisterEvent("PLAYER_REGEN_DISABLED")
    bar:SetScript("OnEvent", function() box:ClearFocus() end)
    bar:SetScript("OnHide", function() box:ClearFocus() end)

    chipScroll = CreateFrame("ScrollFrame", nil, bar)
    chipScroll:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -GAP)
    chipScroll:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -GAP)
    chipScroll:SetHeight(CHIP_HEIGHT)
    chipContent = CreateFrame("Frame", nil, chipScroll)
    chipContent:SetSize(10, CHIP_HEIGHT)
    chipScroll:SetScrollChild(chipContent)
    chipScroll:EnableMouseWheel(true)
    chipScroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, (chipContent:GetWidth() or 0) - (self:GetWidth() or 0))
        local current = self:GetHorizontalScroll() or 0
        self:SetHorizontalScroll(math.min(maxScroll, math.max(0, current - (delta or 0) * 40)))
        UpdateOverflowHints()
    end)

    moreRight = chipScroll:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    moreRight:SetPoint("RIGHT", chipScroll, "RIGHT", 0, 0)
    moreRight:SetText("|cFFFFD100>>|r")
    moreRight:Hide()
    moreLeft = chipScroll:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    moreLeft:SetPoint("LEFT", chipScroll, "LEFT", 0, 0)
    moreLeft:SetText("|cFFFFD100<<|r")
    moreLeft:Hide()
    return bar
end

-- data = { all = n, here = n, hereName = "Zone", zones = { { name =, count = }, ... } }
function FilterBar.Update(data)
    if not bar or type(data) ~= "table" then return end
    local mode = Filter.GetZoneMode()
    local entries = {
        { key = "all", text = "All " .. data.all, tip = "Show every tracked quest" },
        { key = "here", text = "Here " .. data.here,
            tip = "Only quests in your current zone" .. ((data.hereName or "") ~= "" and (": " .. data.hereName) or "") },
        { key = "done", text = "Completed " .. (data.done or 0), tip = "Only completed quests, ready to turn in" },
    }
    local haveMode = mode == "all" or mode == "here" or mode == "done"
    for _, zone in ipairs(data.zones or {}) do
        entries[#entries + 1] = { key = zone.name, text = zone.name .. " " .. zone.count, tip = zone.name }
        if zone.name:lower() == mode:lower() then haveMode = true end
    end
    -- A saved zone with no matching quests must stay visible so it can be cleared.
    if not haveMode then entries[#entries + 1] = { key = mode, text = mode .. " 0", tip = mode } end

    local x, selectedLeft, selectedRight = 0, nil, nil
    for index, entry in ipairs(entries) do
        local chip = AcquireChip(index)
        chip.key, chip.tip = entry.key, entry.tip
        chip.label:SetText(entry.text)
        local width = (chip.label:GetStringWidth() or 40) + 14
        chip:SetWidth(width)
        chip:ClearAllPoints()
        chip:SetPoint("LEFT", chipContent, "LEFT", x, 0)
        local selected = entry.key == mode or (entry.key:lower() == mode:lower() and mode ~= "all" and mode ~= "here" and mode ~= "done")
        if selected then
            chip.bg:SetColorTexture(0.2, 0.45, 0.75, 0.85)
            chip.label:SetTextColor(1, 1, 1)
            selectedLeft, selectedRight = x, x + width
        else
            chip.bg:SetColorTexture(1, 1, 1, 0.08)
            chip.label:SetTextColor(0.8, 0.8, 0.8)
        end
        chip:Show()
        x = x + width + CHIP_SPACING
    end
    for index = #entries + 1, #chips do chips[index]:Hide() end
    chipContent:SetWidth(math.max(1, x - CHIP_SPACING))

    local viewport = chipScroll:GetWidth() or 0
    local maxScroll = math.max(0, (chipContent:GetWidth() or 0) - viewport)
    local offset = chipScroll:GetHorizontalScroll() or 0
    if selectionChanged and selectedLeft then
        if selectedLeft < offset then offset = selectedLeft
        elseif selectedRight > offset + viewport then offset = selectedRight - viewport end
        selectionChanged = false
    end
    chipScroll:SetHorizontalScroll(math.min(maxScroll, math.max(0, offset)))
    UpdateOverflowHints()
end
