local _, ns = ...

local U = ns.utils
local C = ns.constants

local Talents = {}

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

local function SafeAdd(
    left,
    right
)
    left =
        U.ToSafeNumber(left)
        or 0

    right =
        U.ToSafeNumber(right)
        or 0

    return left + right
end

local function GetActiveSpecializationIndex()
    if not C_SpecializationInfo
        or type(
            C_SpecializationInfo.GetSpecialization
        ) ~= "function"
    then
        return nil
    end

    local success, specIndex =
        SafeCall(
            C_SpecializationInfo.GetSpecialization
        )

    if not success then
        return nil
    end

    return U.ToSafeNumber(
        specIndex
    )
end

local function GetActiveSpecializationInfo()
    local specIndex =
        GetActiveSpecializationIndex()

    if specIndex == nil then
        return nil
    end

    if not C_SpecializationInfo
        or type(
            C_SpecializationInfo.GetSpecializationInfo
        ) ~= "function"
    then
        return {
            index = specIndex,
        }
    end

    local success,
        specID,
        name,
        description,
        icon,
        role,
        primaryStat,
        pointsSpent,
        background,
        previewPointsSpent,
        isUnlocked =
        SafeCall(
            C_SpecializationInfo.GetSpecializationInfo,
            specIndex
        )

    if not success then
        return {
            index = specIndex,
        }
    end

    return {
        index =
            specIndex,

        id =
            U.ToSafeNumber(
                specID
            ),

        name =
            U.IsNonEmptyString(name)
            and name
            or nil,

        description =
            U.IsNonEmptyString(description)
            and description
            or nil,

        icon =
            icon,

        role =
            U.IsNonEmptyString(role)
            and role
            or nil,

        primaryStat =
            U.ToSafeNumber(
                primaryStat
            ),

        pointsSpent =
            U.ToSafeNumber(
                pointsSpent
            ),

        background =
            U.IsNonEmptyString(background)
            and background
            or nil,

        previewPointsSpent =
            U.ToSafeNumber(
                previewPointsSpent
            ),

        isUnlocked =
            type(isUnlocked) == "boolean"
            and isUnlocked
            or nil,
    }
end

local function GetPlayerClassName()
    if type(UnitClass) ~= "function" then
        return nil
    end

    local success,
        localizedClassName =
        SafeCall(
            UnitClass,
            "player"
        )

    if success
        and U.IsNonEmptyString(
            localizedClassName
        )
    then
        return localizedClassName
    end

    return nil
end

local function GetActiveConfigID()
    if not C_ClassTalents
        or type(
            C_ClassTalents.GetActiveConfigID
        ) ~= "function"
    then
        return nil
    end

    local success, configID =
        SafeCall(
            C_ClassTalents.GetActiveConfigID
        )

    if not success then
        return nil
    end

    return U.ToSafeNumber(
        configID
    )
end

local function GetConfigInfo(
    configID
)
    if configID == nil
        or not C_Traits
        or type(
            C_Traits.GetConfigInfo
        ) ~= "function"
    then
        return nil
    end

    local success, configInfo =
        SafeCall(
            C_Traits.GetConfigInfo,
            configID
        )

    if success
        and type(configInfo) == "table"
    then
        return configInfo
    end

    return nil
end

local function GetLoadoutName(
    configInfo
)
    if type(configInfo) ~= "table" then
        return nil
    end

    if U.IsNonEmptyString(
        configInfo.name
    )
    then
        return configInfo.name
    end

    return nil
end

local function GetImportString(
    configID
)
    if configID == nil
        or not C_Traits
        or type(
            C_Traits.GenerateImportString
        ) ~= "function"
    then
        return nil
    end

    local success, importString =
        SafeCall(
            C_Traits.GenerateImportString,
            configID
        )

    if success
        and U.IsNonEmptyString(
            importString
        )
    then
        return importString
    end

    return nil
end

