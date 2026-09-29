local _, ns = ...

local U = ns.utils
local C = ns.constants

local Spellbook = {}

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

local function GetActiveSpecializationName()
    if not C_SpecializationInfo
        or type(
            C_SpecializationInfo.GetSpecialization
        ) ~= "function"
        or type(
            C_SpecializationInfo.GetSpecializationInfo
        ) ~= "function"
    then
        return nil
    end

    local success,
        specializationIndex =
        SafeCall(
            C_SpecializationInfo.GetSpecialization
        )

    if not success
        or specializationIndex == nil
    then
        return nil
    end

    local infoSuccess,
        _,
        name =
        SafeCall(
            C_SpecializationInfo.GetSpecializationInfo,
            specializationIndex
        )

    if infoSuccess
        and U.IsNonEmptyString(name)
    then
        return name
    end

    return nil
end

local function GetPlayerSpellBank()
    if Enum
        and type(
            Enum.SpellBookSpellBank
        ) == "table"
        and Enum.SpellBookSpellBank.Player
            ~= nil
    then
        return
            Enum.SpellBookSpellBank.Player
    end

    return 0
end

local function GetSkillLineIndex(
    key,
    fallback
)
    if Enum
        and type(
            Enum.SpellBookSkillLineIndex
        ) == "table"
    then
        local value =
            U.ToSafeNumber(
                Enum.SpellBookSkillLineIndex[
                    key
                ]
            )

        if value ~= nil then
            return value
        end
    end

    return fallback
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
        local success, name =
            SafeCall(
                C_Spell.GetSpellName,
                spellID
            )

        if success
            and U.IsNonEmptyString(name)
        then
            return name
        end
    end

    if C_Spell
        and type(
            C_Spell.GetSpellInfo
        ) == "function"
    then
        local success, info =
            SafeCall(
                C_Spell.GetSpellInfo,
                spellID
            )

        if success
            and type(info) == "table"
            and U.IsNonEmptyString(
                info.name
            )
        then
            return info.name
        end
    end

    return nil
end

local function GetSpellBookItemInfo(
    slotIndex,
    spellBank
)
    if not C_SpellBook
        or type(
            C_SpellBook.GetSpellBookItemInfo
        ) ~= "function"
    then
        return nil
    end

    local success, info =
        SafeCall(
            C_SpellBook.GetSpellBookItemInfo,
            slotIndex,
            spellBank
        )

    if success
        and type(info) == "table"
    then
        return info
    end

    return nil
end

local function GetSpellBookItemType(
    slotIndex,
    spellBank
)
    if not C_SpellBook
        or type(
            C_SpellBook.GetSpellBookItemType
        ) ~= "function"
    then
        return nil, nil, nil
    end

    local success,
        itemType,
        actionID,
        spellID =
        SafeCall(
            C_SpellBook.GetSpellBookItemType,
            slotIndex,
            spellBank
        )

    if not success then
        return nil, nil, nil
    end

    return
        itemType,
        U.ToSafeNumber(
            actionID
        ),
        U.ToSafeNumber(
            spellID
        )
end

local function GetSpellBookItemName(
    slotIndex,
    spellBank
)
    if not C_SpellBook
        or type(
            C_SpellBook.GetSpellBookItemName
        ) ~= "function"
    then
        return nil
    end

    local success, name =
        SafeCall(
            C_SpellBook.GetSpellBookItemName,
            slotIndex,
            spellBank
        )

    if success
        and U.IsNonEmptyString(name)
    then
        return name
    end

    return nil
end

local function GetSpellBookItemLink(
    slotIndex,
    spellBank
)
    if not C_SpellBook
        or type(
            C_SpellBook.GetSpellBookItemLink
        ) ~= "function"
    then
        return nil
    end

    local success, link =
        SafeCall(
            C_SpellBook.GetSpellBookItemLink,
            slotIndex,
            spellBank
        )

    if success
        and U.IsNonEmptyString(link)
    then
        return link
    end

    return nil
end

