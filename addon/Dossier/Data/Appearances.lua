local _, ns = ...

local U = ns.utils
local C = ns.constants

local Appearances = {}

local MAX_SET_ENTRIES = 20
local MAX_OUTFITS = 20

local FALLBACK_CATEGORY_MIN = 1
local FALLBACK_CATEGORY_MAX = 29

local CATEGORY_ORDER = {
    { id = 1, name = "Head", enumKey = "Head" },
    { id = 2, name = "Shoulder", enumKey = "Shoulder" },
    { id = 3, name = "Back", enumKey = "Back" },
    { id = 4, name = "Chest", enumKey = "Chest" },
    { id = 5, name = "Shirt", enumKey = "Shirt" },
    { id = 6, name = "Tabard", enumKey = "Tabard" },
    { id = 7, name = "Wrist", enumKey = "Wrist" },
    { id = 8, name = "Hands", enumKey = "Hands" },
    { id = 9, name = "Waist", enumKey = "Waist" },
    { id = 10, name = "Legs", enumKey = "Legs" },
    { id = 11, name = "Feet", enumKey = "Feet" },
    { id = 12, name = "Wand", enumKey = "Wand" },
    { id = 13, name = "One-Handed Axes", enumKey = "OneHAxe" },
    { id = 14, name = "One-Handed Swords", enumKey = "OneHSword" },
    { id = 15, name = "One-Handed Maces", enumKey = "OneHMace" },
    { id = 16, name = "Daggers", enumKey = "Dagger" },
    { id = 17, name = "Fist Weapons", enumKey = "Fist" },
    { id = 18, name = "Shields", enumKey = "Shield" },
    { id = 19, name = "Held In Off-hand", enumKey = "Holdable" },
    { id = 20, name = "Two-Handed Axes", enumKey = "TwoHAxe" },
    { id = 21, name = "Two-Handed Swords", enumKey = "TwoHSword" },
    { id = 22, name = "Two-Handed Maces", enumKey = "TwoHMace" },
    { id = 23, name = "Staves", enumKey = "Staff" },
    { id = 24, name = "Polearms", enumKey = "Polearm" },
    { id = 25, name = "Bows", enumKey = "Bow" },
    { id = 26, name = "Guns", enumKey = "Gun" },
    { id = 27, name = "Crossbows", enumKey = "Crossbow" },
    { id = 28, name = "Warglaives", enumKey = "Warglaives" },
    { id = 29, name = "Paired", enumKey = "Paired" },
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

local function AddDiagnostic(
    snapshot,
    message
)
    if type(snapshot) ~= "table"
        or type(snapshot.diagnostics) ~= "table"
    then
        return
    end

    if not U.IsNonEmptyString(message) then
        return
    end

    U.SafeInsert(
        snapshot.diagnostics,
        message
    )
end

local function NewSnapshot()
    return {
        key =
            C.SECTIONS.APPEARANCES,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.APPEARANCES
            ],

        categories = {
            count = 0,
            entries = {},
        },

        sets = {
            total = nil,
            collected = nil,
            entries = {},
        },

        latest = {
            entries = {},
        },

        favorites = {
            count = 0,
            entries = {},
        },

        outfits = {
            count = 0,
            entries = {},
            available = false,
        },

        diagnostics = {},
    }
end

local function ResolveCategoryID(
    definition
)
    if type(definition) ~= "table" then
        return nil
    end

    if Enum
        and type(
            Enum.TransmogCollectionType
        ) == "table"
        and definition.enumKey
    then
        local enumID =
            SafeNumber(
                Enum.TransmogCollectionType[
                    definition.enumKey
                ]
            )

        if enumID ~= nil then
            return enumID
        end
    end

    return SafeNumber(
        definition.id
    )
end

