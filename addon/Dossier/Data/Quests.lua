local _, ns = ...

local U = ns.utils
local C = ns.constants

local Quests = {}

local QUEST_STATUS = {
    IN_PROGRESS = "in_progress",
    COMPLETE = "complete",
    READY_TO_TURN_IN = "ready_to_turn_in",
}

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

local function GetQuestLogInfo(index)
    if not C_QuestLog
        or type(
            C_QuestLog.GetInfo
        ) ~= "function"
    then
        return nil
    end

    local success, info =
        SafeCall(
            C_QuestLog.GetInfo,
            index
        )

    if not success
        or type(info) ~= "table"
    then
        return nil
    end

    return info
end

local function GetNumQuestLogEntries(
    diagnostics
)
    if not C_QuestLog
        or type(
            C_QuestLog.GetNumQuestLogEntries
        ) ~= "function"
    then
        AddDiagnostic(
            diagnostics,
            "C_QuestLog.GetNumQuestLogEntries API unavailable."
        )

        return 0
    end

    local success,
        numShownEntries =
        SafeCall(
            C_QuestLog.GetNumQuestLogEntries
        )

    if not success then
        AddDiagnostic(
            diagnostics,
            "C_QuestLog.GetNumQuestLogEntries call failed."
        )

        return 0
    end

    return
        U.ToSafeNumber(
            numShownEntries
        )
        or 0
end

local function GetQuestObjectives(
    questID,
    diagnostics
)
    local objectives = {}

    questID =
        U.ToSafeNumber(
            questID
        )

    if questID == nil then
        return objectives
    end

    if not C_QuestLog
        or type(
            C_QuestLog.GetQuestObjectives
        ) ~= "function"
    then
        AddDiagnostic(
            diagnostics,
            "C_QuestLog.GetQuestObjectives API unavailable."
        )

        return objectives
    end

    local success,
        rawObjectives =
        SafeCall(
            C_QuestLog.GetQuestObjectives,
            questID
        )

    if not success then
        AddDiagnostic(
            diagnostics,
            string.format(
                "C_QuestLog.GetQuestObjectives failed for quest %d.",
                questID
            )
        )

        return objectives
    end

    if type(rawObjectives) ~= "table" then
        return objectives
    end

    for _, objective
        in ipairs(rawObjectives)
    do
        if type(objective) == "table"
            and U.IsNonEmptyString(
                objective.text
            )
        then
            U.SafeInsert(
                objectives,
                {
                    text =
                        objective.text,

                    type =
                        U.IsNonEmptyString(
                            objective.type
                        )
                        and objective.type
                        or nil,

                    finished =
                        objective.finished
                        == true,

                    numFulfilled =
                        U.ToSafeNumber(
                            objective.numFulfilled
                        ),

                    numRequired =
                        U.ToSafeNumber(
                            objective.numRequired
                        ),

                    objectiveType =
                        U.ToSafeNumber(
                            objective.objectiveType
                        ),
                }
            )
        end
    end

    return objectives
end

local function AreAllObjectivesComplete(
    objectives
)
    if type(objectives) ~= "table"
        or #objectives == 0
    then
        return false
    end

    for _, objective
        in ipairs(objectives)
    do
        if objective.finished ~= true then
            return false
        end
    end

    return true
end

local function IsReadyForTurnIn(
    questID
)
    questID =
        U.ToSafeNumber(
            questID
        )

    if questID == nil
        or not C_QuestLog
    then
        return nil
    end

    if type(
        C_QuestLog.ReadyForTurnIn
    ) == "function"
    then
        local success, ready =
            SafeCall(
                C_QuestLog.ReadyForTurnIn,
                questID
            )

        if success
            and type(ready) == "boolean"
        then
            return ready
        end
    end

    if type(
        C_QuestLog.IsComplete
    ) == "function"
    then
        local success, complete =
            SafeCall(
                C_QuestLog.IsComplete,
                questID
            )

        if success
            and type(complete) == "boolean"
        then
            return complete
        end
    end

    return nil
