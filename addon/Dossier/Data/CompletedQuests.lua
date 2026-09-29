local _, ns = ...

local U = ns.utils
local C = ns.constants

local CompletedQuests = {}

local questTitleCache = {}
local pendingQuestLoads = {}
local pendingQuestLoadCount = 0
local readyCallbacks = {}

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

local function CleanQuestTitle(value)
    if not U.IsNonEmptyString(value) then
        return nil
    end

    local title =
        U.Trim(
            U.SafeString(
                value,
                ""
            )
        )

    if title == ""
        or title == "[Unknown Quest]"
    then
        return nil
    end

    return title
end

local function IsTrackingQuestTitle(title)
    if not U.IsNonEmptyString(title) then
        return false
    end

    if title == "Tracking Quest" then
        return true
    end

    if title:match(
        "^Tracking Quest[%s:%-%(]"
    )
    then
        return true
    end

    if title:match(
        "%[Tracking Quest%]"
    )
    then
        return true
    end

    return false
end

local function CacheQuestTitle(
    questID,
    title
)
    questID =
        U.ToSafeNumber(
            questID
        )

    title =
        CleanQuestTitle(
            title
        )

    if questID == nil
        or title == nil
    then
        return nil
    end

    questTitleCache[
        questID
    ] =
        title

    return title
end

local function ReadCachedQuestTitle(
    questID
)
    questID =
        U.ToSafeNumber(
            questID
        )

    if questID == nil then
        return nil
    end

    return CleanQuestTitle(
        questTitleCache[
            questID
        ]
    )
end

local function CollectCompletedQuestIDs(
    diagnostics
)
    if not C_QuestLog
        or type(
            C_QuestLog.GetAllCompletedQuestIDs
        ) ~= "function"
    then
        AddDiagnostic(
            diagnostics,
            "C_QuestLog.GetAllCompletedQuestIDs API unavailable."
        )

        return {}
    end

    local success,
        completedQuestIDs =
        SafeCall(
            C_QuestLog.GetAllCompletedQuestIDs
        )

    if not success then
        AddDiagnostic(
            diagnostics,
            "C_QuestLog.GetAllCompletedQuestIDs call failed."
        )

        return {}
    end

    if type(completedQuestIDs)
        ~= "table"
    then
        AddDiagnostic(
            diagnostics,
            "C_QuestLog.GetAllCompletedQuestIDs returned no quest list."
        )

        return {}
    end

    return completedQuestIDs
end

local function TitleFromTaskQuest(
    questID
)
    if not C_TaskQuest
        or type(
            C_TaskQuest.GetQuestInfoByQuestID
        ) ~= "function"
    then
        return nil
    end

    local success,
        title =
        SafeCall(
            C_TaskQuest.GetQuestInfoByQuestID,
            questID
        )

    if not success then
        return nil
    end

    return CleanQuestTitle(
        title
    )
end

local function TitleFromQuestLog(
    questID
)
    if not C_QuestLog
        or type(
            C_QuestLog.GetTitleForQuestID
        ) ~= "function"
    then
        return nil
    end

    local success, title =
        SafeCall(
            C_QuestLog.GetTitleForQuestID,
            questID
        )

    if not success then
        return nil
    end

    return CleanQuestTitle(
        title
    )
end

local function TitleFromQuestUtils(
    questID
)
    if type(
        QuestUtils_GetQuestName
    ) ~= "function"
    then
        return nil
    end

    local success, title =
        SafeCall(
            QuestUtils_GetQuestName,
            questID
        )

    if not success then
        return nil
    end

    return CleanQuestTitle(
        title
    )
end

local function TitleFromQuestLine(
    questID
)
    if not C_QuestLine
        or type(
            C_QuestLine.GetQuestLineInfo
        ) ~= "function"
    then
        return nil
    end

    local success, info =
        SafeCall(
            C_QuestLine.GetQuestLineInfo,
            questID
        )

    if not success
        or type(info) ~= "table"
    then
        return nil
    end

    return
        CleanQuestTitle(
            info.questName
        )
        or CleanQuestTitle(
            info.questLineName
        )
end