local function BuildCategoryCandidates()
    local result = {}
    local seen = {}

    for sortOrder,
        definition
        in ipairs(CATEGORY_ORDER)
    do
        local categoryID =
            ResolveCategoryID(
                definition
            )

        if categoryID ~= nil
            and not seen[categoryID]
        then
            seen[categoryID] = true

            U.SafeInsert(
                result,
                {
                    categoryID =
                        categoryID,

                    fallbackName =
                        definition.name,

                    sortOrder =
                        sortOrder,
                }
            )
        end
    end

    for categoryID =
        FALLBACK_CATEGORY_MIN,
        FALLBACK_CATEGORY_MAX
    do
        if not seen[categoryID] then
            seen[categoryID] = true

            U.SafeInsert(
                result,
                {
                    categoryID =
                        categoryID,

                    fallbackName =
                        string.format(
                            "Category %d",
                            categoryID
                        ),

                    sortOrder =
                        1000
                        + categoryID,
                }
            )
        end
    end

    return result
end

local function ResolveCategoryName(
    categoryID,
    fallbackName
)
    if C_TransmogCollection
        and type(
            C_TransmogCollection.GetCategoryInfo
        ) == "function"
    then
        local success, name =
            SafeCall(
                C_TransmogCollection.GetCategoryInfo,
                categoryID
            )

        if success
            and U.IsNonEmptyString(name)
        then
            return name
        end
    end

    return fallbackName
        or string.format(
            "Category %s",
            tostring(categoryID)
        )
end

local function GetInventorySlotID(
    slotName
)
    if not U.IsNonEmptyString(slotName) then
        return nil
    end

    if C_PaperDollInfo
        and type(
            C_PaperDollInfo.GetInventorySlotInfo
        ) == "function"
    then
        local success, slotID =
            SafeCall(
                C_PaperDollInfo.GetInventorySlotInfo,
                slotName
            )

        if success then
            return SafeNumber(
                slotID
            )
        end
    end

    if type(GetInventorySlotInfo) == "function" then
        local success, slotID =
            SafeCall(
                GetInventorySlotInfo,
                slotName
            )

        if success then
            return SafeNumber(
                slotID
            )
        end
    end

    return nil
end

local function GetAppearanceTransmogType()
    if not Enum
        or type(
            Enum.TransmogType
        ) ~= "table"
    then
        return nil
    end

    return SafeNumber(
        Enum.TransmogType.Appearance
    )
end

local function GetMainTransmogModification()
    if not Enum
        or type(
            Enum.TransmogModification
        ) ~= "table"
    then
        return nil
    end

    return SafeNumber(
        Enum.TransmogModification.Main
    )
end

local function BuildLocationData(
    slotName
)
    local slotID =
        GetInventorySlotID(
            slotName
        )

    local transmogType =
        GetAppearanceTransmogType()

    local modification =
        GetMainTransmogModification()

    if slotID == nil
        or transmogType == nil
        or modification == nil
    then
        return nil
    end

    return {
        slotID =
            slotID,

        type =
            transmogType,

        modification =
            modification,
    }
end

local function BuildTransmogLocationMap()
    local result = {}

    if not C_TransmogOutfitInfo
        or type(
            C_TransmogOutfitInfo.GetAllSlotLocationInfo
        ) ~= "function"
    then
        return result
    end

    local success,
        appearanceSlotInfo =
        SafeCall(
            C_TransmogOutfitInfo.GetAllSlotLocationInfo
        )

    if not success
        or type(appearanceSlotInfo) ~= "table"
    then
        return result
    end

    for _, slotInfo
        in ipairs(appearanceSlotInfo)
    do
        if type(slotInfo) == "table" then
            local categoryID =
                SafeNumber(
                    slotInfo.collectionType
                )

            local slotID =
                GetInventorySlotID(
                    slotInfo.slotName
                )

            local transmogType =
                SafeNumber(
                    slotInfo.type
                )

            local modification =
                nil

            if Enum
                and type(
                    Enum.TransmogModification
                ) == "table"
            then
                if slotInfo.isSecondary == true then
                    modification =
                        SafeNumber(
                            Enum.TransmogModification.Secondary
                        )
                else
                    modification =
                        SafeNumber(
                            Enum.TransmogModification.Main
                        )
                end
            end

            if categoryID ~= nil
                and slotID ~= nil
                and transmogType ~= nil
                and modification ~= nil
            then
                local existing =
                    result[
                        categoryID
                    ]

                local shouldReplace =
                    existing == nil
                    or (
                        existing.isSecondary == true
                        and slotInfo.isSecondary ~= true
                    )

                if shouldReplace then
                    result[
                        categoryID
                    ] = {
                        isSecondary =
                            slotInfo.isSecondary == true,

                        data = {
                            slotID =
                                slotID,

                            type =
                                transmogType,

                            modification =
                                modification,
                        },
                    }
                end
            end
        end
    end

    return result
