Roster Doc = names, specs, professions, trees, house rules only.
Farm Sheet = every hunt. New X posts go here first.
Command Center HTML = dashboard snapshot. Refresh it when hunts change.
Do not dump news into the Roster Doc.
Keep Alliance house: Starhollow elves, Blackwell, Emberkeg, Xorr pairings.
Beta: never take Skyrinis, Sorinis, or Malavus.

The live hunt list, task checks, and character snapshots are the Google Sheet. `data/checklist.json` and `data/stats.json` are the fallback when that sheet does not load. Setup is `scripts/sheets/SCHEMA.md`. New hunts go on the Hunts tab, and into `data/checklist.json` when the fallback should match. Checks saved in the browser before the sheet were not copied over.
