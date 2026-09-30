local _, ns = ...

local C = ns.constants
local U = ns.utils

-- A track-only shopping list. It counts what you have against what you plan
-- to gather or buy, and never buys or moves anything itself.
local ShoppingList = {}

ShoppingList.refusedEvents = {}

local IMPORT_SOURCE = "Consumable-Connoisseur"
local LOGIN_NAMES = 5
local BAG_SLOTS = NUM_BAG_SLOTS or 4

local listeners = {}

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local function Read(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local ok, value = pcall(fn, ...)

    if not ok or IsSecret(value) then
        return nil
    end

    return value
end

local function Now()
    return Read(time) or 0
end

local function Print(text)
    if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, text)
    end
end

local function Notify()
    for _, callback in ipairs(listeners) do
        pcall(callback)
    end
end

function ShoppingList:OnChanged(callback)
    if type(callback) == "function" then
        table.insert(listeners, callback)
    end
end

function ShoppingList.FillDefaults(store)
    store.items = type(store.items) == "table" and store.items or {}
    store.recipes = type(store.recipes) == "table" and store.recipes or {}

    if store.remind == nil then
        store.remind = true
    end

    return store
end

local function GetStore()
    local db = ns.state and ns.state.db

    if type(db) ~= "table" then
        return nil
    end

    db.shopping = ShoppingList.FillDefaults(type(db.shopping) == "table" and db.shopping or {})

    return db.shopping
end

local function ItemInfoFunction()
    return C_Item and C_Item.GetItemInfo or GetItemInfo
end

-- Returns name, link, stack size, or nil when the game hasn't loaded the item yet.
local function ItemInfo(item)
    local getInfo = ItemInfoFunction()

    if type(getInfo) ~= "function" then
        return nil
    end

    local ok, name, link, _, _, _, _, _, stack = pcall(getInfo, item)

    if not ok or IsSecret(name) or not U.IsNonEmptyString(name) then
        return nil
    end

    return name, link, tonumber(stack)
end

function ShoppingList.ParseItemLink(text)
    if type(text) ~= "string" then
        return nil
    end

    local id = tonumber(string.match(text, "|Hitem:(%d+)"))

    return id, string.match(text, "|h%[(.-)%]|h")
end

function ShoppingList.ParseRecipeLink(text)
    if type(text) ~= "string" then
        return nil
    end

    local id = tonumber(string.match(text, "|Henchant:(%d+)"))

    return id, string.match(text, "|h%[(.-)%]|h")
end

local function ItemName(itemID)
    return (ItemInfo(itemID)) or ("Item " .. tostring(itemID))
end

local function BagItemByName(name)
    if not C_Container or type(C_Container.GetContainerNumSlots) ~= "function" then
        return nil
    end

    local wanted = string.lower(name)

    for bag = 0, BAG_SLOTS do
        local slots = Read(C_Container.GetContainerNumSlots, bag) or 0

        for slot = 1, slots do
            local info = Read(C_Container.GetContainerItemInfo, bag, slot)
            local id, itemName = ShoppingList.ParseItemLink(type(info) == "table" and info.hyperlink or nil)

            if id and itemName and string.lower(itemName) == wanted then
                return id, itemName
            end
        end
    end

    return nil
end

local function ItemCount(itemID, includeBank)
    local getCount = C_Item and C_Item.GetItemCount or GetItemCount

    if type(getCount) ~= "function" then
        return 0
    end

    local ok, count = pcall(getCount, itemID, includeBank == true, false, includeBank == true)

    if not ok or IsSecret(count) then
        return 0
    end

    return tonumber(count) or 0
end

-- Item counts from the bank copy Dossier saved the last time the bank was open.
local function SavedBankCounts()
    local counts = {}
    local bank = ns.Data and ns.Data.Bank
    local snapshot = bank and type(bank.GetCachedSnapshot) == "function" and bank:GetCachedSnapshot()

    for _, section in ipairs(type(snapshot) == "table" and snapshot.sections or {}) do
        for _, item in ipairs(type(section) == "table" and section.items or {}) do
            local id = tonumber(item.itemID)

            if id then
                counts[id] = (counts[id] or 0) + (tonumber(item.count) or 1)
            end
        end
    end

    return counts
end

local function BankOpen()
    return type(ns.IsBankOpen) == "function" and ns:IsBankOpen()
end

