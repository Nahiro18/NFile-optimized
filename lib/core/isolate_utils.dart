import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class CopyFileParams {
  final String source;
  final String destination;
  
  CopyFileParams(this.source, this.destination);
}

class MoveFileParams {
  final String source;
  final String destination;
  
  MoveFileParams(this.source, this.destination);
}

/// Calcula el tamaño de un directorio en un isolate separado
Future<int> calculateDirectorySizeAsync(String path) async {
  return await compute(_calculateDirectorySizeIsolate, path);
}

int _calculateDirectorySizeIsolate(String path) {
  int totalSize = 0;
  
  try {
    final dir = Directory(path);
    if (dir.existsSync()) {
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          try {
            totalSize += entity.lengthSync();
          } catch (e) {
      debugPrint('Operation error: \$e');
    }
        }
      }
    }
  } catch (e) {
      debugPrint('Operation error: \$e');
    }
  
  return totalSize;
}

/// Copia archivos grandes o directorios en un isolate
Future<void> copyFileAsync(String source, String destination) async {
  await compute(_copyFileIsolate, CopyFileParams(source, destination));
}

void _copyFileIsolate(CopyFileParams params) {
  final sourceFile = File(params.source);
  final destFile = File(params.destination);
  
  final entityType = FileSystemEntity.typeSync(params.source);
  
  if (entityType == FileSystemEntityType.directory) {
    _copyDirectorySync(Directory(params.source), Directory(params.destination));
  } else if (entityType == FileSystemEntityType.file) {
    if (!sourceFile.existsSync()) return;
    destFile.parent.createSync(recursive: true);
    
    final sourceStream = sourceFile.openSync();
    final destStream = destFile.openSync(mode: FileMode.write);
    
    try {
      const bufferSize = 64 * 1024; // 64KB
      final buffer = List<int>.filled(bufferSize, 0);
      int bytesRead;
      while ((bytesRead = sourceStream.readIntoSync(buffer)) > 0) {
        destStream.writeFromSync(buffer, 0, bytesRead);
      }
    } finally {
      sourceStream.closeSync();
      destStream.closeSync();
    }
  }
}

void _copyDirectorySync(Directory source, Directory destination) {
  if (!destination.existsSync()) {
    destination.createSync(recursive: true);
  }
  for (final entity in source.listSync(recursive: false)) {
    final name = p.basename(entity.path);
    final newPath = p.join(destination.absolute.path, name);
    if (entity is Directory) {
      _copyDirectorySync(Directory(entity.absolute.path), Directory(newPath));
    } else if (entity is File) {
      entity.copySync(newPath);
    }
  }
}

/// Mueve archivos o directorios grandes en un isolate
Future<void> moveFileAsync(String source, String destination) async {
  await compute(_moveFileIsolate, MoveFileParams(source, destination));
}

void _moveFileIsolate(MoveFileParams params) {
  final sourceEntity = FileSystemEntity.typeSync(params.source);
  
  if (sourceEntity == FileSystemEntityType.notFound) return;

  try {
    if (sourceEntity == FileSystemEntityType.directory) {
      Directory(params.source).renameSync(params.destination);
    } else {
      File(params.source).renameSync(params.destination);
    }
    return;
  } catch (e) {
      // Error handled
    // Si falla rename (eg cruce de particiones), copiar y eliminar
  }
  
  // Fallback: Copy and Delete
  if (sourceEntity == FileSystemEntityType.directory) {
    _copyDirectorySync(Directory(params.source), Directory(params.destination));
    Directory(params.source).deleteSync(recursive: true);
  } else {
    File(params.destination).parent.createSync(recursive: true);
    File(params.source).copySync(params.destination);
    File(params.source).deleteSync();
  }
}

/// Elimina archivos/carpetas en un isolate
Future<void> deleteFileAsync(String path) async {
  await compute(_deleteFileIsolate, path);
}

void _deleteFileIsolate(String path) {
  final entity = FileSystemEntity.typeSync(path);
  
  if (entity == FileSystemEntityType.directory) {
    Directory(path).deleteSync(recursive: true);
  } else if (entity == FileSystemEntityType.file) {
    File(path).deleteSync();
  }
}
