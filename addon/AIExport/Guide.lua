local _, ns = ...

local C = ns.constants

local Guide = {}

local GUIDE_TEXT = [[
AIExport turns your character into a text report you can paste into an AI chat
(Cursor, ChatGPT, Claude, Gemini, or any other assistant). Everything in the
report comes from the game and from AIExport itself. No other addon is needed.

Select all of this text with Ctrl+A and copy it with Ctrl+C to keep it.


1. Make an export
-----------------
1. Type /aixport, or left-click the AIExport minimap button.
2. Tick the sections you want. Select All is a good start.
3. Press Create Export. The text is already selected.
4. Press Ctrl+C, then paste it into your AI chat with Ctrl+V.

Open your bank and each profession window at least once per session. The game
only lets addons read those while they are open, so AIExport keeps the last
copy it saw and marks it as cached.


2. Commands
-----------
/aixport         Open the export window
/aixport bio     Open the Biography timeline
/aixport help    Show this guide


3. What the report contains
---------------------------
The report starts with "Exported By: AIExport" and then one block per section:

- Location: zone, subzone, map, coordinates, hearthstone
- Character Stats: name-realm, level, race, class, XP, health, stats, ratings
- Currencies, Collections, Reputations
- Bags, Bank (cached), Equipment with item level and stats
- Lockouts, Progress, Achievements, Appearances
- Quests in your log and completed quests
- Skills, Profession Details (cached), Talents, Spellbook
- Biography: the timeline described below
- AddOns: every installed addon and whether it loaded

Sections you leave unticked are not in the report.


4. Biography
------------
From the moment AIExport is installed it writes down what happens to the
character it is loaded on:

- Logging in, when your level or zone changed since the last session
- Every level-up, with the zone
- Every death, with the subzone and zone
- The first time you enter each zone in a session
- Every quest you turn in, by name
- Every achievement you earn
- Learning a profession, and each rise in profession skill

Nothing is deleted. The Biography window shows 40 lines per page. Use Older
and Newer to move through the rest. The Biography section of an export
always contains every event, not just the page on screen.

The game saves the full log when you log out or type /reload, in:
World of Warcraft\_classic_beta_\WTF\Account\<account>\<realm>\<character>\SavedVariables\AIExport.lua

AIExport only knows what happened after it was installed. Earlier play is
not in the timeline.


5. Tips for the AI chat
-----------------------
- Paste one character per message. Each report has one "Character:" line.
- Tell the assistant what you want first: a leveling plan, a gear check,
  a profession route, a session recap, or a story of your character.
- Paste a new export each session. The Biography shows what changed.
- The report contains your character name, realm, and gold. Only paste it
  where you are comfortable sharing that.


6. Example AI skill
-------------------
Some assistants, such as Cursor, can load a saved instruction file called a
skill. Save the text between the lines below as SKILL.md in a folder named
aiexport, for example .cursor/skills/aiexport/SKILL.md in your project, or
paste it at the start of a chat in any other assistant.

-------------------------------- SKILL.md --------------------------------
---
name: aiexport
description: Reads a pasted AIExport character report from World of Warcraft Forever. Use when the user pastes text that starts with "Exported By: AIExport" or contains "Character:" and "Biography:" lines.
---

# AIExport report

The user pastes a text report made in game with /aixport.

## Check the paste

- It must contain a "Character: Name-Realm" line. If it does not, ask the
  user to run /aixport, press Create Export, and paste the whole text.
- One report is one character. If there are two "Exported By: AIExport"
  lines, treat each block as its own character.
- Do not invent data. If a section is missing or says "unavailable" or
  "cached", say so instead of guessing.

## Save it

If you can write files, save the paste unchanged as
exports/<name>-<realm>-YYYY-MM-DD.txt using today's date. Add -2, -3 if the
file exists. Keep older files; they are the history.

## Read it

- Level, zone, gold, and XP come from "Character Stats:" and "Location:".
- Gear is under "Equipment:" with item level per slot.
- Professions are under "Skills:" and "Profession Details:".
- The "Biography:" section is a dated timeline. Each line is
  "HH:MM event". Use it to see what happened since the last report:
  levels gained, deaths, new zones, quests turned in, profession gains.

## Answer

Start with a short recap of the session from the Biography, then answer
what the user asked. Name real quests, zones, and items from the report.
Keep advice to things the character can do at its current level.
------------------------------ end SKILL.md ------------------------------
]]

function Guide:GetText()
    local title =
        string.format(
            "%s %s - How to use",
            C.ADDON_TITLE,
            C.VERSION
        )

    return
        title
        .. "\n"
        .. string.rep(
            "=",
            #title
        )
        .. "\n\n"
        .. GUIDE_TEXT
end

ns:RegisterModule(
    "Guide",
    Guide
)

ns.Guide = Guide
