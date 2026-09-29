local _, ns = ...

local U = ns.utils
local C = ns.constants

local Statistics = {}

local MONEY_ICONS = {
    { icon = "GoldIcon", suffix = "g" },
    { icon = "SilverIcon", suffix = "s" },
    { icon = "CopperIcon", suffix = "c" },
}

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end

    return pcall(fn, ...)
end

-- Turns a GetStatistic string into plain text. Nil means the statistic has no
-- value yet ("--", "0", or all-zero money) and is left out of the export.
function Statistics.CleanValue(raw)
    if raw == nil or IsSecret(raw) then
        return nil
    end

    local text = tostring(raw)

    for _, money in ipairs(MONEY_ICONS) do
        text = text:gsub("(%d+)%s*|T[^|]*" .. money.icon .. "[^|]*|t", "%1" .. money.suffix)
    end

    text = text:gsub("|T.-|t", "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = U.Trim((text:gsub("%s+", " ")))

    if text == "" or text == "--" or text:gsub("[%s0gsc]", "") == "" then
        return nil
    end

    return text
end

local function ReadCategory(categoryID)
    local ok, name, parentID = SafeCall(GetCategoryInfo, categoryID)

    if not ok or IsSecret(name) or not U.IsNonEmptyString(name) then
        return nil, nil
    end

    parentID = not IsSecret(parentID) and U.ToSafeNumber(parentID) or nil

    return U.Trim(name), parentID
end

local function ReadStats(categoryID)
    local stats = {}
    local ok, count = SafeCall(GetCategoryNumAchievements, categoryID)
    count = ok and not IsSecret(count) and U.ToSafeNumber(count) or 0

    for index = 1, count do
        local infoOk, id, name = SafeCall(GetAchievementInfo, categoryID, index)
        id = infoOk and not IsSecret(id) and U.ToSafeNumber(id) or nil

        if id and not IsSecret(name) and U.IsNonEmptyString(name) then
            local valueOk, raw = SafeCall(GetStatistic, id)
            local value = valueOk and Statistics.CleanValue(raw) or nil

            if value then
                table.insert(stats, { id = id, name = U.Trim(name), value = value })
            end
        end
    end

    return stats
end

function Statistics:Collect()
    local result = {
        key = C.SECTIONS.STATISTICS,
        title = C.SECTION_LABELS[C.SECTIONS.STATISTICS],
        available = false,
        categories = {},
        diagnostics = {},
    }

    for _, api in ipairs({ "GetStatisticsCategoryList", "GetStatistic", "GetCategoryInfo", "GetCategoryNumAchievements", "GetAchievementInfo" }) do
        if type(_G[api]) ~= "function" then
            table.insert(result.diagnostics, api .. " API unavailable.")
            return result
        end
    end

    local ok, list = SafeCall(GetStatisticsCategoryList)

    if not ok or type(list) ~= "table" then
        table.insert(result.diagnostics, "GetStatisticsCategoryList call failed.")
        return result
    end

    result.available = true

    local names = {}
    local ordered = {}

    for _, rawID in ipairs(list) do
        local categoryID = not IsSecret(rawID) and U.ToSafeNumber(rawID) or nil

        if categoryID then
            local name, parentID = ReadCategory(categoryID)

            if name then
                names[categoryID] = name
                table.insert(ordered, { id = categoryID, name = name, parentID = parentID })
            end
        end
    end

    for _, category in ipairs(ordered) do
        local stats = ReadStats(category.id)

        if #stats > 0 then
            local parentName = category.parentID and category.parentID > 0 and names[category.parentID] or nil

            table.insert(result.categories, {
                id = category.id,
                name = parentName and (parentName .. " - " .. category.name) or category.name,
                stats = stats,
            })
        end
    end

    return result
end

ns:RegisterModule("Data.Statistics", Statistics)

ns.Data = ns.Data or {}
ns.Data.Statistics = Statistics