local function ResolveQuestTitleNow(
    questID
)
    local cached =
        ReadCachedQuestTitle(
            questID
        )

    if cached ~= nil then
        return cached
    end

    local title =
        TitleFromTaskQuest(
            questID
        )

    if title == nil then
        title =
            TitleFromQuestLog(
                questID
            )
    end

    if title == nil then
        title =
            TitleFromQuestUtils(
                questID
            )
    end

    if title == nil then
        title =
            TitleFromQuestLine(
                questID
            )
    end

    if title ~= nil then
        CacheQuestTitle(
            questID,
            title
        )
    end

    return title
end

local function NotifyReadyCallbacks()
    if pendingQuestLoadCount > 0 then
        return
    end

    if #readyCallbacks == 0 then
        return
    end

    local callbacks =
        readyCallbacks

    readyCallbacks = {}

    for _, callback
        in ipairs(callbacks)
    do
        if type(callback) == "function" then
            SafeCall(
                callback
            )
        end
    end
end

local function FinishPendingQuestLoad(
    questID
)
    questID =
        U.ToSafeNumber(
            questID
        )

    if questID == nil
        or not pendingQuestLoads[
            questID
        ]
    then
        return
    end

    pendingQuestLoads[
        questID
    ] =
        nil

    pendingQuestLoadCount =
        math.max(
            0,
            pendingQuestLoadCount - 1
        )

    NotifyReadyCallbacks()
end

local function HandleQuestDataLoaded(
    questID,
    success
)
    questID =
        U.ToSafeNumber(
            questID
        )

    if questID == nil then
        return
    end

    if success == true then
        local title =
            ResolveQuestTitleNow(
                questID
            )

        if title == nil
            and C_Timer
            and type(
                C_Timer.After
            ) == "function"
        then
            C_Timer.After(
                0,
                function()
                    ResolveQuestTitleNow(
                        questID
                    )
                end
            )
        end
    end

    FinishPendingQuestLoad(
        questID
    )
end

local function EnsureQuestEventFrame()
    if CompletedQuests.eventFrame ~= nil then
        return
    end

    if type(CreateFrame) ~= "function" then
        return
    end

    local frame =
        CreateFrame(
            "Frame"
        )

    frame:RegisterEvent(
        "QUEST_DATA_LOAD_RESULT"
    )

    frame:SetScript(
        "OnEvent",
        function(
            _,
            event,
            questID,
            success
        )
            if event
                ~= "QUEST_DATA_LOAD_RESULT"
            then
                return
            end

            HandleQuestDataLoaded(
                questID,
                success
            )
        end
    )

    CompletedQuests.eventFrame =
        frame
end

local function RequestQuestTitleLoad(
    questID
)
    questID =
        U.ToSafeNumber(
            questID
        )

    if questID == nil then
        return false
    end

    if ReadCachedQuestTitle(
        questID
    ) ~= nil
    then
        return false
    end

    if pendingQuestLoads[
        questID
    ]
    then
        return false
    end

    if not C_QuestLog
        or type(
            C_QuestLog.RequestLoadQuestByID
        ) ~= "function"
    then
        return false
    end

    EnsureQuestEventFrame()

    pendingQuestLoads[
        questID
    ] =
        true

    pendingQuestLoadCount =
        pendingQuestLoadCount + 1

    local success =
        SafeCall(
            C_QuestLog.RequestLoadQuestByID,
            questID
        )

    if not success then
        FinishPendingQuestLoad(
            questID
        )

        return false
    end

    return true
end

local function SortResolvedQuests(
    left,
    right
)
    local leftTitle =
        string.lower(
            U.SafeString(
                left and left.title,
                ""
            )
        )

    local rightTitle =
        string.lower(
            U.SafeString(
                right and right.title,
                ""
            )
        )

    if leftTitle ~= rightTitle then
        return
            leftTitle
            < rightTitle
    end

    return
        (
            U.ToSafeNumber(
                left and left.questID
            )
            or 0
        )
        <
        (
            U.ToSafeNumber(
                right and right.questID
            )
            or 0
        )
end

local function SortQuestIDs(
    left,
    right
)
    return
        (
            U.ToSafeNumber(left)
            or 0
        )
        <
        (
            U.ToSafeNumber(right)
            or 0
        )
end

function CompletedQuests:HasPendingTitleLoads()
    return
        pendingQuestLoadCount > 0
end

function CompletedQuests:GetPendingTitleLoadCount()
    return
        pendingQuestLoadCount
