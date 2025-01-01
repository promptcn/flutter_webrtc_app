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
    print('开始设置桌面共享连接...');

    // 获取屏幕共享流
    try {
      _localStream = await navigator.mediaDevices.getDisplayMedia({
        'video': true,
        'audio': false,
      });
      print('成功获取屏幕共享流');
      print('视频轨道数量: ${_localStream!.getVideoTracks().length}');
    } catch (e) {
      print('获取屏幕共享流失败: $e');
      return;
    }

    _localRenderer.srcObject = _localStream;
    setState(() {});

    // 处理来电
    socket!.on("newCall", (data) async {
      print('收到新的呼叫请求');
      final callerId = data["callerId"];

      try {
        _peerConnection = await createPeerConnection({
          'iceServers': [],
          'sdpSemantics': 'unified-plan',
          'iceTransportPolicy': 'all',
        });

        // 添加 ICE 候选者处理
        socket!.on("IceCandidate", (data) async {
          print('桌面端 - 收到远端ICE候选者');
          try {
            String candidate = data["iceCandidate"]["candidate"];
            String sdpMid = data["iceCandidate"]["id"];
            int sdpMLineIndex = data["iceCandidate"]["label"];

            await _peerConnection!.addCandidate(RTCIceCandidate(
              candidate,
              sdpMid,
              sdpMLineIndex,
            ));
            print('桌面端 - 成功添加ICE候选者');
          } catch (e) {
            print('桌面端 - 添加ICE候选者失败: $e');
          }
        });

        // 添加更多事件监听
        _peerConnection!.onTrack = (RTCTrackEvent event) {
          print('桌面端 - onTrack触发');
          print('桌面端 - 轨道类型: ${event.track.kind}');
        };

        // 添加更详细的连接状态监控
        _peerConnection!.onConnectionState = (state) {
          print('桌面端 - 连接状态变化: $state');
        };

        _peerConnection!.onIceConnectionState = (state) {
          print('桌面端 - ICE连接状态: $state');
          if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
            print('桌面端 - ICE连接失败，尝试重新协商...');
          }
        };

        _peerConnection!.onIceGatheringState = (state) {
          print('桌面端 - ICE收集状态: $state');
        };

        _peerConnection!.onIceCandidate = (candidate) {
          print('桌面端 - 发送ICE候选者: ${candidate.candidate}');
          socket!.emit("IceCandidate", {
            "calleeId": callerId,
            "iceCandidate": {
              "id": candidate.sdpMid,
              "label": candidate.sdpMLineIndex,
              "candidate": candidate.candidate
            }
          });
        };

        // 修改添加轨道的方式
        _localStream!.getTracks().forEach((track) {
          print('桌面端 - 添加轨道: ${track.kind}, id: ${track.id}');
          final sender = _peerConnection!.addTrack(track, _localStream!);
          print('桌面端 - 轨道发送器创建成功: ${sender != null}');
        });

        // 设置远程描述并创建应答
        await _peerConnection!.setRemoteDescription(RTCSessionDescription(
            data["sdpOffer"]["sdp"], data["sdpOffer"]["type"]));

        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);

        socket!.emit("answerCall", {
          "callerId": callerId,
          "sdpAnswer": answer.toMap(),
        });
      } catch (e) {
        print('设置PeerConnection失败: $e');
      }
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
