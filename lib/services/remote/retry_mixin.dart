import 'dart:async';
import 'package:flutter/foundation.dart';

/// Mixin para agregar reintentos automáticos a clientes de red
mixin RetryMixin {
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  
  /// Ejecuta una operación con reintentos automáticos
  Future<T> withRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = _maxRetries,
    Duration delay = _retryDelay,
  }) async {
    int attempts = 0;
    
    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        
        if (attempts >= maxRetries) {
          throw Exception('Operation failed after $maxRetries attempts: $e');
        }
        
        debugPrint('[Retry] Attempt $attempts failed, retrying in ${delay.inSeconds}s...');
        await Future.delayed(delay);
        
        // Exponential backoff
        delay = Duration(seconds: delay.inSeconds * 2);
      }
    }
  }
}
