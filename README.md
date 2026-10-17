<p align="center"><img src="docs/icon.png" width="128" alt="Backeddy icon"></p>

<h1 align="center">Backeddy for Mac</h1>

<p align="center">
  <b>Time Machine backups without the guesswork — and a backup server for the whole house, no server skills needed.</b><br>
  <a href="README.pt-BR.md">Português</a> · <a href="README.es.md">Español</a>
</p>

<p align="center"><img src="docs/screenshot.png" width="520" alt="Backeddy main window"></p>

<p align="center"><a href="https://github.com/BackEddy/mac/releases/latest"><b>⬇️ Download Backeddy for Mac</b></a> · macOS 14 Sonoma or later · free</p>

---

## In a nutshell

Your Mac comes with a great backup system, **Time Machine**. The catch is that it works out of sight: you never quite know whether a backup is running, finished or failed. **Backeddy** shows all of that clearly, tells you when something goes wrong, and helps you set up a **backup server** at home — so every Mac in the house (and soon every PC) backs up on its own, with no drive dangling from a cable.

## Before you start: the risks

Backeddy is new and was built by one person with a lot of help from AI. It works in our tests, but it's still an **early preview**. No drama, just honesty — here's what you should know:

- 🧹 **The PC that becomes the server is completely erased.** Use a computer with nothing important on it. The installer warns you twice and asks you to type ERASE, but take your time and double-check which PC and which disks.
- 📦 **Don't make Backeddy the only copy of your stuff, for now.** Photos you can't lose deserve another copy too (a drive in a drawer, a cloud service).
- 💽 **One disk doesn't protect against a broken disk.** With two disks, every file lives on both. With one, if it dies, the backup history goes with it — the files on your Mac are still there, and the server starts over.
- 🪟 **Windows will complain about the installer** (“Windows protected your PC”) because it isn't digitally signed yet. That's expected: click **More info › Run anyway**.
- 🍎 **For now, the server backs up Macs.** It's ready to receive PCs, but the **Backeddy for Windows** app is still on its way.
- 🐢 **The first backup takes a while**: hours if your Mac has a lot on it, longer over Wi-Fi. After that, only what changed is copied.
- 🤝 **No warranty.** It's free and open source, provided as is. If something goes wrong, [tell us](https://github.com/BackEddy/server/issues): that's how it gets better.

## First, a few terms

