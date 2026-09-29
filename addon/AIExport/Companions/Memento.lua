local _, ns = ...

local U = ns.utils

local encounterNames = nil

-- Memento keys kills by the ENCOUNTER_END id, so names come from a reverse scan of
-- the Encounter Journal. Skipped while the journal is open so its page is not moved.
local function BuildEncounterNames(H)
    if encounterNames then
        return encounterNames
    end

    if type(EJ_GetInstanceByIndex) ~= "function"
        or type(EJ_SelectInstance) ~= "function"
        or type(EJ_GetEncounterInfoByIndex) ~= "function"
    then
        encounterNames = {}
        return encounterNames
    end

    if EncounterJournal and EncounterJournal.IsShown and EncounterJournal:IsShown() then
        return {}
    end

    local names = {}
    local tierCount = 1
    local originalTier = nil

    if type(EJ_GetNumTiers) == "function" then
        local ok, count = pcall(EJ_GetNumTiers)
        tierCount = ok and U.ToSafeNumber(count) or 1
    end

    if type(EJ_GetCurrentTier) == "function" then
        local ok, tier = pcall(EJ_GetCurrentTier)
        originalTier = ok and tier or nil
    end

    for tier = 1, tierCount do
        H.SafeCall(EJ_SelectTier, tier)

        for _, isRaid in ipairs({ false, true }) do
            for instanceIndex = 1, 200 do
                local ok, instanceID, instanceName = pcall(EJ_GetInstanceByIndex, instanceIndex, isRaid)

                if not ok or not instanceID then
                    break
                end

                pcall(EJ_SelectInstance, instanceID)

                for encounterIndex = 1, 40 do
                    local found, name, _, _, _, _, _, dungeonEncounterID =
                        pcall(EJ_GetEncounterInfoByIndex, encounterIndex, instanceID)

                    if not found or not name then
                        break
                    end

                    if dungeonEncounterID then
                        names[dungeonEncounterID] = { name = name, instance = instanceName }
                    end
                end
            end
        end
    end

    if originalTier then
        H.SafeCall(EJ_SelectTier, originalTier)
    end

    encounterNames = names

    return names
end

local function DifficultyName(H, difficultyID)
    local ok, name = H.SafeCall(GetDifficultyInfo, difficultyID)

    if ok and type(name) == "string" and name ~= "" then
        return name
    end

    return "Difficulty " .. tostring(difficultyID)
end

ns.Companions:Register({
    id = "memento",
    title = "Memento",
    addons = { "Memento" },
    adds = "Boss kills Memento recorded. Its screenshots also appear in your Biography.",
    Collect = function(_, H)
        local kills = Memento_DataBossKill

        if type(kills) ~= "table" then
            error("Memento_DataBossKill missing")
        end

        local names = BuildEncounterNames(H)
        local biography = ns.Data and ns.Data.Biography
        local rows = {}

        for difficultyKey, encounters in pairs(kills) do
            local difficultyID = tonumber(string.match(tostring(difficultyKey), "^D(%d+)$") or "")

            if type(encounters) == "table" then
                for encounterID in pairs(encounters) do
                    local known = names[encounterID]
                    local seenName = biography and biography:GetEncounterName(encounterID)
                    local text = (known and known.name)
                        or seenName
                        or ("Boss " .. tostring(encounterID) .. ", name not seen yet")

                    local details = {}

                    if known and known.instance then
                        table.insert(details, known.instance)
                    end

                    if difficultyID then
                        table.insert(details, DifficultyName(H, difficultyID))
                    end

                    if #details > 0 then
                        text = text .. " (" .. table.concat(details, ", ") .. ")"
                    end

                    table.insert(rows, "  " .. text)
                end
            end
        end

        table.sort(rows)

        local lines = {
            string.format("Boss kills recorded: %d", #rows),
        }

        for _, row in ipairs(rows) do
            table.insert(lines, row)
        end

        return lines
    end,
})
