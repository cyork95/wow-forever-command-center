local _, ns = ...

ns.utils = ns.utils or {}
local U = ns.utils

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end

    return pcall(fn, ...)
end

function U.IsNonEmptyString(value)
    local text = U.ToSafeString(value)
    return text ~= nil and text ~= ""
end

function U.ToSafeString(value)
    local valueType = type(value)

    if valueType == "nil" then
        return nil
    end

    if valueType == "string" or valueType == "number" then
        local ok, result = pcall(table.concat, { value }, "")

        if ok and type(result) == "string" then
            return result
        end

        return nil
    end

    if valueType == "boolean" then
        return tostring(value)
    end

    return nil
end

function U.SafeString(value, fallback)
    local text = U.ToSafeString(value)

    if text and text ~= "" then
        return text
    end

    return fallback or ""
end

function U.ToSafeNumber(value)
    local ok, valueType = pcall(type, value)

    if ok and valueType == "number" then
        return value
    end

    return nil
end

function U.SafeNumber(value, fallback)
    local numberValue = U.ToSafeNumber(value)

    if numberValue ~= nil then
        return numberValue
    end

    return fallback or 0
end

function U.TableCount(tbl)
    if type(tbl) ~= "table" then
        return 0
    end

    local count = 0

    for _ in pairs(tbl) do
        count = count + 1
    end

    return count
end

function U.ArrayLength(tbl)
    if type(tbl) ~= "table" then
        return 0
    end

    return #tbl
end

function U.SafeInsert(tbl, value)
    if type(tbl) ~= "table" then
        return
    end

    table.insert(tbl, value)
end

function U.JoinLines(lines)
    if type(lines) ~= "table" then
        return ""
    end

    local safe = {}
    local maxIndex = 0

    for key in pairs(lines) do
        if type(key) == "number" and key > maxIndex and key % 1 == 0 then
            maxIndex = key
        end
    end

    for index = 1, maxIndex do
        local text = U.ToSafeString(lines[index])

        if text ~= nil then
            table.insert(safe, text)
        end
    end

    if maxIndex == 0 then
        for _, value in pairs(lines) do
            local text = U.ToSafeString(value)

            if text ~= nil then
                table.insert(safe, text)
            end
        end
    end

    local ok, output = pcall(table.concat, safe, "\n")

    if ok and type(output) == "string" then
        return output
    end

    return ""
end

function U.Trim(value)
    if type(value) ~= "string" then
        return ""
    end

    return value:match("^%s*(.-)%s*$") or ""
end

function U.IsTable(value)
    return type(value) == "table"
end

function U.ShallowCopy(source)
    local copy = {}

    if type(source) ~= "table" then
        return copy
    end

    for key, value in pairs(source) do
        copy[key] = value
    end

    return copy
end

local function NormalizeItemName(name)
    local safeName = U.Trim(U.SafeString(name, ""))

    if safeName ~= "" and safeName ~= "[]" then
        return safeName
    end

    return nil
end

local function NormalizeItemLevel(value)
    local itemLevel = U.ToSafeNumber(value)

    if itemLevel ~= nil and itemLevel > 0 then
        return itemLevel
    end

    return nil
end

function U.GetItemNameFromLink(link)
    if type(link) ~= "string" or link == "" then
        return nil
    end

    return NormalizeItemName(link:match("%[(.-)%]"))
end

function U.RequestItemDataLoad(itemInfo)
    if itemInfo == nil then
        return false
    end

    if not C_Item or type(C_Item.RequestLoadItemDataByID) ~= "function" then
        return false
    end

    local success = SafeCall(C_Item.RequestLoadItemDataByID, itemInfo)

    return success == true
end

function U.GetItemIDFromLink(link)
    if type(link) ~= "string" or link == "" then
        return nil
    end

    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        local success, itemID = SafeCall(C_Item.GetItemInfoInstant, link)

        if success then
            itemID = U.ToSafeNumber(itemID)

            if itemID ~= nil then
                return itemID
            end
        end
    end

    local itemIDFromLink = string.match(link, "item:(%d+)")

    if itemIDFromLink then
        return tonumber(itemIDFromLink)
    end

    return nil
