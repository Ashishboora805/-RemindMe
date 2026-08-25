<!-- # Glass Notes — Offline-First Notes & Reminders (iOS + Android, Flutter)

A fully offline notes + reminders app with a Liquid Glass / glassmorphism UI,
built with Flutter, Drift (SQLite), Riverpod, GoRouter, and
flutter_local_notifications.

Nothing here talks to the network. There is no backend, no Firebase, and no
account system — every read and write is local disk I/O.

---

## 1. Quick start

The Drift code generator output (`*.g.dart`) is **not** checked in, so the
project does not compile until you run `build_runner` once:

```bash
flutter pub get
dart run build_runner build            # generates database.g.dart + the DAO mixins
flutter run                            # -d <ios-simulator|android-emulator|device>
```

Re-run `build_runner` after editing anything under `lib/database/tables/` or
adding a `@DriftAccessor` DAO.

Verify a checkout with:

```bash
flutter analyze     # expected: No issues found!
flutter test        # expected: All tests passed! (32 tests)
```

### Toolchain

Verified against **Flutter 3.47.1 / Dart 3.13.1**.

### Dependency constraints that are load-bearing

Don't relax these without re-running a real device build — each one was pinned
to fix a build that actually failed:

- **`drift_dev` / `build_runner`** must be new enough that the `analyzer` they
  pull in can parse your Dart SDK's language version. An older pair fails with
  `Exception: Missing implementation of visit…` from inside the analyzer, and
  `build_runner` then hangs instead of exiting. If codegen breaks after a
  Flutter upgrade, bump these first.
- **`record` ≥ 7** — the 5.x line resolves a `record_linux` that no longer
  implements `record_platform_interface`, which breaks the Dart kernel compile
  even when the build target is Android or iOS.
- **`flutter_timezone` ≥ 5** — 3.x sets a Kotlin JVM target of 1.8 while the
  current AGP compiles its Java at 11, so Gradle rejects it with
  "Inconsistent JVM-target compatibility".
- **`file_picker` ≥ 12, and with it `share_plus` ≥ 13 and
  `flutter_secure_storage` ≥ 11** (they form one resolution chain).
  `file_picker` 8.x hardcodes `compileSdk 34`, which fails the AAR metadata
  check against `flutter_plugin_android_lifecycle` — that plugin now requires
  its dependents to compile against API 36+.

Two packages are deliberately **absent**:

- `riverpod_generator` / `riverpod_annotation` — every provider here is written
  by hand, so the generator only added a second, more fragile analyzer to the
  codegen step.
- `google_fonts` — it downloads font files over HTTP on first use, and this app
  ships without the `INTERNET` permission. The download always failed and every
  label fell back to a generic monospace face. `AppTypography` now uses the
  platform UI font (SF Pro on iOS, Roboto on Android), which is what the design
  targets anyway. To use a specific family, bundle the `.ttf` under `assets/`
  and set `AppTypography._fontFamily`.

Flutter currently warns that `flutter_timezone` and `share_plus` still apply the
Kotlin Gradle Plugin. That is a warning today and will become a build failure in
a future Flutter release; it is fixed upstream in those plugins, not here.

---

## 2. What's implemented vs. what's scaffolded for you to extend

**Fully implemented, real (non-stubbed) logic:**
- SQLite schema (Drift) for projects, notes, reminders, attachments, tags — with foreign keys, cascades, and a migration hook
- Project CRUD, archive, accent colors, per-project stats (live — the counters re-query on every note/reminder change)
- Text notes with debounced auto-save, pin, favorite, soft-delete (trash); an untouched new note is discarded rather than left as an empty row
- Image notes: camera/gallery picking, local file storage, full-screen viewer
- Voice notes: real recording (`record` package) with pause/resume/stop, local playback (`just_audio`)
- Reminders: one-time / daily / weekly (single + multi-weekday) / monthly / custom (every N days/weeks), with create **and** edit
- Local notification scheduling on **both iOS and Android**, with Complete / Snooze / Open actions wired end-to-end — including from a cold launch and from a killed app (see §6)
- Snooze, complete, uncomplete, cancel, delete, and boot-time re-scheduling of all active reminders
- Global offline search across projects/notes/reminders
- Trash with restore, permanent delete, and a 30-day purge that runs at startup
- ZIP backup/export and import with format validation and merge/replace strategies
- Settings: theme (light/dark/system), storage breakdown + cache clearing, biometric app lock
- Unit tests for the database layer, reminder recurrence/snooze/complete logic, and backup import/export/validation, plus widget tests for the glass design-system components

