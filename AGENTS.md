# Forever Command Center

This repo is CoYo's World of Warcraft: Forever house. It has two parts.

- The site (`index.html`, `assets/app.js`, `data/`) is the command center: roster, hunts, dungeons, quests, and merged addon stats.
- The addon (`addon/Dossier/`) is Dossier, formerly AIExport. In game, `/dossier` builds a text report of one character for an AI. Player docs are in `docs/wiki/`. The example skill for reading a paste is `.cursor/skills/dossier/SKILL.md` and the same text is inside `addon/Dossier/Guide.lua`.

Read `.cursor/rules/dossier-scope.mdc` before changing the addon. Record this character only. Every feature switches off from the Options tab: events unregister, and its tab and export section hide, while saved data stays.

## House rules

Roster Doc = names, specs, professions, trees, house rules only.
Farm Sheet = every hunt. New X posts go here first.
Command Center HTML = dashboard snapshot. Refresh it when hunts change.
Do not dump news into the Roster Doc.
Keep Alliance house: Starhollow elves, Blackwell, Emberkeg, Xorr pairings.
Beta: never take Skyrinis, Sorinis, or Malavus.

`Forever_Roster.html` is the roster doc. The live hunt list and its checks are the Hunts tab of the Google Sheet. `data/checklist.json` is the offline fallback. `forever-command-center.html` is the dashboard snapshot. New hunts go on the Hunts tab, and into `data/checklist.json` when the fallback should match. Do not put patch news on the roster. Sheet setup is `scripts/sheets/SCHEMA.md`.

## Addon

Source is `addon/Dossier/`. Version is `C.VERSION` in `Constants.lua` and `## Version` in both `.toc` files. A player-facing change gets a `CHANGELOG.md` line and a matching wiki page.

Export sections live in `Constants.lua` (`SECTIONS`, `SECTION_ORDER`, `SECTION_GROUPS`, `DEFAULT_SELECTIONS`). A switchable feature is an entry in `Features.lua`. Collectors are `Data/*.lua` with `Collect()`, wired in `Commands.lua` `GetCollector`, and printed from `Formatters/TextFormatter.lua`. Load new data files from both `Dossier.toc` and `Dossier_Camelot.toc`. Companions (`Companions/*.lua`) read the source addon
running Lua globals, never its SavedVariables file: Questie journey comes from `Questie.db.char.journey`, which AceDB already scopes to the current character. A companion reader used by a section goes through `Companions:Read`, gated by the per-addon switch.

Kills (`Data/Kills.lua`) count a player, pet, or guardian killing blow, including pet specials (`SWING_DAMAGE`, `RANGE_DAMAGE`, `SPELL_DAMAGE`, `SPELL_PERIODIC_DAMAGE` with overkill of 0 or more, and `PARTY_KILL`). Ownership is the player GUID, the current or cached pet GUID, or combat-log flags for affiliation mine plus type player, pet, or guardian. The same corpse is not counted twice. Trash inside a dungeon or raid is not counted. Do not count the pet's own death.

Combat pet (`Data/Pet.lua`, export section `pet`) is the summoned class pet and the stable, not battle pets. Battle pets stay in Collections. Status is Out, Dismissed, or none. Dismissed keeps the last pet that was out. The feature id is `pet` (`/dossier off pet`). It has no tab.

Currency and reputation stay current snapshots. Do not add Journalator-style session history unless a new ticket asks for it.

Package with `powershell -File scripts/package-addon.ps1`. A Dossier deploy is not complete until the merged build is also synced to the game AddOns folder and the installed version verified. There is no Lua test suite. Syntax-check touched Lua with `luac` or `lua` when it is installed. WoW itself is not available here.

## Site

- Hunts: the Google Sheet Hunts tab is the live list. `data/checklist.json` is the fallback when the sheet does not load. Parked future drops use `"status": "Parked"`.
- Tasks: the Tasks tab on the sheet, one checkbox column per character. The site task list is empty when the sheet does not load. Ledger notes stay in `data/ledger.json`.
- Characters: `data/characters.json` is still the roster (names, specs, roles). Live level, gold, gear, and the rest of the snapshot come from the sheet's Characters tab. `data/stats.json` is the fallback. Do not invent quest titles. Forever quest ids missing from `data/quests.json` stay as `Quest <id>` in `assets/app.js`.
- Hunt checks: collections are account-wide (one shared check; curated wants render OBTAINED from ATT have-sets/timeline, otherwise manual), gear hunts are per character (manual check-off), class missions are per character (progress derived from quest scans). "Owned" notes stay account-wide: a pet in one character's bags can show as owned on another character's sheet, and the note names who holds it. The site does not write that automatic check back to the sheet. Whole-house view is the Collections view; per-character gear does not toggle from that view.
- Hunts checklist state persists in localStorage (key wow-forever-hunts-v2, migrated once from v1 where possible), merged over checklist.json defaults. Checks saved in localStorage before the sheet were not copied over.
- Site header carries one global Character picker on every tab; roster-card clicks and ?c= links sync it, and it drives every character-scoped view (no per-tab character dropdowns). The House tab is removed; `data/house.json` stays in the repo archived and unfetched.
- Journey: `data/journey.json` is the hand-curated Skyrinis route (zones in order, data-only to extend). Curation trusts installed addon data first, then repo data, then cross-checked community knowledge; never invent quest/item ids or rare names; list gaps in the ticket report. Zone DONE gates on quests, exploration, and collectibles only.
- Dungeons: `data/dungeons.json`. A dungeon with no bosses still has to render. `assets/app.js` shows it when the name matches, including an empty placeholder.
- Empty quest scans, empty macros, and blank stats on characters who have not been played stay blank.

## Shipping

When a task changes files, commit and open a pull request. Do not commit `scripts/addons.local.json`. Issue board: https://github.com/users/cyork95/projects/1
