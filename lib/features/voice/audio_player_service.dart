import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  return AudioPlayerService();
});

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  final _completionController = StreamController<void>.broadcast();
  late final StreamSubscription<void> _playerSub;

  Stream<void> get onComplete => _completionController.stream;

  AudioPlayerService() {
    _playerSub = _player.onPlayerComplete.listen((_) {
      _completionController.add(null);
    });
  }

  Future<void> playBytes(Uint8List bytes) async {
    await _player.play(BytesSource(bytes));
  }

  Future<void> playUrl(String url) async {
    await _player.play(UrlSource(url));
  }

  Future<void> stop() async {
    await _player.stop();
  }

  void dispose() {
    _playerSub.cancel();
    _player.dispose();
    _completionController.close();
  }
}