**Scaffolded but intentionally left thin** (same patterns as above — extend directly):
- Rich text formatting / checklists inside the text note editor (currently plain text with title + content)
- Multi-image attach flow inside the note *editor* itself (image add currently lives on the note detail screen)
- Onboarding/splash screens (the app boots straight to Home)
- Notification sound picker UI — the data model, the iOS `.caf` lookup, and the per-sound Android channel are already implemented (see `Reminder.sound` and `assets/sounds/README.md`); only the picker UI is missing
- Tag management UI (the `tags` / `note_tags` tables and DAO methods exist)
- Archived-project browsing UI (`archivedProjectsProvider` exists and is unused)
- Integration tests on a real device/emulator

---

## 3. Folder structure

```
lib/
  app/                       # App shell, theme, router, lock gate, route-error screen
  core/
    providers/               # App-wide Riverpod providers (DB, services)
    widgets/                 # GlassCard, GlassButton, GlassTextField, GlassBottomSheet
  database/
    tables/                  # Drift table definitions
    dao/                     # Drift DAOs (typed queries)
    database.dart            # AppDatabase, schema version, migrations
  services/                  # NotificationService, ReminderService, AttachmentService,
                             # AudioService, ImageService, AuthenticationService,
                             # StorageService, BackupService, SearchService
  features/
    projects/  notes/  reminders/  attachments/  search/  trash/  settings/
      data|providers|presentation/screens|presentation/widgets
  main.dart
test/
  database_test.dart
  reminder_service_test.dart
  backup_service_test.dart
  widget_test.dart
ios/
  Runner/Info.plist          # Permission strings, background modes
  Runner/AppDelegate.swift   # UNUserNotificationCenter delegate registration
android/
  app/src/main/AndroidManifest.xml   # Permissions + flutter_local_notifications receivers
  app/build.gradle.kts               # Core library desugaring, minSdk floor
  app/src/main/res/drawable/ic_notification.xml
```

---

## 4. Database schema

Six Drift tables: `projects`, `notes`, `reminders`, `attachments`, `tags`,
`note_tags`. Foreign keys cascade project→notes→(attachments, reminders via
noteId `setNull`), and note deletion cascades attachments. See
`lib/database/tables/*.dart` for exact column definitions.

`repeatValue` on `reminders` stores small JSON configs, e.g.:
- Weekly, multiple days: `{"weekdays":[1,3,5]}` (1 = Monday … 7 = Sunday)
- Custom: `{"unit":"day","interval":2}` or `{"unit":"week","interval":3}`

### Migrations

Bump `kSchemaVersion` in `lib/database/database.dart` and add a branch inside
`onUpgrade` in the same file:

```dart
onUpgrade: (m, from, to) async {
  if (from < 2) {
    await m.addColumn(notes, notes.someNewColumn);
  }
},
```

Then re-run `dart run build_runner build`.

---

## 5. How reminder scheduling actually works

1. `ReminderEditorScreen` collects title/description/date/repeat and calls
   `ReminderService.createReminder(...)` (or `updateReminder(...)` when
   editing).
2. `ReminderService` derives a **stable 32-bit notification id** from the
   reminder's UUID (`reminderId.hashCode & 0x7FFFFFFF`) and persists it on the
   row, so re-scheduling the same reminder is always idempotent.
