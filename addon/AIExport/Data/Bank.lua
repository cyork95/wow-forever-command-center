local _, ns = ...

local U = ns.utils
local C = ns.constants

local Bank = {}

local FALLBACK_MAIN_BANK_ID = -1
local FALLBACK_FIRST_BANK_BAG_ID = 5
local FALLBACK_BANK_BAG_COUNT = 7

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end

    return pcall(fn, ...)
end

local function SafeTime()
    if type(time) ~= "function" then
        return nil
    end

    local success, value =
        SafeCall(time)

    if not success then
        return nil
    end

    return U.ToSafeNumber(value)
end

local function GetEnumBagIndex(name)
    if not Enum
        or type(Enum.BagIndex) ~= "table"
    then
        return nil
    end

    return U.ToSafeNumber(
        Enum.BagIndex[name]
    )
end

local function GetMainBankBagID()
    local bagID =
        GetEnumBagIndex("Bank")

    if bagID ~= nil then
        return bagID
    end

    bagID =
        U.ToSafeNumber(BANK_CONTAINER)

    if bagID ~= nil then
        return bagID
    end

    return FALLBACK_MAIN_BANK_ID
end

local function GetReagentBankBagID()
    local candidates = {
        "Reagentbank",
        "ReagentBank",
    }

    for _, key in ipairs(candidates) do
        local bagID =
            GetEnumBagIndex(key)

        if bagID ~= nil then
            return bagID
        end
    end

    local globalID =
        U.ToSafeNumber(
            REAGENTBANK_CONTAINER
        )

    if globalID ~= nil then
        return globalID
    end

    return nil
end

local function AddUniqueBagID(
    bagIDs,
    seen,
    bagID
)
    bagID =
        U.ToSafeNumber(bagID)

    if bagID == nil
        or seen[bagID]
    then
        return
    end

    seen[bagID] = true

    U.SafeInsert(
        bagIDs,
        bagID
    )
end

local function GetBankBagIDs()
    local bagIDs = {}
    local seen = {}

    if Enum
        and type(Enum.BagIndex) == "table"
    then
        for index = 1, 7 do
            local candidates = {
                string.format(
                    "BankBag_%d",
                    index
                ),

                string.format(
                    "BankBag%d",
                    index
                ),
            }

            for _, key in ipairs(candidates) do
                local bagID =
                    GetEnumBagIndex(key)

                if bagID ~= nil then
                    AddUniqueBagID(
                        bagIDs,
                        seen,
                        bagID
                    )

                    break
                end
            end
        end
    end

    if #bagIDs == 0 then
        local bankBagCount =
            U.ToSafeNumber(
                NUM_BANKBAGSLOTS
            )
            or FALLBACK_BANK_BAG_COUNT

        for index = 1, bankBagCount do
            AddUniqueBagID(
                bagIDs,
                seen,
                FALLBACK_FIRST_BANK_BAG_ID
                    + index
                    - 1
            )
        end
    end

    local mainBankID =
        GetMainBankBagID()

    local reagentBankID =
        GetReagentBankBagID()

    local filtered = {}

    for _, bagID in ipairs(bagIDs) do
        if bagID ~= mainBankID
            and bagID ~= reagentBankID
        then
            U.SafeInsert(
                filtered,
                bagID
            )
        end
    end

    table.sort(filtered)

    return filtered
end

local function GetContainerNumSlots(bagID)
    if not C_Container
        or type(
            C_Container.GetContainerNumSlots
        ) ~= "function"
    then
        return 0
    end

    local success, numSlots =
        SafeCall(
            C_Container.GetContainerNumSlots,
            bagID
        )

    if not success then
        return 0
    end

    return U.SafeNumber(
        numSlots,
        0
    )
end

local function GetContainerItemLink(
    bagID,
    slot
)
    if not C_Container
        or type(
            C_Container.GetContainerItemLink
        ) ~= "function"
    then
        return nil
    end

    local success, hyperlink =
        SafeCall(
            C_Container.GetContainerItemLink,
            bagID,
            slot
        )

    if not success
        or type(hyperlink) ~= "string"
        or hyperlink == ""
    then
        return nil
    end

    return hyperlink
end

local function GetContainerItemID(
    bagID,
    slot
)
    if not C_Container
        or type(
            C_Container.GetContainerItemID
        ) ~= "function"
    then
        return nil
    end

    local success, itemID =
        SafeCall(
            C_Container.GetContainerItemID,
            bagID,
            slot
        )

    if not success then
        return nil
    end

    return U.ToSafeNumber(itemID)
end

local function GetContainerItemStackCount(
    bagID,
    slot
)
    if not C_Container
        or type(
            C_Container.GetContainerItemInfo
        ) ~= "function"
    then
        return 1
    end

    local success, info =
        SafeCall(
            C_Container.GetContainerItemInfo,
            bagID,
            slot
        )

    if not success
        or type(info) ~= "table"
    then
        return 1
    end

    return U.SafeNumber(
        info.stackCount,
        1
    )
end

local function GetBagName(
    bagID,
    fallback
)
    if C_Container
        and type(
            C_Container.GetBagName
        ) == "function"
    then
        local success, name =
            SafeCall(
                C_Container.GetBagName,
                bagID
            )

        if success
            and U.IsNonEmptyString(name)
        then
            return name
        end
    end

    return fallback
end

local function CreateBagItemLocation(
    bagID,
    slot
)
    if not ItemLocation
        or type(
            ItemLocation.CreateFromBagAndSlot
        ) ~= "function"
    then
        return nil
    end

    local success, location =
        SafeCall(
            ItemLocation.CreateFromBagAndSlot,
            ItemLocation,
            bagID,
            slot
        )

    if success then
        return location
    end

    return nil
