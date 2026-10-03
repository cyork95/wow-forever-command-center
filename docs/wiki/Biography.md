# Biography

From the moment Dossier is installed, it writes down what happens to the character it is loaded on. Nothing is deleted.

The Biography starts at install. It does not fill in play from before that day. If you moved from AIExport, copy `AIExport.lua` to `Dossier.lua` once or this log starts empty. See [[Install]].

## What gets a line

- Logging in, when your level or zone changed since the last session. The line names the zone.
- Every level-up, with the zone.
- Every death, with the subzone and zone.
- The first time you enter each zone in a session.
- Every quest you turn in, by name.
- Every book, scroll, or plaque you open, by title, with the zone. The page text is not saved. Opening the same book again later adds another line. Letters in the mailbox are left to the Mail tab.
- Every achievement you earn.
- Every boss you defeat, with the difficulty. Inside dungeons and raids, bosses are recorded here. Trash kills are not, because the game hides which creature died. See [[Kills]].
- Learning a profession, and each rise in profession skill.
- Every screenshot the game saves, with the place it was taken. This covers screenshots you take yourself and ones the Screenshotter or Memento takes. Screenshotter shots also say why, for example `Screenshot: Reached level 12, in Westfall`.

Profession skill-ups wait until the game has reported your ranks, so a login where the ranks were not ready yet does not invent a skill-up.

## Reading it

The Biography tab shows 40 lines per page. **Older** and **Newer** move through the rest.

The Biography section of an export always contains every event, not just the page on screen. In the report, each line is a time and an event, `HH:MM event`, under a date. That is how an assistant sees what changed since the last paste. See [[Using it with an AI]].

## Where it is saved

The game writes the full log when you log out or type `/reload`:

`World of Warcraft\_classic_beta_\WTF\Account\<account>\<realm>\<character>\SavedVariables\Dossier.lua`

Turning Biography off stops new lines and hides the tab. Lines already written stay, and they come back when you turn it on. The switch applies to every character on the account. See [[Options]].
