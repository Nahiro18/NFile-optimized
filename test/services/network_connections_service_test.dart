import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nfile/services/network_connections_service.dart';
import 'package:nfile/models/network_connection_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await NetworkConnectionsService.init();
  });

  group('NetworkConnectionsService', () {
    test('init should generate and store encryption key', () async {
      // Reset
      SharedPreferences.setMockInitialValues({});
      await NetworkConnectionsService.init();

      // Verify the encryption key is stored
      final prefs = await SharedPreferences.getInstance();
      final storedKey = prefs.getString('_enc_key');
      expect(storedKey, isNotNull);
      expect(storedKey!.isNotEmpty, true);
    });

    test('init should reuse existing encryption key on subsequent calls', () async {
      SharedPreferences.setMockInitialValues({});
      await NetworkConnectionsService.init();
      final prefs = await SharedPreferences.getInstance();
      final firstKey = prefs.getString('_enc_key');

      // Re-init
      await NetworkConnectionsService.init();
      final secondKey = prefs.getString('_enc_key');

      expect(secondKey, equals(firstKey));
    });

    test('saveConnection should persist encrypted connection', () async {
      final conn = NetworkConnectionModel(
        id: 'test-id-1',
        name: 'Test FTP',
        type: 'ftp',
        host: 'ftp.example.com',
        port: 21,
        username: 'user1',
        password: 'secret123',
      );

      await NetworkConnectionsService.saveConnection(conn);

      final connections = NetworkConnectionsService.getConnections();
      expect(connections.length, 1);
      expect(connections[0].id, 'test-id-1');
      expect(connections[0].name, 'Test FTP');
      expect(connections[0].host, 'ftp.example.com');
      expect(connections[0].username, 'user1');
      expect(connections[0].password, 'secret123');
    });

    test('saveConnection should encrypt data in SharedPreferences (not plain text)',
        () async {
      final conn = NetworkConnectionModel(
        id: 'test-id-plain',
        name: 'PlainTextLeakTest',
        type: 'ftp',
        host: 'plain.example.com',
        port: 21,
        username: 'plaintext_user',
        password: 'plaintext_password_xyz',
      );

      await NetworkConnectionsService.saveConnection(conn);

      // Verify the raw SharedPreferences value does NOT contain plaintext
      final prefs = await SharedPreferences.getInstance();
      final rawValue = prefs.getString('network_connections');

      expect(rawValue, isNotNull);
      expect(rawValue!.contains('plaintext_password_xyz'), false,
          reason: 'Password should not be stored as plain text');
      expect(rawValue.contains('plain.example.com'), false,
          reason: 'Host should not be stored as plain text');
      expect(rawValue.contains('PlainTextLeakTest'), false,
          reason: 'Name should not be stored as plain text');
    });

    test('saveConnection should update existing connection with same id', () async {
      final conn = NetworkConnectionModel(
        id: 'update-id',
        name: 'Original Name',
        type: 'sftp',
        host: 'sftp.example.com',
        port: 22,
        username: 'user1',
        password: 'pass1',
      );

      await NetworkConnectionsService.saveConnection(conn);

      final updated = NetworkConnectionModel(
        id: 'update-id',
        name: 'Updated Name',
        type: 'sftp',
        host: 'sftp.example.com',
        port: 22,
        username: 'user2',
        password: 'pass2',
      );

      await NetworkConnectionsService.saveConnection(updated);

      final connections = NetworkConnectionsService.getConnections();
      expect(connections.length, 1, reason: 'Should not duplicate');
      expect(connections[0].name, 'Updated Name');
      expect(connections[0].username, 'user2');
      expect(connections[0].password, 'pass2');
    });

    test('deleteConnection should remove connection', () async {
      final conn = NetworkConnectionModel(
        id: 'delete-id',
        name: 'To Delete',
        type: 'webdav',
        host: 'webdav.example.com',
        port: 80,
        username: 'user',
        password: 'pass',
      );

      await NetworkConnectionsService.saveConnection(conn);
      expect(NetworkConnectionsService.getConnections().length, 1);

      await NetworkConnectionsService.deleteConnection('delete-id');
      expect(NetworkConnectionsService.getConnections().length, 0);
    });

    test('deleteConnection should not throw on non-existent id', () async {
      await NetworkConnectionsService.deleteConnection('non-existent-id');
      expect(NetworkConnectionsService.getConnections().length, 0);
    });

    test('getConnections should return empty list when nothing saved', () {
      final connections = NetworkConnectionsService.getConnections();
      expect(connections, isEmpty);
    });

    test('multiple connections should be persisted independently', () async {
      final conn1 = NetworkConnectionModel(
        id: 'multi-1',
        name: 'Connection 1',
        type: 'ftp',
        host: 'ftp1.example.com',
        port: 21,
        username: 'user1',
        password: 'pass1',
      );
      final conn2 = NetworkConnectionModel(
        id: 'multi-2',
        name: 'Connection 2',
        type: 'sftp',
        host: 'sftp2.example.com',
        port: 22,
        username: 'user2',
        password: 'pass2',
      );
      final conn3 = NetworkConnectionModel(
        id: 'multi-3',
        name: 'Connection 3',
        type: 'lan',
        host: '192.168.1.1',
        port: 445,
        username: 'user3',
        password: 'pass3',
      );

      await NetworkConnectionsService.saveConnection(conn1);
      await NetworkConnectionsService.saveConnection(conn2);
      await NetworkConnectionsService.saveConnection(conn3);

      final connections = NetworkConnectionsService.getConnections();
      expect(connections.length, 3);

      // Delete middle one
      await NetworkConnectionsService.deleteConnection('multi-2');

      final remaining = NetworkConnectionsService.getConnections();
      expect(remaining.length, 2);
      expect(remaining.any((c) => c.id == 'multi-1'), true);
      expect(remaining.any((c) => c.id == 'multi-3'), true);
      expect(remaining.any((c) => c.id == 'multi-2'), false);
    });
  });
}
