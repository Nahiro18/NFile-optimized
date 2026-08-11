import 'package:flutter/material.dart';

/// Proveedor para manejar configuraciones de accesibilidad centralizadas
class AccessibilityManager extends ChangeNotifier {
  static final AccessibilityManager instance = AccessibilityManager._internal();
  
  AccessibilityManager._internal();

  bool _highContrast = false;
  bool _largeText = false;
  bool _reduceMotion = false;

  bool get highContrast => _highContrast;
  bool get largeText => _largeText;
  bool get reduceMotion => _reduceMotion;

  void toggleHighContrast(bool value) {
    _highContrast = value;
    notifyListeners();
  }

  void toggleLargeText(bool value) {
    _largeText = value;
    notifyListeners();
  }
  
  void toggleReduceMotion(bool value) {
    _reduceMotion = value;
    notifyListeners();
  }

  /// Ajusta el tamaño de fuente en base a la configuración
  double getFontSize(double baseSize) {
    return _largeText ? baseSize * 1.25 : baseSize;
  }
  
  /// Devuelve la duración de una animación, o 0 si reduceMotion está activado
  Duration getAnimationDuration(Duration baseDuration) {
    return _reduceMotion ? Duration.zero : baseDuration;
  }
}

/// Widget envoltorio para mejorar la accesibilidad de elementos semánticos
class AccessibleSemantics extends StatelessWidget {
  final Widget child;
  final String label;
  final String? hint;
  final VoidCallback? onTap;
  
  const AccessibleSemantics({
    super.key,
    required this.child,
    required this.label,
    this.hint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      button: onTap != null,
      onTap: onTap,
      child: child,
    );
  }
}
