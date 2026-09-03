# The map

Every page in this folder, what it is for, and the order they are usually read
in. Each folder has its own `README.md` saying what belongs there; this page is
the one that lists everything at once.

- **[architecture/](architecture/)** - why this CLI is shaped this way
- **[guides/](guides/)** - how to do a thing
- **[reference/](reference/)** - what it exposes, named exactly

---

## Reading paths

**Running it, or debugging one step of a build**
[guides/running-it.md](guides/running-it.md) → [reference/commands.md](reference/commands.md)

**A build talking to the wrong backend**
[architecture/backend-address.md](architecture/backend-address.md)

**A splash screen or launch icon that came out wrong**
[reference/splash-assets.md](reference/splash-assets.md) → [the configurator's constraints](https://github.com/WebTrit/webtrit_phone_configurator/blob/main/docs/reference/splash-and-icon-constraints.md)

---

## architecture/

[Folder README](architecture/README.md).

| Page | What it holds |
| --- | --- |
| [backend-address.md](architecture/backend-address.md) | Which backend a build talks to, and why the revision decides it |

## guides/

[Folder README](guides/README.md).

| Page | What it holds |
| --- | --- |
| [running-it.md](guides/running-it.md) | Running the CLI from a checkout, and the checks a pull request runs |

## reference/

[Folder README](reference/README.md).

| Page | What it holds |
| --- | --- |
| [commands.md](reference/commands.md) | Every command, its options, and what has to have run before it |
| [splash-assets.md](reference/splash-assets.md) | The splash and launch icon pipeline, and the constants behind it |

---

## The other repositories

| Repository | What it holds | Its documentation |
| --- | --- | --- |
| `webtrit_phone_configurator_backend` | What this CLI fetches: themes, translations, assets, credentials | [docs/README.md](https://github.com/WebTrit/webtrit_phone_configurator_backend/blob/main/docs/README.md) |
| `webtrit_phone_configurator` | The web app a brand is configured in | [docs/README.md](https://github.com/WebTrit/webtrit_phone_configurator/blob/main/docs/README.md) |
| `webtrit_phone_builder` | The workflows that run these commands | [docs/README.md](https://github.com/WebTrit/webtrit_phone_builder/blob/main/docs/README.md) |
| `webtrit_phone` | The app these commands configure | its own README |

---

`dart run tool/docs_gate.dart` holds this together: every link resolves, every
page is reachable from a README, and every repository path in backticks names a
file that is there.
