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
| `data/characters.public.json` | public, committed | Redacted site input. Roster-matched characters only: roster id, display name, level, race, class, professions with ranks, reputation names with standings, currency names, collection counts, completed quest count, total kills. No gold, no bags, no bank, no mail, no ledger detail, no item locations. |
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

## Guides (board #42)

`data/guides.json` is a hand-curated list of outbound links (video/article):
id, title, url, creator, type, topics[], appliesTo[], keyTimestamps?,
added. No embedding, no scraping, no thumbnails fetched.

- Curation flow: the Butler keeps a running index of candidate guides across
  sessions; at handover it proposes entries, and the curator appends the
  approved ones to `data/guides.json` by hand. The file is committed (titles
  and URLs are public information).
- `appliesTo` holds roster character ids (currently `malavus`, `sorinis`,
  `skyrinis`) plus topic tags for future surfaces (`economy`). The roster card
  in `assets/app.js` lists entries mapped to that character; the Butler pack
  prints the same mapping under "Relevant guides" per character.

## Phase 2b (SavedVariables: ATT + Collection History + Rarity + Questie)

`scripts/parse-att.ps1`, `parse-att-history.ps1`, `parse-rarity.ps1` and
`scripts/parse-questie.ps1` read the account-level SVs in place under the real
WTF root (same Account-dir loop as 2a) and merge into the private set. No
SavedVariables are ever copied into the repo. Chattynator content is never
read; Polestar is never parsed for progress. Per-character Questie.lua files
are literally `QuestieConfigCharacter = nil` in game, so only the
account-level file is read -- do not go looking for per-char Journey files.

- `data/private/att.json` (private, gitignored): ATT owns have-detail. One
  record per SV character GUID, roster-agnostic (matched to canonicalId by
  first token; unmatched beta throwaways flow through with null; launch
  names flow through unchanged): have id-sets for quests, spells,
  exploration, flightPaths, achievements, titles, toys, mounts, battlePets,
  priorQuests and oneTimeQuests, plus customCollects and scanTimes. The
  account block adds sources. Dossier-owned fields (level, time played,
  deaths, professions, counts, names) are deliberately NOT extracted.
  Value semantics observed in-data: character quest ids map to 1, account
  quest ids to 2, sources to 1. Empty categories store as empty lists,
  populated ones as dicts; the parser handles both. The SV records haves
  only -- want-detail is not derivable from it and stays with the Dossier
  totals; never invent it.
- `data/private/collection-history.json` (private, gitignored): Collection
  History owns the obtained-timeline. Entries keep collectedAt as stored
  (first-class ISO strings), type, cleaned name, itemId parsed from
  `|Hitem:id|` when present, and the raw colour-code text (private only).
  No character attribution exists in the SV, so the timeline is
  account-wide by construction.
- `data/private/rarity.json` (private, gitignored): Rarity owns attempts,
  attempts layer ONLY -- it never decides have/want. Per-item SavedVariables
  fields follow the installed addon (`Interface/AddOns/Rarity/DB/Item.lua`
  expectedFields): attempts, lastAttempts, realAttempts, finds, totalFinds,
  time, lastTime, plus known/enabled/found recorded raw. Zero attempts with
  items present is the honest empty state and overwrites normally; it is
  never manufactured and never a reset.
- `data/private/quest-history.json` (private, gitignored): Questie owns
  quest history. One record per SV character key; stale short-name session
  keys (`<name> - PvE`) resolve to the same canonicalId as current full
  names. Journey events carry timestamp plus ISO, event, subType, quest,
  level and newLevel; any SubType is accepted (Accept/Complete/Level
  observed; Abandon not yet seen). Current-name keys legitimately carry
  complete[] with no journey -- that is not a reset. Dossier 2.2.19+ can print a "Quest history" export section from the same journey (Other-addons plus Questie switch, Questie loaded). It is presentation-only for the AI chat: `parse-dossier-export.ps1` segments the heading but ingests nothing from it -- the SV file stays the single owner.
- Public: `data/att.public.json` (committed) carries the public-safe
  subset: account have-sets and obtainedTimeline/obtainedCount (name, type,
  timestamp, itemId; raw colour text stays private). Per-character detail is
  roster-matched only, like `characters.public.json` -- honestly empty until
  Nov 4. Rarity and quest history have no public projection: private only.
