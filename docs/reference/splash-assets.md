# Splash and launch icons

What `configurator-resources` downloads for a brand's splash screen and launch
icons, and the three generator configs it writes so the phone project can turn
them into platform resources.

The constraints an image has to satisfy before any of this is worth running are
the configurator's:
[splash-and-icon-constraints.md](https://github.com/WebTrit/webtrit_phone_configurator/blob/main/docs/reference/splash-and-icon-constraints.md).

---

## The shape of it

```
the build bundle  ──►  files written into the phone checkout  ──►  three YAML configs
 (paths + colors)      tool/assets/native_splash/…                tool/configs/…
                        tool/assets/launcher_icons/…               read by the phone's generators
```

Every path below is inside the **phone project** being configured, not inside
this repository, and is written `<phone>/…` for that reason. They are constants here
(`lib/src/commands/app_resources/constants/resource_constants.dart`) because
the phone's generators look for them by name.

| Written to | What it is |
| --- | --- |
| `<phone>/tool/assets/native_splash/image.png` | The splash image every platform uses |
| `<phone>/tool/assets/native_splash/android12image.png` | The Android 12+ splash, when the brand has one |
| `<phone>/tool/assets/launcher_icons/android.png`, `ios.png`, `web.png` | The launch icon per platform |
| `<phone>/tool/assets/launcher_icons/ic_foreground.png` | The adaptive foreground for Android |

## The three configs it writes

`GeneratorConfigProcessor` writes them into the phone checkout, where its
generators look:

| File | Read by |
| --- | --- |
| `<phone>/tool/configs/flutter_native_splash.yaml` | `flutter_native_splash` |
| `<phone>/tool/configs/flutter_launcher_icons.yaml` | `flutter_launcher_icons` |
| `<phone>/tool/configs/package_rename_config.yaml` | `package_rename` - the launch name and the bundle identifier per platform |

They are written here rather than asked of `make` in the phone repository: what
they hold is four strings out of the bundle, and running a makefile to echo
them meant the phone's makefile was parsed - and its shared include fetched
over the network - during every release build.

## The Android 12 splash is optional

Which image the Android 12 block names is decided by whether the bundle wrote
one, asked of the file rather than of an address: `writesTo` looks for
`<phone>/tool/assets/native_splash/android12image.png` among the files the bundle
carries. When it is not there, the standard splash image is named for Android
12 as well.

## A missing color

Both halves are skipped rather than guessed, and each says so:

| | |
| --- | --- |
| The splash has no `backgroundColorHex` | `Skipping splash generation: backgroundColorHex is null.` and no `flutter_native_splash.yaml` |
| The launcher has no `backgroundColorHex` | `Skipping launcher generation: backgroundColorHex is null.` and no `flutter_launcher_icons.yaml` |

The launcher's own background is the splash's when the brand set one, and its
`theme_color` is always the launcher's - so an icon and the screen behind it
agree without the brand having to say the color twice.
