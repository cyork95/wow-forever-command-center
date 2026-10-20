# Canonical JSON (Phase 1)

One local parser fills one canonical file set. The canonical set is
**private and local only**; the site consumes a generated redacted file.
Pages serves committed files directly, so redaction happens at
generation time, never at render time.

## Files

| File | Visibility | Contents |
| --- | --- | --- |
| `data/private/characters.json` | private, gitignored | One record per parsed character: identity, level, location, gold, gear, bags, bank, professions, reputations, quests, kills, sessions, statistics, achievements, talents, spells, biography, lockouts, shopping. |
| `data/private/collections.json` | private, gitignored | Per-character collections (mounts/pets/toys counts and names), collected appearances, completed quest names/count. |
| `data/private/economy.json` | private, gitignored | Per-character `goldCopper` and the raw `Character - Wealth` statistics lines. Full ledger detail joins in Phase 2. |
| `data/characters.public.json` | public, committed | Redacted site input. Roster-matched characters only: roster id, display name, level, race, class, professions with ranks, collection counts, completed quest count, total kills. No gold, no bags, no bank, no mail, no ledger detail, no item locations. |
| `data/characters.json` | public, committed | Hand-kept roster identity (names, specs, professions, trees, house rules). The parser never overwrites it; it uses it to match in-game names to roster ids. |
| `data/catalogs.json` | public, committed | Quest/faction name catalog index. `quests.source` points at `data/quests.json`; `extra` and `factions` are filled only from verified sources. Unresolved IDs are listed, never invented. |

Raw Dossier pastes and any copied SavedVariables live under
`exports/raw/` (gitignored). The parser reads them in place; it never
copies raw game data into a committed path.

## Character record (private)

```json
{
  "id": "flann",
  "name": "Flann",
  "displayName": null,
  "realm": "Classic Beta PvE 2",
  "faction": "Alliance",
  "race": "Dwarf",
  "className": "Shaman",
  "level": 20,
  "xp": { "current": 3529, "max": 23200, "rested": 34800 },
  "itemLevel": { "average": 10.38, "equipped": 10.38, "pvp": 10.38 },
  "health": "480/480",
  "location": { "zone": "...", "map": "...", "coordinates": "74.0, 44.9", "hearthstone": "..." },
  "goldCopper": 22067,
  "currencies": [{ "name": "Honor Points", "raw": "12/25000" }],
  "professions": [{ "name": "Mining", "current": 47, "max": 75, "source": "dossier-export" }],
  "gear": [{ "slot": "Back", "name": "Spiritwraith Drape", "itemLevel": 18, "quality": "Rare" }],
  "bags": [{ "name": "Backpack", "items": ["..."] }],
  "bank": { "note": "", "items": ["..."] },
  "shopping": [],
  "lockouts": { "instanceCount": 0, "lines": [] },
  "reputations": [{ "name": "Stormwind", "standing": "Friendly", "value": 1696, "max": 6000, "source": "dossier-export" }],
  "quests": {
    "current": [{ "name": "...", "level": 17, "status": "ready to turn in", "id": 97914, "zone": "Stormwind City", "objectives": [] }],
    "completedNames": ["..."],
    "completedCount": 172
  },
  "kills": { "total": 1509, "creatures": 101, "goldLootedCopper": 3471, "byType": {}, "top": [] },
  "sessions": [],
  "statistics": { "Quests": ["Quests completed 148"] },
  "achievements": { "completed": 4, "total": 112, "recent": [] },
  "professionDetails": [{ "name": "Mining", "current": 47, "max": 75, "knownByColor": {}, "notLearnedYet": 16 }],
  "talents": { "specialization": "Shaman", "loadout": "Shaman", "importString": "...", "tree": [] },
  "spells": [{ "group": "Class", "names": [] }],
  "biography": [{ "date": "2026-09-29", "time": "15:20", "text": "..." }],
  "addonsLoaded": ["Dossier"],
  "exportedAt": null,
  "sources": { "export": { "file": "...", "addonVersion": "2.2.18", "parsedAt": "..." } }
}
```

