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
        bucket[key] = { items = {}, notes = {} }
    end

    bucket[key].items = type(bucket[key].items) == "table" and bucket[key].items or {}
    bucket[key].notes = type(bucket[key].notes) == "table" and bucket[key].notes or {}

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

    if type(date) == "function" and type(time) == "function" and (repeatKind == "monthly" or repeatKind == "yearly") then
        local ok, clock = pcall(date, "*t", now)

        if ok and type(clock) == "table" then
            local stamp

            if repeatKind == "monthly" then
                local month = clock.month + 1
                local year = clock.year

                if month > 12 then
                    month = 1
                    year = year + 1
                end

                stamp = { year = year, month = month, day = 1, hour = 0, min = 0, sec = 0 }
            else
                stamp = { year = clock.year + 1, month = 1, day = 1, hour = 0, min = 0, sec = 0 }
            end

            local converted, value = pcall(time, stamp)

            if converted and type(value) == "number" then
                return value
            end
        end
    end

    if repeatKind == "monthly" then
        return now + (30 * 86400)
    end

    if repeatKind == "yearly" then
        return now + (365 * 86400)
    end

    return nil
end

local function IsOpen(task)
    if task.repeatKind == "once" then
        return task.doneUntil == nil
    end

    return not task.doneUntil or Account().Now() >= task.doneUntil
end

local function RowFor(key)
    local row, ownKey = CharacterRow()

    if not row then
        return nil
    end

    if not key or key == ownKey then
        return row
    end

    local bucket = Bucket()

    if type(bucket[key]) ~= "table" then
        bucket[key] = { items = {}, notes = {} }
    end

    bucket[key].items = type(bucket[key].items) == "table" and bucket[key].items or {}
    bucket[key].notes = type(bucket[key].notes) == "table" and bucket[key].notes or {}

    return bucket[key]
end

function Tasks:Cadence(task)
    local kind = task and task.repeatKind

    if kind == "weekly" then
        return "Each week"
    end

    if kind == "monthly" then
        return "Each month"
    end

    if kind == "yearly" then
        return "Each year"
    end

    if kind == "once" then
        return "Just once"
    end

    return "Each day"
end

function Tasks:Status(task)
    local kind = task and task.repeatKind
    local open = true

    if task then
        if type(task.open) == "boolean" then
            open = task.open
        else
            open = IsOpen(task)
        end
    end

    if kind == "weekly" then
        return open and "Due this week" or "Done this week"
    end

    if kind == "monthly" then
        return open and "Due this month" or "Done this month"
    end

    if kind == "yearly" then
        return open and "Due this year" or "Done this year"
    end

    if kind == "once" then
        return open and "Still to do" or "Finished"
    end

    return open and "Due today" or "Done today"
end

function Tasks:DoneLabel(task)
    local kind = task and task.repeatKind

    if kind == "weekly" then
        return "Done this week"
    end

    if kind == "monthly" then
        return "Done this month"
    end

    if kind == "yearly" then
        return "Done this year"
    end

    if kind == "once" then
        return "Finished"
    end

    return "Done today"
end

function Tasks:Add(name, repeatKind, zone, kind, key)
    local row = RowFor(key)

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

function Tasks:Update(index, key, name, repeatKind)
    local row = RowFor(key)
    local task = row and row.items[index]

    if not task or type(name) ~= "string" or name == "" then
        return
    end

    task.name = name

    if repeatKind then
        task.repeatKind = repeatKind
    end
end

function Tasks:SetDone(index, key, done)
    local row = RowFor(key)
    local task = row and row.items[index]

    if not task then
        return
    end

    if done then
        task.doneUntil = task.repeatKind == "once" and -1 or ResetAt(task.repeatKind)
    else
        task.doneUntil = nil
    end
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
            character = key or Account().CharacterKey(),
            name = task.name,
            repeatKind = task.repeatKind,
            zone = task.zone,
            kind = task.kind,
            open = IsOpen(task),
        })
    end

    return rows
end

function Tasks:AddNote(title, text, key)
    local row = RowFor(key)

    if not row or type(title) ~= "string" or title == "" then
        return
    end

    table.insert(row.notes, 1, {
        title = title,
        text = type(text) == "string" and text or "",
        time = Account().Now(),
    })
end

function Tasks:UpdateNote(index, title, text, key)
    local row = RowFor(key)
    local note = row and row.notes[index]

    if not note or type(title) ~= "string" or title == "" then
        return
    end

    note.title = title
    note.text = type(text) == "string" and text or ""
end

function Tasks:RemoveNote(index, key)
    local row = RowFor(key)

    if row and row.notes[index] then
        table.remove(row.notes, index)
    end
end

function Tasks:Notes(key)
    local record = Bucket() and Bucket()[key or Account().CharacterKey()]
    local rows = {}

    for index, note in ipairs(record and record.notes or {}) do
        if type(note) == "table" then
            local title = type(note.title) == "string" and note.title or ""
            local text = type(note.text) == "string" and note.text or ""

            if title ~= "" or text ~= "" then
                table.insert(rows, { index = index, title = title, text = text, time = note.time })
            end
        end
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
