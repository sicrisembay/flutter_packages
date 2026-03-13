# pub.dev Publishing Checklist for `soil_sensor`

This document lists everything that must be done before publishing the `soil_sensor` package to pub.dev.
Run `flutter pub publish --dry-run` from the `packages/soil_sensor` directory at any time to preview
what the publisher sees and catch validation errors early.

---

## 0. Pre-flight Checks

Do these before touching any files in the package.

### 0.1 Verify the package name is available ✅

Check that `soil_sensor` is not already claimed on pub.dev before investing any further effort:

```
https://pub.dev/packages/soil_sensor
```

**Result:** `https://pub.dev/packages/soil_sensor` returns 404 — the name is available.

~~If the name is taken you must choose a new name and update
`pubspec.yaml` and all internal imports before proceeding.~~

### 0.2 Audit for sensitive / private information

Because this package originates from a private repository, explicitly check every file for
credentials, internal hostnames, private tokens, or hardware-specific secrets before the first
`git push` to the public repo:

```powershell
# Quick grep for common patterns
grep -rn --include='*.dart' --include='*.yaml' --include='*.md' `
  -e 'password' -e 'secret' -e 'token' -e 'api_key' -e 'Bearer' .
```

Also review:
- Hard-coded IP addresses or internal domain names
- Developer-specific file paths
- Private GitHub repository URLs still referenced in comments or docs

---

## 1. Fix Critical Blockers

These issues will cause a publish failure or a very low pub.dev score.

### 1.1 Add a real LICENSE

**File:** `LICENSE`

The file currently contains only:
```
TODO: Add your license here.
```

Replace it with a proper OSI-approved license (e.g. MIT, BSD-3-Clause, Apache-2.0).
pub.dev will not give a package full points without a recognised license.

**Example MIT license:**
```
MIT License

Copyright (c) 2026 <Your Name or Organisation>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

### 1.2 Update `pubspec.yaml` ✅

**File:** `pubspec.yaml`

| Field | Current value | Required action |
|-------|--------------|-----------------|
| `description` | `"Modbus RTU soil sensor (NPK/moisture/pH) integration for Flutter."` | ✅ Acceptable — 62 chars, within 60–180 limit |
| `homepage` | *(missing)* | ✅ Set to `https://github.com/sicrisembay/flutter_packages` |
| `repository` | *(missing)* | ✅ Set to `https://github.com/sicrisembay/flutter_packages` |
| `issue_tracker` | *(missing)* | ✅ Set to `https://github.com/sicrisembay/flutter_packages/issues` |
| `version` | `0.1.0` | ✅ Fine for a first release |
| `topics` | *(missing)* | ✅ Added: `modbus`, `serial`, `sensor`, `agriculture`, `iot` |
| `publish_to` | commented-out `'none'` | ✅ Removed |

**Suggested additions:**
```yaml
name: soil_sensor
description: >-
  A Flutter package for reading Modbus RTU soil sensors (NPK, moisture,
  temperature, pH, conductivity) over USB serial on Android and Windows.
version: 0.1.0
homepage: https://github.com/<your-org>/flutter_packages
repository: https://github.com/<your-org>/flutter_packages
issue_tracker: https://github.com/<your-org>/flutter_packages/issues
topics:
  - modbus
  - serial
  - sensor
  - agriculture
  - iot
```

---

### 1.3 Verify the SDK constraint is correct ✅

**File:** `pubspec.yaml`

The code uses switch expressions (Dart 3.0+) but no features beyond that. The constraint
has been relaxed from `^3.11.1` to `">=3.5.0 <4.0.0"` to maximise compatibility.

```yaml
environment:
  sdk: ">=3.5.0 <4.0.0"
  flutter: ">=3.0.0"
```

---

### 1.4 Create `.pubignore` ✅

**File:** `.pubignore`

Created with the following content to exclude non-essential files from the pub upload:

```
PUBLISH_CHECKLIST.md
build/
*.iml
```

---

## 2. Write Proper Documentation

