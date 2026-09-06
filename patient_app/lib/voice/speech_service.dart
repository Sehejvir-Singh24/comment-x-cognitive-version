import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

const ttsFolder = 'vits-piper-en_US-lessac-medium';

/// All native inference lives in a dedicated isolate; audio never leaves device.
class SpeechService {
  SpeechService({this.onListeningExpired});
  final void Function()? onListeningExpired;
  final transcripts = StreamController<String>.broadcast();
  final _permissionProbe = AudioRecorder();
  final _player = AudioPlayer();
  final _receive = ReceivePort();
  Isolate? _worker;
  SendPort? _commands;
  Completer<void>? _ready;
  Completer<String>? _finalResult;
  final Map<int, Completer<String>> _audio = {};
  Timer? _limit;
  bool _disposed = false;
  int _playGeneration = 0;
  static const _speechChannel = MethodChannel('org.saathi/speech');
  Future<void> initialize() async {
    if (_ready != null) return _ready!.future;
    _ready = Completer<void>();
    try {
      final base = await getApplicationSupportDirectory();
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final asset in manifest.listAssets().where(
        (a) => a.startsWith('assets/models/'),
      )) {
        final file = File('${base.path}/$asset');
        if (!await file.exists()) {
          await file.parent.create(recursive: true);
          final data = await rootBundle.load(asset);
          final pending = File('${file.path}.pending');
          await pending.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            flush: true,
          );
          await pending.rename(file.path);
        }
      }
      if (_disposed) throw StateError('Voice closed');
      _speechChannel.setMethodCallHandler((call) async {
        if (_disposed) return;
        final text = call.arguments as String? ?? '';
        if (call.method == 'partial') {
          transcripts.add(text);
        } else if (call.method == 'final' &&
            _finalResult?.isCompleted == false) {
          _finalResult!.complete(text);
        } else if (call.method == 'error' &&
            _finalResult?.isCompleted == false) {
          _finalResult!.completeError(
            StateError('Offline speech recognition could not understand that.'),
          );
        }
      });
      _receive.listen((dynamic event) {
        if (event is SendPort) {
          _commands = event;
          _ready!.complete();
          return;
        }
        final e = event as List;
        if (e[0] == 'audio') _audio.remove(e[2])?.complete(e[1] as String);
        if (e[0] == 'error') {
          final error = StateError(
            'Voice is unavailable. Please use the buttons.',
          );
          if (!_ready!.isCompleted) _ready!.completeError(error);
          if (_finalResult?.isCompleted == false) {
            _finalResult!.completeError(error);
          }
          for (final pending in _audio.values) {
            if (!pending.isCompleted) pending.completeError(error);
          }
          _audio.clear();
        }
      });
      _worker = await Isolate.spawn(_speechWorker, [
        _receive.sendPort,
        '${base.path}/assets/models',
        (await getTemporaryDirectory()).path,
      ]);
      await _ready!.future.timeout(const Duration(seconds: 45));
    } catch (_) {
      if (!_ready!.isCompleted) {
        _ready!.completeError(StateError('Voice setup failed'));
      }
      rethrow;
    }
  }

  Future<void> startListening() async {
    if (_finalResult?.isCompleted == false || _disposed) return;
    if (!await _permissionProbe.hasPermission()) {
      throw StateError('Microphone permission was not granted.');
    }
    await stopSpeaking();
    await initialize();
    if (_disposed) return;
    final available =
        await _speechChannel.invokeMethod<bool>('availability') ?? false;
    if (!available) {
      throw StateError(
        'Install an offline English speech pack in the phone settings.',
      );
    }
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

  Future<void> cancelListening() async {
    _limit?.cancel();
    await _speechChannel.invokeMethod<void>('cancel');
    if (_finalResult?.isCompleted == false) _finalResult!.complete('');
    _finalResult = null;
  }

  Future<void> speak(String text) async {
    if (_disposed || text.isEmpty) return;
    await stopSpeaking();
    final generation = _playGeneration;
    await initialize();
    if (_disposed || generation != _playGeneration) return;
    final pending = Completer<String>();
    _audio[generation] = pending;
    _commands!.send(['speak', text, generation]);
    late final String path;
    try {
      path = await pending.future.timeout(const Duration(seconds: 30));
    } finally {
      _audio.remove(generation);
    }
    if (!_disposed && generation == _playGeneration) {
      await _player.play(DeviceFileSource(path));
    }
  }

  Future<void> stopSpeaking() async {
    _playGeneration++;
    await _player.stop();
  }

  Future<void> dispose() async {
    _disposed = true;
    await cancelListening();
    await stopSpeaking();
    await _permissionProbe.dispose();
    await _player.dispose();
    _commands?.send(['dispose']);
    final worker = _worker;
    Timer(const Duration(seconds: 35), () => worker?.kill());
    _receive.close();
    await transcripts.close();
    // The worker frees native resources and exits after completing its queue.
  }
}

void _speechWorker(List<dynamic> args) {
  final output = args[0] as SendPort;
  final root = args[1] as String;
  final temp = args[2] as String;
  final input = ReceivePort();
  sherpa.OfflineTts? tts;
  try {
    sherpa.initBindings();
    output.send(input.sendPort);
    input.listen((dynamic message) {
      final command = message as List;
      try {
        switch (command[0]) {
          case 'speak':
            tts ??= sherpa.OfflineTts(
              sherpa.OfflineTtsConfig(
                model: sherpa.OfflineTtsModelConfig(
                  vits: sherpa.OfflineTtsVitsModelConfig(
                    model: '$root/$ttsFolder/en_US-lessac-medium.onnx',
                    tokens: '$root/$ttsFolder/tokens.txt',
                    dataDir: '$root/$ttsFolder/espeak-ng-data',
                  ),
                  numThreads: 2,
                ),
              ),
            );
            final audio = tts!.generate(text: command[1] as String, speed: 0.9);
            final path = '$temp/saathi-reply.wav';
            if (!sherpa.writeWave(
              filename: path,
              samples: audio.samples,
              sampleRate: audio.sampleRate,
            )) {
              throw StateError('audio');
            }
            output.send(['audio', path, command[2]]);
          case 'dispose':
            tts?.free();
            final file = File('$temp/saathi-reply.wav');
            if (file.existsSync()) file.deleteSync();
            input.close();
        }
      } catch (_) {
        output.send(['error']);
      }
    });
  } catch (_) {
    output.send(['error']);
    input.close();
  }
}
