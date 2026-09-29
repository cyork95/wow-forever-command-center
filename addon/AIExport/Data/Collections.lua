local _, ns = ...

local U = ns.utils
local C = ns.constants

local Collections = {}

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
    return U.ToSafeString(value)
end

local function AddDiagnostic(result, message)
    if type(result) ~= "table"
        or type(result.diagnostics) ~= "table"
    then
        return
    end

    if not U.IsNonEmptyString(message) then
        return
    end

    U.SafeInsert(
        result.diagnostics,
        message
    )
end

local function CollectMounts(result)
    local mounts = result.mounts

    if not C_MountJournal then
        AddDiagnostic(
            result,
            "C_MountJournal is unavailable."
        )

        return
    end

    if type(C_MountJournal.GetMountIDs)
        ~= "function"
    then
        AddDiagnostic(
            result,
            "C_MountJournal.GetMountIDs is unavailable."
        )

        return
    end

    if type(C_MountJournal.GetMountInfoByID)
        ~= "function"
    then
        AddDiagnostic(
            result,
            "C_MountJournal.GetMountInfoByID is unavailable."
        )

        return
    end

    local success, mountIDs =
        SafeCall(
            C_MountJournal.GetMountIDs
        )

    if not success
        or type(mountIDs) ~= "table"
    then
        AddDiagnostic(
            result,
            "C_MountJournal.GetMountIDs failed."
        )

        return
    end

    mounts.total = #mountIDs

    for _, mountID in ipairs(mountIDs) do
        local infoSuccess,
            name,
            spellID,
            icon,
            isActive,
            isUsable,
            sourceType,
            isFavorite,
            isFactionSpecific,
            faction,
            shouldHideOnChar,
            isCollected,
            returnedMountID =
            SafeCall(
                C_MountJournal.GetMountInfoByID,
                mountID
            )

        if infoSuccess then
            if isCollected == true then
                mounts.collected =
                    mounts.collected + 1

                local entry = {
                    mountID =
                        SafeNumber(returnedMountID)
                        or SafeNumber(mountID),

                    name =
                        SafeString(name),

                    spellID =
                        SafeNumber(spellID),

                    icon =
                        icon,

                    isActive =
                        isActive == true,

                    isUsable =
                        isUsable == true,

                    sourceType =
                        SafeNumber(sourceType),

                    isFavorite =
                        isFavorite == true,

                    isFactionSpecific =
                        isFactionSpecific == true,

                    faction =
                        faction,

                    shouldHideOnChar =
                        shouldHideOnChar == true,
                }

                if type(
                    C_MountJournal.GetMountInfoExtraByID
                ) == "function"
                then
                    local extraSuccess,
                        creatureDisplayInfoID,
                        description,
                        sourceText,
                        isSelfMount,
                        mountTypeID =
                        SafeCall(
                            C_MountJournal.GetMountInfoExtraByID,
                            mountID
                        )

                    if extraSuccess then
                        entry.creatureDisplayInfoID =
                            SafeNumber(
                                creatureDisplayInfoID
                            )

                        entry.description =
                            SafeString(
                                description
                            )

                        entry.sourceText =
                            SafeString(
                                sourceText
                            )

                        entry.source =
                            entry.sourceText

                        entry.isSelfMount =
                            isSelfMount == true

                        entry.mountTypeID =
                            SafeNumber(
                                mountTypeID
                            )
                    end
                end

                U.SafeInsert(
                    mounts.entries,
                    entry
                )
            end
        else
            AddDiagnostic(
                result,
                string.format(
                    "C_MountJournal.GetMountInfoByID failed for mount ID %s.",
                    tostring(mountID)
                )
            )
        end
    end
end

local function CollectPets(result)
    local pets = result.pets

    if not C_PetJournal then
        AddDiagnostic(
            result,
            "C_PetJournal is unavailable."
        )

        return
    end

    if type(C_PetJournal.GetNumPets)
        ~= "function"
    then
        AddDiagnostic(
            result,
            "C_PetJournal.GetNumPets is unavailable."
        )

        return
    end

    if type(C_PetJournal.GetPetInfoByIndex)
        ~= "function"
    then
        AddDiagnostic(
            result,
            "C_PetJournal.GetPetInfoByIndex is unavailable."
        )

        return
    end

    local countSuccess,
        numPets,
        numOwned =
        SafeCall(
            C_PetJournal.GetNumPets
        )

    if not countSuccess then
        AddDiagnostic(
            result,
            "C_PetJournal.GetNumPets failed."
        )

        return
    end

    pets.total =
        SafeNumber(numPets)
        or 0

    pets.reportedOwned =
        SafeNumber(numOwned)

    for index = 1, pets.total do
        local petSuccess,
            petID,
            speciesID,
            isOwned,
            customName,
            level,
            favorite,
            isRevoked,
            speciesName,
            icon,
            petType,
            companionID,
            tooltipSource,
            tooltipDescription,
            isWild,
            canBattle,
            isTradeable,
            isUnique,
            obtainable =
            SafeCall(
                C_PetJournal.GetPetInfoByIndex,
                index
            )

        if petSuccess then
            local owned =
                isOwned == true
                or petID ~= nil

            if owned then
                pets.owned =
                    pets.owned + 1

                local entry = {
                    petID =
                        SafeString(petID),

                    speciesID =
                        SafeNumber(speciesID),

                    speciesName =
                        SafeString(speciesName),

                    customName =
                        SafeString(customName),

                    level =
                        SafeNumber(level),

                    favorite =
                        favorite == true,

                    isRevoked =
                        isRevoked == true,

                    petType =
                        SafeNumber(petType),

                    companionID =
                        SafeNumber(companionID),

                    tooltipSource =
                        SafeString(
                            tooltipSource
                        ),

                    tooltipDescription =
                        SafeString(
                            tooltipDescription
                        ),

                    isWild =
                        isWild == true,

                    canBattle =
                        canBattle == true,

                    isTradeable =
                        isTradeable == true,

                    isUnique =
                        isUnique == true,

                    obtainable =
                        obtainable,

                    icon =
                        icon,
                }

                if entry.petID
                    and type(
                        C_PetJournal.GetPetStats
                    ) == "function"
                then
                    local statsSuccess,
                        health,
                        maxHealth,
                        power,
                        speed,
                        rarity =
                        SafeCall(
                            C_PetJournal.GetPetStats,
                            entry.petID
                        )

                    if statsSuccess then
                        entry.health =
                            SafeNumber(
                                health
                            )

                        entry.maxHealth =
                            SafeNumber(
                                maxHealth
                            )

                        entry.power =
                            SafeNumber(
                                power
                            )

                        entry.speed =
                            SafeNumber(
                                speed
                            )

                        entry.rarity =
                            SafeNumber(
                                rarity
                            )
                    end
                end

                U.SafeInsert(
                    pets.entries,
                    entry
                )
            end
        else
            AddDiagnostic(
                result,
                string.format(
                    "C_PetJournal.GetPetInfoByIndex failed for pet index %d.",
                    index
                )
            )
        end
    end
