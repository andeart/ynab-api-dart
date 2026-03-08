import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:yaml/yaml.dart';
import 'package:ynab_api_dart/ynab_command.dart';
import 'package:ynab_api_dart/ynab_client.dart';

Future<void> main(List<String> arguments) async {
  final runner = YnabCommandRunner();

  try {
    final code = await runner.run(arguments) ?? 0;
    exitCode = code;
  } on UsageException catch (error) {
    stderr.writeln(error);
    exitCode = 64;
  } on YnabApiException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln('File error: ${error.message}');
    exitCode = 1;
  } on YamlException catch (error) {
    stderr.writeln('YAML parse failure: $error');
    exitCode = 1;
  } on CliException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } catch (error) {
    stderr.writeln('Unexpected error: $error');
    exitCode = 1;
  }
}
