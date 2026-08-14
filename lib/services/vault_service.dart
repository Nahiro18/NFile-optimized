import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:argon2_ffi_base/argon2_ffi_base.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
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
  final String displayName; // Nombre genérico para mostrar en el explorador

  VaultFileRecord({
    required this.id,
    required this.originalName,
    required this.originalPath,
    required this.scrambledPath,
    required this.size,
    required this.lockedAt,
    required this.isInPlace,
    this.isFolder = false,
    String? displayName,
  }) : displayName = displayName ?? 'archivo_${id.substring(0, 8)}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'originalName': originalName,
    'originalPath': originalPath,
    'scrambledPath': scrambledPath,
    'size': size,
    'lockedAt': lockedAt,
    'isInPlace': isInPlace,
    'isFolder': isFolder,
    'displayName': displayName,
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
    displayName: json['displayName'] as String?,
  );
}

/// Servicio de bóveda segura con cifrado AES-256-GCM
class VaultService {
  static const String _magicTag = 'NFILE_VAULT_V2';
  static const int _scrambleSize = 8192; // 8 KB
  static const int _keyLength = 32; // 256 bits
  static const int _ivLength = 16; // 128 bits
  static const int _saltLength = 32; // 256 bits

  // ============ AUTO-LOCK ============
  static const Duration _autoLockTimeout = Duration(minutes: 5);
  static Timer? _autoLockTimer;
  static bool _isUnlocked = false;

  /// Registra actividad del usuario para resetear el timer de auto-lock
  static void recordActivity() {
    _resetAutoLockTimer();
  }

  static void _resetAutoLockTimer() {
    _autoLockTimer?.cancel();
    _autoLockTimer = Timer(_autoLockTimeout, () {
      lock();
    });
  }

  /// Bloquea la bóveda manualmente o por inactividad
  static void lock() {
    _isUnlocked = false;
    _autoLockTimer?.cancel();
    _autoLockTimer = null;
  }

  /// Verifica si la bóveda está desbloqueada
  static bool get isUnlocked => _isUnlocked;

  /// Marca la bóveda como desbloqueada (llamar después de verifyPassword exitoso)
  static void _markUnlocked() {
    _isUnlocked = true;
    recordActivity();
  }

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

    final isValid = _constantTimeEquals(storedHash, checkHash);

    // Defensa contra timing attacks: delay fijo si la contraseña es incorrecta
    // Un atacante no puede distinguir entre "contraseña incorrecta" y
    // "contraseña correcta midiendo el tiempo de respuesta"
    if (!isValid) {
      await Future.delayed(const Duration(milliseconds: 500));
      return false;
    }

