import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'screens/join_screen.dart';
import 'screens/desktop_share_screen.dart';
import 'services/signalling.service.dart';

void main() {
  // 启动应用
  runApp(VideoCallApp());
}

class VideoCallApp extends StatelessWidget {
  VideoCallApp({super.key});

  // 信令服务器地址
  final String websocketUrl = "http://192.168.1.158:5001";

  // 生成本地用户ID
  final String selfCallerID =
      Random().nextInt(999999).toString().padLeft(6, '0');

  @override
  Widget build(BuildContext context) {
    // 初始化信令服务
    SignallingService.instance.init(
      websocketUrl: websocketUrl,
      selfCallerID: selfCallerID,
    );

    // 根据平台返回不同的主页面
    Widget homeScreen =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux
            ? DesktopShareScreen(selfCallerId: selfCallerID) // 桌面端显示共享屏幕界面
            : JoinScreen(selfCallerId: selfCallerID); // 移动端显示接收界面

    return MaterialApp(
      darkTheme: ThemeData.dark(
        useMaterial3: true,
      ).copyWith(
        colorScheme: const ColorScheme.dark(),
      ),
      themeMode: ThemeMode.dark,
      home: homeScreen,
    );
  }
}
