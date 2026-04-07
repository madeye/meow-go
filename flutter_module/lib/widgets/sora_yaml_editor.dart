import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A native Android Sora Editor exposed as a Flutter PlatformView.
///
/// Replaces Flutter's `TextField` for YAML editing — `CodeEditor` is
/// virtualized and handles multi-MB documents without blocking the UI thread.
///
/// Use [onCreated] to receive a [SoraEditorController] for `getText`/`setText`,
/// and [onChanged] to listen for live edits (already debounced on the native
/// side per content-change event).
class SoraYamlEditor extends StatelessWidget {
  const SoraYamlEditor({
    super.key,
    required this.initialText,
    this.readOnly = false,
    this.textSizeSp = 14.0,
    this.onChanged,
    this.onCreated,
  });

  final String initialText;
  final bool readOnly;
  final double textSizeSp;
  final ValueChanged<String>? onChanged;
  final ValueChanged<SoraEditorController>? onCreated;

  static const String _viewType = 'io.github.madeye.meow/sora_editor';

  @override
  Widget build(BuildContext context) {
    final params = <String, dynamic>{
      'initialText': initialText,
      'readOnly': readOnly,
      'textSizeSp': textSizeSp,
    };
    return AndroidView(
      viewType: _viewType,
      creationParams: params,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (int id) {
        onCreated?.call(SoraEditorController._(id, onChanged));
      },
    );
  }
}

/// Handle to a created Sora Editor instance. Use [getText] before saving and
/// [setText] when reverting.
class SoraEditorController {
  SoraEditorController._(int viewId, ValueChanged<String>? onChanged)
      : _channel = MethodChannel('io.github.madeye.meow/sora_editor_$viewId') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onTextChanged') {
        final text = (call.arguments as Map)['text'] as String? ?? '';
        onChanged?.call(text);
      }
    });
  }

  final MethodChannel _channel;

  Future<String> getText() async =>
      (await _channel.invokeMethod<String>('getText')) ?? '';

  Future<void> setText(String text) =>
      _channel.invokeMethod('setText', {'text': text});

  Future<void> undo() => _channel.invokeMethod('undo');
  Future<void> redo() => _channel.invokeMethod('redo');
}
