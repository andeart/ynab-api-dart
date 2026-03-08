import 'package:ynab_api_dart/formatters.dart';
import 'package:ynab_api_dart/ynab_command.dart';

class CategoriesCommand extends YnabCommand {
  @override
  final String name = 'categories';

  @override
  final String description = 'List all budget categories for a YNAB plan.';

  @override
  Future<int> run() async {
    final categories = await withClient(
      (client) => client.getCategories(planId),
    );
    const headers = <String>[
      'Group',
      'Name',
      'ID',
      'Budgeted',
      'Activity',
      'Balance',
    ];
    final rows = categories
        .map(
          (category) => <String>[
            stringValue(category['category_group_name']),
            stringValue(category['name']),
            stringValue(category['id']),
            formatAmount(category['budgeted']),
            formatAmount(category['activity']),
            formatAmount(category['balance']),
          ],
        )
        .toList(growable: false);

    printTable(headers: headers, rows: rows);
    saveResults(name, formatTable(headers: headers, rows: rows));
    return 0;
  }
}