local function ProfessionSnapshots()
    local details = ns.Data and ns.Data.ProfessionDetails

    if not details or type(details.GetCachedSnapshots) ~= "function" then
        return {}
    end

    local ok, snapshots = pcall(details.GetCachedSnapshots, details)

    return ok and type(snapshots) == "table" and snapshots or {}
end

local function FindKnownRecipe(recipeID, name)
    local wanted = name and string.lower(name) or nil

    for _, snapshot in ipairs(ProfessionSnapshots()) do
        for _, recipe in ipairs(type(snapshot.recipes) == "table" and snapshot.recipes or {}) do
            local id = tonumber(recipe.recipeID)

            if (recipeID and id == recipeID)
                or (wanted and type(recipe.name) == "string" and string.lower(recipe.name) == wanted)
            then
                return id, recipe.name, snapshot.name
            end
        end
    end

    return nil
end

local function RecipeProfession(recipeID)
    if not C_TradeSkillUI or type(C_TradeSkillUI.GetTradeSkillLineForRecipe) ~= "function" then
        return nil
    end

    local ok, _, skillLineName = pcall(C_TradeSkillUI.GetTradeSkillLineForRecipe, recipeID)

    return ok and not IsSecret(skillLineName) and U.IsNonEmptyString(skillLineName) and skillLineName or nil
end

-- Fills in a recipe's reagents from the game. Returns false when the game
-- doesn't know them yet, which is usual until its profession window opens.
local function ReadReagents(recipe, recipeID)
    if not C_TradeSkillUI or type(C_TradeSkillUI.GetRecipeSchematic) ~= "function" then
        return false
    end

    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)

    if not ok or type(schematic) ~= "table" or type(schematic.reagentSlotSchematics) ~= "table" then
        return false
    end

    local reagents = {}

    for _, slot in ipairs(schematic.reagentSlotSchematics) do
        local first = type(slot) == "table" and type(slot.reagents) == "table" and slot.reagents[1] or nil
        local itemID = first and tonumber(first.itemID)
        local count = tonumber(slot.quantityRequired)

        if slot.required ~= false and itemID and count and count > 0 then
            table.insert(reagents, { itemID = itemID, name = ItemName(itemID), count = count })
        end
    end

    if #reagents == 0 then
        return false
    end

    recipe.reagents = reagents
    recipe.outputItemID = tonumber(schematic.outputItemID)
    recipe.pending = nil

    if not U.IsNonEmptyString(recipe.name) and U.IsNonEmptyString(schematic.name) then
        recipe.name = schematic.name
    end

    return true
end

-- Accepts an item link, an item ID, or a name. Returns ok, itemID or a reason.
function ShoppingList:AddItem(text, target)
    local store = GetStore()
    text = U.Trim(U.SafeString(text, ""))

    if not store or text == "" then
        return false, "empty"
    end

    local id, name = ShoppingList.ParseItemLink(text)

    if not id and tonumber(text) then
        id = tonumber(text)
    end

    if not id then
        local _, link = ItemInfo(text)
        id, name = ShoppingList.ParseItemLink(link)
    end

    if not id then
        id, name = BagItemByName(text)
    end

    if not id then
        return false, "missing"
    end

    if store.items[id] then
        return false, "duplicate", id
    end

    local infoName, _, stack = ItemInfo(id)

    store.items[id] = {
        name = infoName or name or ("Item " .. id),
        target = math.max(1, math.floor(tonumber(target) or stack or 1)),
        added = Now(),
    }

    Notify()

    return true, id
end

-- Accepts a recipe link or the name of a recipe you know. Adding a listed
-- recipe again crafts one more.
function ShoppingList:AddRecipe(text, count)
    local store = GetStore()
    text = U.Trim(U.SafeString(text, ""))

    if not store or text == "" then
        return false, "empty"
    end

    local recipeID, linkName = ShoppingList.ParseRecipeLink(text)
    local knownID, knownName, profession = FindKnownRecipe(recipeID, not recipeID and text or nil)

    recipeID = recipeID or knownID

    if not recipeID then
        return false, "missing"
    end

    count = math.max(1, math.floor(tonumber(count) or 1))

    local recipe = store.recipes[recipeID]

    if recipe then
        recipe.count = recipe.count + count
        Notify()
        return true, recipeID
    end

    recipe = {
        name = knownName or linkName,
        profession = profession or RecipeProfession(recipeID),
        count = count,
        reagents = {},
        added = Now(),
    }

    if not ReadReagents(recipe, recipeID) then
        recipe.pending = true
    end

    recipe.name = recipe.name or ("Recipe " .. recipeID)
    store.recipes[recipeID] = recipe

    Notify()

    return true, recipeID
