local _, addonTable = ...

-- Retired compatibility stub. Deliberately not listed in the addon's TOC.
--
-- The previous implementation replaced Blizzard map acquisition, shadowed
-- restricted pin methods and rewrote pooled pin scripts. That widened the
-- insecure execution surface instead of establishing a safe taint boundary.
-- In particular, C_Timer.After does not make addon code secure or remove taint
-- from scripts assigned by that code.
--
-- Do not restore these patches to work around a Blizzard tooltip error.
-- Diagnose a fresh error on the exact client build and narrow the originating
-- addon interaction first. Keep Apply as a no-op for any old callers.

local MapTaintGuard = {}
addonTable.MapTaintGuard = MapTaintGuard

function MapTaintGuard.Apply()
    -- Intentionally does not touch WorldMapFrame, BattlefieldMapFrame or pins.
end
