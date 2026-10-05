local _, ns = ...

local C = ns.constants
local U = ns.utils

local Kills = {}

Kills.source = nil
Kills.refusedEvents = {}

-- A DoT can kill a mob after its nameplate left draw distance, so cached mob
-- details are kept for a while after the plate goes away.
local NAMEPLATE_KEEP_SECONDS = 300
local NAMEPLATE_PRUNE_SECONDS = 60
local RECENT_KILL_SECONDS = 5
local RECENT_LIST_SIZE = 10
local MIN_RATE_SECONDS = 60

local nameplateCache = {}
local countedDeaths = {}
local lastPrune = 0
local lastKillGUID = nil
local lastKillAt = 0
local lootWindowSeen = false
local listeners = {}

local session = {
    start = nil,
    kills = 0,
    gold = 0,
    byMob = {},
    recent = {},
    recentMobs = {},
}

local function Clock()
    if type(GetTime) == "function" then
        local ok, value = pcall(GetTime)

        if ok and type(value) == "number" then
            return value
        end
    end

    return time()
end

local function Now()
    local ok, value = pcall(time)
    return ok and value or 0
end

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

-- Calls a unit API and drops secret or failed results.
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

-- Inside instances the game hides mob identity, and comparing a hidden GUID is
-- an error pcall cannot catch, so every handler bails out before touching one.
local function InInstance()
    if type(IsInInstance) ~= "function" then
        return false
    end

    local ok, inInstance, kind = pcall(IsInInstance)

    if not ok then
        return true
    end

    return inInstance == true or (kind ~= nil and kind ~= "none")
end

function Kills.GetMobID(guid)
    if type(guid) ~= "string" or IsSecret(guid) then
        return nil
    end

    local ok, kind, id = pcall(string.match, guid, "^(%a+)%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)")

    if not ok or (kind ~= "Creature" and kind ~= "Vehicle" and kind ~= "Vignette") then
        return nil
    end

    id = tonumber(id)

    if not id or id == 0 then
        return nil
    end

    return id
end

local function ReadZone()
    local zone = Read(GetRealZoneText)

    if U.IsNonEmptyString(zone) then
        return zone
    end

    zone = Read(GetZoneText)

    return U.IsNonEmptyString(zone) and zone or nil
end

local function GetStore()
    local db = ns.state and ns.state.db

    if type(db) ~= "table" then
        return nil
    end

    if type(db.kills) ~= "table" then
        db.kills = {}
    end

    if type(db.kills.mobs) ~= "table" then
        db.kills.mobs = {}
    end

    return db.kills
end

local function Notify()
    for _, callback in ipairs(listeners) do
        pcall(callback)
    end
end

function Kills:OnChanged(callback)
    if type(callback) == "function" then
        table.insert(listeners, callback)
    end
end

local function Prune()
    local now = Clock()

    if now - lastPrune < NAMEPLATE_PRUNE_SECONDS then
        return
    end

    lastPrune = now

    for guid, entry in pairs(nameplateCache) do
        if entry.removedAt and now - entry.removedAt > NAMEPLATE_KEEP_SECONDS then
            nameplateCache[guid] = nil
        end
    end

    for guid, at in pairs(countedDeaths) do
        if now - at > NAMEPLATE_KEEP_SECONDS then
            countedDeaths[guid] = nil
        end
    end
end

-- UnitIsTapDenied raises on a secret token, so the token is checked first.
local function ReadTapDenied(token)
    if token == nil or IsSecret(token) then
        return nil
    end

    local denied = Read(UnitIsTapDenied, token)

    if denied == nil then
        return nil
    end

    return denied == true
end

-- Nil means nothing is known, and the kill is kept since the killing blow was ours.
local function TaggedBySomeoneElse(guid)
    if type(UnitTokenFromGUID) == "function" then
        local live = ReadTapDenied(Read(UnitTokenFromGUID, guid))

        if live ~= nil then
            return live
        end
    end

    local entry = nameplateCache[guid]

    if entry then
        return entry.tapDenied
    end

    return nil
end

