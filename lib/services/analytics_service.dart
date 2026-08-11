import 'package:flutter/foundation.dart';

/// Servicio de analíticas (Mock para entorno de desarrollo)
class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._internal();

  AnalyticsService._internal();
  
  bool _isEnabled = true;
  
  /// Habilitar o deshabilitar seguimiento
  void setAnalyticsEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('[Analytics] Tracking enabled: $_isEnabled');
  }

  /// Registra un evento de la aplicación
  void logEvent(String name, {Map<String, dynamic>? parameters}) {
    if (!_isEnabled) return;
    
    debugPrint('[Analytics] Event: $name | Params: $parameters');
    // TODO: Implementar integración real con Firebase/Sentry
  }
  
  /// Registra una vista de pantalla
  void logScreenView(String screenName) {
    if (!_isEnabled) return;
    
    debugPrint('[Analytics] Screen View: $screenName');
    // TODO: Implementar
  }

  /// Registra un error no fatal
  void logError(String message, dynamic error, StackTrace stackTrace) {
    if (!_isEnabled) return;
    
    debugPrint('[Analytics] Error: $message | Details: $error');
    // TODO: Implementar Crashlytics
  }
}
