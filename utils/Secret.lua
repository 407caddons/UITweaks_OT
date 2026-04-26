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
        if part == nil or not Secret.CanAccessValue(part) then
            return fallback
        end
        parts[i] = tostring(part)
    end
    return table.concat(parts)
end
