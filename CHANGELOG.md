# Changelog

## 2.1.1

- Fixed: the reload prompt kept popping up after joining a group (group mode). Right after a reload the group roster is not known yet, so the zone's addon set was asked for, then the group's again after that reload, and so on. The saved group type now counts until the roster has loaded.
- The reload prompt now only appears when the addon set is not loaded yet; if the addons already match (e.g. the 5-player set), nothing is asked.
- "Not now" is respected by group events and combat end; only your own actions (Apply, buttons) ask again.
- Only one reload prompt per zone type and set, even when several events fire at once.

## 2.1.0

First public release.

- Graphics profiles per zone type (open world, dungeon, Mythic+, raid, delve, PvP) with Live Preview.
- Addon sets per zone type with reload prompt.
- Manual changes in Blizzard's addon list are detected: keep, save to set, or undo.
- Addon Sets page follows the set in use; "Edit Set In Use" / "Reload Now" buttons.
- Optional group mode: addon set follows your group's Group Finder activity.