- Butler packs gain optional sections, skipped when the files are absent:
  Collections detail (ATT), Recently obtained (account-wide last 5), Rarity
  attempts, Quest history (merged across each character's SV keys).
- Ingest safety: every 2b parser records sources (file, sizeBytes, mtime),
  counts and generatedAt, prints a stdout diff, and retains a prev/ copy. A
  missing source, zero records, or source-shrink plus count-drop WARNS and
  keeps the previous good canonical -- good data is never overwritten with
  a reset file. Reset-shape caveat: an emptied Lua table parses to an empty
  LIST through lua-saved.ps1, so parsers guard `-is IDictionary` before
  indexing; the reset tests exercise exactly this.

PowerShell 5.1 pitfalls addenda (see 2a list above, still true): keep .ps1
files pure ASCII -- 5.1 decodes BOM-less UTF-8 as ANSI, and a non-ASCII dash
inside a double-quoted string broke the tokenizer while the same character
in comments was harmless. `@()` around a `List[object]` also bites through
hashtable values (the pack's `$extra` map): `.ToArray()` first. And
`@($oneHash) | ConvertTo-Json` serializes a bare object, not a one-element
array (pipeline unrolling) -- readers accept bare-object docs too.
`@($x)` with `$x` null yields a 1-element array, not an empty one: guard
optional JSON arrays (`$mission.quests`, `$hunt.match.names`) with `if`
before wrapping, or a missing block counts as one null entry.

## Hunts redesign (board #39)

`data/checklist.json` entries carry the bucket schema. `type` is the bucket
(`collection` | `gear` | `mission`); entries with no `type` key are
unmigrated or genuinely ambiguous and render under Other for a human call.
The pre-#39 display type (Pet, Mount, Gear, ...) moved to `kind`, preserved
verbatim -- rendering, search and the dungeon-place rule read it from there,
so no grouping information was clobbered.

- Collection hunts (`accountWide: true`, `assignedTo` as a who-farms note
  only): a curated want renders OBTAINED when its `match.names[]` hits a
  Collection History timeline name (exact, case-insensitive) or its
  `match.questIds[]` / `match.itemIds[]` land in the ATT have-sets.
  Otherwise the manual toggle applies, stored account-wide. ATT SVs record
  haves only, so wants are hand-curated in the hunts data and never derived
  from ATT. Zero of the 21 collection wants match today -- all manual.
- Gear hunts (`targetCharacters`): manual check-off per character, unchanged.
- Class missions (`quests[]`, `targetCharacters`): progress derives from the
  ATT per-character quest have-sets; none are tracked today.
- `rarityId` links a hunt to a Rarity SV key (the display-name key; numeric
  ids live only in the addon's static DB). Attempts display only -- Rarity
  never decides obtained status.
- `guideRef` is `{ kind: "polestar" | "video" | "doc", ref }`: video/doc
  refs resolve against `data/guides.json` ids, polestar refs are free-text
  in-game guide names. None curated yet.
- `data/att.public.json` `characters[]` entries carry `questsHave` id
  arrays (plus `questsHaveCount`) for mission progress; still roster-gated
  (empty until launch characters are scanned). Regen note: parse-att and
  parse-att-history append keys via Add-Member, so top-level key order may
  shuffle between regens; the file stays content-identical and the site
  reads by key.
- `data/rarity.public.json`, generated by parse-rarity.ps1 alongside the
  private file: `{ schemaVersion, generatedAt, source, items: [{ id, name,
  attempts, found }], summary: { itemsTracked, itemsWithAttempts,
  totalAttempts } }`. Counts only: no character GUIDs, names, servers,
  profiles or statistics.
- Hunt checks persist in localStorage under `wow-forever-hunts-v2`:
  collections keyed by hunt alone (`"*"`), gear/mission per character. The
  v1 store migrates once, best-effort (collection checks collapse with
  checked-wins; unmapped ids drop and are reported; attempts carry over),
  then the v1 key is retired.
- Butler packs print `## Hunts` per character: matched gear hunts, mission
  progress from the private Questie complete ids, and the collections line
  account-wide and identical in every pack.
- Classification snapshot (41 entries): 21 collection, 14 gear, 6 unset --
  the 4 milestones (house tasks, not hunts), bmah (a shop, not one
  collectible), hunter-family-pets (a per-hunter stable plan). The two
  consumable recipes (whimsyfin, peace-tea) were classified collection per
  the Butler decision; the remaining six unset entries stay unset
  permanently by the same decision.
- Site logic tests live beside the PowerShell suite as
  `scripts/tests/test-hunts-logic.mjs` (run with `node ...`); it loads
  assets/app.js in a vm and asserts migration, obtained matching, mission
  states, rarity text and guide refs with synthetic fixtures.


## Journey (board #51, Phase J1)

`data/journey.json` is a hand-curated route for Skyrinis's 100% completionist
run: `{ schemaVersion, character: "skyrinis", zones[] }`, zones in running
order. Each zone carries every section key (`quests`, `exploration`,
`collectibles`, `rares`, `boes`, `professions`, `guideRefs`); sections with
nothing verifiable yet stay empty arrays. Quest entries carry a verified id
when one exists (`{id, name}`) or go in name-only (`{name}`, manual tick).

- Curation flow: Butler/Cody curate in the ticket or its decisions comment,
  then hand-edit `journey.json`. Zone-count-agnostic: adding a zone later is
  data-only. Curation sources in trust order: installed addon data (QuestieDB
  / Questie quest data, AllTheThings zone lists) first, this repo's data
  files second, clearly-attributed community knowledge only where it can be
  cross-checked against one of the first two. No invented quest ids, item
  ids, or rare names; gaps are listed in the ticket report, not hidden.
- Seed inclusion rule (J1, verbatim): a quest ships in a zone's list iff
  (a) its id is verified for that zone -- by ATT Camelot zone membership
  (coords on the zone map) or by the repo quests.json zone label (including
  the Northshire Valley and Northshire Abbey sub-zone labels for Elwynn)
  -- AND the repo zone label, when present, does not assign it to a
  different zone -- AND (b) its name verifies in at least one
  Questie-family source (repo quests.json preferred, else the installed
  QuestieDB toc name decode). Verified same-name duplicates ship as
  separate entries with sibling notes. Anything failing (a) or (b) goes to
  the omissions ledger in the ticket report. Result: 142 Zephras Isle
  quests (every ATT-verified in-zone id named) and 83 Elwynn Forest quests
  (49 repo Elwynn-family labels plus 34 ATT extras). Deliberately excluded:
  11 quests with Elwynn objectives that belong to other zones (345, 346,
  1097 Stormwind City; 1667 Warrior; 1860 Mage; 2205, 2300 Rogue; 5623,
  5624, 5628, 5635 Priest).
- J1 seeds: Zephras Isle (Skyborne starting zone: ATT Camelot map 2521 lore
  names the Skyborne and the floating island; checklist hunts reuse the name)
  and Elwynn Forest (map 1429; 1-10 classic arc). No Polestar 01-guide exists
  for either zone (guides start at 02), so `guideRefs` is empty for both.
- Progress sources at render: quests from Skyrinis's per-character completed
  set (`att.public.json` `characters[]` entry for `skyrinis`); exploration
  from his per-character exploration set when the projection carries one --
  today the public file holds exploration counts only, so exploration shows
  pending until the projection gains the set (no generation change in J1);
  collectibles account-wide by Collection History timeline name match (the
  #39 normalization), so a collectible checks when ANY roster character
  holds it. Rares, BoEs, and profession milestones are manual ticks.
- Gating rule: a zone reads DONE only when Quests, Exploration, and
  Collectibles all clear. Rares, BoEs, and professions count toward the
  zone % but never gate DONE. Any route item may carry `"priority": true`,
  rendered starred and surfaced in the route-header priority-targets list.
- Manual checks persist in localStorage under `wow-forever-journey-v1`,
  keyed `zoneId::item name`, with a reset control and an honest footer
  ("Manual checks save on this device only"). Until Skyrinis is scanned
  post-launch (`characters[]` empty), auto items render the honest pending
  state "character not yet scanned", never fake zeros or false completions.
- Butler packs gain a `## Journey` section for the journey character only:
  overall %, current zone, per-zone lines with gating sub-counts, the next
  unfinished gating item, and the honest no-scan line when no ATT data
  exists. Manual ticks live in the browser only and print unchecked.
- Tests: `scripts/tests/test-journey-logic.mjs` validates the route file
  (parses, orders unique/sequential, every section key per zone) and asserts
  the progress computation with synthetic fixtures only (auto vs manual,
  gating, account-wide collectibles, priority surfacing, localStorage
  round-trip); `scripts/tests/test-journey-pack.ps1` proves the pack summary
  in the no-scan and scanned states.
