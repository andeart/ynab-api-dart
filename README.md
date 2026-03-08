# ynab-api-dart

[![CI](https://github.com/andeart/ynab-api-dart/actions/workflows/ci.yml/badge.svg)](https://github.com/andeart/ynab-api-dart/actions/workflows/ci.yml)

## Overview

`ynab-api-dart` is a Dart CLI for working with the YNAB API. The commands currently implemented let you:

1. **List accounts** to discover account IDs
2. **List transactions** to discover transaction IDs, optionally filtered by account and date
3. **Update a transaction** by supplying the fields to change in a YAML file

All commands authenticate via the `YNAB_API_TOKEN` environment variable.

## Features

- List accounts for a plan/budget and inspect their IDs, types, and balances.
- List transactions for a specific account, with optional date filtering.
- Update a single transaction using a YAML file that contains only the fields you want to change.
- More coming soon.

## API Endpoints

### 1. List accounts

- **GET** `https://api.ynab.com/v1/budgets/{plan_id}/accounts`
- Response: `data.accounts[]` — each has `id`, `name`, `type`, `on_budget`, `closed`, `balance` (milliunits)

### 2. List transactions by account

- **GET** `https://api.ynab.com/v1/budgets/{plan_id}/accounts/{account_id}/transactions`
- Query params: `since_date` (ISO date, optional), `type` (`uncategorized` | `unapproved`, optional)
- Response: `data.transactions[]` — each has `id`, `date`, `amount`, `payee_name`, `category_name`, `memo`, `cleared`, `approved`

### 3. Update a transaction

- **PUT** `https://api.ynab.com/v1/budgets/{plan_id}/transactions/{transaction_id}`
- Body: `{"transaction": { ...fields... }}`
- Updatable fields (all optional): `account_id`, `date`, `amount` (milliunits), `payee_id`, `payee_name`, `category_id`, `memo`, `cleared`, `approved`, `flag_color`

## Setup

Create the project and install the required dependencies:

```bash
dart create -t console ynab_api_dart
cd ynab_api_dart
dart pub add http yaml args
```

Before running any command, export your YNAB personal access token:

```bash
export YNAB_API_TOKEN=your_token_here
```

## File Structure

```text
ynab_api_dart/
  bin/
    ynab_api_dart.dart      # Thin CLI entry point with top-level error handling
  lib/
    commands/
      accounts_command.dart
      transactions_command.dart
      update_command.dart
    formatters.dart         # Shared output helpers
    ynab_client.dart        # YNAB API client for the currently implemented API calls
    ynab_command.dart       # Base command + command runner
  pubspec.yaml
  example_transaction.yaml  # Example YAML input for the update command
```

## Usage

The CLI uses the `args` package `CommandRunner` to expose the currently implemented subcommands.

### `accounts` — List all accounts

```bash
dart run bin/ynab_api_dart.dart accounts --plan-id last-used
```

- `--plan-id` (`-p`): Plan/budget ID or `last-used`. **Required.**
- Output: a table of account name, ID, type, and balance.

### `transactions` — List transactions for an account

```bash
dart run bin/ynab_api_dart.dart transactions \
  --plan-id last-used \
  --account-id <uuid> \
  --since-date 2026-03-01
```

- `--plan-id` (`-p`): Plan/budget ID or `last-used`. **Required.**
- `--account-id` (`-a`): The account UUID (get it from the `accounts` command). **Required.**
- `--since-date` (`-s`): Only show transactions on or after this ISO date. Optional.
- Output: a table of transaction ID, date, amount (formatted as dollars), payee, category, memo, cleared.

### `update` — Update a single transaction

```bash
dart run bin/ynab_api_dart.dart update \
  --plan-id last-used \
  --transaction-id <uuid> \
  --file transaction.yaml
```

- `--plan-id` (`-p`): Plan/budget ID or `last-used`. **Required.**
- `--transaction-id` (`-t`): Transaction ID to update. **Required.**
- `--file` (`-f`): Path to YAML file with fields to update. **Required.**

### YAML Input Format

```yaml
date: "2026-03-01"
amount: -25000
payee_name: "Grocery Store"
memo: "Weekly groceries"
cleared: cleared
approved: true
flag_color: green
```

Only include the fields you want to change. The CLI wraps them in `{"transaction": {...}}` before sending the request to the YNAB API.

## Implementation Notes

- **`lib/ynab_client.dart`**: Defines a `YnabClient` class that stores the API token and exposes async methods for the currently implemented API operations:
  - `getAccounts(planId)` — Sends the accounts GET request and returns a parsed list.
  - `getTransactions(planId, accountId, {sinceDate})` — Sends the transactions GET request and returns a parsed list.
  - `updateTransaction(planId, transactionId, Map fields)` — Sends the PUT request and returns the parsed updated transaction.
  - Each method throws on non-200 responses using the API error message when available.
- **`lib/ynab_command.dart`**: Defines `YnabCommand`, which adds shared CLI behavior like `--plan-id`, token loading, and `withClient()`, plus `YnabCommandRunner`, which registers commands.
- **`lib/commands/`**: Contains one file per command (`AccountsCommand`, `TransactionsCommand`, `UpdateCommand`).
- **`lib/formatters.dart`**: Holds shared output helpers for tables and amount formatting.
- **`bin/ynab_api_dart.dart`**: Thin entry point that runs the command runner and maps exceptions to exit codes.

## Error Handling

- Missing `YNAB_API_TOKEN` env var: print helpful message, exit 1
- Missing required flags: `args` package prints usage automatically
- YAML parse failure: catch and print, exit 1
- HTTP non-200: print status code + API error detail from response body
- Network errors: catch `SocketException` / `ClientException`, print message

## Output Formatting

- Accounts and transactions are printed as aligned columns for readability
- Amounts are displayed in dollars (milliunits / 1000, formatted to 2 decimal places)
- The update command prints a confirmation with the key fields of the updated transaction
