<p align="center"><img src="docs/icon.png" width="128" alt="Force TM icon"></p>

<h1 align="center">Force TM</h1>

<p align="center">
  <b>A friendly dashboard to force, follow and verify Time Machine backups on macOS — and free up space safely.</b><br>
  <a href="README.pt-BR.md">Português</a> · <a href="README.es.md">Español</a>
</p>

<p align="center"><img src="docs/screenshot.png" width="520" alt="Force TM main window"></p>

---

## What it does

- **Back Up Now** — starts a Time Machine backup and keeps your Mac awake *only while it runs* (on power or battery). The display can still turn off, and there's a **Turn Off Display** button.
- **Real progress** — same percentage as the Time Machine menu, plus data sent, data analyzed, speed, time remaining, Wi-Fi vs. cable, and a clear view of phases without progress (like “Thinning old backups”).
- **Verified result** — compares the destination's backup list before and after: ✅ only when a new backup really exists, ❌ with the last good backup and Time Machine's errors otherwise.
- **Optional sleep when done** — your Mac goes to sleep 30 s after the backup ends (cancelable).
- **Local snapshots** — see how many there are and delete them to get your space back right away.
- **Turbo mode** — temporarily lifts macOS's throttling of Time Machine; reverts by itself when the backup ends.
- **Cleanup** — WhatsApp for Mac media (by age) and large caches (browsers, Gradle, Xcode, Homebrew, npm, pip, AI models…).
- **Menu bar icon**, **overdue backup notifications**, **history**, built-in **help**.
- Available in **English, Portuguese and Spanish**.

Every action that deletes files shows a warning and asks you to type a confirmation word.

## Download

Get the latest signed and notarized `.dmg` from **[Releases](https://github.com/lordironballs/force-tm/releases)**, open it and drag **Force TM** to Applications.

Requires **macOS 14 Sonoma or later**.

On first launch, turn on **Full Disk Access** for Force TM (System Settings › Privacy & Security › Full Disk Access) so it can read the backup list and the WhatsApp folder.

## Build from source

You need Xcode or the Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/lordironballs/force-tm.git
cd force-tm
./build.sh
```

The app is compiled, installed to `~/Applications/Force TM.app` and opened.

## Why not the Mac App Store?

App Store apps must run in a sandbox, which blocks what Force TM needs: running `tmutil`, Full Disk Access, administrator actions (deleting snapshots, turbo mode) and cleaning other apps' folders. That's why it's distributed here, signed and notarized by Apple.

## Safety

Force TM uses only Apple's own tools (`tmutil`, `pmset`, `sysctl`). It never sees or stores your password — macOS asks for it directly. Deleting local snapshots, WhatsApp media or caches can't be undone: keep your backups up to date. Provided as is, without warranty (see [LICENSE](LICENSE)).

## Apoie / Support / Apoya

Force TM is free. If it helped you, a thank-you donation keeps the project going ❤️

- 🇧🇷 **PIX:** `pix@xwa.com.br` (or use **Support the project** inside the app for the QR code)
- 🌎 **[GitHub Sponsors](https://github.com/sponsors/lordironballs)**
- ⭐ Starring the repo and sharing the app helps a lot too!

## License

[MIT](LICENSE) © 2026 [Eddy Antonini](https://eddyantonini.com.br)
