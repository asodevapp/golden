import 'dart:io';

import 'package:ff_golden_presenter/src/cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runGoldenPresenter(arguments);
}
