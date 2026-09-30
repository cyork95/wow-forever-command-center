local _, ns = ...

local C = ns.constants
local U = ns.utils

local Biography = {}

local DUPLICATE_WINDOW_SECONDS = 5
local LOGIN_READ_DELAY_SECONDS = 3
local LOGIN_ZONE_RETRIES = 7
local ZONE_MAP_TYPE = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3

Biography.KIND = {
    LOGIN = "login",
    LEVEL = "level",
    DEATH = "death",
    ZONE = "zone",
    QUEST = "quest",
    ACHIEVEMENT = "achievement",
    PROFESSION = "profession",
    SCREENSHOT = "screenshot",
    BOSS = "boss",
}

local sessionZones = {}
local loginPending = false
local pendingQuestTitles = {}
local listeners = {}

local eventFrame = CreateFrame("Frame")

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end

    return pcall(fn, ...)
end

local function SafeText(value)
    local text = U.Trim(U.SafeString(value, ""))

    if text == "" then
        return nil
    end

    return text
end

local function Now()
    local success, timestamp = SafeCall(time)

    if success and type(timestamp) == "number" then
        return timestamp
    end

    return 0
end

local function GetStore()
    local db = ns.state and ns.state.db

    if type(db) ~= "table" then
        return nil
    end

    if type(db.biography) ~= "table" then
        db.biography = {}
    end

    if type(db.biographyState) ~= "table" then
        db.biographyState = {}
    end

    if type(db.biographyState.professions) ~= "table" then
        db.biographyState.professions = {}
    end

    if type(db.biographyState.encounters) ~= "table" then
        db.biographyState.encounters = {}
    end

    return db.biography, db.biographyState
end

local function GetMapZone()
    if not C_Map
        or type(C_Map.GetBestMapForUnit) ~= "function"
        or type(C_Map.GetMapInfo) ~= "function"
    then
        return nil
    end

    local success, mapID = SafeCall(C_Map.GetBestMapForUnit, "player")

    if not success or not mapID then
        return nil
    end

    -- Dungeon and micro maps sit below the zone; continents and the world sit above it.
    for _ = 1, 8 do
        local infoSuccess, info = SafeCall(C_Map.GetMapInfo, mapID)

        if not infoSuccess or type(info) ~= "table" then
            return nil
        end

        local mapType = U.ToSafeNumber(info.mapType)

        if mapType == nil or mapType == ZONE_MAP_TYPE then
            return SafeText(info.name)
        elseif mapType < ZONE_MAP_TYPE then
            return nil
        end

        mapID = U.ToSafeNumber(info.parentMapID)

        if not mapID or mapID == 0 then
            return nil
        end
    end

    return nil
end

local function ReadZoneText()
    local success, zone = SafeCall(GetRealZoneText)

    if success and SafeText(zone) then
        return SafeText(zone)
    end

    success, zone = SafeCall(GetZoneText)

    if success and SafeText(zone) then
        return SafeText(zone)
    end

    return nil
end

local function GetZone()
    return ReadZoneText() or GetMapZone()
end

local function GetSubZone()
    local success, subzone = SafeCall(GetSubZoneText)

    if success then
        return SafeText(subzone)
    end

    return nil
end

local function GetLevel()
    local success, level = SafeCall(UnitLevel, "player")

    if success then
        return U.ToSafeNumber(level)
    end

    return nil
end

local function Notify()
    for _, callback in ipairs(listeners) do
        pcall(callback)
    end
end

local function IsDuplicate(last, kind, text, zone, timestamp)
    -- The scan matches each screenshot file to its own event, so none are merged.
    if kind == Biography.KIND.SCREENSHOT then
        return false
    end

    return type(last) == "table"
        and last.kind == kind
        and last.text == text
        and last.zone == zone
        and math.abs(timestamp - (last.t or 0)) <= DUPLICATE_WINDOW_SECONDS
end

