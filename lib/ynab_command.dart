import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:ynab_api_dart/commands/accounts_command.dart';
import 'package:ynab_api_dart/commands/categories_command.dart';
import 'package:ynab_api_dart/commands/transactions_command.dart';
import 'package:ynab_api_dart/commands/update_command.dart';
import 'package:ynab_api_dart/ynab_client.dart';

class YnabCommandRunner extends CommandRunner<int> {
  YnabCommandRunner()
    : super(
        'ynab-api-dart',
        'List YNAB accounts, inspect transactions, and update a transaction.',
      ) {
    addCommand(AccountsCommand());
    addCommand(CategoriesCommand());
    addCommand(TransactionsCommand());
    addCommand(UpdateCommand());
  }
}

abstract class YnabCommand extends Command<int> {
  YnabCommand() {
    argParser.addOption(
      'plan-id',
      abbr: 'p',
      defaultsTo: 'last-used',
      help: 'Plan or budget ID, or "last-used" (default).',
    );
  }

  String get planId => argResults!['plan-id'] as String;

  String readToken() {
    final token = Platform.environment['YNAB_API_TOKEN'];
    if (token == null || token.trim().isEmpty) {
      throw const CliException(
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

class CliException implements Exception {
  const CliException(this.message);

  final String message;

  @override
  String toString() => message;
}
