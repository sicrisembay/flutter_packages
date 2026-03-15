# pub.dev Publishing Checklist for `can_usb`

This document lists everything that must be done before publishing the `can_usb` package to pub.dev.
Run `flutter pub publish --dry-run` from the `packages/can_usb` directory at any time to preview
what the publisher sees and catch validation errors early.

---

## 0. Pre-flight Checks

Do these before touching any files in the package.

### 0.1 Verify the package name is available ✅

Check that `can_usb` is not already claimed on pub.dev before investing any further effort:

```
https://pub.dev/packages/can_usb
```

**Result:** `https://pub.dev/packages/can_usb` returns 404 — the name is available.

~~If the name is taken you must choose a new name and update `pubspec.yaml`,
`example/pubspec.yaml`, and all internal imports before proceeding.~~

### 0.2 Audit for sensitive / private information ✅

Because this package was migrated from a **private** repository, explicitly
check every file for credentials, internal hostnames, private tokens, or
hardware-specific secrets before the first `git push` to the new public repo:

```powershell
# Quick grep for common patterns
grep -rn --include='*.dart' --include='*.yaml' --include='*.md' `
  -e 'password' -e 'secret' -e 'token' -e 'api_key' -e 'Bearer' .
```

Also review:
- Hard-coded IP addresses or internal domain names
- Developer-specific file paths
- Private GitHub repository URLs still referenced in comments or docs

**Result:** No credentials, tokens, passwords, or IP addresses found in any
source or config file. The only references to the old repo are the known URL
fields in `pubspec.yaml` and links in `README.md` — both covered by item #9.

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

### 1.2 Update `pubspec.yaml`

**File:** `pubspec.yaml`

| Field | Current value | Required action |
|-------|--------------|-----------------|
| `description` | `"A new Flutter package project."` | Write a meaningful 60–180 character description |
| `homepage` | *(empty)* | Add the GitHub repository URL or a documentation site URL |
| `repository` | *(missing)* | Add the GitHub repository URL (recommended) |
| `issue_tracker` | *(missing)* | Add URL to the Issues page (optional but recommended) |
| `version` | `0.0.1` | Keep for a first release, or bump to `0.1.0` if you prefer SemVer |
| `topics` | *(missing)* | Add up to 5 discovery tags (improves pub.dev search ranking) |

> **Important — new public repo URL:** `pubspec.yaml` currently points to the
> old private repo (`sicrisembay/CANopen_flutter`). Update all three URL fields
> to the new public repository once it is created.

**Suggested additions:**
```yaml
name: can_usb
description: >-
  A Flutter package for communicating with a USB-CANFD adapter over serial.
  Provides transport, framing, and a high-level device API.
version: 0.1.0
homepage: https://github.com/<your-new-public-org>/flutter_packages
repository: https://github.com/<your-new-public-org>/flutter_packages
issue_tracker: https://github.com/<your-new-public-org>/flutter_packages/issues
topics:
  - can-bus
  - serial
  - hardware
  - iot
```

---

### 1.3 Verify the SDK constraint is correct ✅

**File:** `pubspec.yaml`

The current Dart SDK lower bound is `^3.11.1`.  Confirm this is intentional — it is a very
recent constraint and will exclude users on older SDK versions.  If the code compiles on
`^3.5.0` (latest stable at time of writing), consider relaxing it to broaden compatibility.

```yaml
environment:
  sdk: ">=3.5.0 <4.0.0"
  flutter: ">=3.22.0"
