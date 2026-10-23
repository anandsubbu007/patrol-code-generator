import 'package:flutter/material.dart';
import 'package:patrol_recorder/model.dart';

class ExpectationDialog extends StatefulWidget {
  const ExpectationDialog({
    super.key,
    required this.target,
    this.suggestedText,
  });
  final RecorderTarget target;
  final String? suggestedText;

  @override
  State<ExpectationDialog> createState() => _ExpectationDialogState();
}

class _ExpectationDialogState extends State<ExpectationDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _textValue;
  final _countValue = TextEditingController(text: '1');
  TextEditingController get _value =>
      _kind == RecordedExpectation.count ? _countValue : _textValue;
  final _timeout = TextEditingController(text: '10000');
  RecordedExpectation _kind = RecordedExpectation.visible;

  @override
  void initState() {
    super.initState();
    final selector = widget.target.selector;
    _textValue = TextEditingController(
      text:
          widget.suggestedText ??
          (selector?.kind == SelectorKind.text ||
                  selector?.kind == SelectorKind.richText
              ? selector!.value
              : ''),
    );
  }

  @override
  void dispose() {
    _textValue.dispose();
    _countValue.dispose();
    _timeout.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(
      ExpectationSpec(
        kind: _kind,
        value: switch (_kind) {
          RecordedExpectation.text => _value.text,
          RecordedExpectation.count => int.parse(_value.text),
          _ => null,
        },
        timeoutMs: int.parse(_timeout.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add expectation'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText('${widget.target.toJson()}'),
              const SizedBox(height: 16),
              DropdownButtonFormField<RecordedExpectation>(
                isExpanded: true,
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Expectation'),
                items: [
                  for (final kind in RecordedExpectation.values)
                    DropdownMenuItem(
                      value: kind,
                      child: Text(switch (kind) {
                        RecordedExpectation.exists => 'Exists (one match)',
                        RecordedExpectation.absent => 'Absent',
                        RecordedExpectation.visible => 'Visible',
                        RecordedExpectation.text => 'Exact text',
                        RecordedExpectation.count => 'Match count',
                      }),
                    ),
                ],
                onChanged: (kind) => setState(() => _kind = kind!),
              ),
              if (_kind == RecordedExpectation.text ||
                  _kind == RecordedExpectation.count)
                TextFormField(
                  controller: _value,
                  decoration: InputDecoration(
                    labelText: _kind == RecordedExpectation.text
                        ? 'Expected text'
                        : 'Expected count',
                  ),
                  keyboardType: _kind == RecordedExpectation.count
                      ? TextInputType.number
                      : TextInputType.text,
                  validator: (value) {
                    if (_kind == RecordedExpectation.count) {
                      final count = int.tryParse(value ?? '');
                      return count == null || count < 0
                          ? 'Enter a nonnegative integer.'
                          : null;
                    }
                    return value == null || value.isEmpty || value.length > 1000
                        ? 'Enter 1-1000 characters.'
                        : null;
                  },
                ),
              TextFormField(
                controller: _timeout,
                decoration: const InputDecoration(labelText: 'Timeout (ms)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final timeout = int.tryParse(value ?? '');
                  return timeout == null || timeout < 100 || timeout > 120000
                      ? 'Enter 100-120000 milliseconds.'
                      : null;
                },
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: const Text('Save expectation'),
      ),
    ],
  );
}
