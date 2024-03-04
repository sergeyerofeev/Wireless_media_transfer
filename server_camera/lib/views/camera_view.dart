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
    _localPc.onIceConnectionState = (RTCIceConnectionState state) {
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _localPc.restartIce();
          return;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          // Здесь обрабатываем событие - собеседник вышел из приложения
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

    final localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localVideoRenderer.srcObject = localStream;
    localStream.getTracks().forEach((track) {
      _localPc.addTrack(track, localStream);
    });

    if (mounted) setState(() {});
  }

  //--------------------------------------------------------------------------//
  Future<void> _startSocketHandler() async {
    _server = Server();
    _server.on('connection', (client) async {
      _socket = client;
      if (_socket != null) {
        RTCSessionDescription desc = await _localPc.createOffer(offerConstraints);
        await _localPc.setLocalDescription(desc);
        _sendSocket(_socket, 'signal', 'offer', desc.sdp);
      }

      _socket?.on('msg', (data) async {
        final msg = jsonDecode(data);
        if (msg['command'] == 'signal') {
          if (msg['type'] == 'answer') {
            try {
              await _localPc.setRemoteDescription(RTCSessionDescription(msg['data'], msg['type']));
            } catch (e) {
              print(e);
            }
          } else if (msg['type'] == 'candidate') {
            final data = msg['data'];
            RTCIceCandidate candidate =
                RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']);
            try {
              await _localPc.addCandidate(candidate);
            } catch (e) {
              print(e);
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
      body: Stack(
        children: [
          RTCVideoView(_localVideoRenderer),
        ],
      ),
    );
  }
}