end

local function GetItemInfo(itemInfo)
    if itemInfo == nil then
        return nil
    end

    if not C_Item or type(C_Item.GetItemInfo) ~= "function" then
        return nil
    end

    local success,
        itemName,
        itemLink,
        itemQuality,
        itemLevel,
        itemMinLevel,
        itemType,
        itemSubType,
        itemStackCount,
        itemEquipLoc,
        itemTexture,
        sellPrice,
        classID,
        subClassID,
        bindType,
        expansionID,
        setID,
        isCraftingReagent = SafeCall(C_Item.GetItemInfo, itemInfo)

    if not success then
        return nil
    end

    if not itemName then
        return nil
    end

    return {
        name = NormalizeItemName(itemName),
        link = itemLink,
        quality = U.ToSafeNumber(itemQuality),
        itemLevel = NormalizeItemLevel(itemLevel),
        minLevel = U.ToSafeNumber(itemMinLevel),
        itemType = itemType,
        itemSubType = itemSubType,
        stackCount = U.ToSafeNumber(itemStackCount),
        equipLoc = itemEquipLoc,
        texture = itemTexture,
        sellPrice = U.ToSafeNumber(sellPrice),
        classID = U.ToSafeNumber(classID),
        subClassID = U.ToSafeNumber(subClassID),
        bindType = U.ToSafeNumber(bindType),
        expansionID = U.ToSafeNumber(expansionID),
        setID = U.ToSafeNumber(setID),
        isCraftingReagent = isCraftingReagent == true,
    }
end

local function GetItemNameByID(itemID)
    local safeItemID = U.ToSafeNumber(itemID)

    if safeItemID == nil then
        return nil
    end

    if C_Item and type(C_Item.GetItemNameByID) == "function" then
        local success, itemName = SafeCall(C_Item.GetItemNameByID, safeItemID)

        if success then
            return NormalizeItemName(itemName)
        end
    end

    local info = GetItemInfo(safeItemID)

    if info then
        return info.name
    end

    return nil
end

function U.GetItemDisplayName(linkOrID, itemID)
    local link = type(linkOrID) == "string" and linkOrID or nil
    local resolvedItemID = U.ToSafeNumber(itemID)

    if resolvedItemID == nil then
        resolvedItemID = U.ToSafeNumber(linkOrID)
    end

    if resolvedItemID == nil and link ~= nil then
        resolvedItemID = U.GetItemIDFromLink(link)
    end

    local itemName = GetItemNameByID(resolvedItemID)

    if itemName then
        return itemName
    end

    local itemInfo = GetItemInfo(link or resolvedItemID)

    if itemInfo and itemInfo.name then
        return itemInfo.name
    end

    if resolvedItemID ~= nil then
        U.RequestItemDataLoad(resolvedItemID)

        itemName = GetItemNameByID(resolvedItemID)

        if itemName then
            return itemName
        end

        itemInfo = GetItemInfo(link or resolvedItemID)

        if itemInfo and itemInfo.name then
            return itemInfo.name
        end
    end

    itemName = U.GetItemNameFromLink(link)

    if itemName then
        return itemName
    end

    return "Unknown Item"
end

function U.IsValidItemLevel(value)
    local itemLevel = U.ToSafeNumber(value)

    return itemLevel ~= nil and itemLevel > 0
end

local VALID_EQUIP_LOCS = {
    INVTYPE_HEAD = true,
    INVTYPE_NECK = true,
    INVTYPE_SHOULDER = true,
    INVTYPE_BODY = true,
    INVTYPE_CHEST = true,
    INVTYPE_ROBE = true,
    INVTYPE_WAIST = true,
    INVTYPE_LEGS = true,
    INVTYPE_FEET = true,
    INVTYPE_WRIST = true,
    INVTYPE_HAND = true,
    INVTYPE_FINGER = true,
    INVTYPE_TRINKET = true,
    INVTYPE_CLOAK = true,
    INVTYPE_WEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_2HWEAPON = true,
    INVTYPE_SHIELD = true,
    INVTYPE_HOLDABLE = true,
    INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true,
    INVTYPE_TABARD = true,
}

