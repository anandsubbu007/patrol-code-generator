# Patrol Recorder generator

Development-only companion to `patrol_recorder`. Converts stopped YAML journeys
to ordinary Patrol tests and typed input contracts, preserving user-owned input
providers and test wrappers. It does not record interactions or execute tests.

## Install

After both packages are published:

```sh
flutter pub add patrol_recorder:^0.0.3
flutter pub add --dev patrol_recorder_generator:^0.0.1 patrol:4.10.0
```

If recorder APIs are imported only from a test-only recording entrypoint, both
recorder and generator may be dev dependencies instead. If application widgets
import recorder APIs, only the recorder needs to be a regular app dependency.
The runtime recorder depends only on Flutter; formatter, analyzer, YAML, and
argument parsing dependencies belong to this tooling package.

Requires Dart >=3.13.0 and Flutter >=3.47.0 through the recorder dependency.
Use Flutter for dependency resolution and tests. Recording/replay is verified
on Flutter web; other platforms remain unverified.

## Generate

From the consuming app directory:

```sh
dart run patrol_recorder_generator:generate
dart run patrol_recorder_generator:generate --all
dart run patrol_recorder_generator:generate --journey login
dart run patrol_recorder_generator:generate --journey checkout --case happy --preview
dart run patrol_recorder_generator:generate --journey checkout --inspect-selectors
dart run patrol_recorder_generator:generate --project /path/to/app
dart run patrol_recorder_generator:generate --help
```

The CLI validates the selected batch before writing: schema 1-5, stopped state,
input references, selectors, app bootstrap, screenshot existence, and safe paths.
`--recordings-directory` overrides YAML discovery for one invocation. Invalid
sources and unsafe writes produce explicit failures and nonzero exit status.
In a terminal, omitting `--journey` opens a menu to select one journey, generate
all, preview steps, inspect selectors, reset recordings, or see re-recording
instructions. Failed validation returns to the menu so you can choose an
unaffected journey. The menu also handles an empty or missing recordings folder.
The CLI generates tests; it does not execute tests or start recording.

Reset offers three scopes: YAML only; YAML and referenced screenshots; or both
plus the journey's generated files **including user-owned inputs and tests**.
It lists exact existing files and requires typing `DELETE`. No directories,
fixture assets, unreferenced screenshots, or unrelated files are deleted.
Malformed YAML must be repaired before a screenshot/code reset, or removed with
YAML-only reset. Symlinked paths are refused. Stop recording before resetting.
Record a new journey in DevTools afterward; reset does not automatically re-record.

Use `--all` to bypass the menu, or `--no-interactive` for unattended operation.
Redirected input and `CI=true` default to non-interactive; `--interactive` explicitly
enables the menu. `--journey` always bypasses it. For machine-readable selector
JSON, use `--journey <name>` or `--all` with `--inspect-selectors`.
In non-interactive mode without `--journey`, every `.yml` recording is
validated, including older recordings. Validation reports invalid journeys and
all their missing screenshot paths without writing any output. Paths stored in
YAML are relative to the app project; changing `screenshots_directory` does not
relocate existing captures or update old recordings. Restore missing captures
or re-record the affected journey in DevTools. To generate an unaffected journey,
add `--journey <name>` to the same command; validation failures list valid names
when available. This selects one recording rather than skipping its validation.

Each journey produces:

| File              | Ownership                                                    |
| ----------------- | ------------------------------------------------------------ |
| `*_steps.g.dart`  | Generated Patrol actions; regenerated                        |
| `*_inputs.g.dart` | Abstract typed input contract; regenerated                   |
| `*_inputs.dart`   | User-owned provider, created once and preserved              |
| `*_test.dart`     | User-owned test/setup/assertions, created once and preserved |

Implement deferred input getters and fixture adapters before replay. Recorded
values are never supplied; schema 5 can supply explicitly authored, non-secret
test fixtures. Obtain secrets from your private test provider. Add bounded
business-outcome assertions to the preserved test wrapper. Run through Patrol
CLI, not `flutter test` or the IDE's ordinary test buttons.