    // Contraseña correcta: marcar como desbloqueado y resetear timer
    _markUnlocked();
    return true;
  }

  /// Autenticación biométrica (huella/rostro) como alternativa a la contraseña
  /// Retorna true si la biometría fue exitosa
  static Future<bool> authenticateWithBiometrics({
    String reason = 'Autentícate para acceder a la bóveda',
  }) async {
    try {
      final localAuth = LocalAuthentication();
      // Verificar que el dispositivo soporta biometría
      final isAvailable = await localAuth.isDeviceSupported() &&
          await localAuth.canCheckBiometrics;

      if (!isAvailable) {
        return false;
      }

      // Solicitar autenticación biométrica
      final authenticated = await localAuth.authenticate(
        localizedReason: reason,
      );

      if (authenticated) {
        _markUnlocked();
      }
      return authenticated;
    } catch (e) {
      return false;
    }
  }

  /// Verifica si el dispositivo tiene biometría disponible
  static Future<bool> isBiometricAvailable() async {
    try {
      final localAuth = LocalAuthentication();
      return await localAuth.isDeviceSupported() &&
          await localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
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

    // Generar salt e IV únicos para este archivo
    final salt = _generateSecureRandom(_saltLength);
    final iv = _generateSecureRandom(_ivLength);
    
    // Derivar clave de cifrado
    final key = _deriveEncryptionKey(password, salt);

    // Leer solo la firma (primeros 8KB o el tamaño del archivo si es menor) para evitar cargar todo en memoria
    final scrambleLen = min(_scrambleSize, size);
    final raf = await file.open(mode: FileMode.read);
    final scrambleBytes = await raf.read(scrambleLen);

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

    // Construir archivo final usando un Stream/Sink para no sobrecargar la RAM
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

    // Escribir el archivo cifrado destino en streaming
    final targetFile = File(scrambledPath);
    final sink = targetFile.openWrite();
    sink.add(headerBytes.toBytes());

    // Si el archivo es mayor a la firma, transferimos el resto en chunks de 64KB
    if (size > scrambleLen) {
      await raf.setPosition(scrambleLen);
      while (true) {
        final chunk = await raf.read(64 * 1024);
        if (chunk.isEmpty) break;
        sink.add(chunk);
      }
    }
    await sink.flush();
    await sink.close();
    await raf.close();

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

    final raf = await scrambledFile.open(mode: FileMode.read);
    
    try {
      final baseHeaderLen = _magicTag.length + _saltLength + _ivLength + 4;
      final baseHeader = await raf.read(baseHeaderLen);
      if (baseHeader.length < baseHeaderLen) {
        throw Exception('Invalid vault file format (Too short)');
      }

      // Verificar magic tag
      final magicBytes = baseHeader.sublist(0, _magicTag.length);
      final magic = utf8.decode(magicBytes);
      if (magic != _magicTag) {
        throw Exception('Invalid vault file format (Magic tag mismatch)');
      }

      final salt = baseHeader.sublist(_magicTag.length, _magicTag.length + _saltLength);
      final iv = baseHeader.sublist(_magicTag.length + _saltLength, _magicTag.length + _saltLength + _ivLength);

      // Obtener longitud de la metadata
      final metaLenStart = _magicTag.length + _saltLength + _ivLength;
      final metaLen = (baseHeader[metaLenStart] << 24) |
                      (baseHeader[metaLenStart + 1] << 16) |
                      (baseHeader[metaLenStart + 2] << 8) |
                      baseHeader[metaLenStart + 3];

      // Leer la metadata cifrada
      final encryptedMetadata = await raf.read(metaLen);
      if (encryptedMetadata.length < metaLen) {
        throw Exception('Invalid vault file format (Corrupted header)');
      }

      // Derivar clave
      final key = _deriveEncryptionKey(password, salt);

      // Descifrar metadata
      List<int> decryptedMetadataBytes;
      try {
        decryptedMetadataBytes = _decryptAESGCM(encryptedMetadata, key, iv);
      } catch (e) {
        throw Exception('Incorrect password or corrupted file');
      }

      final metadataStr = utf8.decode(decryptedMetadataBytes);
      final metadata = jsonDecode(metadataStr) as Map<String, dynamic>;

      final originalSize = metadata['size'] as int;
      final scrambleLen = min(_scrambleSize, originalSize);
      final encryptedScrambleLen = scrambleLen + 16;

      // Leer la firma cifrada
      final encryptedScramble = await raf.read(encryptedScrambleLen);
      if (encryptedScramble.length < encryptedScrambleLen) {
        throw Exception('Invalid vault file format (Corrupted payload)');
      }

      // Descifrar firma
      final decryptedScramble = _decryptAESGCM(encryptedScramble, key, iv);

      // Reconstruir archivo de destino
      final destinationDir = p.dirname(record.originalPath);
      final originalFile = File(record.originalPath);

      if (record.isFolder) {
        // Para carpetas, escribimos temporalmente el archivo zip descifrado y luego lo descomprimimos
        final cacheDir = await getTemporaryDirectory();
        final tempZipPath = p.join(cacheDir.path, 'temp_unlock_${record.id}.zip');
        final tempZipFile = File(tempZipPath);
        final sink = tempZipFile.openWrite();
        sink.add(decryptedScramble);
        
        while (true) {
          final chunk = await raf.read(64 * 1024);
          if (chunk.isEmpty) break;
          sink.add(chunk);
        }
        await sink.flush();
        await sink.close();

        // Descomprimir el ZIP en streaming para evitar OOM con carpetas grandes
        final inputBytes = await tempZipFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(inputBytes);
        for (final file in archive) {
          final filename = file.name;
          final fullPath = p.join(destinationDir, filename);
          if (file.isFile) {
            final outFile = File(fullPath);
            await outFile.parent.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          } else {
            await Directory(fullPath).create(recursive: true);
          }
        }
        await tempZipFile.delete();
      } else {
        // Para archivos normales, lo escribimos directamente en streaming al disco
        await originalFile.parent.create(recursive: true);
        final sink = originalFile.openWrite();
        sink.add(decryptedScramble);

        while (true) {
          final chunk = await raf.read(64 * 1024);
          if (chunk.isEmpty) break;
          sink.add(chunk);
        }
        await sink.flush();
        await sink.close();
      }

      // Limpiar archivo cifrado
      await scrambledFile.delete();

      // Actualizar registros
      final records = await loadRecords();
      records.removeWhere((e) => e.id == record.id);
      await saveRecords(records);

      return originalFile;
    } finally {
      await raf.close();
    }
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

    final raf = await scrambledFile.open(mode: FileMode.read);
    
    try {
      final baseHeaderLen = _magicTag.length + _saltLength + _ivLength + 4;
      final baseHeader = await raf.read(baseHeaderLen);
      if (baseHeader.length < baseHeaderLen) {
        throw Exception('Invalid vault file format (Too short)');
      }

      final magicBytes = baseHeader.sublist(0, _magicTag.length);
      final magic = utf8.decode(magicBytes);
      if (magic != _magicTag) {
        throw Exception('Invalid vault file format (Magic tag mismatch)');
      }

      final salt = baseHeader.sublist(_magicTag.length, _magicTag.length + _saltLength);
      final iv = baseHeader.sublist(_magicTag.length + _saltLength, _magicTag.length + _saltLength + _ivLength);

      final metaLenStart = _magicTag.length + _saltLength + _ivLength;
      final metaLen = (baseHeader[metaLenStart] << 24) |
                      (baseHeader[metaLenStart + 1] << 16) |
                      (baseHeader[metaLenStart + 2] << 8) |
                      baseHeader[metaLenStart + 3];

      final encryptedMetadata = await raf.read(metaLen);
      if (encryptedMetadata.length < metaLen) {
        throw Exception('Invalid vault file format (Corrupted header)');
      }

      final key = _deriveEncryptionKey(password, salt);

      List<int> decryptedMetadataBytes;
      try {
        decryptedMetadataBytes = _decryptAESGCM(encryptedMetadata, key, iv);
      } catch (e) {
        throw Exception('Incorrect password or corrupted file');
      }

      final metadataStr = utf8.decode(decryptedMetadataBytes);
      final metadata = jsonDecode(metadataStr) as Map<String, dynamic>;

      final originalSize = metadata['size'] as int;
      final scrambleLen = min(_scrambleSize, originalSize);
      final encryptedScrambleLen = scrambleLen + 16;

      final encryptedScramble = await raf.read(encryptedScrambleLen);
      if (encryptedScramble.length < encryptedScrambleLen) {
        throw Exception('Invalid vault file format (Corrupted payload)');
      }

      final decryptedScramble = _decryptAESGCM(encryptedScramble, key, iv);

      // Escribir en cache temporal usando un Stream/Sink
      final cacheDir = await getTemporaryDirectory();
      final extension = record.isFolder ? '.zip' : '';
      final tempFilePath = p.join(cacheDir.path, 'temp_vault_${record.id}_${record.originalName}$extension');
      final tempFile = File(tempFilePath);
      
      final sink = tempFile.openWrite();
      sink.add(decryptedScramble);

      while (true) {
        final chunk = await raf.read(64 * 1024);
        if (chunk.isEmpty) break;
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();

      return tempFile;
    } finally {
      await raf.close();
    }
  }

  // ============ MÉTODOS PRIVADOS DE CIFRADO ============

  /// Genera bytes aleatorios seguros
  static List<int> _generateSecureRandom(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  /// Deriva clave de cifrado usando Argon2id (estándar moderno)
  /// Mucho más resistente que PBKDF2 contra ataques con GPU/ASIC
  static List<int> _deriveEncryptionKey(String password, List<int> salt) {
    final passwordBytes = utf8.encode(password);
    // Argon2id: memory=64MB, iterations=3, parallelism=4, output=32 bytes
    // Configuración recomendada por OWASP para Argon2id
    // type=2 es Argon2id, version=0x13 es v1.3
    final argon2 = Argon2FfiFlutter();
    final result = argon2.argon2(Argon2Arguments(
      Uint8List.fromList(passwordBytes),
      Uint8List.fromList(salt),
      65536, // memory (KB) = 64MB
      3,     // iterations
      _keyLength,
      4,     // parallelism
      2,     // type: Argon2id
      0x13,  // version: 1.3
    ));
    return List<int>.from(result);
  }

  /// Hashea contraseña con Argon2id para almacenamiento
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

      }
    } catch (e) {
      // Silently ignore cleanup errors
    }
  }

  /// Solicita permisos especiales de Android para acceder a todos los archivos
  /// (Documents, etc.) en Android 11+. Retorna true si los permisos fueron
  /// otorgados.
  static Future<bool> requestAllFilesAccess() async {
    try {
      final result = await Permission.manageExternalStorage.request();
      return result.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// Verifica si la app tiene permiso de acceso total a archivos
  static Future<bool> hasAllFilesAccess() async {
    try {
      return await Permission.manageExternalStorage.isGranted;
    } catch (e) {
      return false;
    }
  }
}