3. Repeat types split into two strategies:

   | Repeat | Strategy |
   | --- | --- |
   | `none` | single `zonedSchedule` |
   | `daily` | OS-native recurrence, `matchDateTimeComponents: time` |
   | `weekly`, one weekday | OS-native recurrence, `dayOfWeekAndTime` |
   | `weekly`, several weekdays | one-shot + advance-on-fire |
   | `monthly` | OS-native recurrence, `dayOfMonthAndTime` |
   | `custom` (every N days/weeks) | one-shot + advance-on-fire |

   The two OS-native-repeat cases have no equivalent in
   `flutter_local_notifications`, so those reminders are scheduled one
   occurrence at a time; `ReminderService.advanceRecurrence` computes the next
   slot and re-arms when the user completes or the app next boots.
4. `NotificationService` **cancels before scheduling** the same notification
   id, which is what makes every call idempotent — calling
   `createReminder`/`updateReminder` twice never doubles up notifications.
5. `nextOccurrenceAfter` handles every repeat type and always returns a time
   strictly in the future, correctly rolling past a month with fewer days than
   the anchor (a reminder anchored on the 31st fires on the 30th/28th) and
   jumping straight to the right slot for a cadence that was missed for months.
6. On boot, `_runBootTasks` in `main.dart` calls
   `rescheduleAllActiveOnBoot()`, which re-arms every active, non-completed
   recurring reminder and rolls any missed occurrence forward. A one-time
   reminder whose time has passed is left alone so the UI can show it as
   overdue.
7. Timezones: `NotificationService` resolves the device's real IANA zone via
   `flutter_timezone` before scheduling anything. Without this the `timezone`
   package defaults to UTC and every reminder fires at the wrong wall-clock
   time.

---

## 6. Notification actions when the app is backgrounded or killed

Complete / Snooze / Open are all declared as **foreground** actions
(`DarwinNotificationActionOption.foreground` on iOS, `showsUserInterface: true`
on Android). That is a deliberate trade-off: acting on a reminder means writing
to SQLite *and* arming the next occurrence, and a background action runs in a
Dart isolate that cannot reach the app's open database. A snooze handled purely
in the background would update nothing and never fire again — so the app is
brought forward and the real `ReminderService` does the work.

Three delivery paths are handled:

- **App alive (foreground or backgrounded)** —
  `onDidReceiveNotificationResponse` calls straight into `ReminderService`.
- **App cold-launched by the notification** —
  `NotificationService.handleAppLaunchNotification()` reads
  `getNotificationAppLaunchDetails()` during boot and replays the action once
  the handler is registered.
- **Anything that still lands in the background** (a dismissal, or an action the
  OS chooses not to foreground) — `notificationBackgroundHandler` appends it to
  `Documents/pending_notification_actions.jsonl`, and
  `NotificationService.drainPendingActions()` replays and clears that queue on
  the next launch. This is why `ActionBroadcastReceiver` is declared in
  `AndroidManifest.xml`.

---

## 7. Platform configuration

### iOS

- `Info.plist` carries `NSCameraUsageDescription`,
  `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`,
  `NSMicrophoneUsageDescription`, `NSFaceIDUsageDescription`,
  `UIBackgroundModes: audio`, and file-sharing keys so backups can be pulled out
  via the Files app.
- `AppDelegate.swift` sets `UNUserNotificationCenter.current().delegate = self`,
  without which notification taps never reach Dart.
- Custom notification sounds must be added to the **Xcode** target's *Copy
  Bundle Resources* as `.caf` files — Flutter assets are not visible to the OS
  notification system. See `assets/sounds/README.md`.

Building:

```bash
flutter build ios --release
# then open ios/Runner.xcworkspace in Xcode to archive/sign/upload
```

Set your Team and Bundle ID in Xcode first. (iOS builds require macOS; they
cannot be produced on Windows or Linux.)

### Android

- `minSdk` is floored at **24** (`record`, `local_auth`, and `just_audio`
  require ≥ 23; 24 leaves headroom).
