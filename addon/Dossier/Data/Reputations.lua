local _, ns = ...

local U = ns.utils
local C = ns.constants

local Reputations = {}

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end

    return pcall(fn, ...)
end

local function AddDiagnostic(
    diagnostics,
    message
)
    if type(diagnostics) ~= "table" then
        return
    end

    if not U.IsNonEmptyString(message) then
        return
    end

    U.SafeInsert(
        diagnostics,
        message
    )
end

local function GetStandingLabel(
    standingID
)
    local standing =
        U.ToSafeNumber(
            standingID
        )

    if standing == nil then
        return nil
    end

    local label =
        _G[
            "FACTION_STANDING_LABEL"
            .. tostring(standing)
        ]

    if U.IsNonEmptyString(label) then
        return label
    end

    return nil
end

local function SafeDifference(
    left,
    right
)
    left =
        U.ToSafeNumber(left)

    right =
        U.ToSafeNumber(right)

    if left == nil
        or right == nil
    then
        return nil
    end

    return left - right
end

local function GetNumFactions()
    if not C_Reputation
        or type(
            C_Reputation.GetNumFactions
        ) ~= "function"
    then
        return nil
    end

    local success, count =
        SafeCall(
            C_Reputation.GetNumFactions
        )

    if not success then
        return nil
    end

    return U.ToSafeNumber(
        count
    )
end

local function GetFactionDataByIndex(
    index
)
    if not C_Reputation
        or type(
            C_Reputation.GetFactionDataByIndex
        ) ~= "function"
    then
        return nil
    end

    local success, data =
        SafeCall(
            C_Reputation.GetFactionDataByIndex,
            index
        )

    if not success
        or type(data) ~= "table"
    then
        return nil
    end

    return data
end

local function IsFactionParagon(
    factionID
)
    factionID =
        U.ToSafeNumber(
            factionID
        )

    if factionID == nil
        or not C_Reputation
        or type(
            C_Reputation.IsFactionParagon
        ) ~= "function"
    then
        return nil
    end

    local success, result =
        SafeCall(
            C_Reputation.IsFactionParagon,
            factionID
        )

    if success
        and type(result) == "boolean"
    then
        return result
    end

    return nil
end

local function IsMajorFaction(
    factionID
)
    factionID =
        U.ToSafeNumber(
            factionID
        )

    if factionID == nil
        or not C_Reputation
        or type(
            C_Reputation.IsMajorFaction
        ) ~= "function"
    then
        return nil
    end

    local success, result =
        SafeCall(
            C_Reputation.IsMajorFaction,
            factionID
        )

    if success
        and type(result) == "boolean"
    then
        return result
    end

    return nil
end

local function GetParagonData(
    factionID
)
    factionID =
        U.ToSafeNumber(
            factionID
        )

    if factionID == nil
        or not C_Reputation
        or type(
            C_Reputation.GetFactionParagonInfo
        ) ~= "function"
    then
        return nil
    end

    local success,
        currentValue,
        threshold,
        rewardQuestID,
        hasRewardPending,
        tooLowLevelForParagon,
        paragonStorageLevel =
        SafeCall(
            C_Reputation.GetFactionParagonInfo,
            factionID
        )

    if not success then
        return nil
    end

    currentValue =
        U.ToSafeNumber(
            currentValue
        )

    threshold =
        U.ToSafeNumber(
            threshold
        )

    rewardQuestID =
        U.ToSafeNumber(
            rewardQuestID
        )

    paragonStorageLevel =
        U.ToSafeNumber(
            paragonStorageLevel
        )

    if currentValue == nil
        and threshold == nil
        and rewardQuestID == nil
        and paragonStorageLevel == nil
        and type(hasRewardPending)
            ~= "boolean"
        and type(tooLowLevelForParagon)
            ~= "boolean"
    then
        return nil
    end

    return {
        currentValue =
            currentValue,

        threshold =
            threshold,

        rewardQuestID =
            rewardQuestID,

        hasRewardPending =
            type(hasRewardPending)
                == "boolean"
            and hasRewardPending
            or nil,

        tooLowLevelForParagon =
            type(tooLowLevelForParagon)
                == "boolean"
            and tooLowLevelForParagon
            or nil,

        storageLevel =
            paragonStorageLevel,
    }
