local _, ns = ...

local C = ns.constants
local U = ns.utils

local Location = {}

local UNKNOWN = "unknown"

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end

    return pcall(fn, ...)
end

local function SafeText(value, fallback)
    local text = U.SafeString(value, "")
    text = U.Trim(text)

    if text ~= "" then
        return text
    end

    return fallback or UNKNOWN
end

local function SafeNumber(value)
    return U.ToSafeNumber(value)
end

local function CollectZoneText()
    if type(GetZoneText) ~= "function" then
        return UNKNOWN
    end

    local success, zoneText =
        SafeCall(GetZoneText)

    if not success then
        return UNKNOWN
    end

    return SafeText(zoneText, UNKNOWN)
end

local function CollectSubZoneText()
    if type(GetSubZoneText) ~= "function" then
        return UNKNOWN
    end

    local success, subZoneText =
        SafeCall(GetSubZoneText)

    if not success then
        return UNKNOWN
    end

    return SafeText(subZoneText, UNKNOWN)
end

local function GetBestMapID()
    if not C_Map
        or type(C_Map.GetBestMapForUnit) ~= "function"
    then
        return nil
    end

    local success, mapID =
        SafeCall(
            C_Map.GetBestMapForUnit,
            "player"
        )

    if not success then
        return nil
    end

    return SafeNumber(mapID)
end

local function GetMapInfo(mapID)
    if mapID == nil then
        return nil
    end

    if not C_Map
        or type(C_Map.GetMapInfo) ~= "function"
    then
        return nil
    end

    local success, mapInfo =
        SafeCall(
            C_Map.GetMapInfo,
            mapID
        )

    if success
        and type(mapInfo) == "table"
    then
        return mapInfo
    end

    return nil
end

local function CollectMapDetails(mapID)
    local mapInfo = GetMapInfo(mapID)

    local mapName = UNKNOWN
    local parentMapID = nil
    local parentMapName = nil

    if mapInfo then
        mapName =
            SafeText(mapInfo.name, UNKNOWN)

        parentMapID =
            SafeNumber(mapInfo.parentMapID)
    end

    if parentMapID
        and parentMapID > 0
    then
        local parentMapInfo =
            GetMapInfo(parentMapID)

        if parentMapInfo then
            local name =
                SafeText(
                    parentMapInfo.name,
                    ""
                )

            if name ~= "" then
                parentMapName = name
            end
        end
    end

    return {
        mapID = mapID,
        mapName = mapName,
        parentMapID = parentMapID,
        parentMapName = parentMapName,
    }
end

local function GetPositionCoordinate(
    position,
    key,
    getterIndex
)
    if type(position) ~= "table" then
        return nil
    end

    local coordinate =
        SafeNumber(position[key])

    if coordinate ~= nil then
        return coordinate
    end

    if type(position.GetXY) == "function" then
        local success, x, y =
            SafeCall(
                position.GetXY,
                position
            )

        if success then
            if getterIndex == 1 then
                return SafeNumber(x)
            end

            return SafeNumber(y)
        end
    end

    return nil
end

local function CollectCoordinates(mapID)
    if mapID == nil then
        return UNKNOWN
    end

    if not C_Map
        or type(C_Map.GetPlayerMapPosition)
            ~= "function"
    then
        return UNKNOWN
    end

    local success, position =
        SafeCall(
            C_Map.GetPlayerMapPosition,
            mapID,
            "player"
        )

    if not success
        or type(position) ~= "table"
    then
        return UNKNOWN
    end

    local x =
        GetPositionCoordinate(
            position,
            "x",
            1
        )

    local y =
        GetPositionCoordinate(
            position,
            "y",
            2
        )

    if x == nil or y == nil then
        return UNKNOWN
    end

    return string.format(
        "%.1f, %.1f",
        x * 100,
        y * 100
    )
end

local function CollectHearthstoneLocation()
    if type(GetBindLocation) ~= "function" then
        return UNKNOWN
    end

    local success, bindLocation =
        SafeCall(GetBindLocation)

    if not success then
        return UNKNOWN
    end

    return SafeText(
        bindLocation,
        UNKNOWN
    )
end

function Location:Collect()
    local mapID = GetBestMapID()

    local mapDetails =
        CollectMapDetails(mapID)

    return {
        key =
            C.SECTIONS.LOCATION,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.LOCATION
            ],

        zone =
            CollectZoneText(),

        subzone =
            CollectSubZoneText(),

        mapID =
            mapDetails.mapID,

        map =
            mapDetails.mapName,

        parentMapID =
            mapDetails.parentMapID,

        parentMap =
            mapDetails.parentMapName,

        coordinates =
            CollectCoordinates(mapID),

        hearthstoneLocation =
            CollectHearthstoneLocation(),
    }
end

ns:RegisterModule(
    "Data.Location",
    Location
)

ns.Data = ns.Data or {}
ns.Data.Location = Location