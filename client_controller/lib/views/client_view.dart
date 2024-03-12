import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart';

import '../gamepad/gamepad_widget.dart';
import '../settings/constraints.dart';

class ClientView extends StatefulWidget {
  const ClientView({super.key});

  @override
  createState() => ClientViewState();
}

class ClientViewState extends State<ClientView> {
  final RTCVideoRenderer _remoteVideoRenderer = RTCVideoRenderer();
  late final RTCPeerConnection _remotePc;

  late final RTCDataChannel _dataChannel;
  bool _statusTorch = false; // Подсветка выключена
  double _zoomValue = 1.0;
  Socket? _socket;

  //--------------------------------------------------------------------------//
  @override
  void initState() {
    _init();
    super.initState();
  }

  //--------------------------------------------------------------------------//
  @override
  void dispose() async {
    await _remoteVideoRenderer.dispose();
    await _dataChannel.close();

    _remotePc.close();
    _remotePc.dispose();

    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    super.dispose();
  }

  //--------------------------------------------------------------------------//
  void _init() async {
    await _makeWebRTC();
    // Используем заранее известный адрес сервера
    String serverip = 'http://192.168.1.38:4001';
    await _startClientSocket(serverip);
  }

  //--------------------------------------------------------------------------//
  Future<void> _makeWebRTC() async {
    await _remoteVideoRenderer.initialize();

    _remotePc = await createPeerConnection(configuration, peerConnectionConstraints);

    _remotePc.onIceConnectionState = (RTCIceConnectionState state) {
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _remotePc.restartIce();
          return;
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
          if (mounted) setState(() {});
          break;
        default:
          return;
      }
    };

    _remotePc.onIceCandidate = (RTCIceCandidate candidate) async {
      await Future.delayed(const Duration(milliseconds: 1000), () {
        _sendSocket(_socket, 'signal', 'candidate', {
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
          'candidate': candidate.candidate,
        });
      });
    };

    _remotePc.onTrack = (RTCTrackEvent event) async {
      if (event.track.kind == 'video') {
        _remoteVideoRenderer.srcObject = event.streams.first;
      }
    };

    _remotePc.onDataChannel = (channel) {
      channel.onMessage = (data) {
        debugPrint('Получили сообщение с сервера ${data.text} ++++++++++++++++++++++++++++++++++++');
      };
    };

    _dataChannel = await _remotePc.createDataChannel('data', RTCDataChannelInit());
  }

  //--------------------------------------------------------------------------//
  Future<void> _startClientSocket(String serverip) async {
    _socket = io(
      serverip,
      OptionBuilder().setTransports(['websocket']).disableAutoConnect().enableMultiplex().build(),
    );

    _socket?.on('msg', (data) async {
      final msg = jsonDecode(data);

      if (msg['command'] == 'signal') {
        if (msg['type'] == 'offer') {
          try {
            await _remotePc.setRemoteDescription(RTCSessionDescription(msg['data'], msg['type']));
            RTCSessionDescription sessionDescription = await _remotePc.createAnswer();
            await _remotePc.setLocalDescription(sessionDescription);
            _sendSocket(_socket, 'signal', 'answer', sessionDescription.sdp);
          } catch (e) {
            debugPrint('$e');
          }
        } else if (msg['type'] == 'candidate') {
          final data = msg['data'];
          RTCIceCandidate candidate =
              RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']);
          try {
            await _remotePc.addCandidate(candidate);
          } catch (e) {
            debugPrint('$e');
          }
        }
      }
    });
    _socket?.connect();
  }

  //--------------------------------------------------------------------------//
  void _sendSocket(Socket? socket, String command, String event, dynamic data) {
    _socket?.emit(
      'msg',
      jsonEncode(<String, dynamic>{
        'command': command,
        'type': event,
        'data': data,
      }),
    );
  }

  //--------------------------------------------------------------------------//
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          RTCVideoView(
            _remoteVideoRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            //mirror: false,
            filterQuality: FilterQuality.low,
          ),
          Positioned(
            top: 10,
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await _dataChannel.send(RTCDataChannelMessage('torch'));
                    _statusTorch ^= true;
                    setState(() {});
                  },
                  child: Icon(_statusTorch ? Icons.flash_off : Icons.flash_on),
                ),
                const SizedBox(width: 30),
                GamepadWidget(dataChannel: _dataChannel),
                ElevatedButton(
                  onPressed: (_zoomValue < 4.0)
                      ? () async {
                          _zoomValue += 1.0;
                          await _dataChannel.send(RTCDataChannelMessage('zoom $_zoomValue'));
                          setState(() {});
                        }
                      : null,
                  child: const Icon(Icons.zoom_in),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: (_zoomValue > 1.0)
                      ? () async {
                          _zoomValue -= 1.0;
                          await _dataChannel.send(RTCDataChannelMessage('zoom $_zoomValue'));
                          setState(() {});
                        }
                      : null,
                  child: const Icon(Icons.zoom_out),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