local function GetConfigTreeIDs(
    configInfo
)
    local treeIDs = {}

    if type(configInfo) ~= "table"
        or type(configInfo.treeIDs)
            ~= "table"
    then
        return treeIDs
    end

    local seen = {}

    for _, rawTreeID
        in ipairs(
            configInfo.treeIDs
        )
    do
        local treeID =
            U.ToSafeNumber(
                rawTreeID
            )

        if treeID ~= nil
            and not seen[treeID]
        then
            seen[treeID] =
                true

            U.SafeInsert(
                treeIDs,
                treeID
            )
        end
    end

    return treeIDs
end

local function GetTreeNodes(
    treeID
)
    if treeID == nil
        or not C_Traits
        or type(
            C_Traits.GetTreeNodes
        ) ~= "function"
    then
        return nil
    end

    local success, nodeIDs =
        SafeCall(
            C_Traits.GetTreeNodes,
            treeID
        )

    if success
        and type(nodeIDs) == "table"
    then
        return nodeIDs
    end

    return nil
end

local function GetNodeInfo(
    configID,
    nodeID
)
    if configID == nil
        or nodeID == nil
        or not C_Traits
        or type(
            C_Traits.GetNodeInfo
        ) ~= "function"
    then
        return nil
    end

    local success, nodeInfo =
        SafeCall(
            C_Traits.GetNodeInfo,
            configID,
            nodeID
        )

    if success
        and type(nodeInfo) == "table"
    then
        return nodeInfo
    end

    return nil
end

local function GetEntryInfo(
    configID,
    entryID
)
    if configID == nil
        or entryID == nil
        or not C_Traits
        or type(
            C_Traits.GetEntryInfo
        ) ~= "function"
    then
        return nil
    end

    local success, entryInfo =
        SafeCall(
            C_Traits.GetEntryInfo,
            configID,
            entryID
        )

    if success
        and type(entryInfo) == "table"
    then
        return entryInfo
    end

    return nil
end

local function GetDefinitionInfo(
    definitionID
)
    if definitionID == nil
        or not C_Traits
        or type(
            C_Traits.GetDefinitionInfo
        ) ~= "function"
    then
        return nil
    end

    local success, definitionInfo =
        SafeCall(
            C_Traits.GetDefinitionInfo,
            definitionID
        )

    if success
        and type(definitionInfo) == "table"
    then
        return definitionInfo
    end

    return nil
end

local function GetSubTreeInfo(
    configID,
    subTreeID
)
    if configID == nil
        or subTreeID == nil
        or not C_Traits
        or type(
            C_Traits.GetSubTreeInfo
        ) ~= "function"
    then
        return nil
    end

    local success, subTreeInfo =
        SafeCall(
            C_Traits.GetSubTreeInfo,
            configID,
            subTreeID
        )

    if success
        and type(subTreeInfo) == "table"
    then
        return subTreeInfo
    end

    return nil
end

local function GetSpellName(
    spellID
)
    spellID =
        U.ToSafeNumber(
            spellID
        )

    if spellID == nil then
        return nil
    end

    if C_Spell
        and type(
            C_Spell.GetSpellName
        ) == "function"
    then
        local success, spellName =
            SafeCall(
                C_Spell.GetSpellName,
                spellID
            )

        if success
            and U.IsNonEmptyString(
                spellName
            )
        then
            return spellName
        end
    end

    if C_Spell
        and type(
            C_Spell.GetSpellInfo
        ) == "function"
    then
        local success, spellInfo =
            SafeCall(
                C_Spell.GetSpellInfo,
                spellID
            )

        if success
            and type(spellInfo) == "table"
            and U.IsNonEmptyString(
                spellInfo.name
            )
        then
            return spellInfo.name
        end
    end

    if type(GetSpellInfo) == "function" then
        local success, spellName =
            SafeCall(
                GetSpellInfo,
                spellID
            )

        if success
            and U.IsNonEmptyString(
                spellName
            )
        then
            return spellName
        end
    end

    return nil
end

