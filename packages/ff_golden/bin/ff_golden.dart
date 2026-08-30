import 'dart:io';

import 'package:ff_golden/src/test_cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runFfGolden(arguments);
}
