-- Search text and zone filter state for the tracker. Pure logic: no frames.
-- The search box is AND-based: every whitespace separated term must appear
-- somewhere in the quest's zone, title or objective text (case-insensitive).
-- The zone filter is "all", "here" (the player's current zone) or a zone name,
-- and is saved in the tracker DB; the search text is session-only.
local _, addonTable = ...
if addonTable.disabledByEllesmere then return end

local Secret = addonTable.Secret
local Filter = {}
addonTable.QuestFilter = Filter

local terms = {}
local rawQuery = ""

local function CanUse(value)
    return type(value) == "string" and (not Secret or Secret.CanAccessValue(value))
end

-- Returns true when the search text changed.
function Filter.SetQuery(text)
    text = CanUse(text) and text or ""
    local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == rawQuery then return false end
    rawQuery = trimmed
    terms = {}
    for term in trimmed:lower():gmatch("%S+") do terms[#terms + 1] = term end
    return true
end

function Filter.GetQuery() return rawQuery end
function Filter.IsSearching() return #terms > 0 end

-- parts: list of strings (zone, title, objectives...). Unreadable entries are skipped.
function Filter.Matches(parts)
    if #terms == 0 then return true end
    local lowered = {}
    for _, part in ipairs(parts) do
        if CanUse(part) then lowered[#lowered + 1] = part:lower() end
    end
    local haystack = table.concat(lowered, "\n")
    for _, term in ipairs(terms) do
        if not haystack:find(term, 1, true) then return false end
    end
    return true
end

function Filter.GetZoneMode()
    local db = addonTable.db
    local mode = db and db.zoneFilter
    if type(mode) ~= "string" or mode == "" then return "all" end
    return mode
end

function Filter.SetZoneMode(mode)
    if addonTable.db then addonTable.db.zoneFilter = mode or "all" end
end

function Filter.IsActive()
    return #terms > 0 or Filter.GetZoneMode() ~= "all"
end

-- Lower-cased names that count as "here", plus the display name of the zone.
function Filter.GetHereNames()
    local names, display = {}, nil
    local function Add(name)
        if CanUse(name) and name ~= "" then
            names[name:lower()] = true
            display = display or name
        end
    end
    if GetRealZoneText then Add(GetRealZoneText()) end
    if GetZoneText then Add(GetZoneText()) end
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
        local mapID = C_Map.GetBestMapForUnit("player")
        local info = mapID and C_Map.GetMapInfo(mapID)
        if type(info) == "table" then Add(info.name) end
    end
    return names, display or ""
end

function Filter.ZoneMatches(zoneName, hereNames)
    local mode = Filter.GetZoneMode()
    if mode == "all" or mode == "done" then return true end
    if not CanUse(zoneName) then return false end
    local lowered = zoneName:lower()
    if mode == "here" then return hereNames ~= nil and hereNames[lowered] == true end
    return lowered == mode:lower()
end
