local _, ns = ...

local U = ns.utils
local C = ns.constants

local Skills = {}

local WEAPON_SKILL_IDS = {
    [43] = true,   -- Swords
    [44] = true,   -- Axes
    [45] = true,   -- Bows
    [46] = true,   -- Guns
    [54] = true,   -- Maces
    [55] = true,   -- Two-Handed Swords
    [136] = true,  -- Staves
    [160] = true,  -- Two-Handed Maces
    [162] = true,  -- Fist Weapons / Unarmed
    [172] = true,  -- Two-Handed Axes
    [173] = true,  -- Daggers
    [176] = true,  -- Thrown
    [226] = true,  -- Crossbows
    [228] = true,  -- Wands
    [229] = true,  -- Polearms
    [3014] = true, -- Feral Combat
}

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

local function AddGroup(
    groupsByName,
    orderedGroups,
    name
)
    if not U.IsNonEmptyString(name) then
        return nil
    end

    local existing =
        groupsByName[name]

    if existing then
        return existing
    end

    local group = {
        name = name,
        entries = {},
    }

    groupsByName[name] =
        group

    U.SafeInsert(
        orderedGroups,
        group
    )

    return group
end

local function AddProfessionEntry(
    group,
    professionIndex,
    fallbackName,
    diagnostics
)
    professionIndex =
        U.ToSafeNumber(
            professionIndex
        )

    if professionIndex == nil
        or type(group) ~= "table"
    then
        return
    end

    if type(GetProfessionInfo)
        ~= "function"
    then
        AddDiagnostic(
            diagnostics,
            "GetProfessionInfo API unavailable."
        )

        return
    end

    local success,
        name,
        icon,
        rank,
        maxRank,
        numAbilities,
        spellOffset,
        skillLineID,
        skillModifier,
        specializationIndex,
        specializationOffset,
        skillLineName =
        SafeCall(
            GetProfessionInfo,
            professionIndex
        )

    if not success then
        AddDiagnostic(
            diagnostics,
            string.format(
                "GetProfessionInfo failed for profession index %d.",
                professionIndex
            )
        )

        return
    end

    if not U.IsNonEmptyString(name) then
        name =
            fallbackName
    end

    if not U.IsNonEmptyString(name) then
        return
    end

    local entry = {
        name =
            name,

        icon =
            icon,

        rank =
            U.ToSafeNumber(
                rank
            ),

        maxRank =
            U.ToSafeNumber(
                maxRank
            ),

        modifier =
            U.ToSafeNumber(
                skillModifier
            ),

        skillLineID =
            U.ToSafeNumber(
                skillLineID
            ),

        skillLineName =
            U.IsNonEmptyString(
                skillLineName
            )
            and skillLineName
            or nil,

        spellOffset =
            U.ToSafeNumber(
                spellOffset
            ),

        numSpells =
            U.ToSafeNumber(
                numAbilities
            ),

        specializationIndex =
            U.ToSafeNumber(
                specializationIndex
            ),

        specializationOffset =
            U.ToSafeNumber(
                specializationOffset
            ),

        professionIndex =
            professionIndex,
    }

    U.SafeInsert(
        group.entries,
        entry
    )
end

local function RemoveEmptyGroups(
    groups
)
    for index = #groups,
        1,
        -1
    do
        local group =
            groups[index]

        if type(group) ~= "table"
            or type(group.entries)
                ~= "table"
            or #group.entries == 0
        then
            table.remove(
                groups,
                index
            )
        end
    end
end

local function CollectProfessions(
    diagnostics
)
    local groupsByName = {}
    local groups = {}

    if type(GetProfessions)
        ~= "function"
    then
        AddDiagnostic(
            diagnostics,
            "GetProfessions API unavailable."
        )

        return groups
    end

    if type(GetProfessionInfo)
        ~= "function"
    then
        AddDiagnostic(
            diagnostics,
            "GetProfessionInfo API unavailable."
        )

        return groups
    end

    local success,
        profession1,
        profession2,
        archaeology,
        fishing,
        cooking =
        SafeCall(
            GetProfessions
        )

    if not success then
        AddDiagnostic(
            diagnostics,
            "GetProfessions call failed."
        )

        return groups
    end

    local professionGroup =
        AddGroup(
            groupsByName,
            groups,
            C.SKILL_CATEGORY_LABELS.PROFESSIONS
        )

    AddProfessionEntry(
        professionGroup,
        profession1,
        nil,
        diagnostics
    )

    AddProfessionEntry(
        professionGroup,
        profession2,
        nil,
        diagnostics
    )

    local secondaryGroup =
        AddGroup(
            groupsByName,
            groups,
            C.SKILL_CATEGORY_LABELS.SECONDARY
        )

    AddProfessionEntry(
        secondaryGroup,
        archaeology,
        PROFESSIONS_ARCHAEOLOGY,
        diagnostics
    )

    AddProfessionEntry(
        secondaryGroup,
        fishing,
        PROFESSIONS_FISHING,
        diagnostics
    )

    AddProfessionEntry(
        secondaryGroup,
        cooking,
        PROFESSIONS_COOKING,
        diagnostics
    )

    RemoveEmptyGroups(
        groups
    )

    return groups
