import 'package:ynab_api_dart/formatters.dart';
import 'package:ynab_api_dart/ynab_command.dart';

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

    const headers = <String>[
      'ID',
      'Date',
      'Amount',
      'Payee',
      'Category',
      'Memo',
      'Cleared',
    ];
    final rows = transactions
        .map(
          (transaction) => <String>[
            stringValue(transaction['id']),
            stringValue(transaction['date']),
            formatAmount(transaction['amount']),
            stringValue(transaction['payee_name']),
            stringValue(transaction['category_name']),
            stringValue(transaction['memo']),
            stringValue(transaction['cleared']),
          ],
        )
        .toList(growable: false);

    printTable(headers: headers, rows: rows);
    saveResults(name, formatTable(headers: headers, rows: rows));
    return 0;
  }
}