local function IsValidEquipLoc(equipLoc)
    if not U.IsNonEmptyString(equipLoc) then
        return false
    end

    return VALID_EQUIP_LOCS[equipLoc] == true
end

function U.ResolveItemLevel(link, itemLocation)
    if itemLocation ~= nil
        and C_Item
        and type(C_Item.GetCurrentItemLevel) == "function"
    then
        local success, currentItemLevel =
            SafeCall(C_Item.GetCurrentItemLevel, itemLocation)

        if success then
            currentItemLevel = NormalizeItemLevel(currentItemLevel)

            if currentItemLevel ~= nil then
                return currentItemLevel
            end
        end
    end

    if type(link) ~= "string" or link == "" then
        return nil
    end

    if C_Item and type(C_Item.GetDetailedItemLevelInfo) == "function" then
        local success, actualItemLevel =
            SafeCall(C_Item.GetDetailedItemLevelInfo, link)

        if success then
            actualItemLevel = NormalizeItemLevel(actualItemLevel)

            if actualItemLevel ~= nil then
                return actualItemLevel
            end
        end
    end

    local info = GetItemInfo(link)

    if info and info.itemLevel then
        return info.itemLevel
    end

    return nil
end

function U.GetItemLevelFromLink(link)
    return U.ResolveItemLevel(link)
end

local itemLevelLoadRequests = setmetatable({}, { __mode = "k" })

local function CreateItemFromLink(link)
    if type(link) ~= "string" or link == "" then
        return nil
    end

    if not Item or type(Item.CreateFromItemLink) ~= "function" then
        return nil
    end

    local success, item = SafeCall(Item.CreateFromItemLink, link)

    if success then
        return item
    end

    return nil
end

function U.ResolveItemLevelWhenLoaded(item, onResolved)
    if type(item) ~= "table" then
        return false
    end

    if U.IsValidItemLevel(item.itemLevel) then
        return false
    end

    local itemLink = item.link

    if type(itemLink) ~= "string" or itemLink == "" then
        return false
    end

    if itemLevelLoadRequests[item] == true then
        return false
    end

    local loadableItem = CreateItemFromLink(itemLink)

    if not loadableItem then
        local itemID = item.itemID or U.GetItemIDFromLink(itemLink)

        if itemID then
            return U.RequestItemDataLoad(itemID)
        end

        return false
    end

    if type(loadableItem.ContinueOnItemLoad) ~= "function" then
        return false
    end

    itemLevelLoadRequests[item] = true

    local success = SafeCall(
        loadableItem.ContinueOnItemLoad,
        loadableItem,
        function()
            itemLevelLoadRequests[item] = nil

            local itemLevel = U.ResolveItemLevel(itemLink)

            if itemLevel ~= nil then
                item.itemLevel = itemLevel
            end

            if type(onResolved) == "function" then
                onResolved(item)
            end
        end
    )

    if not success then
        itemLevelLoadRequests[item] = nil
    end

    return success == true
end

local function ResolveMissingItemLevelsInTable(value, onResolved, visited)
    if type(value) ~= "table" then
        return
    end

    if visited[value] then
        return
    end

    visited[value] = true

    if type(value.link) == "string"
        and not U.IsValidItemLevel(value.itemLevel)
    then
        local itemLevel = U.ResolveItemLevel(value.link)

        if itemLevel ~= nil then
            value.itemLevel = itemLevel
        else
            U.ResolveItemLevelWhenLoaded(value, onResolved)
        end
    end

    for _, child in pairs(value) do
        ResolveMissingItemLevelsInTable(child, onResolved, visited)
    end
end

function U.ResolveMissingItemLevels(exportData, onResolved)
    ResolveMissingItemLevelsInTable(exportData, onResolved, {})
end

function U.GetItemQuality(linkOrID)
    if linkOrID == nil or linkOrID == "" then
        return nil
    end

    local itemID = U.ToSafeNumber(linkOrID)

    if itemID == nil and type(linkOrID) == "string" then
        itemID = U.GetItemIDFromLink(linkOrID)
    end

    if itemID ~= nil
        and C_Item
        and type(C_Item.GetItemQualityByID) == "function"
    then
        local success, quality =
            SafeCall(C_Item.GetItemQualityByID, itemID)

        if success then
            quality = U.ToSafeNumber(quality)

            if quality ~= nil then
                return quality
            end
        end
    end

    local info = GetItemInfo(linkOrID)

    if info then
        return info.quality
    end

    return nil
