# Forever Command Center

GitHub Pages tracker for CoYo's World of Warcraft: Forever house.

Pick a character and the page shows that character's race, spec, professions, talent notes, and any stats merged from an addon export. The hunt list is a set of checkboxes. Checks stay in the browser. Download them if you want a backup.

## Update the site

- New hunt: add a row to `data/checklist.json`. Give it (or a piece) `"mobs": ["Boss Name"]` when the drop source is known, and the hunt shows KillDex kill counts for those mobs.
- Names, specs, professions: edit `data/characters.json`.
- Addon dump: put JSON or a SavedVariables file in `data/exports/`, using the shape in `data/EXPORTS.md`. The live numbers on the page come from `data/stats.json` after that dump is merged.
- Nightly: type `/cexport` in game, copy the text, and paste it into Cursor. The `nightly-export` skill saves it as `exports/beta/<first>-<last>-YYYY-MM-DD.txt`, runs the scan below, and opens a PR.
- Installed addons and a fresh CharacterExport merge: copy `scripts/addons.example.json` to `scripts/addons.local.json`, set `addonsPath` to your `Interface\AddOns` folder, then run `powershell -File scripts/scan-addons.ps1`. Commit `data/addons.json` and any updated `data/stats.json`. The scan also reads the Syndicator, Profession Master, AllTheThings, Nova Instance Tracker, and KillDex saves, so bag items, recipes, kills, and quests reach the sheet without their in-game export buttons. Log out or `/reload` first so the saves are written.
- Dungeons: when Forever Dungeon Journal is installed, the scan copies its bosses, drops, and quests into `data/dungeons.json` for the Dungeons tab. That data ships inside the addon, so it refreshes when the addon updates. Hunts whose item appears in the journal show which boss drops it.
- Screenshots: the scan logs new Memento screenshots in `data/screenshots.json`. Set `who` and `caption` on each one (the nightly skill does this by reading the name over the player's head), then run the scan again. Roster characters' shots are copied to `assets/shots/<id>/` and show in their card.

The older roster page, farm workbook, and dashboard snapshot stay in the repo as source notes.
