local _, ns = ...

local U = ns.utils
local C = ns.constants

local CollectedAppearances = {}

local MAX_ENTRIES = 10000

local CATEGORY_ORDER = {
    { name = "Head", enumKey = "Head", categoryID = 1 },
    { name = "Shoulder", enumKey = "Shoulder", categoryID = 2 },
    { name = "Back", enumKey = "Back", categoryID = 3 },
    { name = "Chest", enumKey = "Chest", categoryID = 4 },
    { name = "Shirt", enumKey = "Shirt", categoryID = 5 },
    { name = "Tabard", enumKey = "Tabard", categoryID = 6 },
    { name = "Wrist", enumKey = "Wrist", categoryID = 7 },
    { name = "Hands", enumKey = "Hands", categoryID = 8 },
    { name = "Waist", enumKey = "Waist", categoryID = 9 },
    { name = "Legs", enumKey = "Legs", categoryID = 10 },
    { name = "Feet", enumKey = "Feet", categoryID = 11 },
    { name = "Wand", enumKey = "Wand", categoryID = 12 },
    { name = "One-Handed Axes", enumKey = "OneHAxe", categoryID = 13 },
    { name = "One-Handed Swords", enumKey = "OneHSword", categoryID = 14 },
    { name = "One-Handed Maces", enumKey = "OneHMace", categoryID = 15 },
    { name = "Daggers", enumKey = "Dagger", categoryID = 16 },
    { name = "Fist Weapons", enumKey = "Fist", categoryID = 17 },
    { name = "Shields", enumKey = "Shield", categoryID = 18 },
    { name = "Held In Off-hand", enumKey = "Holdable", categoryID = 19 },
    { name = "Two-Handed Axes", enumKey = "TwoHAxe", categoryID = 20 },
    { name = "Two-Handed Swords", enumKey = "TwoHSword", categoryID = 21 },
    { name = "Two-Handed Maces", enumKey = "TwoHMace", categoryID = 22 },
    { name = "Staves", enumKey = "Staff", categoryID = 23 },
    { name = "Polearms", enumKey = "Polearm", categoryID = 24 },
    { name = "Bows", enumKey = "Bow", categoryID = 25 },
    { name = "Guns", enumKey = "Gun", categoryID = 26 },
    { name = "Crossbows", enumKey = "Crossbow", categoryID = 27 },
    { name = "Warglaives", enumKey = "Warglaives", categoryID = 28 },
    { name = "Paired", enumKey = "Paired", categoryID = 29 },
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
    if type(value) ~= "string"
        and type(value) ~= "number"
        and type(value) ~= "boolean"
    then
        return nil
    end

    local text = U.Trim(tostring(value))

    if text == "" then
        return nil
    end

    return text
end

local function NormalizeName(value)
    local text = SafeString(value)

    if text == nil then
        return nil
    end

    text = text:gsub("[\r\n]+", " ")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = U.Trim(text)

    if text == "" then
        return nil
    end

    local lower = string.lower(text)

    if lower == "unknown"
        or lower == "unknown item"
        or lower == "[unknown appearance]"
    then
        return nil
    end

    return text
end

local function AddDiagnostic(snapshot, message)
    if type(snapshot) ~= "table"
        or type(snapshot.diagnostics) ~= "table"
    then
        return
    end

    if not U.IsNonEmptyString(message) then
        return
    end

    U.SafeInsert(snapshot.diagnostics, message)
end

local function NewSnapshot()
    return {
        key = C.SECTIONS.COLLECTED_APPEARANCES,
        title = C.SECTION_LABELS[C.SECTIONS.COLLECTED_APPEARANCES],
        total = 0,
        entries = {},
        categories = {},
        truncated = false,
        maxEntries = MAX_ENTRIES,
        diagnostics = {},
    }
end

local function GetEnumCategoryID(enumKey, fallbackID)
    if Enum
        and type(Enum.TransmogCollectionType) == "table"
    then
        local value =
            SafeNumber(
                Enum.TransmogCollectionType[enumKey]
            )

        if value ~= nil then
            return value
        end
    end

    return SafeNumber(fallbackID)
end

local function BuildCategoryCandidates()
    local categories = {}
    local seen = {}

    for order, definition
        in ipairs(CATEGORY_ORDER)
    do
        local categoryID =
            GetEnumCategoryID(
                definition.enumKey,
                definition.categoryID
            )

        if categoryID ~= nil
            and not seen[categoryID]
        then
            seen[categoryID] = true

            U.SafeInsert(
                categories,
                {
                    categoryID = categoryID,
                    fallbackName = definition.name,
                    sortOrder = order,
                }
            )
        end
    end

    return categories
end

local function ResolveCategoryName(categoryID, fallbackName)
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

local function GetCollectedCount(categoryID)
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

    if not success then
        return nil
    end

    return SafeNumber(value)
end

local function GetInventorySlotID(slotName)
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
            return SafeNumber(slotID)
        end
    end

    if type(GetInventorySlotInfo) == "function" then
        local success, slotID =
            SafeCall(
                GetInventorySlotInfo,
                slotName
            )

        if success then
            return SafeNumber(slotID)
        end
    end

    return nil
end

local function GetAppearanceTransmogType()
    if not Enum
        or type(Enum.TransmogType) ~= "table"
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

local function BuildLocationData(slotName)
    local slotID =
        GetInventorySlotID(slotName)

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
        slotID = slotID,
        type = transmogType,
        modification = modification,
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

            local modification = nil

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
                    result[categoryID]

                local shouldReplace =
                    existing == nil
                    or (
                        existing.isSecondary == true
                        and slotInfo.isSecondary ~= true
                    )

                if shouldReplace then
                    result[categoryID] = {
                        isSecondary =
                            slotInfo.isSecondary == true,

                        data = {
                            slotID = slotID,
                            type = transmogType,
                            modification = modification,
                        },
                    }
                end
            end
        end
    end

    return result
end

local function BuildCategoryFallbackLocation(categoryID)
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
        slotName = "MAINHANDSLOT"
    elseif canOffHand == true then
        slotName = "SECONDARYHANDSLOT"
    end

    if slotName == nil then
        return nil
    end

    return BuildLocationData(slotName)
end

local function ResolveCategoryLocation(
    categoryID,
    locationMap
)
    local existing =
        locationMap[categoryID]

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
        locationMap[categoryID] = {
            isSecondary = false,
            data = fallback,
        }

        return fallback
    end

    return nil
end

local function ResolveSourceName(source)
    if type(source) ~= "table" then
        return nil
    end

    local name =
        NormalizeName(
            source.name
        )

    if name ~= nil then
        return name
    end

    local itemID =
        SafeNumber(
            source.itemID
        )

    if itemID ~= nil
        and type(
            U.GetItemDisplayName
        ) == "function"
    then
        name =
            NormalizeName(
                U.GetItemDisplayName(
                    nil,
                    itemID
                )
            )

        if name ~= nil then
            return name
        end
    end

    return nil
end

local function DedupeKey(entry)
    if type(entry) ~= "table" then
        return nil
    end

    if entry.sourceID ~= nil then
        return
            "source:"
            .. tostring(
                entry.sourceID
            )
    end

    if entry.appearanceID ~= nil
        and entry.itemID ~= nil
    then
        return
            "appearance-item:"
            .. tostring(
                entry.appearanceID
            )
            .. ":"
            .. tostring(
                entry.itemID
            )
    end

    if entry.appearanceID ~= nil then
        return
            "appearance:"
            .. tostring(
                entry.appearanceID
            )
    end

    return nil
end

local function AddEntry(
    snapshot,
    seen,
    entry
)
    if type(entry) ~= "table" then
        return false
    end

    if #snapshot.entries
        >= MAX_ENTRIES
    then
        snapshot.truncated = true

        return false
    end

    entry.sourceID =
        SafeNumber(
            entry.sourceID
        )

    entry.itemID =
        SafeNumber(
            entry.itemID
        )

    entry.appearanceID =
        SafeNumber(
            entry.appearanceID
        )

    entry.categoryID =
        SafeNumber(
            entry.categoryID
        )

    entry.name =
        NormalizeName(
            entry.name
        )

    entry.itemName =
        NormalizeName(
            entry.itemName
        )

    entry.categoryName =
        SafeString(
            entry.categoryName
        )

    entry.isCollected = true

    local key =
        DedupeKey(entry)

    if key == nil
        or seen[key]
    then
        return false
    end

    seen[key] = true

    U.SafeInsert(
        snapshot.entries,
        entry
    )

    snapshot.total =
        #snapshot.entries

    return true
end

local function BuildSourceEntry(
    source,
    categoryID,
    categoryName,
    appearanceID
)
    if type(source) ~= "table" then
        return nil
    end

    local sourceID =
        SafeNumber(
            source.sourceID
        )

    local itemID =
        SafeNumber(
            source.itemID
        )

    -- Preserve the visual appearance currently being enumerated.
    -- source.visualID is only a fallback, matching the Retail collector.
    local resolvedAppearanceID =
        SafeNumber(
            appearanceID
        )
        or SafeNumber(
            source.visualID
        )

    local resolvedCategoryID =
        SafeNumber(
            categoryID
        )
        or SafeNumber(
            source.categoryID
        )

    local resolvedName =
        ResolveSourceName(
            source
        )

    if sourceID == nil
        and itemID == nil
        and resolvedAppearanceID == nil
    then
        return nil
    end

    return {
        sourceID = sourceID,
        itemID = itemID,
        appearanceID = resolvedAppearanceID,
        categoryID = resolvedCategoryID,
        categoryName = categoryName,
        name = resolvedName,
        itemName = resolvedName,
        isCollected = true,
    }
end

local function GetAppearanceSources(
    appearanceID,
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

    if appearanceID == nil
        or categoryID == nil
        or type(locationData) ~= "table"
    then
        return nil
    end

    local success, sources =
        SafeCall(
            C_TransmogCollection.GetAppearanceSources,
            appearanceID,
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

local function CollectAppearanceSources(
    snapshot,
    seen,
    categoryID,
    categoryName,
    appearanceID,
    locationData
)
    local sources =
        GetAppearanceSources(
            appearanceID,
            categoryID,
            locationData
        )

    if type(sources) ~= "table" then
        return false
    end

    local added = false

    for _, source
        in pairs(sources)
    do
        if type(source) == "table"
            and source.isCollected == true
        then
            local entry =
                BuildSourceEntry(
                    source,
                    categoryID,
                    categoryName,
                    appearanceID
                )

            if AddEntry(
                snapshot,
                seen,
                entry
            )
            then
                added = true
            end
        end

        if snapshot.truncated then
            break
        end
    end

    return added
end

local function AddAppearanceFallback(
    snapshot,
    seen,
    categoryID,
    categoryName,
    appearanceID
)
    return AddEntry(
        snapshot,
        seen,
        {
            categoryID = categoryID,
            categoryName = categoryName,
            appearanceID = appearanceID,
            isCollected = true,
        }
    )
end

local function CollectCategory(
    snapshot,
    seen,
    candidate,
    locationMap
)
    local categoryID =
        SafeNumber(
            candidate.categoryID
        )

    if categoryID == nil then
        return
    end

    local collectedCount =
        GetCollectedCount(
            categoryID
        )

    if collectedCount == nil
        or collectedCount <= 0
    then
        return
    end

    local locationData =
        ResolveCategoryLocation(
            categoryID,
            locationMap
        )

    if type(locationData) ~= "table" then
        AddDiagnostic(
            snapshot,
            string.format(
                "No Forever transmog location found for category %s.",
                tostring(categoryID)
            )
        )

        return
    end

    if not C_TransmogCollection
        or type(
            C_TransmogCollection.GetCategoryAppearances
        ) ~= "function"
    then
        AddDiagnostic(
            snapshot,
            "C_TransmogCollection.GetCategoryAppearances API unavailable."
        )

        return
    end

    local success, appearances =
        SafeCall(
            C_TransmogCollection.GetCategoryAppearances,
            categoryID,
            locationData
        )

    if not success
        or type(appearances) ~= "table"
    then
        AddDiagnostic(
            snapshot,
            string.format(
                "GetCategoryAppearances failed for category %s.",
                tostring(categoryID)
            )
        )

        return
    end

    local categoryName =
        ResolveCategoryName(
            categoryID,
            candidate.fallbackName
        )

    local category = {
        categoryID = categoryID,
        categoryName = categoryName,
        name = categoryName,
        sortOrder = candidate.sortOrder,
        count = 0,
    }

    U.SafeInsert(
        snapshot.categories,
        category
    )

    for _, appearance
        in pairs(appearances)
    do
        if type(appearance) == "table"
            and appearance.isCollected == true
        then
            local appearanceID =
                SafeNumber(
                    appearance.visualID
                )

            if appearanceID ~= nil then
                local added =
                    CollectAppearanceSources(
                        snapshot,
                        seen,
                        categoryID,
                        categoryName,
                        appearanceID,
                        locationData
                    )

                if not added then
                    added =
                        AddAppearanceFallback(
                            snapshot,
                            seen,
                            categoryID,
                            categoryName,
                            appearanceID
                        )
                end

                if added then
                    category.count =
                        category.count + 1
                end
            end
        end

        if snapshot.truncated then
            break
        end
    end
end

local function GetEntryName(entry)
    if type(entry) ~= "table" then
        return ""
    end

    return
        NormalizeName(
            entry.itemName
        )
        or NormalizeName(
            entry.name
        )
        or ""
end

local function SortSnapshot(snapshot)
    table.sort(
        snapshot.categories,
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

    local categorySort = {}

    for index, category
        in ipairs(snapshot.categories)
    do
        local categoryID =
            SafeNumber(
                category.categoryID
            )

        if categoryID ~= nil then
            categorySort[categoryID] =
                SafeNumber(
                    category.sortOrder
                )
                or index
        end
    end

    table.sort(
        snapshot.entries,
        function(left, right)
            local leftCategory =
                categorySort[
                    SafeNumber(
                        left.categoryID
                    )
                    or -1
                ]
                or 9999

            local rightCategory =
                categorySort[
                    SafeNumber(
                        right.categoryID
                    )
                    or -1
                ]
                or 9999

            if leftCategory ~= rightCategory then
                return
                    leftCategory
                    < rightCategory
            end

            local leftName =
                string.lower(
                    GetEntryName(left)
                )

            local rightName =
                string.lower(
                    GetEntryName(right)
                )

            if leftName ~= rightName then
                return
                    leftName
                    < rightName
            end

            local leftItemID =
                SafeNumber(
                    left.itemID
                )
                or 0

            local rightItemID =
                SafeNumber(
                    right.itemID
                )
                or 0

            if leftItemID ~= rightItemID then
                return
                    leftItemID
                    < rightItemID
            end

            local leftSourceID =
                SafeNumber(
                    left.sourceID
                )
                or 0

            local rightSourceID =
                SafeNumber(
                    right.sourceID
                )
                or 0

            if leftSourceID ~= rightSourceID then
                return
                    leftSourceID
                    < rightSourceID
            end

            return
                (
                    SafeNumber(
                        left.appearanceID
                    )
                    or 0
                )
                <
                (
                    SafeNumber(
                        right.appearanceID
                    )
                    or 0
                )
        end
    )
end

function CollectedAppearances:Collect()
    local snapshot =
        NewSnapshot()

    if type(C_TransmogCollection)
        ~= "table"
    then
        AddDiagnostic(
            snapshot,
            "C_TransmogCollection API unavailable."
        )

        return snapshot
    end

    local locationMap =
        BuildTransmogLocationMap()

    if next(locationMap) == nil then
        AddDiagnostic(
            snapshot,
            "Forever transmog location data unavailable."
        )

        return snapshot
    end

    local seen = {}

    for _, candidate
        in ipairs(
            BuildCategoryCandidates()
        )
    do
        CollectCategory(
            snapshot,
            seen,
            candidate,
            locationMap
        )

        if snapshot.truncated then
            break
        end
    end

    SortSnapshot(snapshot)

    snapshot.total =
        #snapshot.entries

    return snapshot
end

ns:RegisterModule(
    "Data.CollectedAppearances",
    CollectedAppearances
)

ns.Data = ns.Data or {}
ns.Data.CollectedAppearances =
    CollectedAppearances