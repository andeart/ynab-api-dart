import 'dart:io';

import 'package:test/test.dart';
import 'package:ynab_api_dart/formatters.dart';

void main() {
  group('formatAmount', () {
    test('formats positive milliunits from an int', () {
      expect(formatAmount(12345), r'$12.35');
    });

    test('formats negative milliunits from a num', () {
      expect(formatAmount(-1250.0), r'-$1.25');
    });

    test('formats milliunits from a string', () {
      expect(formatAmount('5000'), r'$5.00');
    });

    test('falls back to zero for invalid values', () {
      expect(formatAmount('not-a-number'), r'$0.00');
      expect(formatAmount(null), r'$0.00');
    });
  });

  group('stringValue', () {
    test('returns an empty string for null', () {
      expect(stringValue(null), isEmpty);
    });

    test('returns toString for non-null values', () {
      expect(stringValue(42), '42');
    });
  });

  group('formatTable', () {
    test('formats headers and rows as a table string', () {
      final result = formatTable(
        headers: const ['Name', 'Balance'],
        rows: const [
          ['Checking', r'$1.50'],
          ['Savings', r'$25.00'],
        ],
      );

      expect(
        result,
        'Name      Balance\n'
        '--------  -------\n'
        'Checking  \$1.50  \n'
        'Savings   \$25.00 \n',
      );
    });

    test('returns no results for empty rows', () {
      final result = formatTable(headers: const ['Name'], rows: const []);

      expect(result, '(no results)\n');
    });
  });

  group('saveResults', () {
    test('creates temp directory and writes file', () {
      final tempDir = Directory.systemTemp.createTempSync('ynab_test_');
      final originalDir = Directory.current;
      Directory.current = tempDir;

      try {
        saveResults('accounts', 'Name\n----\nTest\n');

        final file = File('${tempDir.path}/temp/accounts.txt');
        expect(file.existsSync(), isTrue);
        expect(file.readAsStringSync(), 'Name\n----\nTest\n');
      } finally {
        Directory.current = originalDir;
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
