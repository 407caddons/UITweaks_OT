local _, addonTable = ...

-- Centralised helpers for handling secret/tainted values returned by Blizzard
-- secure code paths in TWW 12.0+. Reading a secret value is fine; using it as
-- a table key, comparing it, or concatenating it triggers Lua errors. These
-- helpers validate via the 12.0 globals (canaccessvalue / canaccesssecrets)
-- and silently fall back when the value is poisoned.
--
-- Style: plain functions on addonTable.Secret (matching addonTable.Core.*),
-- no globals, no self-passing.

local Secret = {}
addonTable.Secret = Secret

-- Returns true if the value can be safely used (not secret).
-- Falls through canaccessvalue → issecretvalue → assume-safe so the helper
-- works on classic/older clients too.
function Secret.CanAccessValue(value)
    if canaccessvalue then
        return canaccessvalue(value)
    end
    if issecretvalue then
        return not issecretvalue(value)
    end
    return true
end

-- Returns true if the addon execution context can access secret values at all.
-- (False during a forbidden execution window.)
function Secret.CanAccessSecrets()
    if canaccesssecrets then
        return canaccesssecrets()
    end
    return true
end

-- Copy API data into addon-owned tables. Never compare, stringify or index an
-- inaccessible value; checking only the outer table is not enough. Reject an
-- incomplete snapshot rather than treating a secret completion flag as false.
function Secret.Snapshot(value, seen, depth)
    if not Secret.CanAccessValue(value) then return nil, false end
    local kind = type(value)
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return nil, false end
    elseif kind == "table" then
        depth = depth or 0
        if depth >= 12 then return nil, false end
        seen = seen or {}
        if seen[value] then return nil, false end
        seen[value] = true
        local copy = {}
        for key, entry in pairs(value) do
            if not Secret.CanAccessValue(key) then seen[value] = nil; return nil, false end
            local keyType = type(key)
            if keyType ~= "string" and keyType ~= "number" then seen[value] = nil; return nil, false end
            local result, accessible = Secret.Snapshot(entry, seen, depth + 1)
            if not accessible then seen[value] = nil; return nil, false end
            copy[key] = result
        end
        seen[value] = nil
        return copy, true
    elseif kind ~= "nil" and kind ~= "string" and kind ~= "boolean" then
        return nil, false
    end
    return value, true
end

-- These wrappers are LOCAL to Luna. They never replace a Blizzard global or
-- function. pcall handles unavailable APIs, not taint; Snapshot is the actual
-- value boundary. Missing APIs stay missing so existing capability checks work.
function Secret.WrapQuery(func, fallback)
    if type(func) ~= "function" then return nil end
    return function(...)
        local function capture(...)
            return { n = select("#", ...), ... }
        end
        local ok, result = pcall(function(...) return capture(func(...)) end, ...)
        if not ok then return fallback end
        for i = 1, result.n do
            local value = result[i]
            if not Secret.CanAccessValue(value) then return fallback end
            local copy, accessible
            if type(value) == "table" then
                ok, copy, accessible = pcall(Secret.Snapshot, value)
            else
                copy, accessible = Secret.Snapshot(value)
            end
            if not ok or not accessible then return fallback end
            result[i] = copy
        end
        return unpack(result, 1, result.n)
    end
end

function Secret.QueryAPI(api, fallbacks)
    if not api then return nil end
    local localAPI = {}
    for name, func in pairs(api) do
        if type(func) == "function" and (name:match("^Get") or name:match("^Is")) then
            localAPI[name] = Secret.WrapQuery(func, fallbacks and fallbacks[name])
        else
            localAPI[name] = func
        end
    end
    return localAPI
end

-- Objective arrays can contain one restricted row/quantity alongside readable
-- rows. Preserve indices and copy only accessible fields actually used by Luna,
-- so one secret counter does not freeze every quest objective.
function Secret.QueryRows(func, fields)
    if type(func) ~= "function" then return nil end
    return function(...)
        local ok, result = pcall(function(...)
            local rows = func(...)
            if not Secret.CanAccessValue(rows) or type(rows) ~= "table" then return nil end
            local copy = {}
            for index, row in ipairs(rows) do
                local entry = {}
                if Secret.CanAccessValue(row) and type(row) == "table" then
                    for _, field in ipairs(fields) do
                        local value = row[field]
                        if Secret.CanAccessValue(value) then
                            local kind = type(value)
                            if kind == "string" or kind == "boolean" or kind == "number" then
                                local safe, accessible = Secret.Snapshot(value)
                                if accessible then entry[field] = safe end
                            end
                        end
                    end
                end
                copy[index] = entry
            end
            return copy
        end, ...)
        if ok then return result end
    end
end

-- (name, realm) for unit, or (fallback, nil) if the name itself is secret,
-- or (name, nil) if only the realm is secret.
function Secret.SafeUnitName(unit, fallback)
    local name, realm = UnitName(unit)
    if not Secret.CanAccessValue(name) then
        return fallback, nil
    end
    if not Secret.CanAccessValue(realm) then
        return name, nil
    end
    return name, realm
end

function Secret.SafeUnitNameUnmodified(unit, fallback)
    local name, realm = UnitNameUnmodified(unit)
    if not Secret.CanAccessValue(name) then
        return fallback, nil
    end
    if not Secret.CanAccessValue(realm) then
        return name, nil
    end
    return name, realm
end

-- (localizedClass, englishClass, classID) or (nil, nil, nil) if any is secret.
function Secret.SafeUnitClass(unit)
    local classLocal, classEn, classId = UnitClass(unit)
    if not Secret.CanAccessValue(classLocal)
        or not Secret.CanAccessValue(classEn)
        or not Secret.CanAccessValue(classId) then
        return nil, nil, nil
    end
    return classLocal, classEn, classId
end

function Secret.SafeUnitGUID(unit, fallback)
    local guid = UnitGUID(unit)
    if not Secret.CanAccessValue(guid) then
        return fallback
    end
    return guid
end

-- table.concat over varargs, but bails to fallback if any arg is secret or nil.
-- Use when you'd otherwise write `a .. b .. c` over values that might be tainted.
function Secret.SafeConcat(fallback, ...)
    local count = select("#", ...)
    local parts = {}
    for i = 1, count do
        local part = select(i, ...)
        if not Secret.CanAccessValue(part) or part == nil then
            return fallback
        end
        parts[i] = tostring(part)
    end
    return table.concat(parts)
end
