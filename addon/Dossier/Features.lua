local _, ns = ...

local C = ns.constants

-- Every tracker can be switched off. The switches live in the account-wide
-- DossierDB, so they apply to every character.
local Features = {}

C.FEATURES = {
    {
        id = "biography",
        label = "Biography",
        tab = "biography",
        sections = { C.SECTIONS.BIOGRAPHY },
        modules = { "Data.Biography" },
        aliases = { "bio", "biography" },
        description = "Records level-ups, deaths, new zones, quest turn-ins, achievements, skill-ups, and boss kills.",
    },
    {
        id = "kills",
        label = "Kills",
        tab = "kills",
        sections = { C.SECTIONS.KILLS },
        modules = { "Data.Kills" },
        aliases = { "kills", "kill" },
        description = "Counts the creatures you kill with their drops and gold, and adds the count to creature tooltips.",
    },
    {
        id = "session",
        label = "Session",
        tab = "session",
        sections = { C.SECTIONS.SESSIONS },
        modules = { "Data.Session", "UI.KillPanel" },
        aliases = { "session", "sessions", "panel" },
        description = "Times play sessions with gathering, gold, and XP per hour, shows the session panel, and keeps Previous sessions.",
    },
    {
        id = "shopping",
        label = "Shopping list",
        tab = "shopping",
        sections = { C.SECTIONS.SHOPPING },
        modules = { "Data.ShoppingList" },
        aliases = { "shop", "shopping" },
        description = "Items and recipes you plan to gather or buy, with have and need counts and reminders.",
    },
    {
        id = "screenshots",
        label = "Screenshotter",
        tab = "screenshots",
        sections = {},
        modules = { "Data.Screenshotter" },
        aliases = { "shots", "screenshots", "screenshotter", "shot" },
        description = "Takes screenshots at big moments like level-ups, deaths, and boss kills.",
    },
    {
        id = "companions",
        label = "Companions",
        tab = "companions",
        sections = { C.SECTIONS.COMPANIONS },
        modules = {},
        aliases = { "companions", "companion" },
        description = "Reads other addons, such as Syndicator, KillDex, and AllTheThings, for what they know about this character.",
    },
}

Features.byId = {}
Features.bySection = {}
Features.byTab = {}
Features.byAlias = {}

for _, feature in ipairs(C.FEATURES) do
    Features.byId[feature.id] = feature
    Features.byTab[feature.tab] = feature

    for _, section in ipairs(feature.sections) do
        Features.bySection[section] = feature
    end

    for _, alias in ipairs(feature.aliases) do
        Features.byAlias[alias] = feature
    end
end

local listeners = {}

local function Store()
    if type(DossierDB) ~= "table" or type(DossierDB.features) ~= "table" then
        return nil
    end

    return DossierDB.features
end

function Features.Get(id)
    return Features.byId[id]
end

-- "shop", "Shopping", and "shopping" all find the shopping feature.
function Features.Find(text)
    if type(text) ~= "string" then
        return nil
    end

    local key = string.lower(text)

    return Features.byId[key] or Features.byAlias[key]
end

function Features.SetEvents(frame, events, on)
    if not frame then
        return
    end

    local method = on and frame.RegisterEvent or frame.UnregisterEvent

    if type(method) ~= "function" then
        return
    end

    for _, event in ipairs(events) do
        pcall(method, frame, event)
    end
end

local function ApplyModules(feature, on, loading)
    for _, name in ipairs(feature.modules) do
        local module = ns:GetModule(name)

        if module and type(module.SetFeatureActive) == "function" then
            pcall(module.SetFeatureActive, module, on, loading)
        end
    end
end

-- Modules register their events when their files load, before the saved
-- switches exist, so the features that are off are stopped here.
function Features.ApplySaved()
    for _, feature in ipairs(C.FEATURES) do
        if not ns:IsFeatureOn(feature.id) then
            ApplyModules(feature, false, true)
        end
    end
end

function Features.PrintOff(id)
    local feature = Features.byId[id]

    if feature and DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, string.format(C.TEXT.FEATURE_OFF, feature.label))
    end
end

function ns:IsFeatureOn(id)
    local store = Store()
    return not (store and store[id] == false)
end

function ns:SetFeatureOn(id, on)
    local feature = Features.byId[id]

    if not feature then
        return false
    end

    on = on ~= false

    local store = Store()

    if store then
        store[id] = on
    end

    ApplyModules(feature, on, false)

    for _, callback in ipairs(listeners) do
        pcall(callback, id, on)
    end

    return true
end

function ns:OnFeatureChanged(callback)
    if type(callback) == "function" then
        table.insert(listeners, callback)
    end
end

function ns:GetFeatureForSection(sectionKey)
    return Features.bySection[sectionKey]
end

function ns:IsSectionFeatureOn(sectionKey)
    local feature = Features.bySection[sectionKey]
    return not feature or self:IsFeatureOn(feature.id)
end

function ns:IsTabFeatureOn(tabId)
    local feature = Features.byTab[tabId]
    return not feature or self:IsFeatureOn(feature.id)
end

-- A copy of the selection without the sections of switched-off features.
function ns:FilterSelectionsByFeature(selections)
    local filtered = {}

    for key, value in pairs(type(selections) == "table" and selections or {}) do
        filtered[key] = value == true and self:IsSectionFeatureOn(key) or false
    end

    return filtered
end

ns.Features = Features