end

local function GetToyCount(result)
    if not C_ToyBox then
        AddDiagnostic(
            result,
            "C_ToyBox is unavailable."
        )

        return nil
    end

    if type(C_ToyBox.GetNumFilteredToys)
        == "function"
    then
        local success, count =
            SafeCall(
                C_ToyBox.GetNumFilteredToys
            )

        if success then
            return SafeNumber(count) or 0
        end
    end

    AddDiagnostic(
        result,
        "C_ToyBox.GetNumFilteredToys is unavailable or failed."
    )

    return nil
end

local function CollectToys(result)
    local toys = result.toys

    if not C_ToyBox then
        AddDiagnostic(
            result,
            "C_ToyBox is unavailable."
        )

        return
    end

    if type(C_ToyBox.GetToyFromIndex)
        ~= "function"
    then
        AddDiagnostic(
            result,
            "C_ToyBox.GetToyFromIndex is unavailable."
        )

        return
    end

    if type(C_ToyBox.GetToyInfo)
        ~= "function"
    then
        AddDiagnostic(
            result,
            "C_ToyBox.GetToyInfo is unavailable."
        )

        return
    end

    local filteredToyCount =
        GetToyCount(result)

    if filteredToyCount == nil then
        return
    end

    toys.filteredTotal =
        filteredToyCount

    if type(C_ToyBox.GetNumToys)
        == "function"
    then
        local totalSuccess,
            totalToys =
            SafeCall(
                C_ToyBox.GetNumToys
            )

        if totalSuccess then
            toys.total =
                SafeNumber(totalToys)
                or filteredToyCount
        else
            toys.total =
                filteredToyCount
        end
    else
        toys.total =
            filteredToyCount
    end

    for index = 1, filteredToyCount do
        local indexSuccess, itemID =
            SafeCall(
                C_ToyBox.GetToyFromIndex,
                index
            )

        itemID =
            indexSuccess
            and SafeNumber(itemID)
            or nil

        if itemID
            and itemID > 0
        then
            local infoSuccess,
                returnedItemID,
                toyName,
                icon,
                isFavorite,
                hasFanfare,
                itemQuality =
                SafeCall(
                    C_ToyBox.GetToyInfo,
                    itemID
                )

            if infoSuccess then
                local resolvedItemID =
                    SafeNumber(
                        returnedItemID
                    )
                    or itemID

                local owned = false

                if type(PlayerHasToy)
                    == "function"
                then
                    local ownedSuccess,
                        hasToy =
                        SafeCall(
                            PlayerHasToy,
                            resolvedItemID
                        )

                    owned =
                        ownedSuccess
                        and hasToy == true
                end

                if owned then
                    toys.owned =
                        toys.owned + 1

                    U.SafeInsert(
                        toys.entries,
                        {
                            itemID =
                                resolvedItemID,

                            toyName =
                                SafeString(
                                    toyName
                                ),

                            icon =
                                icon,

                            isFavorite =
                                isFavorite == true,

                            hasFanfare =
                                hasFanfare == true,

                            itemQuality =
                                SafeNumber(
                                    itemQuality
                                ),
                        }
                    )
                end
            else
                AddDiagnostic(
                    result,
                    string.format(
                        "C_ToyBox.GetToyInfo failed for toy item ID %s.",
                        tostring(itemID)
                    )
                )
            end
        elseif not indexSuccess then
            AddDiagnostic(
                result,
                string.format(
                    "C_ToyBox.GetToyFromIndex failed for index %d.",
                    index
                )
            )
        end
    end
end

function Collections:Collect()
    local result = {
        key =
            C.SECTIONS.COLLECTIONS,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.COLLECTIONS
            ],

        mounts = {
            total = 0,
            collected = 0,
            entries = {},
        },

        pets = {
            total = 0,
            owned = 0,
            reportedOwned = nil,
            entries = {},
        },

        toys = {
            total = 0,
            filteredTotal = 0,
            owned = 0,
            entries = {},
        },

        diagnostics = {},
    }

    CollectMounts(result)
    CollectPets(result)
    CollectToys(result)

    return result
end

ns:RegisterModule(
    "Data.Collections",
    Collections
)

ns.Data = ns.Data or {}
ns.Data.Collections = Collections