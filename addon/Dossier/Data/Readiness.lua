local _, ns = ...

local C = ns.constants
local U = ns.utils

local Readiness = {}

local STALE_SECONDS = 7 * 24 * 60 * 60

-- Herbalism, Fishing, Skinning, and Archaeology have no recipe window to open.
local NO_WINDOW_SKILL_LINES = {
    [182] = true,
    [356] = true,
    [393] = true,
    [794] = true,
}

local NO_WINDOW_NAMES = {
    herbalism = true,
    fishing = true,
    skinning = true,
    archaeology = true,
}

local function Now()
    local ok, value = pcall(time)
    return ok and U.ToSafeNumber(value) or 0
end

local function IsSelected(selections, key)
    return type(selections) ~= "table" or selections[key] == true
end

function Readiness.FormatAge(seconds)
    seconds = math.max(0, math.floor(U.ToSafeNumber(seconds) or 0))

    local function Unit(value, word)
        return string.format("%d %s%s", value, word, value == 1 and "" or "s")
    end

    if seconds >= 86400 then
        return Unit(math.floor(seconds / 86400), "day")
    elseif seconds >= 3600 then
        return Unit(math.floor(seconds / 3600), "hour")
    end

    return Unit(math.max(1, math.floor(seconds / 60)), "minute")
end

local function LearnedCraftingProfessions()
    local skills = ns.Data and ns.Data.Skills

    if not skills or type(skills.Collect) ~= "function" then
        return {}
    end

    local ok, data = pcall(skills.Collect, skills)

    if not ok or type(data) ~= "table" then
        return {}
    end

    local professions = {}

    for _, group in ipairs(data.groups or {}) do
        if group.name == C.SKILL_CATEGORY_LABELS.PROFESSIONS
            or group.name == C.SKILL_CATEGORY_LABELS.SECONDARY
        then
            for _, entry in ipairs(group.entries or {}) do
                local name = U.SafeString(entry.name, "")

                if name ~= ""
                    and not NO_WINDOW_SKILL_LINES[U.ToSafeNumber(entry.skillLineID) or 0]
                    and not NO_WINDOW_NAMES[string.lower(name)]
                then
                    table.insert(professions, name)
                end
            end
        end
    end

    return professions
end

local function SnapshotsByName()
    local details = ns.Data and ns.Data.ProfessionDetails
    local byName = {}

    if not details or type(details.GetCachedSnapshots) ~= "function" then
        return byName
    end

    local ok, snapshots = pcall(details.GetCachedSnapshots, details)

    if not ok or type(snapshots) ~= "table" then
        return byName
    end

    for _, snapshot in ipairs(snapshots) do
        for _, field in ipairs({ "name", "parentProfessionName", "baseProfessionName" }) do
            local value = snapshot[field]

            if U.IsNonEmptyString(value) then
                local key = string.lower(value)
                local existing = byName[key]

                if not existing
                    or (U.ToSafeNumber(snapshot.lastUpdated) or 0) > (U.ToSafeNumber(existing.lastUpdated) or 0)
                then
                    byName[key] = snapshot
                end
            end
        end
    end

    return byName
end

local function FallbackProfessionNames()
    local companions = ns.Companions
    local names = {}

    if not companions then
        return names
    end

    for _, profession in ipairs(companions:Read("professionmaster", "ReadProfessions") or {}) do
        if #(profession.recipes or {}) > 0 then
            names[string.lower(profession.name)] = true
        end
    end

    return names
end

local function HasBankFallback()
    local companions = ns.Companions
    local data = companions and companions:Read("syndicator", "ReadBank")

    return type(data) == "table" and #(data.sections or {}) > 0
end

