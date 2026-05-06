# mac-tap-trigger

**Tap a Shortcut on your iPhone → run any command on your Mac, even when you're not there.**

No SSH, no port forwarding, no third-party server. The only moving parts are iCloud Drive (which you already have) and a launchd watcher (which is already running).

```
iPhone Shortcut ─► creates folder in iCloud Drive ─► syncs to Mac
                                                          │
                                                          ▼
                                            launchd WatchPaths fires
                                                          │
                                                          ▼
                                              your shell command runs
```

## Why this exists

The original itch: you remote into your Mac with TeamViewer (or VNC, or anything), the app crashes, now you can't reconnect. You need something that lets you, from anywhere, restart it. SSH would work — but most people don't keep a port open to their home Mac.

The pattern generalizes far beyond TeamViewer. Anything you can run from a shell, you can now run with one tap from your iPhone:

- **Restart a crashed app** (`open -a TeamViewer`, `open -a "Parallels Desktop"`)
- **Wake a sleeping service** (`brew services restart postgresql`)
- **Kick off a long task** (`cd ~/projects/foo && ./nightly.sh`)
- **Toggle Mac state** (`shortcuts run "Toggle Do Not Disturb"`)
- **Send yourself something** (`pbpaste | curl ...` to push your clipboard somewhere)

You install one tiny framework, then add per-task triggers as you need them.

## Requirements

- macOS (tested on Sonoma+; should work on older)
- iCloud Drive enabled and signed in on both your Mac and your iPhone
- The Mac is on AC power and stays awake (this matters — see "Sleep" below)

## Install

```bash
git clone https://github.com/<your-username>/mac-tap-trigger
cd mac-tap-trigger
./install.sh teamviewer 'open -a TeamViewer'
```

That's it for the software side. The installer prints three one-time manual steps that macOS makes you do by hand:

### 1. Grant `/bin/bash` Full Disk Access

System Settings → Privacy & Security → Full Disk Access → `+` → press `Cmd-Shift-G` → type `/bin/bash` → Open → Add.

Why: launchd-spawned bash runs in a TCC sandbox by default and **cannot read iCloud Drive** without this. Skip this step and your trigger silently does nothing.

### 2. Stop the Mac from sleeping on AC power

```bash
sudo pmset -c sleep 0
```

Why: when the Mac sleeps, iCloud sync pauses. iPhone uploads the trigger folder, but it never lands on disk, so launchd never fires. Display sleep is fine — only system sleep breaks the chain.