local function IsNodeSelected(
    nodeInfo
)
    if type(nodeInfo) ~= "table" then
        return false
    end

    local activeRank =
        U.ToSafeNumber(
            nodeInfo.activeRank
        )
        or 0

    local ranksPurchased =
        U.ToSafeNumber(
            nodeInfo.ranksPurchased
        )
        or 0

    return activeRank > 0
        or ranksPurchased > 0
end

local function AddUniqueEntryID(
    result,
    seen,
    entryID
)
    entryID =
        U.ToSafeNumber(
            entryID
        )

    if entryID == nil
        or seen[entryID]
    then
        return
    end

    seen[entryID] =
        true

    U.SafeInsert(
        result,
        entryID
    )
end

local function GetSelectedEntryIDs(
    nodeInfo
)
    local result = {}
    local seen = {}

    if type(nodeInfo) ~= "table"
        or not IsNodeSelected(
            nodeInfo
        )
    then
        return result
    end

    if type(nodeInfo.activeEntry)
        == "table"
    then
        AddUniqueEntryID(
            result,
            seen,
            nodeInfo.activeEntry.entryID
        )
    end

    if type(
        nodeInfo.entryIDsWithCommittedRanks
    ) == "table"
    then
        for _, entryID
            in ipairs(
                nodeInfo.entryIDsWithCommittedRanks
            )
        do
            AddUniqueEntryID(
                result,
                seen,
                entryID
            )
        end
    end

    if #result == 0
        and type(nodeInfo.entryIDs)
            == "table"
        and #nodeInfo.entryIDs == 1
    then
        AddUniqueEntryID(
            result,
            seen,
            nodeInfo.entryIDs[1]
        )
    end

    return result
end

local function GetTalentRank(
    nodeInfo,
    entryID
)
    if type(nodeInfo) ~= "table" then
        return nil
    end

    entryID =
        U.ToSafeNumber(
            entryID
        )

    if type(nodeInfo.activeEntry)
        == "table"
        and U.ToSafeNumber(
            nodeInfo.activeEntry.entryID
        ) == entryID
    then
        local activeEntryRank =
            U.ToSafeNumber(
                nodeInfo.activeEntry.rank
            )

        if activeEntryRank ~= nil
            and activeEntryRank > 0
        then
            return activeEntryRank
        end
    end

    if type(
        nodeInfo.entryIDToRanksIncreased
    ) == "table"
        and entryID ~= nil
    then
        local increasedRank =
            U.ToSafeNumber(
                nodeInfo.entryIDToRanksIncreased[
                    entryID
                ]
            )

        if increasedRank ~= nil
            and increasedRank > 0
        then
            return increasedRank
        end
    end

    local activeRank =
        U.ToSafeNumber(
            nodeInfo.activeRank
        )

    if activeRank ~= nil
        and activeRank > 0
    then
        return activeRank
    end

    local currentRank =
        U.ToSafeNumber(
            nodeInfo.currentRank
        )

    if currentRank ~= nil
        and currentRank > 0
    then
        return currentRank
    end

    local ranksPurchased =
        U.ToSafeNumber(
            nodeInfo.ranksPurchased
        )

    if ranksPurchased ~= nil
        and ranksPurchased > 0
    then
        return ranksPurchased
    end

    return nil
end

local function ResolveTalentName(
    configID,
    entryInfo,
    definitionInfo
)
    if type(definitionInfo) == "table" then
        if U.IsNonEmptyString(
            definitionInfo.overrideName
        )
        then
            return definitionInfo.overrideName
        end

        local spellID =
            U.ToSafeNumber(
                definitionInfo.overriddenSpellID
            )
            or U.ToSafeNumber(
                definitionInfo.spellID
            )

        local spellName =
            GetSpellName(
                spellID
            )

        if U.IsNonEmptyString(
            spellName
        )
        then
            return spellName
        end
    end

    if type(entryInfo) == "table"
        and entryInfo.subTreeID ~= nil
    then
        local subTreeInfo =
            GetSubTreeInfo(
                configID,
                U.ToSafeNumber(
                    entryInfo.subTreeID
                )
            )

        if type(subTreeInfo) == "table"
            and U.IsNonEmptyString(
                subTreeInfo.name
            )
        then
            return subTreeInfo.name
        end
    end

    return nil
