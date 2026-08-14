import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/network_connection_model.dart';

class NetworkConnectionsService {
  static const String _keyConnections = 'network_connections';
  static const String _keyEncryptionKey = '_enc_key';
  static SharedPreferences? _prefs;
  static String _encryptionKey = '';
  static final Random _rng = Random.secure();

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _encryptionKey = _prefs!.getString(_keyEncryptionKey) ?? '';
    if (_encryptionKey.isEmpty) {
      _encryptionKey = _generateKey(32);
      await _prefs!.setString(_keyEncryptionKey, _encryptionKey);
    }
  }

  static String _aesEncrypt(String plain) {
    final keyBytes = utf8.encode(_encryptionKey.padRight(32).substring(0, 32));
    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(plain, iv: iv);
    return base64.encode(iv.bytes + encrypted.bytes);
  }

  static String _aesDecrypt(String ciphertext) {
    final data = base64.decode(ciphertext);
    final ivBytes = data.sublist(0, 16);
    final encryptedBytes = data.sublist(16);
    final keyBytes = utf8.encode(_encryptionKey.padRight(32).substring(0, 32));
    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    final iv = encrypt.IV(Uint8List.fromList(ivBytes));
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final decrypted = encrypter.decrypt(encrypt.Encrypted(Uint8List.fromList(encryptedBytes)), iv: iv);
    return decrypted;
  }

  static String _generateKey(int length) {
    final list = List<int>.generate(length, (_) => _rng.nextInt(256));
    return base64.encode(list);
  }

  static List<NetworkConnectionModel> getConnections() {
    if (_prefs == null) return [];
    final str = _prefs!.getString(_keyConnections);
    if (str == null || str.isEmpty) return [];
    try {
      final decrypted = _aesDecrypt(str);
      final list = json.decode(decrypted) as List<dynamic>;
      return list
          .map((e) => NetworkConnectionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveConnection(NetworkConnectionModel conn) async {
    await init();
    final current = getConnections();
    final index = current.indexWhere((c) => c.id == conn.id);
    if (index >= 0) {
      current[index] = conn;
    } else {
      current.add(conn);
    }
    final jsonStr = json.encode(current.map((e) => e.toJson()).toList());
    final encrypted = _aesEncrypt(jsonStr);
    await _prefs?.setString(_keyConnections, encrypted);
  }

  static Future<void> deleteConnection(String id) async {
    await init();
    final current = getConnections();
    current.removeWhere((c) => c.id == id);
    final jsonStr = json.encode(current.map((e) => e.toJson()).toList());
    final encrypted = _aesEncrypt(jsonStr);
    await _prefs?.setString(_keyConnections, encrypted);
  }
}

