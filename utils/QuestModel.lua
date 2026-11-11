local _, addonTable = ...
if addonTable.disabledByEllesmere then return end

local QuestModel = {}
addonTable.QuestModel = QuestModel

local fields = { text = "string", finished = "boolean", type = "string",
    numFulfilled = "number", numRequired = "number" }

-- One read per quest per pass. Records and objective tables retain identity;
-- unreadable fields retain their last accessible values, not invented defaults.
function QuestModel.New(query)
    local records, epoch, count = {}, 0, 0
    local model = {}

    function model.BeginPass()
        epoch = epoch + 1
    end

    function model.Clear()
        records, count = {}, 0
        epoch = epoch + 1
    end

    function model.Forget(questID)
        if records[questID] then records[questID], count = nil, count - 1 end
    end

    function model.GetRecord(questID)
        return records[questID]
    end

    function model.GetObjectives(questID)
        if not addonTable.Secret.CanAccessValue(questID) or type(questID) ~= "number" then return nil end
        local record = records[questID]
        if not record then
            -- Bound session caches without deleting records read in this pass.
            if count >= 512 then
                local oldestID, oldestEpoch
                for id, candidate in pairs(records) do
                    if candidate.epoch ~= epoch and (not oldestEpoch or candidate.epoch < oldestEpoch) then
                        oldestID, oldestEpoch = id, candidate.epoch
                    end
                end
                if oldestID then model.Forget(oldestID) end
            end
            record = { questID = questID, objectives = {}, revision = 0 }
            records[questID], count = record, count + 1
        end
        if record.epoch == epoch then return record.loaded and record.objectives or nil end
        record.epoch = epoch
        local rows = query(questID)
        record.readable = rows ~= nil
        if not rows then
            for _, objective in ipairs(record.objectives) do objective.freshCounters = false end
            return record.loaded and record.objectives or nil
        end
        local changed = false
        local reset = #rows ~= #record.objectives
        for index, row in ipairs(rows) do
            local objective = record.objectives[index]
            if not objective then objective = {}; record.objectives[index] = objective end
            -- Do not transfer old completion/counters across a changed list or
            -- a change of objective type. Row identity is native index + type.
            if reset or (row.type and objective.type and row.type ~= objective.type) then
                for field in pairs(fields) do objective[field] = nil end
                changed = true
            end
            for field, expected in pairs(fields) do
                local value = row[field]
                if type(value) == expected and value ~= objective[field] then
                    objective[field], changed = value, true
                end
            end
            -- A retained counter must not override newer readable text progress.
            objective.freshCounters = type(row.numFulfilled) == "number" and type(row.numRequired) == "number"
        end
        for index = #record.objectives, #rows + 1, -1 do record.objectives[index] = nil; changed = true end
        record.loaded = true
        if changed then record.revision = record.revision + 1 end
        return record.objectives
    end

    return model
end
