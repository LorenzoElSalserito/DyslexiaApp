import 'package:permission_handler/permission_handler.dart';

class PermissionsHandler {
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  static Future<bool> checkMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }
}