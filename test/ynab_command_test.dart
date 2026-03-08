import 'package:test/test.dart';
import 'package:ynab_api_dart/ynab_command.dart';

void main() {
  group('YnabCommandRunner', () {
    test('registers the supported commands', () {
      final runner = YnabCommandRunner();

      expect(
        runner.commands.keys,
        containsAll(<String>['accounts', 'transactions', 'update']),
      );
    });
  });

  group('CliException', () {
    test('returns its message from toString', () {
      const exception = CliException('Something went wrong.');

      expect(exception.toString(), 'Something went wrong.');
    });
  });
}
