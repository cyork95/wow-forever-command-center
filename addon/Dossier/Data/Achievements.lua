local _, ns = ...

local U = ns.utils
local C = ns.constants

local Achievements = {}

local MAX_RECENT_ACHIEVEMENTS = 10

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

local function CleanText(value)
    if not U.IsNonEmptyString(value) then
        return nil
    end

    local text =
        U.Trim(
            U.SafeString(
                value,
                ""
            )
        )

    if text == "" then
        return nil
    end

    return text
end

local function NewSnapshot()
    return {
        key =
            C.SECTIONS.ACHIEVEMENTS,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.ACHIEVEMENTS
            ],

        points =
            nil,

        total =
            nil,

        completed =
            nil,

        recent = {
            count = 0,
            entries = {},
        },

        categories = {
            count = 0,
            entries = {},
        },

        tracked = {
            count = 0,
            entries = {},
        },

        diagnostics = {},
    }
end

local function CollectSummary(snapshot)
    if type(GetTotalAchievementPoints)
        == "function"
    then
        local success, points =
            SafeCall(
                GetTotalAchievementPoints
            )

        if success then
            snapshot.points =
                U.ToSafeNumber(
                    points
                )
        else
            AddDiagnostic(
                snapshot.diagnostics,
                "GetTotalAchievementPoints call failed."
            )
        end
    else
        AddDiagnostic(
            snapshot.diagnostics,
            "GetTotalAchievementPoints API unavailable."
        )
    end

    if type(GetNumCompletedAchievements)
        ~= "function"
    then
        AddDiagnostic(
            snapshot.diagnostics,
            "GetNumCompletedAchievements API unavailable."
        )

        return
    end

    local success,
        total,
        completed =
        SafeCall(
            GetNumCompletedAchievements
        )

    if not success then
        AddDiagnostic(
            snapshot.diagnostics,
            "GetNumCompletedAchievements call failed."
        )

        return
    end

    snapshot.total =
        U.ToSafeNumber(
            total
        )

    snapshot.completed =
        U.ToSafeNumber(
            completed
        )
end

local function BuildAchievementEntry(
    achievementID
)
    local safeAchievementID =
        U.ToSafeNumber(
            achievementID
        )

    if safeAchievementID == nil then
        return nil
    end

    local entry = {
        achievementID =
            safeAchievementID,
    }

    if type(GetAchievementInfo)
        ~= "function"
    then
        return entry
    end

    local success,
        returnedID,
        name,
        points,
        completed,
        month,
        day,
        year,
        description,
        flags,
        icon,
        rewardText,
        isGuild,
        wasEarnedByMe,
        earnedBy,
        isStatistic =
        SafeCall(
            GetAchievementInfo,
            safeAchievementID
        )

    if not success then
        return entry
    end

    entry.achievementID =
        U.ToSafeNumber(
            returnedID
        )
        or safeAchievementID

    entry.name =
        CleanText(name)

    entry.points =
        U.ToSafeNumber(
            points
        )

    if type(completed)
        == "boolean"
    then
        entry.completed =
            completed
    end

    entry.month =
        U.ToSafeNumber(
            month
        )

    entry.day =
        U.ToSafeNumber(
            day
        )

    entry.year =
        U.ToSafeNumber(
            year
        )

    entry.description =
        CleanText(
            description
        )

    entry.flags =
        U.ToSafeNumber(
            flags
        )

    entry.icon =
        icon

    entry.rewardText =
        CleanText(
            rewardText
        )

    if type(isGuild)
        == "boolean"
    then
        entry.isGuild =
            isGuild
    end

    if type(wasEarnedByMe)
        == "boolean"
    then
        entry.wasEarnedByMe =
            wasEarnedByMe
    end

    entry.earnedBy =
        CleanText(
            earnedBy
        )

    if type(isStatistic)
        == "boolean"
    then
        entry.isStatistic =
            isStatistic
    end

    return entry
end

local function AppendAchievementEntry(
    entries,
    achievementID
)
    local entry =
        BuildAchievementEntry(
            achievementID
        )

    if not entry then
        return
    end

    if U.ToSafeNumber(
        entry.achievementID
    ) == nil
    then
        return
    end

    U.SafeInsert(
        entries,
        entry
    )
end

local function CollectRecent(snapshot)
    if type(GetLatestCompletedAchievements)
        ~= "function"
    then
        AddDiagnostic(
            snapshot.diagnostics,
            "GetLatestCompletedAchievements API unavailable."
        )

        return
    end

    local results = {
        SafeCall(
            GetLatestCompletedAchievements
        )
    }

    if results[1] ~= true then
        AddDiagnostic(
            snapshot.diagnostics,
            "GetLatestCompletedAchievements call failed."
        )

        return
    end

    local entries =
        snapshot.recent.entries

    for index = 2, #results do
        if #entries >= MAX_RECENT_ACHIEVEMENTS then
            break
        end

        local value =
            results[index]

        if type(value) == "table" then
            for _, nestedValue
                in ipairs(value)
            do
                if #entries
                    >= MAX_RECENT_ACHIEVEMENTS
                then
                    break
                end

                AppendAchievementEntry(
                    entries,
                    nestedValue
                )
            end
        else
            AppendAchievementEntry(
                entries,
                value
            )
        end
    end

    snapshot.recent.count =
        #entries
