// permission_service.dart

import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();

  factory PermissionService() => _instance;

  PermissionService._internal();

  /// Richiede il permesso per il microfono
  Future<bool> requestMicrophonePermission() async {
    var status = await Permission.microphone.status;

    if (status.isDenied) {
      status = await Permission.microphone.request();
    }

    return status.isGranted;
  }

  /// Verifica se il permesso del microfono è stato concesso
  Future<bool> checkMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }

  /// Verifica se il permesso del microfono è stato negato permanentemente
  Future<bool> isMicrophonePermissionPermanentlyDenied() async {
    return await Permission.microphone.isPermanentlyDenied;
  }

  /// Richiede tutti i permessi necessari per l'app
  Future<Map<Permission, bool>> requestAllPermissions() async {
    Map<Permission, bool> permissionsStatus = {};

    // Aggiungi qui altri permessi se necessario
    final permissions = [
      Permission.microphone,
    ];

    for (var permission in permissions) {
      permissionsStatus[permission] = await _requestPermission(permission);
    }

    return permissionsStatus;
  }

  /// Richiede un singolo permesso
  Future<bool> _requestPermission(Permission permission) async {
    var status = await permission.status;

    if (status.isDenied) {
      status = await permission.request();
    }

    return status.isGranted;
  }

  /// Apre le impostazioni del dispositivo
  Future<void> openSettings() async {
    await AppSettings.openAppSettings();
  }

  /// Gestisce un permesso negato
  Future<bool> handleDeniedPermission(Permission permission) async {
    if (await permission.isPermanentlyDenied) {
      // Se il permesso è stato negato permanentemente, apri le impostazioni
      await openSettings();
      return false;
    }

    // Richiedi nuovamente il permesso
    final status = await permission.request();
    return status.isGranted;
  }

  /// Verifica se tutti i permessi necessari sono stati concessi
  Future<bool> checkAllPermissions() async {
    final permissions = [
      Permission.microphone,
      // Aggiungi qui altri permessi se necessario
    ];

    for (var permission in permissions) {
      if (!await permission.isGranted) {
        return false;
      }
    }

    return true;
  }

  /// Restituisce lo stato corrente di un permesso
  Future<String> getPermissionStatus(Permission permission) async {
    final status = await permission.status;

    switch (status) {
      case PermissionStatus.granted:
        return 'Concesso';
      case PermissionStatus.denied:
        return 'Negato';
      case PermissionStatus.permanentlyDenied:
        return 'Negato Permanentemente';
      case PermissionStatus.restricted:
        return 'Limitato';
      case PermissionStatus.limited:
        return 'Limitato';
      case PermissionStatus.provisional:
        return 'Provvisorio';
      default:
        return 'Sconosciuto';
    }
  }
}