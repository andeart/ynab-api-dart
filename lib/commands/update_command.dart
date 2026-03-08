import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:ynab_api_dart/formatters.dart';
import 'package:ynab_api_dart/ynab_command.dart';

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
  'subtransactions',
};

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
      throw const CliException(
        'The YAML file does not contain any update fields.',
      );
    }

    final invalidFields = fields.keys
        .where((field) => !_allowedUpdateFields.contains(field))
        .toList(growable: false);
    if (invalidFields.isNotEmpty) {
      throw CliException(
        'Unsupported update field(s): ${invalidFields.join(', ')}',
      );
    }

    final updatedTransaction = await withClient(
      (client) => client.updateTransaction(planId, transactionId, fields),
    );

    final output = StringBuffer();
    output.writeln('Updated transaction successfully:');
    output.writeln('  ID: ${stringValue(updatedTransaction['id'])}');
    output.writeln('  Date: ${stringValue(updatedTransaction['date'])}');
    output.writeln('  Amount: ${formatAmount(updatedTransaction['amount'])}');
    output.writeln('  Payee: ${stringValue(updatedTransaction['payee_name'])}');
    output.writeln(
      '  Category: ${stringValue(updatedTransaction['category_name'])}',
    );
    output.writeln('  Memo: ${stringValue(updatedTransaction['memo'])}');

    stdout.write(output);
    saveResults(name, output.toString());
    return 0;
  }
}

Map<String, dynamic> _readUpdateFields(String filePath) {
  final yamlContent = File(filePath).readAsStringSync();
  final parsed = loadYaml(yamlContent);

  if (parsed is! YamlMap) {
    throw const CliException('Update YAML must contain a top-level mapping.');
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
