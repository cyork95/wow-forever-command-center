# Session

A session is one stretch of play. The timer starts by itself with your first kill, loot, gold, or XP. You do not need the Gathering addon.

Open the tab with `/dossier session`.

## What it tracks

- Kills, and kills per hour
- Items gathered, by type
- Gold gained or spent, and gold per hour
- XP, XP per hour, and how long until your next level at this pace

Gathering types, each with a switch under **Count as gathered**:

- Herbs
- Ore and stone
- Leather
- Cloth
- Cooking and fish
- Elemental
- Enchanting
- Jewelcrafting
- Reagents
- Holiday items
- Consumables

Quest items are off at first. Untick a type to stop counting it.

Money from the mailbox or the guild bank is not counted as earned. Items taken from the mailbox or guild bank are not counted as gathered.

## Pause, reset, and the next session

**Pause** stops the clock. **Start** goes on. **Reset** ends the session: it is saved in your last 20 sessions and a new one begins.

**Previous sessions** lists them by date and time, with how long each lasted, the zone, kills, gathering, gold, and XP.

A `/reload` keeps the session going. If you log out for more than 10 minutes, the old session is saved and a new one starts the next time you play.

## The session panel

**Show the session panel**, `/dossier panel`, or a right-click on the minimap button opens a small window with the timer and the lines you pick:

- Kills
- Gathered
- Gold
- XP and time to level
- Recent creatures

Drag it anywhere and press **Lock** to keep it in place. The **Panel background** slider sets the background from fully clear (0%) to solid (100%).

Left-click the panel title to pause or start. Right-click the title to reset. Point at the title to see your top 15 items gathered with their hourly rates, then how many more there are. The Session tab lists every item.

The panel keeps your last 10 creatures, so it stops growing. Before the first kill or loot it shows just the timer.

## The export

The Sessions section, in the Story card and on by default, has:

- **This session:** time, kills, gathering, gold, and XP with hourly rates
- **Gathered:** everything you have gathered on this character, by type
- **Recent sessions:** your last 10 sessions, one dated line each

**Detailed export** adds item IDs and lists every item and every saved session.

Lifetime gathering is counted per character from the day you start using this session tracker. Gathering's own account-wide totals are not copied in.

## Turning it off

`/dossier off session` hides the tab and the panel, saves the current session into Previous sessions, and leaves Sessions out of the report. The history stays. If Session was off when you logged in, turning it on picks up the saved session instead of starting over. See [[Options]].
