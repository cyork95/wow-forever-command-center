local _, ns = ...

local Runs = {}

local openRun = nil

local function Account()
    return ns.Account
end

local function Row()
    local bucket = Account().Bucket("lockouts")
    local key = Account().CharacterKey()

    if not bucket or not key then
        return nil
    end

    if type(bucket[key]) ~= "table" then
        bucket[key] = { saved = {}, runs = {} }
    end

    bucket[key].saved = type(bucket[key].saved) == "table" and bucket[key].saved or {}
    bucket[key].runs = type(bucket[key].runs) == "table" and bucket[key].runs or {}

    return bucket[key]
end

function Runs:CharacterKeys()
    local keys = Account().Keys(Account().Bucket("lockouts"))
    local mine = Account().CharacterKey()
    local ordered = {}

    if mine then
        table.insert(ordered, mine)
    end

    for _, key in ipairs(keys) do
        if key ~= mine then
            table.insert(ordered, key)
        end
    end

    return ordered
end

function Runs:RefreshSaved()
    if not ns:IsFeatureOn("lockouts") then
        return
    end

    local row = Row()
    local lockouts = ns.Data and ns.Data.Lockouts

    if not row or not lockouts or type(lockouts.Collect) ~= "function" then
        return
    end

    local ok, data = pcall(lockouts.Collect, lockouts, { requestRefresh = false, useCache = true })

    if not ok or type(data) ~= "table" then
        return
    end

    row.saved = {}
    row.savedAt = Account().Now()

    for _, entry in ipairs(data.instances and data.instances.entries or {}) do
        table.insert(row.saved, {
            name = entry.name,
            difficulty = entry.difficultyName,
            progress = entry.encounterProgress,
            encounters = entry.numEncounters,
            resetText = entry.resetText,
        })
    end
end

local function Level()
    if type(UnitLevel) ~= "function" then
        return nil
    end

    local ok, level = pcall(UnitLevel, "player")

    return ok and tonumber(level) or nil
end

local function Money()
    local session = ns.Data and ns.Data.Session

    if session and session.TrustedMoney then
        return session:TrustedMoney()
    end

    if type(GetMoney) ~= "function" then
        return nil
    end

    local ok, money = pcall(GetMoney)

    return ok and tonumber(money) or nil
end

local function KillsNow()
    local kills = ns.Data and ns.Data.Kills
    local session = kills and kills.GetSession and kills:GetSession() or nil

    return session and tonumber(session.kills) or 0
end

function Runs:CheckInstance()
    if not ns:IsFeatureOn("lockouts") or type(IsInInstance) ~= "function" then
        return
    end

    local ok, inside = pcall(IsInInstance)

    if not ok then
        return
    end

    if inside and not openRun then
        local name = type(GetInstanceInfo) == "function" and GetInstanceInfo() or Account().Zone()
        openRun = {
            name = name,
            entered = Account().Now(),
            level = Level(),
            money = Money(),
            kills = KillsNow(),
        }
    elseif openRun and not inside then
        local row = Row()

        if row then
            local leftMoney = Money()
            local gold = nil

            if openRun.money and leftMoney then
                gold = leftMoney - openRun.money
            end

            Account().Push(row.runs, {
                name = openRun.name,
                entered = openRun.entered,
                left = Account().Now(),
                seconds = Account().Now() - (openRun.entered or Account().Now()),
                levelFrom = openRun.level,
                levelTo = Level(),
                gold = gold,
                mobs = math.max(0, KillsNow() - (openRun.kills or 0)),
                character = Account().CharacterKey(),
            }, 50)
        end

        openRun = nil
    end
end

function Runs:ImportNova()
    local row = Row()

    if not row or row.importedFrom or #row.runs > 0 or type(NITdatabase) ~= "table" then
        return
    end

    local global = NITdatabase.global
    local mine = Account().CharacterKey()
    local copied = 0

    if type(global) ~= "table" or not mine then
        return
    end

    for _, realm in pairs(global) do
        if type(realm) == "table" and type(realm.instances) == "table" then
            for _, run in pairs(realm.instances) do
                if type(run) == "table" and run.playerName and string.find(mine, run.playerName, 1, true) then
                    Account().Push(row.runs, {
                        name = run.instanceName,
                        entered = tonumber(run.enteredTime),
                        left = tonumber(run.leftTime),
                        seconds = (tonumber(run.leftTime) or 0) - (tonumber(run.enteredTime) or 0),
                        levelFrom = tonumber(run.enteredLevel),
                        levelTo = tonumber(run.leftLevel),
                        gold = (tonumber(run.leftMoney) or 0) - (tonumber(run.enteredMoney) or 0),
                        mobs = tonumber(run.mobCount),
                        character = mine,
                    }, 50)
                    copied = copied + 1
                end
            end
        end
    end

    if copied > 0 then
        row.importedFrom = "Nova Instance Tracker"
    end
end

function Runs:SavedLines()
    local lines = {}

    for _, key in ipairs(self:CharacterKeys()) do
        local bucket = Account().Bucket("lockouts") or {}
        local record = bucket[key]

        for _, entry in ipairs(record and record.saved or {}) do
            table.insert(lines, {
                character = key,
                name = entry.name or "Instance",
                difficulty = entry.difficulty,
                progress = entry.progress,
                encounters = entry.encounters,
                resetText = entry.resetText,
            })
        end
    end

    table.sort(lines, function(a, b)
        if a.name ~= b.name then
            return a.name < b.name
        end

        return a.character < b.character
    end)

    return lines
end

function Runs:RunLines(key)
    local keys = key and key ~= "all" and { key } or self:CharacterKeys()
    local lines = {}

    for _, character in ipairs(keys) do
        local bucket = Account().Bucket("lockouts") or {}
        local record = bucket[character]

        for _, run in ipairs(record and record.runs or {}) do
            table.insert(lines, run)
        end
    end

    table.sort(lines, function(a, b)
        return (a.entered or 0) > (b.entered or 0)
    end)

    return lines
end

local eventFrame = CreateFrame("Frame")
local registered = {}

local function Register(event)
    local ok, result = pcall(eventFrame.RegisterEvent, eventFrame, event)

    if ok and result ~= false then
        table.insert(registered, event)
    end
end

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "UPDATE_INSTANCE_INFO" or event == "PLAYER_LOGIN" then
        Runs:RefreshSaved()
    end

    if event == "PLAYER_LOGIN" then
        Runs:ImportNova()
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        Runs:CheckInstance()
    end
end)

Register("PLAYER_LOGIN")
Register("UPDATE_INSTANCE_INFO")
Register("PLAYER_ENTERING_WORLD")
Register("ZONE_CHANGED_NEW_AREA")

function Runs:SetFeatureActive(on)
    ns.Features.SetEvents(eventFrame, registered, on)

    if not on then
        return
    end

    Runs:RefreshSaved()
    Runs:ImportNova()
end

ns.Data = ns.Data or {}
ns.Data.Runs = Runs
ns:RegisterModule("Data.Runs", Runs)