end

-- Shift-clicked or dragged text: recipe links are recipes, everything else is an item.
function ShoppingList:Add(text)
    if ShoppingList.ParseRecipeLink(text) then
        return self:AddRecipe(text)
    end

    local ok, result, extra = self:AddItem(text)

    if not ok and result == "missing" and FindKnownRecipe(nil, U.Trim(U.SafeString(text, ""))) then
        return self:AddRecipe(text)
    end

    return ok, result, extra
end

function ShoppingList:ChangeTarget(itemID, delta)
    local store = GetStore()
    local id = tonumber(itemID)

    if not store or not id then
        return
    end

    local item = store.items[id]
    local target = math.max(0, (item and item.target or 0) + (tonumber(delta) or 0))

    if target == 0 then
        store.items[id] = nil
    else
        store.items[id] = item or { name = ItemName(id), added = Now() }
        store.items[id].target = target
    end

    Notify()
end

function ShoppingList:SetTarget(itemID, target)
    local store = GetStore()
    local id = tonumber(itemID)
    local item = store and id and store.items[id]

    self:ChangeTarget(id, (tonumber(target) or 0) - (item and item.target or 0))
end

function ShoppingList:Remove(itemID)
    local store = GetStore()
    local id = tonumber(itemID)

    if store and id and store.items[id] then
        store.items[id] = nil
        Notify()
    end
end

function ShoppingList:SetRecipeCount(recipeID, count)
    local store = GetStore()
    local id = tonumber(recipeID)
    local recipe = store and id and store.recipes[id]

    if not recipe then
        return
    end

    count = math.floor(tonumber(count) or 0)

    if count <= 0 then
        store.recipes[id] = nil
    else
        recipe.count = count
    end

    Notify()
end

function ShoppingList:ChangeRecipeCount(recipeID, delta)
    local store = GetStore()
    local recipe = store and store.recipes[tonumber(recipeID)]

    if recipe then
        self:SetRecipeCount(recipeID, recipe.count + (tonumber(delta) or 0))
    end
end

function ShoppingList:RemoveRecipe(recipeID)
    self:SetRecipeCount(recipeID, 0)
end

function ShoppingList:IsRemindOn()
    local store = GetStore()
    return store ~= nil and store.remind ~= false
end

function ShoppingList:SetRemind(on)
    local store = GetStore()

    if store then
        store.remind = on == true
        Notify()
    end
end

function ShoppingList:GetImportedFrom()
    local store = GetStore()
    return store and store.importedFrom or nil
end

function ShoppingList:IsEmpty()
    local store = GetStore()
    return not store or (next(store.items) == nil and next(store.recipes) == nil)
end

-- Sorted { recipeID, name, profession, count, pending, reagents }.
function ShoppingList:GetRecipes()
    local store = GetStore()
    local list = {}

    for id, recipe in pairs(store and store.recipes or {}) do
        table.insert(list, {
            recipeID = id,
            name = recipe.name,
            profession = recipe.profession,
            count = recipe.count,
            pending = recipe.pending == true,
            reagents = recipe.reagents or {},
        })
    end

    table.sort(list, function(a, b)
        if (a.name or "") ~= (b.name or "") then
            return (a.name or "") < (b.name or "")
        end

        return a.recipeID < b.recipeID
    end)

    return list
end

-- Sorted rows { itemID, name, have, bags, bank, need, short, own, sources },
-- short items first.
function ShoppingList:GetRows()
    local store = GetStore()
    local byID = {}
    local order = {}

    local function Need(id, name, count, source, forRecipe)
        local row = byID[id]

        if not row then
            row = { itemID = id, name = name, need = 0, sources = {}, forRecipes = {} }
            byID[id] = row
            table.insert(order, row)
        end

        row.name = row.name or name
        row.need = row.need + count
        table.insert(row.sources, source)

        if forRecipe then
            table.insert(row.forRecipes, forRecipe)
        end
    end

    for id, item in pairs(store and store.items or {}) do
        Need(id, item.name, item.target or 0, string.format(C.TEXT.SHOPPING_SET_BY_YOU, ShoppingList.FormatCount(item.target or 0)))
        byID[id].own = item.target
    end

    for _, recipe in ipairs(self:GetRecipes()) do
        if not recipe.pending then
            for _, reagent in ipairs(recipe.reagents) do
                local count = reagent.count * recipe.count
                local recipeText = string.format("%s x%s", recipe.name or "a recipe", ShoppingList.FormatCount(recipe.count))

                Need(reagent.itemID, reagent.name, count, string.format(
                    C.TEXT.SHOPPING_FOR_RECIPE,
                    ShoppingList.FormatCount(count),
                    recipe.name or "a recipe",
                    ShoppingList.FormatCount(recipe.count)
                ), recipeText)
            end
        end
    end

    local liveBank = BankOpen()
    local savedBank = not liveBank and SavedBankCounts() or nil

    for _, row in ipairs(order) do
        row.bags = ItemCount(row.itemID, false)
        row.bank = liveBank and math.max(0, ItemCount(row.itemID, true) - row.bags) or (savedBank[row.itemID] or 0)
        row.have = row.bags + row.bank
        row.short = math.max(0, row.need - row.have)
    end

    table.sort(order, function(a, b)
        if (a.short > 0) ~= (b.short > 0) then
            return a.short > 0
        end

        if (a.name or "") ~= (b.name or "") then
            return (a.name or "") < (b.name or "")
        end

        return a.itemID < b.itemID
    end)

    return order
