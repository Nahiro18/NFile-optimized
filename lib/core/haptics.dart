import 'package:flutter/services.dart';

/// Controlador centralizado de respuesta háptica
class NFileHaptics {
  /// Vibración ligera para acciones menores (ej. tocar un botón)
  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  /// Vibración media para acciones importantes (ej. agregar a selección)
  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  /// Vibración fuerte para errores o acciones destructivas (ej. eliminar)
  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  /// Vibración para confirmación de éxito
  static Future<void> success() async {
    await HapticFeedback.vibrate();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }

  /// Vibración para selección
  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }
}
