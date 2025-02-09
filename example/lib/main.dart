import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_video_cast/flutter_video_cast.dart';
import 'package:flutter_video_cast_example/timer.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: CastSample());
  }
}

class CastSample extends StatefulWidget {
  static const _iconSize = 50.0;

  @override
  _CastSampleState createState() => _CastSampleState();
}

class _CastSampleState extends State<CastSample> {
  late ChromeCastController _controller;

  AppState _state = AppState.idle;
  bool? _playing = false;

  Duration position = Duration();
  Duration duration = Duration();

  double volume = 0;

  Timer _timer = Timer();
  StreamSubscription<int>? _tickerSubscription;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Plugin example app'),
        actions: <Widget>[
          AirPlayButton(
            size: CastSample._iconSize,
            color: Colors.white,
            activeColor: Colors.amber,
            onRoutesOpening: () => print('opening'),
            onRoutesClosed: () => print('closed'),
          ),
          ChromeCastButton(
            size: CastSample._iconSize,
            color: Colors.white,
            onButtonCreated: _onButtonCreated,
            onSessionStarted: _onSessionStarted,
            onSessionEnded: _onSessionEnded,
            onRequestCompleted: _onRequestCompleted,
            onRequestFailed: _onRequestFailed,
          ),
        ],
      ),
      body: Center(child: _handleState()),
    );
  }

  Widget _handleState() {
    switch (_state) {
      case AppState.idle:
        return Text('ChromeCast not connected');
      case AppState.connected:
        return Text('No media loaded');
      case AppState.mediaLoaded:
        return _mediaControls();
      case AppState.error:
        return Text('An error has occurred');
      default:
        return Container();
    }
  }

  Widget _mediaControls() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _RoundIconButton(
              icon: Icons.replay_10,
              onPressed: () =>
                  _controller.seek(relative: true, interval: -10.0),
            ),
            _RoundIconButton(
                icon: _playing! ? Icons.pause : Icons.play_arrow,
                onPressed: _playPause),
            _RoundIconButton(
              icon: Icons.forward_10,
              onPressed: () => _controller.seek(relative: true, interval: 10.0),
            ),
          ],
        ),
        Slider(
          value: _sliderValue(),
          onChanged: (double value) {
            _changeSliderValue(value);
          },
        ),
        Text(_time()),

        //End subtitles
        _RoundIconButton(
          icon: Icons.stop,
          onPressed: () => _controller.turnOffSubtitles(),
        ),
      ],
    );
  }

  String _time() {
    if (duration.inHours > 0) {
      return "${formatHour(position)} / ${formatHour(duration)}";
    } else {
      return "${format(position)} / ${format(duration)}";
    }
  }

  format(Duration d) => d.toString().substring(2, 7);
  formatHour(Duration d) => d.toString().split('.').first.padLeft(8, "0");

  double _sliderValue() {
    return position.inSeconds /
        (duration.inSeconds == 0 ? 5 : duration.inSeconds);
  }

  _changeSliderValue(double value) {
    position = Duration(
      seconds:
          ((duration.inSeconds == 0 ? 5 : duration.inSeconds) * value).toInt(),
    );
    _changePosition(position);
    setState(() {});
  }

  _changePosition(Duration position) async {
    if ((await _controller.isConnected()) ?? false) {
      await _controller.seek(interval: position.inSeconds.toDouble());
      position = await _controller.position();
      setState(() {});
    }
  }

  Future<void> _playPause() async {
    final bool playing = (await _controller.isPlaying()) ?? false;
    if (playing) {
      await _controller.pause();
      _tickerSubscription?.cancel();
    } else {
      await _controller.play();
      _tickerSubscription?.cancel();
      _tickerSubscription = _timer.tick(ticks: 0).listen((time) async {
        position = await _controller.position();
        setState(() {});
      });
    }
    setState(() => _playing = !playing);
  }

  Future<void> _onButtonCreated(ChromeCastController controller) async {
    _controller = controller;
    await _controller.addSessionListener();
  }

  Future<void> _onSessionStarted() async {
    setState(() => _state = AppState.connected);

    // Subtitles test
    final videoSubtitle = VideoSubtitle(
      id: 1,
      name: "Português",
      url:
          "https://s3.sa-east-1.amazonaws.com/content.finclass.com/vod/subtitles/Finclass/20_Howard/FINCLASS_20_AULA_02.vtt",
      language: "pt-BR",
    );

    List<VideoSubtitle> videoSubtitles = [];
    videoSubtitles.add(videoSubtitle);

    await _controller.loadMedia(
      "https://d1mmb4c1iqc2nn.cloudfront.net/mp4/FINCLASS_20_AULA_02_Mp4_Avc_Aac_16x9_1280x720p_24Hz_8.5Mbps_qvbr.mp4",
      title: "Pensamento de Segundo Nível",
      subTitle: "Howard Marks",
      image:
          "https://content.finclass.com/finclasses/Howard/Thumbs+aulas/Aula-2.jpg",
      subtitles: videoSubtitles,
    );
  }

  Future<void> _onSessionEnded() async {
    _tickerSubscription?.cancel();
    position = Duration();
    duration = Duration();
    setState(() => _state = AppState.idle);
  }

  Future<void> _onRequestCompleted() async {
    final playing = await _controller.isPlaying();

    if (_state != AppState.mediaLoaded) {
      // Starts with subtitle case it has
      await _controller.changeSubtitle(1);
      //await _controller.seek(interval: 60.toDouble());
    }

    setState(() {
      _state = AppState.mediaLoaded;
      _playing = playing;
    });
    duration = await _controller.duration();
    setState(() {});
  }

  Future<void> _onRequestFailed(String? error) async {
    _tickerSubscription?.cancel();
    setState(() => _state = AppState.error);
    print(error);
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  _RoundIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        child: Icon(icon, color: Colors.white),
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all<Color>(Colors.blue),
          shape: MaterialStateProperty.all<OutlinedBorder>(CircleBorder()),
          padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
            EdgeInsets.all(16.0),
          ),
        ),
        onPressed: onPressed);
  }
}

enum AppState { idle, connected, mediaLoaded, error }
