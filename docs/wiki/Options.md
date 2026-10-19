# Options

The Options tab has two parts. The same options are in the game's Settings under **AddOns > Dossier** (`/dossier settings`), with an **Open Dossier** button. A change in one place shows in the other.

Open the tab with `/dossier options`.

## General

Saved for each character:

- Show the minimap icon
- Item stats in bags and bank
- **Detailed export**, which puts item, spell, and quest IDs back and makes the report several times larger. See [[Making an export]]
- **Reload UI**

## Features

Saved for every character on the account. The same switches are `/dossier off <feature>` and `/dossier on <feature>`. The names are on [[Window and commands]].

| Switch | What it covers |
| --- | --- |
| Biography | Level-ups, deaths, new zones, quests, achievements, skill-ups, and boss kills |
| Kills | Creature counts, drops, gold, and tooltip counts |
| Session | The timer, gathering, gold, and XP per hour, and the session panel |
| Shopping list | Have and need counts, and vendor reminders |
| Combat pet | The summoned hunter beast, warlock demon, or other combat pet, and the stable |
| Screenshotter | Screenshots at big moments |
| Other addons | Reading character data another addon already saved |

A feature that is off stops completely:

- Its game events are no longer watched
- Its tab is hidden
- Its section on the Export tab is greyed out with `(off)` and left out of the report
- Its commands say how to turn it back on

Turning Session off also hides the session panel and saves the current session to Previous sessions. Turning Other addons off stops Dossier reading any other addon.

Nothing a feature saved is deleted. Turn it back on and its history is still there.

The switches apply to every character on the account. They are saved in:

`World of Warcraft\_classic_beta_\WTF\Account\<account>\SavedVariables\Dossier.lua`

Each character's own history, including the Biography, kills, sessions, and shopping list, stays in that character's `SavedVariables\Dossier.lua`.

The Export tab, its other sections, Help, and Options are always on.
