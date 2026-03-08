import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:yaml/yaml.dart';
import 'package:ynab_api_dart/ynab_client.dart';

const Set<String> _allowedUpdateFields = <String>{
  'account_id',
  'date',
  'amount',
  'payee_id',
  'payee_name',
  'category_id',
  'memo',
  'cleared',
  'approved',
  'flag_color',
};

Future<void> main(List<String> arguments) async {
  final runner = YnabCommandRunner();

  try {
    final code = await runner.run(arguments) ?? 0;
    exitCode = code;
  } on UsageException catch (error) {
    stderr.writeln(error);
    exitCode = 64;
  } on YnabApiException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln('File error: ${error.message}');
    exitCode = 1;
  } on YamlException catch (error) {
    stderr.writeln('YAML parse failure: $error');
    exitCode = 1;
  } on _CliException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } catch (error) {
    stderr.writeln('Unexpected error: $error');
    exitCode = 1;
  }
}

class YnabCommandRunner extends CommandRunner<int> {
  YnabCommandRunner()
    : super(
        'ynab-api-dart',
        'List YNAB accounts, inspect transactions, and update a transaction.',
      ) {
    addCommand(AccountsCommand());
    addCommand(TransactionsCommand());
    addCommand(UpdateCommand());
  }
}

abstract class YnabCommand extends Command<int> {
  YnabCommand() {
    argParser.addOption(
      'plan-id',
      abbr: 'p',
      mandatory: true,
      help: 'Plan or budget ID, or "last-used".',
    );
  }

  String get planId => argResults!['plan-id'] as String;

  String readToken() {
    final token = Platform.environment['YNAB_API_TOKEN'];
    if (token == null || token.trim().isEmpty) {
      throw const _CliException(
        'Missing YNAB_API_TOKEN environment variable. '
        'Export it before running the CLI.',
      );
    }

    return token.trim();
  }

  Future<T> withClient<T>(Future<T> Function(YnabClient client) action) async {
    final client = YnabClient(readToken());
    try {
      return await action(client);
    } finally {
      client.close();
    }
  }
}

class AccountsCommand extends YnabCommand {
  @override
  final String name = 'accounts';

  @override
  final String description = 'List all accounts for a YNAB plan.';

  @override
  Future<int> run() async {
    final accounts = await withClient((client) => client.getAccounts(planId));
    final rows = accounts
        .map(
          (account) => <String>[
            _stringValue(account['name']),
            _stringValue(account['id']),
            _stringValue(account['type']),
            _formatAmount(account['balance']),
          ],
        )
        .toList(growable: false);

    _printTable(
      headers: const <String>['Name', 'ID', 'Type', 'Balance'],
      rows: rows,
    );
    return 0;
  }
}

class TransactionsCommand extends YnabCommand {
  TransactionsCommand() : super() {
    argParser
      ..addOption(
        'account-id',
        abbr: 'a',
        mandatory: true,
        help: 'Account UUID.',
      )
      ..addOption(
        'since-date',
        abbr: 's',
        help: 'Only show transactions on or after this ISO date.',
      )
      ..addOption(
        'type',
        allowed: const <String>['uncategorized', 'unapproved'],
        help: 'Optional YNAB transaction type filter.',
      );
  }

  @override
  final String name = 'transactions';

  @override
  final String description = 'List transactions for an account.';

  @override
  Future<int> run() async {
    final accountId = argResults!['account-id'] as String;
    final sinceDate = argResults!['since-date'] as String?;
    final type = argResults!['type'] as String?;

    final transactions = await withClient(
      (client) => client.getTransactions(
        planId,
        accountId,
        sinceDate: sinceDate,
        type: type,
      ),
    );

    final rows = transactions
        .map(
          (transaction) => <String>[
            _stringValue(transaction['id']),
            _stringValue(transaction['date']),
            _formatAmount(transaction['amount']),
            _stringValue(transaction['payee_name']),
            _stringValue(transaction['category_name']),
            _stringValue(transaction['memo']),
            _stringValue(transaction['cleared']),
          ],
        )
        .toList(growable: false);

    _printTable(
      headers: const <String>[
        'ID',
        'Date',
        'Amount',
        'Payee',
        'Category',
        'Memo',
        'Cleared',
      ],
      rows: rows,
    );
    return 0;
  }
}

