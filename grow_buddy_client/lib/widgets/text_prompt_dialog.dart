import 'package:flutter/material.dart';

/// One-field text dialog. Returns the trimmed text, or null on cancel.
/// The dialog owns its controller so it is disposed only after the exit
/// animation finishes (disposing right after showDialog returns crashes).
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialText = '',
  String? labelText,
  String? hintText,
  int maxLines = 1,
  bool autofocus = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialText: initialText,
      labelText: labelText,
      hintText: hintText,
      maxLines: maxLines,
      autofocus: autofocus,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String initialText;
  final String? labelText;
  final String? hintText;
  final int maxLines;
  final bool autofocus;

  const _TextPromptDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialText,
    required this.labelText,
    required this.hintText,
    required this.maxLines,
    required this.autofocus,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        maxLines: widget.maxLines,
        decoration: InputDecoration(labelText: widget.labelText, hintText: widget.hintText),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
