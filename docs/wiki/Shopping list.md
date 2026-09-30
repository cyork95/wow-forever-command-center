# Shopping list

The Shopping tab keeps a list of what you plan to gather or buy, and counts what you already have in your bags and bank. It only keeps track. Dossier never buys anything or moves items for you.

Open it with `/dossier shop`.

## Add a line

Click the box at the top, then:

- Shift-click an item in your bags, on a vendor, or in a profession window, and press Enter or **Add**
- Drag an item onto the box
- Type its name or item ID

A new item starts at one stack. **+** and **-** change how many you want. Hold Shift for 5 at a time. **x** removes the line.

## Recipes

Shift-click a recipe in a profession window to add its reagents, times how many you want to craft. If the game has not shown Dossier the reagents yet, the tab asks you to open that profession window once. Each time you craft that recipe, the count goes down by one.

## Have and need

Each line shows what you have against what you need, and **ready** or **need 8**. Point at a line to see your bags and bank counts and why you need it.

The bank count uses the copy Dossier saved the last time your bank was open. Open the bank when that count looks old. See [[Making an export]].

**Suggest from bags** adds the food and drink you are carrying that is not on the list yet, one stack each, so the list follows what your character actually eats and drinks. Bound items are skipped.

**Clear finished** removes the items you now have enough of.

## Reminders

**Remind me at vendors and on login** prints a chat line at login when you are short of anything, and at a vendor that sells something on your list. The reminder runs once per login, including when you turn Shopping on after logging in.

## The export

The Shopping list section, in the Inventory card and on by default, lists what you are short of first, then the recipes you plan to craft, then what is ready.

## Consumable-Connoisseur

If Consumable-Connoisseur is loaded, Dossier copies this character's restock list once, the first time it loads, into an empty shopping list. That copy runs once even if you turn Shopping on after login.

Connoisseur's auto-buying, bank stashing and withdrawing, reputation purchases, consumable upgrades, and starter lists are left out. Dossier records the list. It does not act for you.

## Turning it off

`/dossier off shop` stops the list and the reminders, hides the tab, and leaves the section out of the report. The list stays. `/dossier on shop` brings it back. See [[Options]].
