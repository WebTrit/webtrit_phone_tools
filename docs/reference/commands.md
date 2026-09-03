# The commands

Everything `webtrit_phone_tools` can be asked to do, and what each one needs.
A build runs them in the order below; a person runs whichever one they are
debugging. Every command takes an optional `<directory>` - the phone project it
works in, the working directory when it is left out.

```bash
webtrit_phone_tools <command> [<directory>] [options]
```

---

## `configurator-resources`

Fetches everything a brand's build needs from the configurator backend -
assets, translations, themes - and writes the keystore and metadata files the
later commands read.

| Option | Required | What it is |
| --- | --- | --- |
| `--applicationId` | yes | The configurator application id |
| `--token` | yes | A signed-in token, or an administrator-minted build key (`wtc_...`) |
| `--keystores-path` | yes | The project's keystore folder |
| `--cache-session-data-path` | no | Where the session data is cached between processes |

Which backend it asks is not an option: it is the revision of this repository
the build checked out
([backend-address.md](../architecture/backend-address.md)).

## `configurator-generate`

Turns what was fetched into the files a Flutter build reads - `dart_define`,
the native splash configuration, the launch icons.

| Option | Required | What it is |
| --- | --- | --- |
| `--keystore-path` | no | The project's keystore folder |
| `--bundleIdAndroid` | no | The Android application identifier |
| `--bundleIdIos` | no | The iOS application identifier |
| `--cache-session-data-path` | no | The cache written by `configurator-resources` |

The splash and launch half of this is [splash-assets.md](splash-assets.md).

## `configurator-setup`

Runs the platform-specific setup a build needs before it can be built.

| Option | Required | What it is |
| --- | --- | --- |
| `--platform` | no | `ios` or `android`. May be given more than once; nothing else is allowed |
| `--keystore-path` | yes | The application keystore directory, absolute or relative to the phone project. Given explicitly rather than taken from the cache, which may name a path from another operating system |
| `--cache-session-data-path` | no | The `cache_session_data.json` that `configurator-resources` produced. Defaults to that name in the working directory |

## `configurator-translations-fetch`

Writes the translation catalogue into the phone repository's ARB files.

| Option | Required | What it is |
| --- | --- | --- |
| `--token` | no | A token for the configurator API. Falls back to `CONFIGURATOR_TOKEN` |
| `--output` | no | Where the ARB files are written, relative to `<directory>`. Defaults to `<phone>/lib/l10n/arb` |

## `update`

Updates the CLI itself.
