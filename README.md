# Omarchy Voice

An [Omarchy](https://omarchy.org) bar widget for **[voice foreman](https://github.com/YassineSawahi/voice-foreman)**: Claude on a real phone call over Tailscale. It phones you when a Claude Code session finishes or needs you, and you can call it. The widget reads and flips its switches through voice foreman's control command, `vf-ctl`.

> **Heads-up:** this is only the bar side. Set up [voice foreman](https://github.com/YassineSawahi/voice-foreman) first; until then the widget shows "Reading…".
>
> Use voice foreman from commit [`5d6a98e`](https://github.com/YassineSawahi/voice-foreman/commit/5d6a98e) or later. Before it, the speech service listened on `127.0.0.1:8765`, which another account on the PC could take while the service was down, and then hear you. Before [`531f434`](https://github.com/YassineSawahi/voice-foreman/commit/531f434), setting up the line put its secret address on a command line, which other accounts on the PC can read; before [`746ad5b`](https://github.com/YassineSawahi/voice-foreman/commit/746ad5b), the line answered any address and trusted the caller's From, so another account could call it claiming to be your phone. After `git pull`, delete `~/.config/voice-foreman/line-secret`, run `tools/configure-line.sh` and `systemctl --user restart vf-line vf-foremand`, and call the new address it prints. Before [`6d0c6e7`](https://github.com/YassineSawahi/voice-foreman/commit/6d0c6e7), the brain's read-only allowlist also let it delete or rename git branches; before [`0e3b2b9`](https://github.com/YassineSawahi/voice-foreman/commit/0e3b2b9), versions controlled the line through ports on `127.0.0.1` that any account on the PC can use, and left its settings (keypad PIN included), logs and transcripts readable by other accounts. Already installed? `git pull` in your voice foreman clone, `.venv/bin/pip install jeepney`, then run `tools/install-services.sh` again.

## What it shows

- **Bar:** a phone icon that's lit during a call and red if your phone stops answering. Middle-click turns calls to your phone on or off.
- **Panel** (left click):
  - Power switch and current state ("Calls you when a session finishes or needs you", "Calling you at 14:05 about 2 things", quiet hours, …).
  - **Talk at the PC:** the conversation goes through the PC's mic and speakers instead of a phone call, or an ongoing call moves there.
  - **Call my phone:** on/off, and **Always** vs **Only when I'm away**.
  - Whether your phone is answering, and a **Call me now** button.

## How it works

This widget is only a front end. It never touches the network, your phone or Tailscale. It runs voice foreman's `vf-ctl` and draws the JSON that comes back: every 10 s, and every 3 s while the panel is open or a call is ringing or live. Each button runs `vf-ctl` with an action, which prints the new state straight away.

`vf-ctl` works with voice foreman's own files and services on this PC:

- **Calls on/off** and **Always / Only when I'm away** go into `~/.config/voice-foreman/settings.json`, which voice foreman checks before it calls you.
- **Power** starts or stops voice foreman's user services (the speech service, the line and foremand) with `systemctl --user`. Off frees the GPU.
- **Call me now** and **Talk at the PC** drop a note into voice foreman's spool folder, the same way a Claude Code session does when it finishes.
- **What's happening** (in a call, ringing, the next call) comes from a status file voice foreman rewrites every second. One older than 10 s counts as unknown.
- **Whether your phone answers** comes from the silent check voice foreman runs every 3 minutes.

The call itself never passes through the widget. Voice foreman rings your phone from its own SIP line on this PC, across your tailnet; [its README](https://github.com/YassineSawahi/voice-foreman#how-it-works) explains that part.

```text
 bar widget --runs--> vf-ctl --+--> settings.json -----+
      ^                        +--> spool folder ------+--> voice foreman
      |                        +--> systemctl --user   |         |
      +------- JSON -----------+<-- status.json <------+         |
                                                                 v
                         your phone <== SIP over Tailscale == its SIP line
```

## Install

```bash
omarchy plugin add https://github.com/YassineSawahi/omarchy-voice.git --enable
```

Voice foreman's `tools/install-services.sh` puts `vf-ctl` in `~/.local/bin`, where the widget finds it by itself. If yours lives elsewhere, set the full path to `vf-ctl` in the widget's settings.

## The `vf-ctl` contract

`vf-ctl` with no arguments prints one JSON object. Every action prints the new state the same way:

```json
{
  "power": true, "calls": true, "mode": "always",
  "in_call": false, "ringing": false, "desk": false,
  "quiet_now": false, "pending": 0, "next_call": null, "callback": null,
  "phone": { "reachable": true, "checked": 1793863263 }
}
```

`next_call`, `callback` and `phone.checked` are Unix times. `mode` is `always` or `away`.

| Action | Command |
|---|---|
| Power | `vf-ctl power on` / `vf-ctl power off` |
| Calls to the phone | `vf-ctl calls toggle` |
| When to call | `vf-ctl mode always` / `vf-ctl mode away` |
| Call me now | `vf-ctl call-me` |
| Talk at the PC | `vf-ctl desk toggle` |

## Controls

| Action | Does |
|---|---|
| Left click | Open or close the panel |
| Middle click | Turn calls to your phone on or off |
| Right click | Read the state again |
| `omarchy-shell io.github.yassinesawahi.voice <fn>` | `toggle`, `toggleCalls`, `togglePower`, `callMe`, `toggleDesk`, `refresh`, `close` |

## Remove

```bash
omarchy plugin remove io.github.yassinesawahi.voice
```

Voice foreman itself is removed separately: see [its README](https://github.com/YassineSawahi/voice-foreman#remove).

## License

MIT
