import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:patrol_recorder/model.dart';

class ScreenshotNameDialog extends StatefulWidget {
  const ScreenshotNameDialog({
    super.key,
    required this.bytes,
    required this.suggested,
    required this.source,
    required this.usedNames,
  });
  final Uint8List bytes;
  final String suggested;
  final String source;
  final Set<String> usedNames;
  @override
  State<ScreenshotNameDialog> createState() => _ScreenshotNameDialogState();
}

class _ScreenshotNameDialogState extends State<ScreenshotNameDialog> {
  late final _name = TextEditingController(text: widget.suggested);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Name this screenshot'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 180, child: Image.memory(widget.bytes)),
            Text(
              'Suggested from ${widget.source}. Use the same name for the same screen/state when re-recording.',
            ),
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Screenshot name (without .png)',
              ),
              validator: (value) {
                try {
                  requireIdentifier(value?.trim() ?? '', 'Screenshot name');
                } on FormatException catch (error) {
                  return error.message;
                }
                return widget.usedNames.contains(value!.trim())
                    ? 'Name already used in this recording. Choose a distinct state name or remove its previous reference first.'
                    : null;
              },
            ),
            const Text(
              'The PNG replaces an existing recorder-owned image with this journey/name. No session folder or timestamp is used.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel capture'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _name.text.trim());
          }
        },
        child: const Text('Save screenshot'),
      ),
    ],
  );
}
