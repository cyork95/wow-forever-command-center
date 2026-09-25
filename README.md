# Forever Command Center

GitHub Pages tracker for CoYo's World of Warcraft: Forever house.

Pick a character and the page shows that character's race, spec, professions, talent notes, and any stats merged from an addon export. The hunt list is a set of checkboxes. Checks stay in the browser. Download them if you want a backup.

## Update the site

- New hunt: add a row to `data/checklist.json`.
- Names, specs, professions: edit `data/characters.json`.
- Addon dump: put JSON or a SavedVariables file in `data/exports/`, using the shape in `data/EXPORTS.md`. The live numbers on the page come from `data/stats.json` after that dump is merged.
- Installed addons and a fresh CharacterExport merge: copy `scripts/addons.example.json` to `scripts/addons.local.json`, set `addonsPath` to your `Interface\AddOns` folder, then run `powershell -File scripts/scan-addons.ps1`. Commit `data/addons.json` and any updated `data/stats.json`.

The older roster page, farm workbook, and dashboard snapshot stay in the repo as source notes.
