import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io/socket_io.dart';

import '../settings/constraints.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  createState() => CameraViewState();
}

class CameraViewState extends State<CameraView> {
  final RTCVideoRenderer _localVideoRenderer = RTCVideoRenderer();
  late final RTCPeerConnection _localPc;
  late final MediaStream _localStream;

  late final RTCDataChannel _dataChannel;
  bool _statusTorch = false; // Подсветка выключена

  late final Server _server;
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
    await _localVideoRenderer.dispose();
    await _dataChannel.close();
    super.dispose();
  }

  //--------------------------------------------------------------------------//
  Future<void> _init() async {
    await _makeWebRTC();
    await _startSocketHandler();
  }

  //--------------------------------------------------------------------------//
  Future<void> _makeWebRTC() async {
    await _localVideoRenderer.initialize();

    _localPc = await createPeerConnection(configuration, peerConnectionConstraints);
    _localPc.onIceConnectionState = (RTCIceConnectionState state) async {
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _localPc.restartIce();
          return;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          // Здесь обрабатываем событие - собеседник вышел из приложения
          // Если подсветка включена, выключаем
          if (_statusTorch) {
            final videoTrack =
                _localStream.getVideoTracks().firstWhere((track) => track.kind == 'video');
            final hasTorch = await videoTrack.hasTorch();

            if (hasTorch) {
              await videoTrack.setTorch(!_statusTorch);
              _statusTorch ^= true; // Устанавливаем выбранное состояние подсветки
              debugPrint('[TORCH] Подсветка ${_statusTorch ? 'включена' : 'выключена'}');
            } else {
              debugPrint('[TORCH] Выбранная камера работает без подсветки');
            }
          }
          return;
        default:
          return;
      }
    };

    _localPc.onIceCandidate = (RTCIceCandidate candidate) async {
      await Future.delayed(const Duration(milliseconds: 1000), () {
        _sendSocket(_socket, 'signal', 'candidate', {
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
          'candidate': candidate.candidate,
        });
      });
    };

    _localPc.onDataChannel = (channel) {
      channel.onMessage = (data) async {
        final dataList = data.text.split(' ');
        final videoTrack = _localStream.getVideoTracks().firstWhere((track) => track.kind == 'video');

        switch (dataList[0]) {
          case 'torch':
            final hasTorch = await videoTrack.hasTorch();

            if (hasTorch) {
              await videoTrack.setTorch(!_statusTorch);
              _statusTorch ^= true; // Устанавливаем выбранное состояние подсветки
              debugPrint('[TORCH] Подсветка ${_statusTorch ? 'включена' : 'выключена'}');
            } else {
              debugPrint('[TORCH] Выбранная камера работает без подсветки');
            }

          case 'zoom':
            await WebRTC.invokeMethod('mediaStreamTrackSetZoom',
                <String, dynamic>{'trackId': videoTrack.id, 'zoomLevel': double.tryParse(dataList[1])});
        }
      };
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localVideoRenderer.srcObject = _localStream;
    _localStream.getTracks().forEach((track) {
      _localPc.addTrack(track, _localStream);
    });

    _dataChannel = await _localPc.createDataChannel('data', RTCDataChannelInit());

    if (mounted) setState(() {});
  }

  //--------------------------------------------------------------------------//
  Future<void> _startSocketHandler() async {
    _server = Server();

    _server.on('connection', (client) async {
      _socket = client;
      if (_socket != null) {
        RTCSessionDescription sessionDescription = await _localPc.createOffer(offerConstraints);
        await _localPc.setLocalDescription(sessionDescription);
        _sendSocket(_socket, 'signal', 'offer', sessionDescription.sdp);
      }

      _socket?.on('msg', (data) async {
        final msg = jsonDecode(data);
        if (msg['command'] == 'signal') {
          if (msg['type'] == 'answer') {
            try {
              await _localPc.setRemoteDescription(RTCSessionDescription(msg['data'], msg['type']));
            } catch (e) {
              debugPrint('$e');
            }
          } else if (msg['type'] == 'candidate') {
            final data = msg['data'];
            RTCIceCandidate candidate =
                RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']);
            try {
              await _localPc.addCandidate(candidate);
            } catch (e) {
              debugPrint('$e');
            }
          }
        }
      });
    });

    _server.listen(4001);
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
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // RTCVideoView(_localVideoRenderer),
            Positioned(
              top: 10,
              child: ElevatedButton(
                onPressed: () async {
                  await _dataChannel.send(RTCDataChannelMessage('Hello client'));
                },
                child: const Text('Отправить клиенту'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