- **Core library desugaring is enabled** in `android/app/build.gradle.kts`.
  `flutter_local_notifications` needs `java.time` on older releases; without it
  the app compiles but scheduling fails at runtime.
- Permissions declared: `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`,
  `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `RECORD_AUDIO`, `CAMERA`.
  `SCHEDULE_EXACT_ALARM` is user-grantable and requested lazily via
  `requestExactAlarmsPermission()`. If it is denied, reminders still fire but
  the OS chooses a window around the requested time rather than hitting it
  exactly. (`USE_EXACT_ALARM` is deliberately *not* declared — it requires a
  Play Console policy declaration.)
- `ScheduledNotificationBootReceiver` re-arms reminders after a reboot or app
  update; `ActionBroadcastReceiver` delivers action-button taps.
- The notification small icon is `res/drawable/ic_notification.xml`, a flat
  white silhouette. Android strips colour from small icons, so using the
  launcher icon here renders as a white square.
- Custom sounds go in `android/app/src/main/res/raw/`. `NotificationService`
  creates one channel per sound name, because Android ≥ 8 takes the sound from
  the channel and a channel's sound cannot be changed after creation.
- `kotlin.incremental=false` is set in `android/gradle.properties`. Kotlin's
  incremental compiler memory-maps its cache files and on Windows regularly
  fails to release them, failing the build with "Could not close incremental
  caches in …/caches-jvm/jvm/kotlin" for whichever plugin module hit it. Plugin
  sources don't change between builds, so nothing is lost. Remove it if you
  build on Linux/macOS.
- Gradle needs real headroom on the drive holding `~/.gradle` — a full disk
  surfaces as confusing Kotlin cache-corruption errors long before it says
  "not enough space".
- Change `applicationId` in `android/app/build.gradle.kts` (currently
  `com.example.notes`) and add a real signing config before shipping.

```bash
flutter build apk --release        # or: flutter build appbundle --release
```

---

## 8. How offline storage works

- **Structured data** (projects, notes, reminders, attachment metadata, tags)
  lives in a single SQLite file (`glass_notes.sqlite`) inside the app's
  Documents directory, managed by Drift.
- **Binary data** (images, voice recordings) is copied into
  `Documents/attachments/images` and `Documents/attachments/audio` by
  `AttachmentService`, with only the file path + metadata stored in SQLite —
  never raw bytes in the database.

---

## 9. How backup/restore works

- **Export**: `BackupService` reads every table into a `database.json`, adds a
  `backup_info.json` with a format/schema version, then walks every attachment
  row and copies the referenced file from disk into the archive under
  `attachments/` or `audio/`. Everything is zipped with `archive` and offered to
  the user via the share sheet.
- **Import**: the ZIP is opened and validated (are `database.json` and
  `backup_info.json` present? is the format version supported?) **before** any
  database mutation happens. Attachment files are written to their permanent
  directories first; then, inside a single Drift transaction, rows are inserted
  with either `insertOrIgnore` (merge — keeps existing data, adds anything new)
  or a full wipe-then-insert (replace). The user is asked to choose merge vs.
  replace before any of this runs. After a successful import,
  `rescheduleAllActiveOnBoot()` re-arms notifications for anything active.

---

## 10. Testing

```bash
flutter test
```

- `database_test.dart` — project/note/reminder CRUD, cascade deletes
- `reminder_service_test.dart` — validation, recurrence math (multi-weekday
  advancing), snooze, complete (one-time vs. recurring), cancel. The
  `flutter_local_notifications` platform channel is stubbed via
  `TestDefaultBinaryMessengerBinding` so these run without a device.
- `backup_service_test.dart` — export produces a valid zip, invalid-zip
  rejection, replace-restore round-trip, merge doesn't duplicate rows.
  `path_provider` is stubbed to a temp directory.
- `widget_test.dart` — the shared glass components in light and dark mode.

The feature screens read from `AppDatabase`, which needs the real sqlite3 native
library, so they are covered by the service/database tests rather than widget
tests. For true end-to-end notification delivery (app killed, device restarted),
run on a simulator/emulator or physical device — a unit test cannot verify
OS-level delivery.

---

## 11. Known platform limitations and how this handles them

- **No native "every N days" or "multiple weekdays" repeat** in
  `flutter_local_notifications` on either platform. Handled by scheduling one
  occurrence at a time and advancing on fire (see §5).
- **Notification permission must be requested, not assumed.** It is requested
  lazily, right before the first reminder is saved
  (`ReminderService.ensurePermission()`), not at launch. If the user declines,
  the reminder is still written to SQLite and the editor says plainly that the
  OS will not alert until notifications are enabled in Settings.
- **iOS and Android can throttle/coalesce notifications** under low-power or
  Focus/Doze conditions. This is OS-level behaviour no app can override.
- **Device restart**: both platforms persist already-scheduled local
  notifications, and Android additionally re-arms them through
  `ScheduledNotificationBootReceiver`. The boot-time
  `rescheduleAllActiveOnBoot()` call is a defensive backstop for a fresh
  install/restore where the notification queue is empty even though SQLite says
  a reminder should be active.
- **Background app refresh is not required** for scheduled local notifications
  to fire. The `audio` background mode is declared only for voice-note
  playback/recording. -->




  # RemindMe

<p align="center">
  <img src="assets/remindme-logo.png" alt="RemindMe Logo" width="180"/>
</p>

<h3 align="center">Remember Everything. Never Miss What Matters.</h3>

<p align="center">
  A beautiful, privacy-first, offline notes & reminders app for iPhone — built with Flutter.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-7C5CFC?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/iOS-26%2B-111827?style=for-the-badge&logo=apple&logoColor=white" alt="iOS"/>
  <img src="https://img.shields.io/badge/Offline-First-8B5CF6?style=for-the-badge" alt="Offline First"/>
  <img src="https://img.shields.io/badge/Privacy-Local%20Storage-EC4899?style=for-the-badge" alt="Privacy"/>
</p>

---

## ✨ What is RemindMe?

**RemindMe** is an all-in-one personal memory app designed around one simple idea:

> **Write it. Save it. Set it. Remember it.**

Instead of using separate apps for notes, reminders, voice memos and quick ideas, RemindMe brings everything together in one calm, modern workspace.

Create projects, write notes, attach images, record voice notes, schedule reminders and receive local notifications — even when you are completely offline.

---

## 🎯 Core Experience

```text
                    REMINDME
                       │
          ┌────────────┼────────────┐
          │            │            │
        NOTES       REMINDERS      VOICE
          │            │            │
          └────────────┼────────────┘
                       │
                    PROJECTS
                       │
                 LOCAL STORAGE
                       │
                LOCAL NOTIFICATIONS