function Biography:Record(kind, text, extra)
    local events = GetStore()

    if not events or not SafeText(text) or not ns:IsFeatureOn("biography") then
        return nil
    end

    local timestamp = Now()
    local zone = extra and extra.zone or GetZone()

    if IsDuplicate(events[#events], kind, text, zone, timestamp) then
        return nil
    end

    local entry = {
        t = timestamp,
        kind = kind,
        text = text,
        zone = zone,
        level = GetLevel(),
    }

    if type(extra) == "table" then
        for key, value in pairs(extra) do
            if key ~= "t" and key ~= "kind" and key ~= "text" then
                entry[key] = value
            end
        end
    end

    table.insert(events, entry)
    Notify()

    return entry
end

function Biography:GetEvents()
    local events = GetStore()

    return events or {}
end

function Biography:GetCount()
    return #self:GetEvents()
end

function Biography:OnChanged(callback)
    if type(callback) == "function" then
        table.insert(listeners, callback)
    end
end

function Biography:FormatDate(timestamp)
    local success, text = SafeCall(date, "%Y-%m-%d", timestamp or 0)

    if success and type(text) == "string" then
        return text
    end

    return "Unknown date"
end

function Biography:FormatTime(timestamp)
    local success, text = SafeCall(date, "%H:%M", timestamp or 0)

    if success and type(text) == "string" then
        return text
    end

    return "--:--"
end

local function RecordLogin()
    local _, state = GetStore()

    if not state then
        return
    end

    local level = GetLevel()
    local zone = GetZone()

    if zone then
        sessionZones[zone] = true
    end

    if state.lastLevel == nil and state.lastZone == nil then
        Biography:Record(
            Biography.KIND.LOGIN,
            string.format(
                "Biography started at level %s in %s",
                tostring(level or "?"),
                zone or "an unknown zone"
            )
        )
    elseif state.lastLevel ~= level or state.lastZone ~= zone then
        Biography:Record(
            Biography.KIND.LOGIN,
            string.format(
                "Logged in at level %s in %s",
                tostring(level or "?"),
                zone or "an unknown zone"
            )
        )
    end

    state.lastLevel = level
    state.lastZone = zone
end

local function RecordLevelUp(newLevel)
    local _, state = GetStore()
    local level = U.ToSafeNumber(newLevel) or GetLevel()
    local zone = GetZone()

    Biography:Record(
        Biography.KIND.LEVEL,
        string.format(
            "Reached level %s in %s",
            tostring(level or "?"),
            zone or "an unknown zone"
        ),
        { level = level }
    )

    if state then
        state.lastLevel = level
    end
end

local function RecordDeath()
    local zone = GetZone()
    local subzone = GetSubZone()
    local text

    if subzone and zone and subzone ~= zone then
        text = string.format("Died at %s in %s", subzone, zone)
    else
        text = string.format("Died in %s", zone or "an unknown zone")
    end

    Biography:Record(Biography.KIND.DEATH, text)
end

local function RecordZone()
    local _, state = GetStore()
    local zone = GetZone()

    if not zone or loginPending then
        return
    end

    if state then
        state.lastZone = zone
    end

    if sessionZones[zone] then
        return
    end

    sessionZones[zone] = true

    Biography:Record(
        Biography.KIND.ZONE,
        string.format("Entered %s", zone)
    )
end

local function GetQuestTitle(questID)
    if not questID then
        return nil
    end

    if C_QuestLog
        and type(C_QuestLog.GetTitleForQuestID) == "function"
    then
        local success, title =
            SafeCall(C_QuestLog.GetTitleForQuestID, questID)

        if success and SafeText(title) then
            return SafeText(title)
        end
    end

    return nil
end

local function QuestPlaceholder(questID)
    return string.format("Turned in quest %s", tostring(questID))
end

local function RecordQuestTurnIn(questID)
    questID = U.ToSafeNumber(questID)

    if not questID then
        return
    end

    local title = GetQuestTitle(questID)

    if title then
        Biography:Record(
            Biography.KIND.QUEST,
            string.format("Turned in %s", title),
            { questID = questID }
        )

        return
    end

    Biography:Record(
        Biography.KIND.QUEST,
        QuestPlaceholder(questID),
        { questID = questID }
    )

    pendingQuestTitles[questID] = true

    if C_QuestLog
        and type(C_QuestLog.RequestLoadQuestByID) == "function"
    then
        SafeCall(C_QuestLog.RequestLoadQuestByID, questID)
    end
end

local function ResolvePendingQuestTitle(questID)
    questID = U.ToSafeNumber(questID)

    if not questID or not pendingQuestTitles[questID] then
        return
    end

    local title = GetQuestTitle(questID)

    if not title then
        return
    end

    pendingQuestTitles[questID] = nil

    local placeholder = QuestPlaceholder(questID)

    for _, entry in ipairs(Biography:GetEvents()) do
        if entry.questID == questID and entry.text == placeholder then
            entry.text = string.format("Turned in %s", title)
        end
    end

    Notify()
end

local function RecordAchievement(achievementID)
    achievementID = U.ToSafeNumber(achievementID)

    if not achievementID or type(GetAchievementInfo) ~= "function" then
        return
    end

    local success, _, name = SafeCall(GetAchievementInfo, achievementID)

    if not success or not SafeText(name) then
        return
    end

    Biography:Record(
        Biography.KIND.ACHIEVEMENT,
        string.format("Earned the achievement %s", SafeText(name)),
        { achievementID = achievementID }
    )
end

local function ReadProfessionRanks()
    local ranks = {}

    if type(GetProfessions) ~= "function"
        or type(GetProfessionInfo) ~= "function"
    then
        return ranks
    end

    local indexes = { SafeCall(GetProfessions) }

    if not indexes[1] then
        return ranks
    end

    for position = 2, 6 do
        local professionIndex = indexes[position]

        if professionIndex then
            local success, name, _, rank =
                SafeCall(GetProfessionInfo, professionIndex)

            rank = U.ToSafeNumber(rank)

            if success and SafeText(name) and rank then
                ranks[SafeText(name)] = rank
            end
        end
    end

    return ranks
end

local function RecordProfessionChanges()
    local events, state = GetStore()

    if not state then
        return
    end

    local known = state.professions
    local seeded = state.professionsSeeded == true

    for name, rank in pairs(ReadProfessionRanks()) do
        local previous = known[name]

        if previous == nil then
            if seeded then
                Biography:Record(
                    Biography.KIND.PROFESSION,
                    string.format("Learned %s", name),
                    { profession = name, rank = rank }
                )
            end
        elseif rank > previous then
            local last = events[#events]

            if type(last) == "table"
                and last.kind == Biography.KIND.PROFESSION
                and last.profession == name
                and last.rank ~= nil
                and last.fromRank ~= nil
            then
                last.rank = rank
                last.text = string.format(
                    "%s rose from %d to %d",
                    name,
                    last.fromRank,
                    rank
                )
                Notify()
            else
                Biography:Record(
                    Biography.KIND.PROFESSION,
                    string.format("%s rose from %d to %d", name, previous, rank),
                    { profession = name, fromRank = previous, rank = rank }
                )
            end
        end

        known[name] = rank
    end

    state.professionsSeeded = true
end

local function RecordScreenshot()
    local zone = GetZone()
    local subzone = GetSubZone()
    local place = zone or "an unknown zone"

    if subzone and zone and subzone ~= zone then
        place = string.format("%s, %s", subzone, zone)
    end

    local screenshotter = ns.Data and ns.Data.Screenshotter
    local reason = screenshotter and screenshotter:ConsumeReason()

    if reason then
        Biography:Record(
            Biography.KIND.SCREENSHOT,
            string.format("Screenshot: %s, in %s", reason, place),
            { reason = reason }
        )
        return
    end

    Biography:Record(
        Biography.KIND.SCREENSHOT,
        string.format("Screenshot saved in %s", place)
    )
end

local function DifficultyName(difficultyID)
    if type(GetDifficultyInfo) ~= "function" or not difficultyID then
        return nil
    end

    local success, name = SafeCall(GetDifficultyInfo, difficultyID)

    if success then
        return SafeText(name)
    end

    return nil
end

local function RecordEncounterEnd(encounterID, encounterName, difficultyID, _, killed)
    encounterID = U.ToSafeNumber(encounterID)
    encounterName = SafeText(encounterName)

    if not encounterID or not encounterName then
        return
    end

    local _, state = GetStore()

    if state then
        state.encounters[encounterID] = encounterName
    end

    if U.ToSafeNumber(killed) ~= 1 then
        return
    end

    local text = "Defeated " .. encounterName
    local difficulty = DifficultyName(U.ToSafeNumber(difficultyID))

    if difficulty then
        text = string.format("%s (%s)", text, difficulty)
    end

    Biography:Record(Biography.KIND.BOSS, text, {
        encounterID = encounterID,
        difficultyID = U.ToSafeNumber(difficultyID),
    })
end

function Biography:GetEncounterName(encounterID)
    local _, state = GetStore()
    local id = U.ToSafeNumber(encounterID)

    if not state or not id then
        return nil
    end

    return state.encounters[id]
end

local function After(seconds, callback)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(seconds, function()
            pcall(callback)
        end)
    else
        pcall(callback)
    end
end

local function OnEvent(_, event, arg1, arg2, ...)
    if not ns:IsFeatureOn("biography") then
        return
    end

    if event == "ENCOUNTER_END" then
        RecordEncounterEnd(arg1, arg2, ...)
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        if arg1 == true or arg2 == true then
            loginPending = true

            local attempts = 0

            local function TryLogin()
                attempts = attempts + 1

                if not ReadZoneText() and attempts <= LOGIN_ZONE_RETRIES then
                    After(1, TryLogin)
                    return
                end

                loginPending = false
                RecordLogin()
                RecordProfessionChanges()
            end

            After(LOGIN_READ_DELAY_SECONDS, TryLogin)
        else
            After(1, RecordZone)
        end

        return
    end

    if event == "PLAYER_LEVEL_UP" then
        RecordLevelUp(arg1)
        return
    end

    if event == "PLAYER_DEAD" then
        RecordDeath()
        return
    end

    if event == "ZONE_CHANGED_NEW_AREA" then
        RecordZone()
        return
    end

    if event == "QUEST_TURNED_IN" then
        RecordQuestTurnIn(arg1)
        return
    end

    if event == "QUEST_DATA_LOAD_RESULT" then
        ResolvePendingQuestTitle(arg1)
        return
    end

    if event == "ACHIEVEMENT_EARNED" then
        RecordAchievement(arg1)
        return
    end

    if event == "SCREENSHOT_SUCCEEDED" then
        RecordScreenshot()
        return
    end

    if event == "SKILL_LINES_CHANGED"
        or event == "TRADE_SKILL_LIST_UPDATE"
    then
        RecordProfessionChanges()
    end
end

local registeredEvents = {}

local function RegisterEventIfAvailable(eventName)
    local success = pcall(
        eventFrame.RegisterEvent,
        eventFrame,
        eventName
    )

    if success then
        table.insert(registeredEvents, eventName)
    end

    return success == true
end

function Biography:SetFeatureActive(on, loading)
    ns.Features.SetEvents(eventFrame, registeredEvents, on)
    loginPending = false

    if not loading then
        Notify()
    end
end

RegisterEventIfAvailable("PLAYER_ENTERING_WORLD")
RegisterEventIfAvailable("PLAYER_LEVEL_UP")
RegisterEventIfAvailable("PLAYER_DEAD")
RegisterEventIfAvailable("ZONE_CHANGED_NEW_AREA")
RegisterEventIfAvailable("QUEST_TURNED_IN")
RegisterEventIfAvailable("QUEST_DATA_LOAD_RESULT")
RegisterEventIfAvailable("ACHIEVEMENT_EARNED")
RegisterEventIfAvailable("SCREENSHOT_SUCCEEDED")
RegisterEventIfAvailable("SKILL_LINES_CHANGED")
RegisterEventIfAvailable("TRADE_SKILL_LIST_UPDATE")
RegisterEventIfAvailable("ENCOUNTER_END")

eventFrame:SetScript("OnEvent", OnEvent)

function Biography:Collect()
    local entries = {}

    for index, entry in ipairs(self:GetEvents()) do
        entries[index] = entry
    end

    return {
        key = C.SECTIONS.BIOGRAPHY,
        title = C.SECTION_LABELS[C.SECTIONS.BIOGRAPHY],
        count = #entries,
        entries = entries,
    }
end

ns:RegisterModule(
    "Data.Biography",
    Biography
)

ns.Data = ns.Data or {}
ns.Data.Biography = Biography