end

local function BuildTalentEntry(
    configID,
    treeID,
    nodeID,
    nodeInfo,
    entryID
)
    local entryInfo =
        GetEntryInfo(
            configID,
            entryID
        )

    if type(entryInfo) ~= "table" then
        return nil
    end

    local definitionID =
        U.ToSafeNumber(
            entryInfo.definitionID
        )

    local definitionInfo =
        GetDefinitionInfo(
            definitionID
        )

    local name =
        ResolveTalentName(
            configID,
            entryInfo,
            definitionInfo
        )

    if not U.IsNonEmptyString(name) then
        return nil
    end

    local rank =
        GetTalentRank(
            nodeInfo,
            entryID
        )

    if rank == nil
        or rank <= 0
    then
        return nil
    end

    local maxRank =
        U.ToSafeNumber(
            entryInfo.maxRanks
        )
        or U.ToSafeNumber(
            nodeInfo.maxRanks
        )
        or rank

    if maxRank < rank then
        maxRank =
            rank
    end

    local spellID = nil

    if type(definitionInfo) == "table" then
        spellID =
            U.ToSafeNumber(
                definitionInfo.overriddenSpellID
            )
            or U.ToSafeNumber(
                definitionInfo.spellID
            )
    end

    local ranksPurchased =
        U.ToSafeNumber(
            nodeInfo.ranksPurchased
        )
        or 0

    local activeRank =
        U.ToSafeNumber(
            nodeInfo.activeRank
        )
        or rank

    local granted =
        activeRank > ranksPurchased

    return {
        name =
            name,

        nodeName =
            name,

        rank =
            rank,

        ranksPurchased =
            ranksPurchased,

        maxRank =
            maxRank,

        configID =
            configID,

        treeID =
            U.ToSafeNumber(
                treeID
            ),

        nodeID =
            U.ToSafeNumber(
                nodeID
            ),

        entryID =
            U.ToSafeNumber(
                entryID
            ),

        definitionID =
            definitionID,

        spellID =
            spellID,

        nodeType =
            U.ToSafeNumber(
                nodeInfo.type
            ),

        entryType =
            U.ToSafeNumber(
                entryInfo.type
            ),

        granted =
            granted,

        selected =
            true,
    }
end

local function BuildTalentTree(
    configID,
    treeID,
    specInfo
)
    local className =
        GetPlayerClassName()

    local specName =
        specInfo
        and specInfo.name
        or nil

    local displayName = nil

    if U.IsNonEmptyString(
        className
    )
        and U.IsNonEmptyString(
            specName
        )
    then
        displayName =
            string.format(
                "%s / %s",
                className,
                specName
            )
    elseif U.IsNonEmptyString(
        specName
    )
    then
        displayName =
            specName
    elseif U.IsNonEmptyString(
        className
    )
    then
        displayName =
            className
    else
        displayName =
            "Active Talents"
    end

    return {
        name =
            displayName,

        type =
            "Talent Tree",

        points =
            0,

        configID =
            configID,

        treeID =
            treeID,

        talents =
            {},
    }
end

local function SortTalentTree(
    tree
)
    if type(tree) ~= "table"
        or type(tree.talents)
            ~= "table"
    then
        return
    end

    table.sort(
        tree.talents,
        function(left, right)
            local leftNode =
                U.ToSafeNumber(
                    left.nodeID
                )
                or 0

            local rightNode =
                U.ToSafeNumber(
                    right.nodeID
                )
                or 0

            if leftNode ~= rightNode then
                return leftNode < rightNode
            end

            local leftEntry =
                U.ToSafeNumber(
                    left.entryID
                )
                or 0

            local rightEntry =
                U.ToSafeNumber(
                    right.entryID
                )
                or 0

            if leftEntry ~= rightEntry then
                return leftEntry < rightEntry
            end

            return
                string.lower(
                    left.name
                    or ""
                )
                <
                string.lower(
                    right.name
                    or ""
                )
        end
    )
