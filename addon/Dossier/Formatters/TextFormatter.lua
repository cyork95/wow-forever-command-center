local _, ns = ...

local U = ns.utils
local C = ns.constants

local TextFormatter = {}

local SHOW_DIAGNOSTICS = false

local STAT_LABEL_OVERRIDES = {
    ITEM_MOD_STRENGTH_SHORT = "STR",
    ITEM_MOD_AGILITY_SHORT = "AGI",
    ITEM_MOD_STAMINA_SHORT = "STA",
    ITEM_MOD_INTELLECT_SHORT = "INT",
    ITEM_MOD_SPIRIT_SHORT = "SPI",
    ITEM_MOD_CRIT_RATING_SHORT = "CRIT",
    ITEM_MOD_CRIT_RATING = "CRIT",
    ITEM_MOD_HASTE_RATING_SHORT = "HASTE",
    ITEM_MOD_HASTE_RATING = "HASTE",
    ITEM_MOD_MASTERY_RATING_SHORT = "MAST",
    ITEM_MOD_MASTERY_RATING = "MAST",
    ITEM_MOD_VERSATILITY = "VERS",
    ITEM_MOD_VERSATILITY_SHORT = "VERS",
    ITEM_MOD_VERSATILITY_RATING_SHORT = "VERS",
    ITEM_MOD_LEECH_RATING_SHORT = "LEECH",
    ITEM_MOD_AVOIDANCE_RATING_SHORT = "AVOID",
    ITEM_MOD_SPEED_RATING_SHORT = "SPEED",
    ITEM_MOD_ARMOR_SHORT = "ARMOR",
    ITEM_MOD_ATTACK_POWER_SHORT = "AP",
    ITEM_MOD_SPELL_POWER_SHORT = "SP",
    ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
    ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
    ITEM_MOD_SPELL_DAMAGE_DONE = "SP",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
    RESISTANCE0_NAME = "ARMOR",
}

local RARITY_FALLBACK = {
    [0] = "Poor",
    [1] = "Common",
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic",
    [5] = "Legendary",
    [6] = "Artifact",
    [7] = "Heirloom",
    [8] = "WoW Token",
}

local STAT_ORDER = {
    ITEM_MOD_STRENGTH_SHORT = 10,
    ITEM_MOD_AGILITY_SHORT = 20,
    ITEM_MOD_STAMINA_SHORT = 30,
    ITEM_MOD_INTELLECT_SHORT = 40,
    ITEM_MOD_SPIRIT_SHORT = 50,
    RESISTANCE0_NAME = 60,
    ITEM_MOD_ARMOR_SHORT = 60,
    ITEM_MOD_ATTACK_POWER_SHORT = 70,
    ITEM_MOD_SPELL_POWER_SHORT = 75,
    ITEM_MOD_SPELL_DAMAGE_DONE = 75,
    ITEM_MOD_CRIT_RATING_SHORT = 80,
    ITEM_MOD_CRIT_RATING = 80,
    ITEM_MOD_HASTE_RATING_SHORT = 90,
    ITEM_MOD_HASTE_RATING = 90,
    ITEM_MOD_MASTERY_RATING_SHORT = 100,
    ITEM_MOD_MASTERY_RATING = 100,
    ITEM_MOD_VERSATILITY = 110,
    ITEM_MOD_VERSATILITY_SHORT = 110,
    ITEM_MOD_VERSATILITY_RATING_SHORT = 110,
    ITEM_MOD_LEECH_RATING_SHORT = 120,
    ITEM_MOD_AVOIDANCE_RATING_SHORT = 130,
    ITEM_MOD_SPEED_RATING_SHORT = 140,
    ITEM_MOD_POWER_REGEN0_SHORT = 150,
    ITEM_MOD_MANA_REGENERATION_SHORT = 150,
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 160,
}

local function SafeNumberText(value, fallback)
    local safeValue = U.ToSafeNumber(value)

    if safeValue ~= nil then
        return U.SafeString(
            safeValue,
            fallback or "0"
        )
    end

    return fallback or "0"
end

local function ShortDecimalText(value, fallback)
    local safeValue = U.ToSafeNumber(value)

    if safeValue == nil then
        return fallback or "0"
    end

    local text =
        string.format(
            "%.2f",
            safeValue
        )

    text =
        text:gsub(
            "0+$",
            ""
        ):gsub(
            "%.$",
            ""
        )

    if text == "-0" then
        return "0"
    end

    return text
end

local function AddLine(lines, value)
    if type(lines) ~= "table" then
        return
    end

    local text =
        U.ToSafeString(
            value
        )

    if text ~= nil then
        table.insert(
            lines,
            text
        )
    end
end

local function AddBlankLine(lines)
    AddLine(
        lines,
        ""
    )
end

local function AddSectionHeader(lines, title)
    AddLine(
        lines,
        string.format(
            "%s:",
            U.SafeString(
                title,
                "Section"
            )
        )
    )
end

local function AddSubHeader(lines, title)
    AddLine(
        lines,
        string.format(
            "== %s ==",
            U.SafeString(
                title,
                "Section"
            )
        )
    )
end

local function InlineText(value, maxLength)
    local text =
        U.ToSafeString(
            value
        )

    if text == nil then
        return nil
    end

    text =
        text:gsub(
            "[\r\n]+",
            " | "
        )

    text =
        U.Trim(
            text
        )

    text =
        text:gsub(
            "%s+",
            " "
        )

    text =
        text:gsub(
            "%s*|%s*",
            " | "
        )

    local collapsedSeparators

    repeat
        text,
            collapsedSeparators =
            text:gsub(
                "%s*|%s*|%s*",
                " | "
            )
    until collapsedSeparators == 0

    text =
        text:gsub(
            "^|%s*",
            ""
        )

    text =
        text:gsub(
            "%s*|$",
            ""
        )

    text =
        U.Trim(
            text
        )

    if text == "" then
        return nil
    end

    local limit =
        U.ToSafeNumber(
            maxLength
        )

    if limit ~= nil
        and limit > 3
        and text:len() > limit
    then
        text =
            U.Trim(
                text:sub(
                    1,
                    limit - 3
                )
            )
            .. "..."
    end

    return text
end

local function CleanWoWText(value)
    local text =
        U.ToSafeString(
            value
        )

    if text == nil then
        return nil
    end

    text =
        U.Trim(
            text
        )

    if text == "" then
        return nil
    end

    text =
        text:gsub(
            "[\r\n]+",
            " | "
        )

    text =
        text:gsub(
            "|%s*[Tt].-|%s*[tT]",
            ""
        )

    text =
        text:gsub(
            "|%s*[Hh].-|%s*[hH].-|%s*[hH]",
            ""
        )

    text =
        text:gsub(
            "|%s*[nN]",
            " | "
        )

    text =
        text:gsub(
            "|%s*[cC]%s*%x%x%x%x%x%x%x%x",
            ""
        )

    text =
        text:gsub(
            "|%s*[cC]%s*%x%x%x%x%x%x",
            ""
        )

    text =
        text:gsub(
            "|%s*[rR]",
            " "
        )

    text =
        text:gsub(
            "|%s*[Hh].-|%s*[hH]",
            ""
        )

    text =
        text:gsub(
            "|%s*[hH]",
            ""
        )

    text =
        text:gsub(
            "|%s*[Tt].-|%s*[tT]",
            ""
        )

    text =
        text:gsub(
            "|%s*[tT]",
            ""
        )

    text =
        text:gsub(
            "item:%d+",
            ""
        )

    text =
        text:gsub(
            "spell:%d+",
            ""
        )

    text =
        text:gsub(
            "quest:%d+",
            ""
        )

    text =
        text:gsub(
            "achievement:%d+",
            ""
        )

    text =
        text:gsub(
            "currency:%d+",
            ""
        )

    text =
        text:gsub(
            "battlepet:%d+",
            ""
        )

    text =
        text:gsub(
            "mount:%d+",
            ""
        )

    text =
        text:gsub(
            "toy:%d+",
            ""
        )

    text =
        text:gsub(
            "%a+:%d+",
            ""
        )

    text =
        text:gsub(
            "item:",
            ""
        )

    text =
        text:gsub(
            "spell:",
            ""
        )

    text =
        text:gsub(
            "quest:",
            ""
        )

    text =
        text:gsub(
            "achievement:",
            ""
        )

    text =
        text:gsub(
            "currency:",
            ""
        )

    text =
        text:gsub(
            "battlepet:",
            ""
        )

    text =
        text:gsub(
            "mount:",
            ""
        )

    text =
        text:gsub(
            "toy:",
            ""
        )

    text =
        U.Trim(
            text
        )

    text =
        text:gsub(
            "%s+",
            " "
        )

    text =
        text:gsub(
            "%s*|%s*",
            " | "
        )

    local collapsedSeparators

    repeat
        text,
            collapsedSeparators =
            text:gsub(
                "%s*|%s*|%s*",
                " | "
            )
    until collapsedSeparators == 0

    text =
        text:gsub(
            "^%s*|+%s*",
            ""
        )

    text =
        text:gsub(
            "%s*|+%s*$",
            ""
        )

    text =
        U.Trim(
            text
        )

    if text == "" then
        return nil
    end

    return text
end

local function RemoveSourceCostSegments(text)
    text =
        U.ToSafeString(
            text
        )

    if text == nil then
        return nil
    end

    text =
        U.Trim(
            text
        )

    if text == "" then
        return nil
    end

    local segments = {}

    for segment
        in text:gmatch(
            "[^|]+"
        )
    do
        segment =
            U.Trim(
                segment
            )

        if segment ~= ""
            and not segment:lower():find(
                "^cost:"
            )
        then
            table.insert(
                segments,
                segment
            )
        end
    end

    if #segments == 0 then
        return nil
    end

    return table.concat(
        segments,
        " | "
    )
end

local function IsVerboseItemTypesEnabled()
    if type(ns) ~= "table" then
        return false
    end

    if type(
        ns.IsVerboseItemTypesEnabled
    ) == "function"
    then
        local success, enabled =
            pcall(
                ns.IsVerboseItemTypesEnabled,
                ns
            )

        if success then
            return enabled == true
        end
    end

    local state =
        ns.state

    if type(state) == "table" then
        if state.verboseItemTypes
            ~= nil
        then
            return
                state.verboseItemTypes
                == true
        end

        local db =
            state.db

        if type(db) == "table" then
            return
                db.verboseItemTypes
                == true
        end
    end

    return false
end

local function IsDetailedExport()
    if type(ns.IsDetailedExport) == "function" then
        local success, enabled = pcall(ns.IsDetailedExport, ns)

        if success then
            return enabled == true
        end
    end

    return false
end

local function IsInvalidItemName(name, link)
    if name == ""
        or name == "[]"
        or name == "[[]]"
    then
        return true
    end

    if type(link) == "string"
        and link ~= ""
        and name == link
    then
        return true
    end

    return
        type(name) == "string"
        and name:find(
            "|Hitem:",
            1,
            true
        ) ~= nil
end

local function FormatItemDisplayName(item)
    if not item then
        return "[Unknown Item]"
    end

    local name =
        U.Trim(
            U.SafeString(
                item.name,
                ""
            )
        )

    if IsInvalidItemName(
        name,
        item.link
    )
    then
        name =
            U.GetItemDisplayName(
                item.link,
                item.itemID
            )
    end

    if IsInvalidItemName(
        name,
        item.link
    )
    then
        name =
            "Unknown Item"
    end

    if name:match(
        "^%[.+%]$"
    )
    then
        return name
    end

    return string.format(
        "[%s]",
        name
    )
end

local function FormatItemLine(item)
    if not item then
        return nil
    end

    local displayName =
        FormatItemDisplayName(
            item
        )

    local count =
        U.ToSafeNumber(
            item.count
        )

    local metadata = {}

    if U.ToSafeNumber(
        item.itemID
    ) ~= nil
    then
        U.SafeInsert(
            metadata,
            "ID: "
                .. SafeNumberText(
                    item.itemID
                )
        )
    end

    if U.IsValidItemLevel(
        item.itemLevel
    )
    then
        U.SafeInsert(
            metadata,
            "iLvl: "
                .. SafeNumberText(
                    item.itemLevel
                )
        )
    else
        U.SafeInsert(
            metadata,
            "iLvl: n/a"
        )
    end

    local quality =
        U.ToSafeNumber(
            item.quality
        )
        or U.ToSafeNumber(
            item.rarity
        )

    if quality ~= nil then
        U.SafeInsert(
            metadata,
            "Q: "
                .. SafeNumberText(
                    quality
                )
        )
    end

    local line =
        displayName

    if count ~= nil then
        line =
            string.format(
                "%s x%s",
                line,
                SafeNumberText(
                    count,
                    "1"
                )
            )
    end

    if #metadata > 0 then
        return string.format(
            "%s [%s]",
            line,
            table.concat(
                metadata,
                ", "
            )
        )
    end

    return line
end

local function ResolveStatLabel(statKey)
    if type(statKey) ~= "string"
        or statKey == ""
    then
        return "Unknown Stat"
    end

    if STAT_LABEL_OVERRIDES[
        statKey
    ]
    then
        return
            STAT_LABEL_OVERRIDES[
                statKey
            ]
    end

    local globalValue =
        _G[statKey]

    if type(globalValue)
        == "string"
        and globalValue ~= ""
    then
        return globalValue
    end

    return statKey
end

local function FormatItemStatLine(stat)
    if not stat then
        return nil
    end

    local key =
        stat.key
        or "UNKNOWN_STAT"

    local label =
        ResolveStatLabel(
            key
        )

    local value =
        U.ToSafeNumber(
            stat.value
        )

    if value == nil then
        return nil
    end

    return string.format(
        "- %s: %s",
        label,
        ShortDecimalText(
            value
        )
    )
end

local function SortStats(stats)
    table.sort(
        stats,
        function(a, b)
            local aKey =
                a
                and a.key
                or ""

            local bKey =
                b
                and b.key
                or ""

            local aOrder =
                STAT_ORDER[aKey]
                or 999

            local bOrder =
                STAT_ORDER[bKey]
                or 999

            if aOrder == bOrder then
                return aKey < bKey
            end

            return
                aOrder < bOrder
        end
    )
end

local function FormatCompactItemStatLine(item)
    if not item
        or type(item.stats)
            ~= "table"
        or #item.stats == 0
    then
        return nil
    end

    local itemStats =
        U.ShallowCopy(
            item.stats
        )

    SortStats(
        itemStats
    )

    local parts = {}

    for _, stat
        in ipairs(itemStats)
    do
        if stat then
            local value =
                U.ToSafeNumber(
                    stat.value
                )

            if value ~= nil then
                local label =
                    ResolveStatLabel(
                        stat.key
                        or "UNKNOWN_STAT"
                    )

                U.SafeInsert(
                    parts,
                    string.format(
                        "%s: %s",
                        label,
                        ShortDecimalText(
                            value
                        )
                    )
                )
            end
        end
    end

    if #parts == 0 then
        return nil
    end

    return
        "- "
        .. table.concat(
            parts,
            ", "
        )
end

local function FormatRarity(item)
    local rarity =
        U.ToSafeNumber(
            item
            and item.rarity
        )

    if rarity == nil then
        return nil
    end

    if type(
        _G.ITEM_QUALITY_COLORS
    ) == "table"
        and _G.ITEM_QUALITY_COLORS[
            rarity
        ]
    then
        local colorEntry =
            _G.ITEM_QUALITY_COLORS[
                rarity
            ]

        if type(colorEntry.name)
            == "string"
            and colorEntry.name ~= ""
        then
            return colorEntry.name
        end
    end

    if RARITY_FALLBACK[
        rarity
    ]
    then
        return
            RARITY_FALLBACK[
                rarity
            ]
    end

    return
        "Quality "
        .. SafeNumberText(
            rarity
        )
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

local TYPE_LINE_EQUIP_SLOT_LABELS = {
    INVTYPE_NECK = "Neck",
    INVTYPE_FINGER = "Finger",
    INVTYPE_TRINKET = "Trinket",
    INVTYPE_CLOAK = "Back",
    INVTYPE_TABARD = "Tabard",
}

local EQUIP_SLOT_LABELS = {
    INVTYPE_HEAD = "Head",
    INVTYPE_NECK = "Neck",
    INVTYPE_SHOULDER = "Shoulder",
    INVTYPE_BODY = "Shirt",
    INVTYPE_CHEST = "Chest",
    INVTYPE_ROBE = "Chest",
    INVTYPE_WAIST = "Waist",
    INVTYPE_LEGS = "Legs",
    INVTYPE_FEET = "Feet",
    INVTYPE_WRIST = "Wrist",
    INVTYPE_HAND = "Hands",
    INVTYPE_FINGER = "Finger",
    INVTYPE_TRINKET = "Trinket",
    INVTYPE_CLOAK = "Back",
    INVTYPE_WEAPON = "One-Hand Weapon",
    INVTYPE_WEAPONMAINHAND = "Main Hand",
    INVTYPE_WEAPONOFFHAND = "Off Hand",
    INVTYPE_2HWEAPON = "Two-Hand Weapon",
    INVTYPE_SHIELD = "Off Hand",
    INVTYPE_HOLDABLE = "Off Hand",
    INVTYPE_RANGED = "Ranged",
    INVTYPE_RANGEDRIGHT = "Ranged",
    INVTYPE_TABARD = "Tabard",
    INVTYPE_PROFESSION_TOOL = "Profession Tool",
    INVTYPE_PROFESSION_GEAR = "Profession Equipment",
}

local function IsProfessionEquipment(item)
    if not item then
        return false
    end

    local equipLoc =
        item.equipLoc

    return
        equipLoc
            == "INVTYPE_PROFESSION_TOOL"
        or equipLoc
            == "INVTYPE_PROFESSION_GEAR"
end

local function ResolveTypeLine(
    item,
    preferEquipSlotType
)
    if preferEquipSlotType
        and item
        and TYPE_LINE_EQUIP_SLOT_LABELS[
            item.equipLoc
        ]
    then
        return
            TYPE_LINE_EQUIP_SLOT_LABELS[
                item.equipLoc
            ]
    end

    local itemType =
        U.SafeString(
            item
            and item.itemType,
            "Unknown"
        )

    local itemSubType =
        U.SafeString(
            item
            and item.itemSubType,
            "Unknown"
        )

    return string.format(
        "%s / %s",
        itemType,
        itemSubType
    )
end

local function ResolveEquipSlotLine(item)
    if not item then
        return nil
    end

    if EQUIP_SLOT_LABELS[
        item.equipLoc
    ]
    then
        return
            EQUIP_SLOT_LABELS[
                item.equipLoc
            ]
    end

    local globalLabel =
        _G[item.equipLoc]

    if type(globalLabel)
        == "string"
        and globalLabel ~= ""
    then
        return globalLabel
    end

    return nil
end

local function AddItemGearDetails(
    lines,
    item,
    preferEquipSlotType
)
    local equipLoc =
        item
        and item.equipLoc

    local isEquippable =
        VALID_EQUIP_LOCS[
            equipLoc
        ] == true

    local isProfessionEquipment =
        IsProfessionEquipment(
            item
        )

    if isEquippable
        or isProfessionEquipment
    then
        local typeText =
            ResolveTypeLine(
                item,
                preferEquipSlotType
            )

        AddLine(
            lines,
            string.format(
                "- Type: %s",
                typeText
            )
        )

        local equipSlotText =
            ResolveEquipSlotLine(
                item
            )

        if equipSlotText then
            AddLine(
                lines,
                string.format(
                    "- Equip Slot: %s",
                    equipSlotText
                )
            )
        end
    end
end

local function IsNumberArray(value)
    if type(value) ~= "table"
        or #value == 0
    then
        return false
    end

    for _, entry
        in ipairs(value)
    do
        if U.ToSafeNumber(
            entry
        ) == nil
        then
            return false
        end
    end

    return true
end