local function GetSpellBookItemLevelLearned(
    slotIndex,
    spellBank
)
    if not C_SpellBook
        or type(
            C_SpellBook.GetSpellBookItemLevelLearned
        ) ~= "function"
    then
        return nil
    end

    local success, level =
        SafeCall(
            C_SpellBook.GetSpellBookItemLevelLearned,
            slotIndex,
            spellBank
        )

    if success then
        return
            U.ToSafeNumber(
                level
            )
    end

    return nil
end

local function GetBooleanFromSpellBookItemAPI(
    fn,
    slotIndex,
    spellBank
)
    if type(fn) ~= "function" then
        return nil
    end

    local success, value =
        SafeCall(
            fn,
            slotIndex,
            spellBank
        )

    if success
        and type(value) == "boolean"
    then
        return value
    end

    return nil
end

local function GetSpellKnown(
    spellID,
    spellBank
)
    spellID =
        U.ToSafeNumber(
            spellID
        )

    if spellID == nil
        or not C_SpellBook
        or type(
            C_SpellBook.IsSpellKnown
        ) ~= "function"
    then
        return nil
    end

    local success, known =
        SafeCall(
            C_SpellBook.IsSpellKnown,
            spellID,
            spellBank
        )

    if success
        and type(known) == "boolean"
    then
        return known
    end

    return nil
end

local function GetSpellBookItemUsable(
    slotIndex,
    spellBank
)
    if not C_SpellBook
        or type(
            C_SpellBook.IsSpellBookItemUsable
        ) ~= "function"
    then
        return nil, nil
    end

    local success,
        usable,
        insufficientPower =
        SafeCall(
            C_SpellBook.IsSpellBookItemUsable,
            slotIndex,
            spellBank
        )

    if not success then
        return nil, nil
    end

    if type(usable) ~= "boolean" then
        usable = nil
    end

    if type(insufficientPower)
        ~= "boolean"
    then
        insufficientPower =
            nil
    end

    return
        usable,
        insufficientPower
end

local function GetSectionKey(
    skillLineIndex
)
    local generalIndex =
        GetSkillLineIndex(
            "General",
            1
        )

    local classIndex =
        GetSkillLineIndex(
            "Class",
            2
        )

    local mainSpecIndex =
        GetSkillLineIndex(
            "MainSpec",
            3
        )

    if skillLineIndex == generalIndex then
        return "general"
    end

    if skillLineIndex == classIndex then
        return "class"
    end

    if skillLineIndex == mainSpecIndex then
        return "spec"
    end

    return nil
end

local function MakeOtherSectionKey(
    skillLineName,
    skillLineIndex
)
    if U.IsNonEmptyString(
        skillLineName
    )
    then
        return
            "other:"
            .. tostring(
                skillLineIndex
            )
            .. ":"
            .. skillLineName
    end

    return
        "other:"
        .. tostring(
            skillLineIndex
            or "unknown"
        )
end

local function GetOrCreateSection(
    sections,
    sectionOrder,
    skillLineInfo,
    skillLineIndex
)
    local skillLineName =
        U.IsNonEmptyString(
            skillLineInfo.name
        )
        and skillLineInfo.name
        or nil

    local sectionKey =
        GetSectionKey(
            skillLineIndex
        )

    if sectionKey then
        local section =
            sections[
                sectionKey
            ]

        section.skillLineName =
            skillLineName

        section.skillLineIndex =
            skillLineIndex

        section.specID =
            U.ToSafeNumber(
                skillLineInfo.specID
            )

        section.offSpecID =
            U.ToSafeNumber(
                skillLineInfo.offSpecID
            )

        section.isOffSpec =
            skillLineInfo.offSpecID
                ~= nil

        section.isActiveSpecSection =
            section.isOffSpec
                ~= true

        return section
    end

    sectionKey =
        MakeOtherSectionKey(
            skillLineName,
            skillLineIndex
        )

    if not sections[
        sectionKey
    ]
    then
        local title =
            skillLineName
            or "Other"

        local isOffSpec =
            skillLineInfo.offSpecID
                ~= nil

        sections[
            sectionKey
        ] = {
            key =
                sectionKey,

            title =
                title,

            skillLineName =
                skillLineName,

            skillLineIndex =
                skillLineIndex,

            specID =
                U.ToSafeNumber(
                    skillLineInfo.specID
                ),

            offSpecID =
                U.ToSafeNumber(
                    skillLineInfo.offSpecID
                ),

            isOffSpec =
                isOffSpec,

            isActiveSpecSection =
                not isOffSpec,

            spells =
                {},
        }

        U.SafeInsert(
            sectionOrder,
            {
                key =
                    sectionKey,

                title =
                    title,
            }
        )
    end

    return
        sections[
            sectionKey
        ]
