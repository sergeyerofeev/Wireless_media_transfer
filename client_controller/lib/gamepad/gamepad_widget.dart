import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'gamepad.dart';

class GamepadWidget extends StatefulWidget {
  final RTCDataChannel _dataChannel;

  const GamepadWidget({super.key, required RTCDataChannel dataChannel}) : _dataChannel = dataChannel;

  @override
  GamepadWidgetState createState() => GamepadWidgetState();
}

class GamepadWidgetState extends State<GamepadWidget> with TickerProviderStateMixin {
  late final Gamepad gamepad;
  double _zoomValue = 1.0;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

  @override
  void initState() {
    gamepad = Gamepad(0);
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        gamepad.updateState();

        int leftY = gamepad.state.leftThumbstickY;
        if (leftY > 1000 || leftY < -1000) {
          double value = (leftY ~/ 1000) / 10.0; // 0 .. 3.2
          value += (value > 0) ? 1.0 : -1.0; // 1.0 .. 4.2 или -1.0 .. -4.2
          if (value > 0 && value > _zoomValue) {
            _zoomValue = value;
            widget._dataChannel.send(RTCDataChannelMessage('zoom ${_zoomValue.toStringAsFixed(1)}'));
          } else if (value < 0) {
            double inv = 5.2 + value; // 4.2 .. 1.0, так как value отрицательное
            if (inv < _zoomValue) {
              _zoomValue = inv;
              widget._dataChannel.send(RTCDataChannelMessage('zoom ${_zoomValue.toStringAsFixed(1)}'));
            }
          }
        }

        return Container();
      },
    );
  }
}