-- Combat-log ownership. A hunter pet or a guardian (Snake Trap and the like)
-- often is not UnitGUID("pet") at the moment of the killing blow.
local AFFILIATION_MINE = 0x00000001
local TYPE_OURS = 0x00000400 + 0x00001000 + 0x00002000

local cachedPetGUID

local function Band(flags, mask)
    if type(flags) ~= "number" or IsSecret(flags) then
        return nil
    end

    if type(bit) ~= "table" or type(bit.band) ~= "function" then
        return nil
    end

    local ok, value = pcall(bit.band, flags, mask)

    if ok and type(value) == "number" then
        return value
    end

    return nil
end

local function RememberPet()
    local guid = Read(UnitGUID, "pet")

    if guid then
        cachedPetGUID = guid
    end
end

local function IsOurPet(guid)
    if not guid or IsSecret(guid) then
        return false
    end

    return guid == Read(UnitGUID, "pet") or guid == cachedPetGUID
end

local function IsOurKiller(attackerGUID, sourceFlags)
    if attackerGUID and not IsSecret(attackerGUID) then
        if attackerGUID == Read(UnitGUID, "player") or IsOurPet(attackerGUID) then
            return true
        end
    end

    local mine = Band(sourceFlags, AFFILIATION_MINE)
    local kind = Band(sourceFlags, TYPE_OURS)

    if mine == nil or kind == nil then
        return false
    end

    return mine ~= 0 and kind ~= 0
end

local FALLBACK_UNITS = { "target", "mouseover", "focus", "pettarget", "targettarget" }

local function FindUnit(guid)
    if type(UnitTokenFromGUID) == "function" then
        local token = Read(UnitTokenFromGUID, guid)

        if token then
            return token
        end
    end

    for _, unit in ipairs(FALLBACK_UNITS) do
        if Read(UnitGUID, unit) == guid then
            return unit
        end
    end

    return nil
end

local function ReadUnitDetails(unit)
    local reaction = Read(UnitReaction, "player", unit)
    local classification = Read(UnitClassification, unit) or "normal"

    return {
        name = Read(UnitName, unit) or "Unknown",
        level = U.ToSafeNumber(Read(UnitLevel, unit)) or 0,
        creatureType = Read(UnitCreatureType, unit),
        classification = classification,
        isBoss = classification == "worldboss",
        isFriendly = reaction ~= nil and reaction >= 5,
        tapDenied = ReadTapDenied(unit),
    }
end

