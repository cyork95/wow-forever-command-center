local _, ns = ...

local U = ns.utils
local C = ns.constants

local Equipment = {}

local BINDING_LABELS = {
    [1] = "Bind on Pickup",
    [2] = "Bind on Equip",
    [3] = "Bind on Use",
    [4] = "Quest Item",
}

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end

    return pcall(fn, ...)
end

local function PositiveNumber(value)
    local numberValue =
        U.ToSafeNumber(value)

    if numberValue ~= nil
        and numberValue > 0
    then
        return numberValue
    end

    return nil
end

local function ExtractItemString(linkOrString)
    if type(linkOrString) ~= "string"
        or linkOrString == ""
    then
        return nil
    end

    local itemString =
        linkOrString:match(
            "|[Hh](item:[^|]+)|[hH]"
        )

    if not itemString then
        itemString =
            linkOrString:match(
                "(item:[^|%s]+)"
            )
    end

    if not itemString
        or itemString == "item:"
    then
        return nil
    end

    return itemString
end

local function ParseItemString(linkOrString)
    local itemString =
        ExtractItemString(linkOrString)

    if not itemString then
        return nil
    end

    local fields = {}

    for part in string.gmatch(
        itemString .. ":",
        "([^:]*):"
    ) do
        U.SafeInsert(
            fields,
            part
        )
    end

    if fields[1] ~= "item" then
        return nil
    end

    local parsed = {
        itemString = itemString,
        rawParts = fields,

        parsedItemID =
            PositiveNumber(
                tonumber(fields[2])
            ),

        enchantID =
            PositiveNumber(
                tonumber(fields[3])
            ),

        suffixID =
            PositiveNumber(
                tonumber(fields[8])
            ),

        uniqueID =
            PositiveNumber(
                tonumber(fields[9])
            ),

        linkLevel =
            PositiveNumber(
                tonumber(fields[10])
            ),

        specializationID =
            PositiveNumber(
                tonumber(fields[11])
            ),
    }

    local gemIDs = {}

    for fieldIndex = 4, 7 do
        local gemID =
            PositiveNumber(
                tonumber(
                    fields[fieldIndex]
                )
            )

        if gemID then
            U.SafeInsert(
                gemIDs,
                gemID
            )
        end
    end

    if #gemIDs > 0 then
        parsed.gemIDs = gemIDs
    end

    local bonusCount =
        U.ToSafeNumber(
            tonumber(fields[14])
        )

    if bonusCount
        and bonusCount > 0
        and bonusCount % 1 == 0
    then
        local bonusIDs = {}
        local valid = true

        for bonusIndex = 1, bonusCount do
            local bonusID =
                U.ToSafeNumber(
                    tonumber(
                        fields[
                            14 + bonusIndex
                        ]
                    )
                )

            if bonusID == nil then
                valid = false
                break
            end

            U.SafeInsert(
                bonusIDs,
                bonusID
            )
        end

        if valid
            and #bonusIDs == bonusCount
        then
            parsed.bonusIDs =
                bonusIDs
        end
    end

    return parsed
end

local function ResolveBinding(bindType)
    local safeBindType =
        U.ToSafeNumber(bindType)

    if safeBindType == nil
        or safeBindType == 0
    then
        return nil
    end

    return {
        type = safeBindType,

        label =
            BINDING_LABELS[
                safeBindType
            ]
            or string.format(
                "Bind Type: %s",
                tostring(safeBindType)
            ),
    }
end

local function AddGem(
    gems,
    seenIndexes,
    index,
    itemID,
    name,
    link
)
    local safeIndex =
        U.ToSafeNumber(index)

    if safeIndex == nil
        or safeIndex < 1
        or safeIndex > 4
    then
        return
    end

    local safeItemID =
        PositiveNumber(itemID)

    local safeName =
        U.IsNonEmptyString(name)
        and name
        or nil

    local safeLink =
        U.IsNonEmptyString(link)
        and link
        or nil

    if safeItemID == nil
        and safeName == nil
        and safeLink == nil
    then
        return
    end

    if seenIndexes[safeIndex] then
        for _, gem in ipairs(gems) do
            if type(gem) == "table"
                and gem.index == safeIndex
            then
                gem.itemID =
                    gem.itemID
                    or safeItemID

                gem.name =
                    gem.name
                    or safeName

                gem.link =
                    gem.link
                    or safeLink

                return
            end
        end
    end

    U.SafeInsert(
        gems,
        {
            index = safeIndex,
            itemID = safeItemID,
            name = safeName,
            link = safeLink,
        }
    )

    seenIndexes[safeIndex] = true
end

