local _, ns = ...

local QuestHistory = {}

local function Account()
    return ns.Account
end

local function Bucket()
    return Account().Bucket("questHistory")
end

local function Row(key)
    local bucket = Bucket()

    key = key or Account().CharacterKey()

    if not bucket or not key then
        return nil, nil
    end

    if type(bucket[key]) ~= "table" then
        bucket[key] = { quests = {} }
    end

    bucket[key].quests = type(bucket[key].quests) == "table" and bucket[key].quests or {}

    return bucket[key], key
end

function QuestHistory:CharacterKeys()
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

local function Find(quests, questID)
    for _, quest in ipairs(quests) do
        if tonumber(quest.questID) == tonumber(questID) then
            return quest
        end
    end

    return nil
end

function QuestHistory:Note(questID, title, zone, when)
    if not ns:IsFeatureOn("questhistory") then
        return
    end

    local row = Row()

    if not row or not questID then
        return
    end

    local quest = Find(row.quests, questID)

    if not quest then
        quest = { questID = questID }
        table.insert(row.quests, quest)
    end

    if type(title) == "string" and title ~= "" then
        quest.title = title
    end

    if type(zone) == "string" and zone ~= "" then
        quest.zone = zone
    end

    if when then
        quest.time = when
    end
end

function QuestHistory:SyncCompleted()
    local completed = ns.Data and ns.Data.CompletedQuests

    if not completed or type(completed.Collect) ~= "function" then
        return
    end

    local ok, data = pcall(completed.Collect, completed)

    if not ok or type(data) ~= "table" then
        return
    end

    for _, entry in ipairs(data.entries or {}) do
        if entry.questID and not entry.unresolved then
            self:Note(entry.questID, entry.title, nil, nil)
        elseif entry.questID then
            self:Note(entry.questID, nil, nil, nil)
        end
    end
end

function QuestHistory:BackfillBiography()
    local db = ns.state and ns.state.db
    local events = db and db.biography and db.biography.events

    if type(events) ~= "table" then
        return
    end

    for _, event in ipairs(events) do
        if type(event) == "table" and event.kind == "quest" and event.questID then
            self:Note(event.questID, event.text, event.zone, event.t)
        end
    end
end

local function QuestieZone(questID)
    if type(QuestieDB) ~= "table" or type(QuestieDB.GetQuest) ~= "function" then
        return nil
    end

    local ok, quest = pcall(QuestieDB.GetQuest, questID)

    if not ok or type(quest) ~= "table" then
        return nil
    end

    local zone = quest.zone or quest.Zone

    if type(zone) == "string" and zone ~= "" then
        return zone
    end

    return nil
end

function QuestHistory:List(key, zoneFilter, query)
    local keys = key and key ~= "all" and { key } or self:CharacterKeys()
    local needle = type(query) == "string" and string.lower(query) or ""
    local rows = {}

    for _, character in ipairs(keys) do
        local record = Bucket() and Bucket()[character]

        for _, quest in ipairs(record and record.quests or {}) do
            local zone = quest.zone or QuestieZone(quest.questID) or "Zone unknown"
            local title = quest.title or ("Quest " .. tostring(quest.questID))
            local inZone = not zoneFilter or zoneFilter == "" or zone == zoneFilter
            local matches = needle == "" or string.find(string.lower(title), needle, 1, true)

            if inZone and matches then
                table.insert(rows, {
                    character = character,
                    questID = quest.questID,
                    title = title,
                    zone = zone,
                    time = quest.time,
                })
            end
        end
    end

    table.sort(rows, function(a, b)
        if a.zone ~= b.zone then
            return a.zone < b.zone
        end

        return a.title < b.title
    end)

    return rows
end

local eventFrame = CreateFrame("Frame")

local function OnLogin()
    if not ns:IsFeatureOn("questhistory") then
        return
    end

    QuestHistory:BackfillBiography()
    QuestHistory:SyncCompleted()
end

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        OnLogin()
    end
end)

-- Questie keeps the journey. This list no longer records. Saved rows stay.

function QuestHistory:SetFeatureActive(on)
    if on then
        OnLogin()
    else
        pcall(eventFrame.UnregisterEvent, eventFrame, "PLAYER_LOGIN")
    end
end

function QuestHistory:NoteTurnIn(questID, title, zone, when)
    local tasks = ns.Data and ns.Data.Tasks

    if tasks and ns:IsFeatureOn("tasks") then
        tasks:CompleteMatching(title, questID)
    end

    if not ns:IsFeatureOn("questhistory") then
        return
    end

    self:Note(questID, title, zone or Account().Zone(), when)
end

ns.Data = ns.Data or {}
ns.Data.QuestHistory = QuestHistory
ns:RegisterModule("Data.QuestHistory", QuestHistory)
