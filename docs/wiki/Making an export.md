# Making an export

The Export tab is the report. Tick the sections you want and press **Create Export**. The text is already selected, so Ctrl+C copies it.

The report starts with `Exported By: Dossier` and then one block per section you left ticked. Sections you leave unticked are absent. A feature that is switched off is greyed with `(off)` and left out. See [[Options]].

Paste one character per message. Each report has one character. Paste a new export when you want the assistant caught up. How to ask for a plan, a gear check, or a recap is on [[Using it with an AI]].

The report includes your character name, realm, and gold. Paste it only where you are comfortable sharing that.

## The six cards

**Select All** ticks every section. **Clear All** clears them. These are on by default except **Completed Achievements** and **Collected Appearances**, which are long. Turn those on when you want the full lists.

### Character

- **Location.** Zone, subzone, map, coordinates, and hearthstone.
- **Character Stats.** Name and realm, level, race, class, XP, health, stats, and ratings. Health is current and max, such as `Health: 486/486`.
- **Equipment.** One line per slot with item level, quality, and stats.
- **Reputations.**
- **Currencies.**

### Inventory

- **Bags.**
- **Bank.** The last copy Dossier saved. See below.
- **Shopping list.** What you are short of, recipes you plan to craft, and what is ready. See [[Shopping list]].
- **Collections.**
- **Appearances.**
- **Collected Appearances.** Off by default.

### Progress

- **Progress.**
- **Quests.** Quests in your log, one line each.
- **Completed Quests.** Quests you have turned in.
- **Achievements.**
- **Completed Achievements.** Off by default.
- **Lockouts.**
- **Kills.** Total kills, kills by creature type, your top 25 creatures, items seen dropping, and gold looted. See [[Kills]].
- **Statistics.** The Statistics tab of the Achievements window: deaths, gold acquired, quests completed, and the rest, grouped by category. A statistic with no value yet is left out. **Detailed export** lists one statistic per line with its ID.

### Abilities

- **Skills.** Profession ranks.
- **Profession Details.** The saved recipe list. Learned recipes are grouped by difficulty color: Orange and Yellow still give skill-ups, Green rarely, Grey does not.
- **Talents.**
- **Spellbook.**

### Story

- **Biography.** The whole timeline, not just the page on the Biography tab. See [[Biography]].
- **Sessions.** This session's time, kills, gathering, gold, and XP with hourly rates, everything you have gathered by type, and your last 10 sessions. **Detailed export** adds item IDs and lists every item and saved session. See [[Session]].

### System

- **AddOns.** Every installed addon and whether it loaded.
- **Companions.** Data from optional addons. Untick this once to leave all of them out. See [[Companions]].

## Token size

The export window shows about how many tokens the text uses (about 4 characters per token) and which three sections are largest. Untick sections you do not need if the AI chat cuts the text off.

**Detailed export**, on the Options tab, puts item, spell, and quest IDs back. The report is then several times larger. Leave it off for a normal paste, and turn it on when the assistant needs exact IDs.

The Export tab also shows the last export's token count.

## Bank and professions

The game only lets an addon read the bank and a profession's recipes while that window is open. Dossier keeps the last copy it saw.

Open your bank and each profession window once per session. The Export tab lists anything not saved yet, or saved more than a week ago, and marks those sections with `!`. The export window repeats it as `Missing: ...`. The list updates as soon as you close the bank or a profession window.

Until Dossier has its own copy, Bank uses Syndicator's bank if Syndicator is loaded, and Profession Details uses Profession Master's recipes if that addon is loaded. Those blocks say where the copy came from. Opening one profession window keeps the saved recipes of your other professions. A recipe is listed as learned only when the game says you know it.

Lines that say `unavailable`, `cached`, or `Saved copy from` are telling you the live window was closed. Treat them as the last saved copy, not as a live look at the bank.
