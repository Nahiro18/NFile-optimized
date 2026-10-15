import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Servicio de bloqueo con biometría
class AppLockService {
  static const String _keyBiometricEnabled = 'biometric_enabled';
  
  static SharedPreferences? _prefs;
  static final LocalAuthentication _localAuth = LocalAuthentication();
  
  // El PIN NO se guarda en SharedPreferences: ese archivo es XML legible y
  // ademas se respaldaba en la nube. Aqui lo protege el keystore del sistema.
  static const String _secureVaultPassword = 'nfile_vault_pin';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Inicializa el servicio
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Guarda la contraseña para uso con biometría
  static Future<void> cacheVaultPassword(String password) async {
    _memoryPin = password;
    try {
      await _secureStorage.write(key: _secureVaultPassword, value: password);
    } catch (e) {
      debugPrint('[AppLock] No se pudo guardar el PIN de forma segura: $e');
    }
  }
  
  /// Obtiene la contraseña guardada
  static String? getCachedVaultPassword() {
    // La API de secure_storage es asincrona; se resuelve via cacheVaultPassword
    // y se lee de forma sincrona solo desde memoria en la sesion actual.
    return _memoryPin;
  }

  // Cache en memoria para la sesion actual (se pierde al cerrar la app).
  static String? _memoryPin;

  /// Carga el PIN del keystore a memoria (llamar tras init()).
  static Future<void> loadVaultPassword() async {
    try {
      _memoryPin = await _secureStorage.read(key: _secureVaultPassword);
    } catch (e) {
      debugPrint('[AppLock] No se pudo leer el PIN: $e');
    }
  }

  /// Elimina el PIN almacenado (al desactivar biometria o al bloquear).
  static Future<void> clearVaultPassword() async {
    _memoryPin = null;
    try {
      await _secureStorage.delete(key: _secureVaultPassword);
    } catch (e) {
      debugPrint('[AppLock] No se pudo borrar el PIN: $e');
    }
  }
  
  /// Verifica si la biometría está habilitada (solo para el baúl)
  static bool isBiometricEnabled() {
    return _prefs?.getBool(_keyBiometricEnabled) ?? false;
  }
  
  /// Habilita/deshabilita biometría
  static Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs?.setBool(_keyBiometricEnabled, enabled);
    if (!enabled) {
      await clearVaultPassword();
    }
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
    } on LocalAuthException catch (e) {
      // local_auth 3.x lanza LocalAuthException, no PlatformException.
      debugPrint('[AppLock] Biometric error: ${e.code}');
      return false;
    } on PlatformException catch (e) {
      debugPrint('[AppLock] Authentication error: $e');
      return false;
    } catch (e) {
      debugPrint('[AppLock] Unexpected auth error: $e');
      return false;
    }
  }
}
