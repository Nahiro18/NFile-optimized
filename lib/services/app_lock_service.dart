import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Servicio de bloqueo con biometría
class AppLockService {
  static const String _keyBiometricEnabled = 'biometric_enabled';
  
  static SharedPreferences? _prefs;
  static final LocalAuthentication _localAuth = LocalAuthentication();
  
  static const String _keyVaultPassword = 'vault_cached_password';

  /// Inicializa el servicio
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Guarda la contraseña para uso con biometría
  static Future<void> cacheVaultPassword(String password) async {
    await _prefs?.setString(_keyVaultPassword, password);
  }
  
  /// Obtiene la contraseña guardada
  static String? getCachedVaultPassword() {
    return _prefs?.getString(_keyVaultPassword);
  }
  
  /// Verifica si la biometría está habilitada (solo para el baúl)
  static bool isBiometricEnabled() {
    return _prefs?.getBool(_keyBiometricEnabled) ?? false;
  }
  
  /// Habilita/deshabilita biometría
  static Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs?.setBool(_keyBiometricEnabled, enabled);
  }
  
  /// Verifica si el dispositivo tiene biometría disponible
  static Future<bool> hasBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }
  
  /// Autentica al usuario usando biometría
  static Future<bool> authenticate({
    required String reason,
  }) async {
    try {
      if (!await hasBiometrics()) return false;
      
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
      );
      
      return authenticated;
    } on PlatformException catch (e) {
      debugPrint('[AppLock] Authentication error: $e');
      return false;
    }
  }
}
