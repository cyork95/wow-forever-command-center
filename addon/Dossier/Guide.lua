local _, ns = ...

local C = ns.constants

local Guide = {}

local GUIDE_TEXT = [[
Dossier turns your character into a text report you can paste into an AI chat
(Cursor, ChatGPT, Claude, Gemini, or any other assistant). Everything in the
report comes from the game and from Dossier itself. No other addon is needed.

Dossier was called AIExport before version 2.0. /aixport still works.

Press Copy guide below to open this text in a window where Ctrl+A and Ctrl+C
copy it.


1. Make an export
-----------------
1. Type /dossier, or left-click the Dossier minimap button.
2. On the Export tab, tick the sections you want. Select All is a good start.
3. Press Create Export. The text is already selected.
4. Press Ctrl+C, then paste it into your AI chat with Ctrl+V.

Open your bank and each profession window at least once per session. The game
only lets addons read those while they are open, so Dossier keeps the last
copy it saw and marks it as cached. The Export tab lists anything not saved
yet, or saved more than a week ago, and marks those sections with "!". Until
then, Dossier uses Syndicator's bank copy and Profession Master's recipes if
those addons are loaded.

The window lists a tab for each part that is switched on:

- Export: the sections, grouped into cards, and the Create Export button
- Biography: your timeline, 40 lines per page
- Kills and Rares: creatures you have killed, and rares with a place and drops
- Session and Sessions: the live timer, then finished sessions for the account
- Ledger, Currencies, and Reputation: gold, currency icons, and reputation bars
- Mail: letters you sent and received. Dossier does not send or take mail
- Professions: each character's skill and rank
- Lockouts: saved instances and a diary of runs
- Shopping: the items and recipes you plan to gather or buy
- Tasks: daily, weekly, and one-time notes, plus a window for this zone
- Quests: every quest the game says this character has completed
- Screenshotter: automatic screenshots at big moments
- Options: the minimap icon, item stats, detailed export, and a switch for
  each part of Dossier
- Help: this guide

A feature you turn off on the Options tab also hides its tab. The same
options are in the game's Settings, under AddOns > Dossier.


2. Commands
-----------
/dossier             Open the Dossier window
/dossier bio         Open the Biography tab
/dossier kills       Open the Kills tab
/dossier session     Open the Session tab
/dossier sessions    Open the live Session tab
/dossier panel       Show or hide the live session panel
/dossier ledger      Open the Ledger tab
/dossier mail        Open the Mail tab
/dossier rares       Open the Rares tab
/dossier lockouts    Open the Lockouts tab
/dossier tasks       Open the Tasks tab and the zone window
/dossier quests      Open completed quests
/dossier shop        Open the Shopping tab
/dossier shots       Open the Screenshotter tab
/dossier shot        Take a screenshot now
/dossier options     Open the Options tab
/dossier settings    Open Dossier's page in the game's Settings
/dossier off kills   Turn a feature off (bio, kills, session, ledger, mail,
                     professions, lockouts, tasks, quests, shop, shots)
/dossier on kills    Turn it back on
/dossier help        Open this guide

Right-click the minimap button to show or hide the live session panel.


3. What the report contains
---------------------------
The report starts with "Exported By: Dossier" and then one block per section:

- Location: zone, subzone, map, coordinates, hearthstone
- Character Stats: name-realm, level, race, class, XP, health, stats, ratings
- Currencies, Collections, Reputations
- Bags, Bank (saved copy), Equipment with item level and stats
- Shopping list: what you are short of, the recipes you plan to craft,
  and what is ready
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
- Session currency, session reputation, gold changes, profession ranks, and rares, when those switches are on
- AddOns: every installed addon and whether it loaded

Sections you leave unticked are not in the report.

The report is kept short so it costs fewer tokens in your AI chat. The
export window shows about how many tokens it uses and which sections are
largest. Untick sections you do not need if your AI chat cuts the text off.
Tick Detailed export on the Options tab to get item, spell, and quest IDs
back; the report is then several times larger.


4. Biography
------------
From the moment Dossier is installed it writes down what happens to the
character it is loaded on:

- Logging in, when your level or zone changed since the last session
- Every level-up, with the zone
- Every death, with the subzone and zone
- The first time you enter each zone in a session
- Every quest you turn in, by name
- Every book, scroll, or plaque you open, by title, with the zone and time.
  The pages themselves are not saved
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
World of Warcraft\_classic_beta_\WTF\Account\<account>\<realm>\<character>\SavedVariables\Dossier.lua

Dossier only knows what happened after it was installed. Earlier play is
not in the timeline.


5. Kills
--------
Dossier counts every creature you or your pet finish off. A creature
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

If KillDex was installed, Dossier copies its kill history once, the
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
Previous sessions on the Session tab lists them by date and time, with
how long each lasted, the zone, and what you got.
Money from the mailbox or guild bank is not counted as earned. A /reload
keeps the session going. If you log out for more than 10 minutes, the old
session is saved and a new one starts next time.

Tick "Show the session panel" for a small window with the timer, kills,
gathering, gold, XP, and your last creatures. Choose which lines it shows,
drag it anywhere, and press Lock to keep it in place. The Panel background
slider sets its background from fully clear (0%) to solid (100%).
Left-click the panel title to pause or start, and right-click it to reset.
Point at the title to see your top 15 items gathered with their hourly rates. The Session tab lists them all.

Everything you gather is also kept for good, by item. The Sessions section
of an export lists those totals and your last 10 sessions.


7. Shopping list
----------------
The Shopping tab keeps a list of what you plan to gather or buy, and counts
what you already have in your bags and bank. It only keeps track. Dossier
never buys anything or moves items for you.

To add something, click the box at the top, then shift-click an item in
your bags, a vendor, or a profession window, and press Enter or Add. You
can also drag an item onto the box, or type its name or item ID.

- An item starts at one stack. Use + and - to change how many you want,
  or hold Shift for 5 at a time. x removes it.
- A recipe you shift-click from a profession window adds its reagents,
  times how many you want to craft. If the game has not shown Dossier the
  reagents yet, the tab asks you to open that profession window once.
  Each time you craft it, the count goes down by one.
- Each line shows what you have against what you need, and "ready" or
  "need 8". Point at a line to see your bags and bank counts and why you
  need it.
- Suggest from bags adds the food and drink you are carrying that is not on the list yet, one stack each.
- Clear finished removes the items you now have enough of.

Tick "Remind me at vendors and on login" for a chat line at login when
you are short of anything, and at a vendor that sells something on your
list. The bank count uses the copy Dossier saved the last time your bank
was open.

If Consumable-Connoisseur is loaded, Dossier copies this character's
restock list once, the first time it loads, into an empty shopping list.
Its auto-buying and bank moving are left out on purpose.


8. Screenshotter
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

Press Take test screenshot, or type /dossier shot, to take one right away.
This works even when the automatic screenshots are off.

While Memento is loaded, the Screenshotter pauses so you do not get two
screenshots of everything. The tab says so. Disable Memento in the AddOns
list to let Dossier take over.

Screenshots are saved in World of Warcraft\_classic_beta_\Screenshots with
the game's usual names. Each one is noted in the Biography with the reason,
so a website or tool that reads the Biography can name and caption them.


9. Ledger, mail, rares, lockouts, tasks, and quests
---------------------------------------------------
Ledger records gold in and out, currency changes, and reputation for the
character you are playing. Currencies and Reputation are part of the same
switch. The lists include your other characters from this account.

Mail stores letters you send and receive. It does not send, take, return,
or open mail for you.

Rares records a rare or rare elite you kill, with the zone, coordinates,
and drops you actually looted. It uses the Kills switch.

Lockouts stores the instances you are saved to and a short diary of runs
you enter and leave. Sessions stores finished play sessions. The live
timer stays on the Session tab.

Tasks are daily, weekly, or one-time notes you write. A quest turn-in or a
matching rare kill can mark one done. /dossier tasks opens a window for
this zone. Quests lists every quest the game says you have completed.

10. Other addons
----------------
Dossier does not need another addon. When Other addons is on, it can read
character data another addon has already saved, such as a bank copy or a
recipe list, and fold that into the normal report. Turning it off stops
those reads. Saved data stays.


11. Options
-----------
The Options tab has two parts. The same options are in the game's Settings,
under AddOns > Dossier (/dossier settings), with an Open Dossier button.

General, saved for each character: show the minimap icon, item stats in
bags and bank, detailed export (item, spell, and quest IDs, much larger),
and a Reload UI button.

Features, for every character on your account: every part of Dossier can be
turned off here, or with /dossier off and /dossier on. The switches are
Biography, Kills, Session, Ledger, Mail, Professions, Lockouts, Tasks, Quests, Shopping list, Screenshotter, and Other addons.

A feature that is off stops recording and running completely. Its tab is
hidden, its section on the Export tab is greyed out with "(off)" and left
out of the report, and its commands say how to turn it back on. Turning
Session off also hides the session panel and saves the current session to
Previous sessions. Turning Other addons off stops Dossier reading any other
addon.

Nothing a feature saved is deleted. Turn it back on and its history is
still there. The switches apply to every character on your account.

The Export tab, its other sections, Help, and Options are always on.


12. Tips for the AI chat
------------------------
- Paste one character per message. Each report has one "Character:" line.
- Tell the assistant what you want first: a leveling plan, a gear check,
  a profession route, a farming route for your shopping list, a session
  recap, or a story of your character.
- Paste a new export each session. The Biography shows what changed.
- The report contains your character name, realm, and gold. Only paste it
  where you are comfortable sharing that.


13. Example AI skill
--------------------
Some assistants, such as Cursor, can load a saved instruction file called a
skill. Save the text between the lines below as SKILL.md in a folder named
dossier, for example .cursor/skills/dossier/SKILL.md in your project, or
paste it at the start of a chat in any other assistant.

-------------------------------- SKILL.md --------------------------------
---
name: dossier
description: Reads a pasted Dossier character report from World of Warcraft Forever. Use when the user pastes text that starts with "Exported By: Dossier" or "Exported By: AIExport" (its old name), or contains "Character:" and "Biography:" lines.
---

# Dossier report

The user pastes a text report made in game with /dossier.

## Check the paste

- It must contain a "Character: Name-Realm" line. If it does not, ask the
  user to run /dossier, press Create Export, and paste the whole text.
- One report is one character. If there are two "Exported By:" lines,
  treat each block as its own character.
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
- "Shopping list:" is what the player plans to gather or buy. Short items
  come first, one line each with what they have and need; "Crafting:"
  lines are recipes they plan to make, and "Ready:" lists what is done.
- "Statistics:" holds the game's own lifetime counters, one "== Category =="
  block each. A statistic that is not listed has no value yet.
- "Session currency:", "Session reputation:", "Gold change:", "Profession:",
  and "Rare:" are the ledger lines, when those switches are on.

## Answer

Start with a short recap of the session from the Biography, then answer
what the user asked. Name real quests, zones, and items from the report.
Keep advice to things the character can do at its current level.
------------------------------ end SKILL.md ------------------------------
]]

function Guide:GetDisplayText()
    local gold = "|cffd4b15a"
    local muted = "|cff8d9aa3"
    local lines = {}

    for line in (self:GetText() .. "\n"):gmatch("(.-)\n") do
        if line:match("^%d+%. ") or line:match("^%d%d%. ") then
            table.insert(lines, gold .. line .. "|r")
        elseif line:match("^-+$") or line:match("^=+$") then
            table.insert(lines, muted .. line .. "|r")
        elseif line:match("^/") then
            table.insert(lines, "|cff7ee0e6" .. line .. "|r")
        else
            table.insert(lines, line)
        end
    end

    return table.concat(lines, "\n")
end

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
