local _, addonTable = ...

-- ============================================================
-- Map taint guard
--
-- Why this file exists:
--
-- The click-to-open feature (left-click a tracker entry → quest details in
-- the quest log) calls QuestMapFrame_OpenToQuestDetails() from addon
-- (insecure) context. Blizzard's implementation writes
-- QuestMapFrame.DetailsFrame.questID, so that field now carries this addon's
-- taint — and it stays tainted until Blizzard code overwrites it securely
-- (e.g. the user clicks the quest log's Back button). On EVERY world-map pin
-- refresh, QuestDataProviderMixin:ShouldShowQuest() reads the field back via
-- QuestMapFrame_GetFocusedQuestID(), tainting the whole refresh. Out of
-- combat that is harmless, but ScriptRegion:SetPassThroughButtons() is
-- restricted for insecure execution in combat (since 10.1.5), so opening the
-- world map while in combat then fails on every quest pin with:
--
--   ADDON_ACTION_BLOCKED ... 'Button:SetPassThroughButtons()'
--   via MapCanvasPinMixin:CheckMouseButtonPassthrough()
--
-- There is no taint-free way to open the quest details pane, and clearing
-- the field ourselves doesn't help (a nil written from insecure code is
-- still a tainted read). Kaliel's Tracker hit the same wall and ships the
-- same class of workaround (KalielsTracker Modules/Hacks.lua, "World Map");
-- ours is narrower: instead of dropping the SetPassThroughButtons call
-- entirely, we only skip it while InCombatLockdown().
--
-- The mechanism: replace the map frame's AcquirePin with a verbatim copy of
-- MapCanvasMixin:AcquirePin (Blizzard_MapCanvas.lua), and combat-guard the
-- combat-restricted input-propagation widget methods per pin instance
-- (SetPassThroughButtons via MapCanvasPinMixin:CheckMouseButtonPassthrough,
-- SetPropagateMouseClicks via SuperTrackablePinMixin:UpdateMousePropagation —
-- the only two such calls in all of Blizzard_SharedMapDataProviders as of
-- 12.0; SetPropagateMouseMotion is wrapped as insurance). Out of combat the
-- behaviour is identical (the calls are legal then, tainted or not). In
-- combat a pin keeps its previous propagation/passthrough setting until next
-- acquired or updated out of combat — cosmetic.
--
-- NOTE: this deliberately breaks the "never write fields onto Blizzard
-- frames" rule. Writing the AcquirePin key taints exactly that key, which is
-- the point: pin acquisition already runs inside secureexecuterange (one
-- data provider per iteration), so the added taint is contained to the code
-- path that was already failing.
--
-- !! The copied code below must be re-synced with Blizzard_MapCanvas.lua
-- !! when the Interface version changes.
-- ============================================================

local MapTaintGuard = {}
addonTable.MapTaintGuard = MapTaintGuard

local patched = {} -- side-table: map frame -> true (never written to the frame)

-- Combat-restricted input-propagation widget methods. Blizzard's pin mixins
-- call these during OnAcquired/pin updates; since our replaced AcquirePin
-- makes the whole acquisition run tainted, every such call would be blocked
-- in combat. Shadow them on each pin instance with a combat-guarded wrapper:
-- out of combat they pass straight through, in combat they no-op instead of
-- erroring (the pin keeps its previous propagation state — cosmetic).
local RESTRICTED_INPUT_METHODS = {
    "SetPassThroughButtons",
    "SetPropagateMouseClicks",
    "SetPropagateMouseMotion",
}

local guardedPins = setmetatable({}, { __mode = "k" })

local function GuardPinInputMethods(pin)
    if guardedPins[pin] then return end
    for i = 1, #RESTRICTED_INPUT_METHODS do
        local name = RESTRICTED_INPUT_METHODS[i]
        local orig = pin[name] -- C method from the shared widget metatable
        if type(orig) == "function" then
            pin[name] = function(self, ...)
                if InCombatLockdown() then return end
                return orig(self, ...)
            end
        end
    end
    guardedPins[pin] = true
end