end

function U.GetItemStats(linkOrID)
    if linkOrID == nil or linkOrID == "" then
        return {}
    end

    if not C_Item or type(C_Item.GetItemStats) ~= "function" then
        return {}
    end

    local itemLink = linkOrID

    if type(itemLink) == "number" then
        itemLink = "item:" .. tostring(itemLink)
    end

    if type(itemLink) ~= "string" or itemLink == "" then
        return {}
    end

    local success, rawStats = SafeCall(C_Item.GetItemStats, itemLink)

    if not success or type(rawStats) ~= "table" then
        return {}
    end

    local stats = {}

    for statKey, statValue in pairs(rawStats) do
        local value = U.ToSafeNumber(statValue)

        if value ~= nil and value ~= 0 then
            U.SafeInsert(stats, {
                key = tostring(statKey),
                value = value,
            })
        end
    end

    table.sort(stats, function(a, b)
        return (a.key or "") < (b.key or "")
    end)

    return stats
end

function U.GetItemMetadata(linkOrID)
    if linkOrID == nil or linkOrID == "" then
        return {}
    end

    local info = GetItemInfo(linkOrID)

    local quality = info and info.quality or nil
    local itemLevel = info and info.itemLevel or nil
    local itemType = info and info.itemType or nil
    local itemSubType = info and info.itemSubType or nil
    local equipLoc = info and info.equipLoc or nil

    if (
        not U.IsNonEmptyString(itemType)
        or not U.IsNonEmptyString(itemSubType)
        or not U.IsNonEmptyString(equipLoc)
    )
        and C_Item
        and type(C_Item.GetItemInfoInstant) == "function"
    then
        local success,
            _,
            instantItemType,
            instantItemSubType,
            instantEquipLoc =
            SafeCall(C_Item.GetItemInfoInstant, linkOrID)

        if success then
            if not U.IsNonEmptyString(itemType) then
                itemType = instantItemType
            end

            if not U.IsNonEmptyString(itemSubType) then
                itemSubType = instantItemSubType
            end

            if not U.IsNonEmptyString(equipLoc) then
                equipLoc = instantEquipLoc
            end
        end
    end

    if not IsValidEquipLoc(equipLoc) then
        equipLoc = nil
    end

    return {
        quality = quality,
        itemLevel = itemLevel,
        itemType = itemType,
        itemSubType = itemSubType,
        equipLoc = equipLoc,
    }
end

function U.MakeItemEntry(link, count, itemID, itemLocation)
    if type(link) ~= "string" or link == "" then
        return nil
    end

    local resolvedItemID =
        U.ToSafeNumber(itemID)
        or U.GetItemIDFromLink(link)

    local metadata = U.GetItemMetadata(link)

    return {
        link = link,
        name = U.GetItemDisplayName(link, resolvedItemID),
        count = U.SafeNumber(count, 1),
        itemID = resolvedItemID,
        itemLevel =
            U.ResolveItemLevel(link, itemLocation)
            or metadata.itemLevel,
        quality =
            U.GetItemQuality(resolvedItemID or link)
            or metadata.quality,
        itemType = metadata.itemType,
        itemSubType = metadata.itemSubType,
        equipLoc = metadata.equipLoc,
        stats = U.GetItemStats(link),
    }
end

function U.MakeSection(name)
    return {
        name = name or "",
        items = {},
    }
end

function U.MakeGroup(name)
    return {
        name = name or "",
        entries = {},
    }
end

function U.HasEntries(tbl, key)
    if type(tbl) ~= "table" then
        return false
    end

    local target = tbl

    if key then
        target = tbl[key]
    end

    return type(target) == "table" and #target > 0
end

function U.IsSelected(selectionTable, key)
    return type(selectionTable) == "table"
        and selectionTable[key] == true
end