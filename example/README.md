# Runnable recorder example

This is a local demonstration, **not authentication**. No backend is contacted.
The `.invalid` accounts in [demo_profiles.dart](patrol_test/demo_profiles.dart) are fictional.
Never enter real credentials. The optional password field exists to demonstrate
reference-only recording and screenshot exclusion, not to authenticate anyone.

## Setup

Use Flutter 3.47.7 / Dart 3.13.5 and Node 22.23.4 for the tested Patrol web runner.

From the repository root:

```sh
flutter pub get
cd tool/devtools_extension
flutter pub get
dart run devtools_extensions build_and_copy --source=. --dest=../../extension/devtools
dart run devtools_extensions validate --package=../..
cd ../../example
flutter pub get
dart pub global activate patrol_cli 4.8.0
```

If the installed `patrol` command is not on PATH, add the pub-cache executable
directory to your terminal's PATH, or replace `patrol` with
`dart pub global run patrol_cli:main` in the commands below.

```sh
flutter run --target patrol_test/recorder_main.dart -d chrome --print-dtd
```

Open the DevTools URL printed by Flutter. Enable **patrol_recorder** through the
DevTools extension enablement prompt. The package must be an actual dependency of
the app's development dependencies, as in this example's pubspec.

All recording setup and shared test defaults live under `patrol_test/`:

- [recorder_main.dart](patrol_test/recorder_main.dart): debug-only app wrapper and
  generator configuration. It is not a discoverable `*_test.dart` file.
- [demo_profiles.dart](patrol_test/demo_profiles.dart): fictional public test data.
- `recorded_journeys/`: independently editable generated tests and data.

The production [lib/main.dart](lib/main.dart) simply runs the application.
[lib/app.dart](lib/app.dart) has no recorder imports, profiles, or per-action hooks.
Its fields start empty. Ordinary `flutter run -d chrome` does not start recording.

For a headless development/automation check, Flutter also supports
`--web-run-headless --web-browser-debug-port=9235 --web-port=8765`.
These are Flutter's public Chrome debugging flags, not recorder APIs.

## Record a journey

1. Open the extension in real DevTools. It should show **Connected - ready**.
2. Click **Start**. In the running app, edit Email and Note using fictional values.
   The app-level observer discovers the fields automatically and records input
   references, **not** the typed values. No per-field callback was added.
3. Click **Open demo account**. The app navigates to a page that shows no input values.
4. In the extension, click **Stop**. The preview contains normal Patrol actions,
   with the values read from a separate data file.
5. Choose a fresh Journey ID, such as `my_login`, and a `demo` or `secondary` profile.
   Existing sample files named `login`/`accounts` will not be overwritten.
6. Click **Capture Flutter content**. The login form deliberately blocks this
   operation while its obscured password field is mounted; the account page permits it.
7. Click **Refresh export projects** and select this example project, not the
   recorder package or the extension's source project.
8. Optionally click **Load recorder_config.yaml**. It resets IDs/profile/name to
   the saved defaults, so choose a fresh Journey ID again afterward.
9. Click **Save new journey**. Inspect the saved Dart, data, PNG, and metadata files.
10. Edit the generated journey data independently, then use **Copy Run Command**.
    Run it in this `example/` directory. Results appear in the terminal.

Profile selection belongs to the testing workflow, not the application UI.
Use the extension's profile selector / `RECORDER_PROFILE` when rerunning.
Focused controller activity can also include selection/composition or programmatic
changes; review input references rather than assuming every notification is typing.

If no authorized DTD project is listed, export is unavailable. Use an IDE-managed
DevTools session or a Flutter launch with the project root granted by its tooling.
Do not start an unrestricted daemon. Browser-download fallback is not implemented.

## Run and rerun saved tests

The sample contains two independently generated fixtures:

- [login_test.dart](patrol_test/recorded_journeys/login/login_test.dart):
  email + note + demo login.
- [accounts_test.dart](patrol_test/recorded_journeys/accounts/accounts_test.dart):
  the same independent bootstrap, then account settings.

