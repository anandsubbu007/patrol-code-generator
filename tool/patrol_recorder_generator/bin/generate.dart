import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';
import 'package:patrol_recorder_generator/src/interactive_generation.dart';
import 'package:patrol_recorder_generator/src/local_generation.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'project',
      defaultsTo: '.',
      help: 'Application directory containing pubspec.yaml.',
    )
    ..addOption(
      'journey',
      help: 'Generate one named journey. Omit to choose interactively in a terminal.',
    )
    ..addFlag(
      'all',
      negatable: false,
      help: 'Generate every .yml journey without opening the menu.',
    )
    ..addFlag(
      'interactive',
      // `dart run` can forward stdout through a pipe even in a terminal.
      defaultsTo: stdin.hasTerminal && Platform.environment['CI'] != 'true',
      help:
          'Show a menu when --journey and --all are omitted. '
          'Defaults to off for redirected input and CI=true.',
    )
    ..addOption(
      'recordings-directory',
      help: 'Override the project-relative YAML directory.',
    )
    ..addOption('case', help: 'Generate one case of the selected --journey.')
    ..addFlag(
      'preview',
      negatable: false,
      help: 'Validate and print generated steps without writing files.',
    )
    ..addFlag(
      'inspect-selectors',
      negatable: false,
      help: 'Validate and print effective selectors as JSON without writing files.',
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
    final journey = args['journey'] as String?;
    if (args['all'] as bool && journey != null) {
      throw const FormatException('--all cannot be combined with --journey.');
    }
    if (args['case'] != null && journey == null) {
      throw const FormatException('--case requires --journey.');
    }
    final project = Directory(args['project'] as String);
    final recordingsDirectory = args['recordings-directory'] as String?;
    final interactive =
        args['interactive'] as bool &&
        journey == null &&
        !(args['all'] as bool);
    final menu = interactive
        ? GenerationMenu(
            recordings: await LocalRecordings.open(
              project,
              recordingsDirectory: recordingsDirectory,
            ),
            readLine: stdin.readLineSync,
            writeLine: stdout.writeln,
          )
        : null;
    var choice = GenerationChoice(
      journey: journey,
      preview: args['preview'] as bool,
      inspectSelectors: args['inspect-selectors'] as bool,
    );
    late GenerationSummary result;
    while (true) {
      try {
        if (menu != null) {
          final selection = await menu.choose(
            preview: args['preview'] as bool,
            inspectSelectors: args['inspect-selectors'] as bool,
          );
          if (selection == null) return;
          choice = selection;
        }
        result = await generateProject(
          project,
          journey: choice.journey,
          recordingsDirectory: recordingsDirectory,
          selectedCase: args['case'] as String?,
          preview: choice.preview || choice.inspectSelectors,
        );
        break;
      } on FormatException catch (error) {
        if (menu == null) rethrow;
        stderr.writeln('Generation failed: ${error.message}');
      } on StateError catch (error) {
        if (menu == null) rethrow;
        stderr.writeln('Generation failed: ${error.message}');
      } on FileSystemException catch (error) {
        if (menu == null) rethrow;
        stderr.writeln(
          'Generation failed: ${error.message} (${error.path ?? 'filesystem'})',
        );
      }
      exitCode = 1;
      stderr.writeln('Choose another journey, reset recordings, or cancel.');
    }
    exitCode = 0;
    if (choice.inspectSelectors) {
      stdout.writeln(
        const JsonEncoder.withIndent('  ').convert(result.selectors),
      );
      return;
    }
    if (choice.preview) {
      for (final output in result.journeys) {
        stdout.writeln('Preview: ${output.config.stepsPath}\n${output.steps}');
      }
      return;
    }
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