local function AddEquipmentEnhancementDetails(
    lines,
    item
)
    local enhancements =
        item
        and item.enhancements

    if type(enhancements)
        ~= "table"
    then
        return
    end

    if U.IsNonEmptyString(
        enhancements.itemString
    )
    then
        AddLine(
            lines,
            "- Item String: "
                .. enhancements.itemString
        )
    end

    local enchant =
        enhancements.enchant

    local enchantID =
        type(enchant) == "table"
        and U.ToSafeNumber(
            enchant.id
        )
        or nil

    if enchantID ~= nil then
        AddLine(
            lines,
            "- Enchant ID: "
                .. SafeNumberText(
                    enchantID
                )
        )
    end

    if type(enhancements.gems)
        == "table"
        and #enhancements.gems > 0
    then
        AddLine(
            lines,
            "- Gems:"
        )

        for _, gem
            in ipairs(
                enhancements.gems
            )
        do
            if type(gem)
                == "table"
            then
                local socketIndex =
                    U.ToSafeNumber(
                        gem.index
                    )

                local gemID =
                    U.ToSafeNumber(
                        gem.itemID
                    )

                local gemName =
                    U.IsNonEmptyString(
                        gem.name
                    )
                    and gem.name
                    or nil

                local gemParts =
                    {}

                if gemName ~= nil then
                    U.SafeInsert(
                        gemParts,
                        gemName
                    )
                end

                if gemID ~= nil then
                    U.SafeInsert(
                        gemParts,
                        "[ID: "
                            .. SafeNumberText(
                                gemID
                            )
                            .. "]"
                    )
                end

                if socketIndex ~= nil
                    and #gemParts > 0
                then
                    AddLine(
                        lines,
                        string.format(
                            "  - Socket %s: %s",
                            SafeNumberText(
                                socketIndex
                            ),
                            table.concat(
                                gemParts,
                                " "
                            )
                        )
                    )
                end
            end
        end
    end

    if IsNumberArray(
        enhancements.bonusIDs
    )
    then
        local bonusIDs = {}

        for _, bonusID
            in ipairs(
                enhancements.bonusIDs
            )
        do
            U.SafeInsert(
                bonusIDs,
                SafeNumberText(
                    bonusID
                )
            )
        end

        AddLine(
            lines,
            "- Bonus IDs: "
                .. table.concat(
                    bonusIDs,
                    ", "
                )
        )
    end

    local binding =
        enhancements.binding

    if type(binding)
        == "table"
        and U.IsNonEmptyString(
            binding.label
        )
    then
        AddLine(
            lines,
            "- Binding: "
                .. binding.label
        )
    end
end

local function AddEquipmentDetails(lines, item)
    local rarityText =
        FormatRarity(
            item
        )

    if rarityText then
        AddLine(
            lines,
            string.format(
                "- Rarity: %s",
                rarityText
            )
        )
    end

    if U.IsValidItemLevel(
        item.itemLevel
    )
    then
        AddLine(
            lines,
            "- Item Level: "
                .. SafeNumberText(
                    item.itemLevel
                )
        )
    end

    if U.ToSafeNumber(
        item.durabilityMax
    ) ~= nil
    then
        AddLine(
            lines,
            "- Durability: "
                .. SafeNumberText(
                    item.durabilityCurrent
                )
                .. "/"
                .. SafeNumberText(
                    item.durabilityMax
                )
        )
    end

    local damageMin =
        U.ToSafeNumber(
            item.weaponDamageMin
        )

    local damageMax =
        U.ToSafeNumber(
            item.weaponDamageMax
        )

    if damageMin ~= nil
        and damageMax ~= nil
    then
        AddLine(
            lines,
            "- Damage: "
                .. SafeNumberText(
                    damageMin
                )
                .. " - "
                .. SafeNumberText(
                    damageMax
                )
        )
    end

    if U.ToSafeNumber(
        item.weaponSpeed
    ) ~= nil
    then
        AddLine(
            lines,
            "- Speed: "
                .. ShortDecimalText(
                    item.weaponSpeed
                )
        )
    end

    AddItemGearDetails(
        lines,
        item,
        true
    )

    AddEquipmentEnhancementDetails(
        lines,
        item
    )

    local itemStats =
        U.ShallowCopy(
            item.stats
            or {}
        )

    SortStats(
        itemStats
    )

    for _, stat
        in ipairs(
            itemStats
        )
    do
        AddLine(
            lines,
            FormatItemStatLine(
                stat
            )
        )
    end
end

local function FormatQuestLine(quest)
    if not quest then
        return nil
    end

    local title =
        quest.title
        or "Unknown Quest"

    local level =
        U.ToSafeNumber(
            quest.level
        )

    local status =
        quest.status

    local suggestedGroup =
        U.ToSafeNumber(
            quest.suggestedGroup
        )

    local questID =
        U.ToSafeNumber(
            quest.questID
        )

    local text =
        title

    if level ~= nil then
        text =
            string.format(
                "%s (Level %s)",
                text,
                SafeNumberText(
                    level
                )
            )
    end

    if suggestedGroup ~= nil
        and suggestedGroup > 1
    then
        text =
            string.format(
                "%s [Group %s]",
                text,
                SafeNumberText(
                    suggestedGroup
                )
            )
    end

    if status
        == "ready_to_turn_in"
    then
        text =
            text
            .. " [Ready to turn in]"
    elseif status
        == "complete"
    then
        text =
            text
            .. " [Complete]"
    else
        text =
            text
            .. " [In Progress]"
    end

    if questID ~= nil then
        text =
            string.format(
                "%s (ID: %s)",
                text,
                SafeNumberText(
                    questID
                )
            )
    end

    return text
end

local function FormatQuestObjectiveLine(
    objective
)
    if not objective
        or not U.IsNonEmptyString(
            objective.text
        )
    then
        return nil
    end

    local statusTag =
        objective.finished
        and "[x]"
        or "[ ]"

    return string.format(
        "  - %s %s",
        statusTag,
        objective.text
    )
end

local function FormatCompletedQuestLine(
    quest
)
    if not quest
        or not U.IsNonEmptyString(
            quest.title
        )
    then
        return nil
    end

    local questID =
        U.ToSafeNumber(
            quest.questID
        )

    if questID ~= nil then
        return string.format(
            "%s (ID: %s)",
            quest.title,
            SafeNumberText(
                questID
            )
        )
    end

    return string.format(
        "%s (ID: n/a)",
        quest.title
    )
end

local function AddCompactIDBlock(
    lines,
    ids,
    maxIDsPerLine,
    maxLineLength
)
    if type(ids) ~= "table"
        or #ids == 0
    then
        return
    end

    local idLimit =
        U.ToSafeNumber(
            maxIDsPerLine
        )
        or 20

    local lengthLimit =
        U.ToSafeNumber(
            maxLineLength
        )
        or 180

    local currentLine = ""
    local currentCount = 0

    for _, rawID
        in ipairs(ids)
    do
        local idText =
            SafeNumberText(
                rawID,
                nil
            )

        local nextText =
            currentLine == ""
            and idText
            or (
                currentLine
                .. ", "
                .. idText
            )

        if currentLine ~= ""
            and (
                currentCount
                    >= idLimit
                or #nextText
                    > lengthLimit
            )
        then
            AddLine(
                lines,
                currentLine
            )

            currentLine =
                idText

            currentCount =
                1
        else
            currentLine =
                nextText

            currentCount =
                currentCount
                + 1
        end
    end

    if currentLine ~= "" then
        AddLine(
            lines,
            currentLine
        )
    end
end

local function FormatSkillLine(entry)
    if not entry then
        return nil
    end

    local name =
        entry.name
        or "Unknown Skill"

    local rank =
        U.ToSafeNumber(
            entry.rank
        )

    local maxRank =
        U.ToSafeNumber(
            entry.maxRank
        )

    local modifier =
        U.ToSafeNumber(
            entry.modifier
        )

    local text

    if rank ~= nil
        and maxRank ~= nil
    then
        text =
            string.format(
                "%s %s/%s",
                name,
                SafeNumberText(
                    rank
                ),
                SafeNumberText(
                    maxRank
                )
            )
    elseif rank ~= nil then
        text =
            string.format(
                "%s %s",
                name,
                SafeNumberText(
                    rank
                )
            )
    else
        text =
            name
    end

    if modifier ~= nil
        and modifier ~= 0
    then
        local modifierText =
            SafeNumberText(
                modifier
            )

        if modifier > 0 then
            modifierText =
                "+"
                .. modifierText
        end

        text =
            string.format(
                "%s (%s)",
                text,
                modifierText
            )
    end

    return text
end

local function FormatTalentLine(entry)
    if not entry then
        return nil
    end

    local name =
        entry.name
        or "Unknown Talent"

    local rank =
        U.ToSafeNumber(
            entry.rank
        )

    local maxRank =
        U.ToSafeNumber(
            entry.maxRank
        )

    if rank ~= nil
        and maxRank ~= nil
    then
        return string.format(
            "%s %s/%s",
            name,
            SafeNumberText(
                rank
            ),
            SafeNumberText(
                maxRank
            )
        )
    end

    if rank ~= nil then
        return string.format(
            "%s %s",
            name,
            SafeNumberText(
                rank
            )
        )
    end

    return name
end

local function FormatSpellLine(entry)
    if not entry then
        return nil
    end

    local name =
        entry.name
        or "Unknown Spell"

    local metadata = {}

    local isPassive =
        entry.isPassive
        == true

    if isPassive then
        U.SafeInsert(
            metadata,
            "Passive"
        )
    end

    if U.ToSafeNumber(
        entry.spellID
    ) ~= nil
    then
        U.SafeInsert(
            metadata,
            "ID: "
                .. SafeNumberText(
                    entry.spellID
                )
        )
    end

    if entry.isActiveSpecSection
        == false
    then
        U.SafeInsert(
            metadata,
            "Off-spec"
        )
    end

    if entry.isKnown == true then
        U.SafeInsert(
            metadata,
            "Known"
        )
    elseif entry.isKnown == false then
        U.SafeInsert(
            metadata,
            "Known: no"
        )
    end

    local canReportUsability =
        entry.isKnown == true
        and not isPassive
        and entry.isActiveSpecSection
            ~= false

    if canReportUsability then
        if entry.isUsable == true then
            U.SafeInsert(
                metadata,
                "Usable"
            )
        elseif entry.isUsable
            == false
        then
            U.SafeInsert(
                metadata,
                "Not usable"
            )
        end

        if entry.insufficientPower
            == true
        then
            U.SafeInsert(
                metadata,
                "Insufficient power"
            )
        end
    end

    if #metadata > 0 then
        return string.format(
            "%s (%s)",
            name,
            table.concat(
                metadata,
                ", "
            )
        )
    end

    return name
end

local function BooleanStatusText(value)
    if value == true then
        return "yes"
    end

    if value == false then
        return "no"
    end

    return "unknown"
end

local function FormatMoneyCopper(copper)
    local amount =
        U.ToSafeNumber(
            copper
        )
        or 0

    if amount <= 0 then
        return "0g"
    end

    local gold =
        math.floor(
            amount / 10000
        )

    local silver =
        math.floor(
            (
                amount % 10000
            )
            / 100
        )

    local copperRemainder =
        amount % 100

    local parts = {
        SafeNumberText(
            gold
        )
            .. "g",
    }

    if silver > 0
        or copperRemainder > 0
    then
        U.SafeInsert(
            parts,
            SafeNumberText(
                silver
            )
                .. "s"
        )
    end

    if copperRemainder > 0 then
        U.SafeInsert(
            parts,
            SafeNumberText(
                copperRemainder
            )
                .. "c"
        )
    end

    return table.concat(
        parts,
        " "
    )
end

local function FormatCurrencyLine(entry)
    if not entry then
        return nil
    end

    local name =
        U.SafeString(
            entry.name,
            "Unknown Currency"
        )

    local currencyID =
        U.ToSafeNumber(
            entry.currencyID
        )

    local text =
        name

    if currencyID ~= nil then
        text =
            string.format(
                "%s (ID: %s)",
                text,
                SafeNumberText(
                    currencyID
                )
            )
    end

    local parts = {}

    local quantity =
        U.ToSafeNumber(
            entry.quantity
        )

    local maxQuantity =
        U.ToSafeNumber(
            entry.maxQuantity
        )

    if quantity ~= nil then
        if maxQuantity ~= nil
            and maxQuantity > 0
        then
            U.SafeInsert(
                parts,
                string.format(
                    "Quantity: %s/%s",
                    SafeNumberText(
                        quantity
                    ),
                    SafeNumberText(
                        maxQuantity
                    )
                )
            )
        else
            U.SafeInsert(
                parts,
                "Quantity: "
                    .. SafeNumberText(
                        quantity
                    )
            )
        end
    end

    local maxWeeklyQuantity =
        U.ToSafeNumber(
            entry.maxWeeklyQuantity
        )

    if entry.canEarnPerWeek
        == true
        or (
            maxWeeklyQuantity
                ~= nil
            and maxWeeklyQuantity
                > 0
        )
    then
        local weeklyQuantity =
            U.ToSafeNumber(
                entry.quantityEarnedThisWeek
            )
            or 0

        if maxWeeklyQuantity ~= nil
            and maxWeeklyQuantity > 0
        then
            U.SafeInsert(
                parts,
                string.format(
                    "Weekly: %s/%s",
                    SafeNumberText(
                        weeklyQuantity
                    ),
                    SafeNumberText(
                        maxWeeklyQuantity
                    )
                )
            )
        else
            U.SafeInsert(
                parts,
                "Weekly: "
                    .. SafeNumberText(
                        weeklyQuantity
                    )
            )
        end
    end

    local totalEarned =
        U.ToSafeNumber(
            entry.totalEarned
        )

    if totalEarned ~= nil
        and totalEarned > 0
    then
        U.SafeInsert(
            parts,
            "Total Earned: "
                .. SafeNumberText(
                    totalEarned
                )
        )
    end

    if entry.isShowInBackpack
        == true
    then
        U.SafeInsert(
            parts,
            "Backpack"
        )
    end

    if entry.isTypeUnused
        == true
    then
        U.SafeInsert(
            parts,
            "Unused"
        )
    end

    if entry.isTradeable
        == true
    then
        U.SafeInsert(
            parts,
            "Tradeable"
        )
    end

    if #parts > 0 then
        return string.format(
            "%s - %s",
            text,
            table.concat(
                parts,
                " - "
            )
        )
    end

    return text
end

local function AddProgressField(
    parts,
    label,
    value
)
    if type(parts) ~= "table"
        or U.ToSafeNumber(
            value
        ) == nil
    then
        return
    end

    table.insert(
        parts,
        string.format(
            "%s: %s",
            label,
            ShortDecimalText(
                value
            )
        )
    )
end

local function FormatProgressBoolean(
    value
)
    if type(value) == "boolean" then
        return
            value
            and "yes"
            or "no"
    end

    return nil
end

local function FormatMythicPlusRunLine(run)
    if type(run) ~= "table" then
        return nil
    end

    local parts = {}

    local name =
        U.ToSafeString(
            run.challengeModeName
        )

    if name ~= nil
        and name ~= ""
    then
        table.insert(
            parts,
            name
        )
    elseif U.ToSafeNumber(
        run.mapChallengeModeID
    ) ~= nil
    then
        table.insert(
            parts,
            "Map ID: "
                .. SafeNumberText(
                    run.mapChallengeModeID
                )
        )
    end

    AddProgressField(
        parts,
        "Level",
        run.bestRunLevel
    )

    AddProgressField(
        parts,
        "Score",
        run.score
    )

    local completed =
        FormatProgressBoolean(
            run.finishedSuccess
        )

    if completed ~= nil then
        table.insert(
            parts,
            "Completed: "
                .. completed
        )
    end

    if #parts == 0 then
        return nil
    end

    return table.concat(
        parts,
        " - "
    )
end

local function HasPositiveProgressNumber(
    value
)
    local safeValue =
        U.ToSafeNumber(
            value
        )

    return
        safeValue ~= nil
        and safeValue > 0
end

local function HasMeaningfulPvPBracketData(
    bracket
)
    if type(bracket) ~= "table" then
        return false
    end

    return
        HasPositiveProgressNumber(
            bracket.rating
        )
        or HasPositiveProgressNumber(
            bracket.seasonBest
        )
        or HasPositiveProgressNumber(
            bracket.weeklyBest
        )
        or HasPositiveProgressNumber(
            bracket.seasonPlayed
        )
        or HasPositiveProgressNumber(
            bracket.seasonWon
        )
        or HasPositiveProgressNumber(
            bracket.weeklyPlayed
        )
        or HasPositiveProgressNumber(
            bracket.weeklyWon
        )
        or HasPositiveProgressNumber(
            bracket.roundsSeasonPlayed
        )
        or HasPositiveProgressNumber(
            bracket.roundsSeasonWon
        )
        or HasPositiveProgressNumber(
            bracket.roundsWeeklyPlayed
        )
        or HasPositiveProgressNumber(
            bracket.roundsWeeklyWon
        )
end

local function HasProgressPairActivity(
    first,
    second
)
    return
        HasPositiveProgressNumber(
            first
        )
        or HasPositiveProgressNumber(
            second
        )
end

local function FormatPvpBracketLine(bracket)
    if not HasMeaningfulPvPBracketData(
        bracket
    )
    then
        return nil
    end

    local label =
        U.SafeString(
            bracket.label,
            "Bracket"
        )

    local parts = {
        label,
    }

    AddProgressField(
        parts,
        "Rating",
        bracket.rating
    )

    AddProgressField(
        parts,
        "Season Best",
        bracket.seasonBest
    )

    AddProgressField(
        parts,
        "Weekly Best",
        bracket.weeklyBest
    )

    if HasProgressPairActivity(
        bracket.seasonPlayed,
        bracket.seasonWon
    )
    then
        table.insert(
            parts,
            string.format(
                "Season: %s/%s",
                SafeNumberText(
                    bracket.seasonWon
                ),
                SafeNumberText(
                    bracket.seasonPlayed
                )
            )
        )
    end

    if HasProgressPairActivity(
        bracket.weeklyPlayed,
        bracket.weeklyWon
    )
    then
        table.insert(
            parts,
            string.format(
                "Weekly: %s/%s",
                SafeNumberText(
                    bracket.weeklyWon
                ),
                SafeNumberText(
                    bracket.weeklyPlayed
                )
            )
        )
    end

    AddProgressField(
        parts,
        "Tier",
        bracket.tier
    )

    AddProgressField(
        parts,
        "Ranking",
        bracket.ranking
    )

    if HasProgressPairActivity(
        bracket.roundsSeasonPlayed,
        bracket.roundsSeasonWon
    )
    then
        table.insert(
            parts,
            string.format(
                "Season Rounds: %s/%s",
                SafeNumberText(
                    bracket.roundsSeasonWon
                ),
                SafeNumberText(
                    bracket.roundsSeasonPlayed
                )
            )
        )
    end

    if HasProgressPairActivity(
        bracket.roundsWeeklyPlayed,
        bracket.roundsWeeklyWon
    )
    then
        table.insert(
            parts,
            string.format(
                "Weekly Rounds: %s/%s",
                SafeNumberText(
                    bracket.roundsWeeklyWon
                ),
                SafeNumberText(
                    bracket.roundsWeeklyPlayed
                )
            )
        )
    end

    if #parts <= 1 then
        return nil
    end

    return table.concat(
        parts,
        " - "
    )
end

local function FormatAddonLine(entry)
    if not entry then
        return nil
    end

    local addonName =
        entry.name
        or entry.internalName
        or "Unknown Addon"

    local parts = {
        string.format(
            "%s - Enabled: %s",
            addonName,
            BooleanStatusText(
                entry.enabled
            )
        ),

        string.format(
            "Loadable: %s",
            BooleanStatusText(
                entry.loadable
            )
        ),

        string.format(
            "Loaded: %s",
            BooleanStatusText(
                entry.loaded
            )
        ),
    }

    if U.IsNonEmptyString(
        entry.reason
    )
    then
        U.SafeInsert(
            parts,
            string.format(
                "Reason: %s",
                entry.reason
            )
        )
    end

    if U.IsNonEmptyString(
        entry.version
    )
    then
        U.SafeInsert(
            parts,
            string.format(
                "Version: %s",
                entry.version
            )
        )
    end

    return table.concat(
        parts,
        " - "
    )
end

local function FormatMountFaction(faction)
    if faction == nil then
        return nil
    end

    if faction == 1
        or faction == "1"
    then
        return "Alliance"
    end

    if faction == 0
        or faction == "0"
    then
        return "Horde"
    end

    return InlineText(
        faction
    )
end