end

local function CollectBagItems(
    bagID,
    fallbackLabel
)
    local section =
        U.MakeSection(
            GetBagName(
                bagID,
                fallbackLabel
            )
        )

    local numSlots =
        GetContainerNumSlots(
            bagID
        )

    section.bagID = bagID
    section.numSlots = numSlots
    section.usedSlots = 0

    for slot = 1, numSlots do
        local hyperlink =
            GetContainerItemLink(
                bagID,
                slot
            )

        if hyperlink then
            local itemID =
                GetContainerItemID(
                    bagID,
                    slot
                )

            local stackCount =
                GetContainerItemStackCount(
                    bagID,
                    slot
                )

            local itemLocation =
                CreateBagItemLocation(
                    bagID,
                    slot
                )

            local entry =
                U.MakeItemEntry(
                    hyperlink,
                    stackCount,
                    itemID,
                    itemLocation
                )

            if entry then
                entry.slot = slot

                U.SafeInsert(
                    section.items,
                    entry
                )

                section.usedSlots =
                    section.usedSlots + 1
            end
        end
    end

    return section
end

local function CollectCurrentBankSections()
    local sections = {}

    local mainBankID =
        GetMainBankBagID()

    U.SafeInsert(
        sections,
        CollectBagItems(
            mainBankID,
            "Main Bank"
        )
    )

    local bankBagIDs =
        GetBankBagIDs()

    for index, bagID
        in ipairs(bankBagIDs)
    do
        U.SafeInsert(
            sections,
            CollectBagItems(
                bagID,
                string.format(
                    "Bank Bag %d",
                    index
                )
            )
        )
    end

    local reagentBankID =
        GetReagentBankBagID()

    if reagentBankID ~= nil
        and reagentBankID ~= mainBankID
    then
        U.SafeInsert(
            sections,
            CollectBagItems(
                reagentBankID,
                "Reagent Bank"
            )
        )
    end

    return sections
end

local function GetPlayerIdentity()
    local characterName =
        "UnknownCharacter"

    local realmName =
        "UnknownRealm"

    if type(UnitName) == "function" then
        local success, name =
            SafeCall(
                UnitName,
                "player"
            )

        if success
            and U.IsNonEmptyString(name)
        then
            characterName = name
        end
    end

    if type(GetRealmName) == "function" then
        local success, realm =
            SafeCall(GetRealmName)

        if success
            and U.IsNonEmptyString(realm)
        then
            realmName = realm
        end
    end

    return realmName, characterName
end

local function GetBankSnapshotStore(
    createIfMissing
)
    if not ns.state
        or type(ns.state.db) ~= "table"
    then
        return nil
    end

    local db =
        ns.state.db

    if createIfMissing
        and type(db.bankCache) ~= "table"
    then
        db.bankCache = {}
    end

    if type(db.bankCache) ~= "table" then
        return nil
    end

    local realmName,
        characterName =
        GetPlayerIdentity()

    if createIfMissing
        and type(
            db.bankCache[realmName]
        ) ~= "table"
    then
        db.bankCache[realmName] = {}
    end

    local realmStore =
        db.bankCache[realmName]

    if type(realmStore) ~= "table" then
        return nil
    end

    if createIfMissing
        and type(
            realmStore[characterName]
        ) ~= "table"
    then
        realmStore[characterName] = {}
    end

    local characterStore =
        realmStore[characterName]

    if type(characterStore) ~= "table" then
        return nil
    end

    return characterStore
end

function Bank:UpdateCacheFromLive()
    if not ns:IsBankOpen() then
        return nil
    end

    local snapshotStore =
        GetBankSnapshotStore(true)

    if not snapshotStore then
        return nil
    end

    local snapshot = {
        sections =
            CollectCurrentBankSections(),

        lastUpdated =
            SafeTime(),
    }

    snapshotStore.snapshot =
        snapshot

    return snapshot
end

function Bank:GetCachedSnapshot()
    local snapshotStore =
        GetBankSnapshotStore(false)

    if not snapshotStore
        or type(
            snapshotStore.snapshot
        ) ~= "table"
    then
        return nil
    end

    return snapshotStore.snapshot
end

function Bank:Collect()
    local available = false
    local cached = false
    local sections = {}
    local lastUpdated = nil
    local unavailableMessage = nil

    if ns:IsBankOpen() then
        local liveSnapshot =
            self:UpdateCacheFromLive()

        available = true
        cached = false

        if liveSnapshot then
            sections =
                liveSnapshot.sections
                or {}

            lastUpdated =
                liveSnapshot.lastUpdated
        else
            sections =
                CollectCurrentBankSections()

            lastUpdated =
                SafeTime()
        end
    else
        local cachedSnapshot =
            self:GetCachedSnapshot()

        if cachedSnapshot then
            available = true
            cached = true

            sections =
                cachedSnapshot.sections
                or {}

            lastUpdated =
                cachedSnapshot.lastUpdated
        else
            unavailableMessage =
                C.TEXT.BANK_UNAVAILABLE_NO_CACHE
        end
    end

    return {
        key =
            C.SECTIONS.BANK,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.BANK
            ],

        available =
            available,

        cached =
            cached,

        lastUpdated =
            lastUpdated,

        unavailableMessage =
            unavailableMessage,

        sections =
            sections,
    }
end

ns:RegisterModule(
    "Data.Bank",
    Bank
)

ns.Data = ns.Data or {}
ns.Data.Bank = Bank