function Kills:RecordKill(mobID, details)
    local store = GetStore()

    if not store or not mobID then
        return nil
    end

    details = details or {}

    local now = Now()
    local mob = store.mobs[mobID]

    if not mob then
        mob = { name = details.name or "Unknown", kills = 0, gold = 0, loot = {}, firstKill = now }
        store.mobs[mobID] = mob
    end

    mob.kills = (mob.kills or 0) + 1
    mob.lastKill = now

    if U.IsNonEmptyString(details.name) and details.name ~= "Unknown" then
        mob.name = details.name
    end

    if type(details.creatureType) == "string" and details.creatureType ~= "" then
        mob.creatureType = details.creatureType
    end

    if (U.ToSafeNumber(details.level) or 0) > 0 then
        mob.level = details.level
    end

    if type(details.classification) == "string" and details.classification ~= "normal" then
        mob.classification = details.classification
    end

    if details.isBoss then
        mob.isBoss = true
    end

    mob.zone = details.zone or mob.zone

    if details.classification == "rare" or details.classification == "rareelite" then
        local account = ns.Account
        local bucket = account and account.Bucket("rares")
        local id = tostring(mobID)

        if bucket then
            local rare = bucket[id]

            if type(rare) ~= "table" then
                rare = { pins = {}, loot = {} }
                bucket[id] = rare
            end

            rare.name = mob.name
            rare.classification = details.classification
            rare.kills = (rare.kills or 0) + 1
            rare.zone = mob.zone
            rare.character = account.CharacterKey()
            rare.time = now
            rare.pins = type(rare.pins) == "table" and rare.pins or {}

            local map, x, y = nil, nil, nil

            if C_Map and type(C_Map.GetBestMapForUnit) == "function" and type(C_Map.GetPlayerMapPosition) == "function" then
                local okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player")
                local okPos, pos, posY = pcall(C_Map.GetPlayerMapPosition, mapID, "player")

                if okMap and okPos then
                    map = mapID

                    if type(pos) == "table" then
                        x, y = pos.x, pos.y
                    elseif type(pos) == "number" then
                        x, y = pos, posY
                    end

                    if type(x) == "number" and x <= 1 then
                        x = math.floor(x * 1000 + 0.5) / 10
                    end

                    if type(y) == "number" and y <= 1 then
                        y = math.floor(y * 1000 + 0.5) / 10
                    end
                end
            end

            rare.map = map or rare.map
            rare.x = x or rare.x
            rare.y = y or rare.y
            rare.loot = type(rare.loot) == "table" and rare.loot or {}
            Kills.lastRare = { id = id, at = type(GetTime) == "function" and GetTime() or 0 }
            account.Push(rare.pins, {
                time = now,
                zone = rare.zone,
                x = rare.x,
                y = rare.y,
                character = rare.character,
            }, 20)

            local tasks = ns.Data and ns.Data.Tasks

            if tasks and ns:IsFeatureOn("tasks") then
                tasks:CompleteMatching(mob.name, nil)
            end
        end
    end

    session.kills = session.kills + 1
    session.byMob[mobID] = (session.byMob[mobID] or 0) + 1
    table.insert(session.recent, 1, { mobID = mobID, name = mob.name, t = now })

    while #session.recent > RECENT_LIST_SIZE do
        table.remove(session.recent)
    end

    for index = #session.recentMobs, 1, -1 do
        if session.recentMobs[index] == mobID then
            table.remove(session.recentMobs, index)
        end
    end

    table.insert(session.recentMobs, 1, mobID)

    while #session.recentMobs > RECENT_LIST_SIZE do
        table.remove(session.recentMobs)
    end

    Notify()

    return mob
end

local function RecordUnitDeath(guid)
    if not guid or countedDeaths[guid] then
        return
    end

    local mobID = Kills.GetMobID(guid)

    if not mobID then
        return
    end

    local details = nameplateCache[guid]
    nameplateCache[guid] = nil

    if not details then
        local unit = FindUnit(guid)

        -- Without a unit there is no way to tell a hostile mob from a scripted quest NPC.
        if not unit then
            return
        end

        details = ReadUnitDetails(unit)
    end

    if details.isFriendly then
        return
    end

    details.zone = ReadZone()
    countedDeaths[guid] = Clock()
    lastKillGUID = guid
    lastKillAt = Clock()

    Kills:RecordKill(mobID, details)
end

local function RecentKillGUID()
    if lastKillGUID and Clock() - lastKillAt <= RECENT_KILL_SECONDS then
        return lastKillGUID
    end

    return nil
end

local function OnNameplateAdded(unit)
    if InInstance() or not unit then
        return
    end

    local guid = Read(UnitGUID, unit)

    if not Kills.GetMobID(guid) then
        return
    end

    Prune()
    nameplateCache[guid] = ReadUnitDetails(unit)
end

local function OnNameplateRemoved(unit)
    if InInstance() or not unit then
        return
    end

    local guid = Read(UnitGUID, unit)
    local entry = guid and nameplateCache[guid]

    if entry then
        entry.removedAt = Clock()

        local denied = ReadTapDenied(unit)

        if denied ~= nil then
            entry.tapDenied = denied
        end
    end
end

local function OnPartyKill(attackerGUID, targetGUID, sourceFlags)
    if InInstance() or IsSecret(targetGUID) or IsOurPet(targetGUID) then
        return
    end

    if IsSecret(attackerGUID) then
        attackerGUID = nil
    end

    if not targetGUID or not IsOurKiller(attackerGUID, sourceFlags) or TaggedBySomeoneElse(targetGUID) then
        return
    end

    RecordUnitDeath(targetGUID)
end

-- Payload slot of overkill after the combat-log prefix. A value of 0 or more
-- is the killing blow. Pet specials often arrive this way and never as PARTY_KILL.
local OVERKILL_AT = {
    SWING_DAMAGE = 2,
    RANGE_DAMAGE = 5,
    SPELL_DAMAGE = 5,
    SPELL_PERIODIC_DAMAGE = 5,
}