end

local function ResolveCategoryCounts(
    categoryID
)
    if type(GetCategoryNumAchievements)
        ~= "function"
    then
        return nil, nil, nil
    end

    local success,
        total,
        completed,
        incomplete =
        SafeCall(
            GetCategoryNumAchievements,
            categoryID,
            true
        )

    if not success then
        return nil, nil, nil
    end

    total =
        U.ToSafeNumber(
            total
        )

    completed =
        U.ToSafeNumber(
            completed
        )

    incomplete =
        U.ToSafeNumber(
            incomplete
        )

    if incomplete == nil
        and total ~= nil
        and completed ~= nil
    then
        incomplete =
            math.max(
                total - completed,
                0
            )
    end

    return total,
        completed,
        incomplete
end

local function CollectCategories(snapshot)
    if type(GetCategoryList)
        ~= "function"
    then
        AddDiagnostic(
            snapshot.diagnostics,
            "GetCategoryList API unavailable."
        )

        return
    end

    if type(GetCategoryInfo)
        ~= "function"
    then
        AddDiagnostic(
            snapshot.diagnostics,
            "GetCategoryInfo API unavailable."
        )

        return
    end

    if type(GetCategoryNumAchievements)
        ~= "function"
    then
        AddDiagnostic(
            snapshot.diagnostics,
            "GetCategoryNumAchievements API unavailable."
        )

        return
    end

    local success, categoryList =
        SafeCall(
            GetCategoryList
        )

    if not success
        or type(categoryList)
            ~= "table"
    then
        AddDiagnostic(
            snapshot.diagnostics,
            "GetCategoryList call failed."
        )

        return
    end

    local entries =
        snapshot.categories.entries

    for _, rawCategoryID
        in ipairs(categoryList)
    do
        local categoryID =
            U.ToSafeNumber(
                rawCategoryID
            )

        if categoryID ~= nil then
            local infoSuccess,
                name,
                parentCategoryID,
                flags =
                SafeCall(
                    GetCategoryInfo,
                    categoryID
                )

            if infoSuccess then
                name =
                    CleanText(name)

                parentCategoryID =
                    U.ToSafeNumber(
                        parentCategoryID
                    )

                flags =
                    U.ToSafeNumber(
                        flags
                    )

                local total,
                    completed,
                    incomplete =
                    ResolveCategoryCounts(
                        categoryID
                    )

                if name ~= nil
                    and total ~= nil
                    and total > 0
                then
                    U.SafeInsert(
                        entries,
                        {
                            categoryID =
                                categoryID,

                            name =
                                name,

                            parentCategoryID =
                                parentCategoryID,

                            flags =
                                flags,

                            total =
                                total,

                            completed =
                                completed,

                            incomplete =
                                incomplete,
                        }
                    )
                end
            end
        end
    end

    snapshot.categories.count =
        #entries
end

local function AddTrackedID(
    trackedIDs,
    seen,
    value
)
    local achievementID =
        U.ToSafeNumber(
            value
        )

    if achievementID == nil
        or seen[achievementID]
    then
        return
    end

    seen[achievementID] =
        true

    U.SafeInsert(
        trackedIDs,
        achievementID
    )
end

local function AddTrackedValues(
    trackedIDs,
    seen,
    ...
)
    for index = 1,
        select("#", ...)
    do
        local value =
            select(
                index,
                ...
            )

        if type(value)
            == "table"
        then
            for _, nestedValue
                in ipairs(value)
            do
                AddTrackedID(
                    trackedIDs,
                    seen,
                    nestedValue
                )
            end
        else
            AddTrackedID(
                trackedIDs,
                seen,
                value
            )
        end
    end
end

local function CollectTracked(snapshot)
    local trackedIDs = {}
    local seen = {}

    if type(GetTrackedAchievements)
        == "function"
    then
        local results = {
            SafeCall(
                GetTrackedAchievements
            )
        }

        if results[1] == true then
            for index = 2,
                #results
            do
                AddTrackedValues(
                    trackedIDs,
                    seen,
                    results[index]
                )
            end
        else
            AddDiagnostic(
                snapshot.diagnostics,
                "GetTrackedAchievements call failed."
            )
        end
    end

    local reportedCount = nil

    if type(GetNumTrackedAchievements)
        == "function"
    then
        local success, count =
            SafeCall(
                GetNumTrackedAchievements
            )

        if success then
            reportedCount =
                U.ToSafeNumber(
                    count
                )
        end
    end

    local entries =
        snapshot.tracked.entries

    for _, achievementID
        in ipairs(trackedIDs)
    do
        AppendAchievementEntry(
            entries,
            achievementID
        )
    end

    snapshot.tracked.count =
        #entries

    if snapshot.tracked.count == 0
        and reportedCount ~= nil
    then
        snapshot.tracked.count =
            reportedCount
    end
end

function Achievements:Collect()
    local snapshot =
        NewSnapshot()

    CollectSummary(
        snapshot
    )

    CollectRecent(
        snapshot
    )

    CollectCategories(
        snapshot
    )

    CollectTracked(
        snapshot
    )

    return snapshot
end

ns:RegisterModule(
    "Data.Achievements",
    Achievements
)

ns.Data = ns.Data or {}
ns.Data.Achievements = Achievements