An additional [browser_verified_test.dart](patrol_test/recorded_journeys/browser_verified/browser_verified_test.dart)
was captured and exported through real DevTools, with its own data, PNG, and
metadata. All three passed through the official Patrol runner.

The [automatic_verified_test.dart](patrol_test/recorded_journeys/automatic_verified/automatic_verified_test.dart)
is a newer real DevTools export made without action hooks, using the test-only
entrypoint. It uses keys and singleton assertions, with no coordinates.

Each imports its own editable data file. They do not import each other's tests.
Patrol's configured test directory is `patrol_test`; **there is no suite entrypoint**.

One file:

```sh
patrol test --target patrol_test/recorded_journeys/login/login_test.dart \
  --dart-define RECORDER_PROFILE=secondary --device chrome --web-headless
```

One stable case tag:

```sh
patrol test --target patrol_test/recorded_journeys/login/login_test.dart \
  --tags recorder_login_sign_in --dart-define RECORDER_PROFILE=demo \
  --device chrome --web-headless
```

Whole suite:

```sh
patrol test --device chrome --web-headless --dart-define RECORDER_PROFILE=demo
```

Patrol installs its official local Node/Playwright dependencies on the first web
run. It builds and launches a separate test app. No recorder Run button or custom
test executor is involved. If Chromium download is blocked, the current CLI also
documents `--web-channel msedge` / `--web-executable-path`; check its installation
behavior rather than assuming those flags skip all downloads.

On this host, Chromium extraction stalled under Node 26.12.0 and succeeded under
Node 22.23.4. Put Node 22 directly on PATH before invoking Patrol. A nested
`npx --call` wrapper propagated npm options into Patrol's own `npx` invocation and
failed; do not use that wrapper to launch Patrol. No runner sources or browser
installation markers were patched.

## Data and configuration schema (M1)

[recorder_config.yaml](recorder_config.yaml) has schema version `1` and these fields:

| Field | Default / validation |
| --- | --- |
| `schema_version` | Required integer `1`; other versions rejected |
| `output_directory` | `patrol_test/recorded_journeys`; safe relative path, no `..` |
| `journey_id` | `login`; lowercase identifier, maximum 64 characters |
| `case_id` | `sign_in`; same identifier rules |
| `case_name` | Human-readable, printable, 1-120 characters |
| `profile` | `demo`; must be a declared named profile |

Unknown fields and incorrect YAML types are rejected. M1 data values are strings;
typed amounts/dates, multiple data sets per case, group management, and reusable
setup are M2 work. The present model does not limit the project to one file.

Each `<journey>_data.dart` contains:

- A `profiles` map of named, non-secret values.
- `loadProfile()`, selecting `RECORDER_PROFILE` and rejecting unknown names.
- Validation for required fields; missing/empty required values fail clearly.
- A separate secret-reference resolver when secret steps were recorded.

Changes made to the generated data file are authoritative for reruns. The running
recording entrypoint's public defaults live independently in
[demo_profiles.dart](patrol_test/demo_profiles.dart), never in application `lib/`.
No arbitrary Dart is parsed back into the recorder in M1.

### Secrets

A recorded secret input named `password` generates only the reference
`RECORDER_SECRET_PASSWORD`. Supply its value outside generated files using a
private JSON file and Patrol's `--dart-define-from-file /private/path/inputs.json`.
Do not include that file in the project. Missing values raise an error naming the
reference, never its value. Input actions disable Patrol value logging.

`String.fromEnvironment` values are embedded in the built test app. This mechanism
avoids source literals; it is not a secure vault. Use short-lived test-only values
and protect binaries/logs. The package does not inherit desktop environment
variables automatically inside a device/browser app.

## Tests and scope

```sh
flutter analyze
flutter test
```

The example is web-runnable now; mobile platform projects and native screenshot
providers are intentionally not claimed as implemented. See the
[current automatic results](../docs/PHASE_1_PLAN.md#automatic-implementation-results)
and [historical M1 report](../docs/MILESTONE_1_RESULTS.md).