local function CombatLogInfo(...)
    if type(CombatLogGetCurrentEventInfo) == "function" then
        local ok, info = pcall(function()
            return { CombatLogGetCurrentEventInfo() }
        end)

        if ok and type(info) == "table" and type(info[2]) == "string" then
            return info
        end
    end

    return { ... }
end

local function OnCombatLog(...)
    if InInstance() then
        return
    end

    local info = CombatLogInfo(...)
    local subevent = info[2]

    if type(subevent) ~= "string" then
        return
    end

    -- hideCaster is a boolean in the current prefix. Older logs omit it.
    local shift = type(info[3]) == "boolean" and 1 or 0
    local sourceGUID = info[3 + shift]
    local sourceFlags = info[5 + shift]
    local destGUID = info[7 + shift]
    local prefix = shift == 1 and 11 or 10

    if subevent == "PARTY_KILL" then
        OnPartyKill(sourceGUID, destGUID, sourceFlags)
        return
    end

    local at = OVERKILL_AT[subevent]

    if not at then
        return
    end

    local overkill = info[prefix + at]

    if type(overkill) ~= "number" or IsSecret(overkill) or overkill < 0 then
        return
    end

    OnPartyKill(sourceGUID, destGUID, sourceFlags)
end

local function OnUnitDied(guid)
    if InInstance() or IsSecret(guid) or TaggedBySomeoneElse(guid) then
        return
    end

    RecordUnitDeath(guid)
end

local function AddLoot(mob, itemID, quantity, name, credited)
    mob.loot = mob.loot or {}

    local entry = mob.loot[itemID]

    if not entry then
        entry = { name = name, quantity = 0, drops = 0 }
        mob.loot[itemID] = entry
    end

    entry.quantity = (entry.quantity or 0) + quantity
    entry.name = name or entry.name

    if not credited[entry] then
        credited[entry] = true
        entry.drops = (entry.drops or 0) + 1
    end
end

local function SlotSources(slot, quantity)
    local sources = {}

    if type(GetLootSourceInfo) == "function" then
        sources = { pcall(GetLootSourceInfo, slot) }

        if table.remove(sources, 1) ~= true then
            sources = {}
        end
    end

    if #sources == 0 then
        local recent = RecentKillGUID()

        if recent then
            sources = { recent, quantity }
        end
    end

    return sources
end

local function OnLootOpened(_, isFromItem)
    if isFromItem or InInstance() or type(GetNumLootItems) ~= "function" then
        return
    end

    local store = GetStore()

    if not store then
        return
    end

    local credited = {}
    local changed = false

    for slot = 1, Read(GetNumLootItems) or 0 do
        local slotType = Read(GetLootSlotType, slot)

        if slotType == (LOOT_SLOT_ITEM or 1) then
            local ok, _, name, quantity = pcall(GetLootSlotInfo, slot)
            local link = Read(GetLootSlotLink, slot)
            local itemID = type(link) == "string" and tonumber(link:match("item:(%d+)"))
            quantity = ok and U.ToSafeNumber(quantity) or 0

            if itemID and quantity > 0 then
                local sources = SlotSources(slot, quantity)
                local total = 0

                for index = 2, #sources, 2 do
                    total = total + (U.ToSafeNumber(sources[index]) or 0)
                end

                for index = 1, #sources, 2 do
                    local mob = store.mobs[Kills.GetMobID(sources[index]) or 0]
                    local share = U.ToSafeNumber(sources[index + 1]) or 0

                    if #sources > 2 and total > 0 then
                        share = math.floor((quantity * share / total) + 0.5)
                    elseif #sources == 2 then
                        share = quantity
                    end

                    if mob and share > 0 then
                        AddLoot(mob, itemID, share, U.IsNonEmptyString(name) and name or nil, credited)
                        changed = true
                    end
                end
            end
        end
    end

    if changed then
        Notify()
    end
end