end

local function BuildCategoryFallbackLocation(
    categoryID
)
    if not C_TransmogCollection
        or type(
            C_TransmogCollection.GetCategoryInfo
        ) ~= "function"
    then
        return nil
    end

    local success,
        _name,
        _isWeapon,
        _canEnchant,
        canMainHand,
        canOffHand,
        canRanged =
        SafeCall(
            C_TransmogCollection.GetCategoryInfo,
            categoryID
        )

    if not success then
        return nil
    end

    local slotName = nil

    if canMainHand == true
        or canRanged == true
    then
        slotName =
            "MAINHANDSLOT"
    elseif canOffHand == true then
        slotName =
            "SECONDARYHANDSLOT"
    end

    if slotName == nil then
        return nil
    end

    return BuildLocationData(
        slotName
    )
end

local function ResolveCategoryLocation(
    categoryID,
    locationMap
)
    local existing =
        locationMap[
            categoryID
        ]

    if type(existing) == "table"
        and type(existing.data) == "table"
    then
        return existing.data
    end

    local fallback =
        BuildCategoryFallbackLocation(
            categoryID
        )

    if fallback ~= nil then
        locationMap[
            categoryID
        ] = {
            isSecondary =
                false,

            data =
                fallback,
        }

        return fallback
    end

    return nil
end

local function GetCategoryAppearances(
    categoryID,
    locationData
)
    if not C_TransmogCollection
        or type(
            C_TransmogCollection.GetCategoryAppearances
        ) ~= "function"
    then
        return nil
    end

    if categoryID == nil
        or type(locationData) ~= "table"
    then
        return nil
    end

    local success, appearances =
        SafeCall(
            C_TransmogCollection.GetCategoryAppearances,
            categoryID,
            locationData
        )

    if success
        and type(appearances) == "table"
    then
        return appearances
    end

    return nil
end

local function GetAppearanceSources(
    visualID,
    categoryID,
    locationData
)
    if not C_TransmogCollection
        or type(
            C_TransmogCollection.GetAppearanceSources
        ) ~= "function"
    then
        return nil
    end

    if visualID == nil
        or categoryID == nil
        or type(locationData) ~= "table"
    then
        return nil
    end

    local success, sources =
        SafeCall(
            C_TransmogCollection.GetAppearanceSources,
            visualID,
            categoryID,
            locationData
        )

    if success
        and type(sources) == "table"
    then
        return sources
    end

    return nil
end

local function WarmCollectedAppearanceData(
    candidates,
    locationMap
)
    for _, candidate
        in ipairs(candidates)
    do
        local categoryID =
            SafeNumber(
                candidate.categoryID
            )

        if categoryID ~= nil then
            local locationData =
                ResolveCategoryLocation(
                    categoryID,
                    locationMap
                )

            if type(locationData) == "table" then
                local appearances =
                    GetCategoryAppearances(
                        categoryID,
                        locationData
                    )

                if type(appearances) == "table" then
                    for _, appearance
                        in pairs(appearances)
                    do
                        if type(appearance) == "table"
                            and appearance.isCollected == true
                        then
                            local visualID =
                                SafeNumber(
                                    appearance.visualID
                                )

                            if visualID ~= nil then
                                GetAppearanceSources(
                                    visualID,
                                    categoryID,
                                    locationData
                                )
                            end
                        end
                    end
                end
            end
        end
    end
end

