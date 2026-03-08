import 'dart:io';

void printTable({
  required List<String> headers,
  required List<List<String>> rows,
}) {
  stdout.write(formatTable(headers: headers, rows: rows));
}

String formatAmount(Object? milliunitsValue) {
  final milliunits = switch (milliunitsValue) {
    final int value => value,
    final num value => value.toInt(),
    final String value => int.tryParse(value) ?? 0,
    _ => 0,
  };
  final amount = milliunits / 1000;
  final sign = amount < 0 ? '-' : '';
  return '$sign\$${amount.abs().toStringAsFixed(2)}';
}

String stringValue(Object? value) {
  if (value == null) {
    return '';
  }

  return value.toString();
}

String formatTable({
  required List<String> headers,
  required List<List<String>> rows,
}) {
  if (rows.isEmpty) {
    return '(no results)\n';
  }

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

  final buffer = StringBuffer();
  buffer.writeln(formatRow(headers));
  buffer.writeln(
    List<String>.generate(
      widths.length,
      (index) => ''.padRight(widths[index], '-'),
    ).join('  '),
  );
  for (final row in rows) {
    buffer.writeln(formatRow(row));
  }
  return buffer.toString();
}

void saveResults(String commandName, String content) {
  final directory = Directory('temp');
  if (!directory.existsSync()) {
    directory.createSync();
  }
  File('temp/$commandName.txt').writeAsStringSync(content);
}