```

### 📝 Notes
- Text notes
- Rich note content
- Checklists
- Pinned notes
- Favorite notes
- Tags
- Search
- Archive
- Recently deleted

### 🔔 Reminders
- Date & time reminders
- One-time reminders
- Daily reminders
- Weekly reminders
- Monthly reminders
- Custom recurring reminders
- Snooze
- Complete
- Reschedule
- Local notification actions

### 🖼️ Images
- Camera capture
- Gallery selection
- Multiple images
- Local image storage
- Full-screen image preview

### 🎙️ Voice Notes
- Record voice notes
- Pause / resume
- Playback
- Rename
- Delete
- Attach recordings to notes
- Fully local audio storage

### 📁 Projects
Organize everything into separate spaces:

```text
Personal
Work
CPApp
School
Ideas
Shopping
Travel
```

Each project can contain its own notes, reminders, images and voice recordings.

---

# 🎨 Design System

RemindMe follows a premium **iOS-inspired Glass UI** with soft gradients, translucent surfaces, blur, rounded cards and subtle motion.

## Brand Colors

| Purpose | Color | Hex |
|---|---|---|
| Primary Purple | 🟣 | `#7C3AED` |
| Electric Violet | 🟣 | `#8B5CF6` |
| Pink Accent | 🩷 | `#EC4899` |
| Reminder Orange | 🟠 | `#F59E0B` |
| Voice Blue | 🔵 | `#3B82F6` |
| Success Green | 🟢 | `#10B981` |
| Dark Text | ⚫ | `#111827` |
| Secondary Text | | `#667085` |
| Glass White | | `#FFFFFF` |

