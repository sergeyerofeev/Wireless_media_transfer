import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../helpers/constants.dart';

class CamPanel extends StatefulWidget {
  const CamPanel({super.key});

  @override
  createState() => CamPanelState();
}

class CamPanelState extends State<CamPanel> {
  final _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _remotePc;
  IO.Socket? _socket;

  //--------------------------------------------------------------------------//
  @override
  void initState() {
    super.initState();
    _init();
  }

  //--------------------------------------------------------------------------//
  @override
  void dispose() async {
    await _closePeer();
    await _closeSocket();
    super.dispose();
  }

  //--------------------------------------------------------------------------//
  Future<void> _closeSocket() async {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
  }

  //--------------------------------------------------------------------------//
  Future<void> _closePeer() async {
    await _remoteRenderer.dispose();

    if (_remotePc != null) {
      _remotePc!.close();
      _remotePc!.dispose();
      _remotePc = null;
    }
  }

  //--------------------------------------------------------------------------//
  void update() {
    if (mounted) {
      setState(() {});
    }
  }

  //--------------------------------------------------------------------------//
  void _init() async {
    await _makeWebRTC();
    String serverip = "http://192.168.1.38:4001";
    print('Сервер IP: $serverip');
    await _startClientSocket(serverip);
  }

  //--------------------------------------------------------------------------//
  Future<void> _startClientSocket(String serverip) async {
    _socket = IO.io(serverip,
        IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().enableMultiplex().build());
    _socket!.on('msg', (data) {
      final msg = jsonDecode(data);
      if (msg["command"] == "signal") {
        socketDataHandler(data);
      }
    });
    _socket!.connect();
  }

  //--------------------------------------------------------------------------//
  Future<void> _makeWebRTC() async {
    await _remoteRenderer.initialize();

    _remotePc = await createPeerConnection(configuration, constraints);
    _remotePc!.onIceConnectionState = (RTCIceConnectionState state) {
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
          update();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _remotePc!.restartIce();
          return;
        default:
          return;
      }
    };
    _remotePc!.onConnectionState = (RTCPeerConnectionState state) async {
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          update();
          break;
        default:
          return;
      }
    };
    _remotePc!.onIceCandidate = (RTCIceCandidate candidate) async {
      await Future.delayed(const Duration(milliseconds: 1000), () {
        _sendSocket("signal", "candidate", {
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
          'candidate': candidate.candidate,
        });
      });
    };

    _remotePc!.onTrack = (RTCTrackEvent event) async {
      if (event.track.kind == "video") {
        _remoteRenderer.srcObject = event.streams.first;
      }
    };
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
      try {
        await _remotePc!.setRemoteDescription(RTCSessionDescription(msg["data"], msg["type"]));
        RTCSessionDescription desc = await _remotePc!.createAnswer();
        await _remotePc!.setLocalDescription(desc);
        _sendSocket("signal", "answer", desc.sdp);
      } catch (e) {
        print(e);
      }
    } else if (msg["type"] == "candidate") {
      final can1 = msg["data"];
      RTCIceCandidate candidate =
          RTCIceCandidate(can1["candidate"], can1["sdpMid"], can1["sdpMLineIndex"]);
      try {
        if (_remotePc != null) await _remotePc!.addCandidate(candidate);
      } catch (e) {
        print(e);
      }
    }
  }

  //--------------------------------------------------------------------------//
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: RTCVideoView(_remoteRenderer),
    );
  }
}
