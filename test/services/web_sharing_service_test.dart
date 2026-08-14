import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfile/services/web_sharing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WebSharingService', () {
    test('auth token should be generated when starting local server', () async {
      // Initially null
      expect(WebSharingService.instance.authToken, isNull);

      // Create a temp directory to share
      final tempDir = await Directory.systemTemp.createTemp('web_share_test_');
      try {
        await WebSharingService.instance.startLocalServer(tempDir.path);

        // After starting, auth token should be set
        expect(WebSharingService.instance.authToken, isNotNull);
        expect(WebSharingService.instance.authToken!.length, greaterThan(10),
            reason: 'Token should be reasonably long');

        await WebSharingService.instance.stopLocalServer();
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('auth token should be cleared when stopping local server', () async {
      final tempDir = await Directory.systemTemp.createTemp('web_share_test_');
      try {
        await WebSharingService.instance.startLocalServer(tempDir.path);
        expect(WebSharingService.instance.authToken, isNotNull);

        await WebSharingService.instance.stopLocalServer();
        expect(WebSharingService.instance.authToken, isNull);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('isLocalActive should reflect server state', () async {
      final tempDir = await Directory.systemTemp.createTemp('web_share_test_');
      try {
        expect(WebSharingService.instance.isLocalActive, false);

        await WebSharingService.instance.startLocalServer(tempDir.path);
        expect(WebSharingService.instance.isLocalActive, true);

        await WebSharingService.instance.stopLocalServer();
        expect(WebSharingService.instance.isLocalActive, false);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('multiple auth tokens should be unique across server starts', () async {
      final tempDir = await Directory.systemTemp.createTemp('web_share_test_');
      try {
        await WebSharingService.instance.startLocalServer(tempDir.path);
        final firstToken = WebSharingService.instance.authToken;

        await WebSharingService.instance.stopLocalServer();
        await WebSharingService.instance.startLocalServer(tempDir.path);
        final secondToken = WebSharingService.instance.authToken;

        await WebSharingService.instance.stopLocalServer();

        expect(firstToken, isNotNull);
        expect(secondToken, isNotNull);
        expect(firstToken, isNot(equals(secondToken)),
            reason: 'Each session should have a unique token');
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('localServerUrl should include IP and port when active', () async {
      final tempDir = await Directory.systemTemp.createTemp('web_share_test_');
      try {
        await WebSharingService.instance.startLocalServer(tempDir.path);
        final url = WebSharingService.instance.localServerUrl;
        expect(url, isNotNull);
        expect(url, contains(':'));
        expect(url, startsWith('http://'));
        await WebSharingService.instance.stopLocalServer();
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
