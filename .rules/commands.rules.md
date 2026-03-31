# CLI Commands Rules

## 1. Command Structure

* **Base class:** All leaf commands must extend `Command<int>`. Sub-command groups must extend
  `Command<int>` and register child commands in their constructor via `addSubcommand(...)`.
* **Return type:** `run()` must always return `Future<int>` (or `int`). Use `ExitCode.success.code`
  (0) for success and `ExitCode.software.code` (1) for errors.
* **Registration:** All top-level commands must be registered in `WebtritPhoneToolsCommandRunner`
  constructor via `addCommand(...)`.

## 2. Argument & Option Parsing

* **Named options** (not positional args) are preferred for all non-trivial inputs.
* **Mandatory options:** Use `argParser.addOption()` with `mandatory: true` for required inputs.
  Do not perform manual null checks on required options that `args` already enforces.
* **Defaults:** Provide sensible `defaultsTo` values for optional flags where applicable.
* **Help strings:** Every `addOption()` and `addFlag()` call must include a descriptive `help:`
  string.
* **Parse in `run()`:** Always resolve `argResults` inside `run()`, not in the constructor.

## 3. Validation

* Validate all user-provided inputs (file paths, URLs, identifiers) at the beginning of `run()`
  before performing any I/O or spawning processes.
* Log a clear error message via `logger.err()` and return `ExitCode.usage.code` on invalid input.

## 4. Logging Conventions

* Use `logger.progress()` to display a spinner for operations that take time (HTTP requests, process
  execution). Always call `.complete()` or `.fail()` on the progress instance.
* Use `logger.success()` for successful completion messages.
* Use `logger.err()` for error messages visible to the user.
* Use `logger.detail()` for verbose output that users would only see with a `--verbose` flag.
* Never use `print()`, `stdout`, or `stderr` directly.

## 5. Dependency Injection in Commands

* Commands receive all external dependencies (e.g., `Logger`, `ConfiguratorBackandDatasource`,
  `HttpClient`) via their constructor.
* Store dependencies as `final` private fields (e.g., `final Logger _logger`).
* The `CommandRunner` is responsible for constructing and injecting dependencies into commands.

## 6. Command Naming & Help

* Command names must be lowercase, hyphen-separated (e.g., `keystore-generate`, `resources-get`).
* `description` and `summary` must be set on every command for `--help` output.
* Use `CommandHelpFormatter` (or equivalent utility) for complex multi-line help formatting.

## 7. Testing Commands

* Every command must have a corresponding test file in `test/src/commands/`.
* Tests use `mocktail` to mock `Logger`, `PubUpdater`, datasource, and other injected dependencies.
* The command runner is tested end-to-end: construct a `WebtritPhoneToolsCommandRunner` with mocked
  dependencies, invoke `run(['command', '--flag', 'value'])`, and assert on the exit code and logger
  interactions.
* Use `setUp`/`tearDown` for test lifecycle management.

## 8. Update Command

* The `update` command is a special built-in command that checks for a newer version on pub.dev via
  `PubUpdater`. It must remain independent of all other commands and have no side effects beyond
  writing to stdout.

## 9. Simple vs Orchestrated Commands

* **Simple commands** (single responsibility, minimal I/O): Implement all logic directly in the
  `Command` subclass without sub-directories.
    * Examples: `update_command.dart`, `assetlinks_generate_command.dart`
* **Complex commands** (multi-step, API + file I/O + external processes): Use the **Orchestrator
  Pattern** as defined in `.rules/architecture.rules.md`.
    * Examples: `app_resources/`, `app_configure/`