end

local function AddSpell(
    section,
    spell,
    seen
)
    if type(section) ~= "table"
        or type(spell) ~= "table"
        or not U.IsNonEmptyString(
            spell.name
        )
    then
        return false
    end

    local spellID =
        U.ToSafeNumber(
            spell.spellID
        )

    local key

    if spellID ~= nil then
        key =
            "id:"
            .. tostring(
                spellID
            )
    else
        key =
            "name:"
            .. spell.name
            .. ":passive:"
            .. tostring(
                spell.isPassive == true
            )
    end

    if seen[key] then
        return false
    end

    seen[key] =
        true

    U.SafeInsert(
        section.spells,
        spell
    )

    return true
end

local function ResolveItemOffSpec(
    itemInfo,
    slotIndex,
    spellBank,
    skillLineInfo
)
    if type(itemInfo) == "table"
        and type(itemInfo.isOffSpec)
            == "boolean"
    then
        return itemInfo.isOffSpec
    end

    local apiValue =
        GetBooleanFromSpellBookItemAPI(
            C_SpellBook
                and C_SpellBook.IsSpellBookItemOffSpec,
            slotIndex,
            spellBank
        )

    if type(apiValue) == "boolean" then
        return apiValue
    end

    if type(skillLineInfo) == "table"
        and skillLineInfo.offSpecID
            ~= nil
    then
        return true
    end

    return false
end

local function BuildSpellEntry(
    slotIndex,
    spellBank,
    skillLineInfo,
    section
)
    local itemInfo =
        GetSpellBookItemInfo(
            slotIndex,
            spellBank
        )

    local itemType,
        actionID,
        spellID =
        GetSpellBookItemType(
            slotIndex,
            spellBank
        )

    if type(itemInfo) == "table" then
        actionID =
            actionID
            or U.ToSafeNumber(
                itemInfo.actionID
            )

        spellID =
            spellID
            or U.ToSafeNumber(
                itemInfo.spellID
            )

        itemType =
            itemType
            or itemInfo.itemType
    end

    local name =
        GetSpellBookItemName(
            slotIndex,
            spellBank
        )

    if not name
        and type(itemInfo) == "table"
        and U.IsNonEmptyString(
            itemInfo.name
        )
    then
        name =
            itemInfo.name
    end

    if not name then
        name =
            GetSpellName(
                spellID
                or actionID
            )
    end

    if not name then
        return nil
    end

    local usable,
        insufficientPower =
        GetSpellBookItemUsable(
            slotIndex,
            spellBank
        )

    local isPassive =
        GetBooleanFromSpellBookItemAPI(
            C_SpellBook
                and C_SpellBook.IsSpellBookItemPassive,
            slotIndex,
            spellBank
        )

    if isPassive == nil
        and type(itemInfo) == "table"
        and type(itemInfo.isPassive)
            == "boolean"
    then
        isPassive =
            itemInfo.isPassive
    end

    local isOffSpec =
        ResolveItemOffSpec(
            itemInfo,
            slotIndex,
            spellBank,
            skillLineInfo
        )

    local entry = {
        name =
            name,

        spellID =
            spellID,

        actionID =
            actionID,

        itemType =
            itemType,

        slotIndex =
            slotIndex,

        link =
            GetSpellBookItemLink(
                slotIndex,
                spellBank
            ),

        levelLearned =
            GetSpellBookItemLevelLearned(
                slotIndex,
                spellBank
            ),

        sourceSkillLineName =
            skillLineInfo.name,

        sourceSkillLineIndex =
            section.skillLineIndex,

        sourceSectionKey =
            section.key,

        skillLineName =
            skillLineInfo.name,

        specID =
            U.ToSafeNumber(
                skillLineInfo.specID
            ),

        offSpecID =
            U.ToSafeNumber(
                skillLineInfo.offSpecID
            ),

        isPassive =
            isPassive,

        isKnown =
            GetSpellKnown(
                spellID
                or actionID,
                spellBank
            ),

        isUsable =
            usable,

        insufficientPower =
            insufficientPower,

        isOffSpec =
            isOffSpec,

        isActiveSpecSection =
            isOffSpec ~= true,
    }

    if C_SpellBook then
        entry.isClassTalent =
            GetBooleanFromSpellBookItemAPI(
                C_SpellBook.IsClassTalentSpellBookItem,
                slotIndex,
                spellBank
            )

        entry.isPvPTalent =
            GetBooleanFromSpellBookItemAPI(
                C_SpellBook.IsPvPTalentSpellBookItem,
                slotIndex,
                spellBank
            )

        entry.isHelpful =
            GetBooleanFromSpellBookItemAPI(
                C_SpellBook.IsSpellBookItemHelpful,
                slotIndex,
                spellBank
            )

        entry.isHarmful =
            GetBooleanFromSpellBookItemAPI(
                C_SpellBook.IsSpellBookItemHarmful,
                slotIndex,
                spellBank
            )
    end

    return entry
