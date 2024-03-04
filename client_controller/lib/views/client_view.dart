import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../settings/constraints.dart';

class ClientView extends StatefulWidget {
  const ClientView({super.key});

  @override
  createState() => ClientViewState();
}

class ClientViewState extends State<ClientView> {
  final RTCVideoRenderer _remoteVideoRenderer = RTCVideoRenderer();
  late final RTCPeerConnection _remotePc;
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
            RTCSessionDescription desc = await _remotePc.createAnswer();
            await _remotePc.setLocalDescription(desc);
            _sendSocket(_socket, 'signal', 'answer', desc.sdp);
          } catch (e) {
            print(e);
          }
        } else if (msg['type'] == 'candidate') {
          final can1 = msg['data'];
          RTCIceCandidate candidate =
              RTCIceCandidate(can1['candidate'], can1['sdpMid'], can1['sdpMLineIndex']);
          try {
            await _remotePc.addCandidate(candidate);
          } catch (e) {
            print(e);
          }
        }
      }
    });
    _socket?.connect();
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
          RTCVideoView(_remoteVideoRenderer),
        ],
      ),
    );
  }
}