end

local function ResolveQuestStatus(
    questID,
    objectives
)
    local ready =
        IsReadyForTurnIn(
            questID
        )

    if ready == true then
        return
            QUEST_STATUS.READY_TO_TURN_IN
    end

    if AreAllObjectivesComplete(
        objectives
    )
    then
        return
            QUEST_STATUS.COMPLETE
    end

    return
        QUEST_STATUS.IN_PROGRESS
end

local function GetQuestInfo(
    index,
    diagnostics
)
    local info =
        GetQuestLogInfo(
            index
        )

    if not info
        or info.isHeader == true
    then
        return nil
    end

    local questID =
        U.ToSafeNumber(
            info.questID
        )

    if questID == nil then
        return nil
    end

    local objectives =
        GetQuestObjectives(
            questID,
            diagnostics
        )

    local status =
        ResolveQuestStatus(
            questID,
            objectives
        )

    return {
        title =
            U.IsNonEmptyString(
                info.title
            )
            and info.title
            or nil,

        questID =
            questID,

        questLogIndex =
            U.ToSafeNumber(
                info.questLogIndex
            )
            or U.ToSafeNumber(
                index
            ),

        level =
            U.ToSafeNumber(
                info.level
            ),

        difficultyLevel =
            U.ToSafeNumber(
                info.difficultyLevel
            ),

        suggestedGroup =
            U.ToSafeNumber(
                info.suggestedGroup
            ),

        status =
            status,

        completed =
            status
                == QUEST_STATUS.READY_TO_TURN_IN,

        objectives =
            objectives,

        campaignID =
            U.ToSafeNumber(
                info.campaignID
            ),

        frequency =
            U.ToSafeNumber(
                info.frequency
            ),

        questClassification =
            U.ToSafeNumber(
                info.questClassification
            ),

        isTask =
            type(info.isTask)
                == "boolean"
            and info.isTask
            or nil,

        isBounty =
            type(info.isBounty)
                == "boolean"
            and info.isBounty
            or nil,

        isStory =
            type(info.isStory)
                == "boolean"
            and info.isStory
            or nil,

        isScaling =
            type(info.isScaling)
                == "boolean"
            and info.isScaling
            or nil,

        isOnMap =
            type(info.isOnMap)
                == "boolean"
            and info.isOnMap
            or nil,

        hasLocalPOI =
            type(info.hasLocalPOI)
                == "boolean"
            and info.hasLocalPOI
            or nil,

        isHidden =
            type(info.isHidden)
                == "boolean"
            and info.isHidden
            or nil,

        isAutoComplete =
            type(info.isAutoComplete)
                == "boolean"
            and info.isAutoComplete
            or nil,
    }
end

function Quests:Collect()
    local groups = {}
    local diagnostics = {}
    local currentHeader = nil

    local numEntries =
        GetNumQuestLogEntries(
            diagnostics
        )

    for index = 1,
        numEntries
    do
        local info =
            GetQuestLogInfo(
                index
            )

        if info
            and info.isHeader == true
        then
            local headerName =
                U.IsNonEmptyString(
                    info.title
                )
                and info.title
                or "General"

            currentHeader = {
                name =
                    headerName,

                quests =
                    {},
            }

            U.SafeInsert(
                groups,
                currentHeader
            )
        elseif info then
            local quest =
                GetQuestInfo(
                    index,
                    diagnostics
                )

            if quest then
                if not currentHeader then
                    currentHeader = {
                        name =
                            "General",

                        quests =
                            {},
                    }

                    U.SafeInsert(
                        groups,
                        currentHeader
                    )
                end

                U.SafeInsert(
                    currentHeader.quests,
                    quest
                )
            end
        end
    end

    return {
        key =
            C.SECTIONS.QUESTS,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.QUESTS
            ],

        groups =
            groups,

        diagnostics =
            diagnostics,
    }
end

ns:RegisterModule(
    "Data.Quests",
    Quests
)

ns.Data = ns.Data or {}
ns.Data.Quests = Quests