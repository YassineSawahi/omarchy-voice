# Omarchy Voice

An [Omarchy](https://omarchy.org) bar widget for **[voice foreman](https://github.com/YassineSawahi/voice-foreman)**: Claude on a real phone call over Tailscale. It phones you when a Claude Code session finishes or needs you, and you can call it. The widget reads and flips its switches through voice foreman's control command, `vf-ctl`.

> **Heads-up:** this is only the bar side. Set up [voice foreman](https://github.com/YassineSawahi/voice-foreman) first; until then the widget shows "Reading…".
>
> Use voice foreman from commit [`8644f39`](https://github.com/YassineSawahi/voice-foreman/commit/8644f39ecce0e151dc4bf8a17a8e86eb79b1977d) or later. Before it, every switch flipped from the bar rewrote `~/.config/voice-foreman/settings.json` readable by other users, keypad PIN included. Already installed? `git pull` in your voice foreman clone; the file is locked down the next time a switch is flipped.

## What it shows

- **Bar:** a phone icon that's lit during a call and red if your phone stops answering. Middle-click turns calls to your phone on or off.
- **Panel** (left click):
  - Power switch and current state ("Calls you when a session finishes or needs you", "Calling you at 14:05 about 2 things", quiet hours, …).
  - **Talk at the PC:** the conversation goes through the PC's mic and speakers instead of a phone call, or an ongoing call moves there.
  - **Call my phone:** on/off, and **Always** vs **Only when I'm away**.
  - Whether your phone is answering, and a **Call me now** button.

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
