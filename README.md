# My Flutter App

A production-ready Flutter application with Clean Architecture.

## Architecture

This project follows **Clean Architecture** principles organized as **Feature-First**:

```
lib/
├── app/                     # App-level configuration
│   └── app.dart             # Root MaterialApp widget
├── core/                    # Shared, cross-feature code
│   ├── constants/           # App-wide constants
│   ├── di/                  # Dependency injection (GetIt + Injectable)
│   ├── error/               # Failure & Exception classes
│   ├── extensions/          # Dart extension methods
│   ├── network/             # Dio setup + interceptors
│   ├── router/              # GoRouter configuration
│   ├── storage/             # SharedPreferences wrapper
│   ├── theme/               # Colors, text styles, themes
│   ├── usecases/            # UseCase base contracts
│   └── widgets/             # Shared reusable widgets
└── features/                # Feature modules (clean arch layers)
    ├── auth/
    │   ├── data/            # Models, data sources, repo impl
    │   ├── domain/          # Entities, repo interfaces, use cases
    │   └── presentation/    # BLoC, pages, widgets
    ├── home/
    │   └── presentation/
    └── splash/
        └── presentation/
```

## State Management

- **BLoC** (`flutter_bloc`) for predictable state management
- **Equatable** for value equality in events/states

## Navigation

- **GoRouter** for declarative, deep-link-ready routing

## Networking

- **Dio** + **Retrofit** for type-safe API calls
- Interceptors for auth token injection and error mapping

## Local Storage

- **SharedPreferences** for simple key-value storage
- **Hive** for structured local data (configured, ready to use)
- **Flutter Secure Storage** for sensitive data (tokens)

## Dependency Injection

- **GetIt** + **Injectable** — run `build_runner` to regenerate DI config

## Getting Started

### Prerequisites

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0

### Installation

```bash
# Get dependencies
flutter pub get

# Generate code (DI, JSON serialization, Retrofit)
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

### Environment Setup

Copy the example env file and fill in your values:

```bash
cp .env.example .env
```

### Running Tests

```bash
flutter test
```

### Build for Release

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## Packages Used

| Package | Purpose |
|---------|---------|
| flutter_bloc | State management |
| go_router | Navigation |
| dio + retrofit | Networking |
| get_it + injectable | Dependency injection |
| shared_preferences | Local storage |
| hive_flutter | Local database |
| flutter_secure_storage | Secure token storage |
| google_fonts | Typography |
| equatable | Value equality |
| dartz | Functional Either type |
| json_serializable | JSON serialization |
| logger | Logging |

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
