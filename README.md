# Anycast Scout GUI

> [!WARNING]
> **In Development / Alpha.** Anycast Scout GUI is under active development.
> UX, bundled backend behavior, and release artifacts may change before a stable
> release. Review generated targets and configs before using them in production
> workflows.

Flutter desktop app for running Anycast Scout backend workflows without leaving
the desktop.

![Anycast Scout GUI dashboard](assets/screenshot.png)

Anycast Scout GUI packages the Rust `anycast-scout` backend into a native
desktop interface for Linux, macOS, and Windows. It helps discover candidate
anycast edge IPs, run scans, validate Connect URLTest results, and keep related
CSV/JSON artifacts and sessions in one place.

The app does not ship private sing-box credentials or ready-to-use configs.
Choose your own sing-box JSON config from Settings before running Connect
checks.

## Run

```bash
flutter pub get
flutter run -d macos
```

Build the backend first, or point Settings -> Core at an existing binary:

```bash
cd ../anycast-scout
cargo build --release --locked
```

The app prefers a bundled backend, then a sibling backend checkout, then
`anycast-scout` from `PATH`.

## Connect Config

The GUI does not bundle sing-box credentials or ready-to-use sing-box configs.
Choose your private JSON config in Settings -> Core with the Browse button before
running Connect checks. Local `config.json`, `.env*`, and sing-box-style JSON
files are ignored by default.

## Verify

```bash
flutter pub get --offline --enforce-lockfile
dart format --output=none --set-exit-if-changed .
flutter analyze --no-pub
flutter test --no-pub
```

CI uses the configured `PUB_CACHE` and `--enforce-lockfile` for repeatable
dependency resolution from the checked-in lockfile.
