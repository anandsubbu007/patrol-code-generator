import 'dart:io';

import 'package:args/args.dart';
import 'package:patrol_recorder_generator/local_generation.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'project',
      defaultsTo: '.',
      help: 'Application directory containing pubspec.yaml.',
    )
    ..addOption(
      'journey',
      help: 'Generate one named journey. Omit to generate every .yml in the configured directory.',
    )
    ..addOption(
      'recordings-directory',
      help: 'Override the project-relative YAML directory.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  try {
    final args = parser.parse(arguments);
    if (args['help'] as bool) {
      stdout.writeln(
        'dart run patrol_recorder_generator:generate [options]\n${parser.usage}',
      );
      return;
    }
    if (args.rest.isNotEmpty) {
      throw const FormatException(
        'Unexpected positional arguments. Use --journey name.',
      );
    }
    final result = await generateProject(
      Directory(args['project'] as String),
      journey: args['journey'] as String?,
      recordingsDirectory: args['recordings-directory'] as String?,
    );
    for (final path in result.result.written) {
      stdout.writeln('Generated: ${result.root.resolve(path).toFilePath()}');
    }
    for (final path in result.result.preserved) {
      stdout.writeln('Preserved: ${result.root.resolve(path).toFilePath()}');
    }
    stdout.writeln(
      '\nNext: implement the abstract getters in each *_inputs.dart provider, then run flutter analyze.',
    );
    stdout.writeln(
      'New inputs intentionally throw until connected. Existing implementations and test wrappers are never overwritten.',
    );
    for (final output in result.journeys) {
      stdout.writeln(
        '\nAfter wiring ${output.config.inputsPath}:\n${output.config.command(singleCase: false)}',
      );
    }
  } on FormatException catch (error) {
    stderr.writeln('Generation failed: ${error.message}');
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln(
      'Generation failed: ${error.message} (${error.path ?? 'filesystem'})',
    );
    exitCode = 1;
  } on StateError catch (error) {
    stderr.writeln('Generation failed: ${error.message}');
    exitCode = 1;
  }
}
