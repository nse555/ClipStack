# ClipStack

A tiny native macOS clipboard history manager in the spirit of ClipMenu.
Lives in the menu bar, keeps your last 100 copied items — text, images, and files —
and survives restarts.

## Features

- **Menu bar history** — click the clipboard icon to see your last 100 copied items
  (deduplicated, newest first). Click one to put it back on the clipboard.
- **Text, images, and files** — copied text shows as a snippet; images show a
  thumbnail with their dimensions (screenshots-to-clipboard included); files copied
  in Finder show their icon and name, and restoring them lets you paste the files
  again in Finder. If an app puts both text and an image render on the clipboard
  (e.g. Excel cells), the text wins.
- **Global hotkey** — press **⌘⇧V** anywhere to pop the history menu up at your cursor.
  While the menu is open, press **1–9, 0** to pick the first ten items.
- **Paste Automatically** (optional) — when enabled, picking an item also sends ⌘V to the
  frontmost app. Requires Accessibility permission (you'll be prompted the first time).
- **Launch at Login** toggle.
- **Privacy-aware** — skips anything marked concealed/transient (e.g. copies from
  password managers like 1Password), so passwords never enter the history.
- History persists to `~/Library/Application Support/ClipStack/history.json`
  (image data lives alongside it in `images/`; images over 10 MB are not recorded).

## Build & run

```bash
./build-app.sh
open build/ClipStack.app
```

Requires the Xcode Command Line Tools (Swift 5.9+). The script assembles and ad-hoc-signs
`build/ClipStack.app`. To install permanently, copy it to `/Applications`.

## Notes

- On recent macOS versions the first time ClipStack reads the clipboard you may get a
  "paste from other apps" prompt — choose **Always Allow** so history capture works silently.
- Quit from the menu (`Quit ClipStack`).
