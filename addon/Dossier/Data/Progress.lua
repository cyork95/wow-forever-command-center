local _, ns = ...

local U = ns.utils
local C = ns.constants

local Progress = {}

local PVP_BRACKETS = {
    {
        id = 1,
        label = "2v2",
    },
    {
        id = 2,
        label = "3v3",
    },
    {
        id = 3,
        label = "Rated Battleground",
    },
    {
        id = 4,
        label = "Solo Shuffle",
    },
    {
        id = 7,
        label = "Battleground Blitz",
    },
}

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end

    return pcall(fn, ...)
end

local function SafeNumber(value)
    return U.ToSafeNumber(value)
end

local function SafeString(value)
    if U.IsNonEmptyString(value) then
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

local function FirstNumber(...)
    for index = 1, select("#", ...) do
        local value =
            SafeNumber(
                select(index, ...)
            )

        if value ~= nil then
            return value
        end
    end

    return nil
end

local function FirstBoolean(...)
    for index = 1, select("#", ...) do
        local value =
            select(index, ...)

        if type(value) == "boolean" then
            return value
        end
    end

    return nil
end

local function FirstString(...)
    for index = 1, select("#", ...) do
        local value =
            SafeString(
                select(index, ...)
            )

        if value ~= nil then
            return value
        end
    end

    return nil
end

local function HasPositiveNumber(value)
    local numberValue =
        SafeNumber(value)

    return numberValue ~= nil
        and numberValue > 0
end

local function CopySummaryFields(summary)
    if type(summary) ~= "table" then
        return nil
    end

    local copy = {}

    local allowedFields = {
        "currentSeasonScore",
        "overallScore",
        "rating",
        "seasonScore",
        "bestSeasonScore",
        "bestRunLevel",
        "numCompletedDungeonRuns",
        "numDungeonRuns",
    }

    for _, field
        in ipairs(allowedFields)
    do
        local value =
            summary[field]

        if type(value) == "number"
            or type(value) == "string"
            or type(value) == "boolean"
        then
            copy[field] = value
        end
    end

    if next(copy) == nil then
        return nil
    end

    return copy
end