local function CollectGemFromAPIs(
    itemLink,
    index
)
    if type(itemLink) ~= "string"
        or itemLink == ""
    then
        return nil, nil, nil
    end

    local gemID = nil
    local gemName = nil
    local gemLink = nil

    if C_Item
        and type(C_Item.GetItemGem)
            == "function"
    then
        local success, name, link =
            SafeCall(
                C_Item.GetItemGem,
                itemLink,
                index
            )

        if success then
            if U.IsNonEmptyString(name) then
                gemName = name
            end

            if U.IsNonEmptyString(link) then
                gemLink = link

                gemID =
                    U.GetItemIDFromLink(
                        link
                    )
            end
        end
    end

    if gemID == nil
        and C_Item
        and type(C_Item.GetItemGemID)
            == "function"
    then
        local success, value =
            SafeCall(
                C_Item.GetItemGemID,
                itemLink,
                index
            )

        if success then
            gemID =
                PositiveNumber(value)
        end
    end

    return gemID,
        gemName,
        gemLink
end

local function CollectEnhancementGems(
    itemLink,
    parsed
)
    local gems = {}
    local seenIndexes = {}

    for index = 1, 4 do
        local gemID,
            gemName,
            gemLink =
            CollectGemFromAPIs(
                itemLink,
                index
            )

        AddGem(
            gems,
            seenIndexes,
            index,
            gemID,
            gemName,
            gemLink
        )
    end

    if type(parsed) == "table"
        and type(parsed.rawParts)
            == "table"
    then
        for index = 1, 4 do
            local gemID =
                PositiveNumber(
                    tonumber(
                        parsed.rawParts[
                            3 + index
                        ]
                    )
                )

            AddGem(
                gems,
                seenIndexes,
                index,
                gemID,
                nil,
                nil
            )
        end
    end

    table.sort(
        gems,
        function(a, b)
            return (a.index or 0)
                < (b.index or 0)
        end
    )

    return gems
end

local function CollectEnhancements(
    itemLink,
    bindType
)
    local parsed =
        ParseItemString(itemLink)

    local enhancements = {}

    if type(parsed) == "table" then
        enhancements.itemString =
            parsed.itemString

        enhancements.parsedItemID =
            parsed.parsedItemID

        enhancements.enchantID =
            parsed.enchantID

        enhancements.gemIDs =
            parsed.gemIDs

        enhancements.suffixID =
            parsed.suffixID

        enhancements.uniqueID =
            parsed.uniqueID

        enhancements.linkLevel =
            parsed.linkLevel

        enhancements.specializationID =
            parsed.specializationID

        enhancements.rawParts =
            parsed.rawParts

        if parsed.enchantID then
            enhancements.enchant = {
                id =
                    parsed.enchantID,
            }
        end

        if type(parsed.bonusIDs)
            == "table"
            and #parsed.bonusIDs > 0
        then
            enhancements.bonusIDs =
                parsed.bonusIDs
        end
    end

    local gems =
        CollectEnhancementGems(
            itemLink,
            parsed
        )

    if #gems > 0 then
        enhancements.gems = gems
    end

    local binding =
        ResolveBinding(bindType)

    if binding then
        enhancements.binding =
            binding
    end

    if next(enhancements) == nil then
        return nil
    end

    return enhancements
end

local function ParseNumberFromText(text)
    if type(text) ~= "string"
        or text == ""
    then
        return nil
    end

    local value =
        text:match(
            "([%d]+[%.%,]?[%d]*)"
        )

    if not value then
        return nil
    end

    value =
        value:gsub(",", ".")

    return tonumber(value)
end

local function ParseDamageRange(text)
    if type(text) ~= "string"
        or text == ""
    then
        return nil, nil
    end

    local minimum,
        maximum =
        text:match(
            "([%d]+)%s*[%-%–]%s*([%d]+)"
        )

    if minimum
        and maximum
    then
        return tonumber(minimum),
            tonumber(maximum)
    end

    return nil, nil
end