```

---

### 1.4 Fix `.pubignore` ✅

**File:** `.pubignore`

The IntelliJ module file `can_usb.iml` is present in the package root but is
not excluded from the pub upload. Add it:

```
PUBLISH_CHECKLIST.md
build/
*.iml
```

---

## 2. Write Proper Documentation

### 2.1 Rewrite `README.md` ✅

**File:** `README.md`

The entire README is still the default template with `TODO` placeholders.
A good README should include:

- [x] **One-line description** — what the package does
- [ ] **Badges** — pub.dev version, CI status, license *(deferred: can only be added after first publish and CI setup — see §9.2)*
- [x] **Features** — bullet list of capabilities (e.g. connect/disconnect, send/receive CAN frames, get device ID, stats)
- [x] **Supported platforms** — Windows / Linux / Android / macOS (note: depends on `flutter_libserialport`)
- [x] **Getting started** — add dependency snippet:
  ```yaml
  dependencies:
    can_usb: ^0.1.0
  ```
- [x] **Usage example** — copy the docstring example from `canusb_device.dart` and expand it
- [x] **API overview** — list the main exported classes (`CanusbDevice`, `CanFrame`, `CanStats`, etc.)
- [x] **Additional information** — how to file issues, contribution guide

### 2.2 Update `CHANGELOG.md` ✅

**File:** `CHANGELOG.md`

Replace the TODO entry with real release notes:

```markdown
## 0.1.0

* Initial release.
* Serial transport layer via `flutter_libserialport`.
* Binary frame builder and parser.
* Commands: Get Device ID, CAN Start/Stop, Send/Receive frames, Protocol Status, CAN Stats, Enter DFU.
* High-level `CanusbDevice` API.
```

---

## 3. Verify the Example App ✅

pub.dev expects an `example/` directory containing a minimal runnable app or
script. Both `example/lib/main.dart` and `example/pubspec.yaml` already exist.

**Results:**
- `flutter pub get` — ✅ dependencies resolved
- `flutter analyze` — ✅ no issues found
- `flutter build windows` — ⚠️ no platform directories present in the example
  project (`windows/`, `android/`, etc. were never scaffolded). This does **not**
  affect the pub.dev score — pub.dev only requires that the example is
  analysable, not that it has a working platform build.

  If you want a fully runnable desktop example, add Windows support with:
  ```powershell
  cd packages\can_usb\example
  flutter create --platforms=windows .
  flutter build windows
  ```
  Note this will add a `windows/` directory (C++ CMake project) to the example.

---

## 4. Code Quality Checks

### 4.1 Resolve lint warnings ✅

Run the analyser and fix all issues:
```powershell
cd packages\can_usb
flutter analyze
```
pub.dev deducts points for any `INFO`, `WARNING`, or `ERROR` level issues.

**Result:** `No issues found!`

### 4.2 Add API documentation comments ✅

pub.dev scores `/// doc comments` coverage.  Ensure that all **public** symbols (classes,
methods, fields, enums) have at least a one-line doc comment.  Check coverage with:
```powershell
dart doc --validate-links .
```

**Result:** `Found 0 warnings and 0 errors.`
One warning (`[9 .. totalLength-2]` unresolved reference in `frame_builder.dart`) was
fixed by replacing square brackets with backticks.

### 4.3 Run tests ✅

Ensure the existing tests pass and aim for meaningful coverage:
```powershell
flutter test
```

**Result:** `75/75 tests passed.`

---

## 5. Dry-Run Validation ✅

From `packages/can_usb`, run:
```powershell
flutter pub publish --dry-run
```

This will:
- List all files that will be uploaded (verify nothing private is included)
- Report any `pubspec.yaml` validation errors
- Show the calculated pub.dev score breakdown

Iterate until there are no errors.

**Result:** `Package has 0 warnings.` Upload size: 24 KB.
Excluded files confirmed absent: `PUBLISH_CHECKLIST.md`, `build/`, `doc/`, `*.iml`.

---

## 6. Publisher Account Setup

- [ ] Enable **Two-Factor Authentication (2FA)** on the Google account you will
      use to publish — pub.dev requires 2FA to be active for the publishing
      account.
