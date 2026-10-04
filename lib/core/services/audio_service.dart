import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playSuccess() async {
    await _player.play(AssetSource('audio/success_chime.wav'));
  }

  Future<void> playWarning() async {
    await _player.play(AssetSource('audio/warning_buzz.wav'));
  }

  Future<void> playError() async {
    await _player.play(AssetSource('audio/error_buzz.wav'));
  }
}
