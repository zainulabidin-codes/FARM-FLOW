# Farm Flow

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart)](https://dart.dev)
[![Standard Readme compliant](<https://img.shields.io/badge/readme%20style-standard-brightgreen.svg?style=flat-square>)](https://github.com/richardlitt/standard-readme)

> A local-first, offline Flutter application designed for dairy farmers to track herd lifecycles, monitor per-cow milk yields, and maintain customer sales ledgers without cloud dependency.

This README reflects the current project status and is subject to updates as development progresses.

## Table of Contents

- [Security](#security)
- [Background](#background)
- [Install](#install)
- [Usage](#usage)
- [API](#api)
- [Maintainers](#maintainers)
- [Contributing](#contributing)
- [License](#license)

## Security

Farm Flow is built as a local-first application where user data resides on the device within a local SQLite database (`dairy_farm.db`).

- Local authentication credentials are encrypted using SHA-256 password hashing.
- No sensitive farm or financial data is transmitted to external cloud servers.
- To report security vulnerabilities or concerns, please contact the repository maintainers directly.

## Background

Dairy farm management in rural environments requires reliable, real-time tracking of animal health, reproduction, milk yield performance, and buyer transactions. Many existing solutions rely on continuous internet access, which is often unavailable in agricultural areas.

Farm Flow addresses this challenge by providing:

- **Offline-First Storage**: A local SQLite database supporting mobile (Android/iOS), desktop (Windows/macOS/Linux via FFI), and web browsers (via WebAssembly/IndexedDB).
- **Exact Unit Precision**: Storage of milk quantities in integer grams and monetary values in integer paise to eliminate floating-point rounding errors.
- **Comprehensive Lifecycle Tracking**: Monitoring cows through milking, pregnancy (9-month timeline tracking), dry periods, heifers, and artificial insemination records.
- **Integrated Customer Ledger**: Managing customer buyers (*Dodis*), default rates per litre, and transaction histories with automated shift conflict resolution.

## Install

### Prerequisites

- **Flutter SDK**: `^3.12.2` or compatible Flutter 3.x stable release
- **Dart SDK**: Included with Flutter
- **Build Tools**:
  - Android Studio / Android SDK API 34+ for Android targets
  - Xcode 15+ for iOS / macOS targets
  - Visual Studio 2022 with C++ desktop tools for Windows targets

### Setup Steps

1. Clone the repository:

   ```sh
   git clone https://github.com/zainulabidin-codes/FARM-FLOW.git
   ```
2. Change to the application directory:

   ```sh
   cd FARM-FLOW/dairy_farm_app
   ```
3. Install dependencies:

   ```sh
   flutter pub get
   ```

## Usage

### Development Builds

Run on the default target device or emulator:

```sh
flutter run
```

Run on specific platform targets:

```sh
flutter run -d windows
flutter run -d chrome
flutter run -d android
```

### Static Diagnostics & Tests

Analyze the codebase for lint issues and errors:

```sh
flutter analyze
```

Run the automated unit and integration test suite:

```sh
flutter test
```

### App Icon Generation

Regenerate platform launcher icons from asset source files:

```sh
dart run flutter_launcher_icons
```

### Production Release Builds

Build executable binaries for deployment:

```sh
flutter build apk --release
flutter build appbundle --release
flutter build windows --release
flutter build web --release
```

## API

Farm Flow utilizes a feature-first architecture managed via `Provider`. Key core modules and APIs include:

- `DatabaseHelper`: Singleton class (`lib/core/database/database_helper.dart`) responsible for database creation, version migrations (up to v12), table schema definition, foreign key index maintenance, and platform-specific FFI engine bootstrapping.
- `AuthProvider`: Provider class (`lib/features/auth/presentation/providers/auth_provider.dart`) managing user registration, authentication, SHA-256 credential verification, and active farmer session state.
- `CowProvider`: Provider class (`lib/features/cows/presentation/providers/cow_provider.dart`) managing herd counts, status updates (`MILKING`, `PREGNANT`, `DRY`, `HEIFER`, `BRED_HEIFER`), pregnancy month calculations, mating logs, heat repeat handling, and lactation histories.
- `MilkEntryProvider`: Provider class (`lib/features/milk_entry/presentation/providers/milk_entry_provider.dart`) handling shift-based milk production entry (morning/evening), total yield tracking, and duplicate shift entry conflict harmonization.
- `DodiProvider`: Provider class (`lib/features/dodi_ledger/presentation/providers/dodi_provider.dart`) managing customer buyer profiles, native contact selection, default milk rates, transaction entries (`MILK_SOLD`, `PAYMENT_RECEIVED`, `ADVANCE_TAKEN`), and net ledger balances.
- `AppRouter`: Static routing hub (`lib/core/routing/app_router.dart`) handling single-source-of-truth navigation transitions across application screens.

## Maintainers

[@zainulabidin-codes](https://github.com/zainulabidin-codes)

## Contributing

1. Fork the repository and create your feature branch (`git checkout -b feature/amazing-feature`).
2. Verify code quality by running `flutter analyze` and `flutter test`.
3. Ensure all database changes maintain integer-only unit rules for amounts (paise) and quantities (grams).
4. Commit your changes (`git commit -m 'Add amazing feature'`).
5. Push to the branch (`git push origin feature/amazing-feature`).
6. Open a Pull Request.

## License

Proprietary. All rights reserved.
