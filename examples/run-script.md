# Example: kick off a long-running script

The trigger runner `eval`s your command but doesn't wait for it, doesn't stream output anywhere visible, and inherits a minimal launchd shell environment. For anything beyond `open -a Foo`, a few practical patterns matter.

## Basic pattern

```bash
./install.sh nightly-build 'cd ~/code/myapp && ./build.sh > /tmp/nightly-build.log 2>&1'
```

Tap the Shortcut, build starts. Check on it later (over SSH, screen sharing, or in person):

```bash
tail -f /tmp/nightly-build.log
```

## Things that bite people

**Always redirect both streams.** `> /tmp/foo.log 2>&1` (or `&> /tmp/foo.log`). If you don't, launchd sends them to per-trigger files at `/tmp/<name>-trigger.{out,err}.log`, which works, but mixing your script's output with the trigger's own log lines makes it harder to read.

**`$PATH` is minimal.** A launchd-spawned shell doesn't load your shell profile. If your script depends on `node`, `python`, `cargo`, etc. installed via Homebrew, either use full paths or prepend Homebrew to `PATH`:

```bash
./install.sh build 'PATH=/opt/homebrew/bin:$PATH cd ~/code/app && npm run build > /tmp/build.log 2>&1'
```

**Working directory is `/`.** Always `cd` first, or use absolute paths everywhere.

**Secrets — don't pass them in argv.** They'd end up in the plist (which lives at `~/Library/LaunchAgents/local.<name>-trigger.plist`, world-readable). Source from a file instead:

```bash
./install.sh deploy 'source ~/.config/deploy.env && ~/code/deploy.sh > /tmp/deploy.log 2>&1'
```

**Long-running commands.** The trigger runner doesn't background your command, but launchd is fine with the runner taking a long time. If the script might run for minutes-to-hours and you'd rather it survive even if launchd reaps the runner, use `nohup` + `&`:

```bash
./install.sh long-job 'nohup ~/code/long.sh > /tmp/long.log 2>&1 &'
```

## Per-tap arguments?

The framework as designed has no way to pass data from the iPhone tap to the command — the tap creates a folder, period. If you need parameters, install multiple triggers (one per parameter combination) or have the command read from a config file your iPhone updates separately (e.g., a different iCloud file the script `cat`s when fired).
