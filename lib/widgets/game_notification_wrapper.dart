// lib/widgets/game_notification_wrapper.dart
import 'package:flutter/material.dart';
import '../services/game_notification_manager.dart';

class GameNotificationWrapper extends StatefulWidget {
  final Widget child;

  const GameNotificationWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  _GameNotificationWrapperState createState() => _GameNotificationWrapperState();
}

class _GameNotificationWrapperState extends State<GameNotificationWrapper> {
  final notificationManager = GameNotificationManager();

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Stack(
        children: [
          widget.child,
          StreamBuilder<Widget>(
            stream: notificationManager.notificationStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return SizedBox.shrink();
              return Positioned(
                top: MediaQuery.of(context).padding.top + 20,
                left: 20,
                right: 20,
                child: snapshot.data!,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    notificationManager.dispose();
    super.dispose();
  }
}