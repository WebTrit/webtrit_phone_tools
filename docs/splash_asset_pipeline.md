# Splash Asset Pipeline

This document describes how the CLI fetches, downloads, and generates native splash screen
resources for the WebTrit Phone app — including Android 12+ splash support.

---

## Overview

The `resources-get` command orchestrates the full splash pipeline:

```
Backend API ──► AssetProcessor ──► ExternalGeneratorRunner ──► Makefile ──► flutter_native_splash
 (fetch URLs)    (download PNGs)    (build env vars)           (generate YAML)  (platform resources)
```

Two splash variants are supported:

| Variant             | Description                                         | Asset path                                       |
|---------------------|-----------------------------------------------------|--------------------------------------------------|
| **Standard splash** | Used on all platforms as the primary splash image    | `tool/assets/native_splash/image.png`            |
| **Android 12**      | Dedicated image optimised for the Android 12+ API   | `tool/assets/native_splash/android12image.png`   |

The Android 12 variant is **optional**. When the backend does not provide it, the pipeline falls
back to the standard splash image for Android 12 as well.

---

## Backend API

`GET .../splash-asset?includeUrl=true` returns:

```json
{
  "id": "...",
  "outputsArtifacts": {
    "splashArtifactId": "...",
    "android12SplashArtifactId": "..."
  },
  "urls": {
    "splashUrl": "https://signed-url-for-splash",
    "android12SplashUrl": "https://signed-url-for-android12"
  }
}
```

- `android12SplashArtifactId` and `android12SplashUrl` are **optional** — older backends omit them.
- Both URLs are pre-signed and expire after a short window.

---

## Pipeline Steps

### 1. Download assets — `AssetProcessor.processSplashAssets()`

**File:** `lib/src/commands/app_resources/processors/asset_processor.dart`

1. Fetches `SplashAssetDto` from the configurator backend via `datasource.getSplashAsset()`.
2. Downloads the standard splash from `urls['splashUrl']` → `tool/assets/native_splash/image.png`.
3. If `urls['android12SplashUrl']` is present and non-empty, downloads it →
   `tool/assets/native_splash/android12image.png`.
4. Returns the `SplashAssetDto` (carries `source.backgroundColorHex` and `urls` map).

### 2. Build environment variables — `AppConfigFactory.createNativeSplashEnv()`

**File:** `lib/src/commands/app_resources/utils/app_config_factory.dart`

Produces the env map consumed by the Makefile target:

| Env variable                | Value                                                      | Always set? |
|-----------------------------|------------------------------------------------------------|-------------|
| `SPLASH_COLOR`              | Background colour from `splashInfo.source.backgroundColorHex` | Yes      |
| `SPLASH_IMAGE`              | `tool/assets/native_splash/image.png`                      | Yes         |
| `ANDROID_12_SPLASH_COLOR`   | Same background colour                                     | Yes         |
| `ANDROID_12_SPLASH_IMAGE`   | `tool/assets/native_splash/android12image.png`             | Only when Android 12 splash exists |

### 3. Generate config — `ExternalGeneratorRunner`

**File:** `lib/src/commands/app_resources/runners/external_generator_runner.dart`

Runs `make generate-native-splash-config` with the environment above. The Makefile target writes
`flutter_native_splash.yaml`, which `flutter_native_splash:create` then consumes to produce
platform-specific splash resources.

---

## Backward Compatibility

| Scenario                        | Behaviour                                                                 |
|---------------------------------|---------------------------------------------------------------------------|
| Old backend (no `android12SplashUrl`) | Download skipped, `ANDROID_12_SPLASH_IMAGE` not set, Makefile falls back to its default |
| New backend + old tools         | Tools ignore the new URL — same fallback as above                         |
| New backend + new tools         | Both images downloaded, separate `ANDROID_12_SPLASH_IMAGE` passed to Makefile |

---

## Constants

Defined in `lib/src/commands/app_resources/constants/resource_constants.dart`:

```dart
const assetSplashIconPath = 'tool/assets/native_splash/image.png';
const assetAndroid12SplashIconPath = 'tool/assets/native_splash/android12image.png';
```

---

## Configurator Frontend Context

The configurator frontend exposes a **multi-page designer** for splash screens:

- **Page 1 — Splash (common/primary):** produces the standard splash image.
- **Page 2 — Android 12:** produces the Android 12 variant with dedicated sizing constraints
  (288 / 192 / 288 dp).

On save, both pages are exported and uploaded via `upload-batch` with targets `splash` and
`android12Splash`.
