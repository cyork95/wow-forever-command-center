# Changelog

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
