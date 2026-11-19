<div align="center">
  <img src="assets/icon.png" width="120" alt="Streakin icon" />

  <h1>Streakin</h1>

  <p>A private, calm, beautiful place to build habits and think in notes.</p>

  <img src="https://img.shields.io/badge/version-1.0.0--alpha-blue" alt="version" />
  <img src="https://img.shields.io/badge/platform-Android%20%7C%20Windows%20%7C%20Linux-brightgreen" alt="platforms" />
  <img src="https://img.shields.io/badge/offline--first-yes-success" alt="offline-first" />
  <img src="https://img.shields.io/badge/telemetry-zero-lightgrey" alt="zero telemetry" />
</div>

---

## What is Streakin?

Streakin is an **offline-first, privacy-first** personal productivity app built around two pillars: a **habit tracker** and a **notetaker**. Everything stays on your device and is encrypted at rest. There is no account, no cloud and no analytics.

The to-do list, calendar, goals and dashboard exist to serve those two pillars, not the other way around.

> This is the app for **individuals**. Streakin Business, for teams and companies, is a separate product.

---

## Features

### Habits
- Daily habit tracking with flexible schedules (every day, weekdays or custom days)
- One-tap check-in with streak tracking and best-streak history
- **Lock-in streaks:** the moment all of the day's habits are done, the day locks in
- Rest tokens let you take planned rest days without breaking your streak, with a configurable weekly cap
- Weekly and monthly views with completion heatmaps
- Milestone celebrations at 7, 14, 30, 60, 90, 180 and 365 days

### Notetaker
- Block-based rich text editor with checklists and templates
- `[[Wiki links]]` and backlinks between notes
- An interactive graph of how your notes connect
- Folders and tags
- `@date` mentions that appear on the calendar and can remind you
- Fast on-device search (meaning-based search is planned)
- Attachments: images, PDFs, `.docx` and `.pptx`
- **Vaults:** separately locked, separately encrypted spaces for your most private notes

### To-do
- Tasks with due dates, priorities and reminders, shown in several views
- Turn a checklist item in a note into a task; completing one completes the other
- You can choose to count today's flagged tasks toward your lock-in

### Goals
- One primary goal at a time, either dated (with a countdown) or open-ended (counting up)
- Link habits to your goal to see how well your days line up with it

### Dashboard
- Today ring showing daily habit completion
- Lock-in streak counter
- Consistency chart (7, 30 or 90 days)
- At-risk habits: the ones not yet done today
- Quick actions: capture a thought, check in, start a note, enter Zen

### Calendar
- Month view showing habits, tasks and dated notes in one place
- The calendar is a read-only view; it never owns data

### Zen Mode
- **Writing Zen:** a distraction-free writing space
- **Focus Zen:** a guided breathing timer for short focus sessions

### Private Sharing
- Move or share your data between your own devices with encrypted files, with no server involved
- Protect a file with a passphrase, or pair two devices with a short verification code
- Preview everything before importing it

### Privacy & Security
- All data encrypted with AES-256-GCM via SQLCipher
- Password-based unlock using Argon2id key derivation
- A recovery key generated at setup is the only way back in if you forget your password
- Auto-lock when the app goes to the background, with a configurable timeout
- Increasing wait times after repeated wrong passwords
- Screen-capture protection and a privacy shield in the app switcher
- Zero network permissions in release builds

### Desktop
- Lives in the system tray; closing the window locks your session
- Reminders keep working while the app is locked
- Optional launch at login
- Keyboard shortcuts for common actions

---

## Platforms

| Platform | Status |
|---|---|
| Android | ✅ Active development |
| Windows | ✅ Active development |
| Linux | ✅ Active development |
| iOS | 🔜 Planned |
| macOS | 🔜 Planned |

---

## Versions

| Version | Status | Highlights |
|---|---|---|
| **1.0.0-alpha** | 🧪 In testing | Habits, notetaker, vaults, to-do, goals, calendar, dashboard, Zen mode, private sharing, desktop tray and reminders, encrypted local database |
| 1.0.0 | Planned | First public release on Google Play, the Microsoft Store and Linux |
| Later | Planned | iOS and macOS, on-device meaning-based search |

---

## Philosophy

> Fewer, finished features. Every animation has a purpose. Private by construction, not by policy.

Streakin is built on the belief that the best productivity tool is one that stays out of your way, respects your privacy unconditionally, and makes the small daily wins feel meaningful.

---

<div align="center">
  <sub>Built by <a href="https://incantum.in">Incantum</a></sub>
</div>

<div align="center">
  <sub>No telemetry · No cloud · Your data stays yours</sub>
</div>
