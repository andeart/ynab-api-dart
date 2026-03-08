import 'package:ynab_api_dart/formatters.dart';
import 'package:ynab_api_dart/ynab_command.dart';

class AccountsCommand extends YnabCommand {
  @override
  final String name = 'accounts';

  @override
  final String description = 'List all accounts for a YNAB plan.';

  @override
  Future<int> run() async {
    final accounts = await withClient((client) => client.getAccounts(planId));
    const headers = <String>['Name', 'ID', 'Type', 'Balance'];
    final rows = accounts
        .map(
          (account) => <String>[
            stringValue(account['name']),
            stringValue(account['id']),
            stringValue(account['type']),
            formatAmount(account['balance']),
          ],
        )
        .toList(growable: false);

    printTable(headers: headers, rows: rows);
    saveResults(name, formatTable(headers: headers, rows: rows));
    return 0;
  }
}
