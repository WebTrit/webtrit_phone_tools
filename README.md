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

## The backend a build talks to

The address of the configurator backend is a constant in this repository, so the
**revision checked out is the choice** - no caller can override it. `main` faces
the Cloud Run backend; `legacy/firebase-backend` is frozen at the last commit
that faced the Firebase one, for configurators deployed before the move. Details,
and why pointing an address elsewhere is not the same thing:
[`docs/architecture/backend-address.md`](docs/architecture/backend-address.md).

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

[**docs/README.md**](docs/README.md) is the map: every page, one line each, and
the routes through them - running the CLI, a build talking to the wrong
backend, a splash screen that came out wrong.

- [The commands](docs/reference/commands.md) - every command and its options
- [The backend a build talks to](docs/architecture/backend-address.md) - and why the revision decides it
- [Splash and launch icons](docs/reference/splash-assets.md) - what is downloaded and what is generated
- [Running it](docs/guides/running-it.md) - from a checkout, and the checks a pull request runs

The coding standards - imports, barrel files, error handling, the orchestrator
pattern, the git flow - are in `AGENTS.md`.
