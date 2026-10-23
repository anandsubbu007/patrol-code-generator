import 'local_generation.dart';

class GenerationChoice {
  const GenerationChoice({
    this.journey,
    this.preview = false,
    this.inspectSelectors = false,
  });

  final String? journey;
  final bool preview;
  final bool inspectSelectors;
}

class GenerationMenu {
  GenerationMenu({
    required this.recordings,
    required this.readLine,
    required this.writeLine,
  });

  final LocalRecordings recordings;
  final String? Function() readLine;
  final void Function(String) writeLine;

  Future<int?> _choose(String prompt, List<String> options) async {
    writeLine(prompt);
    for (var index = 0; index < options.length; index++) {
      writeLine('  ${index + 1}) ${options[index]}');
    }
    writeLine('  0) Cancel');
    while (true) {
      writeLine('Enter a number:');
      final line = readLine();
      if (line == null || line.trim() == '0') return null;
      final number = int.tryParse(line.trim());
      if (number != null && number > 0 && number <= options.length) {
        return number;
      }
      writeLine('Invalid choice. Enter 0-${options.length}.');
    }
  }

  void _recordingHelp() {
    writeLine(
      'Start the app with Patrol Recorder enabled, open its DevTools '
      'extension, record a named journey, then stop and save it. '
      'Run this command again to generate. This CLI does not record or run tests.',
    );
  }

  Future<GenerationChoice?> choose({
    bool preview = false,
    bool inspectSelectors = false,
  }) async {
    while (true) {
      final paths = await recordings.journeys();
      final names = [
        for (final path in paths)
          path.pathSegments.last.substring(
            0,
            path.pathSegments.last.length - 4,
          ),
      ];
      writeLine(
        names.isEmpty
            ? 'No .yml journeys found in ${recordings.directory}/.'
            : 'Recorded journeys in ${recordings.directory}/: ${names.join(', ')}',
      );
      final action = await _choose('What would you like to do?', [
        'Generate one journey',
        'Generate all journeys (all must pass validation)',
        'Preview generated steps (no files written)',
        'Inspect selectors as JSON (no files written)',
        'Delete recordings and start over',
        'Show how to record / re-record a journey',
      ]);
      if (action == null) {
        writeLine('Cancelled. No further changes made.');
        return null;
      }
      if (action == 6) {
        _recordingHelp();
        continue;
      }
      if (action == 5) {
        await _reset();
        continue;
      }
      if (names.isEmpty) {
        _recordingHelp();
        continue;
      }
      String? journey;
      if (action != 2) {
        final selected = await _choose('Which journey?', [
          ...names,
          if (action == 3 || action == 4) 'All journeys',
        ]);
        if (selected == null) continue;
        if (selected <= names.length) journey = names[selected - 1];
      }
      return GenerationChoice(
        journey: journey,
        preview: preview || action == 3 || action == 4,
        inspectSelectors: inspectSelectors || action == 4,
      );
    }
  }

  Future<void> _reset() async {
    final scope = await _choose('Choose what to delete for ALL recordings:', [
      'Journey YAML only; preserve screenshots and generated code',
      'Journey YAML and referenced screenshots; preserve generated code',
      'Journey YAML, referenced screenshots, and generated journey files '
          '(INCLUDING user-owned inputs and tests)',
    ]);
    if (scope == null) return;
    final plan = await recordings.resetPlan(
      screenshots: scope >= 2,
      generatedCode: scope == 3,
    );
    if (plan.isEmpty) {
      writeLine('No matching files to delete.');
      return;
    }
    writeLine(
      'The following ${plan.length} files will be permanently deleted:',
    );
    for (final uri in plan.keys) {
      writeLine('  ${uri.toFilePath()}');
    }
    writeLine(
      'Fixture assets, unreferenced captures, and unrelated files are preserved. '
      'Stop recording before continuing. Type DELETE to confirm:',
    );
    if (readLine()?.trim() != 'DELETE') {
      writeLine('Reset cancelled. No files deleted.');
      return;
    }
    await recordings.deletePlanned(plan);
    writeLine('Deleted ${plan.length} files.');
    _recordingHelp();
  }
}