- **Backup** — a copy of your files kept somewhere else. If your Mac breaks, gets stolen or you delete something by mistake, your files come back from the backup.
- **Time Machine** — the backup built into every Mac (System Settings › General › Time Machine). It copies the whole Mac once, then every hour only what changed. You can “go back in time” and recover a file as it was yesterday or last month.
- **Backup destination** — where Time Machine keeps the copies: an external drive plugged into the Mac, or a server on your home network.
- **Backup server** — a computer that stays on at home and receives backups over the network (Wi-Fi or cable). No need to remember to plug in a drive: your Mac backs up by itself whenever it's home.
- **Backeddy Server** — our free backup server. It turns an old PC (or a Windows PC that's always on) into a Time Machine destination for your Macs and a backup destination for your PCs.
- **Virtual machine** — a “computer inside a computer”. A Windows program pretends to be a whole PC, disk and all, and Backeddy Server runs inside it without touching Windows or your files.
- **Installer USB drive** — a USB stick prepared so a PC can start from it and install Backeddy Server. Backeddy for Mac writes it for you.

## Which one is you?

| You have… | What to do |
| --- | --- |
| An external drive | Plug it into the Mac and pick it in Time Machine. Backeddy follows and confirms every backup. |
| A spare PC or laptop | Set up a **Backeddy Server** with a USB drive (way 1 below). The best option. |
| A Windows PC that's on all the time | Set up **Backeddy Server in a virtual machine** (way 2 below). Windows stays as it is. |

## Setting up a Backeddy Server

In Backeddy for Mac: **File › Set Up a Backeddy Server…** (or the server icon at the top of the window). It asks where the server will run.

### Way 1 — on a computer just for backups

The PC is erased and becomes the server. Works on PCs and laptops from around 2012 onward (64-bit).

1. In Backeddy for Mac, choose **On a computer just for backups**, plug in a USB drive of 4 GB or more and click **Continue**. The app downloads the latest version, verifies it and writes it (everything on the USB drive is erased).
2. Plug the USB drive into the PC, turn it on and pick the drive in the boot menu — usually **F12**, F11, F8 or Esc right after power-on.
3. Follow the screen: choose how to use the disks, the server's name and password. It takes about 5 minutes. At the end, unplug the USB drive and the PC restarts as a server.

Tips: a **network cable** is much faster than Wi-Fi (without a cable, the installer offers Wi-Fi). With **two drives**, the server keeps every file on both: if one dies, nothing is lost. An old **laptop** is great: it uses little power and its battery works as a UPS.

### Way 2 — in a virtual machine, on a Windows PC

Windows and its files stay untouched; the server runs in a virtual machine. The PC has to stay on.

1. On the Windows PC, download **[Instalar-Backeddy.exe](https://github.com/BackEddy/server/releases/latest/download/Instalar-Backeddy.exe)** and open it. Windows will say “Windows protected your PC”: click **More info › Run anyway**. *(Why? The installer isn't digitally signed yet — we're working on it. It's open source and built automatically by GitHub from that code.)*
2. Choose the disk and the backup size. The installer sets everything up by itself (Hyper-V, or VirtualBox on Windows Home).
3. The setup opens in a window, just like the USB one. At the end, click **Eject USB drive** and you're done.

### How much space?

Plan for **twice what your Macs and PCs use**: one full copy plus room for history. Two Macs using 250 GB each → 1 TB. Backeddy for Mac shows how much your Mac uses when you set up the server.

### After setting it up

On your Mac, open **Backup destination › Set up with Backeddy Server…**: the app finds the server on your network, asks for the password and sets up Time Machine for you — no System Settings needed. The **Server** tab shows whether all is well; if the server has a problem (a failing disk, say), it **beeps** until someone notices, and you can stop the beeping from your Mac.

## What the app does

- **Back Up Now** — starts a backup and keeps your Mac awake *only while it runs*. The display can still turn off (there's a **Turn Off Display** button).
- **Real progress** — percentage, data sent, speed, time left, Wi-Fi or cable, and phases without a percentage (like “Cleaning up old backups”) explained.
- **Verified result** — ✅ only when a new backup really exists at the destination; ❌ with the last good backup and the error, if not.
- **When it finishes** — let your Mac sleep as usual, or put it to sleep right after the backup.
- **Local snapshots** — copies Time Machine keeps on the Mac itself that hold on to space; see how many there are and delete them to free space right away.
- **Turbo mode** — lifts the speed limit macOS puts on backups; returns to normal by itself.
- **Cleanup** — old WhatsApp media and big caches (browsers, Xcode, Homebrew, npm, AI models…).
- **Set up a Backeddy Server**, **set up Time Machine** on it and follow everything in the **Server** tab (see above).
- **Menu bar icon**, **overdue backup reminder**, **history** and **help**, in **English, Portuguese and Spanish**.

Backeddy Server (setup, server screen, alerts and panel) speaks **English, Portuguese and Spanish**: you pick the language on the first setup screen.

Every action that deletes something shows a warning and asks you to type a confirmation word.

## Install

1. Download the latest `.dmg` from **[Releases](https://github.com/BackEddy/mac/releases/latest)** (signed and notarized by Apple).
2. Open it and drag **Backeddy** to Applications.
3. On first launch, turn on **Full Disk Access** for Backeddy (System Settings › Privacy & Security › Full Disk Access). Without it, macOS won't let it read the backup list.

## Quick questions

- **Do my files go to the internet?** No. Everything stays at home: on your drive or your server. The app only goes online to check for updates and to download Backeddy Server.
- **Do I need to know Linux or servers?** No. Backeddy Server installs through simple screens, with a mouse, and then takes care of itself (security updates included).
- **What if a server disk breaks?** With two disks, nothing is lost. With one, your files are still on your Macs and the server starts backing up again. Either way, the server warns you (it beeps and shows up in the app).
- **Does it work with Windows?** The server is ready to receive PC backups, but the **Backeddy for Windows** app that makes them is still on its way. For now, the server keeps your Macs' backups.

## Build from source

You need Xcode or the Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/BackEddy/mac.git
cd mac
./build.sh
```

## Why isn't it on the Mac App Store?

App Store apps run in a sandbox, which blocks what Backeddy needs: running `tmutil`, Full Disk Access, administrator actions and writing USB drives. That's why it's distributed here, signed and notarized by Apple.

## Security

Backeddy uses Apple's own tools (`tmutil`, `pmset`, `diskutil`, `authopen`). The administrator password is asked for by macOS; your server's password is kept in the macOS Keychain. Deleting snapshots, media or caches can't be undone: keep your backups current. Provided as is, without warranty (see [LICENSE](LICENSE)).

## Support

Backeddy is free and open source. If it saved your files, a thank-you donation keeps the project going ❤️

- 🇧🇷 **PIX:** `pix@xwa.com.br` (or **Support the project** inside the app for the QR code)
- 🌎 **[GitHub Sponsors](https://github.com/sponsors/lordironballs)**
- ⭐ Starring the repo and telling friends helps a lot too!

## License

[MIT](LICENSE) © 2026 [Eddy Antonini](https://eddyantonini.com.br) · Part of the [Backeddy](https://github.com/BackEddy) family — [Backeddy Server](https://github.com/BackEddy/server) is open source too.