local function CountCollectedAppearances(
    categoryID,
    locationData
)
    local appearances =
        GetCategoryAppearances(
            categoryID,
            locationData
        )

    if type(appearances) ~= "table" then
        return nil
    end

    local seen = {}
    local count = 0

    for _, appearance
        in pairs(appearances)
    do
        if type(appearance) == "table"
            and appearance.isCollected == true
        then
            local visualID =
                SafeNumber(
                    appearance.visualID
                )

            if visualID ~= nil
                and not seen[visualID]
            then
                seen[visualID] = true
                count = count + 1
            end
        end
    end

    return count
end

local function GetCategoryCollectedCountFallback(
    categoryID
)
    if not C_TransmogCollection
        or type(
            C_TransmogCollection.GetCategoryCollectedCount
        ) ~= "function"
    then
        return nil
    end

    local success, value =
        SafeCall(
            C_TransmogCollection.GetCategoryCollectedCount,
            categoryID
        )

    if success then
        return SafeNumber(
            value
        )
    end

    return nil
end

local function GetCategoryTotal(
    categoryID
)
    if not C_TransmogCollection
        or type(
            C_TransmogCollection.GetCategoryTotal
        ) ~= "function"
    then
        return nil
    end

    local success, value =
        SafeCall(
            C_TransmogCollection.GetCategoryTotal,
            categoryID
        )

    if success then
        return SafeNumber(
            value
        )
    end

    return nil
end

local function CollectCategoryCounts(
    categoryID,
    locationData
)
    local collected = nil

    if type(locationData) == "table" then
        collected =
            CountCollectedAppearances(
                categoryID,
                locationData
            )
    end

    if collected == nil then
        collected =
            GetCategoryCollectedCountFallback(
                categoryID
            )
    end

    local total =
        GetCategoryTotal(
            categoryID
        )

    return collected,
        total
end

local function CollectCategories(
    snapshot,
    candidates,
    locationMap
)
    if type(C_TransmogCollection)
        ~= "table"
    then
        AddDiagnostic(
            snapshot,
            "C_TransmogCollection API unavailable."
        )

        return
    end

    local entries =
        snapshot.categories.entries

    for _, candidate
        in ipairs(candidates)
    do
        local locationData =
            ResolveCategoryLocation(
                candidate.categoryID,
                locationMap
            )

        local collected,
            total =
            CollectCategoryCounts(
                candidate.categoryID,
                locationData
            )

        if (
            total ~= nil
            and total > 0
        )
            or (
                collected ~= nil
                and collected > 0
            )
        then
            U.SafeInsert(
                entries,
                {
                    categoryID =
                        candidate.categoryID,

                    name =
                        ResolveCategoryName(
                            candidate.categoryID,
                            candidate.fallbackName
                        ),

                    collected =
                        collected,

                    total =
                        total,

                    sortOrder =
                        candidate.sortOrder,
                }
            )
        end
    end

    table.sort(
        entries,
        function(left, right)
            local leftSort =
                SafeNumber(
                    left.sortOrder
                )
                or 9999

            local rightSort =
                SafeNumber(
                    right.sortOrder
                )
                or 9999

            if leftSort ~= rightSort then
                return
                    leftSort
                    < rightSort
            end

            return
                (
                    SafeNumber(
                        left.categoryID
                    )
                    or 0
                )
                <
                (
                    SafeNumber(
                        right.categoryID
                    )
                    or 0
                )
        end
    )

    snapshot.categories.count =
        #entries
end