local function FormatMountSource(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local sourceText =
        CleanWoWText(
            entry.sourceText
        )
        or CleanWoWText(
            entry.source
        )

    sourceText =
        RemoveSourceCostSegments(
            sourceText
        )

    if sourceText == nil then
        return nil
    end

    if sourceText:len() > 250 then
        sourceText =
            U.Trim(
                sourceText:sub(
                    1,
                    247
                )
            )
            .. "..."
    end

    return sourceText
end

local function FormatMountLine(entry)
    if not entry then
        return nil
    end

    local name =
        U.SafeString(
            entry.name,
            "Unknown Mount"
        )

    local metadata = {}

    if U.ToSafeNumber(
        entry.mountID
    ) ~= nil
    then
        U.SafeInsert(
            metadata,
            "ID: "
                .. SafeNumberText(
                    entry.mountID
                )
        )
    end

    if U.ToSafeNumber(
        entry.spellID
    ) ~= nil
    then
        U.SafeInsert(
            metadata,
            "Spell ID: "
                .. SafeNumberText(
                    entry.spellID
                )
        )
    end

    local text =
        name

    if #metadata > 0 then
        text =
            string.format(
                "%s (%s)",
                text,
                table.concat(
                    metadata,
                    ", "
                )
            )
    end

    local parts = {}

    if entry.isFavorite
        == true
    then
        U.SafeInsert(
            parts,
            "Favorite"
        )
    end

    if entry.isActive
        == true
    then
        U.SafeInsert(
            parts,
            "Active"
        )
    end

    if entry.isUsable
        == true
    then
        U.SafeInsert(
            parts,
            "Usable"
        )
    end

    local factionText =
        FormatMountFaction(
            entry.faction
        )

    if factionText ~= nil then
        U.SafeInsert(
            parts,
            "Faction: "
                .. factionText
        )
    end

    local sourceText =
        FormatMountSource(
            entry
        )

    if sourceText ~= nil then
        U.SafeInsert(
            parts,
            "Source: "
                .. sourceText
        )
    end

    if #parts > 0 then
        return string.format(
            "%s - %s",
            text,
            table.concat(
                parts,
                " - "
            )
        )
    end

    return text
end

local function FormatPetRarity(rarity)
    local rarityNumber =
        U.ToSafeNumber(
            rarity
        )

    if rarityNumber == nil then
        return nil
    end

    if _G
        and _G.BATTLE_PET_BREED_QUALITY
        and type(
            _G.BATTLE_PET_BREED_QUALITY
        ) == "table"
    then
        local quality =
            _G.BATTLE_PET_BREED_QUALITY[
                rarityNumber
            ]

        if U.IsNonEmptyString(
            quality
        )
        then
            return quality
        end
    end

    return
        RARITY_FALLBACK[
            rarityNumber
        ]
end

local function FormatPetLine(entry)
    if not entry then
        return nil
    end

    local name =
        U.SafeString(
            entry.speciesName,
            "Unknown Pet"
        )

    if U.IsNonEmptyString(
        entry.customName
    )
    then
        name =
            string.format(
                '%s "%s"',
                name,
                entry.customName
            )
    end

    local metadata = {}

    if U.ToSafeNumber(
        entry.speciesID
    ) ~= nil
    then
        U.SafeInsert(
            metadata,
            "Species ID: "
                .. SafeNumberText(
                    entry.speciesID
                )
        )
    end

    if IsDetailedExport()
        and U.IsNonEmptyString(
            entry.petID
        )
    then
        U.SafeInsert(
            metadata,
            "Pet ID: "
                .. entry.petID
        )
    end

    local text =
        name

    if #metadata > 0 then
        text =
            string.format(
                "%s (%s)",
                text,
                table.concat(
                    metadata,
                    ", "
                )
            )
    end

    local parts = {}

    if U.ToSafeNumber(
        entry.level
    ) ~= nil
    then
        U.SafeInsert(
            parts,
            "Level: "
                .. SafeNumberText(
                    entry.level
                )
        )
    end

    local rarityText =
        FormatPetRarity(
            entry.rarity
        )

    if U.IsNonEmptyString(
        rarityText
    )
    then
        U.SafeInsert(
            parts,
            rarityText
        )
    end

    if entry.favorite
        == true
    then
        U.SafeInsert(
            parts,
            "Favorite"
        )
    end

    if entry.canBattle
        == true
    then
        U.SafeInsert(
            parts,
            "Battle"
        )
    end

    if entry.isWild
        == true
    then
        U.SafeInsert(
            parts,
            "Wild"
        )
    end

    if entry.isTradeable
        == true
    then
        U.SafeInsert(
            parts,
            "Tradeable"
        )
    end

    if entry.isUnique
        == true
    then
        U.SafeInsert(
            parts,
            "Unique"
        )
    end

    if entry.isRevoked
        == true
    then
        U.SafeInsert(
            parts,
            "Revoked"
        )
    end

    local statParts = {}

    if U.ToSafeNumber(
        entry.maxHealth
    ) ~= nil
    then
        U.SafeInsert(
            statParts,
            "HP "
                .. SafeNumberText(
                    entry.maxHealth
                )
        )
    elseif U.ToSafeNumber(
        entry.health
    ) ~= nil
    then
        U.SafeInsert(
            statParts,
            "HP "
                .. SafeNumberText(
                    entry.health
                )
        )
    end

    if U.ToSafeNumber(
        entry.power
    ) ~= nil
    then
        U.SafeInsert(
            statParts,
            "Power "
                .. SafeNumberText(
                    entry.power
                )
        )
    end

    if U.ToSafeNumber(
        entry.speed
    ) ~= nil
    then
        U.SafeInsert(
            statParts,
            "Speed "
                .. SafeNumberText(
                    entry.speed
                )
        )
    end

    if #statParts > 0 then
        U.SafeInsert(
            parts,
            "Stats: "
                .. table.concat(
                    statParts,
                    ", "
                )
        )
    end

    if #parts > 0 then
        return string.format(
            "%s - %s",
            text,
            table.concat(
                parts,
                " - "
            )
        )
    end

    return text
end

local function FormatToyLine(entry)
    if not entry then
        return nil
    end

    local name =
        U.SafeString(
            entry.toyName,
            "Unknown Toy"
        )

    local itemID =
        SafeNumberText(
            entry.itemID,
            "n/a"
        )

    local text =
        string.format(
            "%s (Item ID: %s)",
            name,
            itemID
        )

    local parts = {}

    if entry.isFavorite
        == true
    then
        U.SafeInsert(
            parts,
            "Favorite"
        )
    end

    if entry.hasFanfare
        == true
    then
        U.SafeInsert(
            parts,
            "New/Fanfare"
        )
    end

    if U.ToSafeNumber(
        entry.itemQuality
    ) ~= nil
    then
        U.SafeInsert(
            parts,
            "Quality: "
                .. SafeNumberText(
                    entry.itemQuality
                )
        )
    end

    if #parts > 0 then
        return string.format(
            "%s - %s",
            text,
            table.concat(
                parts,
                " - "
            )
        )
    end

    return text
end

local function FormatReputationLine(entry)
    if not entry then
        return nil
    end

    local name =
        entry.name
        or "Unknown Faction"

    local standing =
        entry.standing
        or (
            "Standing #"
            .. SafeNumberText(
                entry.standingID
            )
        )

    local value =
        U.ToSafeNumber(
            entry.value
        )

    local minValue =
        U.ToSafeNumber(
            entry.min
        )

    local maxValue =
        U.ToSafeNumber(
            entry.max
        )

    local progress =
        U.ToSafeNumber(
            entry.progress
        )

    local nextStanding =
        U.ToSafeNumber(
            entry.nextStanding
        )

    local text =
        string.format(
            "%s (%s)",
            name,
            standing
        )

    if entry.isMajorFaction
        == true
    then
        text =
            text
            .. " [Major Faction]"
    end

    if value ~= nil
        and minValue ~= nil
        and maxValue ~= nil
    then
        text =
            string.format(
                "%s - Value: %s (%s-%s)",
                text,
                SafeNumberText(
                    value
                ),
                SafeNumberText(
                    minValue
                ),
                SafeNumberText(
                    maxValue
                )
            )
    elseif value ~= nil then
        text =
            string.format(
                "%s - Value: %s",
                text,
                SafeNumberText(
                    value
                )
            )
    end

    if progress ~= nil
        and nextStanding ~= nil
    then
        text =
            string.format(
                "%s - Progress: %s/%s",
                text,
                SafeNumberText(
                    progress
                ),
                SafeNumberText(
                    nextStanding
                )
            )
    end

    if entry.isParagon == true
        and type(entry.paragon)
            == "table"
    then
        local paragonCurrent =
            U.ToSafeNumber(
                entry.paragon.currentValue
            )

        local paragonThreshold =
            U.ToSafeNumber(
                entry.paragon.threshold
            )

        if paragonCurrent ~= nil
            and paragonThreshold ~= nil
        then
            text =
                string.format(
                    "%s - Paragon: %s/%s",
                    text,
                    SafeNumberText(
                        paragonCurrent
                    ),
                    SafeNumberText(
                        paragonThreshold
                    )
                )
        else
            text =
                text
                .. " - Paragon"
        end

        if entry.paragon.hasRewardPending
            == true
        then
            text =
                text
                .. " [Reward Pending]"
        end
    end

    return text
end

local PROFESSION_DIFFICULTY_LABELS = {
    [0] = "OPTIMAL",
    [1] = "MEDIUM",
    [2] = "EASY",
    [3] = "TRIVIAL",
}

local function FormatProfessionRecipeLine(
    recipe
)
    if not recipe then
        return nil
    end

    local recipeName =
        recipe.name
        or "Unknown Recipe"

    local tags = {}

    local requiredSkill =
        U.ToSafeNumber(
            recipe.requiredSkill
        )

    if requiredSkill ~= nil then
        table.insert(
            tags,
            SafeNumberText(
                requiredSkill
            )
        )
    else
        local difficultyValue =
            tonumber(
                recipe.difficulty
            )

        local difficultyLabel =
            difficultyValue ~= nil
            and PROFESSION_DIFFICULTY_LABELS[
                difficultyValue
            ]
            or nil

        if not difficultyLabel
            and U.IsNonEmptyString(
                recipe.difficulty
            )
        then
            difficultyLabel =
                string.upper(
                    recipe.difficulty
                )
        end

        table.insert(
            tags,
            difficultyLabel
            or "?"
        )
    end

    if recipe.learned == true then
        table.insert(
            tags,
            "LEARNED"
        )
    elseif recipe.learned == false then
        table.insert(
            tags,
            "UNLEARNED"
        )
    end

    local prefixes = {}

    for _, tag
        in ipairs(tags)
    do
        table.insert(
            prefixes,
            "["
                .. tag
                .. "]"
        )
    end

    return
        table.concat(
            prefixes,
            " "
        )
        .. " "
        .. recipeName
end

local function AddPercentLine(
    lines,
    label,
    value
)
    AddLine(
        lines,
        string.format(
            "%s: %s%%",
            label,
            ShortDecimalText(
                value,
                "n/a"
            )
        )
    )
end

local function BuildResourceLine(
    label,
    resource
)
    local safeLabel =
        U.SafeString(
            label,
            ""
        )

    if safeLabel == ""
        or type(resource)
            ~= "table"
    then
        return nil
    end

    local current =
        U.ToSafeNumber(
            resource.current
        )

    local max =
        U.ToSafeNumber(
            resource.max
        )

    if current == nil
        and max == nil
    then
        return nil
    end

    local currentText =
        current ~= nil
        and SafeNumberText(
            current
        )
        or "n/a"

    local maxText =
        max ~= nil
        and SafeNumberText(
            max
        )
        or "n/a"

    return string.format(
        "%s: %s/%s",
        safeLabel,
        currentText,
        maxText
    )
end

local function FormatTimestamp(timestamp)
    local value =
        U.ToSafeNumber(
            timestamp
        )

    if value == nil then
        return nil
    end

    if type(date) ~= "function" then
        return nil
    end

    local success, formatted =
        pcall(
            date,
            "%Y-%m-%d %H:%M:%S",
            value
        )

    if not success
        or type(formatted)
            ~= "string"
        or formatted == ""
    then
        return nil
    end

    return formatted
end

local function FormatBagHeader(section)
    local title =
        section
        and section.name
        or "Bag"

    local numSlots =
        U.ToSafeNumber(
            section
            and section.numSlots
        )

    if numSlots == nil then
        return title
    end

    local usedSlots =
        U.ToSafeNumber(
            section
            and section.usedSlots
        )

    if usedSlots == nil then
        usedSlots =
            #(
                section.items
                or {}
            )
    end

    return string.format(
        "%s (%s/%s)",
        title,
        SafeNumberText(
            usedSlots
        ),
        SafeNumberText(
            numSlots
        )
    )
end

local function FormatBankHeader(section)
    local title =
        section
        and section.name
        or "Bank"

    local numSlots =
        U.ToSafeNumber(
            section
            and section.numSlots
        )

    if numSlots == nil then
        return title
    end

    local usedSlots =
        U.ToSafeNumber(
            section
            and section.usedSlots
        )

    if usedSlots == nil then
        usedSlots =
            #(
                section.items
                or {}
            )
    end

    return string.format(
        "%s (%s/%s)",
        title,
        SafeNumberText(
            usedSlots
        ),
        SafeNumberText(
            numSlots
        )
    )
end

function TextFormatter:AddBagsDetailed(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.BAGS
        ]
    )

    local verboseItemTypes =
        IsVerboseItemTypesEnabled()

    local sections =
        data.sections
        or {}

    for _, section
        in ipairs(sections)
    do
        AddSubHeader(
            lines,
            FormatBagHeader(
                section
            )
        )

        local items =
            section.items
            or {}

        if #items == 0 then
            AddLine(
                lines,
                "[Empty]"
            )
        else
            for _, item
                in ipairs(items)
            do
                AddLine(
                    lines,
                    FormatItemLine(
                        item
                    )
                )

                if verboseItemTypes then
                    AddItemGearDetails(
                        lines,
                        item
                    )

                    AddLine(
                        lines,
                        FormatCompactItemStatLine(
                            item
                        )
                    )
                end
            end
        end

        AddBlankLine(
            lines
        )
    end
end

function TextFormatter:AddBankDetailed(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.BANK
        ]
    )

    if not data.available then
        if not TextFormatter.AddBankFallback(lines, data.fallback) then
            AddLine(
                lines,
                data.unavailableMessage
                or C.TEXT.BANK_UNAVAILABLE_NO_CACHE
                or C.TEXT.BANK_UNAVAILABLE
            )
        end

        AddBlankLine(
            lines
        )

        return
    end

    if data.cached then
        local updatedAt =
            FormatTimestamp(
                data.lastUpdated
            )

        if updatedAt then
            AddLine(
                lines,
                string.format(
                    "%s - last updated: %s.]",
                    C.TEXT.BANK_CACHED_PREFIX
                    or "[Using cached bank data",
                    updatedAt
                )
            )
        else
            AddLine(
                lines,
                string.format(
                    "%s.]",
                    C.TEXT.BANK_CACHED_PREFIX
                    or "[Using cached bank data"
                )
            )
        end

        AddBlankLine(
            lines
        )
    end

    local verboseItemTypes =
        IsVerboseItemTypesEnabled()

    local sections =
        data.sections
        or {}

    for _, section
        in ipairs(sections)
    do
        AddSubHeader(
            lines,
            FormatBankHeader(
                section
            )
        )

        local items =
            section.items
            or {}

        if #items == 0 then
            AddLine(
                lines,
                "[Empty]"
            )
        else
            for _, item
                in ipairs(items)
            do
                AddLine(
                    lines,
                    FormatItemLine(
                        item
                    )
                )

                if verboseItemTypes then
                    AddItemGearDetails(
                        lines,
                        item
                    )

                    AddLine(
                        lines,
                        FormatCompactItemStatLine(
                            item
                        )
                    )
                end
            end
        end

        AddBlankLine(
            lines
        )
    end
end

function TextFormatter:AddEquipmentDetailed(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.EQUIPMENT
        ]
    )

    local slots =
        data.slots
        or {}

    for _, slotInfo
        in ipairs(slots)
    do
        AddSubHeader(
            lines,
            slotInfo.slot
            or "Slot"
        )

        if slotInfo.item then
            AddLine(
                lines,
                FormatItemLine(
                    slotInfo.item
                )
            )

            AddEquipmentDetails(
                lines,
                slotInfo.item
            )
        else
            AddLine(
                lines,
                "[Empty]"
            )
        end

        AddBlankLine(
            lines
        )
    end
end

function TextFormatter:AddLocationDetailed(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.LOCATION
        ]
    )

    AddLine(
        lines,
        string.format(
            "Zone: %s",
            U.SafeString(
                data.zone,
                "unknown"
            )
        )
    )

    AddLine(
        lines,
        string.format(
            "Subzone: %s",
            U.SafeString(
                data.subzone,
                "unknown"
            )
        )
    )

    AddLine(
        lines,
        string.format(
            "Map: %s",
            U.SafeString(
                data.map,
                "unknown"
            )
        )
    )

    if U.ToSafeNumber(
        data.mapID
    ) ~= nil
    then
        AddLine(
            lines,
            string.format(
                "Map ID: %s",
                SafeNumberText(
                    data.mapID
                )
            )
        )
    end

    if U.IsNonEmptyString(
        data.parentMap
    )
        and data.parentMap
            ~= "unknown"
    then
        AddLine(
            lines,
            string.format(
                "Parent Map: %s",
                data.parentMap
            )
        )

        if U.ToSafeNumber(
            data.parentMapID
        ) ~= nil
        then
            AddLine(
                lines,
                string.format(
                    "Parent Map ID: %s",
                    SafeNumberText(
                        data.parentMapID
                    )
                )
            )
        end
    end

    AddLine(
        lines,
        string.format(
            "Coordinates: %s",
            U.SafeString(
                data.coordinates,
                "unknown"
            )
        )
    )

    AddLine(
        lines,
        string.format(
            "Hearthstone Location: %s",
            U.SafeString(
                data.hearthstoneLocation,
                "unknown"
            )
        )
    )

    AddBlankLine(
        lines
    )
end

function TextFormatter:AddCharacterStats(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.CHARACTER_STATS
        ]
    )

    AddLine(
        lines,
        string.format(
            "Character: %s",
            U.SafeString(
                data.fullName,
                "Unknown"
            )
        )
    )

    AddLine(
        lines,
        string.format(
            "Faction: %s",
            U.SafeString(
                data.faction,
                "Neutral"
            )
        )
    )

    AddLine(
        lines,
        "Level: "
            .. SafeNumberText(
                data.level
            )
    )

    AddLine(
        lines,
        string.format(
            "Race: %s",
            U.SafeString(
                data.race,
                "Unknown"
            )
        )
    )

    AddLine(
        lines,
        string.format(
            "Class: %s",
            U.SafeString(
                data.class,
                "Unknown"
            )
        )
    )

    local specialization =
        data.specialization
        or {}

    if U.IsNonEmptyString(
        specialization.name
    )
    then
        local specLine =
            string.format(
                "Specialization: %s",
                specialization.name
            )

        if U.IsNonEmptyString(
            specialization.role
        )
        then
            specLine =
                string.format(
                    "%s (%s)",
                    specLine,
                    specialization.role
                )
        end

        AddLine(
            lines,
            specLine
        )
    end

    if U.IsNonEmptyString(
        specialization.primaryStatLabel
    )
    then
        AddLine(
            lines,
            string.format(
                "Primary Stat: %s",
                specialization.primaryStatLabel
            )
        )
    end

    local itemLevel =
        data.itemLevel
        or {}

    if U.ToSafeNumber(
        itemLevel.average
    ) ~= nil
    then
        AddLine(
            lines,
            string.format(
                "Average Item Level: %s",
                ShortDecimalText(
                    itemLevel.average
                )
            )
        )
    end

    if U.ToSafeNumber(
        itemLevel.equipped
    ) ~= nil
    then
        AddLine(
            lines,
            string.format(
                "Equipped Item Level: %s",
                ShortDecimalText(
                    itemLevel.equipped
                )
            )
        )
    end

    if U.ToSafeNumber(
        itemLevel.pvp
    ) ~= nil
    then
        AddLine(
            lines,
            string.format(
                "PvP Item Level: %s",
                ShortDecimalText(
                    itemLevel.pvp
                )
            )
        )
    end

    local resources =
        data.resources
        or {}

    local healthLine =
        BuildResourceLine(
            "Health",
            resources.health
        )

    if type(healthLine)
        == "string"
    then
        AddLine(
            lines,
            healthLine
        )
    end

    local primaryResource =
        resources.primary
        or {}

    local mana =
        resources.mana
        or {}

    local shouldPrintMana =
        mana.available == true
        and mana.current ~= nil
        and mana.max ~= nil

    local shouldPrintPrimaryResource =
        U.IsNonEmptyString(
            primaryResource.label
        )

    if primaryResource.token
        == "MANA"
        and not shouldPrintMana
    then
        shouldPrintPrimaryResource =
            false
    end

    if shouldPrintPrimaryResource then
        local resourceLine =
            BuildResourceLine(
                primaryResource.label,
                primaryResource
            )

        if type(resourceLine)
            == "string"
        then
            AddLine(
                lines,
                resourceLine
            )
        end
    end

    if shouldPrintMana
        and primaryResource.token
            ~= "MANA"
    then
        local manaLine =
            BuildResourceLine(
                "Mana",
                mana
            )

        if type(manaLine)
            == "string"
        then
            AddLine(
                lines,
                manaLine
            )
        end
    end

    local xp =
        data.xp
        or {}

    if xp.available then
        AddLine(
            lines,
            "XP: "
                .. SafeNumberText(
                    xp.current,
                    "n/a"
                )
                .. "/"
                .. SafeNumberText(
                    xp.max,
                    "n/a"
                )
        )

        AddLine(
            lines,
            "XP To Level: "
                .. SafeNumberText(
                    xp.toLevel,
                    "n/a"
                )
        )

        AddPercentLine(
            lines,
            "XP Progress",
            xp.progressPercent
        )

        if U.ToSafeNumber(
            xp.rested
        ) ~= nil
        then
            AddLine(
                lines,
                "Rested XP: "
                    .. SafeNumberText(
                        xp.rested
                    )
            )
        end
    end

    local armor =
        data.armor
        or {}

    if U.ToSafeNumber(
        armor.effective
    ) ~= nil
        or U.ToSafeNumber(
            armor.base
        ) ~= nil
    then
        AddLine(
            lines,
            "Armor: "
                .. SafeNumberText(
                    armor.effective,
                    SafeNumberText(
                        armor.base
                    )
                )
        )
    end

    AddSubHeader(
        lines,
        "Primary Attributes"
    )

    local primaryStats =
        data.primaryStats
        or {}

    local orderedStats = {
        "strength",
        "agility",
        "stamina",
        "intellect",
    }

    for _, statKey
        in ipairs(
            orderedStats
        )
    do
        local entry =
            primaryStats[
                statKey
            ]

        if entry then
            AddLine(
                lines,
                string.format(
                    "%s: %s",
                    U.SafeString(
                        entry.label,
                        statKey
                    ),
                    SafeNumberText(
                        entry.effective,
                        SafeNumberText(
                            entry.base
                        )
                    )
                )
            )
        end
    end

    local attackPower =
        data.attackPower
        or {}

    if U.ToSafeNumber(
        attackPower.effective
    ) ~= nil
    then
        AddLine(
            lines,
            "Attack Power: "
                .. SafeNumberText(
                    attackPower.effective
                )
        )
    end

    AddSubHeader(
        lines,
        "Combat Ratings"
    )

    local combatRatings =
        data.combatRatings
        or {}

    local orderedRatings = {
        "crit",
        "haste",
        "mastery",
        "versatility",
        "leech",
        "speed",
        "avoidance",
    }

    for _, ratingKey
        in ipairs(
            orderedRatings
        )
    do
        local rating =
            combatRatings[
                ratingKey
            ]

        local isEmptyRating =
            rating
            and ratingKey ~= "crit"
            and not IsDetailedExport()
            and (U.ToSafeNumber(rating.rating) or 0) == 0
            and (U.ToSafeNumber(rating.bonus) or 0) == 0

        if rating and not isEmptyRating then
            AddLine(
                lines,
                string.format(
                    "%s: %s rating / %s%%",
                    U.SafeString(
                        rating.label,
                        ratingKey
                    ),
                    SafeNumberText(
                        rating.rating
                    ),
                    ShortDecimalText(
                        rating.bonus
                    )
                )
            )
        end
    end

    if data.restrictedValuesDetected
        == true
    then
        AddLine(
            lines,
            "[Some character values were restricted by the client and could not be exported.]"
        )
    end

    AddBlankLine(
        lines
    )
