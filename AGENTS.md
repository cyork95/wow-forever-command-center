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

`Forever_Roster.html` is the roster doc. `data/checklist.json` is the hunt list the live site reads. `forever-command-center.html` is the dashboard snapshot. New hunts go in `data/checklist.json` and that snapshot. Do not put patch news on the roster.

## Addon

Source is `addon/Dossier/`. Version is `C.VERSION` in `Constants.lua` and `## Version` in both `.toc` files. A player-facing change gets a `CHANGELOG.md` line and a matching wiki page.

Export sections live in `Constants.lua` (`SECTIONS`, `SECTION_ORDER`, `SECTION_GROUPS`, `DEFAULT_SELECTIONS`). A switchable feature is an entry in `Features.lua`. Collectors are `Data/*.lua` with `Collect()`, wired in `Commands.lua` `GetCollector`, and printed from `Formatters/TextFormatter.lua`. Load new data files from both `Dossier.toc` and `Dossier_Camelot.toc`.

Kills (`Data/Kills.lua`) count a player, pet, or guardian killing blow, including pet specials (`SWING_DAMAGE`, `RANGE_DAMAGE`, `SPELL_DAMAGE`, `SPELL_PERIODIC_DAMAGE` with overkill of 0 or more, and `PARTY_KILL`). Ownership is the player GUID, the current or cached pet GUID, or combat-log flags for affiliation mine plus type player, pet, or guardian. The same corpse is not counted twice. Trash inside a dungeon or raid is not counted. Do not count the pet's own death.

Combat pet (`Data/Pet.lua`, export section `pet`) is the summoned class pet and the stable, not battle pets. Battle pets stay in Collections. Status is Out, Dismissed, or none. Dismissed keeps the last pet that was out. The feature id is `pet` (`/dossier off pet`). It has no tab.

Currency and reputation stay current snapshots. Do not add Journalator-style session history unless a new ticket asks for it.

Package with `powershell -File scripts/package-addon.ps1`. There is no Lua test suite. Syntax-check touched Lua with `luac` or `lua` when it is installed. WoW itself is not available here.

## Site

- Hunts: `data/checklist.json`. Parked future drops use `"status": "Parked"`.
- Dungeons: `data/dungeons.json`. A dungeon with no bosses still has to render. `assets/app.js` shows it when the name matches, including an empty placeholder.
- Characters: `data/characters.json`. Do not invent quest titles. Forever quest ids missing from `data/quests.json` stay as `Quest <id>` in `assets/app.js`.
- Hunt checks and "owned" notes are account-wide. A pet in one character's bags can show as owned on another character's sheet, and the note names who holds it.
- Empty quest scans, empty macros, and blank stats on characters who have not been played stay blank.

## Shipping

When a task changes files, commit and open a pull request. Do not commit `scripts/addons.local.json`. Issue board: https://github.com/users/cyork95/projects/1
