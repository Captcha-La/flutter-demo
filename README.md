# Captchala Flutter Demo

A Flutter app demonstrating the [`captchala`](https://pub.dev/packages/captchala)
plugin end-to-end. A settings panel (action / language / theme / voice /
offline / maskClosable) drives the verify flow on iOS, Android, macOS,
Linux, and Windows.

## Links

- Website: <https://captcha.la>
- Dashboard: <https://dash.captcha.la>
- Flutter SDK docs: <https://captcha.la/docs/sdk/flutter>
- All SDK docs: <https://captcha.la/docs>
- Support: <support@captcha.la>

## Prerequisites

- Flutter SDK 3.x (`flutter --version` to verify).
- Android: Android Studio / command-line tools, emulator or USB-connected device.
- iOS / macOS: Xcode 15+ and CocoaPods.
- Linux: standard desktop libraries (GTK + libcurl).
- Windows: Windows 10 (build 1809+).

## Run

```bash
flutter pub get
flutter run                     # auto-picks the foreground device
# or pick explicitly:
flutter run -d <device-id>      # see `flutter devices`
```

For iOS / macOS the first build will run `pod install` automatically.

## App key

The demo uses a public demo `appKey` defined at the top of `lib/main.dart`.
Replace with your own from <https://dash.captcha.la> for real-tenant testing.

## License

MIT — see [LICENSE](./LICENSE).
