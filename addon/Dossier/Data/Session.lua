local _, ns = ...

local C = ns.constants
local U = ns.utils

local Session = {}

Session.refusedEvents = {}

local MIN_RATE_SECONDS = 60
local HISTORY_SIZE = 20
-- A save younger than this at login is a /reload, so the session carries on.
local RESUME_SECONDS = 600

local CLASS_CONSUMABLE = Enum and Enum.ItemClass and Enum.ItemClass.Consumable or 0
local CLASS_TRADEGOODS = Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods or 7
local CLASS_QUEST = Enum and Enum.ItemClass and Enum.ItemClass.Questitem or 12
local CLASS_MISC = Enum and Enum.ItemClass and Enum.ItemClass.Miscellaneous or 15
local MISC = Enum and Enum.ItemMiscellaneousSubclass or {}

-- Same item classes Gathering counts.
Session.CATEGORIES = {
    { key = "herb", class = CLASS_TRADEGOODS, subclasses = { 9 }, default = true },
    { key = "ore", class = CLASS_TRADEGOODS, subclasses = { 7 }, default = true },
    { key = "leather", class = CLASS_TRADEGOODS, subclasses = { 6 }, default = true },
    { key = "cloth", class = CLASS_TRADEGOODS, subclasses = { 5 }, default = true },
    { key = "cooking", class = CLASS_TRADEGOODS, subclasses = { 0, 8 }, default = true },
    { key = "elemental", class = CLASS_TRADEGOODS, subclasses = { 10 }, default = true },
    { key = "enchanting", class = CLASS_TRADEGOODS, subclasses = { 12 }, default = true },
    { key = "jewelcrafting", class = CLASS_TRADEGOODS, subclasses = { 4 }, default = true },
    { key = "reagent", class = CLASS_MISC, subclasses = { MISC.Reagent or 1 }, default = true },
    { key = "holiday", class = CLASS_MISC, subclasses = { MISC.Holiday or 3 }, default = true },
    { key = "consumable", class = CLASS_CONSUMABLE, subclasses = { 1, 2, 3, 4, 5, 6, 7 }, default = true },
    { key = "quest", class = CLASS_QUEST, subclasses = { 0 }, default = false },
}

local CATEGORY_BY_ITEM_CLASS = {}

for _, category in ipairs(Session.CATEGORIES) do
    CATEGORY_BY_ITEM_CLASS[category.class] = CATEGORY_BY_ITEM_CLASS[category.class] or {}

    for _, subclass in ipairs(category.subclasses) do
        CATEGORY_BY_ITEM_CLASS[category.class][subclass] = category.key
    end
end

