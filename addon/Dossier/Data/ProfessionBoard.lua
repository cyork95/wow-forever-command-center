local _, ns = ...

local ProfessionBoard = {}

local function Account()
    return ns.Account
end

local KEEP = {
    Alchemy = true,
    Blacksmithing = true,
    Enchanting = true,
    Engineering = true,
    Herbalism = true,
    Leatherworking = true,
    Mining = true,
    Skinning = true,
    Tailoring = true,
    Cooking = true,
    Fishing = true,
    ["First Aid"] = true,
    Poisons = true,
    Lockpicking = true,
}

local function AddSkill(skills, seen, name, current, max)
    if type(name) ~= "string" or name == "" or seen[name] then
        return
    end

    current = tonumber(current)

    if not current then
        return
    end

    seen[name] = true
    table.insert(skills, {
        name = name,
        current = current,
        max = tonumber(max) or 0,
    })
end

local function ReadProfessionSlots(skills, seen)
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
        return false
    end

    local ok, first, second, archaeology, fishing, cooking = pcall(GetProfessions)

    if not ok then
        return false
    end

    local found = false

    for _, index in ipairs({ first, second, archaeology, fishing, cooking }) do
        if tonumber(index) then
            local success, name, _, rank, maxRank = pcall(GetProfessionInfo, index)

            if success then
                AddSkill(skills, seen, name, rank, maxRank)
                found = true
            end
        end
    end

    return found
end

local function ReadClassicLines(skills, seen)
    if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then
        return
    end

    if type(ExpandSkillHeader) == "function" then
        for _ = 1, 8 do
            local ok, count = pcall(GetNumSkillLines)

            if not ok or type(count) ~= "number" then
                break
            end

            local expanded = false

            for index = 1, count do
                local success, _, isHeader, isExpanded = pcall(GetSkillLineInfo, index)

                if success and isHeader and not isExpanded then
                    pcall(ExpandSkillHeader, index)
                    expanded = true
                    break
                end
            end

            if not expanded then
                break
            end
        end
    end

    local ok, count = pcall(GetNumSkillLines)

    if not ok or type(count) ~= "number" then
        return
    end

    for index = 1, count do
        local success, name, isHeader, _, rank, _, _, maxRank, isAbandonable = pcall(GetSkillLineInfo, index)

        if success and isHeader ~= true and (KEEP[name] or isAbandonable == true) then
            AddSkill(skills, seen, name, rank, maxRank)
        end
    end
end

local function ReadModernLines(skills, seen)
    if type(C_SkillInfo) ~= "table" or type(C_SkillInfo.GetNumSkillLines) ~= "function" or type(C_SkillInfo.GetSkillLineInfo) ~= "function" then
        return
    end

    local ok, count = pcall(C_SkillInfo.GetNumSkillLines)

    if not ok or type(count) ~= "number" then
        return
    end

    for index = 1, count do
        local success, info = pcall(C_SkillInfo.GetSkillLineInfo, index)

        if success and type(info) == "table" and info.isHeader ~= true and (KEEP[info.name] or info.isAbandonable == true) then
            AddSkill(skills, seen, info.name, info.skillRank or info.rank, info.skillMaxRank or info.maxRank)
        end
    end
end

local function ReadSkills()
    local skills = {}
    local seen = {}

    if not ReadProfessionSlots(skills, seen) then
        ReadClassicLines(skills, seen)
        ReadModernLines(skills, seen)
    end

    return skills
end

function ProfessionBoard:Snapshot()
    if not ns:IsFeatureOn("professions") then
        return
    end

    local bucket = Account().Bucket("professions")
    local key = Account().CharacterKey()
    local skills = ReadSkills()

    if not bucket or not key or #skills == 0 then
        return
    end

    bucket[key] = {
        time = Account().Now(),
        skills = skills,
    }
end

function ProfessionBoard:Rows()
    local bucket = Account().Bucket("professions") or {}
    local mine = Account().CharacterKey()
    local keys = {}

    if mine and bucket[mine] then
        table.insert(keys, mine)
    end

    for _, key in ipairs(Account().Keys(bucket)) do
        if key ~= mine then
            table.insert(keys, key)
        end
    end

    local rows = {}

    for _, key in ipairs(keys) do
        table.insert(rows, { character = key, skills = bucket[key].skills or {} })
    end

    return rows
end

local eventFrame = CreateFrame("Frame")
local registered = {}

local function Register(event)
    local ok, result = pcall(eventFrame.RegisterEvent, eventFrame, event)

    if ok and result ~= false then
        table.insert(registered, event)
    end
end

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" and C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(2, function()
            ProfessionBoard:Snapshot()
        end)
    end

    ProfessionBoard:Snapshot()
end)

-- Profession ranks are read from Altoholic on the site. This board no longer
-- records them. Saved rows stay.

function ProfessionBoard:SetFeatureActive(on)
    ns.Features.SetEvents(eventFrame, registered, on)

    if on then
        ProfessionBoard:Snapshot()
    end
end

ns.Data = ns.Data or {}
ns.Data.ProfessionBoard = ProfessionBoard
ns:RegisterModule("Data.ProfessionBoard", ProfessionBoard)
