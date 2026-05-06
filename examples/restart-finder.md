# Example: restart Finder

Finder occasionally wedges — a network mount times out, a Smart Folder query stalls, prefs cache goes sideways — and the GUI Force Quit dialog can be the thing that's stuck. Sending the kill from outside the GUI fixes it.

## Install

```bash
./install.sh restart-finder 'killall Finder'
```

iPhone Shortcut:
- Action: **New Folder**
- Path: `/Triggers/restart-finder/trigger`
- Service: iCloud Drive

`killall Finder` doesn't really kill it permanently — `launchd` notices Finder is gone and respawns it within a second.

## When this is most useful

You're remoted into your Mac, Finder is wedged, and the wedge is blocking the dialog you'd use to fix it from inside the screen-sharing session. Tap the iPhone Shortcut from outside that session — Finder dies, comes back clean, you're unblocked.

## Variation: harder restart

If `killall Finder` doesn't unstick it (Finder has corrupt cached prefs):

```bash
./install.sh nuke-finder 'killall -9 Finder; killall -9 cfprefsd'
```

`cfprefsd` is the prefs daemon; killing it forces all apps to re-read prefs from disk, which sometimes clears the wedge.
