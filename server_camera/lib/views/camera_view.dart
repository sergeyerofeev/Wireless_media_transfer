import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io/socket_io.dart';

import '../helpers/constants.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  createState() => CameraViewState();
}

class CameraViewState extends State<CameraView> {
  final RTCVideoRenderer _localVideoRenderer = RTCVideoRenderer();
  late final RTCPeerConnection _localPc;

  late final Server _socketServer;
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
  void update() {
    if (mounted) setState(() {});
  }

  //--------------------------------------------------------------------------//
  Future<void> _init() async {
    await _makeWebRTC();
    await _startSocketHandler();
  }

  //--------------------------------------------------------------------------//
  Future<void> _makeWebRTC() async {
    await _localVideoRenderer.initialize();

    _localPc = await createPeerConnection(configuration, constraints);
    _localPc.onIceConnectionState = (RTCIceConnectionState state) {
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _localPc.restartIce();
          return;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          return;
        default:
          return;
      }
    };
    _localPc.onConnectionState = (RTCPeerConnectionState state) async {
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          update();
          break;
        default:
          return;
      }
    };
    _localPc.onIceCandidate = (RTCIceCandidate candidate) async {
      await Future.delayed(const Duration(milliseconds: 1000), () {
        _sendSocket("signal", "candidate", {
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

    update();
  }

  //--------------------------------------------------------------------------//
  Future<void> _startSocketHandler() async {
    _socketServer = Server();
    _socketServer.on('connection', (client) async {
      _socket = client;
      if (_socket != null) {
        RTCSessionDescription desc = await _localPc.createOffer(oaConstraints);
        await _localPc.setLocalDescription(desc);
        _sendSocket("signal", "offer", desc.sdp);
      }

      _socket!.on('msg', (data) {
        final msg = jsonDecode(data);
        if (msg["command"] == "signal") {
          socketDataHandler(data);
        }
      });
    });
    _socketServer.listen(4001);
  }

  //--------------------------------------------------------------------------//
  void _sendSocket(command, event, data) {
    var request = {};
    request["command"] = command;
    request["type"] = event;
    request["data"] = data;
    if (_socket != null) {
      _socket!.emit("msg", jsonEncode(request).toString());
    }
  }

  //--------------------------------------------------------------------------//
  void socketDataHandler(String data) async {
    final msg = jsonDecode(data);

    if (msg["type"] == "offer") {
      // Предложения о подключении от клиентов игнорируем,
      // так как это сервер и сервер рассылает предложения
    } else if (msg["type"] == "answer") {
      // Поличили ответ на предложение (offer)
      try {
        await _localPc.setRemoteDescription(RTCSessionDescription(msg["data"], msg["type"]));
      } catch (e) {
        print(e);
      }
    } else if (msg["type"] == "candidate") {
      print('Получили сообщение от кандидата ======================================');
      final can1 = msg["data"];
      RTCIceCandidate candidate =
          RTCIceCandidate(can1["candidate"], can1["sdpMid"], can1["sdpMLineIndex"]);
      try {
        await _localPc.addCandidate(candidate);
      } catch (e) {
        print(e);
      }
    }
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