end

local function MakeEntry(
    data
)
    if type(data) ~= "table" then
        return nil
    end

    if data.isHeader == true
        and data.isHeaderWithRep
            ~= true
    then
        return nil
    end

    if not U.IsNonEmptyString(
        data.name
    )
    then
        return nil
    end

    local factionID =
        U.ToSafeNumber(
            data.factionID
        )

    local standingID =
        U.ToSafeNumber(
            data.reaction
        )

    local minValue =
        U.ToSafeNumber(
            data.currentReactionThreshold
        )

    local maxValue =
        U.ToSafeNumber(
            data.nextReactionThreshold
        )

    local currentValue =
        U.ToSafeNumber(
            data.currentStanding
        )

    local entry = {
        name =
            data.name,

        factionID =
            factionID,

        standingID =
            standingID,

        standing =
            GetStandingLabel(
                standingID
            ),

        value =
            currentValue,

        min =
            minValue,

        max =
            maxValue,

        progress =
            SafeDifference(
                currentValue,
                minValue
            ),

        nextStanding =
            SafeDifference(
                maxValue,
                minValue
            ),

        description =
            U.IsNonEmptyString(
                data.description
            )
            and data.description
            or nil,

        atWarWith =
            type(data.atWarWith)
                == "boolean"
            and data.atWarWith
            or nil,

        canToggleAtWar =
            type(data.canToggleAtWar)
                == "boolean"
            and data.canToggleAtWar
            or nil,

        isChild =
            type(data.isChild)
                == "boolean"
            and data.isChild
            or nil,

        isHeader =
            type(data.isHeader)
                == "boolean"
            and data.isHeader
            or nil,

        isHeaderWithRep =
            type(data.isHeaderWithRep)
                == "boolean"
            and data.isHeaderWithRep
            or nil,

        isWatched =
            type(data.isWatched)
                == "boolean"
            and data.isWatched
            or nil,

        hasBonusRepGain =
            type(data.hasBonusRepGain)
                == "boolean"
            and data.hasBonusRepGain
            or nil,

        canSetInactive =
            type(data.canSetInactive)
                == "boolean"
            and data.canSetInactive
            or nil,

        isAccountWide =
            type(data.isAccountWide)
                == "boolean"
            and data.isAccountWide
            or nil,
    }

    entry.isParagon =
        IsFactionParagon(
            factionID
        )

    entry.isMajorFaction =
        IsMajorFaction(
            factionID
        )

    if entry.isParagon == true then
        entry.paragon =
            GetParagonData(
                factionID
            )
    end

    return entry
end

local function ExpandCollapsedHeaders()
    local expandedNames = {}

    if not C_Reputation
        or type(
            C_Reputation.ExpandFactionHeader
        ) ~= "function"
    then
        return expandedNames
    end

    local index = 1
    local guard = 0

    while guard < 500 do
        guard =
            guard + 1

        local numFactions =
            GetNumFactions()

        if numFactions == nil
            or index > numFactions
        then
            break
        end

        local data =
            GetFactionDataByIndex(
                index
            )

        if data
            and data.isHeader == true
            and data.isCollapsed == true
        then
            if U.IsNonEmptyString(
                data.name
            )
            then
                expandedNames[
                    data.name
                ] = true
            end

            SafeCall(
                C_Reputation.ExpandFactionHeader,
                index
            )
        end

        index =
            index + 1
    end

    return expandedNames
end