end

local function CollectWeaponSkills(
    groups,
    diagnostics
)
    if type(groups) ~= "table" then
        return 0
    end

    if type(C_SkillInfo)
        ~= "table"
        or type(
            C_SkillInfo.GetNumSkillLines
        ) ~= "function"
        or type(
            C_SkillInfo.GetSkillLineInfo
        ) ~= "function"
    then
        AddDiagnostic(
            diagnostics,
            "C_SkillInfo weapon skill APIs unavailable."
        )

        return 0
    end

    local success,
        rawSkillLineCount =
        SafeCall(
            C_SkillInfo.GetNumSkillLines
        )

    local skillLineCount =
        success
        and U.ToSafeNumber(
            rawSkillLineCount
        )
        or nil

    if skillLineCount == nil then
        AddDiagnostic(
            diagnostics,
            "C_SkillInfo.GetNumSkillLines call failed."
        )

        return 0
    end

    local weaponGroup = {
        name =
            C.SKILL_CATEGORY_LABELS.WEAPON,

        entries =
            {},
    }

    local seen = {}

    for index = 1,
        skillLineCount
    do
        local infoSuccess,
            skillInfo =
            SafeCall(
                C_SkillInfo.GetSkillLineInfo,
                index
            )

        if infoSuccess
            and type(skillInfo)
                == "table"
            and skillInfo.isHeader
                ~= true
        then
            local skillID =
                U.ToSafeNumber(
                    skillInfo.skillID
                )

            local parentSkillLineID =
                U.ToSafeNumber(
                    skillInfo.parentSkillLineID
                )
                or 0

            if skillID ~= nil
                and WEAPON_SKILL_IDS[
                    skillID
                ]
                and parentSkillLineID == 0
                and not seen[
                    skillID
                ]
            then
                seen[skillID] =
                    true

                local name =
                    U.IsNonEmptyString(
                        skillInfo.name
                    )
                    and skillInfo.name
                    or (
                        "Weapon Skill "
                        .. tostring(
                            skillID
                        )
                    )

                U.SafeInsert(
                    weaponGroup.entries,
                    {
                        name =
                            name,

                        rank =
                            U.ToSafeNumber(
                                skillInfo.rank
                            ),

                        maxRank =
                            U.ToSafeNumber(
                                skillInfo.maxRank
                            ),

                        modifier =
                            U.ToSafeNumber(
                                skillInfo.modifier
                            ),

                        tempPoints =
                            U.ToSafeNumber(
                                skillInfo.tempPoints
                            ),

                        skillLineID =
                            skillID,

                        skillLineCategoryID =
                            U.ToSafeNumber(
                                skillInfo.skillLineCategoryID
                            ),

                        parentSkillLineID =
                            parentSkillLineID,
                    }
                )
            end
        end
    end

    table.sort(
        weaponGroup.entries,
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

            if leftName ~= rightName then
                return
                    leftName
                    < rightName
            end

            return
                (
                    U.ToSafeNumber(
                        left.skillLineID
                    )
                    or 0
                )
                <
                (
                    U.ToSafeNumber(
                        right.skillLineID
                    )
                    or 0
                )
        end
    )

    if #weaponGroup.entries > 0 then
        U.SafeInsert(
            groups,
            weaponGroup
        )
    end

    return
        #weaponGroup.entries
end

function Skills:Collect()
    local diagnostics = {}

    local groups =
        CollectProfessions(
            diagnostics
        )

    local professionEntryCount = 0

    for _, group
        in ipairs(groups)
    do
        if type(group.entries)
            == "table"
        then
            professionEntryCount =
                professionEntryCount
                + #group.entries
        end
    end

    local weaponSkillCount =
        CollectWeaponSkills(
            groups,
            diagnostics
        )

    U.SafeInsert(
        diagnostics,
        string.format(
            "Skill groups: %d",
            #groups
        )
    )

    U.SafeInsert(
        diagnostics,
        string.format(
            "Profession entries: %d",
            professionEntryCount
        )
    )

    U.SafeInsert(
        diagnostics,
        string.format(
            "Weapon skill entries: %d",
            weaponSkillCount
        )
    )

    if professionEntryCount == 0
        and weaponSkillCount == 0
    then
        AddDiagnostic(
            diagnostics,
            "No profession, secondary, or weapon skill entries returned."
        )
    end

    return {
        key =
            C.SECTIONS.SKILLS,

        title =
            C.SECTION_LABELS[
                C.SECTIONS.SKILLS
            ],

        groups =
            groups,

        diagnostics =
            diagnostics,
    }
end

ns:RegisterModule(
    "Data.Skills",
    Skills
)

ns.Data = ns.Data or {}
ns.Data.Skills = Skills