function Kills.ParseMoney(text)
    if type(text) ~= "string" then
        return 0
    end

    local function Amount(format)
        if type(format) ~= "string" then
            return 0
        end

        local pattern = format
            :gsub("([%(%)%.%+%-%[%]%?%^%$])", "%%%1")
            :gsub("%%d", "(%%d+)")

        return tonumber(text:match(pattern)) or 0
    end

    return Amount(GOLD_AMOUNT) * 10000 + Amount(SILVER_AMOUNT) * 100 + Amount(COPPER_AMOUNT)
end

local function OnMoney(text)
    if InInstance() then
        return
    end

    local copper = Kills.ParseMoney(text)
    local store = GetStore()
    local mob = store and store.mobs[Kills.GetMobID(RecentKillGUID()) or 0]

    if copper <= 0 or not mob then
        return
    end

    mob.gold = (mob.gold or 0) + copper
    session.gold = session.gold + copper
    Notify()
end

local function LinkName(link)
    return type(link) == "string" and link:match("|h%[(.-)%]|h") or nil
end

-- Copies KillDex's history for this character once, so it is not lost when
-- KillDex is removed. Skipped as soon as Dossier has any kills of its own.
function Kills:ImportKillDex()
    local store = GetStore()

    if not store or store.importedFrom or next(store.mobs) ~= nil then
        return false
    end

    local source = type(KillDexCharDB) == "table" and KillDexCharDB.mobs

    if type(source) ~= "table" then
        return false
    end

    local imported = 0

    for mobID, data in pairs(source) do
        local id = tonumber(mobID)

        if id and type(data) == "table" and (tonumber(data.kills) or 0) > 0 then
            local lastLocation = type(data.locations) == "table" and data.locations[#data.locations] or nil
            local mob = {
                name = U.IsNonEmptyString(data.name) and data.name or "Unknown",
                kills = tonumber(data.kills),
                gold = tonumber(data.gold) or 0,
                creatureType = type(data.creatureType) == "string" and data.creatureType ~= "Unknown" and data.creatureType or nil,
                classification = data.classification,
                isBoss = data.isBoss == true or nil,
                firstKill = tonumber(data.firstKill),
                lastKill = tonumber(data.lastKill),
                level = lastLocation and (tonumber(lastLocation.level) or 0) > 0 and tonumber(lastLocation.level) or nil,
                zone = lastLocation and U.IsNonEmptyString(lastLocation.zone) and lastLocation.zone ~= "Unknown" and lastLocation.zone or nil,
                loot = {},
            }

            for itemID, entry in pairs(type(data.loot) == "table" and data.loot or {}) do
                local lootID = tonumber(itemID)

                if lootID and type(entry) == "table" then
                    mob.loot[lootID] = {
                        name = entry.name or LinkName(entry.link),
                        quantity = tonumber(entry.quantity) or 0,
                        drops = tonumber(entry.drops) or 0,
                    }
                end
            end

            store.mobs[id] = mob
            imported = imported + mob.kills
        end
    end

    store.importedFrom = "KillDex"
    store.importedAt = Now()
    store.importedKills = imported
    Notify()

    return true
end

function Kills:GetMobs()
    local store = GetStore()
    return store and store.mobs or {}
end

function Kills:GetMob(mobID)
    return self:GetMobs()[mobID]
end

function Kills:GetKillCount(mobID)
    local mob = self:GetMob(mobID)
    return mob and mob.kills or 0
end

function Kills:HasData()
    return next(self:GetMobs()) ~= nil
end

function Kills:GetImportInfo()
    local store = GetStore()

    if store and store.importedFrom then
        return { source = store.importedFrom, kills = store.importedKills, at = store.importedAt }
    end

    return nil
end

function Kills:GetTotals()
    local totals = { kills = 0, creatures = 0, gold = 0, byType = {} }
    local byType = {}

    for _, mob in pairs(self:GetMobs()) do
        local kills = mob.kills or 0
        local kind = mob.creatureType or "Unknown"

        totals.kills = totals.kills + kills
        totals.creatures = totals.creatures + 1
        totals.gold = totals.gold + (mob.gold or 0)
        byType[kind] = (byType[kind] or 0) + kills
    end

    for kind, kills in pairs(byType) do
        table.insert(totals.byType, { name = kind, kills = kills })
    end

    table.sort(totals.byType, function(a, b)
        if a.kills ~= b.kills then
            return a.kills > b.kills
        end

        return a.name < b.name
    end)

    return totals
end

function Kills:GetSession()
    local seconds = math.max(0, Now() - (session.start or Now()))
    local creatures = {}
    local mobs = self:GetMobs()

    for _, mobID in ipairs(session.recentMobs) do
        local mob = mobs[mobID]
        table.insert(creatures, {
            mobID = mobID,
            name = mob and mob.name or "Unknown",
            count = session.byMob[mobID] or 0,
            classification = mob and mob.classification or nil,
        })
    end

    return {
        kills = session.kills,
        gold = session.gold,
        seconds = seconds,
        killsPerHour = session.kills * 3600 / math.max(seconds, MIN_RATE_SECONDS),
        byMob = session.byMob,
        recent = session.recent,
        creatures = creatures,
    }
end

function Kills:ResetSession()
    session.start = Now()
    session.kills = 0
    session.gold = 0
    session.byMob = {}
    session.recent = {}
    session.recentMobs = {}
    Notify()
end

-- Sorted list of { id, mob } for the Kills tab and the export.
function Kills:GetSortedMobs(sortKey, filter)
    local list = {}
    local needle = U.IsNonEmptyString(filter) and string.lower(filter) or nil

    for id, mob in pairs(self:GetMobs()) do
        if not needle or string.find(string.lower(mob.name or ""), needle, 1, true) then
            table.insert(list, { id = id, mob = mob })
        end
    end

    table.sort(list, function(a, b)
        if sortKey == "name" then
            if (a.mob.name or "") ~= (b.mob.name or "") then
                return (a.mob.name or "") < (b.mob.name or "")
            end
        elseif sortKey == "recent" then
            if (a.mob.lastKill or 0) ~= (b.mob.lastKill or 0) then
                return (a.mob.lastKill or 0) > (b.mob.lastKill or 0)
            end
        elseif (a.mob.kills or 0) ~= (b.mob.kills or 0) then
            return (a.mob.kills or 0) > (b.mob.kills or 0)
        end

        return a.id < b.id
    end)

    return list
end

function Kills:IsTooltipEnabled()
    local db = ns.state and ns.state.db
    return not (type(db) == "table" and db.killTooltip == false)
end

function Kills:SetTooltipEnabled(enabled)
    local db = ns.state and ns.state.db

    if type(db) == "table" then
        db.killTooltip = enabled ~= false
    end
end

local tooltipHooked = false

local function SetupTooltip()
    if tooltipHooked
        or not TooltipDataProcessor
        or type(TooltipDataProcessor.AddTooltipPostCall) ~= "function"
        or not (Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit)
    then
        return
    end

    tooltipHooked = true

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
        if not ns:IsFeatureOn("kills") or not Kills:IsTooltipEnabled() or type(data) ~= "table" or IsSecret(data.guid) then
            return
        end

        local count = Kills:GetKillCount(Kills.GetMobID(data.guid))

        if count > 0 and tooltip and type(tooltip.AddLine) == "function" then
            tooltip:AddLine(string.format(C.TEXT.KILLS_TOOLTIP, count, count == 1 and "" or "s"), 0.36, 0.78, 0.66)
        end
    end)