### Visual Language

- Glassmorphism
- Soft blur
- Translucent cards
- Large rounded corners
- Subtle borders
- Soft shadows
- Gradient accents
- iOS-style typography
- Haptic feedback
- Smooth transitions
- Dark & Light mode

---

# 🧊 Glass UI

A typical RemindMe card follows this visual hierarchy:

```text
╭────────────────────────────────────╮
│                                    │
│   🔔  Reminder                     │
│                                    │
│   Call school client               │
│   Today · 6:30 PM                  │
│                                    │
│                 Snooze   Complete  │
│                                    │
╰────────────────────────────────────╯
```

The interface intentionally stays clean and content-focused instead of filling the screen with controls.

---

# 📱 Main Screens

## Home

The home screen gives a quick overview of the user's day:

- Greeting
- Today's reminders
- Upcoming reminders
- Projects
- Recent notes
- Search
- Quick create

```text
Home
 ├── Today's Reminders
 ├── Recent Notes
 ├── My Projects
 └── Quick Add
```

## Project Dashboard

```text
Project
 ├── All
 ├── Notes
 ├── Reminders
 └── Completed
```

## Quick Create

A floating `+` button opens:

```text
╭────────────────────────╮
│       Create New       │
├────────────────────────┤
│  📝  Text Note         │
│  🖼️  Image Note        │
│  🎙️  Voice Note        │
│  🔔  Reminder          │
╰────────────────────────╯
```

---

# 🔔 Reminder Flow

```text
Create Reminder
      ↓
Select Date
      ↓
Select Time
      ↓
Choose Repeat
      ↓
Save to SQLite
      ↓
Schedule Local Notification
      ↓
      ⏰
Reminder Fires
      ↓
┌─────────┬──────────┬──────────┐
│  Open   │  Snooze  │ Complete │
└─────────┴──────────┴──────────┘
```

RemindMe does **not** depend on a cloud server for core reminders.

---

# 🔒 Privacy First

RemindMe is designed as an **offline-first** application.

Core personal data stays on the device:

```text
Notes          → SQLite
Reminders      → SQLite
Projects       → SQLite
Images         → Local Files
Voice Notes    → Local Files
Settings       → Local Storage
Notifications  → iOS Local Notifications
```

No account or internet connection is required for the core experience.

---

# 💾 Backup & Restore

RemindMe can provide an offline backup system.

Example:

```text
RemindMe-Backup.zip
│
├── database.json
├── backup_info.json
│
├── images/
│   ├── image_001.jpg
│   └── image_002.jpg
│
└── audio/
    ├── voice_001.m4a
    └── voice_002.m4a
```

Backup options:

- Export backup
- Share backup
- Import backup
- Merge data
- Restore data
- Validate backup before restore

---

# 🏗️ Architecture

RemindMe uses a feature-based Flutter architecture.

```text
lib/
│
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme/
│
├── core/
│   ├── constants/
│   ├── extensions/
│   ├── errors/
│   ├── utils/
│   └── widgets/
│
├── database/
│   ├── database.dart
│   ├── tables/
│   ├── dao/
│   └── migrations/
│
├── services/
│   ├── notification_service.dart
│   ├── reminder_service.dart
│   ├── audio_service.dart
│   ├── image_service.dart
│   ├── attachment_service.dart
│   ├── backup_service.dart
│   └── search_service.dart
│
├── features/
│   ├── projects/
│   ├── notes/
│   ├── reminders/
│   ├── attachments/
│   ├── search/
│   ├── trash/
│   ├── backup/
│   └── settings/
│
└── main.dart
```

