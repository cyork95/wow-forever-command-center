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

The window has seven tabs:
- Export: the sections, grouped into cards, and the Create Export button
- Biography: your timeline, 40 lines per page
- Kills: every creature you have killed, with drops and gold
- Session: a timer with this session's kills, gathering, gold, and XP
- Screenshotter: automatic screenshots at big moments, like Memento
- Companions: the optional addons AIExport can read, each with its own switch
- Help: this guide and the options


2. Commands
-----------
/aixport             Open the AIExport window
/aixport bio         Open the Biography tab
/aixport kills       Open the Kills tab
/aixport session     Open the Session tab
/aixport panel       Show or hide the live session panel
/aixport shots       Open the Screenshotter tab
/aixport shot        Take a screenshot now
/aixport companions  Open the Companions tab
/aixport help        Open this guide

Right-click the minimap button to show or hide the live session panel.


3. What the report contains
---------------------------
The report starts with "Exported By: AIExport" and then one block per section:

- Location: zone, subzone, map, coordinates, hearthstone
- Character Stats: name-realm, level, race, class, XP, health, stats, ratings
- Currencies, Collections, Reputations
- Bags, Bank (saved copy), Equipment with item level and stats
- Lockouts, Progress, Achievements, Appearances
- Kills: total kills, kills by creature type, your top 25 creatures, items
  seen dropping, and gold looted
- Sessions: this session's time, kills, gathering, gold, and XP with
  hourly rates, everything you have ever gathered by type, and your last
  10 sessions
- Statistics: the numbers from the Statistics tab of the Achievements
  window, such as deaths, gold acquired, and quests completed. Only
  statistics with a value are listed, grouped by category.
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
  for screenshots you take yourself and ones the Screenshotter or Memento
  takes for you. Screenshotter shots also say why they were taken, for
  example "Screenshot: Reached level 12, in Westfall".

Nothing is deleted. The Biography tab shows 40 lines per page. Use Older
and Newer to move through the rest. The Biography section of an export
always contains every event, not just the page on screen.

The game saves the full log when you log out or type /reload, in:
World of Warcraft\_classic_beta_\WTF\Account\<account>\<realm>\<character>\SavedVariables\AIExport.lua

AIExport only knows what happened after it was installed. Earlier play is
not in the timeline.


5. Kills
--------
AIExport counts every creature you or your pet finish off. A creature
another player tagged first is not counted. Inside dungeons and raids the
game hides which creature died, so only bosses are recorded there, in the
Biography.

Loot you pick up and gold you loot are added to the creature you took them
from.

The Kills tab lists every creature with its kills, level, zone, and when
you last killed one. Search by name, sort by most kills, name, or most
recent, and click a creature to see its drops and gold. Tick "Kill count
on creature tooltips" to add "Killed 12 times" when you point at a
creature you have killed before. The live panel is on the Session tab.

If KillDex was installed, AIExport copies its kill history once, the
first time it loads, so your earlier kills carry over. After that KillDex
is no longer needed.


6. Session
----------
A session is one stretch of play. Its timer starts by itself with your
first kill, loot, gold, or XP, so Gathering is no longer needed. It
tracks:

- Kills, and kills per hour
- Items gathered: herbs, ore and stone, leather, cloth, cooking and fish,
  elemental, enchanting, and jewelcrafting materials, reagents, holiday
  items, and consumables. Untick a type under "Count as gathered" to stop
  counting it. Quest items are off at first.
- Gold gained or spent, and XP, each with an hourly rate
- How long until your next level at this pace

Press Pause to stop the clock and Start to go on. Press Reset to end the
session: it is saved in your last 20 sessions and a new one begins.
Money from the mailbox or guild bank is not counted as earned. A /reload
keeps the session going. If you log out for more than 10 minutes, the old
session is saved and a new one starts next time.

