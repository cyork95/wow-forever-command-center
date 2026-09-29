# Changelog

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