end

function TextFormatter:AddCurrenciesDetailed(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.CURRENCIES
        ]
    )

    AddLine(
        lines,
        "Gold: "
            .. FormatMoneyCopper(
                data.money
            )
    )

    local entries =
        data.entries
        or {}

    local count =
        U.ToSafeNumber(
            data.count
        )
        or #entries

    AddLine(
        lines,
        "Currency Count: "
            .. SafeNumberText(
                count,
                tostring(
                    #entries
                )
            )
    )

    AddBlankLine(
        lines
    )

    if count == 0 then
        AddLine(
            lines,
            "[No currencies found.]"
        )

        AddBlankLine(
            lines
        )

        return
    end

    local categories =
        data.categories
        or {}

    if #categories > 0 then
        for _, category
            in ipairs(categories)
        do
            AddSubHeader(
                lines,
                category.name
                or "Other"
            )

            for _, entry
                in ipairs(
                    category.entries
                    or {}
                )
            do
                AddLine(
                    lines,
                    FormatCurrencyLine(
                        entry
                    )
                )
            end

            AddBlankLine(
                lines
            )
        end
    else
        for _, entry
            in ipairs(entries)
        do
            AddLine(
                lines,
                FormatCurrencyLine(
                    entry
                )
            )
        end

        AddBlankLine(
            lines
        )
    end
end

function TextFormatter:AddQuestsDetailed(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.QUESTS
        ]
    )

    local groups =
        data.groups
        or {}

    if #groups == 0 then
        AddLine(
            lines,
            "[No active quests found.]"
        )

        AddBlankLine(
            lines
        )

        return
    end

    for _, group
        in ipairs(groups)
    do
        AddSubHeader(
            lines,
            group.name
            or "General"
        )

        local quests =
            group.quests
            or {}

        if #quests == 0 then
            AddLine(
                lines,
                "[No quests in this group.]"
            )
        else
            for _, quest
                in ipairs(quests)
            do
                AddLine(
                    lines,
                    FormatQuestLine(
                        quest
                    )
                )

                local objectives =
                    quest.objectives
                    or {}

                for _, objective
                    in ipairs(
                        objectives
                    )
                do
                    AddLine(
                        lines,
                        FormatQuestObjectiveLine(
                            objective
                        )
                    )
                end
            end
        end

        AddBlankLine(
            lines
        )
    end
end

function TextFormatter:AddCompletedQuestsDetailed(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.COMPLETED_QUESTS
        ]
    )

    local entries =
        data.entries
        or {}

    local resolvedQuests =
        data.resolvedQuests
        or {}

    local trackingQuests =
        data.trackingQuests
        or {}

    local unresolvedQuestIDs =
        data.unresolvedQuestIDs
        or {}

    local count =
        U.ToSafeNumber(
            data.count
        )
        or #entries

    local resolvedCount =
        U.ToSafeNumber(
            data.resolvedCount
        )
        or #resolvedQuests

    local unresolvedCount =
        U.ToSafeNumber(
            data.unresolvedCount
        )
        or #unresolvedQuestIDs

    local trackingCount =
        U.ToSafeNumber(
            data.trackingCount
        )
        or #trackingQuests

    AddLine(
        lines,
        "Completed Quest Count: "
            .. SafeNumberText(
                count
            )
    )

    AddLine(
        lines,
        "Resolved Quest Titles: "
            .. SafeNumberText(
                resolvedCount
            )
    )

    AddLine(
        lines,
        "Unresolved Quest Titles: "
            .. SafeNumberText(
                unresolvedCount
            )
    )

    AddLine(
        lines,
        "Tracking Quest Count: "
            .. SafeNumberText(
                trackingCount
            )
    )

    AddBlankLine(
        lines
    )

    AddSubHeader(
        lines,
        "Resolved Quests"
    )

    if #resolvedQuests == 0 then
        AddLine(
            lines,
            "[No resolved completed quest titles returned by the Forever quest APIs.]"
        )
    else
        for _, quest
            in ipairs(
                resolvedQuests
            )
        do
            local line =
                FormatCompletedQuestLine(
                    quest
                )

            if line then
                AddLine(
                    lines,
                    line
                )
            end
        end
    end

    if #trackingQuests > 0 then
        AddBlankLine(
            lines
        )

        AddSubHeader(
            lines,
            "Tracking Quests"
        )

        for _, quest
            in ipairs(
                trackingQuests
            )
        do
            AddLine(
                lines,
                string.format(
                    "Tracking Quest (ID: %s)",
                    SafeNumberText(
                        quest
                        and quest.questID
                    )
                )
            )
        end
    end

    if #unresolvedQuestIDs > 0 then
        AddBlankLine(
            lines
        )

        AddSubHeader(
            lines,
            "Unresolved Quest IDs"
        )

        AddCompactIDBlock(
            lines,
            unresolvedQuestIDs,
            20,
            180
        )
    end

    AddBlankLine(
        lines
    )
end

function TextFormatter:AddSkills(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.SKILLS
        ]
    )

    local groups =
        data.groups
        or {}

    if #groups == 0 then
        AddLine(
            lines,
            "[No profession skills returned.]"
        )

        AddBlankLine(
            lines
        )

        return
    end

    for _, group
        in ipairs(groups)
    do
        AddSubHeader(
            lines,
            group.name
            or "Skills"
        )

        local entries =
            group.entries
            or {}

        if #entries == 0 then
            AddLine(
                lines,
                "[No skills in this group.]"
            )
        else
            for _, entry
                in ipairs(entries)
            do
                AddLine(
                    lines,
                    FormatSkillLine(
                        entry
                    )
                )
            end
        end

        AddBlankLine(
            lines
        )
    end
end

function TextFormatter:AddProfessionDetailsDetailed(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.PROFESSION_DETAILS
        ]
    )

    if data.available == false then
        if not TextFormatter.AddProfessionFallback(lines, data.fallback) then
            AddLine(
                lines,
                data.unavailableMessage
                or C.TEXT.PROFESSION_DETAILS_UNAVAILABLE_NO_CACHE
            )
        end

        AddBlankLine(
            lines
        )

        return
    end

    if data.cached then
        local updatedAt =
            FormatTimestamp(
                data.lastUpdated
            )

        if updatedAt then
            AddLine(
                lines,
                string.format(
                    "%s - last updated: %s.]",
                    C.TEXT.PROFESSION_DETAILS_CACHED_PREFIX
                    or "[Using cached profession details",
                    updatedAt
                )
            )
        else
            AddLine(
                lines,
                string.format(
                    "%s.]",
                    C.TEXT.PROFESSION_DETAILS_CACHED_PREFIX
                    or "[Using cached profession details"
                )
            )
        end

        AddBlankLine(
            lines
        )
    end

    local professions =
        data.professions
        or {}

    if #professions == 0 then
        if not TextFormatter.AddProfessionFallback(lines, data.fallback) then
            AddLine(
                lines,
                data.unavailableMessage
                or C.TEXT.PROFESSION_DETAILS_UNAVAILABLE_NO_CACHE
            )
        end

        AddBlankLine(
            lines
        )

        return
    end

    for _, profession
        in ipairs(
            professions
        )
    do
        local professionName =
            profession.name
            or "Unknown Profession"

        local rank =
            U.ToSafeNumber(
                profession.rank
            )

        local maxRank =
            U.ToSafeNumber(
                profession.maxRank
            )

        local recipeCount =
            U.ToSafeNumber(
                profession.recipeCount
            )
            or #(
                profession.recipes
                or {}
            )

        local header =
            professionName

        if rank ~= nil
            and maxRank ~= nil
        then
            header =
                string.format(
                    "%s (%s/%s)",
                    header,
                    SafeNumberText(
                        rank
                    ),
                    SafeNumberText(
                        maxRank
                    )
                )
        end

        header =
            string.format(
                "%s - Recipes: %s",
                header,
                SafeNumberText(
                    recipeCount
                )
            )

        AddSubHeader(
            lines,
            header
        )

        if U.IsNonEmptyString(
            profession.expansionName
        )
        then
            AddLine(
                lines,
                "Expansion: "
                    .. profession.expansionName
            )
        end

        if U.ToSafeNumber(
            profession.professionID
        ) ~= nil
        then
            AddLine(
                lines,
                "Profession ID: "
                    .. SafeNumberText(
                        profession.professionID
                    )
            )
        end

        local recipes =
            profession.recipes
            or {}

        if #recipes == 0 then
            AddLine(
                lines,
                "[No recipes returned.]"
            )
        else
            for _, recipe
                in ipairs(
                    recipes
                )
            do
                AddLine(
                    lines,
                    FormatProfessionRecipeLine(
                        recipe
                    )
                )
            end
        end

        AddBlankLine(
            lines
        )
    end

    if TextFormatter.AddProfessionFallback(lines, data.fallback) then
        AddBlankLine(
            lines
        )
    end
end

function TextFormatter:AddTalents(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.TALENTS
        ]
    )

    local wroteMetadata =
        false

    local specialization =
        data.specialization
        or {}

    if U.IsNonEmptyString(
        specialization.name
    )
    then
        AddLine(
            lines,
            string.format(
                "Active Specialization: %s",
                specialization.name
            )
        )

        wroteMetadata =
            true
    end

    if U.IsNonEmptyString(
        data.loadoutName
    )
    then
        AddLine(
            lines,
            string.format(
                "Loadout Name: %s",
                data.loadoutName
            )
        )

        wroteMetadata =
            true
    end

    if data.configID ~= nil and IsDetailedExport() then
        AddLine(
            lines,
            string.format(
                "Active Config ID: %s",
                SafeNumberText(
                    data.configID,
                    tostring(
                        data.configID
                    )
                )
            )
        )

        wroteMetadata =
            true
    end

    if wroteMetadata then
        AddBlankLine(
            lines
        )
    end

    if U.IsNonEmptyString(
        data.importString
    )
    then
        AddLine(
            lines,
            "Talent Import String:"
        )

        AddLine(
            lines,
            data.importString
        )

        AddBlankLine(
            lines
        )
    end

    local trees =
        data.trees
        or {}

    if #trees == 0 then
        AddLine(
            lines,
            "[No talent trees returned by the Forever talent APIs.]"
        )

        AddBlankLine(
            lines
        )
    else
        for _, tree
            in ipairs(trees)
        do
            local header =
                tree.name
                or "Tree"

            if U.IsNonEmptyString(
                tree.type
            )
            then
                header =
                    string.format(
                        "%s (%s)",
                        tree.type,
                        header
                    )
            end

            AddSubHeader(
                lines,
                header
            )

            local talents =
                tree.talents
                or {}

            if #talents == 0 then
                AddLine(
                    lines,
                    "[No selected talent nodes returned by the Forever talent APIs.]"
                )
            else
                for _, entry
                    in ipairs(
                        talents
                    )
                do
                    if entry
                        and U.IsNonEmptyString(
                            entry.name
                        )
                    then
                        AddLine(
                            lines,
                            FormatTalentLine(
                                entry
                            )
                        )
                    end
                end
            end

            AddBlankLine(
                lines
            )
        end
    end

    local diagnostics =
        data.diagnostics
        or {}

    if SHOW_DIAGNOSTICS then
        for _, message
            in ipairs(
                diagnostics
            )
        do
            AddLine(
                lines,
                "[Debug] "
                    .. message
            )
        end
    end

    if SHOW_DIAGNOSTICS and #diagnostics > 0 then
        AddBlankLine(
            lines
        )
    end
end

function TextFormatter:AddSpellbookDetailed(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.SPELLBOOK
        ]
    )

    local sectionOrder =
        data.sectionOrder
        or {
            {
                key = "general",
                title = "General",
            },
            {
                key = "class",
                title = "Class",
            },
            {
                key = "spec",
                title = "Spec",
            },
        }

    local sections =
        data.sections
        or {}

    for _, sectionMeta
        in ipairs(
            sectionOrder
        )
    do
        local section =
            sections[
                sectionMeta.key
            ]
            or {}

        AddSubHeader(
            lines,
            section.title
            or sectionMeta.title
        )

        local spells =
            section.spells
            or {}

        if #spells == 0 then
            AddLine(
                lines,
                "[No spells returned by the Forever spellbook APIs.]"
            )
        else
            for _, entry
                in ipairs(spells)
            do
                if entry
                    and U.IsNonEmptyString(
                        entry.name
                    )
                then
                    AddLine(
                        lines,
                        FormatSpellLine(
                            entry
                        )
                    )
                end
            end
        end

        AddBlankLine(
            lines
        )
    end

    local diagnostics =
        data.diagnostics
        or {}

    if SHOW_DIAGNOSTICS then
        for _, message
            in ipairs(
                diagnostics
            )
        do
            AddLine(
                lines,
                "[Debug] "
                    .. message
            )
        end
    end

    if SHOW_DIAGNOSTICS and #diagnostics > 0 then
        AddBlankLine(
            lines
        )
    end
end

local function YesNo(value)
    if type(value)
        ~= "boolean"
    then
        return nil
    end

    return
        value
        and "yes"
        or "no"
end

local function FormatLockoutInstanceLine(
    entry
)
    local name =
        U.SafeString(
            entry
            and entry.name,
            "Unknown Instance"
        )

    local details = {}

    local difficultyName =
        entry
        and U.ToSafeString(
            entry.difficultyName
        )

    local maxPlayers =
        entry
        and U.ToSafeNumber(
            entry.maxPlayers
        )

    if difficultyName ~= nil
        and difficultyName ~= ""
        and maxPlayers ~= nil
    then
        table.insert(
            details,
            string.format(
                "%s, %s",
                difficultyName,
                SafeNumberText(
                    maxPlayers
                )
            )
        )
    elseif difficultyName ~= nil
        and difficultyName ~= ""
    then
        table.insert(
            details,
            difficultyName
        )
    elseif maxPlayers ~= nil then
        table.insert(
            details,
            SafeNumberText(
                maxPlayers
            )
        )
    end

    if entry
        and type(entry.isRaid)
            == "boolean"
    then
        table.insert(
            details,
            entry.isRaid
            and "Raid"
            or "Dungeon"
        )
    end

    local line =
        name

    if #details > 0 then
        line =
            string.format(
                "%s (%s)",
                line,
                table.concat(
                    details,
                    ", "
                )
            )
    end

    local parts = {}

    local lockedText =
        YesNo(
            entry
            and entry.locked
        )

    if lockedText then
        table.insert(
            parts,
            "Locked: "
                .. lockedText
        )
    end

    local extendedText =
        YesNo(
            entry
            and entry.extended
        )

    if extendedText then
        table.insert(
            parts,
            "Extended: "
                .. extendedText
        )
    end

    local resetText =
        U.ToSafeString(
            entry
            and entry.resetText
        )

    if resetText ~= nil
        and resetText ~= ""
    then
        table.insert(
            parts,
            "Reset: "
                .. resetText
        )
    end

    local encounterProgress =
        U.ToSafeNumber(
            entry
            and entry.encounterProgress
        )

    local numEncounters =
        U.ToSafeNumber(
            entry
            and entry.numEncounters
        )

    if encounterProgress ~= nil
        and numEncounters ~= nil
    then
        table.insert(
            parts,
            string.format(
                "Progress: %s/%s",
                SafeNumberText(
                    encounterProgress
                ),
                SafeNumberText(
                    numEncounters
                )
            )
        )
    end

    local lockoutID =
        U.ToSafeNumber(
            entry
            and (
                entry.lockoutID
                or entry.id
            )
        )

    if lockoutID ~= nil then
        table.insert(
            parts,
            "Lockout ID: "
                .. SafeNumberText(
                    lockoutID
                )
        )
    end

    if #parts > 0 then
        line =
            line
            .. " - "
            .. table.concat(
                parts,
                " - "
            )
    end

    return line
end

local function FormatWorldBossLine(entry)
    local line =
        U.SafeString(
            entry
            and entry.name,
            "Unknown World Boss"
        )

    local worldBossID =
        U.ToSafeNumber(
            entry
            and entry.worldBossID
        )

    if worldBossID ~= nil then
        line =
            string.format(
                "%s (ID: %s)",
                line,
                SafeNumberText(
                    worldBossID
                )
            )
    end

    local resetText =
        U.ToSafeString(
            entry
            and entry.resetText
        )

    if resetText ~= nil
        and resetText ~= ""
    then
        line =
            line
            .. " - Reset: "
            .. resetText
    end

    return line
end

function TextFormatter:AddReputationsDetailed(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.REPUTATIONS
        ]
    )

    local entries =
        data.entries
        or {}

    if #entries == 0 then
        AddLine(
            lines,
            "[No reputations returned by the Forever reputation APIs.]"
        )
    else
        for _, entry
            in ipairs(entries)
        do
            AddLine(
                lines,
                FormatReputationLine(
                    entry
                )
            )
        end
    end

    local diagnostics =
        data.diagnostics
        or {}

    if SHOW_DIAGNOSTICS then
        for _, message
            in ipairs(
                diagnostics
            )
        do
            AddLine(
                lines,
                "[Debug] "
                    .. message
            )
        end
    end

    AddBlankLine(
        lines
    )
end

