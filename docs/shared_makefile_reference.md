# 📦 WebTrit Phone Makefile Documentation

This Makefile provides flexible build and run automation for the WebTrit Phone Flutter project, supporting configuration
management, flavors, and parameterization.

---

## 🗂 Makefile Structure

### 📁 Project Root Path

```makefile
phone_project_path ?= .
```

Defines the root path of the Flutter project. Defaults to the current directory.

---

### ⚙️ Build Version Configuration

```makefile
BUILD_CONFIG_FILE := $(phone_project_path)/build.config
```

Reads the `VERSION` value from `build.config`. Based on the version, the `VERSION_STAGE` is determined, which controls
flavor logic.

Possible stages:

- `legacy` — version is missing or outdated.
- `v0.0.1` — supports deeplink flavor only.
- `v0.0.2+` — supports deeplink and SMS receiver flavors.

---

### 📄 Dart Define JSON

```makefile
DART_DEFINE_PATH ?= $(phone_project_path)/dart_define.json
```

Path to the Dart define file passed as `--dart-define-from-file`.

---

## 🍦 Flavor Computation

### 🔗 Deeplink Flavor

```makefile
compute-deeplink-flavor
```

Sets `deeplinks` or `deeplinksDisabled` based on the presence of `WEBTRIT_APP_LINK_DOMAIN`.

### 📩 SMS Receiver Flavor

```makefile
compute-sms-flavor
```

Sets `smsReceiver` or `smsReceiverDisabled` based on `WEBTRIT_CALL_TRIGGER_MECHANISM_SMS`.

### 🔧 Compute FLAVOR_ARG

```makefile
compute-flavor-arg
```

Generates the appropriate `--flavor` argument based on version stage:

- `legacy`: no flavor used.
- `v0.0.1`: deeplink flavor only.
- `v0.0.2+`: deeplink + SMS flavor concatenation.

---

## 🚀 Flutter Command Flags

### Common flags:

```makefile
COMMON_FLAGS := --dart-define-from-file=...
COMMON_BUILD_FLAGS := $(COMMON_FLAGS) --no-tree-shake-icons
```

### Optional build arguments:

- `--build-name`
- `--build-number`
- `--release`
- `--no-codesign`
- `--config-only`

---

## 🔨 Macros

### Build Command Macro

```makefile
FLUTTER_BUILD_COMMAND
```

Executes `flutter build` with all necessary flags and conditions.

### Run Command Macro

```makefile
FLUTTER_RUN_COMMAND
```

Executes `flutter run` with appropriate arguments. `--no-tree-shake-icons` is not used here.

---

## 🎯 Targets

### Build:

- `make build-apk` — builds Android APK.
- `make build-appbundle` — builds Android App Bundle.
- `make build-ios` — builds iOS app.
- `make build` — builds using the default `BUILD_PLATFORM`.
- `make build-ios-config-only` — generates iOS Xcode project only (no actual build).

### Run:

- `make run` — runs using `BUILD_PLATFORM`.
- `make run-apk` — runs Android APK on device.
- `make run-ios` — runs iOS app on simulator/device.

---

## 📝 Notes

- Requires `jq` for JSON parsing.
- `dart_define.json` must be present and valid.
- On iOS, `--flavor` is ignored for `run` and `config-only` modes.

---

## 📚 Usage Examples

```bash
make build-apk build_name=1.2.3 build_number=123 release=true
make run-apk
make build-ios-config-only no_codesign=true
```