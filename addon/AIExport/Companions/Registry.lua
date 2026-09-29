local _, ns = ...

local C = ns.constants
local U = ns.utils

local Companions = {}

Companions.list = {}
Companions.byId = {}

local Helpers = {}
Companions.helpers = Helpers

function Helpers.SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end

    return pcall(fn, ...)
end

function Helpers.Get(root, ...)
    local value = root

    for index = 1, select("#", ...) do
        if type(value) ~= "table" then
            return nil
        end

        value = value[select(index, ...)]
    end

    return value
end

function Helpers.PlayerNames()
    local names = {}
    local ok, name = Helpers.SafeCall(UnitName, "player")

    if ok and type(name) == "string" and name ~= "" then
        table.insert(names, name)

        local first = string.match(name, "^(%S+)%s")

        if first then
            table.insert(names, first)
        end
    end

    return names
end

function Helpers.KeyName(key)
    if type(key) ~= "string" then
        return nil
    end

    return string.match(key, "^(.-)%-[^%-]*$") or key
end

-- Returns the first key in `tbl` whose name part matches the player, trying the
-- full name before the first word so "Flann Anvilhew" wins over "Flann".
-- UnitName can return only the first word, so a key whose first word matches is
-- accepted when it is the only one.
function Helpers.FindCharacterKey(tbl)
    if type(tbl) ~= "table" then
        return nil
    end

    local names = Helpers.PlayerNames()

    for _, name in ipairs(names) do
        local lowered = string.lower(name)

        for key in pairs(tbl) do
            local keyName = Helpers.KeyName(key)

            if keyName and string.lower(keyName) == lowered then
                return key
            end
        end
    end

    for _, name in ipairs(names) do
        local lowered = string.lower(name)
        local match = nil
        local matches = 0

        for key in pairs(tbl) do
            local keyName = Helpers.KeyName(key)
            local first = keyName and string.match(keyName, "^(%S+)")

            if first and string.lower(first) == lowered then
                match = key
                matches = matches + 1
            end
        end

        if matches == 1 then
            return match
        end
    end

    return nil
end

function Helpers.Plural(count, word)
    return string.format("%d %s%s", count, word, count == 1 and "" or "s")
end

function Helpers.FormatMoney(copper)
    copper = math.floor(U.ToSafeNumber(copper) or 0)

    local negative = copper < 0

    if negative then
        copper = -copper
    end

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local rest = copper % 100
    local parts = {}

    if gold > 0 then
        table.insert(parts, gold .. "g")
    end

    if silver > 0 or gold > 0 then
        table.insert(parts, silver .. "s")
    end

    table.insert(parts, rest .. "c")

    return (negative and "-" or "") .. table.concat(parts, " ")
end

function Helpers.FormatDate(timestamp)
    local ok, text = Helpers.SafeCall(date, "%Y-%m-%d %H:%M", U.ToSafeNumber(timestamp) or 0)

    if ok and type(text) == "string" then
        return text
    end

    return "unknown time"
end

function Helpers.FormatDuration(seconds)
    seconds = math.floor(U.ToSafeNumber(seconds) or 0)

    if seconds < 0 then
        seconds = 0
    end

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)

    if days > 0 then
        return string.format("%dd %dh %dm", days, hours, minutes)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, seconds % 60)
    end

    return string.format("%ds", seconds)
end

function Helpers.LinkName(link)
    if type(link) ~= "string" then
        return nil
    end

    return string.match(link, "|h%[(.-)%]|h") or U.GetItemNameFromLink(link)
end

function Helpers.Count(tbl)
    if type(tbl) ~= "table" then
        return 0
    end

    local count = 0

    for _ in pairs(tbl) do
        count = count + 1
    end

    return count
end

-- Walks nested containers and calls `visit(item)` for every table with an itemLink.
function Helpers.EachItem(container, visit, depth)
    depth = depth or 0

    if type(container) ~= "table" or depth > 4 then
        return
    end

    if type(container.itemLink) == "string" then
        visit(container)
        return
    end

    for _, value in pairs(container) do
        Helpers.EachItem(value, visit, depth + 1)
    end
end

