import 'package:event_bus/event_bus.dart';

/// Singleton global para el bus de eventos de la aplicación.
class AppEventBus {
  static final EventBus _eventBus = EventBus();

  static EventBus get instance => _eventBus;
}

// --- Definición de Eventos ---

/// Evento lanzado cuando una operación de archivo asíncrona es exitosa (Copia, Movimiento, Eliminación)
class FileOperationSuccessEvent {
  final String operationType; // 'copy', 'move', 'delete', 'rename', etc.
  final String message;

  FileOperationSuccessEvent({required this.operationType, required this.message});
}

/// Evento lanzado cuando ocurre un error en una operación asíncrona
class FileOperationErrorEvent {
  final String operationType;
  final String errorMessage;

  FileOperationErrorEvent({required this.operationType, required this.errorMessage});
}

/// Evento lanzado cuando se seleccionan o deseleccionan elementos masivamente
class FileSelectionChangedEvent {
  final int selectionCount;

  FileSelectionChangedEvent({required this.selectionCount});
}

/// Evento lanzado cuando se finaliza de escanear un directorio o cambiar de ruta
class DirectoryLoadEvent {
  final String path;
  final bool isSuccessful;

  DirectoryLoadEvent({required this.path, this.isSuccessful = true});
}