local function ParseWeaponDetailsFromTooltipData(
    slotId
)
    if not C_TooltipInfo
        or type(
            C_TooltipInfo.GetInventoryItem
        ) ~= "function"
    then
        return nil, nil, nil
    end

    local success, data =
        SafeCall(
            C_TooltipInfo.GetInventoryItem,
            "player",
            slotId
        )

    if not success
        or type(data) ~= "table"
        or type(data.lines) ~= "table"
    then
        return nil, nil, nil
    end

    local damageMin = nil
    local damageMax = nil
    local speed = nil

    for _, line in ipairs(data.lines) do
        if type(line) == "table" then
            local leftText =
                U.SafeString(
                    line.leftText,
                    ""
                )

            local rightText =
                U.SafeString(
                    line.rightText,
                    ""
                )

            if damageMin == nil
                or damageMax == nil
            then
                local minValue,
                    maxValue =
                    ParseDamageRange(
                        leftText
                    )

                if minValue
                    and maxValue
                then
                    damageMin =
                        minValue

                    damageMax =
                        maxValue
                end
            end

            if speed == nil
                and rightText ~= ""
            then
                local lowerText =
                    string.lower(
                        rightText
                    )

                if lowerText:find(
                    "speed",
                    1,
                    true
                )
                then
                    speed =
                        ParseNumberFromText(
                            rightText
                        )
                end
            end

            if damageMin
                and damageMax
                and speed
            then
                break
            end
        end
    end

    return damageMin,
        damageMax,
        speed
end

local function ResolveSlotID(slotInfo)
    if type(slotInfo) ~= "table" then
        return nil
    end

    if type(slotInfo.slotToken)
        == "string"
        and type(GetInventorySlotInfo)
            == "function"
    then
        local success, slotID =
            SafeCall(
                GetInventorySlotInfo,
                slotInfo.slotToken
            )

        if success then
            slotID =
                U.ToSafeNumber(
                    slotID
                )

            if slotID ~= nil then
                return slotID
            end
        end
    end

    return U.ToSafeNumber(
        slotInfo.slotId
    )
end

local function CollectItemStats(itemLink)
    if type(itemLink) ~= "string"
        or itemLink == ""
    then
        return {}
    end

    if not C_Item
        or type(C_Item.GetItemStats)
            ~= "function"
    then
        return {}
    end

    local success, rawStats =
        SafeCall(
            C_Item.GetItemStats,
            itemLink
        )

    if not success
        or type(rawStats) ~= "table"
    then
        return {}
    end

    local stats = {}

    for statKey,
        statValue
        in pairs(rawStats)
    do
        local value =
            U.ToSafeNumber(
                statValue
            )

        if value ~= nil then
            U.SafeInsert(
                stats,
                {
                    key =
                        tostring(
                            statKey
                        ),

                    value =
                        value,
                }
            )
        end
    end

    table.sort(
        stats,
        function(a, b)
            return (a.key or "")
                < (b.key or "")
        end
    )

    return stats
end

local function CreateEquipmentItemLocation(
    slotId
)
    slotId =
        U.ToSafeNumber(slotId)

    if slotId == nil then
        return nil
    end

    if ItemLocation
        and type(
            ItemLocation.CreateFromEquipmentSlot
        ) == "function"
    then
        local success, location =
            SafeCall(
                ItemLocation.CreateFromEquipmentSlot,
                ItemLocation,
                slotId
            )

        if success then
            return location
        end
    end

    return nil
end

local function CollectItemMeta(
    slotId,
    itemLink,
    fallbackItemID
)
    local itemID =
        U.GetItemIDFromLink(
            itemLink
        )
        or U.ToSafeNumber(
            fallbackItemID
        )

    local quality = nil
    local itemLevel = nil
    local itemType = nil
    local itemSubType = nil
    local equipLoc = nil
    local bindType = nil

    local itemInfo =
        itemLink
        or itemID

    if itemInfo
        and C_Item
        and type(C_Item.GetItemInfo)
            == "function"
    then
        local success,
            _,
            _,
            rawQuality,
            rawItemLevel,
            _,
            rawItemType,
            rawItemSubType,
            _,
            rawEquipLoc,
            _,
            _,
            _,
            rawBindType =
            SafeCall(
                C_Item.GetItemInfo,
                itemInfo
            )

        if success then
            quality =
                U.ToSafeNumber(
                    rawQuality
                )

            if U.IsValidItemLevel(
                rawItemLevel
            ) then
                itemLevel =
                    U.ToSafeNumber(
                        rawItemLevel
                    )
            end

            if U.IsNonEmptyString(
                rawItemType
            ) then
                itemType =
                    rawItemType
            end

            if U.IsNonEmptyString(
                rawItemSubType
            ) then
                itemSubType =
                    rawItemSubType
            end

            if U.IsNonEmptyString(
                rawEquipLoc
            ) then
                equipLoc =
                    rawEquipLoc
            end

            bindType =
                U.ToSafeNumber(
                    rawBindType
                )
        end
    end

    if itemInfo
        and C_Item
        and type(
            C_Item.GetItemInfoInstant
        ) == "function"
        and (
            itemType == nil
            or itemSubType == nil
            or equipLoc == nil
        )
    then
        local success,
            instantItemID,
            instantType,
            instantSubType,
            instantEquipLoc =
            SafeCall(
                C_Item.GetItemInfoInstant,
                itemInfo
            )

        if success then
            itemID =
                itemID
                or U.ToSafeNumber(
                    instantItemID
                )

            if itemType == nil
                and U.IsNonEmptyString(
                    instantType
                )
            then
                itemType =
                    instantType
            end

            if itemSubType == nil
                and U.IsNonEmptyString(
                    instantSubType
                )
            then
                itemSubType =
                    instantSubType
            end

            if equipLoc == nil
                and U.IsNonEmptyString(
                    instantEquipLoc
                )
            then
                equipLoc =
                    instantEquipLoc
            end
        end
    end

    if quality == nil
        and itemID ~= nil
    then
        quality =
            U.GetItemQuality(
                itemID
            )
    end

    local itemLocation =
        CreateEquipmentItemLocation(
            slotId
        )

    local resolvedItemLevel =
        U.ResolveItemLevel(
            itemLink or itemID,
            itemLocation
        )

    if resolvedItemLevel ~= nil then
        itemLevel =
            resolvedItemLevel
    end

    local durabilityCurrent = nil
    local durabilityMax = nil

    if type(GetInventoryItemDurability)
        == "function"
    then
        local success,
            current,
            maximum =
            SafeCall(
                GetInventoryItemDurability,
                slotId
            )

        if success then
            durabilityCurrent =
                U.ToSafeNumber(current)

            durabilityMax =
                U.ToSafeNumber(maximum)
        end
    end

    return {
        itemID =
            itemID,

        rarity =
            quality,

        itemLevel =
            itemLevel,

        itemType =
            itemType,

        itemSubType =
            itemSubType,

        equipLoc =
            equipLoc,

        durabilityCurrent =
            durabilityCurrent,

        durabilityMax =
            durabilityMax,

        bindType =
            bindType,
    }
