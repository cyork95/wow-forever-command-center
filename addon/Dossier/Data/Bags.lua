local _, ns = ...

local U = ns.utils
local C = ns.constants

local Bags = {}

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end

    return pcall(fn, ...)
end

local function GetContainerNumSlots(bagID)
    if not C_Container
        or type(C_Container.GetContainerNumSlots) ~= "function"
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

    return U.SafeNumber(numSlots, 0)
end

local function GetContainerItemLink(bagID, slot)
    if not C_Container
        or type(C_Container.GetContainerItemLink) ~= "function"
    then
        return nil
    end

    local success, link =
        SafeCall(
            C_Container.GetContainerItemLink,
            bagID,
            slot
        )

    if not success then
        return nil
    end

    if type(link) ~= "string"
        or link == ""
    then
        return nil
    end

    return link
end

local function GetContainerItemID(bagID, slot)
    if not C_Container
        or type(C_Container.GetContainerItemID) ~= "function"
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

local function GetContainerItemStackCount(bagID, slot)
    if not C_Container
        or type(C_Container.GetContainerItemInfo) ~= "function"
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

local function GetBagName(bagID, fallback)
    if C_Container
        and type(C_Container.GetBagName) == "function"
    then
        local success, bagName =
            SafeCall(
                C_Container.GetBagName,
                bagID
            )

        if success
            and U.IsNonEmptyString(bagName)
        then
            return bagName
        end
    end

    return fallback
end

local function CreateBagItemLocation(bagID, slot)
    if not ItemLocation
        or type(ItemLocation.CreateFromBagAndSlot) ~= "function"
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

local function CollectBagItems(bagID, fallbackLabel)
    local label =
        GetBagName(
            bagID,
            fallbackLabel
        )

    local section =
        U.MakeSection(label)

    local numSlots =
        GetContainerNumSlots(bagID)

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

local function GetNormalBagCount()
    local count =
        U.ToSafeNumber(NUM_BAG_SLOTS)

    if count ~= nil
        and count >= 0
    then
        return count
    end

    return 4
end

local function GetReagentBagID()
    if not Enum
        or not Enum.BagIndex
    then
        return nil
    end

    return U.ToSafeNumber(
        Enum.BagIndex.ReagentBag
    )
end

function Bags:Collect()
    local sections = {}
    local collectedBagIDs = {}

    U.SafeInsert(
        sections,
        CollectBagItems(
            0,
            "Backpack"
        )
    )

    collectedBagIDs[0] = true

    local normalBagCount =
        GetNormalBagCount()

    for bagID = 1, normalBagCount do
        U.SafeInsert(
            sections,
            CollectBagItems(
                bagID,
                string.format(
                    "Bag %d",
                    bagID
                )
            )
        )

        collectedBagIDs[bagID] = true
    end

    local reagentBagID =
        GetReagentBagID()

    if reagentBagID ~= nil
        and reagentBagID >= 0
        and not collectedBagIDs[reagentBagID]
    then
        U.SafeInsert(
            sections,
            CollectBagItems(
                reagentBagID,
                "Reagent Bag"
            )
        )

        collectedBagIDs[reagentBagID] = true
    end

    return {
        key =
            C.SECTIONS.BAGS,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.BAGS
            ],

        sections =
            sections,
    }
end

ns:RegisterModule(
    "Data.Bags",
    Bags
)

ns.Data = ns.Data or {}
ns.Data.Bags = Bags