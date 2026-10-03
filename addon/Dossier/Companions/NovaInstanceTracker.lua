local _, ns = ...

local U = ns.utils

local RECENT_RUNS = 10

local function IsPlayer(H, name)
    if type(name) ~= "string" then
        return false
    end

    for _, candidate in ipairs(H.PlayerNames()) do
        if candidate == name then
            return true
        end
    end

    return false
end

local function LockoutLines(H, character)
    local lines = {}
    local saved = type(character) == "table" and character.savedInstances

    if type(saved) ~= "table" then
        return lines
    end

    for key, lockout in pairs(saved) do
        if type(lockout) == "table" then
            local name = lockout.name or lockout.instanceName or tostring(key)
            local reset = U.ToSafeNumber(lockout.resetTime)
            local difficulty = lockout.difficultyName

            local text = "  " .. tostring(name)

            if difficulty then
                text = text .. " (" .. tostring(difficulty) .. ")"
            end

            if reset then
                text = text .. ", resets " .. H.FormatDate(reset)
            end

            table.insert(lines, text)
        end
    end

    table.sort(lines)

    return lines
end

local function RunLine(H, run)
    local parts = {
        H.FormatDate(run.enteredTime),
        tostring(run.instanceName or "Unknown instance"),
    }

    local enteredLevel = U.ToSafeNumber(run.enteredLevel)
    local leftLevel = U.ToSafeNumber(run.leftLevel)

    if enteredLevel and leftLevel and leftLevel > enteredLevel then
        table.insert(parts, string.format("level %d to %d", enteredLevel, leftLevel))
    elseif enteredLevel then
        table.insert(parts, "level " .. enteredLevel)
    end

    local entered = U.ToSafeNumber(run.enteredTime)
    local left = U.ToSafeNumber(run.leftTime)

    if entered and left and left >= entered then
        table.insert(parts, H.FormatDuration(left - entered))
    end

    if U.ToSafeNumber(run.mobCount) then
        table.insert(parts, run.mobCount .. " mobs")
    end

    local money = U.ToSafeNumber(run.leftMoney) and U.ToSafeNumber(run.enteredMoney)
        and (run.leftMoney - run.enteredMoney)

    if money and money ~= 0 then
        table.insert(parts, (money > 0 and "+" or "") .. H.FormatMoney(money))
    end

    return "  " .. table.concat(parts, ", ")
end

ns.Companions:Register({
    id = "novainstancetracker",
    title = "Nova Instance Tracker",
    addons = { "NovaInstanceTracker" },
    adds = "Your saved lockouts and your recent instance runs.",
    IsBuiltIn = function()
        if not ns:IsFeatureOn("lockouts") or not ns.Account then
            return false
        end

        local db = ns.Account.Database()
        local key = ns.Account.CharacterKey()
        local row = db and key and type(db.lockouts) == "table" and db.lockouts[key] or nil

        if type(row) ~= "table" then
            return false
        end

        return #(row.saved or {}) > 0 or #(row.runs or {}) > 0
    end,
    Collect = function(_, H)
        local global = H.Get(NITdatabase, "global")

        if type(global) ~= "table" then
            error("NITdatabase.global missing")
        end

        local character = nil
        local runs = {}

        for _, realm in pairs(global) do
            if type(realm) == "table" then
                if not character and type(realm.myChars) == "table" then
                    local key = H.FindCharacterKey(realm.myChars)
                    character = key and realm.myChars[key]
                end

                if type(realm.instances) == "table" then
                    for _, run in pairs(realm.instances) do
                        if type(run) == "table" and IsPlayer(H, run.playerName) then
                            table.insert(runs, run)
                        end
                    end
                end
            end
        end

        if not character and #runs == 0 then
            return {}
        end

        local lines = {}
        local lockouts = LockoutLines(H, character)

        if #lockouts > 0 then
            table.insert(lines, "Lockouts:")

            for _, line in ipairs(lockouts) do
                table.insert(lines, line)
            end
        else
            table.insert(lines, "Lockouts: none saved")
        end

        table.sort(runs, function(a, b)
            return (U.ToSafeNumber(a.enteredTime) or 0) > (U.ToSafeNumber(b.enteredTime) or 0)
        end)

        if #runs > 0 then
            table.insert(lines, string.format("Recent instance runs (%d recorded):", #runs))

            for index = 1, math.min(RECENT_RUNS, #runs) do
                table.insert(lines, RunLine(H, runs[index]))
            end
        else
            table.insert(lines, "Instance runs: none recorded")
        end

        return lines
    end,
})
