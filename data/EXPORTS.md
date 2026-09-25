# Addon exports

The site reads `characters.json`, `checklist.json`, and `stats.json`. Checkboxes stay in the browser. Character stats, gear, gold, and profession skill stay in `stats.json`, which gets replaced when an export comes in.

Drop exports in `data/exports/`. JSON is the easiest shape. A SavedVariables `.lua` dump is fine too. Name the file with the character and the date, for example `skyrinis-2026-11-04.json`.

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

`character` must match a name in `characters.json`. `owned` marks checklist rows whose name matches.

`scripts/scan-addons.ps1` also reads addon saves under `WTF` and adds these fields to each character in `stats.json`:

- `items`: item names from Syndicator (bags, bank, mail, worn). Hunts with a matching name check themselves.
- `recipes`: known recipes by profession from Profession Master. Recipe hunts check themselves once learned. Its skill levels raise `professions[].current`.
- `collections`: AllTheThings counts for mounts, pets, toys, titles, and achievements. `playedSeconds` comes from AllTheThings too.
- `statistics.Character` and `statistics.Kills`: deaths, quests, areas explored, lockouts, and KillDex kill counts. Other groups you add stay.
- `sources`: each addon and the time its save was written. Nova Instance Tracker's level and gold win when its save is newer than `exportedAt`. `statistics` is the character window's statistics tab, grouped however you like. New hunts still get added to `checklist.json` by hand so the board stays the source of truth.