end

function Kills:Collect()
    local totals = self:GetTotals()
    local top = {}

    for index, entry in ipairs(self:GetSortedMobs("kills")) do
        if index > C.KILLS_EXPORT_TOP then
            break
        end

        table.insert(top, entry.mob)
    end

    local drops = {}
    local seen = {}

    for _, mob in pairs(self:GetMobs()) do
        for _, entry in pairs(mob.loot or {}) do
            if U.IsNonEmptyString(entry.name) and not seen[entry.name] then
                seen[entry.name] = true
                table.insert(drops, entry.name)
            end
        end
    end

    table.sort(drops)

    return {
        key = C.SECTIONS.KILLS,
        title = C.SECTION_LABELS[C.SECTIONS.KILLS],
        totals = totals,
        top = top,
        drops = drops,
        session = self:GetSession(),
        imported = self:GetImportInfo(),
    }
end

local eventFrame = CreateFrame("Frame")
local registeredEvents = {}

local function Register(event)
    local ok, result = pcall(eventFrame.RegisterEvent, eventFrame, event)
    ok = ok and result ~= false

    if ok then
        table.insert(registeredEvents, event)
    else
        table.insert(Kills.refusedEvents, event)
    end

    return ok
end

local function IsLoggedInNow()
    return type(IsLoggedIn) ~= "function" or IsLoggedIn() == true