end

function ShoppingList:GetShortRows()
    local short = {}

    for _, row in ipairs(self:GetRows()) do
        if row.short > 0 then
            table.insert(short, row)
        end
    end

    return short
end

-- Removes the items you added that you now have enough of.
function ShoppingList:ClearFinished()
    local store = GetStore()
    local removed = 0

    if not store then
        return removed
    end

    for _, row in ipairs(self:GetRows()) do
        if row.own and row.short == 0 and store.items[row.itemID] then
            store.items[row.itemID] = nil
            removed = removed + 1
        end
    end

    if removed > 0 then
        Notify()
    end

    return removed
end

function ShoppingList.FormatCount(value)
    local text = tostring(math.floor(tonumber(value) or 0))
    return (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

function ShoppingList.PendingText(recipe)
    if U.IsNonEmptyString(recipe.profession) then
        return string.format(C.TEXT.SHOPPING_PENDING, recipe.profession)
    end

    return C.TEXT.SHOPPING_PENDING_UNKNOWN
end

local function ResolvePending()
    local store = GetStore()
    local resolved = false

    for id, recipe in pairs(store and store.recipes or {}) do
        if recipe.pending and ReadReagents(recipe, id) then
            resolved = true
        end
    end

    if resolved then
        Notify()
    end
end

local function OnSpellcast(unit, _, spellID)
    if unit ~= "player" or IsSecret(spellID) then
        return
    end

    local store = GetStore()
    local id = tonumber(spellID)
    local recipe = store and id and store.recipes[id]

    if recipe then
        ShoppingList:SetRecipeCount(id, recipe.count - 1)
    end
end

local function NeedList(rows, limit)
    local parts = {}

    for index, row in ipairs(rows) do
        if limit and index > limit then
            table.insert(parts, string.format("and %d more", #rows - limit))
            break
        end

        table.insert(parts, string.format("%s (need %s)", row.name or ("Item " .. row.itemID), ShoppingList.FormatCount(row.short)))
    end

    return table.concat(parts, ", ")
end

function ShoppingList:RemindAtLogin()
    if not self:IsRemindOn() then
        return false
    end

    local short = self:GetShortRows()

    if #short == 0 then
        return false
    end

    Print(string.format(C.TEXT.SHOPPING_LOGIN, NeedList(short, LOGIN_NAMES)))

    return true
end

local function MerchantItemID(index)
    local id = Read(GetMerchantItemID, index)

    if tonumber(id) then
        return tonumber(id)
    end

    return (ShoppingList.ParseItemLink(Read(GetMerchantItemLink, index)))
end

-- Names the short items this vendor sells. It never buys them.
function ShoppingList:RemindAtVendor()
    if not self:IsRemindOn() then
        return false
    end

    local shortByID = {}

    for _, row in ipairs(self:GetShortRows()) do
        shortByID[row.itemID] = row
    end

    local sold = {}
    local seen = {}

    for index = 1, Read(GetMerchantNumItems) or 0 do
        local id = MerchantItemID(index)

        if id and shortByID[id] and not seen[id] then
            seen[id] = true
            table.insert(sold, shortByID[id])
        end
    end

    if #sold == 0 then
        return false
    end

    Print(string.format(C.TEXT.SHOPPING_VENDOR, #sold, #sold == 1 and "" or "s", NeedList(sold)))

    return true
end

local function PlayerKey()
    local name = Read(UnitName, "player")
    local realm = Read(GetRealmName)

    if not U.IsNonEmptyString(name) then
        return nil
    end

    return U.IsNonEmptyString(realm) and (name .. "-" .. realm) or name
end

local function ConnoisseurRestocker()
    if type(ConnoisseurRestockerDB) == "table" then
        local root = ConnoisseurRestockerDB

        if type(root.global) == "table" and type(root.global.restocker) == "table" then
            return root.global.restocker
        end

        return type(root.restocker) == "table" and root.restocker or root
    end

    if type(ConnoisseurDB) == "table" and type(ConnoisseurDB.global) == "table" then
        return type(ConnoisseurDB.global.restocker) == "table" and ConnoisseurDB.global.restocker or nil
    end

    return nil
end

-- "itemType, itemName, amount, stash, ..." or a table with the same fields.
local function ParseConnoisseurEntry(itemID, entry)
    local id = tonumber(itemID)

    if type(entry) == "string" then
        local fields = {}

        for field in string.gmatch(entry .. ",", "([^,]*),") do
            table.insert(fields, U.Trim(field))
        end

        return id, fields[2], tonumber(fields[3])
    elseif type(entry) == "table" then
        return id or tonumber(entry.itemID),
            entry.itemName or entry.name,
            tonumber(entry.amount or entry.count or entry.quantity)
    end

    return nil
end

-- Copies this character's Connoisseur restock list once, into an empty list.
function ShoppingList:ImportConnoisseur()
    local store = GetStore()

    if not store or store.importedFrom or not self:IsEmpty() then
        return false
    end

    local restocker = ConnoisseurRestocker()

    if type(restocker) ~= "table" then
        return false
    end

    local list = nil
    local byCharacter = restocker.listsByCharacter
    local key = PlayerKey()
    local choice = type(byCharacter) == "table" and key and byCharacter[key] or nil

    if type(choice) == "table" then
        list = choice
    elseif type(choice) == "string" and type(restocker.lists) == "table" then
        list = restocker.lists[choice]
    end

    if type(list) ~= "table" then
        return false
    end

    local entries = type(list.items) == "table" and list.items or list
    local imported = 0

    for itemID, entry in pairs(entries) do
        local id, name, amount = ParseConnoisseurEntry(itemID, entry)

        if id and amount and amount > 0 then
            store.items[id] = {
                name = U.IsNonEmptyString(name) and name or ItemName(id),
                target = math.floor(amount),
                added = Now(),
            }
            imported = imported + 1
        end
    end

    if imported == 0 then
        return false
    end

    store.importedFrom = IMPORT_SOURCE
    Notify()

    return true
end

function ShoppingList:Collect()
    return {
        key = C.SECTIONS.SHOPPING,
        title = C.SECTION_LABELS[C.SECTIONS.SHOPPING],
        rows = self:GetRows(),
        recipes = self:GetRecipes(),
        importedFrom = self:GetImportedFrom(),
    }
end

local eventFrame = CreateFrame("Frame")
local registeredEvents = {}

local function Register(event)
    local ok, result = pcall(eventFrame.RegisterEvent, eventFrame, event)
    ok = ok and result ~= false

    if ok then
        table.insert(registeredEvents, event)
    else
        table.insert(ShoppingList.refusedEvents, event)
    end

    return ok
end

function ShoppingList:SetFeatureActive(on, loading)
    ns.Features.SetEvents(eventFrame, registeredEvents, on)

    if not loading then
        Notify()
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if not ns:IsFeatureOn("shopping") then
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnSpellcast(...)
    elseif event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_SHOW" then
        ResolvePending()
    elseif event == "MERCHANT_SHOW" then
        ShoppingList:RemindAtVendor()
    elseif event == "BAG_UPDATE_DELAYED" then
        Notify()
    elseif event == "PLAYER_LOGIN" then
        if ns:IsFeatureOn("companions") then
            ShoppingList:ImportConnoisseur()
        end

        ShoppingList:RemindAtLogin()
    end
end)

Register("PLAYER_LOGIN")
Register("UNIT_SPELLCAST_SUCCEEDED")
Register("TRADE_SKILL_LIST_UPDATE")
Register("TRADE_SKILL_SHOW")
Register("MERCHANT_SHOW")
Register("BAG_UPDATE_DELAYED")

ns:RegisterModule("Data.ShoppingList", ShoppingList)

ns.Data = ns.Data or {}
ns.Data.ShoppingList = ShoppingList
