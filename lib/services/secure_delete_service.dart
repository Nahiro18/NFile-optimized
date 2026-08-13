import 'dart:io';
import 'dart:math';

class SecureDeleteService {
  static final Random _random = Random.secure();

  /// Borra un archivo o directorio de forma segura.
  /// Si es un directorio, sobreescribe recursivamente todos los archivos internos antes de eliminarlo.
  static Future<void> deleteSecurely(FileSystemEntity entity) async {
    if (!await entity.exists()) return;

    if (entity is Directory) {
      try {
        final list = entity.listSync(recursive: true);
        for (final child in list) {
          if (child is File) {
            await _deleteFileSecurely(child);
          }
        }
      } catch (e) {
      debugPrint('Operation error: \$e');
    }
      try {
        await entity.delete(recursive: true);
      } catch (e) {
      debugPrint('Operation error: \$e');
    }
    } else if (entity is File) {
      await _deleteFileSecurely(entity);
    }
  }

  /// Borra un archivo sobreescribiéndolo con bytes aleatorios y ceros
  static Future<void> _deleteFileSecurely(File file) async {
    if (!await file.exists()) return;

    try {
      final length = await file.length();
      if (length > 0) {
        // Pase 1: Sobreescribir con datos aleatorios
        final randomFile = await file.open(mode: FileMode.write);
        final randomBytes = List<int>.generate(length, (i) => _random.nextInt(256));
        await randomFile.writeFrom(randomBytes);
        await randomFile.flush();
        await randomFile.close();

        // Pase 2: Sobreescribir con ceros
        final zeroFile = await file.open(mode: FileMode.write);
        final zeroBytes = List<int>.filled(length, 0);
        await zeroFile.writeFrom(zeroBytes);
        await zeroFile.flush();
        await zeroFile.close();
      }
    } catch (e) {
      // Si falla la sobreescritura, al menos intentamos eliminarlo normalmente
    } finally {
      // Eliminar el archivo del sistema
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
