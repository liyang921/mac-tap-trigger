# Example: restart TeamViewer on a remote Mac

The motivating use case for this whole repo. You remote into your Mac with TeamViewer, the app crashes, and now you can't reconnect. With one tap on your iPhone, you re-launch it.

## Install

```bash
./install.sh teamviewer 'open -a TeamViewer'
```

Then on your iPhone, make a Shortcut:

- Action: **New Folder**
- Path: `/Triggers/teamviewer/trigger`
- Service: iCloud Drive

Add it to the home screen. Tap when needed.

## Why `open -a TeamViewer` and not something fancier

`open -a` is enough. If TeamViewer is running, this is a no-op. If it's not, it starts. Either way you get a usable TeamViewer in a few seconds. No need to `pkill` first.

If you want to be paranoid (force-restart even if it's already running but is in a wedged state):

```bash
./install.sh teamviewer 'pkill -x TeamViewer; sleep 1; open -a TeamViewer'
```

## When this won't help you

- If the Mac itself is asleep (not just display-asleep), iCloud sync is paused and the trigger never lands. See the README's "stop the Mac from sleeping" step.
- If iCloud is signed out, broken, or full, ditto.
- If your home internet is down, ditto.

For "Mac is awake and online but the app died" — which is most TeamViewer crashes — this is enough.
