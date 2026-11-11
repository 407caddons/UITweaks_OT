local _,addon=...
local API=LunaUITweaksAPI
if addon.disabledByEllesmere or not API or not API.RegisterLayoutParticipant then return end
local preview
local function Enabled() return addon.db and addon.db.enabled end
local function Save(frame)
    if InCombatLockdown() or not addon.db then return end
    local point,_,relativePoint,x,y=frame:GetPoint()
    local db=addon.db
    db.point=point; db.x=math.floor(x+.5); db.y=math.floor(y+.5)
    frame:ClearAllPoints(); frame:SetPoint(point,UIParent,relativePoint,db.x,db.y)
    local body=_G.UIThingsTrackerBody
    if body then
        body:ClearAllPoints(); body:SetPoint(point,UIParent,relativePoint,db.x,db.y)
    end
end
local function SetLayoutMode(active)
    if not addon.db or InCombatLockdown() then return end
    addon.db.locked=not active
    addon.ObjectiveTracker.UpdateSettings()
    if not active or not Enabled() then
        if preview then preview:Hide() end
        return
    end
    if not preview then
        preview=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
        preview:SetMovable(true); preview:SetClampedToScreen(true); preview:SetFrameStrata("DIALOG")
        preview:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        preview:SetBackdropColor(.04,.18,.16,.35); preview:SetBackdropBorderColor(.3,.9,.75,1)
        local text=preview:CreateFontString(nil,"OVERLAY","GameFontNormal")
        text:SetPoint("CENTER"); text:SetText("Objective Tracker preview")
        API.RegisterLayoutTarget("Objective Tracker",function() return preview end,Enabled,Save)
    end
    local db=addon.db
    preview:SetSize(db.width,db.height)
    preview:ClearAllPoints(); preview:SetPoint(db.point,UIParent,db.point,db.x,db.y)
    preview:Show()
end
API.RegisterLayoutParticipant("LunaUITweaks_ObjectiveTracker",SetLayoutMode)

local watcher=CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
watcher:SetScript("OnEvent",function() if preview then preview:Hide() end end)
