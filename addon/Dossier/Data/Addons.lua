local _, ns = ...

local U = ns.utils
local C = ns.constants

local Addons = {}

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return false
    end

    return pcall(func, ...)
end

local function GetAddonCount()
    if not C_AddOns
        or type(C_AddOns.GetNumAddOns) ~= "function"
    then
        return 0
    end

    local success, count =
        SafeCall(C_AddOns.GetNumAddOns)

    if not success then
        return 0
    end

    return U.SafeNumber(count, 0)
end

local function GetAddonInfo(index)
    if not C_AddOns
        or type(C_AddOns.GetAddOnInfo) ~= "function"
    then
        return nil
    end

    local success,
        name,
        title,
        notes,
        loadable,
        reason,
        security =
        SafeCall(C_AddOns.GetAddOnInfo, index)

    if not success then
        return nil
    end

    return {
        name = name,
        title = title,
        notes = notes,
        loadable = loadable,
        reason = reason,
        security = security,
    }
end

local function GetAddonMetadata(identifier, field)
    if identifier == nil
        or type(field) ~= "string"
        or field == ""
    then
        return nil
    end

    if not C_AddOns
        or type(C_AddOns.GetAddOnMetadata) ~= "function"
    then
        return nil
    end

    local success, value =
        SafeCall(
            C_AddOns.GetAddOnMetadata,
            identifier,
            field
        )

    if success and U.IsNonEmptyString(value) then
        return value
    end

    return nil
end

local function GetAddonDisplayName(index, info)
    if info and U.IsNonEmptyString(info.title) then
        return info.title
    end

    local identifier =
        info and info.name or index

    local title =
        GetAddonMetadata(identifier, "Title")

    if U.IsNonEmptyString(title) then
        return title
    end

    if info and U.IsNonEmptyString(info.name) then
        return info.name
    end

    return string.format("Addon %d", index)
end

local function GetAddonVersion(index, info)
    local identifier =
        info and info.name or index

    return GetAddonMetadata(identifier, "Version")
end

local function NormalizeEnableState(state)
    if state == nil then
        return nil
    end

    if Enum and Enum.AddOnEnableState then
        if state == Enum.AddOnEnableState.All
            or state == Enum.AddOnEnableState.Some
        then
            return true
        end

        if state == Enum.AddOnEnableState.None then
            return false
        end
    end

    local numericState = U.ToSafeNumber(state)

    if numericState ~= nil then
        if numericState > 0 then
            return true
        end

        return false
    end

    local stateText =
        U.SafeString(state, "")

    if stateText == "All"
        or stateText == "Some"
    then
        return true
    end

    if stateText == "None" then
        return false
    end

    return nil
end

local function GetPlayerName()
    if type(UnitName) ~= "function" then
        return nil
    end

    local success, playerName =
        SafeCall(UnitName, "player")

    if success
        and U.IsNonEmptyString(playerName)
    then
        return playerName
    end

    return nil
end

local function GetAddonEnabledState(index, info)
    if not C_AddOns
        or type(C_AddOns.GetAddOnEnableState) ~= "function"
    then
        return nil, nil
    end

    local identifier =
        info and info.name or index

    local characterName = GetPlayerName()

    local success, state =
        SafeCall(
            C_AddOns.GetAddOnEnableState,
            identifier,
            characterName
        )

    if not success then
        success, state =
            SafeCall(
                C_AddOns.GetAddOnEnableState,
                identifier
            )
    end

    if not success then
        return nil, nil
    end

    return NormalizeEnableState(state), state
end

local function IsAddonLoaded(index, info)
    if not C_AddOns
        or type(C_AddOns.IsAddOnLoaded) ~= "function"
    then
        return nil
    end

    local identifier =
        info and info.name or index

    local success,
        loadedOrLoading,
        loaded =
        SafeCall(
            C_AddOns.IsAddOnLoaded,
            identifier
        )

    if not success then
        return nil
    end

    if type(loaded) == "boolean" then
        return loaded
    end

    if type(loadedOrLoading) == "boolean" then
        return loadedOrLoading
    end

    return nil
end

function Addons:Collect()
    local entries = {}
    local diagnostics = {}

    local numAddons = GetAddonCount()

    for index = 1, numAddons do
        local info = GetAddonInfo(index)

        if info
            and (
                U.IsNonEmptyString(info.name)
                or U.IsNonEmptyString(info.title)
            )
        then
            local enabled, enableState =
                GetAddonEnabledState(index, info)

            local loadable = nil

            if type(info.loadable) == "boolean" then
                loadable = info.loadable
            end

            U.SafeInsert(entries, {
                name =
                    GetAddonDisplayName(index, info),

                internalName =
                    info.name,

                version =
                    GetAddonVersion(index, info),

                enabled =
                    enabled,

                enableState =
                    enableState,

                loaded =
                    IsAddonLoaded(index, info),

                loadable =
                    loadable,

                reason =
                    info.reason,
            })
        end
    end

    table.sort(entries, function(a, b)
        local aName =
            U.SafeString(a and a.name, "")

        local bName =
            U.SafeString(b and b.name, "")

        return aName < bName
    end)

    if numAddons == 0 then
        U.SafeInsert(
            diagnostics,
            "C_AddOns.GetNumAddOns returned 0 installed AddOns."
        )
    elseif #entries == 0 then
        U.SafeInsert(
            diagnostics,
            string.format(
                "C_AddOns.GetNumAddOns returned %d AddOns, but C_AddOns.GetAddOnInfo did not return any names or titles.",
                numAddons
            )
        )
    end

    return {
        key = C.SECTIONS.ADDONS,
        title =
            C.SECTION_LABELS[C.SECTIONS.ADDONS],
        count = numAddons,
        entries = entries,
        diagnostics = diagnostics,
    }
end

ns:RegisterModule(
    "Data.Addons",
    Addons
)

ns.Data = ns.Data or {}
ns.Data.Addons = Addons