function TextFormatter:AddCollections(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.COLLECTIONS
        ]
    )

    local mounts =
        data.mounts
        or {}

    AddSubHeader(
        lines,
        "Mounts"
    )

    AddLine(
        lines,
        string.format(
            "Mount Count: %s/%s",
            SafeNumberText(
                mounts.collected
            ),
            SafeNumberText(
                mounts.total
            )
        )
    )

    local mountEntries =
        mounts.entries
        or {}

    if #mountEntries == 0 then
        AddLine(
            lines,
            "[No mounts found.]"
        )
    else
        for _, entry
            in ipairs(
                mountEntries
            )
        do
            AddLine(
                lines,
                FormatMountLine(
                    entry
                )
            )
        end
    end

    AddBlankLine(
        lines
    )

    local pets =
        data.pets
        or {}

    AddSubHeader(
        lines,
        "Battle Pets"
    )

    AddLine(
        lines,
        string.format(
            "Pet Count: %s/%s",
            SafeNumberText(
                pets.owned
            ),
            SafeNumberText(
                pets.total
            )
        )
    )

    local petEntries =
        pets.entries
        or {}

    if #petEntries == 0 then
        AddLine(
            lines,
            "[No battle pets found.]"
        )
    else
        for _, entry
            in ipairs(
                petEntries
            )
        do
            AddLine(
                lines,
                FormatPetLine(
                    entry
                )
            )
        end
    end

    AddBlankLine(
        lines
    )

    local toys =
        data.toys
        or {}

    AddSubHeader(
        lines,
        "Toys"
    )

    AddLine(
        lines,
        string.format(
            "Toy Count: %s/%s",
            SafeNumberText(
                toys.owned
            ),
            SafeNumberText(
                toys.total
            )
        )
    )

    local toyEntries =
        toys.entries
        or {}

    if #toyEntries == 0 then
        AddLine(
            lines,
            "[No toys found.]"
        )
    else
        for _, entry
            in ipairs(
                toyEntries
            )
        do
            AddLine(
                lines,
                FormatToyLine(
                    entry
                )
            )
        end
    end

    AddBlankLine(
        lines
    )
end

function TextFormatter:AddLockouts(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.LOCKOUTS
        ]
    )

    local instances =
        data.instances
        or {}

    local instanceEntries =
        instances.entries
        or {}

    AddLine(
        lines,
        "Instance Lockout Count: "
            .. SafeNumberText(
                instances.count,
                tostring(
                    #instanceEntries
                )
            )
    )

    AddBlankLine(
        lines
    )

    AddSubHeader(
        lines,
        "Saved Instances"
    )

    if #instanceEntries == 0 then
        AddLine(
            lines,
            "[No saved instances found.]"
        )
    else
        for _, entry
            in ipairs(
                instanceEntries
            )
        do
            if entry
                and U.IsNonEmptyString(
                    entry.name
                )
            then
                AddLine(
                    lines,
                    FormatLockoutInstanceLine(
                        entry
                    )
                )

                local encounters =
                    entry.encounters
                    or {}

                for _, encounter
                    in ipairs(
                        encounters
                    )
                do
                    if encounter then
                        local encounterName =
                            U.SafeString(
                                encounter.name,
                                "Encounter "
                                    .. SafeNumberText(
                                        encounter.index,
                                        "?"
                                    )
                            )

                        local status =
                            encounter.isKilled
                                == true
                            and "killed"
                            or "available"

                        AddLine(
                            lines,
                            string.format(
                                "  - %s: %s",
                                encounterName,
                                status
                            )
                        )
                    end
                end
            end
        end
    end

    AddBlankLine(
        lines
    )

    AddSubHeader(
        lines,
        "World Bosses"
    )

    local worldBosses =
        data.worldBosses
        or {}

    local worldBossEntries =
        worldBosses.entries
        or {}

    AddLine(
        lines,
        "World Boss Lockout Count: "
            .. SafeNumberText(
                worldBosses.count,
                tostring(
                    #worldBossEntries
                )
            )
    )

    if #worldBossEntries == 0 then
        AddLine(
            lines,
            "[No world boss lockouts found.]"
        )
    else
        for _, entry
            in ipairs(
                worldBossEntries
            )
        do
            if entry
                and U.IsNonEmptyString(
                    entry.name
                )
            then
                AddLine(
                    lines,
                    FormatWorldBossLine(
                        entry
                    )
                )
            end
        end
    end

    AddBlankLine(
        lines
    )
end

function TextFormatter:AddProgress(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.PROGRESS
        ]
    )

    AddBlankLine(
        lines
    )

    local mythicPlus =
        data.mythicPlus
        or {}

    AddSubHeader(
        lines,
        "Mythic+"
    )

    local printedMythicPlus =
        false

    if U.ToSafeNumber(
        mythicPlus.overallScore
    ) ~= nil
    then
        AddLine(
            lines,
            "Overall Score: "
                .. ShortDecimalText(
                    mythicPlus.overallScore
                )
        )

        printedMythicPlus =
            true
    end

    if U.ToSafeNumber(
        mythicPlus.seasonScore
    ) ~= nil
        and mythicPlus.seasonScore
            ~= mythicPlus.overallScore
    then
        AddLine(
            lines,
            "Season Score: "
                .. ShortDecimalText(
                    mythicPlus.seasonScore
                )
        )

        printedMythicPlus =
            true
    end

    local runs =
        mythicPlus.runs
        or {}

    for _, run
        in ipairs(runs)
    do
        local line =
            FormatMythicPlusRunLine(
                run
            )

        if line ~= nil then
            AddLine(
                lines,
                line
            )

            printedMythicPlus =
                true
        end
    end

    if not printedMythicPlus then
        AddLine(
            lines,
            "[No Mythic+ progress returned by the Forever APIs.]"
        )
    end

    AddBlankLine(
        lines
    )

    AddSubHeader(
        lines,
        "PvP"
    )

    local pvp =
        data.pvp
        or {}

    local printedPvp =
        false

    if U.ToSafeNumber(
        pvp.honorLevel
    ) ~= nil
    then
        AddLine(
            lines,
            "Honor Level: "
                .. SafeNumberText(
                    pvp.honorLevel
                )
        )

        printedPvp =
            true
    end

    if U.ToSafeNumber(
        pvp.honor
    ) ~= nil
        and U.ToSafeNumber(
            pvp.honorMax
        ) ~= nil
    then
        AddLine(
            lines,
            string.format(
                "Honor Progress: %s/%s",
                SafeNumberText(
                    pvp.honor
                ),
                SafeNumberText(
                    pvp.honorMax
                )
            )
        )

        printedPvp =
            true
    end

    local brackets =
        pvp.brackets
        or {}

    for _, bracket
        in ipairs(
            brackets
        )
    do
        local line =
            FormatPvpBracketLine(
                bracket
            )

        if line ~= nil then
            AddLine(
                lines,
                line
            )

            printedPvp =
                true
        end
    end

    if not printedPvp then
        AddLine(
            lines,
            "[No PvP progress returned by the Forever APIs.]"
        )
    end

    AddBlankLine(
        lines
    )
end

local function IsWholeNumber(value)
    return
        U.ToSafeNumber(
            value
        ) ~= nil
        and value % 1 == 0
end

local function FormatAchievementDate(
    month,
    day,
    year
)
    month =
        U.ToSafeNumber(
            month
        )

    day =
        U.ToSafeNumber(
            day
        )

    year =
        U.ToSafeNumber(
            year
        )

    if not IsWholeNumber(month)
        or not IsWholeNumber(day)
        or not IsWholeNumber(year)
    then
        return nil
    end

    if month < 1
        or month > 12
        or day < 1
        or day > 31
        or year < 0
    then
        return nil
    end

    if year < 100 then
        year =
            2000
            + year
    end

    return string.format(
        "%04d-%02d-%02d",
        year,
        month,
        day
    )
end

local function FormatAchievementEntryDate(
    entry
)
    return
        FormatAchievementDate(
            entry
            and entry.month,
            entry
            and entry.day,
            entry
            and entry.year
        )
end

local function FormatAchievementName(entry)
    local name =
        U.ToSafeString(
            entry
            and entry.name
        )

    local achievementID =
        U.ToSafeNumber(
            entry
            and entry.achievementID
        )

    if name == nil
        or name == ""
    then
        name =
            "[Unknown Achievement]"
    end

    if achievementID ~= nil then
        return string.format(
            "%s (ID: %s)",
            name,
            SafeNumberText(
                achievementID
            )
        )
    end

    return name
end

local REWARD_PREFIXES = {
    "Reward:",
    "Title:",
    "Pet:",
    "Mount:",
    "Decor Reward:",
    "Item Reward:",
    "Cross-Game Reward:",
}

local function RewardHasKnownPrefix(
    reward
)
    for _, prefix
        in ipairs(
            REWARD_PREFIXES
        )
    do
        if reward:sub(
            1,
            #prefix
        ) == prefix
        then
            return true
        end
    end

    return false
end

local function AppendAchievementReward(
    parts,
    rewardText
)
    local reward =
        U.Trim(
            U.SafeString(
                rewardText,
                ""
            )
        )

    if reward ~= "" then
        if RewardHasKnownPrefix(
            reward
        )
        then
            table.insert(
                parts,
                reward
            )
        else
            table.insert(
                parts,
                "Reward: "
                    .. reward
            )
        end
    end
end

local function FormatRecentAchievementLine(
    entry
)
    local parts = {
        FormatAchievementName(
            entry
        ),
    }

    if U.ToSafeNumber(
        entry
        and entry.points
    ) ~= nil
    then
        table.insert(
            parts,
            "Points: "
                .. SafeNumberText(
                    entry.points
                )
        )
    end

    local dateText =
        FormatAchievementEntryDate(
            entry
        )

    if dateText ~= nil then
        table.insert(
            parts,
            "Completed: "
                .. dateText
        )
    end

    AppendAchievementReward(
        parts,
        entry
        and entry.rewardText
    )

    if entry
        and entry.isGuild
            == true
    then
        table.insert(
            parts,
            "Guild"
        )
    end

    if entry
        and entry.wasEarnedByMe
            == true
    then
        table.insert(
            parts,
            "Earned by me"
        )
    end

    return table.concat(
        parts,
        " - "
    )
end

local CATEGORY_SUMMARY_LIMIT =
    25

local function IsValidAchievementCategory(
    entry
)
    local name =
        U.ToSafeString(
            entry
            and entry.name
        )

    local total =
        U.ToSafeNumber(
            entry
            and entry.total
        )

    if name == nil
        or name == ""
        or total == nil
        or total <= 0
    then
        return false
    end

    return true
end

local function IsTopLevelAchievementCategory(
    entry
)
    local parentCategoryID =
        U.ToSafeNumber(
            entry
            and entry.parentCategoryID
        )

    return
        parentCategoryID == nil
        or parentCategoryID == 0
end

local function HasCategoryParentMetadata(
    entries
)
    if type(entries) ~= "table" then
        return false
    end

    for _, entry
        in ipairs(entries)
    do
        if U.ToSafeNumber(
            entry
            and entry.parentCategoryID
        ) ~= nil
        then
            return true
        end
    end

    return false
end

local function AppendAchievementCategorySummaryEntry(
    summary,
    seenNames,
    entry
)
    local name =
        U.ToSafeString(
            entry
            and entry.name
        )

    if name == nil
        or name == ""
    then
        return false
    end

    local dedupeKey =
        name:lower()

    if seenNames[
        dedupeKey
    ]
    then
        return false
    end

    seenNames[
        dedupeKey
    ] = true

    if #summary
        < CATEGORY_SUMMARY_LIMIT
    then
        table.insert(
            summary,
            entry
        )
    end

    return true
end

local function BuildAchievementCategorySummary(
    entries
)
    local summary = {}
    local seenNames = {}

    local hasParentMetadata =
        HasCategoryParentMetadata(
            entries
        )

    local uniqueValidCount =
        0

    if type(entries) ~= "table" then
        return
            summary,
            false
    end

    for _, entry
        in ipairs(entries)
    do
        if IsValidAchievementCategory(
            entry
        )
            and (
                not hasParentMetadata
                or IsTopLevelAchievementCategory(
                    entry
                )
            )
        then
            if AppendAchievementCategorySummaryEntry(
                summary,
                seenNames,
                entry
            )
            then
                uniqueValidCount =
                    uniqueValidCount
                    + 1
            end
        end
    end

    if #summary == 0
        and hasParentMetadata
    then
        seenNames = {}
        uniqueValidCount = 0

        for _, entry
            in ipairs(entries)
        do
            if IsValidAchievementCategory(
                entry
            )
                and AppendAchievementCategorySummaryEntry(
                    summary,
                    seenNames,
                    entry
                )
            then
                uniqueValidCount =
                    uniqueValidCount
                    + 1
            end
        end
    end

    return
        summary,
        uniqueValidCount
            > CATEGORY_SUMMARY_LIMIT
end

local function FormatAchievementCategoryLine(
    entry
)
    local name =
        U.ToSafeString(
            entry
            and entry.name
        )

    local completed =
        U.ToSafeNumber(
            entry
            and entry.completed
        )
        or 0

    local total =
        U.ToSafeNumber(
            entry
            and entry.total
        )

    if name == nil
        or name == ""
        or total == nil
        or total <= 0
    then
        return nil
    end

    return string.format(
        "%s - Completed: %s/%s",
        name,
        SafeNumberText(
            completed
        ),
        SafeNumberText(
            total
        )
    )
end

local function FormatTrackedAchievementLine(
    entry
)
    local parts = {
        FormatAchievementName(
            entry
        ),
    }

    if U.ToSafeNumber(
        entry
        and entry.points
    ) ~= nil
    then
        table.insert(
            parts,
            "Points: "
                .. SafeNumberText(
                    entry.points
                )
        )
    end

    if entry
        and entry.completed
            == true
    then
        table.insert(
            parts,
            "Completed"
        )

        local dateText =
            FormatAchievementEntryDate(
                entry
            )

        if dateText ~= nil then
            table.insert(
                parts,
                "Completed: "
                    .. dateText
            )
        end
    else
        table.insert(
            parts,
            "In Progress"
        )
    end

    AppendAchievementReward(
        parts,
        entry
        and entry.rewardText
    )

    return table.concat(
        parts,
        " - "
    )
end

local function FormatCompletedAchievementLine(
    entry
)
    if not entry
        or entry.completed
            ~= true
    then
        return nil
    end

    local parts = {
        FormatAchievementName(
            entry
        ),
    }

    if U.ToSafeNumber(
        entry.points
    ) ~= nil
    then
        table.insert(
            parts,
            "Points: "
                .. SafeNumberText(
                    entry.points
                )
        )
    end

    local dateText =
        FormatAchievementEntryDate(
            entry
        )

    if dateText ~= nil then
        table.insert(
            parts,
            "Completed: "
                .. dateText
        )
    end

    AppendAchievementReward(
        parts,
        entry.rewardText
    )

    if entry.isGuild == true then
        table.insert(
            parts,
            "Guild"
        )
    end

    if entry.wasEarnedByMe
        == true
    then
        table.insert(
            parts,
            "Earned by me"
        )
    end

    return table.concat(
        parts,
        " - "
    )
end

local function CompletedAchievementCategoryName(
    entry
)
    local categoryName =
        U.ToSafeString(
            entry
            and entry.categoryName
        )

    if categoryName ~= nil
        and categoryName ~= ""
    then
        return categoryName
    end

    local categoryID =
        U.ToSafeNumber(
            entry
            and entry.categoryID
        )

    if categoryID ~= nil then
        return
            "Category "
            .. SafeNumberText(
                categoryID
            )
    end

    return "Uncategorized"
end

function TextFormatter:AddAchievementsDetailed(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.ACHIEVEMENTS
        ]
    )

    if U.ToSafeNumber(
        data.points
    ) ~= nil
    then
        AddLine(
            lines,
            "Achievement Points: "
                .. SafeNumberText(
                    data.points
                )
        )
    end

    local completed =
        U.ToSafeNumber(
            data.completed
        )

    local total =
        U.ToSafeNumber(
            data.total
        )

    if completed ~= nil
        and total ~= nil
    then
        AddLine(
            lines,
            string.format(
                "Achievements Completed: %s/%s",
                SafeNumberText(
                    completed
                ),
                SafeNumberText(
                    total
                )
            )
        )
    elseif completed ~= nil then
        AddLine(
            lines,
            "Achievements Completed: "
                .. SafeNumberText(
                    completed
                )
        )
    elseif total ~= nil then
        AddLine(
            lines,
            "Achievements Total: "
                .. SafeNumberText(
                    total
                )
        )
    end

    AddBlankLine(
        lines
    )

    AddSubHeader(
        lines,
        "Recent Achievements"
    )

    local recent =
        data.recent
        or {}

    local recentEntries =
        recent.entries
        or {}

    if #recentEntries == 0 then
        AddLine(
            lines,
            "[No recent achievements returned by the Forever APIs.]"
        )
    else
        for index, entry
            in ipairs(
                recentEntries
            )
        do
            if index > 10 then
                break
            end

            AddLine(
                lines,
                FormatRecentAchievementLine(
                    entry
                )
            )
        end
    end

    AddBlankLine(
        lines
    )

    AddSubHeader(
        lines,
        "Category Summary"
    )

    local categories =
        data.categories
        or {}

    local categoryEntries =
        categories.entries
        or {}

    local categorySummary,
        categorySummaryTruncated =
        BuildAchievementCategorySummary(
            categoryEntries
        )

    if #categorySummary == 0 then
        AddLine(
            lines,
            "[No achievement categories returned by the Forever APIs.]"
        )
    else
        for _, entry
            in ipairs(
                categorySummary
            )
        do
            local line =
                FormatAchievementCategoryLine(
                    entry
                )

            if line ~= nil then
                AddLine(
                    lines,
                    line
                )
            end
        end

        if categorySummaryTruncated then
            AddLine(
                lines,
                "[Category summary truncated to 25 entries.]"
            )
        end
    end

    AddBlankLine(
        lines
    )

    AddSubHeader(
        lines,
        "Tracked Achievements"
    )

    local tracked =
        data.tracked
        or {}

    local trackedEntries =
        tracked.entries
        or {}

    if #trackedEntries == 0 then
        AddLine(
            lines,
            "[No tracked achievements.]"
        )
    else
        for _, entry
            in ipairs(
                trackedEntries
            )
        do
            AddLine(
                lines,
                FormatTrackedAchievementLine(
                    entry
                )
            )
        end
    end

    AddBlankLine(
        lines
    )
end

function TextFormatter:AddCompletedAchievementsDetailed(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.COMPLETED_ACHIEVEMENTS
        ]
    )

    local entries =
        data.entries
        or {}

    local count =
        U.ToSafeNumber(
            data.count
        )
        or #entries

    AddLine(
        lines,
        "Completed Achievement List Count: "
            .. SafeNumberText(
                count,
                tostring(
                    #entries
                )
            )
    )

    local reportedCompletedTotal =
        U.ToSafeNumber(
            data.reportedCompletedTotal
        )

    if reportedCompletedTotal ~= nil
        and count
            < reportedCompletedTotal
    then
        AddLine(
            lines,
            "Reported Completed Count: "
                .. SafeNumberText(
                    reportedCompletedTotal
                )
        )

        AddLine(
            lines,
            "[Completed achievement list may be incomplete because the Forever achievement category APIs did not return every completed achievement.]"
        )
    end

    if #entries == 0 then
        AddLine(
            lines,
            "[No completed achievements returned by the Forever APIs.]"
        )

        AddBlankLine(
            lines
        )

        return
    end

    local currentCategoryKey

    for _, entry
        in ipairs(entries)
    do
        if entry
            and entry.completed
                == true
        then
            local categoryName =
                CompletedAchievementCategoryName(
                    entry
                )

            if categoryName
                ~= currentCategoryKey
            then
                currentCategoryKey =
                    categoryName

                AddBlankLine(
                    lines
                )

                AddSubHeader(
                    lines,
                    categoryName
                )
            end

            local line =
                FormatCompletedAchievementLine(
                    entry
                )

            if line ~= nil then
                AddLine(
                    lines,
                    line
                )
            end
        end
    end

    if data.truncated == true then
        AddLine(
            lines,
            "[Completed achievement list truncated to "
                .. SafeNumberText(
                    data.maxEntries
                )
                .. " entries.]"
        )
    end

    AddBlankLine(
        lines
    )
end

local function HasAppearanceData(data)
    if type(data) ~= "table" then
        return false
    end

    local categories =
        data.categories
        and data.categories.entries
        or {}

    if #categories > 0 then
        return true
    end

    local sets =
        data.sets
        or {}

    if U.ToSafeNumber(
        sets.collected
    ) ~= nil
        or #(
            sets.entries
            or {}
        ) > 0
    then
        return true
    end

    if #(
        data.latest
        and data.latest.entries
        or {}
    ) > 0
    then
        return true
    end

    if #(
        data.favorites
        and data.favorites.entries
        or {}
    ) > 0
        or (
            U.ToSafeNumber(
                data.favorites
                and data.favorites.count
            )
            or 0
        ) > 0
    then
        return true
    end

    if #(
        data.outfits
        and data.outfits.entries
        or {}
    ) > 0
        or (
            U.ToSafeNumber(
                data.outfits
                and data.outfits.count
            )
            or 0
        ) > 0
    then
        return true
    end

    return false
end

