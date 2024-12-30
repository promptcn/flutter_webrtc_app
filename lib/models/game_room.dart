import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'player.dart';

class GameRoom {
  final String roomId;
  final String hostId;
  final List<Player> players;
  final int maxPlayers = 6; // 先从6人局开始

  // 简化的游戏状态
  bool isGameStarted = false;
  bool isNight = false;

  GameRoom({
    required this.roomId,
    required this.hostId,
    List<Player>? players,
  }) : players = players ?? [];

  bool get canStartGame =>
      players.length >= 6 && players.every((p) => p.isReady);
}
