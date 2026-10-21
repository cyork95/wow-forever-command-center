local _, ns = ...

local U = ns.utils
local C = ns.constants

-- Reads Questie's journey from its runtime table. Questie keeps one journey
-- per character in Questie.db.char.journey (AceDB "char" is this character
-- only), so other characters never leak into an export. Questie's SavedVariables
-- file itself cannot be read by another addon; this table can, the same way the
-- other companions read their addon's globals. QuestieDB is module-local inside
-- Questie, so quest names resolve through the game's own quest APIs and fall
-- back to "Quest <id>", the same form the site uses for unknown quests.
local function JourneyTable()
    if type(Questie) ~= "table" then
        return nil
    end

    local db = Questie.db

    if type(db) ~= "table" or type(db.char) ~= "table" then
        return nil
    end

    if type(db.char.journey) ~= "table" then
        return nil
    end

    return db.char.journey
end

local function ResolveQuestTitle(questID, H)
    if U.ToSafeNumber(questID) == nil then
        return nil
    end

    if C_QuestLog and type(C_QuestLog.GetTitleForQuestID) == "function" then
        local ok, title = H.SafeCall(C_QuestLog.GetTitleForQuestID, questID)

        if ok and U.IsNonEmptyString(title) then
            return title
        end
    end

    if C_TaskQuest and type(C_TaskQuest.GetQuestInfoByQuestID) == "function" then
        local ok, title = H.SafeCall(C_TaskQuest.GetQuestInfoByQuestID, questID)

        if ok and U.IsNonEmptyString(title) then
            return title
        end
    end

    return nil
end

local function ReadJourneyEntries(H)
    local journey = JourneyTable()

    if journey == nil then
        return nil
    end

    local events = {}
    local counts = {
        events = 0,
        accepts = 0,
        completes = 0,
        abandons = 0,
        levelUps = 0,
        notes = 0,
    }

    for _, entry in ipairs(journey) do
        if type(entry) == "table" then
            local event = entry.Event
            local subType = entry.SubType
            local questID = U.ToSafeNumber(entry.Quest)
            local timestamp = U.ToSafeNumber(entry.Timestamp)
            local row = nil

            if event == "Quest" and questID ~= nil then
                if subType == "Accept" then
                    counts.accepts = counts.accepts + 1
                elseif subType == "Complete" then
                    counts.completes = counts.completes + 1
                elseif subType == "Abandon" then
                    counts.abandons = counts.abandons + 1
                end

                row = {
                    event = "Quest",
                    subType = subType,
                    quest = questID,
                    title = ResolveQuestTitle(questID, H),
                    level = U.ToSafeNumber(entry.Level),
                    timestamp = timestamp,
                    date = H.FormatDate(timestamp),
                }
            elseif event == "Level" and U.ToSafeNumber(entry.NewLevel) ~= nil then
                counts.levelUps = counts.levelUps + 1

                row = {
                    event = "Level",
                    newLevel = U.ToSafeNumber(entry.NewLevel),
                    timestamp = timestamp,
                    date = H.FormatDate(timestamp),
                }
            elseif event == "Note" then
                counts.notes = counts.notes + 1

                row = {
                    event = "Note",
                    title = U.IsNonEmptyString(entry.Title) and entry.Title or nil,
                    timestamp = timestamp,
                    date = H.FormatDate(timestamp),
                }
            end

            if row ~= nil then
                counts.events = counts.events + 1
                table.insert(events, row)
            end
        end
    end

    local limit = C.QUEST_HISTORY_EXPORT_LIMIT or 300
    local omitted = 0

    if #events > limit then
        omitted = #events - limit
        local recent = {}

        for index = omitted + 1, #events do
            table.insert(recent, events[index])
        end

        events = recent
    end

    return {
        events = events,
        counts = counts,
        omitted = omitted,
        limit = limit,
    }
end

local function SummaryLines(data)
    local lines = {}

    if type(data) ~= "table" then
        return lines
    end

    local counts = data.counts or {}

    if (counts.events or 0) == 0 then
        return lines
    end

    table.insert(lines, string.format(
        "Quest history: %d journey events (%d accepted, %d completed, %d abandoned, %d level-ups)",
        counts.events or 0,
        counts.accepts or 0,
        counts.completes or 0,
        counts.abandons or 0,
        counts.levelUps or 0
    ))

    return lines
end

ns.Companions:Register({
    id = "questie",
    title = "Questie",
    addons = { "Questie" },
    adds = "Quest history from Questie's journey: accepts, completions, abandonments, and level-ups for this character.",

    ReadJourney = function(_, H)
        return ReadJourneyEntries(H)
    end,

    Collect = function(_, H)
        return SummaryLines(ReadJourneyEntries(H))
    end,
})
