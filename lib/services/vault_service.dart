import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'secure_delete_service.dart';

/// Registro de archivo en la bóveda
class VaultFileRecord {
  final String id;
  final String originalName;
  final String originalPath;
  final String scrambledPath;
  final int size;
  final String lockedAt;
  final bool isInPlace;
  final bool isFolder;

  VaultFileRecord({
    required this.id,
    required this.originalName,
    required this.originalPath,
    required this.scrambledPath,
    required this.size,
    required this.lockedAt,
    required this.isInPlace,
    this.isFolder = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'originalName': originalName,
    'originalPath': originalPath,
    'scrambledPath': scrambledPath,
    'size': size,
    'lockedAt': lockedAt,
    'isInPlace': isInPlace,
    'isFolder': isFolder,
  };

  factory VaultFileRecord.fromJson(Map<String, dynamic> json) => VaultFileRecord(
    id: json['id'] as String,
    originalName: json['originalName'] as String,
    originalPath: json['originalPath'] as String,
    scrambledPath: json['scrambledPath'] as String,
    size: json['size'] as int,
    lockedAt: json['lockedAt'] as String,
    isInPlace: json['isInPlace'] as bool,
    isFolder: json['isFolder'] as bool? ?? false,
  );
}

/// Servicio de bóveda segura con cifrado AES-256-GCM
class VaultService {
  static const String _magicTag = 'NFILE_VAULT_V2';
  static const int _scrambleSize = 8192; // 8 KB
  static const int _keyLength = 32; // 256 bits
  static const int _ivLength = 16; // 128 bits
  static const int _saltLength = 32; // 256 bits
  static const int _pbkdf2Iterations = 100000;

  /// Verifica si hay una contraseña configurada
  static Future<bool> isPasswordSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('vault_password_hash');
  }

  /// Configura una nueva contraseña para la bóveda
  static Future<void> setPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Generar salt aleatorio de 32 bytes
    final salt = _generateSecureRandom(_saltLength);
    
    // Derivar hash con PBKDF2 (100,000 iteraciones)
    final hash = _hashPasswordWithPBKDF2(password, salt);
    
    await prefs.setString('vault_salt', base64.encode(salt));
    await prefs.setString('vault_password_hash', base64.encode(hash));
    
