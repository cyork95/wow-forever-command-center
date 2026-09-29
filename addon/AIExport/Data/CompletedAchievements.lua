local _, ns = ...

local U = ns.utils
local C = ns.constants

local CompletedAchievements = {}

local MAX_COMPLETED_ACHIEVEMENTS = 5000

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
            C.SECTIONS.COMPLETED_ACHIEVEMENTS,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.COMPLETED_ACHIEVEMENTS
            ],

        count =
            0,

        reportedCompletedTotal =
            nil,

        entries =
            {},

        categories =
            {},

        diagnostics =
            {},

        truncated =
            false,

        maxEntries =
            MAX_COMPLETED_ACHIEVEMENTS,
    }
end

local function ResolveReportedCompletedTotal(
    snapshot
)
    if type(GetNumCompletedAchievements)
        ~= "function"
    then
        AddDiagnostic(
            snapshot.diagnostics,
            "GetNumCompletedAchievements API unavailable."
        )

        return nil
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

        return nil
    end

    snapshot.reportedTotal =
        U.ToSafeNumber(
            total
        )

    return U.ToSafeNumber(
        completed
    )
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

local function BuildDedupeKey(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local achievementID =
        U.ToSafeNumber(
            entry.achievementID
        )

    if achievementID ~= nil then
        return string.format(
            "id:%d",
            achievementID
        )
    end

    local name =
        CleanText(
            entry.name
        )

    local categoryID =
        U.ToSafeNumber(
            entry.categoryID
        )

    if name ~= nil
        and categoryID ~= nil
    then
        return string.format(
            "name:%s:category:%d",
            name,
            categoryID
        )
    end

    return nil
end

local function BuildCompletedEntry(
    categoryID,
    categoryName,
    achievementID,
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
    isStatistic
)
    if completed ~= true then
        return nil
    end

    local cleanName =
        CleanText(name)

    if cleanName == nil then
        return nil
    end

    local entry = {
        achievementID =
            U.ToSafeNumber(
                achievementID
            ),

        name =
            cleanName,

        categoryID =
            U.ToSafeNumber(
                categoryID
            ),

        categoryName =
            CleanText(
                categoryName
            ),

        points =
            U.ToSafeNumber(
                points
            ),

        completed =
            true,

        month =
            U.ToSafeNumber(
                month
            ),

        day =
            U.ToSafeNumber(
                day
            ),

        year =
            U.ToSafeNumber(
                year
            ),

        description =
            CleanText(
                description
            ),

        flags =
            U.ToSafeNumber(
                flags
            ),

        icon =
            icon,

        rewardText =
            CleanText(
                rewardText
            ),

        earnedBy =
            CleanText(
                earnedBy
            ),
    }

    if type(isGuild) == "boolean" then
        entry.isGuild =
            isGuild
    end

    if type(wasEarnedByMe) == "boolean" then
        entry.wasEarnedByMe =
            wasEarnedByMe
    end

    if type(isStatistic) == "boolean" then
        entry.isStatistic =
            isStatistic
    end

    return entry
end

local function CollectCompletedFromCategory(
    snapshot,
    seen,
    categoryID,
    categoryName
)
    local total,
        completed =
        ResolveCategoryCounts(
            categoryID
        )

    if total == nil
        or total <= 0
    then
        return
    end

    if completed ~= nil
        and completed <= 0
    then
        return
    end

    if type(GetAchievementInfo)
        ~= "function"
    then
        AddDiagnostic(
            snapshot.diagnostics,
            "GetAchievementInfo API unavailable."
        )

        return
    end

    for achievementIndex = 1,
        total
    do
        if snapshot.truncated then
            return
        end

        local success,
            achievementID,
            name,
            points,
            isCompleted,
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
                categoryID,
                achievementIndex
            )

        if success
            and isCompleted == true
        then
            local entry =
                BuildCompletedEntry(
                    categoryID,
                    categoryName,
                    achievementID,
                    name,
                    points,
                    isCompleted,
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
                    isStatistic
                )

            local dedupeKey =
                BuildDedupeKey(
                    entry
                )

            if entry
                and dedupeKey
                and not seen[dedupeKey]
            then
                seen[dedupeKey] =
                    true

                U.SafeInsert(
                    snapshot.entries,
                    entry
                )

                if #snapshot.entries
                    >= MAX_COMPLETED_ACHIEVEMENTS
                then
                    snapshot.truncated =
                        true

                    return
                end
            end
        end
    end
end

local function CollectCategories(
    snapshot
)
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

    local success, categoryList =
        SafeCall(
            GetCategoryList
        )

    if not success
        or type(categoryList) ~= "table"
    then
        AddDiagnostic(
            snapshot.diagnostics,
            "GetCategoryList call failed."
        )

        return
    end

    local seen = {}

    for _, rawCategoryID
        in ipairs(categoryList)
    do
        if snapshot.truncated then
            break
        end

        local categoryID =
            U.ToSafeNumber(
                rawCategoryID
            )

        if categoryID ~= nil then
            local categoryName = nil

            local infoSuccess,
                name =
                SafeCall(
                    GetCategoryInfo,
                    categoryID
                )

            if infoSuccess then
                categoryName =
                    CleanText(name)
            end

            snapshot.categories[
                categoryID
            ] = categoryName

            CollectCompletedFromCategory(
                snapshot,
                seen,
                categoryID,
                categoryName
            )
        end
    end
end

function CompletedAchievements:Collect()
    local snapshot =
        NewSnapshot()

    snapshot.reportedCompletedTotal =
        ResolveReportedCompletedTotal(
            snapshot
        )

    CollectCategories(
        snapshot
    )

    snapshot.count =
        #snapshot.entries

    if snapshot.reportedCompletedTotal
        ~= nil
        and snapshot.count
            < snapshot.reportedCompletedTotal
        and not snapshot.truncated
    then
        AddDiagnostic(
            snapshot.diagnostics,
            string.format(
                "Enumerated %d completed achievements while the API reports %d completed achievements.",
                snapshot.count,
                snapshot.reportedCompletedTotal
            )
        )
    end

    return snapshot
end

ns:RegisterModule(
    "Data.CompletedAchievements",
    CompletedAchievements
)

ns.Data = ns.Data or {}
ns.Data.CompletedAchievements =
    CompletedAchievements