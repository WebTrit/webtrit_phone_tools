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

## Which backend a build talks to

The address of the configurator backend is a constant in this repository, so the
**revision checked out is the choice** - no caller can override it. `main` faces
the Cloud Run backend; `legacy/firebase-backend` is frozen at the last commit
that faced the Firebase one, for configurators deployed before the move. Details,
and why pointing an address elsewhere is not the same thing:
[`docs/which_backend_a_build_talks_to.md`](docs/which_backend_a_build_talks_to.md).

---

## Usage

### Android Keystore Signing

Nothing here makes a keystore any more. The configurator backend does, on the deploy screen, and
the result lands in the Secrets catalogue as a credential like any other; a build reads it from the
slot it is linked to rather than from a checkout.

The only reason this ever needed a JVM was the belief that it produced a JKS. It did not: `keytool
-genkeypair` under Java 9+ writes PKCS#12 whatever the file is called.

### Resources & Configuration

Core commands for fetching assets, translations, and themes.

```sh
# Fetch resources (assets, translations, themes)
$ webtrit_phone_tools resources-get --applicationId=<id> --token=<jwt> --keystores-path=<path>

# Generate local configuration files
$ webtrit_phone_tools configurator-generate


```

---

## Documentation

- [Architecture & Orchestrator Pattern](.rules/architecture.rules.md)
- [CLI Commands Conventions](.rules/commands.rules.md)
- [Global Coding Standards](.rules/global.rules.md)
- [Shared Makefile Reference](docs/shared_makefile_reference.md)
- [Splash Asset Pipeline](docs/splash_asset_pipeline.md)
