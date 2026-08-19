# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

SkillMatch is a Flutter application targeting Android. App ID: `com.example.skillmatch`.

The app consumes a **Laravel REST API** as its backend (separate repository). All server communication goes through repository classes over HTTP.

## Workflow Rules

**IMPORTANT: After completing every prompt/task, append a summary entry to `FinishedTask.md` at the project root.** Each entry must include:

- Date and time
- The task that was requested (one line)
- Files created or modified
- Key decisions made or anything that needs the developer's review

Always **append** — never overwrite or delete previous entries. If `FinishedTask.md` does not exist yet, create it.

Example entry format:

```markdown
## 2026-06-11 — Add login screen
- Task: Build login UI with email/password and connect to auth provider
- Files: lib/modules/auth/widgets/login_screen.dart (new), lib/modules/auth/models/auth_provider.dart (modified)
- Notes: API endpoint assumed as POST /api/login — confirm with backend
```

## Commands

```
flutter pub get                      # Install dependencies
flutter run                          # Run in debug mode (hot reload enabled)
flutter analyze                      # Lint and static analysis
flutter test                         # Run all tests
flutter test test/widget_test.dart   # Run a single test file
flutter build apk                    # Build Android APK
flutter build web                    # Build for web
```

## Architecture

The app uses a **modular (feature-based) architecture**. Every feature lives in its own module under `lib/modules/`, and each module contains exactly three layers:

```
lib/
├── main.dart                  # Bootstraps MyApp, registers MultiProvider
├── core/
│   ├── constants/             # API base URL, app-wide constants
│   ├── network/               # Shared HTTP client setup (base headers, auth token)
│   └── utils/                 # Shared helpers
└── modules/
    └── <feature>/             # e.g. auth, profile, skills, matches
        ├── widgets/           # UI layer — screens and widgets for this feature
        ├── models/            # Data models + Provider classes (state management)
        └── repository/        # HTTP methods calling the Laravel API
```

### Layer responsibilities

- **widgets/** — UI only. Screens and reusable widgets. They read/watch state via the Provider package and call provider methods. Widgets must never make HTTP calls directly.
- **models/** — Two things live here:
  1. Data model classes with `fromJson` / `toJson` mapping Laravel JSON responses. 
  2. Provider classes (`ChangeNotifier`) that hold the feature's state, expose loading/error states, and call the repository.
- **repository/** — All HTTP methods for the feature (GET/POST/PUT/DELETE against Laravel endpoints). Repositories return parsed model objects, never raw JSON, and never touch UI or state.

Data flow is one-directional: **widget → provider (models/) → repository → Laravel API**, then state changes notify widgets via `notifyListeners()`.

### State management

Provider package. Register all providers in `main.dart` using `MultiProvider` above `MaterialApp`. When adding a new feature module, register its provider there.

### Backend conventions (Laravel)

- Base URL and endpoints are defined in `core/constants/` — never hardcode URLs in repositories.
- Responses are JSON; expect Laravel's standard shapes (e.g. validation errors under `errors`, paginated data under `data`).
- Auth token (e.g. Laravel Sanctum) is attached via the shared client in `core/network/`.

### When creating a new feature

1. Create `lib/modules/<feature>/` with `widgets/`, `models/`, `repository/` subfolders.
2. Build the repository first, then the provider, then the UI.
3. Register the provider in `main.dart`.
4. Append the summary to `FinishedTask.md`.

## Linting

Rules are in [analysis_options.yaml](analysis_options.yaml), which extends `flutter_lints/flutter.yaml`. Add project-specific rules under the `linter: rules:` section there.

## Dependencies

Managed via [pubspec.yaml](pubspec.yaml). Requires Dart SDK `^3.11.5`. After adding or removing packages, run `flutter pub get`.

Expected packages for this architecture (add via `pubspec.yaml` if not present):

- `provider` — state management
- `http` — repository layer HTTP calls