-- Returns { missing = { {section, label, text} }, saved = { ... } } for the
-- bank and each profession with a recipe window, limited to ticked sections.
function Readiness:GetMissingData(selections)
    local result = { missing = {}, saved = {} }
    local now = Now()

    if IsSelected(selections, C.SECTIONS.BANK) then
        local bank = ns.Data and ns.Data.Bank
        local snapshot = bank and type(bank.GetCachedSnapshot) == "function" and bank:GetCachedSnapshot()

        if type(snapshot) ~= "table" then
            local text = C.TEXT.READINESS_BANK_MISSING

            if HasBankFallback() then
                text = text .. " " .. string.format(C.TEXT.READINESS_USING_FALLBACK, "Syndicator")
            end

            table.insert(result.missing, { section = C.SECTIONS.BANK, label = "Bank", text = text })
        else
            local age = now - (U.ToSafeNumber(snapshot.lastUpdated) or now)

            if age > STALE_SECONDS then
                table.insert(result.missing, {
                    section = C.SECTIONS.BANK,
                    label = "Bank",
                    text = string.format(C.TEXT.READINESS_BANK_STALE, Readiness.FormatAge(age)),
                })
            else
                table.insert(result.saved, { label = "Bank", age = age })
            end
        end
    end

    if IsSelected(selections, C.SECTIONS.PROFESSION_DETAILS) then
        local snapshots = SnapshotsByName()
        local fallbacks = nil

        for _, name in ipairs(LearnedCraftingProfessions()) do
            local snapshot = snapshots[string.lower(name)]

            if not snapshot then
                fallbacks = fallbacks or FallbackProfessionNames()

                local text = string.format(C.TEXT.READINESS_PROFESSION_MISSING, name)

                if fallbacks[string.lower(name)] then
                    text = text .. " " .. string.format(C.TEXT.READINESS_USING_FALLBACK, "Profession Master")
                end

                table.insert(result.missing, { section = C.SECTIONS.PROFESSION_DETAILS, label = name, text = text })
            else
                local age = now - (U.ToSafeNumber(snapshot.lastUpdated) or now)

                if age > STALE_SECONDS then
                    table.insert(result.missing, {
                        section = C.SECTIONS.PROFESSION_DETAILS,
                        label = name,
                        text = string.format(C.TEXT.READINESS_PROFESSION_STALE, name, Readiness.FormatAge(age)),
                    })
                else
                    table.insert(result.saved, { label = name, age = age, profession = true })
                end
            end
        end
    end

    return result
end

function Readiness:IsSectionMissing(result, section)
    for _, entry in ipairs(result and result.missing or {}) do
        if entry.section == section then
            return true
        end
    end

    return false
end

function Readiness:SummaryText(result)
    if #result.missing > 0 then
        local lines = {}

        for _, entry in ipairs(result.missing) do
            table.insert(lines, entry.text)
        end

        return table.concat(lines, "\n"), true
    end

    local professionCount = 0
    local bankAge = nil

    for _, entry in ipairs(result.saved) do
        if entry.profession then
            professionCount = professionCount + 1
        else
            bankAge = entry.age
        end
    end

    local parts = {}

    if bankAge then
        table.insert(parts, "Bank")
    end

    if professionCount > 0 then
        table.insert(parts, string.format("%d profession%s", professionCount, professionCount == 1 and "" or "s"))
    end

    if #parts == 0 then
        return C.TEXT.LABEL_BANK_HINT, false
    end

    local text = table.concat(parts, " and ") .. " saved"

    if bankAge then
        text = text .. string.format(" (bank %s ago)", Readiness.FormatAge(bankAge))
    end

    return text .. ".", false
end

function Readiness:MissingLabels(result)
    local labels = {}

    for _, entry in ipairs(result and result.missing or {}) do
        table.insert(labels, entry.label)
    end

    return labels
end

local listeners = {}

function Readiness:OnChanged(callback)
    if type(callback) == "function" then
        table.insert(listeners, callback)
    end
end

local notifyPending = false

local function Notify()
    notifyPending = false

    for _, callback in ipairs(listeners) do
        pcall(callback)
    end
end

function Readiness:NotifyChanged()
    if notifyPending then
        return
    end

    if C_Timer and type(C_Timer.After) == "function" then
        notifyPending = true
        C_Timer.After(0.3, Notify)
    else
        Notify()
    end
end

local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function()
    Readiness:NotifyChanged()
end)

for _, eventName in ipairs({ "BANKFRAME_CLOSED", "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE" }) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end

ns:RegisterModule("Data.Readiness", Readiness)

ns.Data = ns.Data or {}
ns.Data.Readiness = Readiness