local function CollectSets(snapshot)
    if not C_TransmogSets
        or type(
            C_TransmogSets.GetAllSets
        ) ~= "function"
    then
        AddDiagnostic(
            snapshot,
            "C_TransmogSets.GetAllSets API unavailable."
        )

        return
    end

    local success, sets =
        SafeCall(
            C_TransmogSets.GetAllSets
        )

    if not success
        or type(sets) ~= "table"
    then
        AddDiagnostic(
            snapshot,
            "C_TransmogSets.GetAllSets call failed."
        )

        return
    end

    snapshot.sets.total =
        #sets

    local collectedCount = 0

    for _, setInfo
        in ipairs(sets)
    do
        if type(setInfo) == "table" then
            local isCollected =
                setInfo.collected

            if isCollected == true then
                collectedCount =
                    collectedCount + 1

                if #snapshot.sets.entries
                    < MAX_SET_ENTRIES
                then
                    U.SafeInsert(
                        snapshot.sets.entries,
                        {
                            setID =
                                SafeNumber(
                                    setInfo.setID
                                ),

                            baseSetID =
                                SafeNumber(
                                    setInfo.baseSetID
                                ),

                            name =
                                SafeString(
                                    setInfo.name
                                ),

                            description =
                                SafeString(
                                    setInfo.description
                                ),

                            label =
                                SafeString(
                                    setInfo.label
                                ),

                            expansionID =
                                SafeNumber(
                                    setInfo.expansionID
                                ),

                            classMask =
                                SafeNumber(
                                    setInfo.classMask
                                ),

                            favorite =
                                type(
                                    setInfo.favorite
                                ) == "boolean"
                                and setInfo.favorite
                                or nil,

                            isCollected =
                                true,
                        }
                    )
                end
            end
        end
    end

    snapshot.sets.collected =
        collectedCount
end

local function MergeSourceInfo(
    entry,
    sourceInfo
)
    if type(entry) ~= "table"
        or type(sourceInfo) ~= "table"
    then
        return
    end

    entry.sourceID =
        entry.sourceID
        or SafeNumber(
            sourceInfo.sourceID
        )

    entry.itemID =
        entry.itemID
        or SafeNumber(
            sourceInfo.itemID
        )

    entry.visualID =
        entry.visualID
        or SafeNumber(
            sourceInfo.visualID
        )
        or SafeNumber(
            sourceInfo.itemAppearanceID
        )

    entry.categoryID =
        entry.categoryID
        or SafeNumber(
            sourceInfo.categoryID
        )
        or SafeNumber(
            sourceInfo.category
        )

    if entry.name == nil then
        entry.name =
            SafeString(
                sourceInfo.name
            )
    end

    if entry.itemLink == nil then
        entry.itemLink =
            SafeString(
                sourceInfo.itemLink
            )
    end

    if entry.isCollected == nil
        and type(
            sourceInfo.isCollected
        ) == "boolean"
    then
        entry.isCollected =
            sourceInfo.isCollected
    end
end

local function EnrichSource(
    entry
)
    if type(entry) ~= "table"
        or entry.sourceID == nil
        or not C_TransmogCollection
    then
        return
    end

    if type(
        C_TransmogCollection.GetSourceInfo
    ) == "function"
    then
        local success, sourceInfo =
            SafeCall(
                C_TransmogCollection.GetSourceInfo,
                entry.sourceID
            )

        if success
            and type(sourceInfo) == "table"
        then
            MergeSourceInfo(
                entry,
                sourceInfo
            )
        end
    end

    if type(
        C_TransmogCollection.GetAppearanceSourceInfo
    ) == "function"
    then
        local success, sourceInfo =
            SafeCall(
                C_TransmogCollection.GetAppearanceSourceInfo,
                entry.sourceID
            )

        if success
            and type(sourceInfo) == "table"
        then
            MergeSourceInfo(
                entry,
                sourceInfo
            )
        end
    end

    if entry.itemID == nil
        and type(
            C_TransmogCollection.GetSourceItemID
        ) == "function"
    then
        local success, itemID =
            SafeCall(
                C_TransmogCollection.GetSourceItemID,
                entry.sourceID
            )

        if success then
            entry.itemID =
                SafeNumber(
                    itemID
                )
        end
    end

    if entry.name == nil
        and entry.itemID ~= nil
    then
        entry.name =
            U.GetItemDisplayName(
                entry.itemLink,
                entry.itemID
            )
    end
end

