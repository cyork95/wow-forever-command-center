local _, ns = ...

local C = ns.constants

local Guide = {}

local GUIDE_TEXT = [[
AIExport turns your character into a text report you can paste into an AI chat
(Cursor, ChatGPT, Claude, Gemini, or any other assistant). Everything in the
report comes from the game and from AIExport itself. No other addon is needed.

Press Copy guide below to open this text in a window where Ctrl+A and Ctrl+C
copy it.


1. Make an export
-----------------
1. Type /aixport, or left-click the AIExport minimap button.
2. On the Export tab, tick the sections you want. Select All is a good start.
3. Press Create Export. The text is already selected.
4. Press Ctrl+C, then paste it into your AI chat with Ctrl+V.

Open your bank and each profession window at least once per session. The game
only lets addons read those while they are open, so AIExport keeps the last
copy it saw and marks it as cached. The Export tab lists anything not saved
yet, or saved more than a week ago, and marks those sections with "!". Until
then, AIExport uses Syndicator's bank copy and Profession Master's recipes if
those addons are loaded.

The window has four tabs:
- Export: the sections, grouped into cards, and the Create Export button
- Companions: the optional addons AIExport can read, each with its own switch
- Biography: your timeline, 40 lines per page
- Help: this guide and the options


2. Commands
-----------
/aixport             Open the AIExport window
/aixport bio         Open the Biography tab
/aixport companions  Open the Companions tab
/aixport help        Open this guide


3. What the report contains
---------------------------
The report starts with "Exported By: AIExport" and then one block per section:

- Location: zone, subzone, map, coordinates, hearthstone
- Character Stats: name-realm, level, race, class, XP, health, stats, ratings
- Currencies, Collections, Reputations
- Bags, Bank (saved copy), Equipment with item level and stats
- Lockouts, Progress, Achievements, Appearances
- Quests in your log and completed quests
- Skills, Profession Details (saved copy), Talents, Spellbook
- Biography: the timeline described below
- Companions: data from the optional addons described below
- AddOns: every installed addon and whether it loaded

Sections you leave unticked are not in the report.

The report is kept short so it costs fewer tokens in your AI chat. The
export window shows about how many tokens it uses and which sections are
largest. Untick sections you do not need if your AI chat cuts the text off.
Tick Detailed export under Help to get item, spell, and quest IDs back; the
report is then several times larger.


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
- Every boss you defeat, with the difficulty
- Learning a profession, and each rise in profession skill
- Every screenshot the game saves, with the place it was taken. This works
  for screenshots you take yourself and ones Memento takes for you.

Nothing is deleted. The Biography tab shows 40 lines per page. Use Older
and Newer to move through the rest. The Biography section of an export
always contains every event, not just the page on screen.

The game saves the full log when you log out or type /reload, in:
World of Warcraft\_classic_beta_\WTF\Account\<account>\<realm>\<character>\SavedVariables\AIExport.lua

AIExport only knows what happened after it was installed. Earlier play is
not in the timeline.


5. Companions
-------------
AIExport never needs another addon. When one of these is loaded, AIExport can
read what it has saved for this character and add it to the Companions
section of the export:

- Syndicator: your mail, and your bank contents even while the bank is closed
- KillDex: total kills, creature types, your top 15 creatures, and items seen
  dropping
- AllTheThings: deaths, quests, areas explored, time played, and mount, pet,
  toy, and title counts
- Nova Instance Tracker: your saved lockouts and recent instance runs
- Profession Master: every recipe you know, grouped by profession
- Auctionator: the auction price of each stack in your bags, plus a total
- Memento: the boss kills it recorded
- Talents Forever: your planned talent build and saved builds for your class

Each one is optional. The Companions tab shows whether each addon is loaded,
installed but not loaded, or not installed, with a switch to leave it out.
Switches are on by default and only work while that addon is loaded. Untick
Companions on the Export tab to leave out all of them at once.

If a companion addon changes how it saves data, its block says it could not
be read instead of breaking the export.


6. Tips for the AI chat
-----------------------
- Paste one character per message. Each report has one "Character:" line.
- Tell the assistant what you want first: a leveling plan, a gear check,
  a profession route, a session recap, or a story of your character.
- Paste a new export each session. The Biography shows what changed.
- The report contains your character name, realm, and gold. Only paste it
  where you are comfortable sharing that.


7. Example AI skill
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
- Do not invent data. If a section is missing or says "unavailable",
  "cached", or "Saved copy from", say so instead of guessing.

## Save it

If you can write files, save the paste unchanged as
exports/<name>-<realm>-YYYY-MM-DD.txt using today's date. Add -2, -3 if the
file exists. Keep older files; they are the history.

## Read it

- Level, zone, gold, and XP come from "Character Stats:" and "Location:".
- Gear is under "Equipment:", one line per slot with item level, quality,
  and stats.
- Professions are under "Skills:" and "Profession Details:". Learned
  recipes are grouped by difficulty color: Orange and Yellow still give
  skill-ups, Green rarely, Grey never.
- The "Biography:" section is a dated timeline. Each line is
  "HH:MM event". Use it to see what happened since the last report:
  levels gained, deaths, new zones, quests turned in, profession gains.
- "Companions:" holds optional blocks such as "== KillDex ==" or
  "== Syndicator ==". They only appear when the player has those addons.

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
