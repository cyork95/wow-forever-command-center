# Screenshotter

The Screenshotter takes a screenshot at big moments and writes the reason into the [[Biography]]. You do not need Memento for that.

Open the tab with `/dossier shots`. Take one immediately with **Take test screenshot** or `/dossier shot`. That works even when automatic screenshots are off.

## Moments

**Take screenshots automatically** turns the whole feature on or off. Each moment has its own switch.

On at first:

- Level up
- Death
- Achievement earned
- Dungeon or raid boss killed
- Battleground or arena ends
- Duel finished
- New mount, pet, toy, or recipe

Off at first:

- Login
- Every few minutes. The slider runs from 5 to 60 minutes and starts at 5. Timed shots keep going after `/reload`.

Two moments within 3 seconds, such as a level-up that also earns an achievement, share one screenshot.

## How the shot looks

- **Hide the interface** hides your action bars and windows for the shot. This is skipped in combat, when the game does not allow it.
- **Add a name and date stamp** shows a small label with your name, realm, level, and the date while the interface is hidden.
- **Camera sound** plays when a shot is taken.
- A chat message can print for each screenshot.

Hide interface, the stamp, the sound, and the chat line start on.

## Where the file goes

Screenshots are saved in `World of Warcraft\_classic_beta_\Screenshots` with the game's usual names. An addon cannot rename those files. Each one is noted in the Biography with the place and, for Screenshotter shots, the reason, so a tool that reads the Biography can name and caption them later.

## Memento

While Memento is loaded, the Screenshotter pauses so you do not get two screenshots of the same moment. The tab says so. Disable Memento in the AddOns list to let Dossier take over.

When the Screenshotter is on and Memento is not loaded, the Companions tab shows Memento as **Built into Dossier**. Boss kills Memento recorded stay available as a companion block until then. Boss kills are in the Biography either way.

## Turning it off

`/dossier off shots` stops automatic screenshots and hides the tab. Shots already taken stay in the Screenshots folder and in the Biography. `/dossier shot` still takes one when you ask. See [[Options]].