local function FormatAppearanceCategoryLine(
    entry
)
    if type(entry) ~= "table"
        or not U.IsNonEmptyString(
            entry.name
        )
    then
        return nil
    end

    local collected =
        U.ToSafeNumber(
            entry.collected
        )

    local total =
        U.ToSafeNumber(
            entry.total
        )

    if total ~= nil
        and total <= 0
    then
        total =
            nil
    end

    if collected ~= nil
        and total ~= nil
    then
        return string.format(
            "%s - Collected: %s/%s",
            entry.name,
            SafeNumberText(
                collected
            ),
            SafeNumberText(
                total
            )
        )
    end

    if total ~= nil then
        return string.format(
            "%s - Total: %s",
            entry.name,
            SafeNumberText(
                total
            )
        )
    end

    if collected ~= nil then
        return string.format(
            "%s - Collected: %s",
            entry.name,
            SafeNumberText(
                collected
            )
        )
    end

    return nil
end

local function CleanAppearanceName(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local name =
        CleanWoWText(
            entry.name
        )
        or CleanWoWText(
            entry.itemName
        )

    if name ~= nil then
        return name
    end

    if U.GetItemNameFromLink then
        name =
            U.GetItemNameFromLink(
                entry.itemLink
            )

        if U.IsNonEmptyString(
            name
        )
        then
            return name
        end
    end

    return
        CleanWoWText(
            entry.itemLink
        )
end

local function AddAppearanceEntryLines(
    lines,
    entries,
    maxEntries,
    fallbackText
)
    if type(entries) ~= "table"
        or #entries == 0
    then
        AddLine(
            lines,
            fallbackText
        )

        return
    end

    local printed =
        0

    for _, entry
        in ipairs(entries)
    do
        if printed
            >= maxEntries
        then
            break
        end

        if type(entry)
            == "table"
        then
            local name =
                CleanAppearanceName(
                    entry
                )

            local sourceID =
                U.ToSafeNumber(
                    entry.sourceID
                )

            local visualID =
                U.ToSafeNumber(
                    entry.visualID
                    or entry.appearanceID
                )

            local itemID =
                U.ToSafeNumber(
                    entry.itemID
                )

            local categoryName =
                CleanWoWText(
                    entry.categoryName
                )

            if name ~= nil
                or sourceID ~= nil
                or visualID ~= nil
            then
                local line =
                    name
                    or "Appearance"

                local details = {}

                if sourceID ~= nil then
                    table.insert(
                        details,
                        "Source ID: "
                            .. SafeNumberText(
                                sourceID
                            )
                    )
                end

                if visualID ~= nil then
                    table.insert(
                        details,
                        "Visual ID: "
                            .. SafeNumberText(
                                visualID
                            )
                    )
                end

                if itemID ~= nil then
                    table.insert(
                        details,
                        "Item ID: "
                            .. SafeNumberText(
                                itemID
                            )
                    )
                end

                if #details > 0 then
                    line =
                        line
                        .. " ("
                        .. table.concat(
                            details,
                            ", "
                        )
                        .. ")"
                end

                if categoryName ~= nil then
                    line =
                        line
                        .. " - Category: "
                        .. categoryName
                end

                AddLine(
                    lines,
                    line
                )

                printed =
                    printed
                    + 1
            end
        end
    end

    if printed == 0 then
        AddLine(
            lines,
            fallbackText
        )
    end
end

local function ResolveCollectedAppearanceDisplayName(
    entry
)
    if type(entry) ~= "table" then
        return nil
    end

    local collectedModule =
        ns.Data
        and ns.Data.CollectedAppearances

    if collectedModule
        and type(
            collectedModule.ResolveEntryDisplayName
        ) == "function"
    then
        local name =
            collectedModule.ResolveEntryDisplayName(
                entry
            )

        if U.IsNonEmptyString(
            name
        )
        then
            return name
        end
    end

    local function normalize(value)
        local text =
            CleanWoWText(
                value
            )

        if text == nil then
            return nil
        end

        local lower =
            text:lower()

        if lower == "unknown"
            or lower == "unknown item"
            or lower == "[unknown appearance]"
            or text:match(
                "^cnIQ%d*:?"
            )
        then
            return nil
        end

        if text:find(
            "|H",
            1,
            true
        )
            or text:find(
                "|h",
                1,
                true
            )
        then
            return nil
        end

        if text:match(
            "^%s*item:%d"
        )
        then
            return nil
        end

        return text
    end

    local name

    if collectedModule
        and type(
            collectedModule.ExtractItemNameFromLink
        ) == "function"
    then
        name =
            collectedModule.ExtractItemNameFromLink(
                entry.itemLink
            )
    elseif U.GetItemNameFromLink then
        name =
            normalize(
                U.GetItemNameFromLink(
                    entry.itemLink
                )
            )
    end

    return
        name
        or normalize(
            entry.itemName
        )
        or normalize(
            entry.name
        )
end

local function FormatCollectedAppearanceLine(
    entry
)
    if type(entry) ~= "table" then
        return nil
    end

    local name =
        ResolveCollectedAppearanceDisplayName(
            entry
        )
        or "[Unknown Appearance]"

    local details = {}

    local sourceID =
        U.ToSafeNumber(
            entry.sourceID
        )

    local itemID =
        U.ToSafeNumber(
            entry.itemID
        )

    local appearanceID =
        U.ToSafeNumber(
            entry.appearanceID
            or entry.visualID
        )

    if sourceID ~= nil then
        table.insert(
            details,
            "Source ID: "
                .. SafeNumberText(
                    sourceID
                )
        )
    end

    if itemID ~= nil then
        table.insert(
            details,
            "Item ID: "
                .. SafeNumberText(
                    itemID
                )
        )
    end

    if appearanceID ~= nil then
        table.insert(
            details,
            "Appearance ID: "
                .. SafeNumberText(
                    appearanceID
                )
        )
    end

    if #details > 0 then
        return string.format(
            "%s (%s)",
            name,
            table.concat(
                details,
                ", "
            )
        )
    end

    return name
end

local function CollectedAppearanceCategoryKey(
    value
)
    local number =
        U.ToSafeNumber(
            value
        )

    if number ~= nil then
        return tostring(
            number
        )
    end

    local text =
        CleanWoWText(
            value
        )

    if text ~= nil then
        return text:lower()
    end

    return nil
end

function TextFormatter:AddCollectedAppearancesDetailed(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.COLLECTED_APPEARANCES
        ]
    )

    local entries =
        data.entries
        or {}

    AddLine(
        lines,
        "Collected Appearance Source Count: "
            .. SafeNumberText(
                data.total,
                tostring(
                    #entries
                )
            )
    )

    if data.truncated == true then
        AddLine(
            lines,
            "[Appearance list truncated at "
                .. SafeNumberText(
                    data.maxEntries,
                    tostring(
                        #entries
                    )
                )
                .. " entries.]"
        )
    end

    AddBlankLine(
        lines
    )

    if #entries == 0 then
        AddLine(
            lines,
            "[No collected appearances returned by the Forever transmog APIs.]"
        )

        AddBlankLine(
            lines
        )

        return
    end

    local grouped = {}

    for _, entry
        in ipairs(entries)
    do
        if type(entry)
            == "table"
        then
            local categoryName =
                CleanWoWText(
                    entry.categoryName
                )
                or "Other"

            local categoryKey =
                CollectedAppearanceCategoryKey(
                    entry.categoryID
                )
                or CollectedAppearanceCategoryKey(
                    categoryName
                )
                or "other"

            if grouped[
                categoryKey
            ] == nil
            then
                grouped[
                    categoryKey
                ] = {
                    name =
                        categoryName,

                    entries =
                        {},
                }
            end

            table.insert(
                grouped[
                    categoryKey
                ].entries,
                entry
            )
        end
    end

    local categories =
        data.categories
        or {}

    for _, category
        in ipairs(categories)
    do
        local categoryKey =
            CollectedAppearanceCategoryKey(
                category.categoryID
            )
            or CollectedAppearanceCategoryKey(
                category.categoryName
                or category.name
            )

        local group =
            categoryKey
            and grouped[
                categoryKey
            ]

        if group
            and #group.entries > 0
        then
            AddSubHeader(
                lines,
                group.name
            )

            for _, entry
                in ipairs(
                    group.entries
                )
            do
                AddLine(
                    lines,
                    FormatCollectedAppearanceLine(
                        entry
                    )
                )
            end

            AddBlankLine(
                lines
            )

            grouped[
                categoryKey
            ] = nil
        end
    end

    local remainingKeys = {}

    for categoryKey, group
        in pairs(grouped)
    do
        if type(group)
            == "table"
            and #group.entries > 0
        then
            table.insert(
                remainingKeys,
                categoryKey
            )
        end
    end

    table.sort(
        remainingKeys,
        function(left, right)
            return
                (
                    grouped[left].name
                    or left
                )
                <
                (
                    grouped[right].name
                    or right
                )
        end
    )

    for _, categoryKey
        in ipairs(
            remainingKeys
        )
    do
        local group =
            grouped[
                categoryKey
            ]

        AddSubHeader(
            lines,
            group.name
        )

        for _, entry
            in ipairs(
                group.entries
            )
        do
            AddLine(
                lines,
                FormatCollectedAppearanceLine(
                    entry
                )
            )
        end

        AddBlankLine(
            lines
        )
    end
end

function TextFormatter:AddAppearances(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.APPEARANCES
        ]
    )

    if not HasAppearanceData(
        data
    )
    then
        AddLine(
            lines,
            "[No appearance data returned by the Forever transmog APIs.]"
        )

        AddBlankLine(
            lines
        )

        return
    end

    local categories =
        data.categories
        or {}

    local categoryEntries =
        categories.entries
        or {}

    AddSubHeader(
        lines,
        "Category Summary"
    )

    if #categoryEntries == 0 then
        AddLine(
            lines,
            "[No appearance categories returned by the Forever transmog APIs.]"
        )
    elseif not IsDetailedExport() then
        local parts = {}

        for _, entry in ipairs(categoryEntries) do
            local line = FormatAppearanceCategoryLine(entry)

            if line then
                table.insert(parts, (line:gsub(" %- Collected: ", " "):gsub(" %- Total: ", " of ")))
            end
        end

        AddLine(lines, table.concat(parts, ", "))
    else
        for _, entry
            in ipairs(
                categoryEntries
            )
        do
            AddLine(
                lines,
                FormatAppearanceCategoryLine(
                    entry
                )
            )
        end
    end

    AddBlankLine(
        lines
    )

    AddSubHeader(
        lines,
        "Transmog Sets"
    )

    local sets =
        data.sets
        or {}

    local collected =
        U.ToSafeNumber(
            sets.collected
        )

    local total =
        U.ToSafeNumber(
            sets.total
        )

    if collected ~= nil
        and total ~= nil
    then
        AddLine(
            lines,
            string.format(
                "Collected Sets: %s/%s",
                SafeNumberText(
                    collected
                ),
                SafeNumberText(
                    total
                )
            )
        )
    elseif collected ~= nil then
        AddLine(
            lines,
            "Collected Sets: "
                .. SafeNumberText(
                    collected
                )
        )
    else
        AddLine(
            lines,
            "[No transmog set summary returned by the Forever APIs.]"
        )
    end

    local setEntries =
        sets.entries
        or {}

    local printedSets =
        0

    for _, entry
        in ipairs(
            setEntries
        )
    do
        if printedSets >= 20 then
            break
        end

        if type(entry)
            == "table"
        then
            local setName =
                CleanWoWText(
                    entry.name
                )

            local setID =
                U.ToSafeNumber(
                    entry.setID
                )

            if setName ~= nil then
                local line =
                    setName

                if setID ~= nil then
                    line =
                        line
                        .. " (Set ID: "
                        .. SafeNumberText(
                            setID
                        )
                        .. ")"
                end

                AddLine(
                    lines,
                    line
                )

                printedSets =
                    printedSets
                    + 1
            elseif setID ~= nil then
                AddLine(
                    lines,
                    "Set ID: "
                        .. SafeNumberText(
                            setID
                        )
                )

                printedSets =
                    printedSets
                    + 1
            end
        end
    end

    AddBlankLine(
        lines
    )

    AddSubHeader(
        lines,
        "Latest Appearances"
    )

    AddAppearanceEntryLines(
        lines,
        data.latest
            and data.latest.entries
            or {},
        10,
        "[No latest appearances returned by the Forever APIs.]"
    )

    AddBlankLine(
        lines
    )

    AddSubHeader(
        lines,
        "Favorites"
    )

    AddAppearanceEntryLines(
        lines,
        data.favorites
            and data.favorites.entries
            or {},
        20,
        "[No favorite appearances returned by the Forever APIs.]"
    )

    AddBlankLine(
        lines
    )

    AddSubHeader(
        lines,
        "Outfits"
    )

    local outfits =
        data.outfits
        or {}

    local outfitEntries =
        outfits.entries
        or {}

    local outfitCount =
        U.ToSafeNumber(
            outfits.count
        )

    if outfitCount ~= nil then
        AddLine(
            lines,
            "Outfit Count: "
                .. SafeNumberText(
                    outfitCount
                )
        )
    end

    local printedOutfits =
        0

    for _, outfit
        in ipairs(
            outfitEntries
        )
    do
        if printedOutfits >= 20 then
            break
        end

        local name

        if type(outfit)
            == "table"
        then
            name =
                CleanWoWText(
                    outfit.name
                )
        else
            name =
                CleanWoWText(
                    outfit
                )
        end

        if name ~= nil then
            AddLine(
                lines,
                name
            )

            printedOutfits =
                printedOutfits
                + 1
        end
    end

    if outfitCount == nil
        and printedOutfits == 0
    then
        AddLine(
            lines,
            "[No saved outfits returned by the Forever APIs.]"
        )
    end

    AddBlankLine(
        lines
    )
end

function TextFormatter:AddAddonsDetailed(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.ADDONS
        ]
    )

    local entries =
        data.entries
        or {}

    AddLine(
        lines,
        "AddOns Count: "
            .. SafeNumberText(
                data.count,
                tostring(
                    #entries
                )
            )
    )

    AddBlankLine(
        lines
    )

    if #entries == 0 then
        AddLine(
            lines,
            "[No AddOns returned by the Forever AddOns APIs.]"
        )
    else
        for _, entry
            in ipairs(entries)
        do
            AddLine(
                lines,
                FormatAddonLine(
                    entry
                )
            )
        end
    end

    local diagnostics =
        data.diagnostics
        or {}

    if SHOW_DIAGNOSTICS then
        for _, message
            in ipairs(
                diagnostics
            )
        do
            AddLine(
                lines,
                "[Debug] "
                    .. message
            )
        end
    end

    AddBlankLine(
        lines
    )
end

function TextFormatter:AddBiography(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.BIOGRAPHY
        ]
    )

    local entries =
        data.entries
        or {}

    AddLine(
        lines,
        "Events: "
            .. tostring(
                #entries
            )
    )

    if #entries == 0 then
        AddLine(
            lines,
            C.TEXT.BIOGRAPHY_EMPTY
        )

        AddBlankLine(
            lines
        )

        return
    end

    local biography =
        ns.Data
        and ns.Data.Biography

    local currentDate =
        nil

    for _, entry
        in ipairs(entries)
    do
        local entryDate =
            biography
            and biography:FormatDate(
                entry.t
            )
            or "Unknown date"

        if entryDate ~= currentDate then
            currentDate =
                entryDate

            AddSubHeader(
                lines,
                entryDate
            )
        end

        AddLine(
            lines,
            string.format(
                "%s %s",
                biography
                    and biography:FormatTime(
                        entry.t
                    )
                    or "--:--",
                U.SafeString(
                    entry.text,
                    ""
                )
            )
        )
    end

    AddBlankLine(
        lines
    )
end

local function KillMobText(mob, detailed)
    local name = U.SafeString(mob.name, "Unknown")
    local kills = tostring(tonumber(mob.kills) or 0)

    if not detailed then
        return name .. " " .. kills
    end

    local facts = { kills .. " kills" }

    if (tonumber(mob.level) or 0) > 0 then
        table.insert(facts, "level " .. mob.level)
    end

    if mob.creatureType then
        table.insert(facts, mob.creatureType)
    end

    if mob.zone then
        table.insert(facts, mob.zone)
    end

    if (tonumber(mob.gold) or 0) > 0 then
        table.insert(facts, "gold " .. FormatMoneyCopper(mob.gold))
    end

    return name .. ": " .. table.concat(facts, ", ")
end