Optional app `recorder_config` settings include `recordings_directory`,
`screenshots_directory`, `output_directory`, `wait_timeout_ms` (100-120000,
default 15000), and `max_scrolls` (1-200, default 60). Normal `lib/main.dart`
startup is inferred; custom test factories can be configured in the app pubspec.
See the [complete recorder guide](https://github.com/anandsubbu007/patrol-code-generator#readme)
for recording, supported interactions, configuration, screenshots, and privacy.

## Authored journeys

Edit YAML only after stopping recording. Re-recording the same name replaces its
YAML, including manual additions. Schema 5 supports either flat `steps` or a
`cases` list, never both. Recorder-created journeys stay flat; advanced cases are
authored manually. Legacy schemas 1-4 remain readable.

```yaml
schema_version: 5
journey: {id: checkout, name: Checkout}
state: stopped
assets:
	customer: {path: assets/customer.json, format: json}
inputs:
	email: {type: string}
	quantity: {type: integer}
	password: {type: string, secret: true}
profiles:
	demo: {email: demo@example.invalid, quantity: 2}
setup:
	fixtures:
		- {id: seed, action: asset, asset: customer}
groups:
	sign_in:
		- id: email
			action: enterText
			target: {key: email}
			input: '{{email}}'
			secret: false
		- {id: submit, action: tap, target: {key: old_submit}}
cases:
	- id: happy
		name: Happy checkout
		profile: demo
		setup: [fixtures]
		data: {quantity: 3}
		selector_overrides:
			login_submit: {key: login, within: {key: sign_in_form}}
		steps:
			- {id: login, action: group, group: sign_in}
			- id: ready
				action: expect
				target: {key: account_title}
				expectation: {kind: text, value: Account overview, timeout_ms: 10000}
	- id: empty
		name: Empty cart
		profile: demo
		steps:
			- id: no_items
				action: expect
				target: {key: cart_item}
				expectation: {kind: count, value: 0}
```

### Assets

An `asset` step applies a named test fixture through the input provider's
`Future<void> applyAsset(String name, Object value)` method, in step order.
It is not a screenshot, Flutter bundled asset, executable script, file picker,
or upload action. Only UTF-8 `text` and non-null `json` formats are supported.
JSON is passed as decoded maps/lists/scalars; text is passed as a string.

Store the example fixture at `patrol_recorder/assets/customer.json`. Every asset
path must start with `assets/` and is relative to the configured recordings
directory, including a `--recordings-directory` override. Absolute paths, URIs,
traversal, percent-encoded paths, and symlinked files/directories are rejected by
the local CLI. The canonical app project and its recordings directory bound
all reads. Each asset is limited to 1 MiB, with a 10 MiB total per journey.
Every declared asset is validated, even when only one case is selected.

The generator embeds validated fixture values into Dart; replay performs no
fixture file reads. Treat these fixtures as source-controlled, non-secret data.
It does not modify the app's asset bundle or copy files outside the configured
output directory. Unknown/missing references, unsupported formats, corrupt JSON,
and oversized files fail preview and generation before output is written.

Implement `applyAsset` in the user-owned `*_inputs.dart` class to connect your
test service/fixture store. Its inherited implementation deliberately throws
until connected. Calls have the configured `wait_timeout_ms` deadline and identify
the step on failure. A timeout stops replay; Dart cannot cancel an already
running adapter future, so adapters should support their own cleanup.
App bootstrap runs first, followed by referenced setup steps, then case steps.
Pre-bootstrap dependency injection belongs in the preserved user-owned wrapper.

### Cases and data

IDs are explicit lowercase identifiers (1-64 characters). Serialization preserves
them. Reusable group expansion prefixes child IDs with the group call ID, such as
`login_submit`; setup IDs become `setup_fixtures_seed`. Repeated calls therefore
have distinct, deterministic IDs. Unknown/cyclic groups, duplicate IDs/setup
calls, IDs exceeding 64 characters, and expansions above 500 entries fail.
Limits: 50 cases, groups, setup definitions, profiles, and assets; 100 input types.

Input types are `string`, `integer`, `number` (Dart `double`), `boolean`, and `json`
(Dart `Object`). JSON must be non-null, finite, string-keyed, and at most 20 levels
deep. Schema types govern profile values and case `data`; case data overrides the
selected profile. Declared inputs appear as typed getters, including those used
by fixture adapters. Missing values produce getters that throw until connected.
Text entry stringifies numeric/boolean inputs and JSON-encodes JSON inputs.
Secret inputs must be strings and cannot have literal profile/case values; their
default provider uses `RECORDER_SECRET_<NAME>` or your private implementation.
Unannotated recorded input references remain strings.

`expect` supports `exists`, `absent`, `visible`, exact `text`, and `count`, with
100-120000 ms timeouts (default 10000). Text/count require their correctly typed
`value`; the other forms reject a value. Missing/unsupported forms fail with
case/step context. `source: authored` and `include: true` are defaults in schema 5.
Excluding a group call excludes its expanded actions; reusable definition steps
cannot individually use `include: false`. Edit the definition or exclude the call.

`selector_overrides` replaces the target of an identified widget step, including
expanded setup/group IDs. The replacement must be a supported resolved selector,
optionally scoped with `within`. Unknown step IDs and asset overrides fail.
Coordinates/indexes remain unsupported; generation never guesses a target.

### Preview and outputs

`--case <id>` requires `--journey <id>`. Omit it to generate all cases of a
selected journey. Each authored case writes four files under
`<output_directory>/<journey_id>/cases/<case_id>/`; legacy/flat output paths stay
unchanged. Providers and wrappers remain user-owned and are never regenerated
over existing files. Deleting a case does not delete its old output files.

`--preview` validates exactly like generation and prints generated steps without
writing. `--inspect-selectors` validates and prints effective selectors as JSON,
including stable case/step IDs and whether an override was applied. No subprocess
runner is added. Library callers can use `resolveAssets`, `generateCases`,
`expandedSteps`, and `inspectSelectors`; direct generation refuses unresolved
asset contents rather than silently skipping the step.

## Development and publishing

The local `pubspec_overrides.yaml` resolves `patrol_recorder` from the checkout.
It is excluded from the published archive. The release manifest uses the hosted
dependency `patrol_recorder: ^0.0.3`, which supplies the updated expectation
transport types. Publish recorder 0.0.3 before validating hosted-only resolution.
The repository root excludes `tool/` from its runtime archive, and Pub
inherits those exclusions.
For generator publication, stage its source and release metadata outside the
checkout without the local override, then validate hosted-only resolution.
Follow the [release checklist](https://github.com/anandsubbu007/patrol-code-generator/blob/main/doc/PUBLISHING.md)
for the exact staging and publication commands.

```sh
flutter pub get
flutter analyze
flutter test
```

## License and support

Licensed under [BSD-3-Clause](LICENSE). Independent project, not an official
Patrol product. Report sanitized reproduction details and tool versions in the
[issue tracker](https://github.com/anandsubbu007/patrol-code-generator/issues).
Do not share credentials, private screenshots, or authenticated debugging URLs.
