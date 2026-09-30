# Troubleshooting

## The addon does not load

`Dossier.toc` has to sit directly inside `Interface\AddOns\Dossier\`. If the path is `AddOns\Dossier\Dossier\Dossier.toc`, move the inner folder up one level. Then tick Dossier on the character select **AddOns** list and restart the client. See [[Install]].

Dossier is built for the World of Warcraft Forever client. A retail AddOns folder will not load it.

## The Biography is empty after updating from AIExport

The game stores saves under the addon's name. Copy `AIExport.lua` to `Dossier.lua` while the game is closed, and change `AIExportDBChar` to `DossierDBChar`, before Dossier runs the first time. Steps are on [[Install]].

Play from before either addon was installed is not reconstructed.

## Chat says to turn AIExport off

AIExport is still loaded next to Dossier, so kills and screenshots can be recorded twice. Disable AIExport in the AddOns list and `/reload`.

## A tab is gone

That feature is off. The Options tab, or `/dossier on` plus the feature name, turns it back on. History saved before you turned it off is still there. Names: `bio`, `kills`, `session`, `shop`, `shots`, `companions`. See [[Options]].

Export, Help, and Options do not turn off.

## The bank or a profession has a ! 

The game only shares the bank and profession recipes while that window is open. Dossier is showing a missing copy, or one older than a week. Open the bank, or open that profession, then close the window. The `!` clears when the copy is saved.

The export may say `Missing: Bank not saved yet. Open your bank once.` or `Blacksmithing not saved yet. Open its window once.`

Until then, Bank can come from Syndicator and recipes from Profession Master, labeled `Saved copy from`. See [[Making an export]].

## The shopping list bank count looks wrong

It uses the last bank Dossier saved. Open the bank once so the count includes what is stored there. See [[Shopping list]].

## The report is cut off in the AI chat

Untick the largest sections. The export window names the three biggest and shows an approximate token count. Turn **Detailed export** off unless you need IDs. Completed Achievements and Collected Appearances start off because they are long.

## Kills are missing inside a dungeon

Trash kills in dungeons and raids are hidden by the game, so Dossier does not count them. Bosses are in the [[Biography]]. A creature someone else tagged first is not counted either. See [[Kills]].

## The session timer stays at zero

The timer starts on your first kill, loot, gold, or XP. Standing in town before any of those leaves it idle. Mail and guild bank gold do not start it and are not counted as earned.

After more than 10 minutes logged out, the previous session is saved and a new one starts on the next kill, loot, gold, or XP. A `/reload` keeps the current session.

Quest items are off under **Count as gathered** until you tick them.

## Screenshots are not happening

**Take screenshots automatically** has to be on, and the moment you expected has to be ticked. Login and the every-few-minutes shot start off.

If Memento is loaded, the Screenshotter pauses and the tab says so. Disable Memento to let Dossier take the shots.

`/dossier shot` takes one right away, including when automatic shots are off. Files keep the game's names in the `Screenshots` folder. The reason is in the Biography. See [[Screenshotter]].

## An update seems to have done nothing

Releases that add files need a full restart of the game, not only `/reload`. Exit to the desktop and start the client again.
