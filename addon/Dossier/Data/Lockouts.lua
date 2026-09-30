local _, ns = ...

local U = ns.utils
local C = ns.constants

local Lockouts = {}

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end

    return pcall(fn, ...)
end

local function SafeNumber(value)
    return U.ToSafeNumber(value)
end

local function SafeString(value, fallback)
    local text =
        U.SafeString(
            value,
            fallback or ""
        )

    if U.IsNonEmptyString(text) then
        return text
    end

    return fallback or ""
end

local function BooleanOrNil(value)
    if type(value) == "boolean" then
        return value
    end

    return nil
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

local function Now()
    if type(time) ~= "function" then
        return nil
    end

    local success, timestamp =
        SafeCall(time)

    if not success then
        return nil
    end

    return SafeNumber(timestamp)
end

local function FormatResetSeconds(
    resetSeconds
)
    local seconds =
        SafeNumber(resetSeconds)

    if seconds == nil then
        return nil
    end

    if seconds < 0 then
        seconds = 0
    end

    seconds =
        math.floor(seconds)

    if seconds < 60 then
        return string.format(
            "%ds",
            seconds
        )
    end

    if seconds < 3600 then
        local minutes =
            math.floor(
                seconds / 60
            )

        local remainingSeconds =
            seconds % 60

        return string.format(
            "%dm %ds",
            minutes,
            remainingSeconds
        )
    end

    if seconds < 86400 then
        local hours =
            math.floor(
                seconds / 3600
            )

        local minutes =
            math.floor(
                (seconds % 3600) / 60
            )

        return string.format(
            "%dh %dm",
            hours,
            minutes
        )
    end

    local days =
        math.floor(
            seconds / 86400
        )

    local hours =
        math.floor(
            (seconds % 86400) / 3600
        )

    return string.format(
        "%dd %dh",
        days,
        hours
    )
end

local function RequestRefresh(
    diagnostics
)
    if type(RequestRaidInfo) ~= "function" then
        AddDiagnostic(
            diagnostics,
            "RequestRaidInfo API unavailable."
        )

        return false
    end

    local success =
        SafeCall(RequestRaidInfo)

    if not success then
        AddDiagnostic(
            diagnostics,
            "RequestRaidInfo call failed."
        )
    end

    return success == true
end

local function CollectEncounters(
    instanceIndex,
    numEncounters,
    diagnostics
)
    local encounters = {}

    local encounterCount =
        SafeNumber(numEncounters)
        or 0

    if encounterCount <= 0 then
        return encounters
    end

    if type(GetSavedInstanceEncounterInfo)
        ~= "function"
    then
        AddDiagnostic(
            diagnostics,
            "GetSavedInstanceEncounterInfo API unavailable."
        )

        return encounters
    end

    for encounterIndex = 1,
        encounterCount
    do
        local success,
            name,
            fileDataID,
            isKilled =
            SafeCall(
                GetSavedInstanceEncounterInfo,
                instanceIndex,
                encounterIndex
            )

        if success then
            U.SafeInsert(
                encounters,
                {
                    index =
                        encounterIndex,

                    name =
                        U.IsNonEmptyString(name)
                        and SafeString(name)
                        or nil,

                    fileDataID =
                        SafeNumber(
                            fileDataID
                        ),

                    isKilled =
                        BooleanOrNil(
                            isKilled
                        ),
                }
            )
        else
            AddDiagnostic(
                diagnostics,
                string.format(
                    "GetSavedInstanceEncounterInfo failed for instance %d encounter %d.",
                    instanceIndex,
                    encounterIndex
                )
            )
        end
    end

    return encounters
end

local function CollectSavedInstances(
    result
)
    if type(GetNumSavedInstances)
        ~= "function"
    then
        AddDiagnostic(
            result.diagnostics,
            "GetNumSavedInstances API unavailable."
        )

        return
    end

    if type(GetSavedInstanceInfo)
        ~= "function"
    then
        AddDiagnostic(
            result.diagnostics,
            "GetSavedInstanceInfo API unavailable."
        )

        return
    end

    local countSuccess, count =
        SafeCall(
            GetNumSavedInstances
        )

    if not countSuccess then
        AddDiagnostic(
            result.diagnostics,
            "GetNumSavedInstances call failed."
        )

        return
    end

    local savedCount =
        SafeNumber(count)
        or 0

    for index = 1, savedCount do
        local success,
            name,
            lockoutID,
            resetSeconds,
            difficultyID,
            locked,
            extended,
            instanceIDMostSig,
            isRaid,
            maxPlayers,
            difficultyName,
            numEncounters,
            encounterProgress,
            extendDisabled,
            instanceID =
            SafeCall(
                GetSavedInstanceInfo,
                index
            )

        if success
            and U.IsNonEmptyString(name)
        then
            local safeResetSeconds =
                SafeNumber(
                    resetSeconds
                )

            local safeNumEncounters =
                SafeNumber(
                    numEncounters
                )

            local entry = {
                index =
                    index,

                name =
                    SafeString(name),

                lockoutID =
                    SafeNumber(
                        lockoutID
                    ),

                id =
                    SafeNumber(
                        lockoutID
                    ),

                resetSeconds =
                    safeResetSeconds,

                resetText =
                    FormatResetSeconds(
                        safeResetSeconds
                    ),

                difficultyID =
                    SafeNumber(
                        difficultyID
                    ),

                difficultyName =
                    U.IsNonEmptyString(
                        difficultyName
                    )
                    and SafeString(
                        difficultyName
                    )
                    or nil,

                locked =
                    BooleanOrNil(
                        locked
                    ),

                extended =
                    BooleanOrNil(
                        extended
                    ),

                extendDisabled =
                    BooleanOrNil(
                        extendDisabled
                    ),

                isRaid =
                    BooleanOrNil(
                        isRaid
                    ),

                maxPlayers =
                    SafeNumber(
                        maxPlayers
                    ),

                numEncounters =
                    safeNumEncounters,

                encounterProgress =
                    SafeNumber(
                        encounterProgress
                    ),

                instanceID =
                    SafeNumber(
                        instanceID
                    )
                    or SafeNumber(
                        instanceIDMostSig
                    ),

                encounters = {},
            }

            entry.encounters =
                CollectEncounters(
                    index,
                    safeNumEncounters,
                    result.diagnostics
                )

            U.SafeInsert(
                result.instances.entries,
                entry
            )
        elseif not success then
            AddDiagnostic(
                result.diagnostics,
                string.format(
                    "GetSavedInstanceInfo failed for index %d.",
                    index
                )
            )
        end
    end

    result.instances.count =
        #result.instances.entries