function TextFormatter:AddKills(lines, data)
    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.KILLS])

    local totals = data.totals or {}

    if (tonumber(totals.kills) or 0) == 0 then
        AddLine(lines, C.TEXT.KILLS_EMPTY)
        AddBlankLine(lines)
        return
    end

    local detailed = IsDetailedExport()

    AddLine(lines, string.format("Total kills: %d across %d creatures", totals.kills, totals.creatures or 0))
    AddLine(lines, "Gold looted: " .. FormatMoneyCopper(totals.gold))

    if data.imported then
        AddLine(lines, string.format(C.TEXT.KILLS_IMPORTED, tostring(data.imported.kills or 0)))
    end

    local session = data.session

    if session and (session.kills or 0) > 0 then
        AddLine(lines, string.format("This session: %d kills, %d per hour", session.kills, session.killsPerHour or 0))
    end

    local types = {}

    for _, entry in ipairs(totals.byType or {}) do
        table.insert(types, entry.name .. " " .. entry.kills)
    end

    if #types > 0 then
        AddLine(lines, "By type: " .. table.concat(types, ", "))
    end

    local top = data.top or {}

    if #top > 0 then
        AddSubHeader(lines, string.format("Top %d creatures", #top))

        if detailed then
            for _, mob in ipairs(top) do
                AddLine(lines, KillMobText(mob, true))
            end
        else
            local parts = {}

            for _, mob in ipairs(top) do
                table.insert(parts, KillMobText(mob, false))
            end

            AddLine(lines, table.concat(parts, ", "))
        end
    end

    local drops = data.drops or {}

    if #drops > 0 then
        local shown = drops
        local limit = C.KILLS_EXPORT_DROPS

        if not detailed and #drops > limit then
            shown = {}

            for index = 1, limit do
                shown[index] = drops[index]
            end

            table.insert(shown, string.format("and %d more", #drops - limit))
        end

        AddLine(lines, "Drops seen: " .. table.concat(shown, ", "))
    end

    AddBlankLine(lines)
end

-- 1h 23m, 45 kills (32/hr), 120 gathered (85/hr), gold +1g 20s 0c, 12,345 XP (9,000/hr)
local function SessionLine(S, entry, rates)
    local parts = { S.FormatDuration(entry.seconds) }

    if entry.zone then
        table.insert(parts, entry.zone)
    end

    local counts = {}

    local function Add(value, word, rate, format)
        if (value or 0) ~= 0 then
            local text = (format or S.FormatCount)(value) .. " " .. word

            if rates and rate then
                text = text .. " (" .. (format or S.FormatCount)(rate) .. "/hr)"
            end

            table.insert(counts, text)
        end
    end

    Add(entry.kills, "kills", entry.killsPerHour)
    Add(entry.gathered, "gathered", entry.gatheredPerHour)

    if (entry.gold or 0) ~= 0 then
        local text = "gold " .. S.FormatGold(entry.gold)

        if rates and entry.goldPerHour then
            text = text .. " (" .. S.FormatGold(entry.goldPerHour) .. "/hr)"
        end

        table.insert(counts, text)
    end

    Add(entry.xp, "XP", entry.xpPerHour)

    if (entry.levels or 0) > 0 then
        table.insert(counts, entry.levels == 1 and "1 level" or (entry.levels .. " levels"))
    end

    return table.concat(parts, ", ") .. (#counts > 0 and (": " .. table.concat(counts, ", ")) or "")
end

-- Session lines start with "This session", a category, or a date, never with
-- the "Character:", "Level:", or "Gold:" labels the nightly scan reads.
function TextFormatter:AddSessions(lines, data)
    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.SESSIONS])

    local S = ns.Data and ns.Data.Session
    local lifetime = data.lifetime or { total = 0, items = {}, byType = {} }
    local history = data.history or {}

    if not S or (not data.active and (lifetime.total or 0) == 0 and #history == 0) then
        AddLine(lines, C.TEXT.SESSIONS_EMPTY)
        AddBlankLine(lines)
        return
    end

    local detailed = IsDetailedExport()
    local summary = data.summary

    if data.active and summary then
        local text = "This session: " .. SessionLine(S, summary, true)

        if summary.timeToLevel then
            text = text .. ", next level in " .. S.FormatDuration(summary.timeToLevel)
        end

        AddLine(lines, text)
    else
        AddLine(lines, C.TEXT.SESSIONS_IDLE)
    end

    if (lifetime.total or 0) > 0 then
        AddSubHeader(lines, "Gathered")

        local byType = {}

        for _, item in ipairs(lifetime.items) do
            local key = item.type or "other"
            byType[key] = byType[key] or {}
            table.insert(byType[key], item)
        end

        local order = {}

        for key, count in pairs(lifetime.byType) do
            table.insert(order, { key = key, count = count })
        end

        table.sort(order, function(a, b)
            if a.count ~= b.count then
                return a.count > b.count
            end

            return a.key < b.key
        end)

        for _, group in ipairs(order) do
            local label = C.SESSION_CATEGORY_LABELS[group.key] or group.key
            local parts = {}

            for index, item in ipairs(byType[group.key] or {}) do
                if detailed then
                    table.insert(parts, string.format("%s %s (ID %d)", item.name or "Unknown item", S.FormatCount(item.count), item.id))
                elseif index <= C.SESSION_EXPORT_ITEMS then
                    table.insert(parts, (item.name or "Unknown item") .. " " .. S.FormatCount(item.count))
                end
            end

            local hidden = #(byType[group.key] or {}) - #parts

            if hidden > 0 then
                table.insert(parts, string.format("and %d more", hidden))
            end

            AddLine(lines, string.format("%s %s: %s", label, S.FormatCount(group.count), table.concat(parts, ", ")))
        end
    end

    if #history > 0 then
        AddSubHeader(lines, "Recent sessions")

        for index, entry in ipairs(history) do
            if not detailed and index > C.SESSION_EXPORT_HISTORY then
                break
            end

            local when = type(date) == "function" and date("%Y-%m-%d %H:%M", tonumber(entry.start) or 0) or tostring(entry.start)
            AddLine(lines, when .. ", " .. SessionLine(S, entry, false))
        end
    end

    AddBlankLine(lines)
end

-- Shopping lines start with an item name, "Short on", "Crafting", or "Ready",
-- never with the "Character:", "Level:", or "Gold:" labels the nightly scan reads.
function TextFormatter:AddShopping(lines, data)
    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.SHOPPING])

    local rows = data.rows or {}
    local recipes = data.recipes or {}
    local list = ns.Data and ns.Data.ShoppingList
    local count = list and list.FormatCount or tostring

    if #rows == 0 and #recipes == 0 then
        AddLine(lines, C.TEXT.SHOPPING_EXPORT_EMPTY)
        AddBlankLine(lines)
        return
    end

    local detailed = IsDetailedExport()
    local short = {}
    local ready = {}

    for _, row in ipairs(rows) do
        table.insert((row.short or 0) > 0 and short or ready, row)
    end

    local function Name(row)
        local name = row.name or ("Item " .. tostring(row.itemID))
        return detailed and string.format("%s (ID %d)", name, row.itemID) or name
    end

    if #rows > 0 then
        AddLine(lines, string.format("Short on %d of %d items.", #short, #rows))
    end

    for _, row in ipairs(short) do
        local text = string.format("%s: have %s of %s", Name(row), count(row.have or 0), count(row.need or 0))

        if (row.bank or 0) > 0 then
            text = text .. string.format(" (bags %s, bank %s)", count(row.bags or 0), count(row.bank))
        end

        if #(row.forRecipes or {}) > 0 then
            text = text .. ", for " .. table.concat(row.forRecipes, ", ")
        end

        AddLine(lines, text)
    end

    for _, recipe in ipairs(recipes) do
        local text = string.format("Crafting: %s x%s", recipe.name or "Recipe", count(recipe.count or 1))

        if recipe.profession then
            text = text .. " (" .. recipe.profession .. ")"
        end

        if detailed then
            text = text .. string.format(" (recipe ID %d)", recipe.recipeID)
        end

        if recipe.pending then
            text = text .. ", reagents not read yet"
        end

        AddLine(lines, text)
    end

    if #ready > 0 then
        local parts = {}

        for _, row in ipairs(ready) do
            table.insert(parts, string.format("%s %s/%s", Name(row), count(row.have or 0), count(row.need or 0)))
        end

        AddLine(lines, "Ready: " .. table.concat(parts, ", "))
    end

    AddBlankLine(lines)
end

-- Category names such as "Character" go in "== ... ==" subheaders and stat
-- lines are indented, so no line can pass for the "Character:", "Level:", or
-- "Gold:" lines the nightly scan reads.
function TextFormatter:AddStatistics(lines, data)
    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.STATISTICS])

    if not data.available then
        AddLine(lines, C.TEXT.STATISTICS_UNAVAILABLE)
        AddBlankLine(lines)
        return
    end

    local categories = data.categories or {}

    if #categories == 0 then
        AddLine(lines, C.TEXT.STATISTICS_EMPTY)
        AddBlankLine(lines)
        return
    end

    local detailed = IsDetailedExport()

    for _, category in ipairs(categories) do
        AddSubHeader(lines, category.name)

        if detailed then
            for _, stat in ipairs(category.stats) do
                AddLine(lines, string.format("  %s: %s (ID %d)", stat.name, stat.value, stat.id))
            end
        else
            local parts = {}

            for _, stat in ipairs(category.stats) do
                table.insert(parts, stat.name .. " " .. stat.value)
            end

            AddLine(lines, table.concat(parts, ", "))
        end
    end

    AddBlankLine(lines)
end

function TextFormatter:AddCompanions(
    lines,
    data
)
    AddSectionHeader(
        lines,
        data.title
        or C.SECTION_LABELS[
            C.SECTIONS.COMPANIONS
        ]
    )

    local entries =
        data.entries
        or {}

    if #entries == 0 then
        AddLine(
            lines,
            C.TEXT.COMPANIONS_NONE
        )

        AddBlankLine(
            lines
        )

        return
    end

    for _, entry
        in ipairs(entries)
    do
        AddSubHeader(
            lines,
            U.SafeString(
                entry.title,
                "Companion"
            )
        )

        for _, text
            in ipairs(
                entry.lines
                or {}
            )
        do
            AddLine(
                lines,
                U.SafeString(
                    text,
                    ""
                )
            )
        end
    end

    AddBlankLine(
        lines
    )
end

local COMPACT_LINE_LIMIT = 240

local RECIPE_DIFFICULTY_GROUPS = {
    { key = "optimal", label = "Orange" },
    { key = "medium", label = "Yellow" },
    { key = "easy", label = "Green" },
    { key = "trivial", label = "Grey" },
    { key = "other", label = "Other" },
}

local RECIPE_DIFFICULTY_KEYS = {
    ["0"] = "optimal",
    ["1"] = "medium",
    ["2"] = "easy",
    ["3"] = "trivial",
    optimal = "optimal",
    difficult = "optimal",
    medium = "medium",
    easy = "easy",
    trivial = "trivial",
}

local function CountedList(values, showCounts)
    local order = {}
    local counts = {}

    for _, value in ipairs(values or {}) do
        if U.IsNonEmptyString(value) then
            if counts[value] == nil then
                counts[value] = 0
                table.insert(order, value)
            end

            counts[value] = counts[value] + 1
        end
    end

    local result = {}

    for _, value in ipairs(order) do
        if showCounts ~= false and counts[value] > 1 then
            table.insert(result, string.format("%s x%d", value, counts[value]))
        else
            table.insert(result, value)
        end
    end

    return result
end

local function AddJoinedList(lines, label, values)
    if type(values) ~= "table" or #values == 0 then
        return
    end

    local current = U.IsNonEmptyString(label) and (label .. ": ") or ""
    local hasValue = false

    for _, value in ipairs(values) do
        local text = tostring(value)

        if hasValue and #current + #text + 2 > COMPACT_LINE_LIMIT then
            AddLine(lines, current)
            current = "  " .. text
        elseif hasValue then
            current = current .. ", " .. text
        else
            current = current .. text
        end

        hasValue = true
    end

    AddLine(lines, current)
end

local function PlainItemName(item)
    return (FormatItemDisplayName(item):gsub("^%[(.*)%]$", "%1"))
end

local function CompactStatText(item)
    if type(item) ~= "table" or type(item.stats) ~= "table" or #item.stats == 0 then
        return nil
    end

    local stats = U.ShallowCopy(item.stats)
    SortStats(stats)

    local parts = {}

    for _, stat in ipairs(stats) do
        local value = stat and U.ToSafeNumber(stat.value)

        if value ~= nil and value ~= 0 then
            table.insert(
                parts,
                ResolveStatLabel(stat.key or "UNKNOWN_STAT") .. " " .. ShortDecimalText(value)
            )
        end
    end

    if #parts == 0 then
        return nil
    end

    return table.concat(parts, ", ")
end

local function IsGearItem(item)
    return type(item) == "table"
        and (VALID_EQUIP_LOCS[item.equipLoc] == true or IsProfessionEquipment(item))
end

local function CompactItemEntries(items)
    local order = {}
    local byKey = {}
    local withStats = IsVerboseItemTypesEnabled()

    for _, item in ipairs(items or {}) do
        if type(item) == "table" then
            local name = PlainItemName(item)
            local suffix = nil

            if IsGearItem(item) then
                local parts = {}

                if U.IsValidItemLevel(item.itemLevel) then
                    table.insert(parts, "iLvl " .. SafeNumberText(item.itemLevel))
                end

                local rarity = FormatRarity(item)

                if rarity then
                    table.insert(parts, rarity)
                end

                local stats = withStats and CompactStatText(item) or nil

                if stats then
                    table.insert(parts, stats)
                end

                if #parts > 0 then
                    suffix = table.concat(parts, " ")
                end
            end

            local key = name .. "|" .. (suffix or "")
            local entry = byKey[key]

            if not entry then
                entry = { name = name, suffix = suffix, count = 0 }
                byKey[key] = entry
                table.insert(order, entry)
            end

            entry.count = entry.count + (U.ToSafeNumber(item.count) or 1)
        end
    end

    local result = {}

    for _, entry in ipairs(order) do
        local text = entry.name

        if entry.count > 1 then
            text = text .. " x" .. SafeNumberText(entry.count)
        end

        if entry.suffix then
            text = text .. " (" .. entry.suffix .. ")"
        end

        table.insert(result, text)
    end

    return result
end

local function AddCachedNote(lines, lastUpdated)
    local updatedAt = FormatTimestamp(lastUpdated)

    if updatedAt then
        AddLine(lines, "(Saved copy from " .. updatedAt .. ")")
    else
        AddLine(lines, "(Saved copy)")
    end
end

local function AddItemContainers(lines, sections, formatHeader)
    for _, section in ipairs(sections or {}) do
        local entries = CompactItemEntries(section.items)

        if #entries == 0 then
            AddLine(lines, formatHeader(section) .. ": empty")
        else
            AddJoinedList(lines, formatHeader(section), entries)
        end
    end
end

function TextFormatter.AddBankFallback(lines, fallback)
    if type(fallback) ~= "table" or #(fallback.sections or {}) == 0 then
        return false
    end

    AddLine(lines, fallback.note)
    AddItemContainers(lines, fallback.sections, FormatBankHeader)

    return true
end

function TextFormatter.AddProfessionFallback(lines, fallback)
    if type(fallback) ~= "table" or #(fallback.professions or {}) == 0 then
        return false
    end

    for _, profession in ipairs(fallback.professions) do
        local header = profession.name

        if U.ToSafeNumber(profession.level) then
            header = string.format("%s (skill %s)", header, SafeNumberText(profession.level))
        end

        AddSubHeader(lines, header)
        AddLine(lines, fallback.note)
        AddJoinedList(lines, "Known recipes", profession.recipes)
    end

    return true
end

function TextFormatter:AddBags(lines, data)
    if IsDetailedExport() then
        return self:AddBagsDetailed(lines, data)
    end

    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.BAGS])
    AddItemContainers(lines, data.sections, FormatBagHeader)
    AddBlankLine(lines)
end

function TextFormatter:AddBank(lines, data)
    if IsDetailedExport() then
        return self:AddBankDetailed(lines, data)
    end

    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.BANK])

    if not data.available then
        if not TextFormatter.AddBankFallback(lines, data.fallback) then
            AddLine(
                lines,
                data.unavailableMessage
                or C.TEXT.BANK_UNAVAILABLE_NO_CACHE
                or C.TEXT.BANK_UNAVAILABLE
            )
        end

        AddBlankLine(lines)
        return
    end

    if data.cached then
        AddCachedNote(lines, data.lastUpdated)
    end

    AddItemContainers(lines, data.sections, FormatBankHeader)
    AddBlankLine(lines)
end

local function CompactEquipmentDetails(item)
    local parts = {}

    if U.IsValidItemLevel(item.itemLevel) then
        table.insert(parts, "iLvl " .. SafeNumberText(item.itemLevel))
    end

    local rarity = FormatRarity(item)

    if rarity then
        table.insert(parts, rarity)
    end

    local subType = U.ToSafeString(item.itemSubType)

    if U.IsNonEmptyString(subType) and subType ~= "Miscellaneous" then
        table.insert(parts, subType)
    end

    local damageMin = U.ToSafeNumber(item.weaponDamageMin)
    local damageMax = U.ToSafeNumber(item.weaponDamageMax)

    if damageMin ~= nil and damageMax ~= nil then
        local damage = SafeNumberText(damageMin) .. "-" .. SafeNumberText(damageMax) .. " damage"

        if U.ToSafeNumber(item.weaponSpeed) ~= nil then
            damage = damage .. " at " .. ShortDecimalText(item.weaponSpeed) .. " speed"
        end

        table.insert(parts, damage)
    end

    local durabilityCurrent = U.ToSafeNumber(item.durabilityCurrent)
    local durabilityMax = U.ToSafeNumber(item.durabilityMax)

    if durabilityCurrent ~= nil
        and durabilityMax ~= nil
        and durabilityCurrent < durabilityMax
    then
        table.insert(
            parts,
            "durability " .. SafeNumberText(durabilityCurrent) .. "/" .. SafeNumberText(durabilityMax)
        )
    end

    local enhancements = type(item.enhancements) == "table" and item.enhancements or {}

    if type(enhancements.enchant) == "table" and U.ToSafeNumber(enhancements.enchant.id) ~= nil then
        table.insert(parts, "enchanted")
    end

    local gems = {}

    for _, gem in ipairs(type(enhancements.gems) == "table" and enhancements.gems or {}) do
        if type(gem) == "table" and U.IsNonEmptyString(gem.name) then
            table.insert(gems, gem.name)
        end
    end

    if #gems > 0 then
        table.insert(parts, "gems " .. table.concat(gems, " and "))
    end

    local text = ""

    if #parts > 0 then
        text = " " .. table.concat(parts, ", ")
    end

    local stats = CompactStatText(item)

    if stats then
        text = text .. " - " .. stats
    end

    return text
end

function TextFormatter:AddEquipment(lines, data)
    if IsDetailedExport() then
        return self:AddEquipmentDetailed(lines, data)
    end

    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.EQUIPMENT])

    local emptySlots = {}

    for _, slotInfo in ipairs(data.slots or {}) do
        local slot = slotInfo.slot or "Slot"

        if slotInfo.item then
            AddLine(
                lines,
                slot .. ": " .. FormatItemDisplayName(slotInfo.item) .. CompactEquipmentDetails(slotInfo.item)
            )
        else
            table.insert(emptySlots, slot)
        end
    end

    AddJoinedList(lines, "Empty", emptySlots)
    AddBlankLine(lines)
end

function TextFormatter:AddCompletedQuests(lines, data)
    if IsDetailedExport() then
        return self:AddCompletedQuestsDetailed(lines, data)
    end

    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.COMPLETED_QUESTS])

    local resolvedQuests = data.resolvedQuests or {}
    local unresolvedQuestIDs = data.unresolvedQuestIDs or {}
    local count = U.ToSafeNumber(data.count) or #(data.entries or {})
    local trackingCount = U.ToSafeNumber(data.trackingCount) or #(data.trackingQuests or {})

    local summary = "Completed Quest Count: " .. SafeNumberText(count)

    if trackingCount > 0 then
        summary = summary .. " (" .. SafeNumberText(trackingCount) .. " hidden tracking flags)"
    end

    AddLine(lines, summary)

    local titles = {}

    for _, quest in ipairs(resolvedQuests) do
        if type(quest) == "table" and U.IsNonEmptyString(quest.title) then
            table.insert(titles, quest.title)
        end
    end

    AddJoinedList(lines, "Quests", CountedList(titles))

    local ids = {}

    for _, questID in ipairs(unresolvedQuestIDs) do
        table.insert(ids, SafeNumberText(questID))
    end

    AddJoinedList(lines, "Unnamed quest IDs", ids)
    AddBlankLine(lines)
end

local function RecipeDifficultyKey(recipe)
    local key = RECIPE_DIFFICULTY_KEYS[string.lower(U.SafeString(recipe.difficulty, ""))]
    return key or "other"
end

function TextFormatter:AddProfessionDetails(lines, data)
    if IsDetailedExport() then
        return self:AddProfessionDetailsDetailed(lines, data)
    end

    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.PROFESSION_DETAILS])

    local professions = data.professions or {}

    if data.available == false or #professions == 0 then
        if not TextFormatter.AddProfessionFallback(lines, data.fallback) then
            AddLine(lines, data.unavailableMessage or C.TEXT.PROFESSION_DETAILS_UNAVAILABLE_NO_CACHE)
        end

        AddBlankLine(lines)
        return
    end

    if data.cached then
        AddCachedNote(lines, data.lastUpdated)
    end

    for _, profession in ipairs(professions) do
        local rank = U.ToSafeNumber(profession.rank)
        local maxRank = U.ToSafeNumber(profession.maxRank)
        local header = profession.name or "Unknown Profession"

        if rank ~= nil and maxRank ~= nil then
            header = string.format("%s %s/%s", header, SafeNumberText(rank), SafeNumberText(maxRank))
        end

        AddSubHeader(lines, header)

        local learned = {}
        local learnableNow = {}
        local unlearnedCount = 0

        for _, group in ipairs(RECIPE_DIFFICULTY_GROUPS) do
            learned[group.key] = {}
        end

        for _, recipe in ipairs(profession.recipes or {}) do
            if type(recipe) == "table" and U.IsNonEmptyString(recipe.name) then
                if recipe.learned == true then
                    table.insert(learned[RecipeDifficultyKey(recipe)], recipe.name)
                else
                    local required = U.ToSafeNumber(recipe.requiredSkill)

                    if required ~= nil and rank ~= nil and required <= rank then
                        table.insert(learnableNow, recipe.name)
                    else
                        unlearnedCount = unlearnedCount + 1
                    end
                end
            end
        end

        local anyLearned = false

        for _, group in ipairs(RECIPE_DIFFICULTY_GROUPS) do
            local names = CountedList(learned[group.key], false)

            if #names > 0 then
                anyLearned = true
                AddJoinedList(lines, group.label, names)
            end
        end

        if not anyLearned then
            AddLine(lines, "No learned recipes recorded.")
        end

        AddJoinedList(lines, "Can learn now", CountedList(learnableNow, false))

        if unlearnedCount > 0 then
            AddLine(lines, "Not learned yet: " .. SafeNumberText(unlearnedCount) .. " more recipes")
        end
    end

    TextFormatter.AddProfessionFallback(lines, data.fallback)
    AddBlankLine(lines)
end

function TextFormatter:AddSpellbook(lines, data)
    if IsDetailedExport() then
        return self:AddSpellbookDetailed(lines, data)
    end

    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.SPELLBOOK])

    local sectionOrder = data.sectionOrder or {
        { key = "general", title = "General" },
        { key = "class", title = "Class" },
        { key = "spec", title = "Spec" },
    }

    local sections = data.sections or {}

    for _, sectionMeta in ipairs(sectionOrder) do
        local section = sections[sectionMeta.key] or {}
        local names = {}
        local unknown = {}

        for _, entry in ipairs(section.spells or {}) do
            if type(entry) == "table" and U.IsNonEmptyString(entry.name) then
                local name = entry.name

                if entry.isPassive == true then
                    name = name .. " (passive)"
                end

                if entry.isKnown == false then
                    table.insert(unknown, name)
                else
                    table.insert(names, name)
                end
            end
        end

        local title = section.title or sectionMeta.title
        AddJoinedList(lines, title, CountedList(names, false))
        AddJoinedList(lines, title .. " (not learned yet)", CountedList(unknown, false))
    end

    AddBlankLine(lines)
end

