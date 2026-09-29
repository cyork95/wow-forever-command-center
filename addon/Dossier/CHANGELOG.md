# Changelog

## 2.0.0

- AIExport is now **Dossier**. The addon folder, the window, the minimap button, and the export header ("Exported By: Dossier") use the new name. Type `/dossier`; `/aixport` still works.
- Saved data moves from `AIExport.lua` to `Dossier.lua` in each character's SavedVariables folder. Copy it over once before Dossier runs, or your Biography, kills, and settings start empty. The README's "Coming from AIExport" section shows how.
- If AIExport is still loaded, Dossier prints a reminder in chat to turn it off, so kills and screenshots are not recorded twice.
- The Session tab lists **Previous sessions** by date and time, with how long each lasted, the zone, kills, gathering, gold, and XP.
- The session panel title no longer runs under the Lock and close buttons. Before the first kill or loot it shows just the timer.
- Remove the old `AIExport` folder from `Interface\AddOns` and restart the game after updating.

## 1.7.0

- New **Session** tab, which replaces Gathering. A timer starts by itself with your first kill, loot, gold, or XP and tracks kills, items gathered by type, gold, and XP, each per hour, plus the time to your next level. **Pause**, **Start**, and **Reset** control it, and Reset saves the session in your last 20. Open it with `/aixport session`.
- Gathering counts herbs, ore and stone, leather, cloth, cooking and fish, elemental, enchanting, and jewelcrafting materials, reagents, holiday items, and consumables. Each type has a switch under **Count as gathered**; quest items are off at first. Mailbox and guild bank items and money are not counted.
- The live kill panel is now the session panel. It shows the timer, kills, gathering, gold, XP, and your last creatures, with a switch for each line. Left-click its title to pause or start, right-click to reset, and point at it for every item gathered with its hourly rate. Its options moved from the Kills tab to the Session tab.
- A `/reload` keeps the session going. After more than 10 minutes logged out, the old session is saved and a new one starts.
- New **Sessions** export section in the Story card, on by default: the current session with hourly rates, lifetime gathering by type, and your last 10 sessions.
- The tabs are in a new order: Export, Biography, Kills, Session, Screenshotter, Companions, Help.
- The game needs a full restart after updating, because new files were added.

## 1.6.0

- New **Screenshotter** tab, which replaces Memento. It takes a screenshot on level-ups, deaths, achievements, dungeon and raid boss kills, the end of battlegrounds and arenas, finished duels, and new mounts, pets, toys, and recipes. Login and timed screenshots (every 5 to 60 minutes) are there too, off at first. Each moment has its own switch, and **Take screenshots automatically** turns it all off or on.
- Options to hide the interface for the shot (skipped in combat), add a name, level, and date stamp, play a camera sound, and print a chat line. Two moments within 3 seconds share one screenshot.
- **Take test screenshot** and `/aixport shot` take one right away. `/aixport shots` opens the tab.
- While Memento is loaded, the Screenshotter pauses and the tab says so, so you never get two screenshots of the same moment. When the Screenshotter is on and Memento is not loaded, the Companions tab shows Memento as "Built into AIExport".
- Biography screenshot lines now say why the shot was taken, for example "Screenshot: Reached level 12, in Westfall".
- The tabs are in a new order: Export, Biography, Kills, Screenshotter, Companions, Help.
- The game needs a full restart after updating, because new files were added.

## 1.5.0

- New **Statistics** export section in the Progress card, on by default. It copies the Statistics tab of the Achievements window, such as deaths, gold acquired, and quests completed, grouped by category. Statistics with no value yet are left out. **Detailed export** lists one statistic per line with its ID.
- The game needs a full restart after updating, because a new file was added.

## 1.4.0

