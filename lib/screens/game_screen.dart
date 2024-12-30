import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/game_room.dart';
import '../models/player.dart';
import '../models/role.dart';

class GameScreen extends StatefulWidget {
  final GameRoom gameRoom;
  final Player currentPlayer;

  const GameScreen({
    super.key,
    required this.gameRoom,
    required this.currentPlayer,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final List<RTCVideoRenderer> _renderers = [];
  bool _isMuted = false;
  bool _isVideoEnabled = true;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
  }

  Future<void> _initializeRenderers() async {
    for (int i = 0; i < widget.gameRoom.maxPlayers; i++) {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      _renderers.add(renderer);
    }
    setState(() {});
  }

  void _toggleAudio() {
    setState(() => _isMuted = !_isMuted);
    // 在这里实现音频开关逻辑
  }

  void _toggleVideo() {
    setState(() => _isVideoEnabled = !_isVideoEnabled);
    // 在这里实现视频开关逻辑
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.gameRoom.isNight ? '🌙 夜晚' : '☀️ 白天',
        ),
        actions: [
          IconButton(
            icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
            onPressed: _toggleAudio,
          ),
          IconButton(
            icon: Icon(_isVideoEnabled ? Icons.videocam : Icons.videocam_off),
            onPressed: _toggleVideo,
          ),
        ],
      ),
      body: Column(
        children: [
          // 角色信息
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black45,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.currentPlayer.role == Role.werewolf
                      ? Icons.wrong_location
                      : Icons.person,
                  color: widget.currentPlayer.role == Role.werewolf
                      ? Colors.red
                      : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  '你的身份: ${widget.currentPlayer.role?.displayName ?? "未分配"}',
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
          // 玩家视频网格
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3 / 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: widget.gameRoom.players.length,
              itemBuilder: (context, index) {
                final player = widget.gameRoom.players[index];
                return Card(
                  color: !player.isAlive ? Colors.red.withOpacity(0.3) : null,
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: player.stream != null
                              ? RTCVideoView(
                                  _renderers[index],
                                  objectFit: RTCVideoViewObjectFit
                                      .RTCVideoViewObjectFitCover,
                                )
                              : const Icon(
                                  Icons.person_outline,
                                  size: 48,
                                  color: Colors.white54,
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text(
                              player.name,
                              style: TextStyle(
                                decoration: !player.isAlive
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (!player.isAlive)
                              const Chip(
                                label: Text('已死亡'),
                                backgroundColor: Colors.red,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (var renderer in _renderers) {
      renderer.dispose();
    }
    super.dispose();
  }
}