end

local function EnsureExampleRare()
    local name = type(UnitName) == "function" and UnitName("player") or nil

    if type(name) ~= "string" or string.lower(name) ~= "ulrathor" then
        return
    end

    local store = GetStore()

    if not store or store.mobs["example-hogger"] then
        return
    end

    local now = type(time) == "function" and time() or 0

    store.mobs["example-hogger"] = {
        name = "Hogger",
        kills = 2,
        gold = 4700,
        loot = {
            ["117"] = { name = "Tough Jerky", quantity = 2, drops = 2 },
        },
        classification = "rare",
        creatureType = "Humanoid",
        level = 11,
        zone = "Elwynn Forest",
        firstKill = now,
        lastKill = now,
        example = true,
    }
    Notify()
end

local function OnLogin()
    RememberPet()

    if ns:IsFeatureOn("companions") then
        Kills:ImportKillDex()
    end

    EnsureExampleRare()
    SetupTooltip()
end

function Kills:SetFeatureActive(on, loading)
    ns.Features.SetEvents(eventFrame, registeredEvents, on)
    lootWindowSeen = false

    if on and not loading and IsLoggedInNow() then
        OnLogin()
    end

    if not loading then
        Notify()
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if not ns:IsFeatureOn("kills") then
        return
    end

    if event == "NAME_PLATE_UNIT_ADDED" then
        OnNameplateAdded(...)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        OnNameplateRemoved(...)
    elseif event == "PARTY_KILL" then
        OnPartyKill(...)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLog(...)
    elseif event == "UNIT_PET" then
        local unit = ...

        if unit == "player" then
            RememberPet()
        end
    elseif event == "UNIT_DIED" then
        OnUnitDied(...)
    elseif event == "LOOT_OPENED" then
        if not lootWindowSeen then
            lootWindowSeen = true
            OnLootOpened(...)
        end
    elseif event == "LOOT_CLOSED" then
        lootWindowSeen = false
    elseif event == "CHAT_MSG_MONEY" then
        OnMoney(...)
    elseif event == "CHAT_MSG_LOOT" then
        local text = ...
        local recent = Kills.lastRare
        local now = type(GetTime) == "function" and GetTime() or 0

        if recent and (now - (recent.at or 0)) < 12 and type(text) == "string" then
            local item = string.match(text, "%[(.-)%]")
            local bucket = ns.Account and ns.Account.Database() and ns.Account.Database().rares
            local rare = bucket and bucket[recent.id]

            if item and type(rare) == "table" then
                rare.loot = type(rare.loot) == "table" and rare.loot or {}
                local seen = false

                for _, name in ipairs(rare.loot) do
                    if name == item then
                        seen = true
                    end
                end

                if not seen then
                    table.insert(rare.loot, item)
                end
            end
        end
    elseif event == "PLAYER_LOGIN" then
        OnLogin()
    end
end)

Register("PLAYER_LOGIN")
Register("UNIT_PET")
Register("NAME_PLATE_UNIT_ADDED")
Register("NAME_PLATE_UNIT_REMOVED")
Register("COMBAT_LOG_EVENT_UNFILTERED")

if Register("PARTY_KILL") then
    Kills.source = "PARTY_KILL"
elseif Register("UNIT_DIED") then
    Kills.source = "UNIT_DIED"
end

Register("LOOT_OPENED")
Register("LOOT_CLOSED")
Register("CHAT_MSG_MONEY")
Register("CHAT_MSG_LOOT")

session.start = Now()

ns:RegisterModule("Data.Kills", Kills)

ns.Data = ns.Data or {}
ns.Data.Kills = Kills
