# AGENTS.md — ynab-api-dart

## Project Overview

A Dart CLI for working with the YNAB (You Need A Budget) API. The CLI uses `CommandRunner` from the `args` package to expose subcommands for reading and mutating YNAB data. Authentication is via the `YNAB_API_TOKEN` environment variable.

## Tech Stack

- **Language**: Dart (SDK `^3.11.1`)
- **CLI framework**: `package:args` (`CommandRunner` / `Command`)
- **HTTP**: `package:http`
- **YAML parsing**: `package:yaml`
- **Linting**: `package:lints/recommended.yaml`
- **Testing**: `package:test` (dev dependency)

## Directory Structure

```text
ynab-api/
  bin/
    ynab_api_dart.dart         # CLI entry point — wires CommandRunner, handles top-level errors
  lib/
    ynab_client.dart           # YnabClient — HTTP calls to YNAB API
    ynab_command.dart          # YnabCommand base class + YnabCommandRunner
    commands/                  # one file per command
      accounts_command.dart
      transactions_command.dart
      update_command.dart
    formatters.dart            # shared output helpers (printTable, formatAmount, etc.)
  test/                         # unit and integration tests
  example_transaction.yaml      # sample YAML for the update command
  pubspec.yaml
  analysis_options.yaml
```

## Core Conventions

### Before Committing

- Follow `package:lints/recommended.yaml`. Run `dart analyze`.
- Fix linting errors with `dart fix --apply`.
- Format all Dart files with `dart format .`.
- Run tests with `dart test`.
- Use explicit type annotations for public APIs; inference is fine for local variables.

### Exit Codes

- `0`: Success
- `1`: Runtime error (API failure, file error, invalid input)
- `64`: Usage error (bad flags or missing required args)

Exit-code handling lives in the `main()` function's `try/catch` chain. Individual commands return `int` (always `0` on success) and throw on failure.

### Error Handling

- Commands must never catch exceptions for control flow. Let errors propagate to `main()`.
- Use `YnabApiException` for any YNAB API error (HTTP status, network, unexpected response shape).
- Use `CliException` for user-facing validation errors that don't fit `UsageException`.
- Use `UsageException` (from `package:args`) only for flag/argument problems.
- Write error messages to `stderr` — never `stdout`.
- Error messages should be human-readable sentences, not stack traces.

### Authentication

- All commands read the token from `Platform.environment['YNAB_API_TOKEN']`.
- The `readToken()` method on `YnabCommand` handles the missing-token case.
- Never log, print, or persist the token.

## Adding a New Command

Every new command follows this checklist:

### 1. Create the Command Class

Extend `YnabCommand`. Each command must define:

- `name` — the CLI verb (kebab-case, e.g. `create-transaction`).
- `description` — one-line summary shown in `--help`.
- `run()` — async, returns `Future<int>` (`0` on success).

Register arguments in the constructor via `argParser.addOption(...)` or `argParser.addFlag(...)`. Use `mandatory: true` for required options.

```dart
class BudgetsCommand extends YnabCommand {
  @override
  final String name = 'budgets';

  @override
  final String description = 'List all budgets for the authenticated user.';

  @override
  Future<int> run() async {
    final budgets = await withClient(
      (client) => client.getBudgets(),
    );
    // format and print
    return 0;
  }
}
```

### 2. Add the API Method to `YnabClient`

- Place the new method in `lib/ynab_client.dart`.
- Follow the existing pattern: call `_get` / `_put` / `_post` / `_delete`, decode the response, validate the shape, and return typed data.
- Prefer `List<Map<String, dynamic>>` for collection endpoints and `Map<String, dynamic>` for single-resource endpoints.
- Add a new private `_post` or `_delete` helper in `YnabClient` if the HTTP verb doesn't exist yet, mirroring the style of `_get` and `_put`.

### 3. Register the Command

In the `YnabCommandRunner` constructor, add:

```dart
addCommand(BudgetsCommand());
```

### 4. Write Tests

- Place test files in `test/` with the pattern `<command_name>_test.dart` or `ynab_client_test.dart`.
- Use `package:test`.
- Mock HTTP via the `httpClient` parameter on `YnabClient`.
- Test both success and error paths (invalid responses, non-200 status codes, network errors).

### 5. Update Documentation

- Add the new command to the **Usage** section in `README.md` with example invocations.
- If the command accepts YAML input, add or update an example YAML file.

## API Client (`lib/ynab_client.dart`)

### Design Rules

- The base URL is `https://api.ynab.com/v1`. It must not be hard-coded elsewhere.
- Every HTTP call goes through `_send()`, which handles non-2xx responses and network exceptions uniformly.
- Response parsing: decode JSON with `_decodeJson`, then navigate the `data` wrapper to extract the resource. Validate the type (`is List`, `is Map`) before returning.
- The client is stateless (no caching). The caller creates it, uses it, and calls `close()`.
- `withClient()` in `YnabCommand` ensures `close()` is always called.

### Adding New HTTP Verbs

If a YNAB endpoint requires POST, PATCH, or DELETE, add a private helper that mirrors `_get` / `_put`:

```dart
Future<http.Response> _post(Uri uri, {required String body}) {
  return _send(() => _httpClient.post(uri, headers: _headers, body: body));
}
```

## Output Formatting

- Use `printTable()` for any command that returns a list of resources.
- Column headers should be short, human-readable labels.
- Amounts are stored in milliunits. Always convert with `formatAmount()` before displaying.
- For single-resource output (like `update`), print key fields as labeled lines.
- Write output to `stdout`. Never mix `stderr` output into success responses.

## Testing

- Framework: `package:test`.
- File naming: `test/<name>_test.dart`.
- Mock the HTTP client — do not make real network calls in tests.
- `YnabClient` accepts an optional `http.Client` for this purpose.
- Cover: success responses, API error responses (4xx/5xx), network exceptions, malformed JSON, missing fields.
- Run tests with `dart test`.

## Environment Variables

- `YNAB_API_TOKEN`: Required. Personal access token from YNAB Developer Settings.

## Dependencies Policy

- Keep dependencies minimal. Prefer the Dart standard library when it suffices.
- Pin major versions in `pubspec.yaml` with caret syntax (`^x.y.z`).
- Remove unused dependencies promptly to keep the CLI lean.
- Run `dart pub upgrade --major-versions` periodically to stay current, but verify nothing breaks.

## Git & Commit Conventions

- Commit messages: imperative mood, concise summary line (≤72 chars). E.g. `Add budgets command with list output`.
- One logical change per commit. Don't mix feature work with formatting fixes.
- Run `dart analyze` and `dart format .` before every commit.