(Lid-closed sleep on a laptop is a separate setting. If you want lid-closed-but-running, also: `sudo pmset -c disablesleep 1` and don't forget to plug in an external display or use `caffeinate -d`. This is a "your setup" problem.)

### 3. Create the iPhone Shortcut

In the Shortcuts app on iPhone:

1. New Shortcut, name it whatever you want ("Restart TeamViewer" etc.)
2. Add one action: **"New Folder"**
3. Set:
   - **Path**: `/Triggers/<your-trigger-name>/trigger`  (e.g. `/Triggers/teamviewer/trigger`)
   - **Service**: iCloud Drive
4. Add to home screen.

Tap. Wait 5–15 seconds for iCloud sync. Done.

## Adding more triggers

Same `install.sh`, different name:

```bash
./install.sh restart-finder 'killall Finder'
./install.sh kick-off-build 'cd ~/code/myapp && ./build.sh > /tmp/build.log 2>&1'
```

Each trigger gets:
- its own iCloud subfolder (`Triggers/<name>/`) — different triggers don't fire each other
- its own LaunchAgent
- its own log at `/tmp/<name>-trigger.log`

Make a separate iPhone Shortcut for each (path: `/Triggers/<that-name>/trigger`).

## Uninstall a trigger

```bash
./uninstall.sh teamviewer
```

This removes the LaunchAgent. The iCloud folder, the shared runner script, and old log files are left in place — delete manually if you want.

## Troubleshooting

The single most useful command:

```bash
cat /tmp/<your-trigger-name>-trigger.log
```

Every fire writes a line. If there's no line, the watcher didn't fire.

### iPhone says it ran, but nothing happens on Mac

In order:

1. **Did the folder reach iCloud?**
   ```bash
   ls "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Triggers/<name>/"
   ```
   If empty: iCloud sync is broken (Mac asleep? signed out? full?).

2. **Is the LaunchAgent loaded?**
   ```bash
   launchctl print "gui/$(id -u)/local.<name>-trigger" | head -5
   ```
   "Could not find service" → re-run `./install.sh`.

3. **Did the script run but fail?**
   ```bash
   tail /tmp/<name>-trigger.log /tmp/<name>-trigger.err.log
   ```
   "Operation not permitted" → `/bin/bash` lost Full Disk Access; re-grant.

### Folder was created but TeamViewer/$your-app didn't open

Run the action manually to make sure the command itself works:

```bash
eval 'open -a TeamViewer'   # or whatever you passed to install.sh
```

If that works but the trigger doesn't, the problem is in the launchd → script handoff. Check both `.log` and `.err.log`.

### Manually test the whole chain (without the iPhone)

```bash
mkdir "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Triggers/<name>/test"
# wait 1-2 seconds
tail /tmp/<name>-trigger.log
```

## Why this architecture (paths I tried that didn't work)

The lazy-looking iCloud-folder design isn't the obvious choice. It's what's left after several more direct paths turned out to be dead ends:

1. **iOS 26 "Run Shortcut on Mac"** — no longer supported in iOS 26. The older "Run on Mac" routing was removed.
2. **iPhone running a Mac Shortcut directly** — iOS rejects "Run Shell Script" actions on iPhone ("not supported on this device").
3. **launchd `KeepAlive`** (Mac auto-restarts the app on crash) — works, but it's a 24/7 babysitter rather than an on-demand trigger. You can't choose *when* to fire it.
4. **iCloud Drive + Shortcuts "Save File"** — iOS 26's "Save File" action expects file-typed input, won't accept arbitrary text.
5. **iCloud Drive + "New Folder"** — works. The `New Folder` action takes a path, no file content needed.

A few specific gotchas this design fixes:

- **launchd fires before iCloud finishes writing the folder contents.** Solved by polling for up to 10s in the runner script before giving up.
- **launchd-spawned bash can't read iCloud Drive.** Solved by granting `/bin/bash` Full Disk Access (TCC requirement).
- **`rm -f` doesn't remove directories.** The trigger payload is a folder, so cleanup is `rm -rf`.

## How it works under the hood

For each trigger you install:

| Path | What |
|---|---|
| `~/.local/bin/mac-tap-trigger.sh` | Shared runner, same for all triggers. Polls the watch folder, then `eval`s the command. |
| `~/Library/LaunchAgents/local.<name>-trigger.plist` | Per-trigger LaunchAgent. `WatchPaths` points at one iCloud subfolder; `ProgramArguments` passes the name + command to the runner. |
| `~/Library/Mobile Documents/com~apple~CloudDocs/Triggers/<name>/` | The iCloud subfolder this trigger watches. |
| `/tmp/<name>-trigger.log` | What this trigger has done lately. |

When the iPhone Shortcut creates `Triggers/<name>/trigger`, iCloud syncs it to the Mac, the change to `Triggers/<name>/` fires the LaunchAgent, the LaunchAgent runs the runner with `<name>` and `<command>` as argv, the runner waits for the folder to actually appear, runs `eval "$command"`, and `rm -rf`s the folder so the next tap starts clean.

## License

MIT — see [LICENSE](LICENSE).

## Contributing

PRs welcome, especially:
- Tested examples for other use cases (add a markdown file under `examples/`)
- Compatibility notes for older macOS / iOS versions
- A way to do this without iCloud Drive (Dropbox? a local web hook? something else?)