end

local function CollectTraitTrees(
    configID,
    configInfo,
    specInfo,
    diagnostics
)
    local trees = {}

    if not C_Traits
        or type(
            C_Traits.GetTreeNodes
        ) ~= "function"
        or type(
            C_Traits.GetNodeInfo
        ) ~= "function"
        or type(
            C_Traits.GetEntryInfo
        ) ~= "function"
        or type(
            C_Traits.GetDefinitionInfo
        ) ~= "function"
    then
        AddDiagnostic(
            diagnostics,
            "C_Traits tree, node, entry, or definition APIs unavailable."
        )

        return trees
    end

    local treeIDs =
        GetConfigTreeIDs(
            configInfo
        )

    if #treeIDs == 0 then
        AddDiagnostic(
            diagnostics,
            "C_Traits.GetConfigInfo returned no tree IDs for the active config."
        )

        return trees
    end

    local totalNodeCount = 0
    local selectedNodeCount = 0
    local exportedTalentCount = 0

    for _, treeID
        in ipairs(treeIDs)
    do
        local tree =
            BuildTalentTree(
                configID,
                treeID,
                specInfo
            )

        local nodeIDs =
            GetTreeNodes(
                treeID
            )

        if type(nodeIDs) ~= "table" then
            AddDiagnostic(
                diagnostics,
                string.format(
                    "C_Traits.GetTreeNodes returned no nodes for tree %s.",
                    tostring(treeID)
                )
            )
        else
            totalNodeCount =
                SafeAdd(
                    totalNodeCount,
                    #nodeIDs
                )

            local seenEntries = {}

            for _, rawNodeID
                in ipairs(nodeIDs)
            do
                local nodeID =
                    U.ToSafeNumber(
                        rawNodeID
                    )

                local nodeInfo =
                    GetNodeInfo(
                        configID,
                        nodeID
                    )

                if type(nodeInfo) == "table"
                    and IsNodeSelected(
                        nodeInfo
                    )
                then
                    selectedNodeCount =
                        selectedNodeCount + 1

                    local selectedEntryIDs =
                        GetSelectedEntryIDs(
                            nodeInfo
                        )

                    for _, entryID
                        in ipairs(
                            selectedEntryIDs
                        )
                    do
                        local key =
                            tostring(nodeID)
                            .. ":"
                            .. tostring(entryID)

                        if not seenEntries[key] then
                            seenEntries[key] =
                                true

                            local entry =
                                BuildTalentEntry(
                                    configID,
                                    treeID,
                                    nodeID,
                                    nodeInfo,
                                    entryID
                                )

                            if entry ~= nil then
                                U.SafeInsert(
                                    tree.talents,
                                    entry
                                )

                                tree.points =
                                    SafeAdd(
                                        tree.points,
                                        entry.rank
                                    )

                                exportedTalentCount =
                                    exportedTalentCount + 1
                            end
                        end
                    end
                end
            end
        end

        SortTalentTree(
            tree
        )

        U.SafeInsert(
            trees,
            tree
        )
    end

    AddDiagnostic(
        diagnostics,
        string.format(
            "Trait tree IDs: %d",
            #treeIDs
        )
    )

    AddDiagnostic(
        diagnostics,
        string.format(
            "Trait nodes returned: %d",
            totalNodeCount
        )
    )

    AddDiagnostic(
        diagnostics,
        string.format(
            "Selected trait nodes: %d",
            selectedNodeCount
        )
    )

    AddDiagnostic(
        diagnostics,
        string.format(
            "Talent entries exported: %d",
            exportedTalentCount
        )
    )

    if selectedNodeCount > 0
        and exportedTalentCount == 0
    then
        AddDiagnostic(
            diagnostics,
            "Selected trait nodes were found, but no talent names could be resolved."
        )
    elseif selectedNodeCount == 0 then
        AddDiagnostic(
            diagnostics,
            "C_Traits returned no selected nodes for the active config."
        )
    end

    return trees
end