function Helpers.ItemLines(container, limit)
    local counts = {}
    local order = {}

    Helpers.EachItem(container, function(item)
        local name = Helpers.LinkName(item.itemLink)

        if name then
            if not counts[name] then
                table.insert(order, name)
                counts[name] = 0
            end

            counts[name] = counts[name] + (U.ToSafeNumber(item.itemCount) or 1)
        end
    end)

    table.sort(order)

    local lines = {}

    for index, name in ipairs(order) do
        if limit and index > limit then
            table.insert(lines, string.format("  ...and %d more", #order - limit))
            break
        end

        table.insert(lines, string.format("  %s x%d", name, counts[name]))
    end

    return lines, #order
end

local function AddOnApi()
    if C_AddOns then
        return C_AddOns.IsAddOnLoaded, C_AddOns.GetAddOnInfo
    end

    return IsAddOnLoaded, GetAddOnInfo
end

function Companions:Register(definition)
    if type(definition) ~= "table"
        or type(definition.id) ~= "string"
        or self.byId[definition.id]
    then
        return
    end

    definition.addons = definition.addons or {}
    table.insert(self.list, definition)
    self.byId[definition.id] = definition
end

function Companions:GetAll()
    return self.list
end

function Companions:Get(id)
    return self.byId[id]
end

function Companions:GetStatus(definition)
    if type(definition) ~= "table" then
        return "missing"
    end

    local isLoaded, getInfo = AddOnApi()
    local installed = false

    for _, folder in ipairs(definition.addons) do
        local ok, loaded = Helpers.SafeCall(isLoaded, folder)

        if ok and loaded then
            return "loaded"
        end

        local infoOk, name, _, _, _, reason = Helpers.SafeCall(getInfo, folder)

        if infoOk and name and reason ~= "MISSING" then
            installed = true
        end
    end

    return installed and "installed" or "missing"
end

function Companions:IsAvailable(definition)
    return self:GetStatus(definition) == "loaded"
end

local function GetChoices()
    local db = ns.state and ns.state.db

    if type(db) ~= "table" then
        return nil
    end

    if type(db.companions) ~= "table" then
        db.companions = {}
    end

    return db.companions
end

function Companions:IsEnabled(id)
    local choices = GetChoices()

    return not choices or choices[id] ~= false
end

function Companions:SetEnabled(id, enabled)
    local choices = GetChoices()

    if choices and self.byId[id] then
        choices[id] = enabled ~= false
    end
end

function Companions:CollectOne(definition)
    local ok, lines = pcall(definition.Collect, definition, Helpers)

    if not ok or type(lines) ~= "table" then
        return {
            string.format("[%s data could not be read in this version.]", definition.title),
        }
    end

    if #lines == 0 then
        return { "[Nothing recorded for this character yet.]" }
    end

    return lines
end

-- Runs `definition[reader]` for a loaded companion and returns its structured
-- data, or nil when the addon is not loaded or its layout could not be read.
-- Used by sections that fall back to a companion's copy of data AIExport has
-- not saved itself, so it ignores the Companions switches.
function Companions:Read(id, reader)
    local definition = self.byId[id]

    if not definition
        or type(definition[reader]) ~= "function"
        or not self:IsAvailable(definition)
    then
        return nil
    end

    local ok, data = pcall(definition[reader], definition, Helpers)

    if ok then
        return data
    end

    return nil
end

function Companions:IsBuiltIn(definition)
    return type(definition) == "table"
        and type(definition.IsBuiltIn) == "function"
        and definition:IsBuiltIn() == true
end

function Companions:Collect()
    local entries = {}

    for _, definition in ipairs(self.list) do
        if self:IsEnabled(definition.id)
            and self:IsAvailable(definition)
            and not self:IsBuiltIn(definition)
        then
            table.insert(entries, {
                id = definition.id,
                title = definition.title,
                lines = self:CollectOne(definition),
            })
        end
    end

    return {
        key = C.SECTIONS.COMPANIONS,
        title = C.SECTION_LABELS[C.SECTIONS.COMPANIONS],
        entries = entries,
    }
end

ns:RegisterModule("Companions", Companions)

ns.Companions = Companions