- [ ] Log in to [pub.dev](https://pub.dev) with your Google account
- [x] ~~Create a **publisher** (e.g. `yourname.dev` or an organisation domain) via
      *pub.dev → Profile → Create Publisher*~~ — *deferred: no domain purchased
      yet. Publishing under personal Google account for now. A publisher can be
      created and the package transferred to it at any time after initial publish.*
- [x] ~~Verify publisher domain ownership via Google Search Console~~ — *deferred (see above)*
- [x] ~~Add the `publisher` field to `pubspec.yaml`~~ — *not needed when publishing
      under a personal account; omit the `--publisher` flag.*

---

## 7. Publish ✅

```powershell
cd packages\can_usb
flutter pub publish
```

You will be prompted to confirm and authenticate via a browser.

**Result:** Published successfully. Package live at https://pub.dev/packages/can_usb

---

## 8. Post-Publish

- [x] Tag and push the release commit in git:
  ```powershell
  git tag can_usb-v0.1.0
  git push origin can_usb-v0.1.0
  ```
- [x] Verify the package page at `https://pub.dev/packages/can_usb` — ✅ live,
      metadata/topics/repository all correct.
- [x] Check the pub.dev score and address any remaining recommendations —
      **150 / 160 pub points** (as of 2026-03-15).
      - ~~`pubspec.yaml` description was too long (> 180 chars).~~ ✅ Fixed — shortened to 136 chars.

---

## 9. Optional Improvements (Nice-to-Have)

These do not block publishing but improve the pub.dev score and discoverability.

### 9.1 Add package screenshots

pub.dev can display screenshots on the package page.  Add a `screenshots` key
to `pubspec.yaml`:

```yaml
screenshots:
  - description: 'Example app — connect and send a CAN frame'
    path: screenshots/example_app.png
```

Create the `screenshots/` directory and add at least one PNG.

### 9.2 Set up CI (GitHub Actions)

pub.dev awards a CI badge when a verified CI workflow runs tests on the
published package.  Add a workflow file, for example
`.github/workflows/ci.yaml`:

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
        working-directory: packages/can_usb
      - run: flutter analyze
        working-directory: packages/can_usb
      - run: flutter test
        working-directory: packages/can_usb
```

---

## Summary of Current Package State

| # | File | Issue | Status | Severity |
|---|------|-------|--------|----------|
| 1 | `LICENSE` | Placeholder text — no real license | ✅ Fixed | ~~Blocker~~ |
| 2 | `pubspec.yaml` | Default description, empty `homepage` | ✅ Fixed | ~~Blocker~~ |
| 3 | `README.md` | Entirely TODO placeholders | ✅ Fixed | ~~Blocker~~ |
| 4 | `CHANGELOG.md` | TODO placeholder entry | ✅ Fixed | ~~High~~ |
| 5 | *(missing)* | No `example/` directory | ✅ Fixed | ~~High~~ |
| 6 | `pubspec.yaml` | SDK lower bound `^3.11.1` may be too restrictive | ✅ Fixed | ~~Medium~~ |
| 7 | Source files | Doc comment coverage unknown — needs audit | ✅ Fixed (0 warnings, 0 errors) | ~~Medium~~ |
| 8 | *(new)* | Package name availability not yet confirmed | ✅ Fixed (404 on pub.dev) | ~~Blocker~~ |
| 9 | `pubspec.yaml`, `README.md` | URLs still point to old private repo (`sicrisembay/CANopen_flutter`) | ✅ Fixed | ~~Blocker~~ |
| 9a | `README.md`, `packages/can_usb/` | `FRAME_SPECIFICATION.md` linked but does not exist in new repo | ✅ Fixed (links to `sicrisembay/webserial_canfd`) | ~~High~~ |
| 10 | `pubspec.yaml` | `topics` field missing | ✅ Fixed | ~~Medium~~ |
| 11 | `.pubignore` | `can_usb.iml` not excluded from upload | ✅ Fixed | ~~Low~~ |
| 12 | Publisher account | 2FA not confirmed active; publisher domain deferred | ⬜ Pending (2FA) / ✅ Deferred (publisher) | **Blocker** (2FA only) |
| 13 | `example/` | Example app not verified to build | ✅ Analysed clean; no platform dirs (see §3) | ~~High~~ |
| 14 | `pubspec.yaml` | Description too long (> 180 chars) — 0/10 pub points | ✅ Fixed — shortened to 136 chars | ~~Medium~~ |
