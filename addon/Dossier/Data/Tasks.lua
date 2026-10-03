local _, ns = ...

local Tasks = {}

Tasks.refusedEvents = {}

local function Account()
    return ns.Account
end

local function Bucket()
    return Account().Bucket("tasks")
end

local function CharacterRow()
    local bucket = Bucket()
    local key = Account().CharacterKey()

    if not bucket or not key then
        return nil, nil
    end

    if type(bucket[key]) ~= "table" then
        bucket[key] = { items = {} }
    end

    bucket[key].items = type(bucket[key].items) == "table" and bucket[key].items or {}

    return bucket[key], key
end

function Tasks:CharacterKeys()
    local keys = Account().Keys(Bucket())
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

local function ResetAt(repeatKind)
    local now = Account().Now()

    if repeatKind == "daily" and type(GetQuestResetTime) == "function" then
        local ok, seconds = pcall(GetQuestResetTime)

        if ok and type(seconds) == "number" then
            return now + seconds
        end
    end

    if repeatKind == "weekly" and C_DateAndTime and type(C_DateAndTime.GetSecondsUntilWeeklyReset) == "function" then
        local ok, seconds = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)

        if ok and type(seconds) == "number" then
            return now + seconds
        end
    end

    if repeatKind == "weekly" then
        return now + (7 * 86400)
    end

    if repeatKind == "daily" then
        return now + 86400
    end

    return nil
end

local function IsOpen(task)
    if task.repeatKind == "once" then
        return task.doneUntil == nil
    end

    return not task.doneUntil or Account().Now() >= task.doneUntil
end

function Tasks:Add(name, repeatKind, zone, kind)
    local row = CharacterRow()

    if not row or type(name) ~= "string" or name == "" then
        return
    end

    table.insert(row.items, {
        name = name,
        repeatKind = repeatKind or "once",
        zone = zone,
        kind = kind or "task",
        doneUntil = nil,
    })
end

function Tasks:Remove(index, key)
    local bucket = Bucket()
    local row = bucket and bucket[key or Account().CharacterKey()]

    if row and row.items[index] then
        table.remove(row.items, index)
    end
end

function Tasks:CompleteMatching(name, questID)
    local row = CharacterRow()

    if not row then
        return
    end

    for _, task in ipairs(row.items) do
        local sameName = type(name) == "string" and string.lower(task.name or "") == string.lower(name)
        local sameQuest = questID and tonumber(task.questID) == tonumber(questID)

        if (sameName or sameQuest) and IsOpen(task) then
            task.doneUntil = task.repeatKind == "once" and -1 or ResetAt(task.repeatKind)
        end
    end
end

function Tasks:Open(key)
    local keys = key and key ~= "all" and { key } or self:CharacterKeys()
    local rows = {}

    for _, character in ipairs(keys) do
        local record = Bucket() and Bucket()[character]

        for index, task in ipairs(record and record.items or {}) do
            if IsOpen(task) then
                table.insert(rows, {
                    character = character,
                    index = index,
                    name = task.name,
                    repeatKind = task.repeatKind,
                    zone = task.zone,
                    kind = task.kind,
                })
            end
        end
    end

    return rows
end

function Tasks:All(key)
    local record = Bucket() and Bucket()[key or Account().CharacterKey()]
    local rows = {}

    for index, task in ipairs(record and record.items or {}) do
        table.insert(rows, {
            index = index,
            name = task.name,
            repeatKind = task.repeatKind,
            zone = task.zone,
            kind = task.kind,
            open = IsOpen(task),
        })
    end

    return rows
end

local eventFrame = CreateFrame("Frame")
local registered = {}

local function Register(event)
    local ok, result = pcall(eventFrame.RegisterEvent, eventFrame, event)

    if ok and result ~= false then
        table.insert(registered, event)
    else
        table.insert(Tasks.refusedEvents, event)
    end
end

function Tasks:SetFeatureActive(on, loading)
    ns.Features.SetEvents(eventFrame, registered, on)

    if not on and not loading then
        local panel = ns.UI and ns.UI.TrackerWindow

        if panel and panel.Hide then
            panel:Hide()
        end
    end
end

eventFrame:SetScript("OnEvent", function(_, event, questID)
    if not ns:IsFeatureOn("tasks") then
        return
    end

    if event == "QUEST_TURNED_IN" then
        local title = nil

        if C_QuestLog and type(C_QuestLog.GetTitleForQuestID) == "function" then
            local ok, name = pcall(C_QuestLog.GetTitleForQuestID, questID)
            title = ok and name or nil
        end

        Tasks:CompleteMatching(title, questID)
    end
end)

Register("QUEST_TURNED_IN")

ns.Data = ns.Data or {}
ns.Data.Tasks = Tasks
ns:RegisterModule("Data.Tasks", Tasks)