- AIExport now tracks kills itself. It counts every creature you or your pet finish off, skips creatures another player tagged first, and adds the loot and gold you take to that creature. Dungeon and raid trash is not counted, because the game hides it there.
- New **Kills** tab with search, sorting by most kills, name, or most recent, and each creature's drops and gold. Open it with `/aixport kills`.
- New live kill panel with this session's kills, kills per hour, and the last 10 creatures killed. Turn it on from the Kills tab, with `/aixport panel`, or by right-clicking the minimap button. It can be moved and locked, and remembers where it was. A **Panel background** slider on the Kills tab sets how see-through its background is, from clear to solid.
- Creature tooltips show "Killed 12 times". The Kills tab has a switch to turn that off.
- New **Kills** export section in the Progress card: total kills, kills by creature type, your top 25 creatures, items seen dropping, and gold looted.
- Your KillDex history is copied in once, so earlier kills carry over. Once AIExport has kills of its own, the Companions tab shows KillDex as "Built into AIExport" and leaves its block out of the export.
- The game needs a full restart after updating, because new files were added.

## 1.3.1

- The Export tab lists saved data that is missing or more than a week old, such as "Bank not saved yet. Open your bank once." or "Blacksmithing not saved yet. Open its window once." The Bank and Profession Details boxes get a "!" until it is fixed, and the list updates as soon as you close the bank or a profession window. The export window repeats it as "Missing: ...".
- When AIExport has no saved copy, Bank uses Syndicator's copy and Profession Details uses Profession Master's recipes, each labeled with where it came from.
- Smaller Location, Currencies, Reputations, Achievements, Appearances, Quests, and Talents sections. Quests are one line each and keep their IDs. **Detailed export** still shows the full format.
- The Biography login line waits for the real zone instead of writing "an unknown zone" or a continent name, which also stops the extra "Entered ..." line after every login.
- The game needs a full restart after updating, because a new file was added.

## 1.3.0

- Exports are much smaller. Item, spell, quest, and appearance IDs are gone. Equipment is one line per slot. Bag and bank stacks are merged. Lists such as completed quests, spells, and collected appearances are joined per line. Profession details list learned recipes by difficulty color, name recipes you can learn now, and count the rest. Lines that only say nothing was returned are dropped.
- The export window shows an approximate token count, colored by size, and the three largest sections. The Export tab shows the size of the last export.
- New option under Help: **Detailed export** brings back the full format with IDs.
- "Verbose item types" is now called "Item stats in bags and bank".
- The Biography records boss kills. Memento boss kills use those names from then on.
- The Profession Master, Syndicator, and Talents Forever blocks now find the character when the game reports only the first name.
- AIExport is listed under **Data Export** in the AddOn list.
- The Create Export button text is sharper.

## 1.2.0

- New look: one dark window with the AIExport logo in the header and Export, Companions, Biography, and Help tabs. Export sections are grouped into cards.
- New logo and minimap icon.
- Added Companions: optional export blocks for Syndicator, KillDex, AllTheThings, Nova Instance Tracker, Profession Master, Auctionator, Memento, and Talents Forever. Each shows whether it is loaded and can be switched off. AIExport still works with none of them.
- Added a Companions section to the export, on by default.
- The Biography now records every screenshot the game saves.
- `/aixport help` opens the Help tab. Added `/aixport companions`.
- The export window uses the new look and shows a "Ctrl+C to copy" hint.
- The game needs a full restart after updating, because new files were added.

## 1.1.0

- Renamed the addon to AIExport. The only slash command is `/aixport`.
- Added the Biography: a saved timeline of logins, level-ups, deaths, new zones, quest turn-ins, achievements, and profession skill-ups. Nothing is deleted.
- Added the Biography window (`/aixport bio`), 40 lines per page with Older and Newer.
- Every export now starts with `Exported By: AIExport 1.1.0` and includes a Biography section with every stored event.
- Added the in-game guide (`/aixport help` or the How to use button) with an example AI skill.
- Added `AIExport_Camelot.toc` for the World of Warcraft Forever client.
- Settings saved by earlier builds under another name do not carry over. Section choices and the minimap position start from defaults once, and the bank cache fills again the next time you open your bank.
