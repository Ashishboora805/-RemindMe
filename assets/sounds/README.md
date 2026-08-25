# Custom reminder sounds

Drop short notification sounds here.

- **iOS**: a custom notification sound must ALSO be added to the Xcode project
  (`Runner` target → Build Phases → Copy Bundle Resources) as a `.caf`/`.aiff`/`.wav`
  file under 30 seconds. `NotificationService` looks it up as `<name>.caf`.
- **Android**: place the file in `android/app/src/main/res/raw/<name>.<ext>`
  (lowercase, no spaces). `NotificationService` resolves it as a `RawResourceAndroidNotificationSound`.

The value stored in `Reminder.sound` is the bare name (e.g. `chime`), or
`default` to use the system sound.
