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
      } catch (_) {}
      try {
        await entity.delete(recursive: true);
      } catch (_) {}
    } else if (entity is File) {
      await _deleteFileSecurely(entity);
    }
  }

  /// Borra un archivo sobreescribiéndolo con bytes aleatorios y ceros
  /// Usa chunks de 64KB para no saturar la memoria RAM
  static Future<void> _deleteFileSecurely(File file) async {
    if (!await file.exists()) return;

    try {
      final length = await file.length();
      if (length > 0) {
        const chunkSize = 64 * 1024; // 64KB por chunk

        // Pase 1: Sobreescribir con datos aleatorios
        final randomFile = await file.open(mode: FileMode.write);
        int written = 0;
        while (written < length) {
          final remaining = length - written;
          final writeSize = remaining < chunkSize ? remaining : chunkSize;
          final chunk = List<int>.generate(writeSize, (_) => _random.nextInt(256));
          await randomFile.writeFrom(chunk);
          written += writeSize;
        }
        await randomFile.flush();
        await randomFile.close();

        // Pase 2: Sobreescribir con ceros
        final zeroFile = await file.open(mode: FileMode.write);
        final zeroChunk = List<int>.filled(chunkSize, 0);
        written = 0;
        while (written < length) {
          final remaining = length - written;
          final writeSize = remaining < chunkSize ? remaining : chunkSize;
          if (writeSize == chunkSize) {
            await zeroFile.writeFrom(zeroChunk);
          } else {
            await zeroFile.writeFrom(List<int>.filled(writeSize, 0));
          }
          written += writeSize;
        }
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