### 2.1 Rewrite `README.md` ✅

**File:** `README.md`

- [x] **One-line description** — what the package does
- [ ] **Badges** — pub.dev version, CI status, license *(deferred: can only be added after first publish and CI setup — see §9.2)*
- [x] **Features** — bullet list of capabilities
- [x] **Supported platforms** — Android (via `usb_serial`) and Windows (via `flutter_libserialport`)
- [x] **Getting started** — dependency snippet + Android permissions note
- [x] **Usage example** — basic connect + read loop
- [x] **API overview** — `SoilSensorService`, `SensorReading`, `ModbusRtuService` tables
- [x] **Additional information** — issues link, contribution guide

### 2.2 Update `CHANGELOG.md` ✅

**File:** `CHANGELOG.md`

Replaced the TODO entry with real release notes:

```markdown
## 0.1.0

* Initial release.
* USB serial transport for Android (`usb_serial`) and Windows (`flutter_libserialport`).
* Modbus RTU FC03 implementation via `ModbusRtuService`.
* High-level `SoilSensorService` API: `listDevices`, `connect`, `disconnect`, `readSensor`.
* `SensorReading` model: moisture, temperature, conductivity, pH, nitrogen, phosphorus, potassium.
* `hasNpk` and `isRecent` convenience getters on `SensorReading`.
```

---

## 3. Add an Example App ✅

**Directory:** `example/`

`example/pubspec.yaml` and `example/lib/main.dart` created. The example app demonstrates
device scanning, connect/disconnect, and a live sensor reading display.

- `flutter pub get` — ✅ dependencies resolved
- `flutter analyze` — ✅ no issues found

No platform directories (`android/`, `windows/`) are required for pub.dev scoring —
the example only needs to be statically analysable.

---

## 4. Code Quality Checks

### 4.1 Fix broken test ✅

**File:** `test/soil_sensor_test.dart`

~~The existing test references a `Calculator` class (leftover from the package template).~~

Replaced with 14 tests covering `SensorReading` (field values, `hasNpk`, `isRecent`) and
`ModbusRtuService` (CRC, request builder, response parser, error handling, register scaling).

**Result:** `14/14 tests passed.`

### 4.2 Resolve lint warnings ✅

Run the analyser and fix all issues:
```powershell
cd packages\soil_sensor
flutter analyze
```

**Result:** `No issues found!` Fixes applied:
- Removed `library soil_sensor;` directive (`unnecessary_library_name` lint)
- Added `ModbusRtuService` to the library barrel export

### 4.3 Add API documentation comments ✅

pub.dev scores `/// doc comments` coverage. Ensure all **public** symbols (classes, methods,
fields, enums) have at least a one-line doc comment. Check with:
```powershell
dart doc --validate-links .
```

**Result:** `Found 0 warnings and 0 errors.` Fixes applied:
- Added `///` doc comments with units to all `SensorReading` fields
- Added class-level doc comment to `SensorReading`
- Added `///` doc comment to `ModbusRtuService.calculateCrc16`
- Fixed broken `doc/MODBUS_RTU_PROTOCOL.md` relative link in README — replaced with full GitHub URL

### 4.4 Run tests ✅

After fixing the broken test (§4.1), ensure they pass:
```powershell
flutter test
```

**Result:** `14/14 tests passed.`

---

## 5. Dry-Run Validation ✅

From `packages/soil_sensor`, run:
```powershell
flutter pub publish --dry-run
```

This will:
- List all files that will be uploaded (verify nothing private is included)
- Report any `pubspec.yaml` validation errors
- Show the calculated pub.dev score breakdown

Iterate until there are no errors.

Expected upload: only `lib/`, `test/`, `example/`, `pubspec.yaml`, `README.md`, `CHANGELOG.md`,
`LICENSE`, `analysis_options.yaml`. Confirm that `PUBLISH_CHECKLIST.md`, `build/`, and
`soil_sensor.iml` are absent from the list.