end

local function GetEquippedItem(
    slotId,
    slotLabel
)
    local inventorySlot =
        U.ToSafeNumber(slotId)

    if inventorySlot == nil then
        return nil
    end

    local itemLink = nil

    if type(GetInventoryItemLink)
        == "function"
    then
        local success, link =
            SafeCall(
                GetInventoryItemLink,
                "player",
                inventorySlot
            )

        if success
            and U.IsNonEmptyString(
                link
            )
        then
            itemLink = link
        end
    end

    local inventoryItemID = nil

    if type(GetInventoryItemID)
        == "function"
    then
        local success, itemID =
            SafeCall(
                GetInventoryItemID,
                "player",
                inventorySlot
            )

        if success then
            inventoryItemID =
                U.ToSafeNumber(
                    itemID
                )
        end
    end

    if itemLink == nil
        and inventoryItemID == nil
    then
        return nil
    end

    local meta =
        CollectItemMeta(
            inventorySlot,
            itemLink,
            inventoryItemID
        )

    local damageMin,
        damageMax,
        weaponSpeed =
        ParseWeaponDetailsFromTooltipData(
            inventorySlot
        )

    return {
        slotId =
            inventorySlot,

        slotLabel =
            slotLabel,

        link =
            itemLink,

        name =
            U.GetItemDisplayName(
                itemLink,
                meta.itemID
            ),

        count =
            1,

        itemID =
            meta.itemID,

        stats =
            CollectItemStats(
                itemLink
            ),

        rarity =
            meta.rarity,

        itemLevel =
            meta.itemLevel,

        itemType =
            meta.itemType,

        itemSubType =
            meta.itemSubType,

        equipLoc =
            meta.equipLoc,

        weaponDamageMin =
            damageMin,

        weaponDamageMax =
            damageMax,

        weaponSpeed =
            weaponSpeed,

        durabilityCurrent =
            meta.durabilityCurrent,

        durabilityMax =
            meta.durabilityMax,

        enhancements =
            CollectEnhancements(
                itemLink,
                meta.bindType
            ),
    }
end

function Equipment:Collect()
    local slots = {}

    for _, slotInfo
        in ipairs(C.EQUIPMENT_SLOTS)
    do
        local slotId =
            ResolveSlotID(
                slotInfo
            )

        if slotId ~= nil then
            local item =
                GetEquippedItem(
                    slotId,
                    slotInfo.label
                )

            U.SafeInsert(
                slots,
                {
                    slot =
                        slotInfo.label,

                    slotId =
                        slotId,

                    item =
                        item,
                }
            )
        end
    end

    return {
        key =
            C.SECTIONS.EQUIPMENT,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.EQUIPMENT
            ],

        slots =
            slots,
    }
end

ns:RegisterModule(
    "Data.Equipment",
    Equipment
)

ns.Data = ns.Data or {}
ns.Data.Equipment = Equipment