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

### Keystore Project Initialization

Initialize a full keystore project directory for a given application. Fetches application metadata
from the Configurator API and generates the required folder structure, signing keys, deep link
metadata, and template credential files.

```sh
$ webtrit_phone_tools keystore-init --applicationId=<id> --token=<jwt> [directory]
```

The command creates the following structure under `<directory>/applications/<applicationId>/`:

```
<applicationId>/
├── assets/                              # Application assets (logos, icons, etc.)
├── build/
│   └── google-play-service-account.json # Google Play service account for CI publishing
├── deep_links/
│   └── .well-known/
│       ├── apple-app-site-association.json
│       └── assetlinks.json
├── push_notifications/
│   └── firebase-service-account.json    # Firebase service account for push notifications
├── ssl_certificates/                    # SSL certificates for the application
├── AuthKey_[key_id].p8                  # iOS APNs auth key
├── Certificates.p12                     # iOS distribution certificate
├── Provision.mobileprovision            # iOS provisioning profile
├── upload-keystore.jks                  # Android upload keystore (JKS)
├── upload-keystore.p12                  # Android upload keystore (P12)
├── upload-keystore-metadata.json        # Android keystore metadata
└── upload-store-connect-metadata.json   # App Store Connect credentials
```

Files that require manual completion are created with an `.incomplete` suffix.

### Android Keystore Signing

Tools for managing signing keys and certificates.

```sh
# Generate a new keystore
$ webtrit_phone_tools keystore-generate --bundleId="com.webtrit.app" --appendDirectory ../keystores/applications

# Commit changes to the keystore repository
$ webtrit_phone_tools keystore-commit --bundleId="com.webtrit.app" --appendDirectory ../keystores/applications

# Verify an existing keystore
$ webtrit_phone_tools keystore-verify ../keystores/applications/com.webtrit.app

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

## Documentation

- [Architecture & Orchestrator Pattern](.rules/architecture.rules.md)
- [CLI Commands Conventions](.rules/commands.rules.md)
- [Global Coding Standards](.rules/global.rules.md)
- [Shared Makefile Reference](docs/shared_makefile_reference.md)
- [Splash Asset Pipeline](docs/splash_asset_pipeline.md)