**Result:** `Package has 1 warning.` — only warning is uncommitted git changes (expected
during development). No pubspec errors, no code issues.

Upload manifest confirmed clean:
- ✅ `PUBLISH_CHECKLIST.md` absent (`.pubignore` working)
- ✅ `build/` absent
- ✅ `soil_sensor.iml` absent
- ✅ Total compressed size: **18 KB**

Warning will clear after committing all changes to git (see §8).

---

## 6. Publisher Account Setup

- [ ] Enable **Two-Factor Authentication (2FA)** on the Google account you will
      use to publish — pub.dev requires 2FA to be active for the publishing account.
- [ ] Log in to [pub.dev](https://pub.dev) with your Google account
- [ ] *(Optional)* Create a **publisher** (e.g. `yourname.dev`) via
      *pub.dev → Profile → Create Publisher* and verify domain ownership via
      Google Search Console. A publisher can be created and the package transferred
      to it at any time after initial publish.

---

## 7. Publish

```powershell
cd packages\soil_sensor
flutter pub publish
```

You will be prompted to confirm and authenticate via a browser.

---

## 8. Post-Publish

- [ ] Tag and push the release commit in git:
  ```powershell
  git tag soil_sensor-v0.1.0
  git push origin soil_sensor-v0.1.0
  ```
- [ ] Verify the package page at `https://pub.dev/packages/soil_sensor` — check
      metadata, topics, and repository link are all correct.
- [ ] Check the pub.dev score and address any remaining recommendations
      (analysis may take ~1 hour for a new package).

---

## 9. Optional Improvements (Nice-to-Have)

### 9.1 Add package screenshots

pub.dev can display screenshots on the package page. Add a `screenshots` key to `pubspec.yaml`:

```yaml
screenshots:
  - description: 'Example app — connect and read soil sensor data'
    path: screenshots/example_app.png
```

Create the `screenshots/` directory and add at least one PNG.

### 9.2 Set up CI (GitHub Actions)

pub.dev awards a CI badge when a verified CI workflow runs tests on the published package.
Add a workflow file, for example `.github/workflows/ci.yaml`:

```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.22.x'
      - run: flutter pub get
        working-directory: packages/soil_sensor
      - run: flutter analyze
        working-directory: packages/soil_sensor
      - run: flutter test
        working-directory: packages/soil_sensor
```

---

## Summary of Current Package State

| # | File | Issue | Status | Severity |
|---|------|-------|--------|----------|
| 1 | `LICENSE` | Placeholder text — no real license | ⬜ Pending | **Blocker** |
| 2 | `pubspec.yaml` | Missing `homepage`, `repository`, `issue_tracker`, `topics` | ✅ Fixed | ~~Blocker~~ |
| 3 | `README.md` | Entirely TODO placeholders | ✅ Fixed | ~~Blocker~~ |
| 4 | `CHANGELOG.md` | TODO placeholder entry | ✅ Fixed | ~~High~~ |
| 5 | *(missing)* | No `example/` directory | ✅ Fixed | ~~High~~ |
| 6 | `test/soil_sensor_test.dart` | References non-existent `Calculator` class — tests fail | ✅ Fixed (14/14 passed) | ~~High~~ |
| 7 | `pubspec.yaml` | SDK lower bound `^3.11.1` may be too restrictive | ✅ Fixed | ~~Medium~~ |
| 8 | Source files | Doc comment coverage not yet audited | ✅ Fixed (0 warnings, 0 errors) | ~~Medium~~ |
| 9 | *(missing)* | No `.pubignore` — `soil_sensor.iml`, `build/` will be uploaded | ✅ Fixed | ~~Medium~~ |
| 10 | `pubspec.yaml` | `publish_to: 'none'` comment block should be removed | ✅ Fixed | ~~Low~~ |
| 11 | Publisher account | 2FA not confirmed active | ⬜ Pending | **Blocker** |
| 12 | Package name | Availability on pub.dev not yet confirmed | ⬜ Pending | **Blocker** |