end

local function CollectSkillLine(
    section,
    skillLineInfo,
    spellBank,
    seen
)
    local offset =
        U.ToSafeNumber(
            skillLineInfo.itemIndexOffset
        )
        or 0

    local count =
        U.ToSafeNumber(
            skillLineInfo.numSpellBookItems
        )
        or 0

    local added =
        0

    for itemOffset = 1,
        count
    do
        local slotIndex =
            offset
            + itemOffset

        local entry =
            BuildSpellEntry(
                slotIndex,
                spellBank,
                skillLineInfo,
                section
            )

        if entry
            and AddSpell(
                section,
                entry,
                seen
            )
        then
            added =
                added + 1
        end
    end

    return added
end

local function SortSections(
    sections
)
    for _, section
        in pairs(
            sections
        )
    do
        if type(section) == "table"
            and type(section.spells)
                == "table"
        then
            table.sort(
                section.spells,
                function(left, right)
                    local leftName =
                        string.lower(
                            left.name
                            or ""
                        )

                    local rightName =
                        string.lower(
                            right.name
                            or ""
                        )

                    if leftName
                        ~= rightName
                    then
                        return
                            leftName
                            < rightName
                    end

                    return
                        (
                            U.ToSafeNumber(
                                left.spellID
                            )
                            or 0
                        )
                        <
                        (
                            U.ToSafeNumber(
                                right.spellID
                            )
                            or 0
                        )
                end
            )
        end
    end
end