### Data Flow

```text
UI
 ↓
Riverpod
 ↓
Repository
 ↓
SQLite / Local File System
```

Business logic is kept outside widgets to make the application easier to test and maintain.

---

# 🗃️ Data Model

Main entities:

```text
Project
   │
   ├── Notes
   │     ├── Text
   │     ├── Images
   │     └── Voice
   │
   └── Reminders
```

Core database tables:

- `projects`
- `notes`
- `reminders`
- `attachments`
- `tags`
- `note_tags`

---

# 🧰 Technology Stack

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform UI |
| Dart | Application language |
| Riverpod | State management |
| SQLite / Drift | Local database |
| Local Notifications | Offline reminders |
| Path Provider | Local file storage |
| Audio Recorder | Voice notes |
| Audio Player | Voice playback |
| Image Picker | Camera & gallery |
| File Picker | Backup/import |
| Local Authentication | Optional app lock |

---

# 🚀 Getting Started

## Requirements

- Flutter SDK
- Dart SDK
- Xcode
- CocoaPods
- iOS Simulator or physical iPhone

## Install

```bash
git clone <YOUR_REPOSITORY_URL>
cd remindme
flutter pub get
```

## Run

```bash
flutter run
```

For iOS:

```bash
cd ios
pod install
cd ..
flutter run
```

---

# 🔐 iOS Permissions

Depending on enabled features, RemindMe may request:

- Notifications
- Microphone
- Camera
- Photo Library
- Face ID / device authentication

Permissions should be requested only when the related feature is used.

---

# 🛣️ Roadmap

### Phase 1 — Foundation
- [x] Project architecture
- [ ] Theme system
- [ ] SQLite database
- [ ] Riverpod state management
- [ ] Routing

### Phase 2 — Notes
- [ ] Text notes
- [ ] Image notes
- [ ] Voice notes
- [ ] Attachments
- [ ] Tags
- [ ] Search

### Phase 3 — Reminders
- [ ] One-time reminders
- [ ] Recurring reminders
- [ ] Local notifications
- [ ] Snooze
- [ ] Notification actions

### Phase 4 — Organization
- [ ] Projects
- [ ] Favorites
- [ ] Archive
- [ ] Trash
- [ ] Completed reminders

### Phase 5 — Privacy & Backup
- [ ] Offline backup
- [ ] Restore
- [ ] App lock
- [ ] Face ID
- [ ] Storage management

### Phase 6 — Polish
- [ ] Glass UI
- [ ] Dark mode
- [ ] Animations
- [ ] Haptics
- [ ] Accessibility
- [ ] Performance optimization

---

# 🌙 Dark Mode

RemindMe supports a dark visual system designed around deep surfaces, translucent cards and violet/pink accents.

```text
Light Mode
☀️ Clean · Bright · Glass

Dark Mode
🌙 Deep · Soft · Premium
```

---

# 📸 Screenshots

Add screenshots here as the UI is implemented:

```text
docs/
├── home.png
├── project.png
├── note-editor.png
├── reminder.png
├── voice-note.png
└── settings.png
```

Example layout for GitHub:

| Home | Notes | Reminders |
|---|---|---|
| Add screenshot | Add screenshot | Add screenshot |

---

# 🧠 Product Philosophy

RemindMe is built around three principles:

### 01 — Remember
Capture anything quickly.

### 02 — Organize
Keep ideas inside projects and tags.

### 03 — Act
Turn important notes into reminders so they don't get forgotten.

---

# 🤝 Contributing

Contributions, ideas and improvements are welcome.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests where appropriate
5. Open a pull request

---

# 📄 License

Add your preferred license here.

---

<p align="center">
  <strong>RemindMe</strong><br/>
  Remember Everything. Never Miss What Matters.
</p>

<p align="center">
  Built with ❤️ and Flutter.
</p>

