# webtrit_phone_tools

**WebTrit Phone CLI tools** — A comprehensive toolkit for automating the preparation, configuration,
and signing of WebTrit mobile applications.

---

## Getting Started

Activate the CLI globally via **pub.dev**:

```sh
dart pub global activate webtrit_phone_tools

```

Or install it locally from the source:

```sh
dart pub global activate --source=path <path_to_package>

```

---

## Usage

### Android Keystore Signing

Tools for managing signing keys and certificates.

```sh
# Generate a new keystore
$ webtrit_phone_tools keystore-generate --bundleId="com.webtrit.app" --appendDirectory ../keystores

# Commit changes to the keystore repository
$ webtrit_phone_tools keystore-commit --bundleId="com.webtrit.app" --appendDirectory ../keystores

# Verify an existing keystore
$ webtrit_phone_tools keystore-verify ../keystores/com.webtrit.app

```

### Resources & Configuration

Core commands for fetching assets, translations, and themes.

```sh
# Fetch resources (assets, translations, themes)
$ webtrit_phone_tools resources-get --applicationId=<id> --token=<jwt> --keystores-path=<path>

# Generate local configuration files
$ webtrit_phone_tools configurator-generate

# Create metadata (Assetlinks and Apple App Site Association)
$ webtrit_phone_tools assetlinks-generate --bundleId=<id> --appleTeamID=<id> --androidFingerprints=<sha256> --output=<path>

```

---

## Architecture

Complex commands in this toolkit follow the **Orchestrator Pattern**. This design ensures a clean
separation of concerns, making the code easier to test, maintain, and scale.

### Layer Responsibilities

| Layer          | Entity                      | Responsibility                                                                                                                                                                           |
|----------------|-----------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Command**    | `...Command`                | **The Conductor.** Parses CLI arguments, initializes the `Context`, and dictates the execution flow. It contains no data processing logic.                                               |
| **Context**    | `...Context`                | **The State.** An immutable object that holds all validated parameters (paths, IDs, tokens). It acts as the single source of truth passed between layers.                                |
| **Services**   | `...Fetcher` / `...Service` | **External Data.** Handles interactions with APIs or external databases. Returns clean DTOs or models to the conductor.                                                                  |
| **Processors** | `...Processor`              | **Business Logic & I/O.** Manages data transformation, asset migration, and disk read/write operations. Each processor handles one logical domain.                                       |
| **Util**       | `...Util`                   | **The Toolbox. Stateless logic containing reusable helpers specific to the command’s domain. It handles repetitive tasks like string manipulation, path formatting, or data validation.. |
| **Runners**    | `...Runner`                 | **Infrastructure.** Executes external system commands (`make`, `shell scripts`, etc.) and handles their `stdout` and `stderr` streams.                                                   |

### Execution Flow

1. **Parsing:** The `Command` extracts raw data from `argResults`.
2. **Contextualization:** A `Context` is built, normalizing paths and validating inputs.
3. **Fetching:** A `Service` retrieves necessary remote data.
4. **Processing:** One or more `Processors` perform file system manipulations or data transforms.
5. **Execution:** If required, a `Runner` triggers external processes to finalize the output.
6. **Exit:** The command returns a standard `ExitCode`.

---

## Providing Assets for Builds

Since Dart CLI tools do not have a native "assets" mechanism like Flutter, we use **stringification
** to embed resources directly into the CLI binary.

Run this script before building the package:

```sh
./stringify_assets.sh assets lib/src/gen/stringify_assets.dart

```

---

## Documentation

For build flavor logic and advanced usage via Makefile, see
the [Shared Makefile Reference](https://www.google.com/search?q=docs/shared_makefile_reference.md).