local function NormalizeRun(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local run = {
        mapChallengeModeID =
            FirstNumber(
                entry.mapChallengeModeID,
                entry.challengeModeID,
                entry.mapID
            ),

        challengeModeName =
            FirstString(
                entry.challengeModeName,
                entry.mapName,
                entry.name
            ),

        bestRunLevel =
            FirstNumber(
                entry.bestRunLevel,
                entry.level,
                entry.mythicLevel
            ),

        score =
            FirstNumber(
                entry.score,
                entry.rating,
                entry.dungeonScore
            ),

        finishedSuccess =
            FirstBoolean(
                entry.finishedSuccess,
                entry.completed
            ),
    }

    if run.finishedSuccess == nil then
        local completedInTime =
            SafeNumber(
                entry.completedInTime
            )

        if completedInTime ~= nil then
            run.finishedSuccess =
                completedInTime > 0
        end
    end

    if run.mapChallengeModeID ~= nil
        or run.challengeModeName ~= nil
        or run.bestRunLevel ~= nil
        or run.score ~= nil
        or run.finishedSuccess ~= nil
    then
        return run
    end

    return nil
end

local function RunKey(run)
    if type(run) ~= "table" then
        return nil
    end

    return table.concat(
        {
            tostring(
                run.mapChallengeModeID
                or ""
            ),

            tostring(
                run.challengeModeName
                or ""
            ),

            tostring(
                run.bestRunLevel
                or ""
            ),

            tostring(
                run.score
                or ""
            ),
        },
        ":"
    )
end

local function AddRun(
    runs,
    seenRuns,
    run
)
    if type(run) ~= "table" then
        return
    end

    local key =
        RunKey(run)

    if key
        and seenRuns[key]
    then
        return
    end

    if key then
        seenRuns[key] = true
    end

    U.SafeInsert(
        runs,
        run
    )
end

local function AppendRuns(
    runs,
    seenRuns,
    source
)
    if type(source) ~= "table" then
        return
    end

    for _, entry
        in pairs(source)
    do
        local run =
            NormalizeRun(entry)

        if run then
            AddRun(
                runs,
                seenRuns,
                run
            )
        end
    end
end

local function CollectMapScores(
    mythicPlus,
    diagnostics,
    seenRuns
)
    if not C_ChallengeMode
        or type(
            C_ChallengeMode.GetMapScoreInfo
        ) ~= "function"
    then
        return
    end

    local success, scores =
        SafeCall(
            C_ChallengeMode.GetMapScoreInfo
        )

    if not success then
        AddDiagnostic(
            diagnostics,
            "C_ChallengeMode.GetMapScoreInfo call failed."
        )

        return
    end

    if type(scores) ~= "table" then
        return
    end

    for _, scoreInfo
        in pairs(scores)
    do
        if type(scoreInfo) == "table" then
            local mapID =
                SafeNumber(
                    scoreInfo.mapChallengeModeID
                )

            local mapName =
                SafeString(
                    scoreInfo.name
                )

            if (
                mapName == nil
                or mapName == ""
            )
                and mapID ~= nil
                and type(
                    C_ChallengeMode.GetMapUIInfo
                ) == "function"
            then
                local mapSuccess,
                    resolvedName =
                    SafeCall(
                        C_ChallengeMode.GetMapUIInfo,
                        mapID
                    )

                if mapSuccess
                    and U.IsNonEmptyString(
                        resolvedName
                    )
                then
                    mapName =
                        resolvedName
                end
            end

            local run = {
                mapChallengeModeID =
                    mapID,

                challengeModeName =
                    mapName,

                bestRunLevel =
                    SafeNumber(
                        scoreInfo.level
                    ),

                score =
                    SafeNumber(
                        scoreInfo.dungeonScore
                    ),

                finishedSuccess =
                    SafeNumber(
                        scoreInfo.completedInTime
                    ) == 1,
            }

            if HasPositiveNumber(
                run.bestRunLevel
            )
                or HasPositiveNumber(
                    run.score
                )
            then
                AddRun(
                    mythicPlus.runs,
                    seenRuns,
                    run
                )
            end
        end
    end
end

local function CollectMythicPlus(result)
    local mythicPlus =
        result.mythicPlus

    local seenRuns = {}

    if C_ChallengeMode
        and type(
            C_ChallengeMode.GetOverallDungeonScore
        ) == "function"
    then
        local success, score =
            SafeCall(
                C_ChallengeMode.GetOverallDungeonScore
            )

        if success then
            score =
                SafeNumber(score)

            if HasPositiveNumber(score) then
                mythicPlus.overallScore =
                    score
            end
        else
            AddDiagnostic(
                result.diagnostics,
                "C_ChallengeMode.GetOverallDungeonScore call failed."
            )
        end
    end

    CollectMapScores(
        mythicPlus,
        result.diagnostics,
        seenRuns
    )

    if C_PlayerInfo
        and type(
            C_PlayerInfo.GetPlayerMythicPlusRatingSummary
        ) == "function"
    then
        local success, summary =
            SafeCall(
                C_PlayerInfo.GetPlayerMythicPlusRatingSummary,
                "player"
            )

        if success
            and type(summary) == "table"
        then
            mythicPlus.summary =
                CopySummaryFields(
                    summary
                )

            local seasonScore =
                FirstNumber(
                    summary.currentSeasonScore,
                    summary.seasonScore,
                    summary.rating
                )

            if HasPositiveNumber(
                seasonScore
            ) then
                mythicPlus.seasonScore =
                    seasonScore
            end

            if mythicPlus.overallScore
                == nil
            then
                local overallScore =
                    SafeNumber(
                        summary.overallScore
                    )

                if HasPositiveNumber(
                    overallScore
                ) then
                    mythicPlus.overallScore =
                        overallScore
                end
            end

            AppendRuns(
                mythicPlus.runs,
                seenRuns,
                summary.runs
            )

            AppendRuns(
                mythicPlus.runs,
                seenRuns,
                summary.mapScores
            )

            AppendRuns(
                mythicPlus.runs,
                seenRuns,
                summary.dungeonScores
            )

            AppendRuns(
                mythicPlus.runs,
                seenRuns,
                summary.completedRuns
            )
        elseif not success then
            AddDiagnostic(
                result.diagnostics,
                "C_PlayerInfo.GetPlayerMythicPlusRatingSummary call failed."
            )
        end
    end

    mythicPlus.available =
        HasPositiveNumber(
            mythicPlus.overallScore
        )
        or HasPositiveNumber(
            mythicPlus.seasonScore
        )
        or #mythicPlus.runs > 0
end

local function CollectHonor(result)
    local pvp =
        result.pvp

    if type(UnitHonorLevel)
        == "function"
    then
        local success, value =
            SafeCall(
                UnitHonorLevel,
                "player"
            )

        if success then
            pvp.honorLevel =
                SafeNumber(value)
        else
            AddDiagnostic(
                result.diagnostics,
                "UnitHonorLevel call failed."
            )
        end
    end

    if type(UnitHonor)
        == "function"
    then
        local success, value =
            SafeCall(
                UnitHonor,
                "player"
            )

        if success then
            pvp.honor =
                SafeNumber(value)
        else
            AddDiagnostic(
                result.diagnostics,
                "UnitHonor call failed."
            )
        end
    end

    if type(UnitHonorMax)
        == "function"
    then
        local success, value =
            SafeCall(
                UnitHonorMax,
                "player"
            )

        if success then
            pvp.honorMax =
                SafeNumber(value)
        else
            AddDiagnostic(
                result.diagnostics,
                "UnitHonorMax call failed."
            )
        end
    end

    if pvp.honorLevel ~= nil
        or pvp.honor ~= nil
        or pvp.honorMax ~= nil
    then
        pvp.available = true
    end
end

local function HasBracketData(bracket)
    return bracket.rating ~= nil
        or bracket.seasonBest ~= nil
        or bracket.weeklyBest ~= nil
        or bracket.seasonPlayed ~= nil
        or bracket.seasonWon ~= nil
        or bracket.weeklyPlayed ~= nil
        or bracket.weeklyWon ~= nil
        or bracket.tier ~= nil
        or bracket.ranking ~= nil
        or bracket.roundsSeasonPlayed ~= nil
        or bracket.roundsSeasonWon ~= nil
        or bracket.roundsWeeklyPlayed ~= nil
        or bracket.roundsWeeklyWon ~= nil
end

local function CollectRatedPvP(result)
    if type(GetPersonalRatedInfo)
        ~= "function"
    then
        return
    end

    for _, candidate
        in ipairs(PVP_BRACKETS)
    do
        local success,
            rating,
            seasonBest,
            weeklyBest,
            seasonPlayed,
            seasonWon,
            weeklyPlayed,
            weeklyWon,
            _,
            tier,
            ranking,
            roundsSeasonPlayed,
            roundsSeasonWon,
            roundsWeeklyPlayed,
            roundsWeeklyWon =
            SafeCall(
                GetPersonalRatedInfo,
                candidate.id
            )

        if success then
            local bracket = {
                id =
                    candidate.id,

                label =
                    candidate.label,

                rating =
                    SafeNumber(rating),

                seasonBest =
                    SafeNumber(
                        seasonBest
                    ),

                weeklyBest =
                    SafeNumber(
                        weeklyBest
                    ),

                seasonPlayed =
                    SafeNumber(
                        seasonPlayed
                    ),

                seasonWon =
                    SafeNumber(
                        seasonWon
                    ),

                weeklyPlayed =
                    SafeNumber(
                        weeklyPlayed
                    ),

                weeklyWon =
                    SafeNumber(
                        weeklyWon
                    ),

                tier =
                    SafeNumber(tier),

                ranking =
                    SafeNumber(ranking),

                roundsSeasonPlayed =
                    SafeNumber(
                        roundsSeasonPlayed
                    ),

                roundsSeasonWon =
                    SafeNumber(
                        roundsSeasonWon
                    ),

                roundsWeeklyPlayed =
                    SafeNumber(
                        roundsWeeklyPlayed
                    ),

                roundsWeeklyWon =
                    SafeNumber(
                        roundsWeeklyWon
                    ),
            }

            if HasBracketData(bracket) then
                U.SafeInsert(
                    result.pvp.brackets,
                    bracket
                )

                result.pvp.available =
                    true
            end
        else
            AddDiagnostic(
                result.diagnostics,
                string.format(
                    "GetPersonalRatedInfo call failed for bracket %d.",
                    candidate.id
                )
            )
        end
    end
end

function Progress:Collect()
    local result = {
        key =
            C.SECTIONS.PROGRESS,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.PROGRESS
            ],

        mythicPlus = {
            available = false,
            overallScore = nil,
            seasonScore = nil,
            runs = {},
            summary = nil,
        },

        pvp = {
            available = false,
            honorLevel = nil,
            honor = nil,
            honorMax = nil,
            brackets = {},
        },

        diagnostics = {},
    }

    CollectMythicPlus(result)
    CollectHonor(result)
    CollectRatedPvP(result)

    return result
end

ns:RegisterModule(
    "Data.Progress",
    Progress
)

ns.Data = ns.Data or {}
ns.Data.Progress = Progress