local function BuildAppearanceEntry(
    visualID,
    categoryID,
    locationMap
)
    visualID =
        SafeNumber(
            visualID
        )

    categoryID =
        SafeNumber(
            categoryID
        )

    if visualID == nil then
        return nil
    end

    local entry = {
        visualID =
            visualID,

        categoryID =
            categoryID,

        categoryName =
            categoryID
            and ResolveCategoryName(
                categoryID,
                nil
            )
            or nil,
    }

    if categoryID ~= nil then
        local locationData =
            ResolveCategoryLocation(
                categoryID,
                locationMap
            )

        local sources =
            GetAppearanceSources(
                visualID,
                categoryID,
                locationData
            )

        if type(sources) == "table" then
            local selectedSource = nil

            for _, source
                in pairs(sources)
            do
                if type(source) == "table" then
                    if selectedSource == nil then
                        selectedSource =
                            source
                    end

                    if source.isCollected == true then
                        selectedSource =
                            source

                        break
                    end
                end
            end

            if selectedSource ~= nil then
                MergeSourceInfo(
                    entry,
                    selectedSource
                )
            end
        end
    end

    EnrichSource(
        entry
    )

    return entry
end

local function CollectLatest(
    snapshot,
    locationMap
)
    if not C_TransmogCollection
        or type(
            C_TransmogCollection.GetLatestAppearance
        ) ~= "function"
    then
        AddDiagnostic(
            snapshot,
            "C_TransmogCollection.GetLatestAppearance API unavailable."
        )

        return
    end

    local success,
        visualID,
        categoryID =
        SafeCall(
            C_TransmogCollection.GetLatestAppearance
        )

    if not success then
        AddDiagnostic(
            snapshot,
            "C_TransmogCollection.GetLatestAppearance call failed."
        )

        return
    end

    visualID =
        SafeNumber(
            visualID
        )

    if visualID == nil then
        return
    end

    local entry =
        BuildAppearanceEntry(
            visualID,
            categoryID,
            locationMap
        )

    if entry then
        U.SafeInsert(
            snapshot.latest.entries,
            entry
        )
    end
end

local function CollectFavorites(
    snapshot,
    candidates,
    locationMap
)
    local entries =
        snapshot.favorites.entries

    snapshot.favorites.count =
        0

    if not C_TransmogCollection
        or type(
            C_TransmogCollection.GetCategoryAppearances
        ) ~= "function"
    then
        AddDiagnostic(
            snapshot,
            "C_TransmogCollection.GetCategoryAppearances API unavailable for favorites."
        )

        return
    end

    local hasFavorites = nil

    if type(
        C_TransmogCollection.HasFavorites
    ) == "function"
    then
        local success, value =
            SafeCall(
                C_TransmogCollection.HasFavorites
            )

        if success
            and type(value) == "boolean"
        then
            hasFavorites =
                value
        end
    end

    if hasFavorites == false then
        return
    end

    local seen = {}
    local maxFavorites = 20

    for _, candidate
        in ipairs(candidates)
    do
        if #entries >= maxFavorites then
            break
        end

        local categoryID =
            SafeNumber(
                candidate.categoryID
            )

        if categoryID ~= nil then
            local locationData =
                ResolveCategoryLocation(
                    categoryID,
                    locationMap
                )

            local appearances =
                GetCategoryAppearances(
                    categoryID,
                    locationData
                )

            if type(appearances) == "table" then
                for _, appearance
                    in pairs(appearances)
                do
                    if #entries >= maxFavorites then
                        break
                    end

                    if type(appearance) == "table"
                        and appearance.isFavorite == true
                    then
                        local visualID =
                            SafeNumber(
                                appearance.visualID
                            )

                        if visualID ~= nil
                            and not seen[visualID]
                        then
                            seen[visualID] =
                                true

                            local entry = {
                                visualID =
                                    visualID,

                                categoryID =
                                    categoryID,

                                categoryName =
                                    ResolveCategoryName(
                                        categoryID,
                                        candidate.fallbackName
                                    ),

                                isCollected =
                                    appearance.isCollected == true,

                                sortOrder =
                                    candidate.sortOrder,
                            }

                            local sources =
                                GetAppearanceSources(
                                    visualID,
                                    categoryID,
                                    locationData
                                )

                            if type(sources) == "table" then
                                local selectedSource = nil

                                for _, source
                                    in pairs(sources)
                                do
                                    if type(source) == "table" then
                                        if selectedSource == nil then
                                            selectedSource =
                                                source
                                        end

                                        if source.isCollected == true then
                                            selectedSource =
                                                source

                                            break
                                        end
                                    end
                                end

                                if selectedSource ~= nil then
                                    MergeSourceInfo(
                                        entry,
                                        selectedSource
                                    )
                                end
                            end

                            if entry.name == nil
                                and entry.itemID ~= nil
                            then
                                entry.name =
                                    U.GetItemDisplayName(
                                        entry.itemLink,
                                        entry.itemID
                                    )
                            end

                            U.SafeInsert(
                                entries,
                                entry
                            )
                        end
                    end
                end
            end
        end
    end

    table.sort(
        entries,
        function(left, right)
            local leftSort =
                SafeNumber(
                    left.sortOrder
                )
                or 9999

            local rightSort =
                SafeNumber(
                    right.sortOrder
                )
                or 9999

            if leftSort ~= rightSort then
                return leftSort < rightSort
            end

            local leftName =
                SafeString(
                    left.name
                )
                or ""

            local rightName =
                SafeString(
                    right.name
                )
                or ""

            if leftName ~= rightName then
                return leftName < rightName
            end

            return
                (
                    SafeNumber(
                        left.visualID
                    )
                    or 0
                )
                <
                (
                    SafeNumber(
                        right.visualID
                    )
                    or 0
                )
        end
    )

    snapshot.favorites.count =
        #entries

    if hasFavorites == true
        and #entries == 0
    then
        AddDiagnostic(
            snapshot,
            "Favorite appearances exist but category enumeration returned no favorite entries."
        )
    end
