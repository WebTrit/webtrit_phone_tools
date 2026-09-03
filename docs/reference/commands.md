# The commands

Everything `webtrit_phone_tools` can be asked to do, and what each one needs.
A build runs them in the order below; a person runs whichever one they are
debugging.

```bash
webtrit_phone_tools <command> [directory] [options]
```

---

## `configurator-resources`

Fetches everything a brand's build needs from the configurator backend:
assets, translations, themes, and the metadata files the later steps read.

| Option | What it is |
| --- | --- |
| `--application-id` | The configurator application id |
| `--token` | A signed-in token, or an administrator-minted build key (`wtc_...`) |

The directory it is given is where the keystore and metadata files are
created. Which backend it asks is not an option: it is the revision of this
repository the build checked out
([backend-address.md](../architecture/backend-address.md)).

## `configurator-generate`

Turns what was fetched into the files a Flutter build reads - `dart_define`,
the native splash configuration, the launch icons.

| Option | What it is |
| --- | --- |
| `--keystore-path` | The project's keystore folder |
| `--android-application-id` | The Android application identifier |
| `--ios-application-id` | The iOS application identifier |

The splash and launch half of this is [splash-assets.md](splash-assets.md).

## `configurator-setup`

Runs the platform-specific setup a build needs before it can be built:
keychains, profiles, and the platform files the phone project expects.

| Option | What it is |
| --- | --- |
| `--platform` | The platform to set up. May be given more than once |
| `--keystore-path` | The application keystore directory, absolute or relative to the phone project |
| `--session-data-path` | The `cache_session_data.json` that `configurator-resources` produced |

## `configurator-translations-fetch`

Writes the translation catalogue into the phone repository's ARB files.

| Option | What it is |
| --- | --- |
| `--token` | A token for the configurator API |
| `--directory` | Where the ARB files are written, relative to the phone repository root |

## `update`

Updates the CLI itself.
