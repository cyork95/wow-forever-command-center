# Command center sheet

Cody owns the Google Sheet. This file is the schema, the setup steps, and the CSV contract the phone companion can fetch later. The site reads the published CSV. Writes go through the bound Apps Script in `Code.gs`.

`/dossier` in game copies a text report, not JSON. The paste that fills Characters is the character JSON already produced by `scripts/scan-addons.ps1` (one object from `data/exports/`, or the `characters` map in `data/stats.json`). That JSON is what carries bags, recipes, kills, and finished quests. Pasting the in-game text report does not.

Screenshots, the quest catalog, and `data/dungeons.json` stay in the repo. They still update when the scan runs and those files are committed.

## Tabs

Character checkbox columns, in this order:

`skyrinis`, `sorinis`, `taloninis`, `lucinis`, `vesperinis`, `malavus`, `bramblebeard`, `flann`, `ullrathor`, `trendirun`

A new roster id is a new row on Config. **Command center → Add character columns** inserts the checkbox column. On Hunts it is inserted before `tries`.

### Characters

One row per roster id.

| Column | What it holds |
| --- | --- |
| id | Roster id, such as `flann` |
| name | Display name |
| realm | Realm |
| level | Level |
| zone | Zone |
| subzone | Subzone |
| goldCopper | Gold in copper |
| health | Health text |
| powerType | Power type, or blank |
| playedSeconds | Time played, in seconds |
| exportedAt | Export timestamp |
| professions | Compact text, such as `Mining 47/75, Blacksmithing 19/75` |
| snapshot | The full character object as JSON |

`snapshot` is what the site loads. The other columns are the human-readable copy. A snapshot over 50,000 characters is refused. `parseImport` does not change hunt or task checks.

### Hunts

One row per hunt, one row per set piece (`parentId` is the parent hunt id), and one row per library book (`id` like `book:archmage-theocritus-research-journal`). Book ids are the book name in lower case, with apostrophes removed and every other run of non-letters collapsed to a hyphen. The same title shares one row. Dungeon drops that are not already hunts do not get rows.

Definition columns: `id`, `parentId`, `name`, `type`, `zone`, `minLevel`, `priority`, `status`, `owners`, `notes`, `how`, `source`, `mobs`, `need`, `defaultDone`.

`owners` and `mobs` are pipe-separated (`malavus|sorinis`). `defaultDone` is the seed flag. After import, the character checkbox is the live value. `defaultDone` matters only when the site falls back to `data/checklist.json`.

Then one real checkbox column per character id, then `tries`. `tries` is JSON keyed by character id, such as `{"flann":2}`. An empty count is `{}`.

The seed copies `defaultDone: true` into every character checkbox. Today that is only `milestone-beta`.

### Tasks

`id`, `name`, `cadence`, `zone`, `notes`, then the same character checkbox columns. The seed is a header row. Cadence is `daily`, `weekly`, `monthly`, `yearly`, or `once`. The Tasks tab on the site reads this tab. Ledger notes stay in `data/ledger.json`.

### Import

`B2` is the paste cell. Put the character JSON there, then **Command center → Parse import**. The same function runs for a `parseImport` POST.

### Config

`id` and `name` for each roster character. Parse import uses this to match a display name when the JSON has no id. A single full-name match wins. A single first-name match is used when the full name does not hit.

## Setup

1. Create a sheet with tabs named `Characters`, `Hunts`, `Tasks`, `Import`, and `Config`.
2. From the repo root, run `powershell -File scripts/sheets/build-seed.ps1`. It writes CSVs under `scripts/sheets/seed/`. That folder is not committed.
3. For each tab, **File → Import** the matching CSV and replace the current sheet. Import `characters.csv` into Characters, and the same for `hunts.csv`, `tasks.csv`, `import.csv`, and `config.csv`.
4. **Extensions → Apps Script**. Replace the default file with `scripts/sheets/Code.gs`. The project must stay bound to this sheet.
5. **Project settings → Script properties**. Add `WRITE_SECRET`. Do not put that value in the repo.
6. **Deploy → New deployment → Web app**. Execute as you. Who has access: Anyone. Copy the web app URL (`…/exec`).
7. In the sheet, **Command center → Install checkboxes**, then **Add character columns** if Config has an id the Hunts or Tasks header does not.
8. **File → Share → Publish to web**. Publish the Characters, Hunts, and Tasks tabs as CSV. Copy each link.
9. Put those three URLs in `data/sheet.json` (`characters`, `hunts`, `tasks`). They are public on purpose, the same way `data/stats.json` is public on GitHub Pages.
10. Put the web app URL and the secret in `data/sheet.local.json` (gitignored), or in the site's **Sheet writes** control. That control stores them in this browser only.

`data/sheet.example.json` shows the shape. `data/sheet.json` holds only the public CSV URLs.

Published checkbox cells come through as `TRUE` or `FALSE`.

## Writes

The site POSTs JSON with `Content-Type: text/plain;charset=utf-8` so the browser does not preflight. Every action includes `secret`. A wrong secret returns `{ "ok": false, "error": "bad secret" }` with HTTP 200, because the web app cannot set a 401.

- `toggleHunt` — `{ "id", "characterId", "checked" }`. Sets that character's checkbox on Hunts. Unknown hunt ids are not created.
- `toggleTask` — the same fields on Tasks.
- `setTries` — `{ "id", "characterId", "count" }`. Updates the `tries` object on a hunt row. Zero removes that character's count.
- `parseImport` — `{ "json": { … } }`. One character object, or `{ "characters": { "flann": { … } } }`. Upserts Characters and refreshes the scalar columns from the object.

## Phone companion

The companion is not in this repo. When it is updated, it should:

- Fetch the same published Hunts and Tasks CSV URLs as `data/sheet.json`.
- Treat the first row as headers.
- Treat a checkbox cell as checked only when the value is `TRUE` (any case).
- Use the roster id column for each character. Do not read `localStorage`.
- Write a change with the same POST body and shared secret. Do not invent hunt rows for dungeon drops that are not already on Hunts.

## Fallback

If a CSV URL is empty or a fetch fails, the site uses `data/stats.json` and `data/checklist.json`, and the task list is empty. Checks are not saved in that mode. Checks that used to live in this browser were not copied onto the sheet.
