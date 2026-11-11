local _, addonTable = ...
if addonTable.disabledByEllesmere then return end

-- Keyed, coalescing work queue. Timers defer execution; they do not make it
-- secure. Every batch and every individual job rechecks combat lockdown.
local Deferred = {}
addonTable.Deferred = Deferred

function Deferred.New(reportError)
    local jobs, order = {}, {}
    local head, generation, scheduled = 1, 0, false
    local frame = CreateFrame("Frame")
    local queue = {}
    local schedule

    local function report(err)
        if reportError then reportError(err) end
    end

    function queue.Cancel(key)
        jobs[key] = nil
    end

    function queue.Clear()
        jobs, order, head = {}, {}, 1
        generation, scheduled = generation + 1, false
        frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end

    function queue.Flush()
        if InCombatLockdown() then
            frame:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        local batchGeneration = generation
        local scanned = 0
        while head <= #order and scanned < 4 do
            if InCombatLockdown() then break end
            local entry = order[head]
            head, scanned = head + 1, scanned + 1
            if jobs[entry.key] == entry then
                jobs[entry.key] = nil -- re-queueing the same key creates a new request
                local valid = true
                if entry.valid then
                    local ok, result = pcall(entry.valid)
                    valid = ok and result == true
                    if not ok then report(result) end
                end
                if valid then
                    local ok, err = pcall(entry.func)
                    if not ok then report(err) end
                end
                -- A disable/settings callback can clear the queue mid-batch.
                if generation ~= batchGeneration then return end
            end
        end
        if head > #order then
            order, head = {}, 1
            frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        else
            schedule()
        end
    end

    schedule = function()
        if scheduled then return end
        if InCombatLockdown() then
            frame:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        scheduled = true
        local stamp = generation
        C_Timer.After(0.05, function()
            if stamp ~= generation then return end
            scheduled = false
            queue.Flush()
        end)
    end

    function queue.Put(key, func, valid)
        local entry = jobs[key]
        if entry then
            entry.func, entry.valid = func, valid
        else
            entry = { key = key, func = func, valid = valid }
            jobs[key] = entry
            order[#order + 1] = entry
        end
        schedule()
    end

    frame:SetScript("OnEvent", function()
        frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        schedule()
    end)
    return queue
end
