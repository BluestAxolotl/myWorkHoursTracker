# myworkhourstracker

Work Hours Tracker is a Flutter app focused on tracking hours worked across multiple job profiles created by user.

## Platform Support

- Android only (for now)

Non-Android Flutter platform folders were intentionally removed from this repository.

## Implemented Feature Highlights

- First-run app settings initialization flow
- Required app settings validation before save
- SharedPreferences persistence with fallback defaults
- Sidebar settings access (gear icon) regardless of profile count
- Last profile deletion keeps user on the main app screen
- Combined currency search-and-selection field in the settings screen
- SQLCipher database encryption with a unique per-install key generated on first app launch, stored securely in Android Keystore

For implementation details, see [docs/app-settings-feature.md](docs/app-settings-feature.md).

## Run The App (Android)

1. Ensure Android SDK/emulator or a physical Android device is available.
2. Install dependencies:
	```bash
	flutter pub get
	```
3. Run the app:
	```bash
	flutter run -d android
	```

## Useful Commands

```bash
flutter analyze
flutter test
```

## Android Deployment

This project is Android-only, so deployment is typically one of two paths:

1. Sideload an APK onto a phone for testers.
2. Run the app in an Android emulator on a developer machine.

See [docs/android-deployment.md](docs/android-deployment.md) for the exact commands and notes, including an automated GitHub Actions workflow to produce signed AAB/APK artifacts.

## Recent Fixes (branch: delete-work-session-from-calendar)

- Daily overtime is now computed per-session so switching to daily overtime retroactively recalculates past sessions.
- Calendar arrows advance full pay-period windows (weekly/biweekly) to keep windows aligned when navigating.
- Totals section is rebuilt when `JobProfile` settings change to avoid stale totals after edits.
- Removed footer text from the Job Profile details page.

