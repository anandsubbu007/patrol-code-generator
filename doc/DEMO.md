# Screenshots and demonstration

## Gallery

These screenshots show the actual local Flutter example, using only fictional
data. They demonstrate the app under test, not a claim of native-platform support.

| Screen                                               | What to notice                                                             |
| ---------------------------------------------------- | -------------------------------------------------------------------------- |
| ![Connected DevTools recorder](images/recorder.png)  | Earlier connected-extension capture; not a screenshot of the new M2 dialog |
| ![Login](images/login.png)                           | A normal keyed Flutter form; no per-action recorder callbacks              |
| ![Account overview](images/account.png)              | A visible outcome to assert after replay                                   |
| ![Repeated controls](images/repeated-controls.png)   | Identical labels in different ancestor scopes                              |
| ![Fixture lab](images/fixture-lab.png)               | New M2 app lab with fictional customer data, typed fields and two items    |
| ![Narrow fixture lab](images/fixture-lab-mobile.png) | The same lab at 390px browser width, not native-mobile proof               |

## Recorded video

[Watch/download the refreshed example walkthrough (WebM, 9.84 seconds)](https://github.com/anandsubbu007/patrol-code-generator/blob/main/doc/media/example-walkthrough.webm).
The repository copy is `doc/media/example-walkthrough.webm`.

This silent recording shows the actual debug example: entering fictional input,
opening the account, and loading/clearing the fixture lab. It is an **app UI
walkthrough**, not a recording of DevTools, generation, or Patrol execution.
Use the script below to film a full narrated end-to-end release demonstration.
The video is excluded from the pub archive; the gallery PNGs are included.

The two maintained M2 Patrol cases (`populated` and `empty`) separately passed
real headless web replay on 2026-10-23. Their YAML, fixture files, implemented
adapter/providers, generated steps and wrappers are under the
[runnable M2 example](../example/README.md#m2-fixtures-and-expectations).
This is not a new live DevTools recording -> generation proof: the fixture cases
are manually authored and the current DevTools dialog capture remains unrefreshed.

To reproduce the media with the example running at `http://localhost:8931`:

```sh
cd example
NODE_PATH="$HOME/.pub-cache/hosted/pub.dev/patrol-4.10.0/web_runner/node_modules" \
   node tool/record_publication_demo.cjs
```

Patrol installs Playwright dependencies during its first web run. Otherwise use
your installed Playwright package on `NODE_PATH`; the capture script adds no
runtime dependency to the Flutter recorder. Set `DEMO_APP_URL` for a different
local app URL. The script replaces the app video, login/account screenshots, and
desktop/narrow fixture images using an isolated context and fictional values.

## Short walkthrough script

Use a clean app state and the recording-only entrypoint:

```sh
cd example
flutter run --target patrol_test/recorder_main.dart -d chrome --print-dtd
```

1. Open the printed DevTools URL. Enable **patrol_recorder** and wait for
   **Connected - ready**.
2. Click **Record**, select the example project, and name the journey
   `publication_demo`. Save to a new journey; do not overwrite a maintained
   recording merely to film the demo.
3. Show that its YAML exists immediately with `state: recording`.
4. In the app enter `demo@example.invalid` and a fictional note. Click
   **Open demo account**.
5. In DevTools, **Capture visible screen**, name it `account_overview`, and
   save. Capture is optional, not needed for code generation.
   Also demonstrate **Add expectation**: select **Demo account is open**, choose
   **Exact text**, review its prefilled value, and confirm it into the journey.
6. Stop recording, review targets, and show **Journey YAML saved**. Open the
   YAML and point out `{{email}}` / `{{note}}`, not the typed values.
7. Run the copied command:

   ```sh
   dart run patrol_recorder_generator:generate --journey publication_demo
   ```

8. Show the four generated files. Wire the abstract getters in
   `publication_demo_inputs.dart` to fictional fixtures, then add a bounded
   account-open assertion in the user-owned test.
9. Run through Patrol:

   ```sh
   dart pub global run patrol_cli:main test \
     --target patrol_test/recorded_journeys/publication_demo/publication_demo_test.dart \
     --device chrome --web-headless
   ```

10. Show the result from that actual run. Do not present an app walkthrough as
    proof that recording, generation, or replay passed.

For a concise narrated release video, allow roughly 90-120 seconds. Film the app,
DevTools panel, YAML, input implementation, and actual CLI result in that order.
Video is optional on pub.dev; use a repository/release link rather than embedding
an HTML video player in the pub.dev README.

## Capture and privacy

- Use a separate local browser context, not a personal browser profile.
- Record only the example with fictional values. Do not show private source,
  real credentials, personal tabs, terminal history, or notifications.
- Keep VM Service and DTD URLs out of published images/video; their authentication
  tokens are local session credentials.
- Browser screenshots of the app do not apply recorder masking. Avoid entering
  sensitive data; recorder PNGs mask `obscureText`, `RecorderSensitive`, and
  `RecorderIgnore`, but other visible content can still be captured.
- Keep the gallery PNGs at `doc/images/` for pubspec screenshot paths.
  Keep video under `doc/media/`, which is excluded from the pub archive.
- Review every final image and the video before uploading. Do not claim a full
  end-to-end demo unless all stages are actually shown.