Tick "Show the session panel" for a small window with the timer, kills,
gathering, gold, XP, and your last creatures. Choose which lines it shows,
drag it anywhere, and press Lock to keep it in place. The Panel background
slider sets its background from fully clear (0%) to solid (100%).
Left-click the panel title to pause or start, and right-click it to reset.
Point at the title to see every item gathered with its hourly rate.

Everything you gather is also kept for good, by item. The Sessions section
of an export lists those totals and your last 10 sessions.


7. Screenshotter
----------------
The Screenshotter takes a screenshot for you at big moments, so Memento is
no longer needed. Tick "Take screenshots automatically" to turn it on or
off. Then tick the moments you want:

- Level up, death, achievement earned
- Dungeon or raid boss killed
- Battleground or arena ends, duel finished
- New mount, pet, toy, or recipe
- Login (off at first)
- Every few minutes (off at first). Drag the slider to pick 5 to 60
  minutes.

Two moments that happen within 3 seconds, such as a level-up that also
earns an achievement, share one screenshot. The options are:

- Hide the interface: hides your action bars and windows for the shot.
  This is skipped in combat, when the game does not allow it.
- Add a name and date stamp: while the interface is hidden, a small label
  shows your name, realm, level, and the date.
- Camera sound, and a chat message for each screenshot.

Press Take test screenshot, or type /aixport shot, to take one right away.
This works even when the automatic screenshots are off.

While Memento is loaded, the Screenshotter pauses so you do not get two
screenshots of everything. The tab says so. Disable Memento in the AddOns
list to let AIExport take over.

Screenshots are saved in World of Warcraft\_classic_beta_\Screenshots with
the game's usual names. Each one is noted in the Biography with the reason,
so a website or tool that reads the Biography can name and caption them.


8. Companions
-------------
AIExport never needs another addon. When one of these is loaded, AIExport can
read what it has saved for this character and add it to the Companions
section of the export:

- Syndicator: your mail, and your bank contents even while the bank is closed
- KillDex: total kills, creature types, your top 15 creatures, and items seen
  dropping. Once AIExport has kills of its own, the Companions tab shows
  KillDex as "Built into AIExport" and leaves its block out.
- AllTheThings: deaths, quests, areas explored, time played, and mount, pet,
  toy, and title counts
- Nova Instance Tracker: your saved lockouts and recent instance runs
- Profession Master: every recipe you know, grouped by profession
- Auctionator: the auction price of each stack in your bags, plus a total
- Memento: the boss kills it recorded. While the Screenshotter is on and
  Memento is not loaded, the Companions tab shows Memento as "Built into
  AIExport". Boss kills are in the Biography either way.
- Talents Forever: your planned talent build and saved builds for your class

Each one is optional. The Companions tab shows whether each addon is loaded,
installed but not loaded, or not installed, with a switch to leave it out.
Switches are on by default and only work while that addon is loaded. Untick
Companions on the Export tab to leave out all of them at once.

If a companion addon changes how it saves data, its block says it could not
be read instead of breaking the export.


9. Tips for the AI chat
-----------------------
- Paste one character per message. Each report has one "Character:" line.
- Tell the assistant what you want first: a leveling plan, a gear check,
  a profession route, a session recap, or a story of your character.
- Paste a new export each session. The Biography shows what changed.
- The report contains your character name, realm, and gold. Only paste it
  where you are comfortable sharing that.


10. Example AI skill
--------------------
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
- "Kills:" lists total kills, kills by creature type, the most-killed
  creatures, and items seen dropping.
- "Sessions:" starts with "This session:", the current play session with
  hourly rates. "== Gathered ==" lists lifetime gathering by type, and
  "== Recent sessions ==" has one dated line per past session.
- "Statistics:" holds the game's own lifetime counters, one "== Category =="
  block each. A statistic that is not listed has no value yet.
- "Companions:" holds optional blocks such as "== Syndicator ==". They
  only appear when the player has those addons.

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
