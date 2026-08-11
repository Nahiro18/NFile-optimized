import 'package:flutter/material.dart';

/// Controlador centralizado de animaciones
class NFileAnimations {
  /// Duraciones estándar
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  
  /// Curvas de animación personalizadas
  static const Curve easeOutBack = Cubic(0.34, 1.56, 0.64, 1);
  static const Curve easeInOutCubic = Cubic(0.65, 0, 0.35, 1);
  static const Curve bouncy = ElasticOutCurve(0.8);
  
  /// Utilidad para transiciones de página fluidas
  static Route createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: easeOutBack));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      transitionDuration: normal,
    );
  }
}
