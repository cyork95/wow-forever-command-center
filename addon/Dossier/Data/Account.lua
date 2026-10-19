local _, ns = ...

local Account = {}

function Account.Database()
    if type(DossierDB) ~= "table" then
        return nil
    end

    return DossierDB
end

function Account.Bucket(name)
    local db = Account.Database()

    if not db then
        return nil
    end

    if type(db[name]) ~= "table" then
        db[name] = {}
    end

    return db[name]
end

function Account.CharacterKey()
    local name = type(UnitName) == "function" and UnitName("player") or nil
    local realm = type(GetRealmName) == "function" and GetRealmName() or nil

    if type(name) ~= "string" or name == "" or name == "Unknown" then
        return nil
    end

    if type(realm) == "string" and realm ~= "" and realm ~= "Unknown" then
        return name .. "-" .. realm
    end

    return name
end

function Account.Now()
    if type(time) ~= "function" then
        return 0
    end

    local ok, value = pcall(time)

    return ok and type(value) == "number" and value or 0
end

function Account.Zone()
    local zone = type(GetRealZoneText) == "function" and GetRealZoneText() or nil

    if type(zone) == "string" and zone ~= "" then
        return zone
    end

    zone = type(GetZoneText) == "function" and GetZoneText() or nil

    if type(zone) == "string" and zone ~= "" then
        return zone
    end

    return nil
end

function Account.Shown(frameName)
    local frame = _G[frameName]

    return frame and type(frame.IsVisible) == "function" and frame:IsVisible() == true
end

function Account.Push(list, row, cap)
    table.insert(list, 1, row)

    while #list > cap do
        table.remove(list)
    end
end

function Account.Keys(bucket)
    local keys = {}

    if type(bucket) ~= "table" then
        return keys
    end

    for key, value in pairs(bucket) do
        if type(value) == "table" then
            table.insert(keys, key)
        end
    end

    table.sort(keys)

    return keys
end

-- "Oct 3 11:02"
function Account.FormatWhen(timestamp)
    timestamp = tonumber(timestamp)

    if not timestamp or timestamp <= 0 or type(date) ~= "function" then
        return ""
    end

    local ok, text = pcall(date, "%b %d %H:%M", timestamp)

    if ok and type(text) == "string" then
        return text:gsub(" 0", " ")
    end

    return ""
end

function Account.FormatGold(copper)
    local session = ns.Data and ns.Data.Session

    if session and session.FormatGold then
        return session.FormatGold(copper)
    end

    return tostring(math.floor(tonumber(copper) or 0))
end

-- Gold, silver, and copper icons, with green for a gain and red for a spend.
function Account.Coins(copper)
    copper = math.floor(tonumber(copper) or 0)
    local sign = ""

    if copper < 0 then
        sign = "|cffff6b61-|r"
    elseif copper > 0 then
        sign = "|cff7dffb3+|r"
    end

    if type(GetCoinTextureString) == "function" then
        local ok, text = pcall(GetCoinTextureString, math.abs(copper))

        if ok and type(text) == "string" and text ~= "" then
            return sign .. text
        end
    end

    return Account.FormatGold(copper)
end

ns.Account = Account
ns.Data = ns.Data or {}
ns.Data.Account = Account
