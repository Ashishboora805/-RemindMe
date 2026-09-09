# Custom reminder sounds

Drop short notification sounds here.

- **iOS**: the bundled `.mp3` files are registered in the Runner target and
  must remain under 30 seconds. `NotificationService` looks them up as
  `<name>.mp3`.
- **Android**: the bundled files are copied to
  `android/app/src/main/res/raw/<name>.<ext>` (lowercase, underscores, no spaces).
  `NotificationService` resolves them as a `RawResourceAndroidNotificationSound`.

The value stored in `Reminder.sound` is the bare name (`funny` or
`ticking_clock`), or `default` to use the system sound.