    debugPrint('[VaultService] Password set successfully');
  }

  /// Verifica si la contraseña proporcionada es correcta
  static Future<bool> verifyPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final saltBase64 = prefs.getString('vault_salt');
    final hashBase64 = prefs.getString('vault_password_hash');
    
    if (saltBase64 == null || hashBase64 == null) return false;
    
    final salt = base64.decode(saltBase64);
    final storedHash = base64.decode(hashBase64);
    
    final checkHash = _hashPasswordWithPBKDF2(password, salt);
    
    // Comparación constante en tiempo para evitar timing attacks
    return _constantTimeEquals(storedHash, checkHash);
  }

  /// Obtiene el directorio de la bóveda
  static Future<Directory> getVaultDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(p.join(docDir.path, 'vault'));
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }

  /// Obtiene el archivo de metadatos
  static Future<File> getMetadataFile() async {
    final vaultDir = await getVaultDir();
    return File(p.join(vaultDir.path, 'metadata.json'));
  }

  /// Carga todos los registros de archivos cifrados
  static Future<List<VaultFileRecord>> loadRecords() async {
    final file = await getMetadataFile();
    if (!await file.exists()) return [];
    
    try {
      final str = await file.readAsString();
      final list = jsonDecode(str) as List;
      return list.map((e) => VaultFileRecord.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[VaultService] Error loading records: $e');
      return [];
    }
  }

  /// Guarda los registros de archivos cifrados
  static Future<void> saveRecords(List<VaultFileRecord> records) async {
    final file = await getMetadataFile();
    final str = jsonEncode(records.map((e) => e.toJson()).toList());
    await file.writeAsString(str, flush: true);
  }

  /// Bloquea y cifra un archivo o carpeta
  static Future<VaultFileRecord> lockFile({
    required File file,
    required String password,
    required bool inPlace,
    String? customName,
    String? customPath,
    bool isFolder = false,
  }) async {
    if (!await file.exists()) {
      throw Exception('File does not exist: ${file.path}');
    }

    final originalPath = customPath ?? file.path;
    final originalName = customName ?? p.basename(originalPath);
    final size = await file.length();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // Determinar ruta de destino
    String scrambledPath;
    if (inPlace) {
      final dir = isFolder ? originalPath : p.dirname(originalPath);
      scrambledPath = p.join(dir, '.vault_$timestamp.nfv');
    } else {
      final vaultDir = await getVaultDir();
      scrambledPath = p.join(vaultDir.path, 'vault_$timestamp.nfv');
    }

    // Leer bytes del archivo
    final fileBytes = await file.readAsBytes();

    // Generar salt e IV únicos para este archivo
    final salt = _generateSecureRandom(_saltLength);
    final iv = _generateSecureRandom(_ivLength);
    
    // Derivar clave de cifrado
    final key = _deriveEncryptionKey(password, salt);

    // Dividir archivo: primeros 8KB (firma) + resto
    final scrambleLen = min(_scrambleSize, fileBytes.length);
    final scrambleBytes = fileBytes.sublist(0, scrambleLen);
    final restBytes = fileBytes.sublist(scrambleLen);

    // Cifrar la firma con AES-256-GCM
    final encryptedScramble = _encryptAESGCM(scrambleBytes, key, iv);

    // Preparar metadata
    final metadata = {
      'name': originalName,
      'path': originalPath,
      'size': size,
      'timestamp': timestamp,
      'isFolder': isFolder,
    };
    final metadataBytes = utf8.encode(jsonEncode(metadata));
    
    // Cifrar metadata
    final encryptedMetadata = _encryptAESGCM(metadataBytes, key, iv);

    // Construir archivo final:
    // [MAGIC_TAG][SALT][IV][METADATA_LEN][ENCRYPTED_METADATA][ENCRYPTED_SCRAMBLE][REST]
    final headerBytes = BytesBuilder();
    headerBytes.add(utf8.encode(_magicTag)); // 14 bytes
    headerBytes.add(salt); // 32 bytes
    headerBytes.add(iv); // 16 bytes

    // Metadata length (4 bytes big-endian)
    final metaLen = encryptedMetadata.length;
    headerBytes.add([
      (metaLen >> 24) & 0xFF,
      (metaLen >> 16) & 0xFF,
      (metaLen >> 8) & 0xFF,
      metaLen & 0xFF,
    ]);

    headerBytes.add(encryptedMetadata);
    headerBytes.add(encryptedScramble);
    headerBytes.add(restBytes);

    // Escribir archivo cifrado
    final targetFile = File(scrambledPath);
    await targetFile.writeAsBytes(headerBytes.toBytes(), flush: true);

    // Eliminar archivo original de forma segura
    await SecureDeleteService.deleteSecurely(file);

    // Crear registro
    final record = VaultFileRecord(
      id: timestamp,
      originalName: originalName,
      originalPath: originalPath,
      scrambledPath: scrambledPath,
      size: size,
      lockedAt: DateTime.now().toIso8601String(),
      isInPlace: inPlace,
      isFolder: isFolder,
    );

    // Guardar registro
    final records = await loadRecords();
    records.add(record);
    await saveRecords(records);

    debugPrint('[VaultService] File encrypted: ${record.originalName}');
    return record;
  }

  /// Desbloquea y descifra un archivo
  static Future<File> unlockFile({
    required VaultFileRecord record,
    required String password,
  }) async {
    final scrambledFile = File(record.scrambledPath);
    if (!await scrambledFile.exists()) {
      throw Exception('Scrambled vault file not found: ${record.scrambledPath}');
    }

    final bytes = await scrambledFile.readAsBytes();

    // Verificar magic tag
    if (bytes.length < _magicTag.length + _saltLength + _ivLength + 4) {
      throw Exception('Invalid vault file format (Too short)');
    }

    final magicBytes = bytes.sublist(0, _magicTag.length);
    final magic = utf8.decode(magicBytes);
    if (magic != _magicTag) {
      throw Exception('Invalid vault file format (Magic tag mismatch)');
    }

    // Extraer salt e IV
    final saltStart = _magicTag.length;
    final ivStart = saltStart + _saltLength;
    final metaLenStart = ivStart + _ivLength;

    final salt = bytes.sublist(saltStart, ivStart);
    final iv = bytes.sublist(ivStart, metaLenStart);

    // Extraer longitud de metadata
    final metaLen = (bytes[metaLenStart] << 24) |
                    (bytes[metaLenStart + 1] << 16) |
                    (bytes[metaLenStart + 2] << 8) |
                    bytes[metaLenStart + 3];

    final metaStart = metaLenStart + 4;
    final metaEnd = metaStart + metaLen;

    if (bytes.length < metaEnd) {
      throw Exception('Invalid vault file format (Corrupted header)');
    }

    // Derivar clave de descifrado
    final key = _deriveEncryptionKey(password, salt);

    // Descifrar metadata
    final encryptedMetadata = bytes.sublist(metaStart, metaEnd);
    List<int> decryptedMetadataBytes;
    try {
      decryptedMetadataBytes = _decryptAESGCM(encryptedMetadata, key, iv);
    } catch (e) {
      throw Exception('Incorrect password or corrupted file');
    }

    final metadataStr = utf8.decode(decryptedMetadataBytes);
    final metadata = jsonDecode(metadataStr) as Map<String, dynamic>;

    // Extraer bytes cifrados de la firma
    final originalSize = metadata['size'] as int;
    final scrambleLen = min(_scrambleSize, originalSize);
    final encryptedScrambleLen = scrambleLen + 16; // AES-GCM SIEMPRE añade un MAC de 16 bytes, incluso si está vacío
    final fileDataStart = metaEnd;

    if (bytes.length < fileDataStart + encryptedScrambleLen) {
      throw Exception('Invalid vault file format (Corrupted payload)');
    }

    // Descifrar firma
    final encryptedScramble = bytes.sublist(fileDataStart, fileDataStart + encryptedScrambleLen);
    final decryptedScramble = _decryptAESGCM(encryptedScramble, key, iv);
    
    final restBytes = bytes.sublist(fileDataStart + encryptedScrambleLen);

    // Reconstruir archivo original
    final originalBytes = BytesBuilder();
    originalBytes.add(decryptedScramble);
    originalBytes.add(restBytes);

    final originalFile = File(record.originalPath);

    if (record.isFolder) {
      // Reconstruir estructura de carpeta
      final archive = ZipDecoder().decodeBytes(originalBytes.toBytes());
      final destinationDir = p.dirname(record.originalPath);

      for (final file in archive) {
        final filename = file.name;
        final fullPath = p.join(destinationDir, filename);

        if (file.isFile) {
          final data = file.content as List<int>;
          final destFile = File(fullPath);
          await destFile.parent.create(recursive: true);
          await destFile.writeAsBytes(data, flush: true);
        } else {
          await Directory(fullPath).create(recursive: true);
        }
      }
    } else {
      // Recrear carpeta padre si fue eliminada
      final originalDir = originalFile.parent;
      if (!await originalDir.exists()) {
        await originalDir.create(recursive: true);
      }

      await originalFile.writeAsBytes(originalBytes.toBytes(), flush: true);
    }

    // Limpiar archivo cifrado
    await scrambledFile.delete();

    // Actualizar registros
    final records = await loadRecords();
    records.removeWhere((e) => e.id == record.id);
    await saveRecords(records);

    debugPrint('[VaultService] File decrypted: ${record.originalName}');
    return originalFile;
  }

  /// Bloquea una carpeta completa comprimiéndola primero
  static Future<VaultFileRecord> lockDirectory({
    required Directory directory,
    required String password,
    required bool inPlace,
  }) async {
    if (!await directory.exists()) {
      throw Exception('Directory does not exist: ${directory.path}');
    }

    final originalPath = directory.path;
    final originalName = p.basename(originalPath);

    // Listar todos los archivos recursivamente
    final list = directory.listSync(recursive: true);
    final archive = Archive();

    for (final entity in list) {
      if (entity is File) {
        final relPath = p.relative(entity.path, from: p.dirname(originalPath)).replaceAll('\\', '/');
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
      }
    }

    // Codificar como ZIP
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    if (zipBytes == null) {
      throw Exception('Failed to zip directory contents');
    }

    // Escribir ZIP temporal
    final tempDir = await getTemporaryDirectory();
    final tempZipFile = File(p.join(tempDir.path, 'temp_vault_zip_${DateTime.now().millisecondsSinceEpoch}.zip'));
    await tempZipFile.writeAsBytes(zipBytes, flush: true);

    try {
      // Cifrar el ZIP
      final record = await lockFile(
        file: tempZipFile,
        password: password,
        inPlace: inPlace,
        customName: originalName,
        customPath: originalPath,
        isFolder: true,
      );

      // Limpiar carpeta original de forma segura
      if (inPlace) {
        final children = directory.listSync();
        for (final child in children) {
          if (child.path != record.scrambledPath) {
            await SecureDeleteService.deleteSecurely(child);
          }
        }
      } else {
        await SecureDeleteService.deleteSecurely(directory);
      }

      return record;
    } finally {
      if (await tempZipFile.exists()) {
        await tempZipFile.delete();
      }
    }
  }

  /// Descifra temporalmente un archivo para visualización
  static Future<File> decryptTemporary({
    required VaultFileRecord record,
    required String password,
  }) async {
    final scrambledFile = File(record.scrambledPath);
    if (!await scrambledFile.exists()) {
      throw Exception('Scrambled vault file not found');
    }

    final bytes = await scrambledFile.readAsBytes();

    // Extraer componentes
    final saltStart = _magicTag.length;
    final ivStart = saltStart + _saltLength;
    final metaLenStart = ivStart + _ivLength;

    final salt = bytes.sublist(saltStart, ivStart);
    final iv = bytes.sublist(ivStart, metaLenStart);

    final metaLen = (bytes[metaLenStart] << 24) |
                    (bytes[metaLenStart + 1] << 16) |
                    (bytes[metaLenStart + 2] << 8) |
                    bytes[metaLenStart + 3];

    final metaStart = metaLenStart + 4;
    final metaEnd = metaStart + metaLen;

    final key = _deriveEncryptionKey(password, salt);

    // Descifrar metadata
    final encryptedMetadata = bytes.sublist(metaStart, metaEnd);
    final decryptedMetadataBytes = _decryptAESGCM(encryptedMetadata, key, iv);
    final decryptedMetadataStr = utf8.decode(decryptedMetadataBytes);
    final metadata = jsonDecode(decryptedMetadataStr) as Map<String, dynamic>;

    final originalSize = metadata['size'] as int;
    final scrambleLen = min(_scrambleSize, originalSize);
    final encryptedScrambleLen = scrambleLen + 16; // AES-GCM adds a 16-byte MAC tag
    final fileDataStart = metaEnd;

    final encryptedScramble = bytes.sublist(fileDataStart, fileDataStart + encryptedScrambleLen);
    final decryptedScramble = _decryptAESGCM(encryptedScramble, key, iv);
    final restBytes = bytes.sublist(fileDataStart + encryptedScrambleLen);

    final originalBytes = BytesBuilder();
    originalBytes.add(decryptedScramble);
    originalBytes.add(restBytes);

    // Escribir en cache temporal
    final cacheDir = await getTemporaryDirectory();
    final extension = record.isFolder ? '.zip' : '';
    final tempFilePath = p.join(cacheDir.path, 'temp_vault_${record.id}_${record.originalName}$extension');
    final tempFile = File(tempFilePath);
    await tempFile.writeAsBytes(originalBytes.toBytes(), flush: true);

    return tempFile;
  }

  // ============ MÉTODOS PRIVADOS DE CIFRADO ============

  /// Genera bytes aleatorios seguros
  static List<int> _generateSecureRandom(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  /// Deriva clave de cifrado usando PBKDF2
  static List<int> _deriveEncryptionKey(String password, List<int> salt) {
    final passwordBytes = utf8.encode(password);
    
    final hmac = Hmac(sha256, salt);
    var block = List<int>.from(passwordBytes);
    var result = List<int>.filled(_keyLength, 0);
    
    for (int i = 0; i < _pbkdf2Iterations; i++) {
      block = hmac.convert(block).bytes;
      for (int j = 0; j < _keyLength; j++) {
        result[j] ^= block[j];
      }
    }
    
    return result;
  }

  /// Hashea contraseña con PBKDF2 para almacenamiento
  static List<int> _hashPasswordWithPBKDF2(String password, List<int> salt) {
    return _deriveEncryptionKey(password, salt);
  }

  /// Cifra datos con AES-256-GCM
  static List<int> _encryptAESGCM(List<int> data, List<int> key, List<int> iv) {
    final keyObj = encrypt.Key(Uint8List.fromList(key));
    final ivObj = encrypt.IV(Uint8List.fromList(iv));
    final encrypter = encrypt.Encrypter(encrypt.AES(keyObj, mode: encrypt.AESMode.gcm));
    
    final encrypted = encrypter.encryptBytes(data, iv: ivObj);
    return encrypted.bytes;
  }

  /// Descifra datos con AES-256-GCM
  static List<int> _decryptAESGCM(List<int> encryptedData, List<int> key, List<int> iv) {
    final keyObj = encrypt.Key(Uint8List.fromList(key));
    final ivObj = encrypt.IV(Uint8List.fromList(iv));
    final encrypter = encrypt.Encrypter(encrypt.AES(keyObj, mode: encrypt.AESMode.gcm));
    
    final encrypted = encrypt.Encrypted(Uint8List.fromList(encryptedData));
    final decrypted = encrypter.decryptBytes(encrypted, iv: ivObj);
    return decrypted;
  }

  /// Comparación constante en tiempo para evitar timing attacks
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  /// Limpia los archivos desencriptados temporales del caché para mayor seguridad
  static Future<void> clearDecryptedTempFiles() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(recursive: false)) {
          if (entity is File) {
            final name = p.basename(entity.path);
            if (name.startsWith('temp_vault_')) {
              try {
                // Sobreescribir con ceros antes de borrar
                final len = entity.lengthSync();
                if (len > 0) {
                  final randomBytes = List<int>.generate(len, (_) => Random.secure().nextInt(256));
                  await entity.writeAsBytes(randomBytes, flush: true);
                  final zeroBytes = List<int>.filled(len, 0);
                  await entity.writeAsBytes(zeroBytes, flush: true);
                }
              } catch (_) {}
              await entity.delete();
            }
          }
        }
        debugPrint('[VaultService] Temporary decrypted files cleared successfully');
      }
    } catch (e) {
      debugPrint('[VaultService] Error clearing temp files: $e');
    }
  }
}
