local _, ns = ...

local C = ns.constants
local U = ns.utils

local Pet = {}

local HAPPINESS = {
    [1] = "Unhappy",
    [2] = "Content",
    [3] = "Happy",
}

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

local function Text(value)
    if type(value) ~= "string" or IsSecret(value) then
        return nil
    end

    value = U.Trim(value)

    if value == "" or value == "Unknown" then
        return nil
    end

    return value
end

local function Number(value)
    if IsSecret(value) then
        return nil
    end

    value = U.ToSafeNumber(value)

    if not value or value <= 0 then
        return nil
    end

    return value
end

local function Store()
    local db = ns.state and ns.state.db

    if type(db) ~= "table" then
        return nil
    end

    if type(db.combatPet) ~= "table" then
        db.combatPet = {}
    end

    return db.combatPet
end

local function PetIsOut()
    if type(UnitExists) == "function" then
        local ok, exists = pcall(UnitExists, "pet")

        if ok then
            return exists == true
        end
    end

    return Text(Read(UnitName, "pet")) ~= nil
end

local function PetSpells()
    local spells = {}
    local seen = {}
    local book = BOOKTYPE_PET or "pet"
    local count = 0

    if type(HasPetSpells) == "function" then
        local ok, num = pcall(HasPetSpells)

        if ok and type(num) == "number" and num > 0 then
            count = num
        end
    end

    if count == 0 or type(GetSpellBookItemName) ~= "function" then
        return spells
    end

    for index = 1, count do
        local ok, name, rank = pcall(GetSpellBookItemName, index, book)
        name = ok and Text(name) or nil

        if name and not seen[name] then
            seen[name] = true
            rank = ok and Text(rank) or nil

            if rank then
                name = name .. " (" .. rank .. ")"
            end

            table.insert(spells, name)
        end
    end

    return spells
end

local function PetDiet()
    if type(GetPetFoodTypes) ~= "function" then
        return nil
    end

    local ok, foods = pcall(function()
        return { GetPetFoodTypes() }
    end)

    if not ok or type(foods) ~= "table" then
        return nil
    end

    local names = {}

    for _, food in ipairs(foods) do
        food = Text(food)

        if food then
            table.insert(names, food)
        end
    end

    if #names == 0 then
        return nil
    end

    return table.concat(names, ", ")
end

local function PetHappiness()
    if type(GetPetHappiness) ~= "function" then
        return nil
    end

    local ok, happiness = pcall(GetPetHappiness)

    if not ok or IsSecret(happiness) then
        return nil
    end

    return HAPPINESS[tonumber(happiness)]
end

local function ReadSummoned()
    if not PetIsOut() then
        return nil
    end

    local name = Text(Read(UnitName, "pet"))

    if not name then
        return nil
    end

    local health = Number(Read(UnitHealth, "pet"))
    local healthMax = Number(Read(UnitHealthMax, "pet"))

    return {
        name = name,
        family = Text(Read(UnitCreatureFamily, "pet")),
        creatureType = Text(Read(UnitCreatureType, "pet")),
        level = Number(Read(UnitLevel, "pet")),
        health = health,
        healthMax = healthMax,
        diet = PetDiet(),
        happiness = PetHappiness(),
        spells = PetSpells(),
    }
end

local function AddStable(pets, name, family, level)
    name = Text(name)

    if not name then
        return
    end

    table.insert(pets, {
        name = name,
        family = Text(family),
        level = Number(level),
    })
end

local function ReadStable()
    local pets = {}

    if C_StableInfo and type(C_StableInfo.GetNumStablePets) == "function" and type(C_StableInfo.GetStablePetInfo) == "function" then
        local ok, count = pcall(C_StableInfo.GetNumStablePets)

        if ok and type(count) == "number" and count > 0 then
            for index = 1, count do
                local okInfo, info = pcall(C_StableInfo.GetStablePetInfo, index)

                if okInfo and type(info) == "table" then
                    AddStable(pets, info.name or info.petName, info.family or info.petType or info.type, info.level)
                end
            end

            if #pets > 0 then
                return pets
            end
        end
    end

    if type(GetStablePetInfo) ~= "function" then
        return pets
    end

    local slots = 4

    if type(GetNumStableSlots) == "function" then
        local ok, num = pcall(GetNumStableSlots)

        if ok and type(num) == "number" and num > 0 then
            slots = num
        end
    elseif type(NUM_PET_STABLE_SLOTS) == "number" and NUM_PET_STABLE_SLOTS > 0 then
        slots = NUM_PET_STABLE_SLOTS
    end

    for index = 1, slots do
        local ok, _, name, level, family = pcall(GetStablePetInfo, index)

        if ok then
            AddStable(pets, name, family, level)
        end
    end

    return pets
end

local function Snapshot()
    local store = Store()
    local active = ReadSummoned()

    if not store then
        return active, active and "out" or "none"
    end

    if active then
        store.active = active
        store.status = "out"
        return active, "out"
    end

    if type(store.active) == "table" and Text(store.active.name) then
        store.status = "dismissed"
        return store.active, "dismissed"
    end

    store.status = "none"
    return nil, "none"
end

function Pet:Collect()
    local active, status = Snapshot()
    local stable = ReadStable()

    if not active and #stable == 0 then
        status = "none"
    end

    return {
        key = C.SECTIONS.PET,
        title = C.SECTION_LABELS[C.SECTIONS.PET],
        status = status,
        active = active,
        stable = stable,
    }
end

local eventFrame = CreateFrame("Frame")
local registeredEvents = {}

local function Register(event)
    local ok, result = pcall(eventFrame.RegisterEvent, eventFrame, event)
    ok = ok and result ~= false

    if ok then
        table.insert(registeredEvents, event)
    end
end

function Pet:SetFeatureActive(on)
    ns.Features.SetEvents(eventFrame, registeredEvents, on)

    if on then
        Snapshot()
    end
end

eventFrame:SetScript("OnEvent", function(_, event, unit)
    if not ns:IsFeatureOn("pet") then
        return
    end

    if event == "UNIT_PET" and unit ~= "player" then
        return
    end

    Snapshot()
end)

Register("PLAYER_LOGIN")
Register("UNIT_PET")

ns:RegisterModule("Data.Pet", Pet)

ns.Data = ns.Data or {}
ns.Data.Pet = Pet