end
local function CollectOutfits(snapshot)
    if not C_TransmogCollection
        or type(
            C_TransmogCollection.GetCustomSets
        ) ~= "function"
    then
        AddDiagnostic(
            snapshot,
            "C_TransmogCollection.GetCustomSets API unavailable."
        )

        return
    end

    local success, customSetIDs =
        SafeCall(
            C_TransmogCollection.GetCustomSets
        )

    if not success
        or type(customSetIDs) ~= "table"
    then
        AddDiagnostic(
            snapshot,
            "C_TransmogCollection.GetCustomSets call failed."
        )

        return
    end

    snapshot.outfits.available =
        true

    snapshot.outfits.count =
        #customSetIDs

    for _, rawCustomSetID
        in ipairs(customSetIDs)
    do
        if #snapshot.outfits.entries
            >= MAX_OUTFITS
        then
            break
        end

        local customSetID =
            SafeNumber(
                rawCustomSetID
            )

        if customSetID ~= nil then
            local name = nil
            local icon = nil

            if type(
                C_TransmogCollection.GetCustomSetInfo
            ) == "function"
            then
                local infoSuccess,
                    resolvedName,
                    resolvedIcon =
                    SafeCall(
                        C_TransmogCollection.GetCustomSetInfo,
                        customSetID
                    )

                if infoSuccess then
                    name =
                        SafeString(
                            resolvedName
                        )

                    icon =
                        resolvedIcon
                end
            end

            U.SafeInsert(
                snapshot.outfits.entries,
                {
                    outfitID =
                        customSetID,

                    customSetID =
                        customSetID,

                    name =
                        name
                        or string.format(
                            "Custom Set %d",
                            customSetID
                        ),

                    icon =
                        icon,
                }
            )
        end
    end
end

function Appearances:Collect()
    local snapshot =
        NewSnapshot()

    local candidates =
        BuildCategoryCandidates()

    local locationMap =
        BuildTransmogLocationMap()

    if next(locationMap) ~= nil then
        WarmCollectedAppearanceData(
            candidates,
            locationMap
        )
    else
        AddDiagnostic(
            snapshot,
            "Forever transmog location data unavailable for appearance warm-up."
        )
    end

    CollectCategories(
        snapshot,
        candidates,
        locationMap
    )

    CollectSets(
        snapshot
    )

    CollectLatest(
        snapshot,
        locationMap
    )

    CollectFavorites(
        snapshot,
        candidates,
        locationMap
    )

    CollectOutfits(
        snapshot
    )

    return snapshot
end

ns:RegisterModule(
    "Data.Appearances",
    Appearances
)

ns.Data = ns.Data or {}
ns.Data.Appearances =
    Appearances