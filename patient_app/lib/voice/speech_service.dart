import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Voice input and output are provided by Android system services.
///
/// Saathi no longer ships or runs a bundled speech model. Android handles
/// speech recognition and text-to-speech; Gemini handles conversational text.
class SpeechService {
  SpeechService({this.onListeningExpired});

  final void Function()? onListeningExpired;
  final transcripts = StreamController<String>.broadcast();
  static const _speechChannel = MethodChannel('org.saathi/speech');
  Completer<String>? _finalResult;
  Timer? _limit;
  bool _disposed = false;
  bool _initialized = false;
  String _lastPartial = '';

  // Android SpeechRecognizer error codes
  // https://developer.android.com/reference/android/speech/SpeechRecognizer
  static const _errorNoMatch = 7;
  static const _errorSpeechTimeout = 6;
  static const _errorRecognizerBusy = 8;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final support = await getApplicationSupportDirectory();
      final legacyModels = Directory('${support.path}/assets/models');
      if (await legacyModels.exists()) {
        await legacyModels.delete(recursive: true);
      }
    } catch (_) {}
    _speechChannel.setMethodCallHandler((call) async {
      if (_disposed) return;
      final text = call.arguments is String ? call.arguments as String : '';
      if (call.method == 'partial') {
        _lastPartial = text;
        transcripts.add(text);
      } else if (call.method == 'final' &&
          _finalResult?.isCompleted == false) {
        _limit?.cancel();
        final resultText =
            text.trim().isNotEmpty ? text.trim() : _lastPartial.trim();
        _finalResult!.complete(resultText);
      } else if (call.method == 'error' &&
          _finalResult?.isCompleted == false) {
        // Distinguish transient errors (no speech / timeout / busy) from
        // permanent failures.  For transient errors we prefer whatever
        // partial text was captured so far; for permanent errors we also
        // fall back to the partial to avoid silently dropping the turn.
        final errorCode = int.tryParse(text) ?? -1;
        _limit?.cancel();
        final captured = _lastPartial.trim();
        if (captured.isNotEmpty) {
          // Use whatever the recognizer already heard.
          _finalResult!.complete(captured);
        } else if (errorCode == _errorNoMatch ||
            errorCode == _errorSpeechTimeout ||
            errorCode == _errorRecognizerBusy) {
          // Transient, no speech detected — complete with empty so the
          // caller can decide to retry or pause gracefully.
          _finalResult!.complete('');
        } else {
          // Permanent error — surface it.
          _finalResult!.completeError(
            StateError('Speech recognition error: $errorCode'),
          );
        }
      }
    });
    _initialized = true;
  }

  Future<void> startListening() async {
    if (_disposed) return;
    if (_finalResult?.isCompleted == false) {
      _finalResult!.complete('');
    }
    await initialize();
    final available =
        await _speechChannel.invokeMethod<bool>('availability') ?? false;
    if (!available) {
      throw StateError(
        'Google speech recognition is unavailable on this phone.',
      );
    }
    await stopSpeaking();
    _lastPartial = '';
    _finalResult = Completer<String>();
    await _speechChannel.invokeMethod<void>('start');
    _limit = Timer(const Duration(seconds: 30), () {
      cancelListening().whenComplete(() {
        if (!_disposed) onListeningExpired?.call();
      });
    });
  }

  Future<String> stopListening() async {
    _limit?.cancel();
    final pending = _finalResult;
    if (pending == null) return '';
    await _speechChannel.invokeMethod<void>('stop');
    return pending.future.timeout(const Duration(seconds: 10));
  }

  Future<String> finalTranscript() async => await _finalResult?.future ?? '';

  Future<void> cancelListening() async {
    _limit?.cancel();
    await _speechChannel.invokeMethod<void>('cancel');
    if (_finalResult?.isCompleted == false) _finalResult!.complete('');
    _finalResult = null;
    _lastPartial = '';
  }

  Future<void> speak(String text) async {
    if (_disposed || text.trim().isEmpty) return;
    await initialize();
    await _speechChannel.invokeMethod<void>('speak', {'text': text});
  }

  Future<void> stopSpeaking() async {
    await _speechChannel.invokeMethod<void>('stopSpeaking');
  }

  Future<void> dispose() async {
    _disposed = true;
    await cancelListening();
    await stopSpeaking();
    _speechChannel.setMethodCallHandler(null);
    await transcripts.close();
  }
}