function TextFormatter:AddCollectedAppearances(lines, data)
    if IsDetailedExport() then
        return self:AddCollectedAppearancesDetailed(lines, data)
    end

    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.COLLECTED_APPEARANCES])

    local entries = data.entries or {}

    AddLine(
        lines,
        "Collected Appearance Source Count: " .. SafeNumberText(data.total, tostring(#entries))
    )

    if data.truncated == true then
        AddLine(lines, "(List stops at " .. SafeNumberText(data.maxEntries, tostring(#entries)) .. " entries.)")
    end

    local order = {}
    local groups = {}

    for _, entry in ipairs(entries) do
        if type(entry) == "table" then
            local category = CleanWoWText(entry.categoryName) or "Other"
            local name = ResolveCollectedAppearanceDisplayName(entry)

            if not groups[category] then
                groups[category] = {}
                table.insert(order, category)
            end

            if name and not name:match("^Hidden ") then
                table.insert(groups[category], name)
            end
        end
    end

    for _, category in ipairs(order) do
        local names = CountedList(groups[category], false)

        if #names > 0 then
            AddJoinedList(lines, category .. " (" .. #names .. ")", names)
        end
    end

    AddBlankLine(lines)
end

function TextFormatter:AddAddons(lines, data)
    if IsDetailedExport() then
        return self:AddAddonsDetailed(lines, data)
    end

    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.ADDONS])

    local entries = data.entries or {}
    local loaded = {}
    local notLoaded = {}

    for _, entry in ipairs(entries) do
        if type(entry) == "table" then
            local text = entry.name or entry.internalName or "Unknown Addon"

            if U.IsNonEmptyString(entry.version) then
                text = text .. " [" .. entry.version .. "]"
            end

            if entry.loaded == true then
                table.insert(loaded, text)
            else
                local reason = U.IsNonEmptyString(entry.reason) and string.lower(entry.reason)
                    or (entry.enabled == false and "disabled")
                    or "not loaded"

                table.insert(notLoaded, text .. " - " .. reason)
            end
        end
    end

    AddLine(
        lines,
        string.format(
            "AddOns Count: %s (%d loaded)",
            SafeNumberText(data.count, tostring(#entries)),
            #loaded
        )
    )

    if #loaded > 0 then
        AddSubHeader(lines, "Loaded")

        for _, text in ipairs(loaded) do
            AddLine(lines, text)
        end
    end

    if #notLoaded > 0 then
        AddSubHeader(lines, "Not loaded")

        for _, text in ipairs(notLoaded) do
            AddLine(lines, text)
        end
    end

    AddBlankLine(lines)
end

local function IsKnownText(value)
    return U.IsNonEmptyString(value) and value ~= "unknown"
end

function TextFormatter:AddLocation(lines, data)
    if IsDetailedExport() then
        return self:AddLocationDetailed(lines, data)
    end

    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.LOCATION])

    local zone = U.SafeString(data.zone, "unknown")
    AddLine(lines, "Zone: " .. zone)

    if IsKnownText(data.subzone) and data.subzone ~= zone then
        AddLine(lines, "Subzone: " .. data.subzone)
    end

    local maps = {}

    if IsKnownText(data.map) and data.map ~= zone then
        table.insert(maps, data.map)
    end

    if IsKnownText(data.parentMap) and data.parentMap ~= data.map then
        table.insert(maps, data.parentMap)
    end

    if #maps > 0 then
        AddLine(lines, "Map: " .. table.concat(maps, ", "))
    end

    if IsKnownText(data.coordinates) then
        AddLine(lines, "Coordinates: " .. data.coordinates)
    end

    if IsKnownText(data.hearthstoneLocation) then
        AddLine(lines, "Hearthstone Location: " .. data.hearthstoneLocation)
    end

    AddBlankLine(lines)
end

local function CompactCurrencyText(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local text = U.SafeString(entry.name, "Unknown Currency")
    local quantity = U.ToSafeNumber(entry.quantity)
    local maxQuantity = U.ToSafeNumber(entry.maxQuantity)

    if quantity ~= nil and maxQuantity ~= nil and maxQuantity > 0 then
        text = string.format("%s %s/%s", text, SafeNumberText(quantity), SafeNumberText(maxQuantity))
    elseif quantity ~= nil then
        text = text .. " " .. SafeNumberText(quantity)
    end

    local maxWeekly = U.ToSafeNumber(entry.maxWeeklyQuantity)

    if maxWeekly ~= nil and maxWeekly > 0 then
        text = string.format(
            "%s (week %s/%s)",
            text,
            SafeNumberText(U.ToSafeNumber(entry.quantityEarnedThisWeek) or 0),
            SafeNumberText(maxWeekly)
        )
    end

    return text
end

local function CompactCurrencyList(entries)
    local values = {}

    for _, entry in ipairs(entries or {}) do
        local text = CompactCurrencyText(entry)

        if text then
            table.insert(values, text)
        end
    end

    return values
end

function TextFormatter:AddCurrencies(lines, data)
    if IsDetailedExport() then
        return self:AddCurrenciesDetailed(lines, data)
    end

    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.CURRENCIES])
    AddLine(lines, "Gold: " .. FormatMoneyCopper(data.money))

    local categories = data.categories or {}

    if #categories > 0 then
        for _, category in ipairs(categories) do
            AddJoinedList(lines, category.name or "Other", CompactCurrencyList(category.entries))
        end
    else
        AddJoinedList(lines, "Currencies", CompactCurrencyList(data.entries))
    end

    AddBlankLine(lines)
end

local function CompactReputationLine(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local text = string.format(
        "%s %s",
        entry.name or "Unknown Faction",
        entry.standing or ("Standing #" .. SafeNumberText(entry.standingID))
    )

    if entry.isMajorFaction == true then
        text = text .. " (major faction)"
    end

    local progress = U.ToSafeNumber(entry.progress)
    local nextStanding = U.ToSafeNumber(entry.nextStanding)
    local value = U.ToSafeNumber(entry.value)

    if progress ~= nil and nextStanding ~= nil then
        text = string.format("%s %s/%s", text, SafeNumberText(progress), SafeNumberText(nextStanding))
    elseif value ~= nil then
        text = text .. " " .. SafeNumberText(value)
    end

    if entry.isParagon == true and type(entry.paragon) == "table" then
        local current = U.ToSafeNumber(entry.paragon.currentValue)
        local threshold = U.ToSafeNumber(entry.paragon.threshold)

        if current ~= nil and threshold ~= nil then
            text = string.format("%s, paragon %s/%s", text, SafeNumberText(current), SafeNumberText(threshold))
        else
            text = text .. ", paragon"
        end

        if entry.paragon.hasRewardPending == true then
            text = text .. ", reward waiting"
        end
    end

    return text
end

function TextFormatter:AddReputations(lines, data)
    if IsDetailedExport() then
        return self:AddReputationsDetailed(lines, data)
    end

    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.REPUTATIONS])

    for _, entry in ipairs(data.entries or {}) do
        AddLine(lines, CompactReputationLine(entry))
    end

    AddBlankLine(lines)
end

local QUEST_STATUS_TEXT = {
    ready_to_turn_in = "ready to turn in",
    complete = "complete",
}

local function CompactQuestLine(quest)
    if type(quest) ~= "table" then
        return nil
    end

    local details = {}
    local level = U.ToSafeNumber(quest.level)
    local group = U.ToSafeNumber(quest.suggestedGroup)
    local questID = U.ToSafeNumber(quest.questID)
    local status = QUEST_STATUS_TEXT[quest.status] or "in progress"

    if level ~= nil then
        table.insert(details, SafeNumberText(level))
    end

    table.insert(details, status)

    if group ~= nil and group > 1 then
        table.insert(details, "group " .. SafeNumberText(group))
    end

    if questID ~= nil then
        table.insert(details, "ID " .. SafeNumberText(questID))
    end

    local text = string.format("%s (%s)", quest.title or "Unknown Quest", table.concat(details, ", "))

    if quest.status == "ready_to_turn_in" or quest.status == "complete" then
        return text
    end

    local objectives = {}

    for _, objective in ipairs(quest.objectives or {}) do
        if type(objective) == "table" and U.IsNonEmptyString(objective.text) then
            local objectiveText = U.Trim((objective.text:gsub("%s+", " ")))

            if objective.finished then
                objectiveText = objectiveText .. " (done)"
            end

            table.insert(objectives, objectiveText)
        end
    end

    if #objectives > 0 then
        text = text .. ": " .. table.concat(objectives, "; ")
    end

    return text
end

function TextFormatter:AddQuests(lines, data)
    if IsDetailedExport() then
        return self:AddQuestsDetailed(lines, data)
    end

    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.QUESTS])

    for _, group in ipairs(data.groups or {}) do
        if #(group.quests or {}) > 0 then
            AddSubHeader(lines, group.name or "General")

            for _, quest in ipairs(group.quests) do
                AddLine(lines, CompactQuestLine(quest))
            end
        end
    end

    AddBlankLine(lines)
end

local function CompactAchievementText(entry, extra)
    local name = U.ToSafeString(entry and entry.name)

    if name == nil or name == "" then
        name = "Unknown Achievement"
    end

    local details = {}
    local dateText = FormatAchievementEntryDate(entry)

    if dateText then
        table.insert(details, dateText)
    end

    if extra then
        table.insert(details, extra)
    end

    AppendAchievementReward(details, entry and entry.rewardText)

    if #details == 0 then
        return name
    end

    return string.format("%s (%s)", name, table.concat(details, ", "))
end

local function CompactAchievementCategories(entries)
    local started = {}
    local notStarted = 0
    local seen = {}
    local topLevelOnly = HasCategoryParentMetadata(entries)

    for _, entry in ipairs(entries or {}) do
        if IsValidAchievementCategory(entry)
            and (not topLevelOnly or IsTopLevelAchievementCategory(entry))
        then
            local key = string.lower(U.ToSafeString(entry.name))

            if not seen[key] then
                seen[key] = true

                local completed = U.ToSafeNumber(entry.completed) or 0

                if completed > 0 then
                    table.insert(started, string.format(
                        "%s %s/%s",
                        entry.name,
                        SafeNumberText(completed),
                        SafeNumberText(entry.total)
                    ))
                else
                    notStarted = notStarted + 1
                end
            end
        end
    end

    return started, notStarted
end

function TextFormatter:AddAchievements(lines, data)
    if IsDetailedExport() then
        return self:AddAchievementsDetailed(lines, data)
    end

    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.ACHIEVEMENTS])

    local points = U.ToSafeNumber(data.points)
    local completed = U.ToSafeNumber(data.completed)
    local total = U.ToSafeNumber(data.total)

    if points ~= nil and points > 0 then
        AddLine(lines, "Achievement Points: " .. SafeNumberText(points))
    end

    if completed ~= nil and total ~= nil then
        AddLine(lines, string.format("Achievements Completed: %s/%s", SafeNumberText(completed), SafeNumberText(total)))
    elseif completed ~= nil then
        AddLine(lines, "Achievements Completed: " .. SafeNumberText(completed))
    end

    local recent = {}

    for index, entry in ipairs(data.recent and data.recent.entries or {}) do
        if index > 10 then
            break
        end

        table.insert(recent, CompactAchievementText(entry))
    end

    AddJoinedList(lines, "Recent", recent)

    local started, notStarted = CompactAchievementCategories(data.categories and data.categories.entries)

    if #started > 0 or notStarted > 0 then
        local text = "Started: " .. (#started > 0 and table.concat(started, ", ") or "none")

        if notStarted > 0 then
            text = string.format("%s; %d categor%s not started", text, notStarted, notStarted == 1 and "y" or "ies")
        end

        AddLine(lines, text)
    end

    local tracked = {}

    for _, entry in ipairs(data.tracked and data.tracked.entries or {}) do
        table.insert(tracked, CompactAchievementText(entry, entry.completed == true and "done" or "in progress"))
    end

    AddJoinedList(lines, "Tracked", tracked)
    AddBlankLine(lines)
end

function TextFormatter:AddCompletedAchievements(lines, data)
    if IsDetailedExport() then
        return self:AddCompletedAchievementsDetailed(lines, data)
    end

    AddSectionHeader(lines, data.title or C.SECTION_LABELS[C.SECTIONS.COMPLETED_ACHIEVEMENTS])

    local entries = data.entries or {}
    local count = U.ToSafeNumber(data.count) or #entries
    local reported = U.ToSafeNumber(data.reportedCompletedTotal)

    if reported ~= nil and count < reported then
        AddLine(lines, string.format("Completed: %s listed of %s", SafeNumberText(count), SafeNumberText(reported)))
    else
        AddLine(lines, "Completed: " .. SafeNumberText(count))
    end

    local order = {}
    local byCategory = {}

    for _, entry in ipairs(entries) do
        if type(entry) == "table" and entry.completed == true then
            local category = CompletedAchievementCategoryName(entry)

            if not byCategory[category] then
                byCategory[category] = {}
                table.insert(order, category)
            end

            table.insert(byCategory[category], CompactAchievementText(entry))
        end
    end

    for _, category in ipairs(order) do
        AddJoinedList(lines, category, byCategory[category])
    end

    if data.truncated == true then
        AddLine(lines, string.format("(List stops at %s entries.)", SafeNumberText(data.maxEntries)))
    end

    AddBlankLine(lines)
end

local function IsPlaceholderLine(line)
    return type(line) == "string" and line:match("^%[No .*%]$") ~= nil
end

local function IsSubHeaderLine(line)
    return type(line) == "string" and line:match("^== .+ ==$") ~= nil
end

local function CompactSectionLines(lines, first)
    local last = #lines
    local kept = {}

    for index = first, last do
        if not IsPlaceholderLine(lines[index]) then
            table.insert(kept, lines[index])
        end
    end

    for index = last, first, -1 do
        lines[index] = nil
    end

    local withHeaders = {}

    for index, line in ipairs(kept) do
        local nextLine = kept[index + 1]
        local isEmptySubHeader = IsSubHeaderLine(line)
            and (nextLine == nil or nextLine == "" or IsSubHeaderLine(nextLine))

        if not isEmptySubHeader then
            table.insert(withHeaders, line)
        end
    end

    local contentLines = 0

    for index, line in ipairs(withHeaders) do
        local previous = lines[#lines]
        local isExtraBlank = line == "" and (#lines < first or previous == "")

        if not isExtraBlank then
            table.insert(lines, line)

            if index > 1 and line ~= "" then
                contentLines = contentLines + 1
            end
        end
    end

    if contentLines == 0 and #lines >= first then
        table.insert(lines, first + 1, "None recorded.")
    end

    if lines[#lines] ~= "" then
        table.insert(lines, "")
    end
end

local function CountCharacters(lines, first, last)
    local total = 0

    for index = first, last do
        total = total + #(lines[index] or "") + 1
    end

    return total
end

function TextFormatter:GetLastStats()
    return self.lastStats
end

function TextFormatter.EstimateTokens(characters)
    local count = U.ToSafeNumber(characters) or 0
    return math.ceil(count / (C.CHARACTERS_PER_TOKEN or 4))
end

function TextFormatter:Build(
    selectedSections,
    exportData
)
    local lines = {}
    local addedAny =
        false
    local sectionSizes = {}
    local compact = not IsDetailedExport()

    self.lastStats = nil

    exportData =
        exportData
        or {}

    local handlers = {
        [C.SECTIONS.LOCATION] =
            function()
                self:AddLocation(
                    lines,
                    exportData.location
                    or {}
                )
            end,

        [C.SECTIONS.CHARACTER_STATS] =
            function()
                self:AddCharacterStats(
                    lines,
                    exportData.character_stats
                    or {}
                )
            end,

        [C.SECTIONS.CURRENCIES] =
            function()
                self:AddCurrencies(
                    lines,
                    exportData.currencies
                    or {}
                )
            end,

        [C.SECTIONS.COLLECTIONS] =
            function()
                self:AddCollections(
                    lines,
                    exportData.collections
                    or {}
                )
            end,

        [C.SECTIONS.BAGS] =
            function()
                self:AddBags(
                    lines,
                    exportData.bags
                    or {}
                )
            end,

        [C.SECTIONS.BANK] =
            function()
                self:AddBank(
                    lines,
                    exportData.bank
                    or {}
                )
            end,

        [C.SECTIONS.EQUIPMENT] =
            function()
                self:AddEquipment(
                    lines,
                    exportData.equipment
                    or {}
                )
            end,

        [C.SECTIONS.LOCKOUTS] =
            function()
                self:AddLockouts(
                    lines,
                    exportData.lockouts
                    or {}
                )
            end,

        [C.SECTIONS.PROGRESS] =
            function()
                self:AddProgress(
                    lines,
                    exportData.progress
                    or {}
                )
            end,

        [C.SECTIONS.KILLS] =
            function()
                self:AddKills(
                    lines,
                    exportData.kills
                    or {}
                )
            end,

        [C.SECTIONS.SESSIONS] =
            function()
                self:AddSessions(
                    lines,
                    exportData.sessions
                    or {}
                )
            end,

        [C.SECTIONS.SHOPPING] =
            function()
                self:AddShopping(
                    lines,
                    exportData.shopping
                    or {}
                )
            end,

        [C.SECTIONS.STATISTICS] =
            function()
                self:AddStatistics(
                    lines,
                    exportData.statistics
                    or {}
                )
            end,

        [C.SECTIONS.ACHIEVEMENTS] =
            function()
                self:AddAchievements(
                    lines,
                    exportData.achievements
                    or {}
                )
            end,

        [C.SECTIONS.COMPLETED_ACHIEVEMENTS] =
            function()
                self:AddCompletedAchievements(
                    lines,
                    exportData.completed_achievements
                    or {}
                )
            end,

        [C.SECTIONS.COLLECTED_APPEARANCES] =
            function()
                self:AddCollectedAppearances(
                    lines,
                    exportData.collected_appearances
                    or {}
                )
            end,

        [C.SECTIONS.APPEARANCES] =
            function()
                self:AddAppearances(
                    lines,
                    exportData.appearances
                    or {}
                )
            end,

        [C.SECTIONS.REPUTATIONS] =
            function()
                self:AddReputations(
                    lines,
                    exportData.reputations
                    or {}
                )
            end,

        [C.SECTIONS.QUESTS] =
            function()
                self:AddQuests(
                    lines,
                    exportData.quests
                    or {}
                )
            end,

        [C.SECTIONS.COMPLETED_QUESTS] =
            function()
                self:AddCompletedQuests(
                    lines,
                    exportData.completed_quests
                    or {}
                )
            end,

        [C.SECTIONS.SKILLS] =
            function()
                self:AddSkills(
                    lines,
                    exportData.skills
                    or {}
                )
            end,

        [C.SECTIONS.PROFESSION_DETAILS] =
            function()
                self:AddProfessionDetails(
                    lines,
                    exportData.profession_details
                    or {}
                )
            end,

        [C.SECTIONS.TALENTS] =
            function()
                self:AddTalents(
                    lines,
                    exportData.talents
                    or {}
                )
            end,

        [C.SECTIONS.SPELLBOOK] =
            function()
                self:AddSpellbook(
                    lines,
                    exportData.spellbook
                    or {}
                )
            end,

        [C.SECTIONS.BIOGRAPHY] =
            function()
                self:AddBiography(
                    lines,
                    exportData.biography
                    or {}
                )
            end,

        [C.SECTIONS.COMPANIONS] =
            function()
                self:AddCompanions(
                    lines,
                    exportData.companions
                    or {}
                )
            end,

        [C.SECTIONS.ADDONS] =
            function()
                self:AddAddons(
                    lines,
                    exportData.addons
                    or {}
                )
            end,
    }

    for _, sectionKey
        in ipairs(
            C.SECTION_ORDER
        )
    do
        if U.IsSelected(
            selectedSections,
            sectionKey
        )
            and handlers[
                sectionKey
            ]
        then
            local first = #lines + 1

            handlers[
                sectionKey
            ]()

            if compact and #lines >= first then
                CompactSectionLines(lines, first)
            end

            table.insert(sectionSizes, {
                key = sectionKey,
                title = C.SECTION_LABELS[sectionKey] or sectionKey,
                characters = CountCharacters(lines, first, #lines),
            })

            addedAny =
                true
        end
    end

    if not addedAny then
        return
            C.TEXT.NOTHING_SELECTED
    end

    table.insert(
        lines,
        1,
        ""
    )

    table.insert(
        lines,
        1,
        string.format(
            "Exported By: %s %s",
            C.ADDON_TITLE,
            C.VERSION
        )
    )

    while #lines > 0
        and lines[#lines] == ""
    do
        table.remove(
            lines,
            #lines
        )
    end

    local output =
        U.JoinLines(
            lines
        )

    if output == "" then
        return
            C.TEXT.NOTHING_TO_EXPORT
    end

    for _, size in ipairs(sectionSizes) do
        size.tokens = TextFormatter.EstimateTokens(size.characters)
    end

    table.sort(sectionSizes, function(left, right)
        return left.characters > right.characters
    end)

    self.lastStats = {
        characters = #output,
        tokens = TextFormatter.EstimateTokens(#output),
        detailed = not compact,
        sections = sectionSizes,
        selections = selectedSections,
    }

    return output
end

ns:RegisterModule(
    "Formatters.TextFormatter",
    TextFormatter
)

ns.Formatters =
    ns.Formatters
    or {}

ns.Formatters.TextFormatter =
    TextFormatter