Every field that can disagree between sources carries a `source`.
One source per field: Phase 1 is `dossier-export` for everything.
Phase 2 adds Syndicator (inventory/mail/bank/gold), DataStore via
Altoholic (reputations/currencies), AllTheThings, Journalator,
Questie Journey, Rarity — allowlisted, size-capped, and the orphaned
ProfessionMaster/Nova SavedVariables are read-only historical sources,
never required. Chattynator content is out in every phase: variable
names and file size only.

## Public redaction rule

`data/characters.public.json` is generated from the private set by an
allowlist of fields, not a denylist. A field is public only if it is
named in the parser's public projection. Gold, bag/bank contents, mail
and ledger detail have no path into the public file. Characters that
do not match the roster in `data/characters.json` (beta throwaways,
historical exports) are excluded from the public file.

## Mail (from Phase 1b)

Public mail, when it ships, is correspondent, date and item names
only — no bodies, no gold amounts. If that cannot be done cleanly,
counts only.
## Phase 1c backlog (recorded, no code yet)

- Hunts/checklist persistence: after the sheet retirement, toggles are
  session-only (in-memory, reset on reload). Needs a persistence design
  before launch; device-local storage is the leading simple option.
  Checks must survive reloads by the Oct 27 reservation/hunt period.
- Mail long-term source: the canonical pipeline's redacted projection, never a
  committed data/ledger.json with real data. The 1b revert of a real-data
  ledger during testing was correct and stays the rule: gold, bag/bank
  contents, mail and ledger detail are private-local only.
## Deploy notes

- GitHub Pages builds the main branch only (verified via the deployments API:
  every recorded Pages build is ref=main). Pushing any other branch never
  deploys. A merge into main IS the live deploy.
- Session rule: no branch comparison or deployment-base conclusion without a
  fresh git fetch in the same session. Stale local refs caused a wrong
  base call during Phase 1b (local main predated PR #27).

## Phase 2a (SavedVariables: Syndicator + DataStore)

`scripts/parse-saved-vars.ps1` reads `Syndicator.lua`, `DataStore_Reputations.lua`,
`DataStore_Currencies.lua` and `DataStore_Characters.lua` in place under the real
`WTF/` root (from `scripts/addons.local.json`, overridable with `-WtfRoot`) and
merges them into the private set. No SavedVariables are ever copied into the repo.

- `characters.json` records gain source-tagged blocks; dossier-export fields are
  never overwritten (snapshot times differ):
  - `syndicator = { moneyCopper, bags, bank, bankTabs, equipped, mail[{itemName,
    itemId, count, expiresAt}] }` — inventory/mail/bank/gold stay private-only.
  - `datastore = { reputations[{id, name?, standing, standingId, negative,
    value}], currencies[{name, quantity}] }`.
- `economy.json` records gain `syndicatorMoneyCopper` and `datastoreMoneyCopper`.
- `data/catalogs.json` `factions` maps only IDs verified by the repo map in
  `scripts/altoholic.ps1`, corroborated in-data by the Flann Dossier export (same
  standings per faction; Gadgetzan 600 == 600). Anything else stays in
  `unresolved.factions` — names are never invented. Currency names resolve from
  the in-file `DataStore_Currencies_Catalog` (e.g. Honor Points = id 1792,
  triple-checked against Syndicator, DataStore totals and the Dossier export).
- Duplicate Syndicator rows (stale short names, realm-suffix variants) resolve by
  money agreement: same-session DataStore money outranks the older dossier gold.
- Anonymous DataStore entries pair to characters by nearest-preceding logout
  timestamp inside one hour (positional pairing misattributes when beta
  throwaways without exports interleave).
- Fixtures live only under gitignored `data/private/fixtures/` with obviously
  fake names; the test asserts no fixture id appears in any committed file.

PowerShell 5.1 pitfalls hit while writing the parser (recorded so later phases
do not re-learn them): never wrap a `List[object]` in `@(...)` — the DLR
MaybeDebase binder throws "Argument types do not match" (use `.ToArray()`;
`List[string]` and arrays are fine); never round-trip UTF-8 JSON through
`Get-Content -Raw` (it decodes as ANSI — read with `[IO.File]::ReadAllText`
plus explicit UTF8).