local function RestoreCollapsedHeaders(
    expandedNames
)
    if type(expandedNames) ~= "table"
        or next(expandedNames) == nil
    then
        return
    end

    if not C_Reputation
        or type(
            C_Reputation.CollapseFactionHeader
        ) ~= "function"
    then
        return
    end

    local numFactions =
        GetNumFactions()

    if numFactions == nil then
        return
    end

    for index = numFactions,
        1,
        -1
    do
        local data =
            GetFactionDataByIndex(
                index
            )

        if data
            and data.isHeader == true
            and data.isCollapsed ~= true
            and U.IsNonEmptyString(
                data.name
            )
            and expandedNames[
                data.name
            ]
        then
            SafeCall(
                C_Reputation.CollapseFactionHeader,
                index
            )
        end
    end
end

local function CollectEntries(
    diagnostics
)
    local entries = {}

    if type(C_Reputation) ~= "table" then
        AddDiagnostic(
            diagnostics,
            "C_Reputation API unavailable."
        )

        return entries
    end

    if type(
        C_Reputation.GetNumFactions
    ) ~= "function"
    then
        AddDiagnostic(
            diagnostics,
            "C_Reputation.GetNumFactions API unavailable."
        )

        return entries
    end

    if type(
        C_Reputation.GetFactionDataByIndex
    ) ~= "function"
    then
        AddDiagnostic(
            diagnostics,
            "C_Reputation.GetFactionDataByIndex API unavailable."
        )

        return entries
    end

    local expandedNames =
        ExpandCollapsedHeaders()

    local numFactions =
        GetNumFactions()

    if numFactions == nil then
        AddDiagnostic(
            diagnostics,
            "C_Reputation.GetNumFactions call failed."
        )

        RestoreCollapsedHeaders(
            expandedNames
        )

        return entries
    end

    local seen = {}

    for index = 1,
        numFactions
    do
        local data =
            GetFactionDataByIndex(
                index
            )

        local entry =
            MakeEntry(
                data
            )

        if entry then
            local key = nil

            if entry.factionID
                ~= nil
            then
                key =
                    "id:"
                    .. tostring(
                        entry.factionID
                    )
            else
                key =
                    "name:"
                    .. string.lower(
                        entry.name
                    )
            end

            if not seen[key] then
                seen[key] =
                    true

                U.SafeInsert(
                    entries,
                    entry
                )
            end
        end
    end

    RestoreCollapsedHeaders(
        expandedNames
    )

    return entries
end

local function SortEntries(entries)
    table.sort(
        entries,
        function(left, right)
            if (
                left.isMajorFaction
                == true
            )
                ~= (
                    right.isMajorFaction
                    == true
                )
            then
                return
                    left.isMajorFaction
                    == true
            end

            local leftName =
                string.lower(
                    left.name
                    or ""
                )

            local rightName =
                string.lower(
                    right.name
                    or ""
                )

            if leftName ~= rightName then
                return
                    leftName
                    < rightName
            end

            return
                (
                    U.ToSafeNumber(
                        left.factionID
                    )
                    or 0
                )
                <
                (
                    U.ToSafeNumber(
                        right.factionID
                    )
                    or 0
                )
        end
    )
end

function Reputations:Collect()
    local diagnostics = {}

    local entries =
        CollectEntries(
            diagnostics
        )

    SortEntries(
        entries
    )

    U.SafeInsert(
        diagnostics,
        string.format(
            "Total reputation entries: %d",
            #entries
        )
    )

    if #entries == 0 then
        AddDiagnostic(
            diagnostics,
            "No reputation entries returned by C_Reputation."
        )
    end

    return {
        key =
            C.SECTIONS.REPUTATIONS,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.REPUTATIONS
            ],

        entries =
            entries,

        diagnostics =
            diagnostics,
    }
end

ns:RegisterModule(
    "Data.Reputations",
    Reputations
)

ns.Data = ns.Data or {}
ns.Data.Reputations = Reputations