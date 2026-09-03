# Running it

## From a checkout

```sh
dart pub global activate --source=path .
webtrit_phone_tools --help
```

Published as a pub.dev package, so a machine that only consumes it takes it
from there instead:

```sh
dart pub global activate webtrit_phone_tools
```

What a build runs, and in what order, is [the commands](../reference/commands.md).

## The checks a pull request runs

`.github/workflows/webtrit_phone_tools.yaml`, on any change under `bin/`,
`lib/`, `test/` or `pubspec.yaml`:

```sh
dart pub get
dart format --line-length 120 --set-exit-if-changed bin lib test
dart analyze --fatal-warnings
dart test
```

Two more jobs run beside them: a spell check, and `verify-version`, which runs
the version test with `--run-skipped` so the number the CLI reports and the one
in `pubspec.yaml` cannot drift apart.

One path dependency survives resolution: `webtrit_appearance_theme`, which the
theme step reads to decide light and dark. It lives in the phone repository, so
CI checks that out beside this one.
