# Architecture Rules — Orchestrator Pattern

## 1. Overview

Complex commands (those requiring API fetching, file I/O, and external process execution) MUST
follow the **Orchestrator Pattern**. Each such command is organized into a self-contained
subdirectory under `lib/src/commands/<feature_name>/`.

## 2. Layer Responsibilities

| Layer            | Naming                            | Responsibility                                                                |
|------------------|-----------------------------------|-------------------------------------------------------------------------------|
| **Command**      | `<Name>Command`                   | Parses CLI args, validates input, builds `Context`, delegates to layers below |
| **Context**      | `<Name>Context`                   | Immutable validated state; passed between all layers                          |
| **Service**      | `<Name>Fetcher` / `<Name>Service` | Fetches remote data (API calls); pure I/O, no business logic                  |
| **Processor**    | `<Name>Processor`                 | Transforms/writes data (file I/O, JSON manipulation, asset downloads)         |
| **Runner**       | `<Name>Runner`                    | Executes external processes (`flutter`, `dart`, `keytool`, `make`, `git`)     |
| **Factory/Util** | `<Name>Factory` / `<Name>Util`    | Pure stateless helpers; no side effects                                       |

## 3. Layer Rules

* **Context is immutable:** Never mutate a `Context` after creation. If additional data is needed
  downstream, create a new context or pass data explicitly.
* **No cross-layer skipping:** A `Command` must not call a `Runner` directly without going through
  a `Processor` or `Service` when applicable.
* **Services are pure fetchers:** Services must not perform file I/O or spawn processes. They only
  interact with remote APIs or in-memory transformations.
* **Processors own file I/O:** All file reading/writing must happen in `Processor` classes. Do not
  perform file I/O in `Command`, `Service`, or `Runner`.
* **Runners own process spawning:** All `Process.start()` or `Process.runSync()` calls must live in
  `Runner` classes. Never spawn processes in `Command` or `Processor`.

## 4. Directory Structure

Each complex command directory must follow this layout:

```
lib/src/commands/<feature_name>/
├── <feature_name>.dart          # Barrel export
├── <name>_command.dart          # Main command class
├── models/
│   ├── models.dart
│   └── <name>_context.dart
├── services/                    # (optional — only if API calls are needed)
│   ├── services.dart
│   └── <name>_fetcher.dart
├── processors/                  # (optional — only if file I/O is needed)
│   ├── processors.dart
│   └── <name>_processor.dart
├── runners/                     # (optional — only if external processes are needed)
│   ├── runners.dart
│   └── <name>_runner.dart
├── interceptors/                # (optional — only if Dio interceptors are needed)
│   ├── interceptors.dart
│   └── <name>_interceptor.dart
└── utils/                       # (optional — only if feature-specific helpers are needed)
    ├── utils.dart
    └── <name>_util.dart
```

## 5. Dependency Injection

* **Constructor injection only:** Pass `Logger`, `HttpClient`, datasource instances via constructor
  arguments. Never use global singletons or service locators.
* **Testability:** All external dependencies (logger, HTTP client, process runner) must be
  injectable so they can be replaced with `mocktail` mocks in tests.

## 6. External Process Execution

* Use `Process.start()` for long-running processes that stream output (e.g., `flutter build`).
* Use `Process.runSync()` for short blocking operations (e.g., `keytool -list`).
* Always check the process exit code and log errors via `logger.err()` before propagating failures.
* Never hardcode absolute binary paths; rely on the system `PATH`.

## 7. HTTP & Retry

* All HTTP interactions with the WebTrit Configurator backend use the `data` package's
  `ConfiguratorBackandDatasource` wrapped with Dio.
* Retry logic (exponential backoff, max 3 retries) for 5xx errors and connection timeouts must be
  implemented as a Dio `Interceptor` subclass inside `interceptors/`.
* Fast-fail (do not retry) on 4xx client errors, especially 401 Unauthorized.

## 8. Template Rendering

* Mustache templates live in `assets/` and are stringified into Dart constants in
  `lib/src/gen/stringify_assets.dart` by `stringify_assets.sh`.
* Never embed large template strings directly in source files.
* Use `TemplateExtension.renderAndCleanJson()` which prunes null/empty fields after rendering.

## 9. Extension Methods

* Extension classes must be placed in `lib/src/extension/`.
* Each extension file must contain exactly one extension and be named `<type>_extension.dart`.
* Extensions must remain pure (no side effects, no I/O).
* Export all extensions via `lib/src/extension/extension.dart`.