function Spellbook:Collect()
    local diagnostics = {}

    local sections = {
        general = {
            key =
                "general",

            title =
                "General",

            isActiveSpecSection =
                true,

            isOffSpec =
                false,

            spells =
                {},
        },

        class = {
            key =
                "class",

            title =
                "Class",

            isActiveSpecSection =
                true,

            isOffSpec =
                false,

            spells =
                {},
        },

        spec = {
            key =
                "spec",

            title =
                "Spec",

            isActiveSpecSection =
                true,

            isOffSpec =
                false,

            spells =
                {},
        },
    }

    local sectionOrder = {
        {
            key =
                "general",

            title =
                "General",
        },

        {
            key =
                "class",

            title =
                "Class",
        },

        {
            key =
                "spec",

            title =
                "Spec",
        },
    }

    if type(C_SpellBook)
        ~= "table"
    then
        AddDiagnostic(
            diagnostics,
            "C_SpellBook API unavailable."
        )

        return {
            key =
                C.SECTIONS.SPELLBOOK,

            title =
                C.SECTION_LABELS[
                    C.SECTIONS.SPELLBOOK
                ],

            sections =
                sections,

            sectionOrder =
                sectionOrder,

            diagnostics =
                diagnostics,
        }
    end

    if type(
        C_SpellBook.GetNumSpellBookSkillLines
    ) ~= "function"
        or type(
            C_SpellBook.GetSpellBookSkillLineInfo
        ) ~= "function"
    then
        AddDiagnostic(
            diagnostics,
            "C_SpellBook skill-line APIs unavailable."
        )

        return {
            key =
                C.SECTIONS.SPELLBOOK,

            title =
                C.SECTION_LABELS[
                    C.SECTIONS.SPELLBOOK
                ],

            sections =
                sections,

            sectionOrder =
                sectionOrder,

            diagnostics =
                diagnostics,
        }
    end

    local spellBank =
        GetPlayerSpellBank()

    local className =
        GetPlayerClassName()

    local specializationName =
        GetActiveSpecializationName()

    local countSuccess,
        rawSkillLineCount =
        SafeCall(
            C_SpellBook.GetNumSpellBookSkillLines
        )

    local skillLineCount =
        countSuccess
        and U.ToSafeNumber(
            rawSkillLineCount
        )
        or 0

    local totalSpells =
        0

    local validSkillLines =
        0

    local offSpecSkillLines =
        0

    local seenBySection =
        {}

    for skillLineIndex = 1,
        skillLineCount
    do
        local success,
            skillLineInfo =
            SafeCall(
                C_SpellBook.GetSpellBookSkillLineInfo,
                skillLineIndex
            )

        if success
            and type(skillLineInfo)
                == "table"
        then
            validSkillLines =
                validSkillLines + 1

            if skillLineInfo.offSpecID
                ~= nil
            then
                offSpecSkillLines =
                    offSpecSkillLines + 1
            end

            local section =
                GetOrCreateSection(
                    sections,
                    sectionOrder,
                    skillLineInfo,
                    skillLineIndex
                )

            if section then
                if not seenBySection[
                    section.key
                ]
                then
                    seenBySection[
                        section.key
                    ] = {}
                end

                totalSpells =
                    totalSpells
                    + CollectSkillLine(
                        section,
                        skillLineInfo,
                        spellBank,
                        seenBySection[
                            section.key
                        ]
                    )
            end
        end
    end

    SortSections(
        sections
    )

    AddDiagnostic(
        diagnostics,
        string.format(
            "Spellbook skill lines: %d",
            validSkillLines
        )
    )

    AddDiagnostic(
        diagnostics,
        string.format(
            "Off-spec skill lines: %d",
            offSpecSkillLines
        )
    )

    AddDiagnostic(
        diagnostics,
        string.format(
            "Spellbook spells exported: %d",
            totalSpells
        )
    )

    if sections.class
        and U.IsNonEmptyString(
            sections.class.skillLineName
        )
    then
        AddDiagnostic(
            diagnostics,
            "Class skill line: "
                .. sections.class.skillLineName
        )
    end

    if sections.spec
        and U.IsNonEmptyString(
            sections.spec.skillLineName
        )
    then
        AddDiagnostic(
            diagnostics,
            "Main spec skill line: "
                .. sections.spec.skillLineName
        )
    end

    if totalSpells == 0 then
        AddDiagnostic(
            diagnostics,
            "No player spellbook entries were returned."
        )
    end

    return {
        key =
            C.SECTIONS.SPELLBOOK,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.SPELLBOOK
            ],

        className =
            className,

        specializationName =
            specializationName,

        sections =
            sections,

        sectionOrder =
            sectionOrder,

        diagnostics =
            diagnostics,
    }
end

ns:RegisterModule(
    "Data.Spellbook",
    Spellbook
)

ns.Data = ns.Data or {}
ns.Data.Spellbook =
    Spellbook