-- Verbatim copies of the local helpers in Blizzard_MapCanvas.lua referenced
-- by AcquirePin. Pin pools created before we patch keep Blizzard's secure
-- originals; pools created afterwards get these identical copies.
local function OnPinReleased(pinPool, pin)
    local map = pin:GetMap()
    if map then
        map:UnregisterPin(pin)
    end

    Pool_HideAndClearAnchors(pinPool, pin)
    pin:OnReleased()

    pin.pinTemplate = nil
    pin:SetOwningMap(nil)
end

local function OnPinMouseUp(pin, button, upInside)
    pin:OnMouseUp(button, upInside)
    if upInside then
        pin:OnClick(button)
    end
end

-- Verbatim copy of MapCanvasMixin:AcquirePin except for the
-- GuardPinInputMethods call right after Acquire().
local function AcquirePin(self, pinTemplate, ...)
    if not self.pinPools[pinTemplate] then
        local pinTemplateType = self:GetPinTemplateType(pinTemplate)
        self.pinPools[pinTemplate] = CreateFramePool(pinTemplateType, self:GetCanvas(), pinTemplate, OnPinReleased)
    end

    local pin, newPin = self.pinPools[pinTemplate]:Acquire()

    GuardPinInputMethods(pin) -- LunaUITweaks addition, see header comment

    pin.pinTemplate = pinTemplate
    pin:SetOwningMap(self)

    if newPin then
        local isMouseClickEnabled = pin:IsMouseClickEnabled()
        local isMouseMotionEnabled = pin:IsMouseMotionEnabled()

        if isMouseClickEnabled then
            pin:SetScript("OnMouseUp", OnPinMouseUp)
            pin:SetScript("OnMouseDown", pin.OnMouseDown)

            -- Prevent OnClick handlers from being run twice, once a frame is in the mapCanvas ecosystem it needs
            -- to process mouse events only via the map system.
            if pin:IsObjectType("Button") then
                pin:SetScript("OnClick", nil)
            end
        end

        if isMouseMotionEnabled then
            if newPin and not pin:DisableInheritedMotionScriptsWarning() then
                -- These will never be called, just define a OnMouseEnter and OnMouseLeave on the pin mixin and it'll be called when appropriate
                assert(pin:GetScript("OnEnter") == nil)
                assert(pin:GetScript("OnLeave") == nil)
            end
            pin:SetScript("OnEnter", pin.OnMouseEnter)
            pin:SetScript("OnLeave", pin.OnMouseLeave)
        end

        pin:SetMouseClickEnabled(isMouseClickEnabled)
        pin:SetMouseMotionEnabled(isMouseMotionEnabled)
    end

    if newPin then
        pin:OnLoad()
    end

    self.ScrollContainer:MarkCanvasDirty()
    pin:Show()
    pin:OnAcquired(...)

    -- Most pins should pass through right clicks to allow the map to zoom out
    -- This needs to be checked after OnAcquired because re-used pins can have
    -- dynamic setups that requires input propagation adjustment.
    -- (In combat the guarded SetPassThroughButtons inside no-ops.)
    pin:CheckMouseButtonPassthrough("RightButton")

    self:RegisterPin(pin)

    return pin
end

local function PatchMap(map)
    if not map or patched[map] then return end
    -- Sanity-check the API surface so a future Blizzard rewrite degrades to
    -- "guard not applied" (the old error returns) instead of a broken map.
    if type(map.AcquirePin) ~= "function"
        or type(map.GetPinTemplateType) ~= "function"
        or type(map.RegisterPin) ~= "function"
        or type(map.UnregisterPin) ~= "function"
        or type(map.pinPools) ~= "table"
        or not map.ScrollContainer then
        return
    end
    map.AcquirePin = AcquirePin
    patched[map] = true
end

-- Idempotent; called from UpdateSettings whenever the tracker is enabled.
function MapTaintGuard.Apply()
    PatchMap(WorldMapFrame)
    PatchMap(BattlefieldMapFrame) -- load-on-demand; usually nil here
end

-- The battlefield (zone) map shares the same data providers and refreshes
-- during combat, so it needs the same guard once it loads.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(_, _, name)
    if name == "Blizzard_BattlefieldMap" and next(patched) ~= nil then
        PatchMap(BattlefieldMapFrame)
    end
end)
