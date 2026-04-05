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