local state = nil
local listeners = {}
local lootPatterns = nil
local lastMoney = nil
local lastXP = nil
local lastMaxXP = nil
local lastKillCount = 0

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local function Read(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local ok, value = pcall(fn, ...)

    if not ok or IsSecret(value) then
        return nil
    end

    return value
end

local function Clock()
    return Read(GetTime) or Read(time) or 0
end

local function Now()
    return Read(time) or 0
end

local function NewState()
    return {
        status = "idle",
        elapsed = 0,
        runStart = nil,
        startedAt = nil,
        zone = nil,
        items = {},
        gathered = 0,
        byType = {},
        xp = 0,
        levels = 0,
        goldCarried = 0,
        killsCarried = 0,
        startMoney = Read(GetMoney),
    }
end

state = NewState()

local function GetStore()
    local db = ns.state and ns.state.db

    if type(db) ~= "table" then
        return nil
    end

    return Session.FillDefaults(db.session or {}, db)
end

-- Persisted session gold never goes below zero. Live gold can still show a spend.
local function PersistGold(copper)
    copper = math.floor(tonumber(copper) or 0)

    if copper < 0 then
        return 0
    end

    return copper
end

function Session.FillDefaults(store, db)
    if db then
        db.session = store
    end

    store.gathered = type(store.gathered) == "table" and store.gathered or {}
    store.history = type(store.history) == "table" and store.history or {}
    store.categories = type(store.categories) == "table" and store.categories or {}

    for _, category in ipairs(Session.CATEGORIES) do
        if store.categories[category.key] == nil then
            store.categories[category.key] = category.default
        end
    end

    for _, entry in ipairs(store.history) do
        if type(entry) == "table" then
            entry.gold = PersistGold(entry.gold)
        end
    end

    if type(store.current) == "table" then
        store.current.gold = PersistGold(store.current.gold)
    end

    return store
end

local function Notify()
    for _, callback in ipairs(listeners) do
        pcall(callback)
    end
end

function Session:OnChanged(callback)
    if type(callback) == "function" then
        table.insert(listeners, callback)
    end
end

local function ReadZone()
    local zone = Read(GetRealZoneText)

    if U.IsNonEmptyString(zone) then
        return zone
    end

    zone = Read(GetZoneText)

    return U.IsNonEmptyString(zone) and zone or nil
end

local function KillsSession()
    local kills = ns.Data and ns.Data.Kills
    return kills and kills:GetSession() or nil
end

function Session:GetStatus()
    return state.status
end

function Session:IsRunning()
    return state.status == "running"
end

function Session:GetSeconds()
    local seconds = state.elapsed

    if state.status == "running" and state.runStart then
        seconds = seconds + math.max(0, Clock() - state.runStart)
    end

    return seconds
end

local function Start()
    if state.status == "running" then
        return
    end

    state.status = "running"
    state.runStart = Clock()
    state.startedAt = state.startedAt or Now()
    state.zone = state.zone or ReadZone()
end

-- Any activity starts the timer, or resumes it after a pause, as Gathering does.
local function Activity()
    Start()
    Notify()
end

function Session:Start()
    Start()
    Notify()
end

function Session:Pause()
    if state.status ~= "running" then
        return
    end

    state.elapsed = self:GetSeconds()
    state.runStart = nil
    state.status = "paused"
    Notify()
end

function Session:Toggle()
    if state.status == "running" then
        self:Pause()
    else
        self:Start()
    end
end

function Session:GetKills()
    local kills = KillsSession()
    return state.killsCarried + (kills and kills.kills or 0)
end

-- A GetMoney() of 0 while the last real balance was higher is the client unloading
-- on logout, not an empty purse. 0 is truthy in Lua, so it used to be subtracted
-- from the starting wallet and saved as a large negative.
function Session:TrustedMoney()
    local money = Read(GetMoney)

    if money == nil then
        return lastMoney
    end

    if money == 0 and (lastMoney or 0) > 0 then
        return lastMoney
    end

    return money
end

function Session:GetGold()
    local money = self:TrustedMoney()

    if not money or not state.startMoney then
        return state.goldCarried
    end

    return state.goldCarried + money - state.startMoney
end

function Session:HasActivity()
    return state.gathered > 0 or state.xp > 0 or self:GetKills() > 0 or self:GetGold() ~= 0
end

local function PerHour(value, seconds)
    return value * 3600 / math.max(seconds, MIN_RATE_SECONDS)
end

function Session:GetSummary()
    local seconds = self:GetSeconds()
    local kills = self:GetKills()
    local gold = self:GetGold()
    local items = {}
    local byType = {}

    for itemID, item in pairs(state.items) do
        table.insert(items, {
            id = itemID,
            name = item.name,
            type = item.type,
            count = item.count,
            perHour = PerHour(item.count, seconds),
        })
    end

    table.sort(items, function(a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end

        return (a.name or "") < (b.name or "")
    end)

    for key, count in pairs(state.byType) do
        table.insert(byType, { key = key, label = C.SESSION_CATEGORY_LABELS[key] or key, count = count })
    end

    table.sort(byType, function(a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end

        return a.label < b.label
    end)

    local xpPerHour = PerHour(state.xp, seconds)
    local timeToLevel = nil
    local currentXP = Read(UnitXP, "player")
    local maxXP = Read(UnitXPMax, "player")

    if state.xp > 0 and tonumber(currentXP) and tonumber(maxXP) and maxXP > 0 then
        timeToLevel = (maxXP - currentXP) * 3600 / math.max(xpPerHour, 1)
    end

    local killsSession = KillsSession()

    return {
        status = state.status,
        seconds = seconds,
        startedAt = state.startedAt,
        zone = state.zone,
        kills = kills,
        killsPerHour = PerHour(kills, seconds),
        creatures = killsSession and killsSession.creatures or {},
        gathered = state.gathered,
        gatheredPerHour = PerHour(state.gathered, seconds),
        byType = byType,
        items = items,
        gold = gold,
        goldPerHour = PerHour(gold, seconds),
        xp = state.xp,
        xpPerHour = xpPerHour,
        levels = state.levels,
        timeToLevel = timeToLevel,
    }
end

local function HistoryEntry()
    return {
        start = state.startedAt or Now(),
        seconds = math.floor(Session:GetSeconds()),
        zone = state.zone,
        kills = Session:GetKills(),
        gathered = state.gathered,
        gold = PersistGold(Session:GetGold()),
        xp = state.xp,
        levels = state.levels,
    }
end

local function PushHistory(store, entry)
    table.insert(store.history, 1, entry)

    while #store.history > HISTORY_SIZE do
        table.remove(store.history)
    end

    local account = ns.Account
    local key = account and account.CharacterKey()
    local bucket = account and account.Bucket("sessions")

    if bucket and key then
        bucket[key] = type(bucket[key]) == "table" and bucket[key] or {}
        account.Push(bucket[key], entry, 20)
    end
end

function Session:Reset()
    local store = GetStore()

    if store and self:HasActivity() then
        PushHistory(store, HistoryEntry())
    end

    state = NewState()
    lastMoney = state.startMoney

    local kills = ns.Data and ns.Data.Kills

    if kills then
        kills:ResetSession()
    end

    lastKillCount = 0

    if store then
        store.current = nil
    end

    Notify()
end

function Session:GetHistory()
    local store = GetStore()
    return store and store.history or {}
end

function Session:GetLifetime()
    local store = GetStore()
    local items = {}
    local byType = {}
    local total = 0

    for itemID, item in pairs(store and store.gathered or {}) do
        local count = tonumber(item.count) or 0
        total = total + count
        byType[item.type or "other"] = (byType[item.type or "other"] or 0) + count
        table.insert(items, { id = itemID, name = item.name, type = item.type, count = count })
    end

    table.sort(items, function(a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end

        return (a.name or "") < (b.name or "")
    end)

    return { total = total, byType = byType, items = items }
end

function Session:IsCategoryOn(key)
    local store = GetStore()
    return store ~= nil and store.categories[key] == true
end

function Session:SetCategory(key, enabled)
    local store = GetStore()

    if store and store.categories[key] ~= nil then
        store.categories[key] = enabled == true
        Notify()
    end
end

function Session.CategoryFor(classID, subclassID)
    local byClass = CATEGORY_BY_ITEM_CLASS[tonumber(classID)]
    return byClass and byClass[tonumber(subclassID)] or nil
end

local function ItemClass(itemID)
    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        local ok, _, _, _, _, _, classID, subclassID = pcall(C_Item.GetItemInfoInstant, itemID)

        if ok and classID then
            return classID, subclassID
        end
    end

    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo

    if type(getInfo) == "function" then
        local ok, _, _, _, _, _, _, _, _, _, _, _, classID, subclassID = pcall(getInfo, itemID)

        if ok then
            return classID, subclassID
        end
    end

    return nil, nil
end

-- "You receive loot: %sx%d." -> "^You receive loot: (.+)x(%d+)%.$"
local function ToPattern(format)
    local pattern = string.gsub(format, "([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    pattern = string.gsub(pattern, "%%s", "(.+)")
    pattern = string.gsub(pattern, "%%d", "(%%d+)")

    return "^" .. pattern .. "$"
end

local function LootPatterns()
    if lootPatterns then
        return lootPatterns
    end

    local patterns = {}

    for _, name in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF" }) do
        local format = _G[name]

        if type(format) == "string" and not IsSecret(format) then
            table.insert(patterns, ToPattern(format))
        end
    end

    if #patterns > 0 then
        lootPatterns = patterns
    end

    return patterns
end

local function IsShown(frame)
    return frame and type(frame.IsVisible) == "function" and frame:IsVisible() == true
end

function Session.ParseLoot(message)
    if type(message) ~= "string" or IsSecret(message) then
        return nil
    end

    for _, pattern in ipairs(LootPatterns()) do
        local link, quantity = string.match(message, pattern)

        if link then
            local itemID = tonumber(string.match(link, "|Hitem:(%d+)"))

            if itemID then
                return itemID, string.match(link, "%[(.-)%]"), tonumber(quantity) or 1
            end
        end
    end

    return nil
end

local function OnLoot(message)
    if IsShown(InboxFrame) or IsShown(GuildBankFrame) then
        return
    end

    local itemID, name, quantity = Session.ParseLoot(message)

    if not itemID then
        return
    end

    local key = Session.CategoryFor(ItemClass(itemID))

    if not key or not Session:IsCategoryOn(key) then
        return
    end

    Start()

    local seconds = Session:GetSeconds()
    local item = state.items[itemID]

    if not item then
        item = { name = name, type = key, count = 0, first = seconds }
        state.items[itemID] = item
    end

    item.count = item.count + quantity
    item.last = seconds
    state.gathered = state.gathered + quantity
    state.byType[key] = (state.byType[key] or 0) + quantity

    local store = GetStore()

    if store then
        local lifetime = store.gathered[itemID]

        if not lifetime then
            lifetime = { name = name, type = key, count = 0, first = Now() }
            store.gathered[itemID] = lifetime
        end

        lifetime.name = name or lifetime.name
        lifetime.count = lifetime.count + quantity
        lifetime.last = Now()
    end

    Notify()
end

local function OnMoney()
    local money = Read(GetMoney)

    if not money then
        return
    end

    -- Unload reports 0. Keep the last balance so the saved session is not minus the wallet.
    if money == 0 and (lastMoney or 0) > 0 then
        return
    end

    if not state.startMoney then
        state.startMoney = money
    end

    local delta = money - (lastMoney or money)
    lastMoney = money

    if delta == 0 then
        return
    end

    -- Mail and the guild bank move money without earning it.
    if IsShown(InboxFrame) or IsShown(GuildBankFrame) then
        state.startMoney = state.startMoney + delta
        Notify()
        return
    end

    Activity()
end

local function ReadXP()
    return Read(UnitXP, "player"), Read(UnitXPMax, "player")
end

local function OnXP()
    local current, maximum = ReadXP()

    if not tonumber(current) or not tonumber(maximum) then
        return
    end

    local gained = 0

    if lastXP and lastMaxXP then
        if maximum ~= lastMaxXP then
            gained = (lastMaxXP - lastXP) + current
            state.levels = state.levels + 1
        else
            gained = current - lastXP
        end
    end

    lastXP = current
    lastMaxXP = maximum

    if gained > 0 then
        state.xp = state.xp + gained
        Activity()
    end
end

local function OnKillsChanged()
    if not ns:IsFeatureOn("session") then
        return
    end

    local kills = KillsSession()
    local count = kills and kills.kills or 0

    if count > lastKillCount then
        lastKillCount = count
        Activity()
    else
        lastKillCount = count
    end
end

local function SaveCurrent()
    local store = GetStore()

    if not store then
        return
    end

    if not Session:HasActivity() then
        store.current = nil
        return
    end

    store.current = {
        savedAt = Now(),
        wasRunning = state.status == "running",
        seconds = Session:GetSeconds(),
        startedAt = state.startedAt,
        zone = state.zone,
        items = state.items,
        gathered = state.gathered,
        byType = state.byType,
        xp = state.xp,
        levels = state.levels,
        gold = PersistGold(Session:GetGold()),
        kills = Session:GetKills(),
    }
end

local function SavedHistoryEntry(saved)
    return {
        start = saved.startedAt or saved.savedAt,
        seconds = math.floor(tonumber(saved.seconds) or 0),
        zone = saved.zone,
        kills = tonumber(saved.kills) or 0,
        gathered = tonumber(saved.gathered) or 0,
        gold = PersistGold(saved.gold),
        xp = tonumber(saved.xp) or 0,
        levels = tonumber(saved.levels) or 0,
    }
end

local function SavedIsStale(saved)
    return Now() - (tonumber(saved.savedAt) or 0) > RESUME_SECONDS
end

-- A session left behind while this feature was off still belongs in Previous sessions
-- once it is too old to resume. A recent one stays in store.current until the feature is on.
local function ArchiveStaleCurrent()
    local store = GetStore()
    local saved = store and store.current

    if type(saved) ~= "table" or not SavedIsStale(saved) then
        return
    end

    store.current = nil
    PushHistory(store, SavedHistoryEntry(saved))
end

-- After a /reload the session carries on. After a real logout it goes into history.
local function RestoreCurrent()
    local store = GetStore()
    local saved = store and store.current

    if type(saved) ~= "table" then
        return
    end

    store.current = nil

    if SavedIsStale(saved) then
        PushHistory(store, SavedHistoryEntry(saved))
        return
    end

    state.elapsed = tonumber(saved.seconds) or 0
    state.startedAt = saved.startedAt
    state.zone = saved.zone
    state.items = type(saved.items) == "table" and saved.items or {}
    state.gathered = tonumber(saved.gathered) or 0
    state.byType = type(saved.byType) == "table" and saved.byType or {}
    state.xp = tonumber(saved.xp) or 0
    state.levels = tonumber(saved.levels) or 0
    state.goldCarried = tonumber(saved.gold) or 0
    state.killsCarried = tonumber(saved.kills) or 0
    state.status = "paused"

    if saved.wasRunning then
        Start()
    end
end

function Session:Collect()
    return {
        key = C.SECTIONS.SESSIONS,
        title = C.SECTION_LABELS[C.SECTIONS.SESSIONS],
        active = self:HasActivity(),
        summary = self:GetSummary(),
        lifetime = self:GetLifetime(),
        history = self:GetHistory(),
    }
end

function Session.FormatCount(value)
    local text = tostring(math.floor((tonumber(value) or 0) + 0.5))
    local sign = ""

    if string.sub(text, 1, 1) == "-" then
        sign = "-"
        text = string.sub(text, 2)
    end

    return sign .. (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- 5025 -> "01:23:45"
function Session.FormatClock(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60), seconds % 60)
end

-- 5025 -> "1h 23m"; 90 -> "1m"
function Session.FormatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)

    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    end

    return string.format("%dm", math.max(minutes, seconds > 0 and 1 or 0))
end

-- 12000 -> "+1g 20s 0c"
function Session.FormatGold(copper)
    copper = math.floor(tonumber(copper) or 0)
    local helpers = ns.Companions and ns.Companions.helpers
    local text = helpers and helpers.FormatMoney(math.abs(copper)) or tostring(math.abs(copper))

    return (copper < 0 and "-" or "+") .. text
end

local eventFrame = CreateFrame("Frame")
local registeredEvents = {}

local function Register(event)
    local ok, result = pcall(eventFrame.RegisterEvent, eventFrame, event)
    ok = ok and result ~= false

    if ok then
        table.insert(registeredEvents, event)
    else
        table.insert(Session.refusedEvents, event)
    end

    return ok
end

-- Off ends the session into history. On resumes a saved session when one is
-- waiting, and new gold and XP count from now so time spent off is not added.
function Session:SetFeatureActive(on, loading)
    ns.Features.SetEvents(eventFrame, registeredEvents, on)

    if loading then
        if not on then
            ArchiveStaleCurrent()
        end

        return
    end

    if on then
        state.startMoney = Read(GetMoney)
        lastMoney = state.startMoney
        lastXP, lastMaxXP = ReadXP()

        local kills = KillsSession()
        lastKillCount = kills and kills.kills or 0
        RestoreCurrent()
        Notify()
    else
        self:Reset()
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if not ns:IsFeatureOn("session") then
        return
    end

    if event == "CHAT_MSG_LOOT" then
        OnLoot(...)
    elseif event == "PLAYER_MONEY" then
        OnMoney()
    elseif event == "PLAYER_XP_UPDATE" then
        OnXP()
    elseif event == "PLAYER_LOGIN" then
        state.startMoney = Read(GetMoney)
        lastMoney = state.startMoney
        lastXP, lastMaxXP = ReadXP()
        RestoreCurrent()
        Notify()
    elseif event == "PLAYER_LOGOUT" then
        SaveCurrent()
    end
end)

Register("PLAYER_LOGIN")
Register("PLAYER_LOGOUT")
Register("CHAT_MSG_LOOT")
Register("PLAYER_MONEY")
Register("PLAYER_XP_UPDATE")

if ns.Data and ns.Data.Kills then
    ns.Data.Kills:OnChanged(OnKillsChanged)
end

ns:RegisterModule("Data.Session", Session)

ns.Data = ns.Data or {}
ns.Data.Session = Session
