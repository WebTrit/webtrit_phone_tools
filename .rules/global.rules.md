# GLOBAL DART CLI CODING STANDARDS

**[CRITICAL]** These rules apply to ALL files and ALL requests. You must strictly follow them before
writing any code.

## 1. CRITICAL: CLEAN CODE & GIT FLOW

* **No Cyrillic:** Strictly prohibited anywhere in the codebase. This includes source files,
  comments, strings, logs, identifiers, JSON/YAML keys, and commit messages.
* **Self-Documenting Code:** Code must be clean and self-explanatory. Do not write comments to
  describe logic or use them as visual separators. Use DartDoc strictly for public APIs.
* **No Conversational Filler:** AI tools or generators must output pure, commit-ready code without
  unnecessary explanations.
* **Branch Naming:** Must follow the pattern: `feature/*`, `refactor/*`, `fix/*`, `chore/*`,
  `build/*`, `style/*`, `docs/*`, or `release/*`.
* **Commit Messages:** Must follow Conventional Commits format (e.g.,
  `feat(keystore): add verify command`,
  `fix: resolve crash on missing config`).

## 2. DART STANDARDS & FORMATTING

* **Formatter & Linter:** Page width is strictly `120` characters. Prefer single quotes
  (`prefer_single_quotes: true`).
* **Callbacks:** Must be concise and single-expression only. If a callback requires multiple
  statements, extract the logic into a private method.
* **Parameters:** Required named parameters MUST always be declared before optional named
  parameters.
* **Doubles:** Avoid unnecessary `.0` literals. Do not force double values when not strictly
  required by the API or type context.
* **No Dead Code:** Remove unused variables, imports, and commented-out code before committing.
* **Avoid `dynamic`:** Use explicit types wherever possible. Only use `dynamic` or `Object?` when
  genuinely necessary (e.g., JSON parsing boundaries).

## 3. IMPORT ORDERING

Imports must be grouped into specific sections and sorted alphabetically within each group. Sections
must be separated by exactly **one empty line**. Omit any section if it has no imports. Do not add
comments to describe the sections.

1. **Dart SDK** (`import 'dart:async';`)
2. **External dependencies** (`import 'package:args/command_runner.dart';`)
3. **Internal/project package imports** (
   `import 'package:webtrit_phone_tools/src/commands/commands.dart';`)
4. **Relative imports** (`import '../models/models.dart';`)

## 4. BARREL FILES

* Each directory with multiple files must export its contents via a `<directory_name>.dart` barrel
  file.
* Barrel files must list exports in alphabetical order.
* Do not re-export symbols that are purely internal implementation details.

## 5. ERROR HANDLING & LOGGING

* **`mason_logger`:** Use the project's `Logger` instance (injected via constructor) for all
  terminal output. Never use `print()` or `stdout.write()` directly.
* **Log Levels:** Use `logger.info()` for progress, `logger.success()` for completion,
  `logger.err()` for errors, `logger.detail()` for verbose/debug output.
* **Exit Codes:** Commands must return meaningful exit codes (`ExitCode.success.code`,
  `ExitCode.software.code`, etc.) from `run()`. Never call `exit()` directly from within a command.
* **Exceptions:** Catch specific exception types, not bare `catch (e)`. Always log the error before
  rethrowing or returning a non-zero exit code.

## 6. GIT FLOW & CONVENTIONAL COMMITS

* **Branching:** Use specific prefixes: `feature/`, `refactor/`, `fix/`, `chore/`, `build/`,
  `style/`, `docs/`, `release/`.
* **Commits:** Strictly follow Conventional Commits.
    * Allowed types: `feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `style`, `ci`, `perf`,
      `build`, `revert`.
    * Example: `feat(keystore): add init command`.
* **No Cyrillic:** This applies to branch names and commit messages as well. English only.