class UpdateCommand extends YnabCommand {
  UpdateCommand() : super() {
    argParser
      ..addOption(
        'transaction-id',
        abbr: 't',
        mandatory: true,
        help: 'Transaction UUID to update.',
      )
      ..addOption(
        'file',
        abbr: 'f',
        mandatory: true,
        help: 'Path to YAML file containing fields to update.',
      );
  }

  @override
  final String name = 'update';

  @override
  final String description = 'Update a single transaction using a YAML file.';

  @override
  Future<int> run() async {
    final transactionId = argResults!['transaction-id'] as String;
    final filePath = argResults!['file'] as String;
    final fields = _readUpdateFields(filePath);

    if (fields.isEmpty) {
      throw const _CliException(
        'The YAML file does not contain any update fields.',
      );
    }

    final invalidFields = fields.keys
        .where((field) => !_allowedUpdateFields.contains(field))
        .toList(growable: false);
    if (invalidFields.isNotEmpty) {
      throw _CliException(
        'Unsupported update field(s): ${invalidFields.join(', ')}',
      );
    }

    final updatedTransaction = await withClient(
      (client) => client.updateTransaction(planId, transactionId, fields),
    );

    stdout.writeln('Updated transaction successfully:');
    stdout.writeln('  ID: ${_stringValue(updatedTransaction['id'])}');
    stdout.writeln('  Date: ${_stringValue(updatedTransaction['date'])}');
    stdout.writeln('  Amount: ${_formatAmount(updatedTransaction['amount'])}');
    stdout.writeln(
      '  Payee: ${_stringValue(updatedTransaction['payee_name'])}',
    );
    stdout.writeln(
      '  Category: ${_stringValue(updatedTransaction['category_name'])}',
    );
    stdout.writeln('  Memo: ${_stringValue(updatedTransaction['memo'])}');
    return 0;
  }
}

Map<String, dynamic> _readUpdateFields(String filePath) {
  final yamlContent = File(filePath).readAsStringSync();
  final parsed = loadYaml(yamlContent);

  if (parsed is! YamlMap) {
    throw const _CliException('Update YAML must contain a top-level mapping.');
  }

  return _toPlainMap(parsed);
}

Map<String, dynamic> _toPlainMap(YamlMap yamlMap) {
  return yamlMap.map<String, dynamic>((dynamic key, dynamic value) {
    final normalizedKey = key.toString();
    if (value is YamlMap) {
      return MapEntry<String, dynamic>(normalizedKey, _toPlainMap(value));
    }
    if (value is YamlList) {
      return MapEntry<String, dynamic>(normalizedKey, _toPlainList(value));
    }

    return MapEntry<String, dynamic>(normalizedKey, value);
  });
}

List<dynamic> _toPlainList(YamlList yamlList) {
  return yamlList
      .map<dynamic>((dynamic value) {
        if (value is YamlMap) {
          return _toPlainMap(value);
        }
        if (value is YamlList) {
          return _toPlainList(value);
        }

        return value;
      })
      .toList(growable: false);
}

void _printTable({
  required List<String> headers,
  required List<List<String>> rows,
}) {
  final allRows = <List<String>>[headers, ...rows];
  final widths = List<int>.generate(
    headers.length,
    (index) => allRows
        .map((row) => row[index].length)
        .reduce((current, next) => current > next ? current : next),
  );

  String formatRow(List<String> row) {
    return List<String>.generate(
      row.length,
      (index) => row[index].padRight(widths[index]),
    ).join('  ');
  }

  stdout.writeln(formatRow(headers));
  stdout.writeln(
    List<String>.generate(
      widths.length,
      (index) => ''.padRight(widths[index], '-'),
    ).join('  '),
  );

  if (rows.isEmpty) {
    stdout.writeln('(no results)');
    return;
  }

  for (final row in rows) {
    stdout.writeln(formatRow(row));
  }
}

String _formatAmount(Object? milliunitsValue) {
  final milliunits = switch (milliunitsValue) {
    int value => value,
    num value => value.toInt(),
    String value => int.tryParse(value) ?? 0,
    _ => 0,
  };
  final amount = milliunits / 1000;
  final sign = amount < 0 ? '-' : '';
  return '$sign\$${amount.abs().toStringAsFixed(2)}';
}

String _stringValue(Object? value) {
  if (value == null) {
    return '';
  }

  return value.toString();
}

class _CliException implements Exception {
  const _CliException(this.message);

  final String message;

  @override
  String toString() => message;
}
