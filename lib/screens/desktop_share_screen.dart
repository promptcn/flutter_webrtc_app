import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/signalling.service.dart';

class DesktopShareScreen extends StatefulWidget {
  final String selfCallerId;

  const DesktopShareScreen({super.key, required this.selfCallerId});

  @override
  State<DesktopShareScreen> createState() => _DesktopShareScreenState();
}

class _DesktopShareScreenState extends State<DesktopShareScreen> {
  final socket = SignallingService.instance.socket;
  final _localRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    _setupConnection();
  }

  Future<void> _setupConnection() async {
    // 获取屏幕共享流
    _localStream = await navigator.mediaDevices.getDisplayMedia({
      'video': true,
      'audio': false,
    });

    _localRenderer.srcObject = _localStream;
    setState(() {});

    // 处理来电
    socket!.on("newCall", (data) async {
      final callerId = data["callerId"];

      _peerConnection = await createPeerConnection({});

      // 添加屏幕共享轨道
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 处理ICE候选
      _peerConnection!.onIceCandidate = (candidate) {
        socket!.emit("IceCandidate", {
          "calleeId": callerId,
          "iceCandidate": {
            "id": candidate.sdpMid,
            "label": candidate.sdpMLineIndex,
            "candidate": candidate.candidate
          }
        });
      };

      // 设置远程描述并创建应答
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(
          data["sdpOffer"]["sdp"], data["sdpOffer"]["type"]));

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      socket!.emit("answerCall", {
        "callerId": callerId,
        "sdpAnswer": answer.toMap(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('屏幕共享 - ID: ${widget.selfCallerId}')),
      body: Center(
        child: RTCVideoView(
          _localRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
        ),
      ),
    );
  }
}
