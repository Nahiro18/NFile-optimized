import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nfile/services/vault_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VaultService', () {
    late Directory tempDir;
    late File testFile;
    const testPassword = 'TestPassword123!';

    setUp(() async {
      // Crear directorio temporal para tests
      tempDir = await Directory.systemTemp.createTemp('vault_test_');
      testFile = File('${tempDir.path}/test.txt');
      await testFile.writeAsString('Contenido secreto de prueba');
      
      // Mock path_provider para que devuelva el directorio temporal
      const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      });
    });

    tearDown(() async {
      // Limpiar después de cada test
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('isPasswordSet should return false initially', () async {
      final isSet = await VaultService.isPasswordSet();
      expect(isSet, false);
    });

    test('setPassword and verifyPassword should work correctly', () async {
      await VaultService.setPassword(testPassword);
      
      final isSet = await VaultService.isPasswordSet();
      expect(isSet, true);
      
      final isValid = await VaultService.verifyPassword(testPassword);
      expect(isValid, true);
      
      final isInvalid = await VaultService.verifyPassword('WrongPassword');
      expect(isInvalid, false);
    });

    test('lockFile should encrypt and delete original file', () async {
      await VaultService.setPassword(testPassword);
      
      final record = await VaultService.lockFile(
        file: testFile,
        password: testPassword,
        inPlace: false,
      );

      // Verificar que el archivo original fue eliminado
      expect(await testFile.exists(), false);
      
      // Verificar que el archivo cifrado existe
      expect(await File(record.scrambledPath).exists(), true);
      
      // Verificar que el contenido está cifrado (no es texto plano)
      final encryptedBytes = await File(record.scrambledPath).readAsBytes();
      final encryptedStr = String.fromCharCodes(encryptedBytes.take(100));
      expect(encryptedStr.contains('Contenido secreto'), false);
    });

    test('unlockFile should restore file correctly', () async {
      await VaultService.setPassword(testPassword);
      
      final originalContent = await testFile.readAsString();
      
      final record = await VaultService.lockFile(
        file: testFile,
        password: testPassword,
        inPlace: false,
      );

      final restoredFile = await VaultService.unlockFile(
        record: record,
        password: testPassword,
      );

      expect(await restoredFile.exists(), true);
      
      final restoredContent = await restoredFile.readAsString();
      expect(restoredContent, originalContent);
    });

    test('unlockFile should fail with wrong password', () async {
      await VaultService.setPassword(testPassword);
      
      final record = await VaultService.lockFile(
        file: testFile,
        password: testPassword,
        inPlace: false,
      );

      expect(
        () => VaultService.unlockFile(
          record: record,
          password: 'WrongPassword123',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('lockFile should handle empty file', () async {
      final emptyFile = File('${tempDir.path}/empty.txt');
      await emptyFile.create();
      
      await VaultService.setPassword(testPassword);
      
      final record = await VaultService.lockFile(
        file: emptyFile,
        password: testPassword,
        inPlace: false,
      );

      expect(record.size, 0);
      
      final restoredFile = await VaultService.unlockFile(
        record: record,
        password: testPassword,
      );
      
      expect(await restoredFile.exists(), true);
    });

    test('lockFile with inPlace should create hidden file', () async {
      await VaultService.setPassword(testPassword);
      
      final record = await VaultService.lockFile(
        file: testFile,
        password: testPassword,
        inPlace: true,
      );

      expect(record.scrambledPath, contains('.vault_'));
      expect(record.scrambledPath, endsWith('.nfv'));
    });
  });
}
