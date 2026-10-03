local _, ns = ...

local ProfessionBoard = {}

local function Account()
    return ns.Account
end

local function ReadSkills()
    local skills = {}

    if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then
        return skills
    end

    local ok, count = pcall(GetNumSkillLines)

    if not ok or type(count) ~= "number" then
        return skills
    end

    for index = 1, count do
        local success, name, isHeader, _, rank, _, _, maxRank = pcall(GetSkillLineInfo, index)

        if success and isHeader ~= true and type(name) == "string" and name ~= "" and tonumber(rank) then
            table.insert(skills, {
                name = name,
                current = tonumber(rank) or 0,
                max = tonumber(maxRank) or 0,
            })
        end
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

eventFrame:SetScript("OnEvent", function()
    ProfessionBoard:Snapshot()
end)

Register("PLAYER_LOGIN")
Register("SKILL_LINES_CHANGED")

function ProfessionBoard:SetFeatureActive(on)
    ns.Features.SetEvents(eventFrame, registered, on)

    if on then
        ProfessionBoard:Snapshot()
    end
end

ns.Data = ns.Data or {}
ns.Data.ProfessionBoard = ProfessionBoard
ns:RegisterModule("Data.ProfessionBoard", ProfessionBoard)