end

function CompletedQuests:OnTitlesReady(
    callback
)
    if type(callback) ~= "function" then
        return
    end

    if pendingQuestLoadCount <= 0 then
        SafeCall(
            callback
        )

        return
    end

    U.SafeInsert(
        readyCallbacks,
        callback
    )
end

function CompletedQuests:Collect()
    EnsureQuestEventFrame()

    local diagnostics = {}

    local rawQuestIDs =
        CollectCompletedQuestIDs(
            diagnostics
        )

    local resolvedQuests = {}
    local trackingQuests = {}
    local unresolvedQuestIDs = {}

    local seenQuestIDs = {}
    local requestedLoads = 0

    for _, rawQuestID
        in ipairs(rawQuestIDs)
    do
        local questID =
            U.ToSafeNumber(
                rawQuestID
            )

        if questID ~= nil
            and not seenQuestIDs[
                questID
            ]
        then
            seenQuestIDs[
                questID
            ] =
                true

            local title =
                ResolveQuestTitleNow(
                    questID
                )

            if IsTrackingQuestTitle(
                title
            )
            then
                U.SafeInsert(
                    trackingQuests,
                    {
                        questID =
                            questID,

                        title =
                            title,

                        tracking =
                            true,
                    }
                )
            elseif title then
                U.SafeInsert(
                    resolvedQuests,
                    {
                        questID =
                            questID,

                        title =
                            title,
                    }
                )
            else
                if RequestQuestTitleLoad(
                    questID
                )
                then
                    requestedLoads =
                        requestedLoads + 1
                end

                U.SafeInsert(
                    unresolvedQuestIDs,
                    questID
                )
            end
        end
    end

    table.sort(
        resolvedQuests,
        SortResolvedQuests
    )

    table.sort(
        trackingQuests,
        SortResolvedQuests
    )

    table.sort(
        unresolvedQuestIDs,
        SortQuestIDs
    )

    local entries = {}

    for _, quest
        in ipairs(resolvedQuests)
    do
        U.SafeInsert(
            entries,
            quest
        )
    end

    for _, quest
        in ipairs(trackingQuests)
    do
        U.SafeInsert(
            entries,
            quest
        )
    end

    for _, questID
        in ipairs(
            unresolvedQuestIDs
        )
    do
        U.SafeInsert(
            entries,
            {
                questID =
                    questID,

                title =
                    nil,

                unresolved =
                    true,
            }
        )
    end

    AddDiagnostic(
        diagnostics,
        string.format(
            "Completed quest IDs: %d",
            #rawQuestIDs
        )
    )

    AddDiagnostic(
        diagnostics,
        string.format(
            "Resolved completed quests: %d",
            #resolvedQuests
        )
    )

    AddDiagnostic(
        diagnostics,
        string.format(
            "Unresolved completed quests: %d",
            #unresolvedQuestIDs
        )
    )

    AddDiagnostic(
        diagnostics,
        string.format(
            "Tracking quests: %d",
            #trackingQuests
        )
    )

    AddDiagnostic(
        diagnostics,
        string.format(
            "Quest title loads requested: %d",
            requestedLoads
        )
    )

    AddDiagnostic(
        diagnostics,
        string.format(
            "Quest title loads pending: %d",
            pendingQuestLoadCount
        )
    )

    return {
        key =
            C.SECTIONS.COMPLETED_QUESTS,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.COMPLETED_QUESTS
            ],

        entries =
            entries,

        resolvedQuests =
            resolvedQuests,

        trackingQuests =
            trackingQuests,

        unresolvedQuestIDs =
            unresolvedQuestIDs,

        count =
            #entries,

        rawCount =
            #rawQuestIDs,

        resolvedCount =
            #resolvedQuests,

        unresolvedCount =
            #unresolvedQuestIDs,

        trackingCount =
            #trackingQuests,

        requestedTitleLoads =
            requestedLoads,

        pendingTitleLoads =
            pendingQuestLoadCount,

        diagnostics =
            diagnostics,
    }
end

EnsureQuestEventFrame()

ns:RegisterModule(
    "Data.CompletedQuests",
    CompletedQuests
)

ns.Data = ns.Data or {}
ns.Data.CompletedQuests =
    CompletedQuests