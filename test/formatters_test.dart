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
}