end

local function CollectWorldBosses(
    result
)
    if type(GetNumSavedWorldBosses)
        ~= "function"
    then
        AddDiagnostic(
            result.diagnostics,
            "GetNumSavedWorldBosses API unavailable."
        )

        return
    end

    if type(GetSavedWorldBossInfo)
        ~= "function"
    then
        AddDiagnostic(
            result.diagnostics,
            "GetSavedWorldBossInfo API unavailable."
        )

        return
    end

    local countSuccess, count =
        SafeCall(
            GetNumSavedWorldBosses
        )

    if not countSuccess then
        AddDiagnostic(
            result.diagnostics,
            "GetNumSavedWorldBosses call failed."
        )

        return
    end

    local savedCount =
        SafeNumber(count)
        or 0

    for index = 1, savedCount do
        local success,
            name,
            worldBossID,
            resetSeconds =
            SafeCall(
                GetSavedWorldBossInfo,
                index
            )

        if success
            and U.IsNonEmptyString(name)
        then
            local safeResetSeconds =
                SafeNumber(
                    resetSeconds
                )

            U.SafeInsert(
                result.worldBosses.entries,
                {
                    index =
                        index,

                    name =
                        SafeString(name),

                    worldBossID =
                        SafeNumber(
                            worldBossID
                        ),

                    resetSeconds =
                        safeResetSeconds,

                    resetText =
                        FormatResetSeconds(
                            safeResetSeconds
                        ),
                }
            )
        elseif not success then
            AddDiagnostic(
                result.diagnostics,
                string.format(
                    "GetSavedWorldBossInfo failed for index %d.",
                    index
                )
            )
        end
    end

    result.worldBosses.count =
        #result.worldBosses.entries
end

local function NewResult()
    return {
        key =
            C.SECTIONS.LOCKOUTS,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.LOCKOUTS
            ],

        requestedRefresh =
            false,

        cached =
            false,

        lastUpdated =
            nil,

        instances = {
            count = 0,
            entries = {},
        },

        worldBosses = {
            count = 0,
            entries = {},
        },

        diagnostics = {},
    }
end

function Lockouts:Collect(options)
    local result =
        NewResult()

    local optionsTable =
        type(options) == "table"
        and options
        or {}

    if optionsTable.requestRefresh
        ~= false
    then
        result.requestedRefresh =
            RequestRefresh(
                result.diagnostics
            )
    end

    CollectSavedInstances(
        result
    )

    CollectWorldBosses(
        result
    )

    local useCache =
        optionsTable.useCache
        ~= false

    local db =
        ns.state
        and ns.state.db

    local cache =
        db
        and db.lockoutsCache

    local hasLiveData =
        result.instances.count > 0
        or result.worldBosses.count > 0

    if useCache
        and not hasLiveData
        and type(cache) == "table"
        and cache.lastUpdated ~= nil
    then
        if type(cache.instances)
            == "table"
        then
            result.instances =
                cache.instances
        end

        if type(cache.worldBosses)
            == "table"
        then
            result.worldBosses =
                cache.worldBosses
        end

        result.cached = true

        result.lastUpdated =
            cache.lastUpdated
    else
        result.lastUpdated =
            Now()
    end

    return result
end

function Lockouts:UpdateCacheFromLive()
    local snapshot =
        self:Collect({
            useCache = false,
            requestRefresh = false,
        })

    snapshot.cached = false

    snapshot.lastUpdated =
        Now()
        or snapshot.lastUpdated

    if ns.state
        and type(ns.state.db) == "table"
    then
        ns.state.db.lockoutsCache = {
            lastUpdated =
                snapshot.lastUpdated,

            instances =
                snapshot.instances,

            worldBosses =
                snapshot.worldBosses,
        }
    end

    return snapshot
end

Lockouts.FormatResetSeconds =
    FormatResetSeconds

ns:RegisterModule(
    "Data.Lockouts",
    Lockouts
)

ns.Data = ns.Data or {}
ns.Data.Lockouts = Lockouts