import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'role.dart';

class Player {
  final String id;
  final String name;
  bool isReady = false;
  bool isAlive = true;
  Role? role;
  MediaStream? stream;

  Player({
    required this.id,
    required this.name,
    this.isReady = false,
    this.isAlive = true,
    this.role,
    this.stream,
  });
}
