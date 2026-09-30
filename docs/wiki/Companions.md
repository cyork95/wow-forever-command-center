# Companions

Dossier never needs another addon. When one of these is loaded, Dossier can read what it has saved for this character and add it to the Companions section of the export.

Each companion is optional. The Companions tab shows whether each addon is loaded, installed but not loaded, or not installed, and has a switch to leave it out. Switches are on by default and only work while that addon is loaded.

Untick **Companions** on the Export tab to leave all of them out of one report. `/dossier off companions` stops Dossier reading any other addon and hides the tab. See [[Options]].

If a companion addon changes how it saves data, its block says it could not be read. The rest of the export still works.

## What each one adds

| Addon | What it adds |
| --- | --- |
| Syndicator | Your mail, and your bank contents while the bank is closed |
| AllTheThings | Deaths, quests, areas explored, time played, and mount, pet, toy, and title counts |
| Nova Instance Tracker | Your saved lockouts and recent instance runs |
| Profession Master | Every recipe you know, grouped by profession |
| Auctionator | The auction price of each stack in your bags, plus a total |
| Talents Forever | Your planned talent build and saved builds for your class |
| KillDex | Total kills, creature types, your top 15 creatures, and items seen dropping. Shown as **Built into Dossier** and left out once Dossier has kills of its own. See [[Kills]] |
| Memento | The boss kills it recorded. Shown as **Built into Dossier** while the Screenshotter is on and Memento is not loaded. See [[Screenshotter]] |

Until Dossier has saved the bank itself, the Bank section can use Syndicator's copy. Until it has saved a profession, Profession Details can use Profession Master's recipes. Those fallbacks are labeled with where the copy came from. See [[Making an export]].

Want another addon covered? Ask in the comments on the CurseForge project. Dossier only reads character data another addon already stores. It does not take actions for you.
