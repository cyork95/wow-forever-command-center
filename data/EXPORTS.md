# Addon exports

The site reads roster identity from `characters.json`. Live character numbers, hunt rows, and task checks come from the Google Sheet. `stats.json` and `checklist.json` are the fallback when that sheet does not load. Checkboxes are columns on the sheet, one per character. They are not stored in the browser. Checks saved in a browser before the sheet were left behind.

Drop exports in `data/exports/`. JSON is the easiest shape. A SavedVariables `.lua` dump is fine too. Name the file with the character and the date, for example `skyrinis-2026-11-04.json`. Paste that JSON into the sheet Import tab (cell B2, then **Command center → Parse import**) to update the live page. Committing `stats.json` only refreshes the fallback.

```json
{
  "character": "Skyrinis Starhollow",
  "exportedAt": "2026-11-04T18:00:00-04:00",
  "addon": "AddonName",
  "level": 18,
  "zone": "Westfall",
  "subzone": "Sentinel Hill",
  "goldCopper": 1250,
  "health": 420,
  "power": 180,
  "powerType": "Mana",
  "playedSeconds": 3600,
  "stats": {
    "Strength": 25,
    "Agility": 40,
    "Stamina": 30,
    "Intellect": 20,
    "Spirit": 22,
    "Armor": 400,
    "Attack Power": 80,
    "Spell Power": 0,
    "Melee Crit": "4%",
    "Hit": "0%"
  },
  "professions": [
    { "name": "Mining", "current": 45, "max": 75 },
    { "name": "Herbalism", "current": 30, "max": 75 }
  ],
  "gear": [
    { "slot": "Main Hand", "name": "Smite's Mighty Hammer", "itemLevel": 22, "quality": "Rare" }
  ],
  "owned": ["Prairie Chicken", "First Mate Band"],
  "statistics": {
    "Kills": [{ "name": "Total kills", "value": "128" }],
    "Quests": [{ "name": "Quests completed", "value": "42" }],
    "Deaths": [{ "name": "Total deaths", "value": "3" }]
  }
}
```

`character` must match a name in `characters.json`, or the JSON can be the whole `stats.json` map (`characters` keyed by roster id). `owned` marks checklist rows whose name matches. `statistics` is the character window's statistics tab, grouped however you like. New hunts are rows on the sheet Hunts tab. `checklist.json` stays the fallback, so add the hunt there too when the offline copy should match. The in-game `/dossier` report is text. `parseImport` accepts this JSON, not that text.

`scripts/scan-addons.ps1` also reads addon saves under `WTF` and adds these fields to each character in `stats.json`:

- `items`: item names from Syndicator (bags, bank, mail, worn). Hunts with a matching name check themselves.
- `recipes`: known recipes by profession from Profession Master. Recipe hunts check themselves once learned. Its skill levels raise `professions[].current`.
- `collections`: AllTheThings counts for mounts, pets, toys, titles, and achievements. `playedSeconds` comes from AllTheThings too.
- `statistics.Character` and `statistics.Kills`: deaths, quests, areas explored, lockouts, and KillDex kill counts. Other groups you add stay.
- `completedQuests`: quest ids Questie has marked finished. `data/quests.json` has the name, level, and zone for each id. Names QuestieDB does not know are filled from a CharacterExport `Resolved Quests` list when one is on disk. The quests still in the log are not in the save.
- `huntKills`: KillDex kills for each mob named in a hunt's `mobs` list. The hunt shows them as kills logged.
- `looted`: hunt items, and dungeon-journal drops, that KillDex saw drop for this character. A matching hunt checks itself, and the dungeon row shows the drop in hand, even after the item is sold or used.
- `sources`: each addon and the time its save was written. Nova Instance Tracker's level and gold win when its save is newer than `exportedAt`.

Dossier's Biography lives in `biography/<id>.json`, one file per roster character. The scan copies every event from the character's `Dossier.lua` save (`AIExport.lua` before the 2.0.0 rename) and keeps the ones already in the file, so nothing drops out:

```json
{
  "character": "Flann Anvilhew",
  "updated": "2026-09-29T21:40:00",
  "count": 2,
  "events": [
    { "t": 1790000000, "at": "2026-09-21T10:13:20", "kind": "level", "text": "Reached level 12 in Westfall", "zone": "Westfall", "level": 12 },
    { "t": 1790000100, "at": "2026-09-21T10:15:00", "kind": "quest", "text": "Turned in The Defias Brotherhood", "zone": "Westfall", "questID": 155 }
  ]
}
```

`kind` is one of `login`, `level`, `death`, `zone`, `quest`, `achievement`, `boss`, `profession`, or `screenshot`. Screenshots taken by Dossier's Screenshotter also carry `reason`, such as `"Reached level 12"`.

Screenshots live in `screenshots.json`, one entry per file in the game's `Screenshots` folder:

```json
{
  "source": "WoWScrnShot_092426_184911.jpg",
  "takenAt": "2026-09-24T18:49:11",
  "who": "Flann Anvilhew",
  "caption": "Father Gavin offers Rime's Wrath.",
  "file": "assets/shots/flann/2026-09-24_1849_Flann-Anvilhew_father-gavin-offers-rime-s-wrath.jpg",
  "archive": "Dossier/2026-09-24_1849_Flann-Anvilhew_father-gavin-offers-rime-s-wrath.jpg"
}
```

The scan fills `source` and `takenAt`. It fills `who` from a matching Biography screenshot event, and `caption` from that event's `reason`. Set anything still empty by hand or through the nightly skill. Once `who` is known, the scan names the copies `YYYY-MM-DD_HHMM_Character-Name_reason`, with the reason taken from `caption`. `file` is the 1280px site copy, written when `who` matches a roster character. `archive` is a full-size copy under the game's `Screenshots` folder. The game's original `source` file is never renamed.
