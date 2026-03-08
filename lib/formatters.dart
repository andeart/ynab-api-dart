import 'dart:io';

void printTable({
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
