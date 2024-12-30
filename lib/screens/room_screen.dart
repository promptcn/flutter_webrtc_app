import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/game_room.dart';
import '../models/player.dart';
import 'game_screen.dart';

class RoomScreen extends StatefulWidget {
  final String roomId;
  final Player currentPlayer;
  final bool isHost;

  const RoomScreen({
    super.key,
    required this.roomId,
    required this.currentPlayer,
    required this.isHost,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late GameRoom gameRoom;
  final List<RTCVideoRenderer> _renderers = [];

  @override
  void initState() {
    super.initState();
    _initRoom();
  }

  Future<void> _initRoom() async {
    gameRoom = GameRoom(
      roomId: widget.roomId,
      hostId: widget.isHost ? widget.currentPlayer.id : '',
      players: [widget.currentPlayer],
    );

    // 初始化视频渲染器
    for (int i = 0; i < gameRoom.maxPlayers; i++) {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      _renderers.add(renderer);
    }

    setState(() {});
  }

  void _toggleReady() {
    setState(() {
      widget.currentPlayer.isReady = !widget.currentPlayer.isReady;
    });
  }

  void _startGame() {
    if (gameRoom.canStartGame) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(
            gameRoom: gameRoom,
            currentPlayer: widget.currentPlayer,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('房间号: ${widget.roomId}'),
        actions: [
          if (widget.isHost)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: gameRoom.canStartGame ? _startGame : null,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3 / 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: gameRoom.maxPlayers,
              itemBuilder: (context, index) {
                final player = index < gameRoom.players.length
                    ? gameRoom.players[index]
                    : null;

                return Card(
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: player?.stream != null
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
                            Text(player?.name ?? '等待加入...'),
                            if (player != null)
                              Chip(
                                label: Text(
                                  player.isReady ? '已准备' : '未准备',
                                ),
                                backgroundColor:
                                    player.isReady ? Colors.green : Colors.grey,
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _toggleReady,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    widget.currentPlayer.isReady ? Colors.red : Colors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                widget.currentPlayer.isReady ? '取消准备' : '准备',
                style: const TextStyle(fontSize: 18),
              ),
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