local function GetPvpTalentInfo(
    talentID
)
    if not C_SpecializationInfo then
        return nil
    end

    if type(
        C_SpecializationInfo.GetPvpTalentInfo
    ) == "function"
    then
        local success, info =
            SafeCall(
                C_SpecializationInfo.GetPvpTalentInfo,
                talentID
            )

        if success
            and type(info) == "table"
        then
            return info
        end
    end

    if type(
        C_SpecializationInfo.GetPvpTalentInfoByID
    ) == "function"
    then
        local success, info =
            SafeCall(
                C_SpecializationInfo.GetPvpTalentInfoByID,
                talentID
            )

        if success
            and type(info) == "table"
        then
            return info
        end
    end

    return nil
end

local function CollectPvPTalents()
    if not C_SpecializationInfo
        or type(
            C_SpecializationInfo.GetAllSelectedPvpTalentIDs
        ) ~= "function"
    then
        return nil
    end

    local success, talentIDs =
        SafeCall(
            C_SpecializationInfo.GetAllSelectedPvpTalentIDs
        )

    if not success
        or type(talentIDs) ~= "table"
    then
        return nil
    end

    local tree = {
        name =
            PVP_TALENTS
            or "PvP Talents",

        type =
            "PvP Talents",

        points =
            0,

        talents =
            {},
    }

    local seen = {}

    for _, rawTalentID
        in ipairs(talentIDs)
    do
        local talentID =
            U.ToSafeNumber(
                rawTalentID
            )

        if talentID ~= nil
            and not seen[talentID]
        then
            seen[talentID] =
                true

            local info =
                GetPvpTalentInfo(
                    talentID
                )

            local name =
                info
                and info.name
                or nil

            if U.IsNonEmptyString(name) then
                U.SafeInsert(
                    tree.talents,
                    {
                        name =
                            name,

                        rank =
                            1,

                        maxRank =
                            1,

                        talentID =
                            talentID,

                        spellID =
                            U.ToSafeNumber(
                                info.spellID
                            ),
                    }
                )

                tree.points =
                    tree.points + 1
            end
        end
    end

    if #tree.talents == 0 then
        return nil
    end

    table.sort(
        tree.talents,
        function(left, right)
            return
                string.lower(
                    left.name
                    or ""
                )
                <
                string.lower(
                    right.name
                    or ""
                )
        end
    )

    return tree
end

function Talents:Collect()
    local diagnostics = {}
    local trees = {}

    local specInfo =
        GetActiveSpecializationInfo()

    local configID =
        GetActiveConfigID()

    local configInfo =
        GetConfigInfo(
            configID
        )

    local loadoutName =
        GetLoadoutName(
            configInfo
        )

    local importString =
        GetImportString(
            configID
        )

    if configID == nil then
        AddDiagnostic(
            diagnostics,
            "C_ClassTalents.GetActiveConfigID returned no active config."
        )
    elseif configInfo == nil then
        AddDiagnostic(
            diagnostics,
            "C_Traits.GetConfigInfo returned no active config info."
        )
    else
        local traitTrees =
            CollectTraitTrees(
                configID,
                configInfo,
                specInfo,
                diagnostics
            )

        for _, tree
            in ipairs(traitTrees)
        do
            U.SafeInsert(
                trees,
                tree
            )
        end
    end

    local pvpTree =
        CollectPvPTalents()

    if pvpTree then
        U.SafeInsert(
            trees,
            pvpTree
        )
    end

    AddDiagnostic(
        diagnostics,
        string.format(
            "Talent trees exported: %d",
            #trees
        )
    )

    return {
        key =
            C.SECTIONS.TALENTS,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.TALENTS
            ],

        specialization =
            specInfo,

        trees =
            trees,

        diagnostics =
            diagnostics,

        configID =
            configID,

        importString =
            importString,

        loadoutName =
            loadoutName,
    }
end

ns:RegisterModule(
    "Data.Talents",
    Talents
)

ns.Data = ns.Data or {}
ns.Data.Talents =
    Talents