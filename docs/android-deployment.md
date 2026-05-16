# Android Deployment

## 1) Sideloading on Android phones

### Build an APK
```bash
flutter pub get
flutter build apk --release
```

### Install on a phone
- Copy the APK to the device and open it.
- Or install with ADB:
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## 2) Developer testing on a computer

For computer-based testing, the simplest path is an Android emulator.

### Run on an emulator
1. Start an Android emulator in Android Studio, or connect a physical device.
2. Check that Flutter sees it:
```bash
flutter devices
```
3. Run the app:
```bash
flutter run
```

### Optional release-style emulator test
If you want to test a release build on an emulator or device:
```bash
flutter build apk --release
flutter install --release
```

## Recommended workflow

- Use `flutter run` on an emulator during development.
- Use `flutter build apk --release` for sideloading to testers.
- Keep `flutter analyze` and `flutter test` in your pre-release checklist.

## Current repo state

- Android-only Flutter project.
- Release build currently signs with the debug key in `android/app/build.gradle.kts`.
- That is acceptable for sideloading and internal device testing, but not for public Play Store release.

## Automated builds (GitHub Actions)

This repository contains a GitHub Actions workflow that can produce an AAB or APK and upload it as a workflow artifact. The workflow file is `.github/workflows/build-release.yml`.

How it works:
- Trigger manually via the Actions UI (`workflow_dispatch`) and choose `aab` or `apk`, or push to `main` to trigger automatically.
- The workflow expects the following repository secrets when you want a properly signed release:
	- `ANDROID_KEYSTORE_BASE64`: Base64-encoded contents of your JKS keystore file.
	- `ANDROID_KEYSTORE_PASSWORD`: The keystore store password.
	- `ANDROID_KEY_ALIAS`: The key alias inside the keystore.
	- `ANDROID_KEY_PASSWORD`: The key password.

To configure secrets locally (example using `gh`):
```bash
gh secret set ANDROID_KEYSTORE_BASE64 --body "$(base64 -w0 release-key.jks)"
gh secret set ANDROID_KEYSTORE_PASSWORD --body "your_store_password"
gh secret set ANDROID_KEY_ALIAS --body "release_key"
gh secret set ANDROID_KEY_PASSWORD --body "your_key_password"
```

If you do not provide keystore secrets, the workflow will still build but the result will be signed with the debug key (same as local builds). After a successful run, download the `android-release` artifact from the Actions run.
