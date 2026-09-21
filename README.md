# omarchy-brainfm

A bar icon for [brain.fm](https://my.brain.fm/) on [Omarchy](https://omarchy.org/). Click to launch or focus your brain.fm browser tab, or open a popup with now-playing info and transport controls.

This is a launcher + MPRIS remote, not a browser-automation bot: it doesn't log you in, pick a mood, or start playback on its own. You do that once in the browser like normal; this plugin gives you a bar icon to get back to it and control it afterward.

## What it does

- **🧠 icon in the bar.** Always visible, like the volume or network icon.
- **Left-click** opens a popup: track title/artist, transport controls (prev/play-pause/next), and an "Open brain.fm" button.
- **Right-click** skips the popup and directly focuses your existing brain.fm browser window, or opens `https://my.brain.fm/` if none is open.
- **Playback controls are real**, driven by [MPRIS](https://specifications.freedesktop.org/mpris-spec/latest/) — the standard Linux media-control protocol. Chromium exposes brain.fm's play/pause/next/previous over MPRIS on its own (no scraping involved), and this plugin is just a client of that, using the same mechanism Omarchy's own media widget uses.
- **A small animated level meter** stands in for cover art, driven by real-time system audio output level (via PipeWire, same API Omarchy's own mic meter uses). This isn't decorative-only guesswork: brain.fm's web player sets Media Session artwork with an empty `sizes` field, which Chromium's MPRIS integration silently rejects — so the "real" artwork Chromium would otherwise expose is just its own logo. Showing a level meter beats showing a wrong picture.

## Requirements

- [Omarchy](https://omarchy.org/) (Hyprland + the Omarchy shell)
- A default browser that exposes MPRIS for its media sessions (Chromium and Chromium-based browsers do this on Linux; this is what Omarchy ships by default)
- A brain.fm account, logged in once in your normal browser — this plugin doesn't handle login

## Install

```
omarchy plugin add https://github.com/revans/omarchy-brainfm.git --enable
```

Or manually:

```
git clone https://github.com/revans/omarchy-brainfm.git ~/.config/omarchy/plugins/rre.brainfm
omarchy plugin enable rre.brainfm
```

If you also have Omarchy's built-in Media widget (`omarchy.media`) enabled, you'll get two now-playing indicators in the bar. Disable it if you only want this one:

```
omarchy plugin disable omarchy.media
```

## Notes

- The popup uses `triggerMode: "hover"` rather than the shell's default click-outside-to-dismiss, specifically so that screenshot tools (which grab focus to let you select a region) don't close it mid-shot. The trade-off: clicking elsewhere on the desktop won't auto-close it — click the 🧠 icon again to close it.
- Nothing about this plugin is brain.fm-specific under the hood beyond the launch URL and window-matching pattern — it follows whatever Chromium reports as the active MPRIS player. If you're playing something else louder than brain.fm at the same time, that's what you'll see.
