import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/signalling.service.dart';

class CallScreen extends StatefulWidget {
  final String callerId, calleeId;
  final dynamic offer;
  const CallScreen({
    super.key,
    this.offer,
    required this.callerId,
    required this.calleeId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  // socket instance
  final socket = SignallingService.instance.socket;

  // videoRenderer for localPeer
  final _localRTCVideoRenderer = RTCVideoRenderer();

  // videoRenderer for remotePeer
  final _remoteRTCVideoRenderer = RTCVideoRenderer();

  // mediaStream for localPeer
  MediaStream? _localStream;

  // RTC peer connection
  RTCPeerConnection? _rtcPeerConnection;

  // list of rtcCandidates to be sent over signalling
  List<RTCIceCandidate> rtcIceCadidates = [];

  // media status
  bool isAudioOn = true, isVideoOn = true, isFrontCameraSelected = true;

  @override
  void initState() {
    // initializing renderers
    _localRTCVideoRenderer.initialize();
    _remoteRTCVideoRenderer.initialize();

    // setup Peer Connection
    _setupPeerConnection();
    super.initState();
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  _setupPeerConnection() async {
    // 添加连接状态变化日志
    print('开始建立点对点连接...');

    _rtcPeerConnection = await createPeerConnection({
      // 'iceServers': [
      //   {
      //     'urls': ['stun.voipbuster.com', 'stun.voipstunt.com']
      //   }
      // ]
    });

    // 监听连接状态变化
    _rtcPeerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      print('连接状态变化: $state');
    };

    // 监听 ICE 连接状态
    _rtcPeerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('ICE 连接状态: $state');
    };

    // 监听 ICE 候选者收集状态
    _rtcPeerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
      print('ICE 收集状态: $state');
    };

    _rtcPeerConnection!.onSignalingState = (RTCSignalingState state) {
      print('信令状态变化: $state');
    };

    _rtcPeerConnection!.onTrack = (event) {
      print('收到远端媒体流轨道');
      print('轨道类型: ${event.track.kind}'); // 'video' 或 'audio'
      print('轨道状态: ${event.track.enabled}');
      print('媒体流ID: ${event.streams[0].id}');

      // 确保在主线程中更新 UI
      setState(() {
        _remoteRTCVideoRenderer.srcObject = event.streams[0];
      });
    };

    // 获取本地媒体流时添加日志
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': isAudioOn,
      'video': isVideoOn
          ? {'facingMode': isFrontCameraSelected ? 'user' : 'environment'}
          : false,
    });

    print('本地媒体流获取成功');
    print('视频轨道数量: ${_localStream!.getVideoTracks().length}');
    print('音频轨道数量: ${_localStream!.getAudioTracks().length}');

    // 添加轨道时打印日志
    _localStream!.getTracks().forEach((track) {
      print('添加轨道到连接: ${track.kind}');
      _rtcPeerConnection!.addTrack(track, _localStream!);
    });

    // set source for local video renderer
    _localRTCVideoRenderer.srcObject = _localStream;
    setState(() {});

    // for Incoming call
    if (widget.offer != null) {
      print('处理来电请求...');

      // 添加 ICE 候选者处理
      _rtcPeerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        print('接听方发送 ICE 候选者');
        socket!.emit("IceCandidate", {
          "calleeId": widget.callerId, // 注意这里发送给呼叫方
          "iceCandidate": {
            "id": candidate.sdpMid,
            "label": candidate.sdpMLineIndex,
            "candidate": candidate.candidate
          }
        });
      };

      // listen for Remote IceCandidate
      socket!.on("IceCandidate", (data) {
        print('收到远端 ICE candidate');
        String candidate = data["iceCandidate"]["candidate"];
        String sdpMid = data["iceCandidate"]["id"];
        int sdpMLineIndex = data["iceCandidate"]["label"];

        // add iceCandidate
        _rtcPeerConnection!.addCandidate(RTCIceCandidate(
          candidate,
          sdpMid,
          sdpMLineIndex,
        ));
      });

      // set SDP offer as remoteDescription for peerConnection
      await _rtcPeerConnection!.setRemoteDescription(
        RTCSessionDescription(widget.offer["sdp"], widget.offer["type"]),
      );
      print('设置远程描述成功');

      // create SDP answer
      RTCSessionDescription answer = await _rtcPeerConnection!.createAnswer();
      print('创建应答成功');

      // set SDP answer as localDescription for peerConnection
      _rtcPeerConnection!.setLocalDescription(answer);
      print('设置本地描述成功');

      // send SDP answer to remote peer over signalling
      socket!.emit("answerCall", {
        "callerId": widget.callerId,
        "sdpAnswer": answer.toMap(),
      });
      print('已发送应答');
    }
    // for Outgoing Call
    else {
      print('发起呼叫...');

      // 修改 ICE 候选者处理逻辑
      _rtcPeerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        print('呼叫方发送 ICE 候选者');
        socket!.emit("IceCandidate", {
          "calleeId": widget.calleeId,
          "iceCandidate": {
            "id": candidate.sdpMid,
            "label": candidate.sdpMLineIndex,
            "candidate": candidate.candidate
          }
        });
      };

      // listen for local iceCandidate and add it to the list of IceCandidate
      _rtcPeerConnection!.onIceCandidate =
          (RTCIceCandidate candidate) => rtcIceCadidates.add(candidate);

      // when call is accepted by remote peer
      socket!.on("callAnswered", (data) async {
        print('对方接受呼叫');
        // set SDP answer as remoteDescription for peerConnection
        await _rtcPeerConnection!.setRemoteDescription(
          RTCSessionDescription(
            data["sdpAnswer"]["sdp"],
            data["sdpAnswer"]["type"],
          ),
        );
        print('设置远端描述完成');

        // send iceCandidate generated to remote peer over signalling
        for (RTCIceCandidate candidate in rtcIceCadidates) {
          socket!.emit("IceCandidate", {
            "calleeId": widget.calleeId,
            "iceCandidate": {
              "id": candidate.sdpMid,
              "label": candidate.sdpMLineIndex,
              "candidate": candidate.candidate
            }
          });
        }
      });

      // create SDP Offer
      RTCSessionDescription offer = await _rtcPeerConnection!.createOffer();
      print('创建提议成功');

      // set SDP offer as localDescription for peerConnection
      await _rtcPeerConnection!.setLocalDescription(offer);
      print('设置本地描述成功');

      // make a call to remote peer over signalling
      socket!.emit('makeCall', {
        "calleeId": widget.calleeId,
        "sdpOffer": offer.toMap(),
      });
      print('已发送提议');
    }
  }

  _leaveCall() {
    Navigator.pop(context);
  }

  _toggleMic() {
    // change status
    isAudioOn = !isAudioOn;
    // enable or disable audio track
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = isAudioOn;
    });
    setState(() {});
  }

  _toggleCamera() {
    // change status
    isVideoOn = !isVideoOn;

    // enable or disable video track
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = isVideoOn;
    });
    setState(() {});
  }

  _switchCamera() {
    // change status
    isFrontCameraSelected = !isFrontCameraSelected;

    // switch camera
    _localStream?.getVideoTracks().forEach((track) {
      // ignore: deprecated_member_use
      track.switchCamera();
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text("P2P Call App"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(children: [
                RTCVideoView(
                  _remoteRTCVideoRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  // 添加键值以便调试
                  key: const Key('remoteVideo'),
                ),
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: SizedBox(
                    height: 150,
                    width: 120,
                    child: RTCVideoView(
                      _localRTCVideoRenderer,
                      mirror: isFrontCameraSelected,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      // 添加键值以便调试
                      key: const Key('localVideo'),
                    ),
                  ),
                )
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: Icon(isAudioOn ? Icons.mic : Icons.mic_off),
                    onPressed: _toggleMic,
                  ),
                  IconButton(
                    icon: const Icon(Icons.call_end),
                    iconSize: 30,
                    onPressed: _leaveCall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.cameraswitch),
                    onPressed: _switchCamera,
                  ),
                  IconButton(
                    icon: Icon(isVideoOn ? Icons.videocam : Icons.videocam_off),
                    onPressed: _toggleCamera,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _localRTCVideoRenderer.dispose();
    _remoteRTCVideoRenderer.dispose();
    _localStream?.dispose();
    _rtcPeerConnection?.dispose();
    super.dispose();
  }
}
