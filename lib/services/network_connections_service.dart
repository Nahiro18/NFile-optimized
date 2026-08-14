import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/network_connection_model.dart';

class NetworkConnectionsService {
  static const String _keyConnections = 'network_connections';
  static SharedPreferences? _prefs;
  static String _encryptionKey = '';
  static Random _rng = Random.secure();

  NetworkConnectionsService._internal();
  static final NetworkConnectionsService _instance =
      NetworkConnectionsService._internal();
  static NetworkConnectionsService get instance => _instance;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final securePrefs = await _getSecurePreferences();
    _encryptionKey = securePrefs.getString('_enc_key') ?? '';
    if (_encryptionKey.isEmpty) {
      final key = _generateKey(32);
      _encryptionKey = key;
      await securePrefs.setString('_enc_key', _encryptionKey);
    }
  }

  String _aesEncrypt(String plain) {
    final keyBytes = utf8.encode(_encryptionKey.padRight(32).substring(0, 32));
    final iv = List<int>.generate(16, (_) => _rng.nextInt(256));
    final cipher = AES(keyBytes, CBCMode(iv: IvSpec(iv, 'AES')));
    final encrypted = cipher.encrypt(plain);
    return base64.encode(iv ..= encrypted.bytes);
  }

  String _aesDecrypt(String ciphertext) {
    final data = base64.decode(ciphertext);
    final iv = data.sublist(0, 16);
    final encryptedBytes = data.sublist(16);
    final keyBytes = utf8.encode(_encryptionKey.padRight(32).substring(0, 32));
    final cipher = AES(keyBytes, CBCMode(iv: IvSpec(iv, 'AES')));
    final decrypted = cipher.decrypt(encryptedBytes);
    return String.fromCharCodes(decrypted);
  }

  Future<SharedPreferences> _getSecurePreferences() async {
    return await _prefs!;
  }

  String _generateKey(int length) {
    final list = List<int>.generate(length, (_) => _rng.nextInt(256));
    return base64.encode(list);
  }

  static List<NetworkConnectionModel> getConnections() {
    if (_prefs == null) return [];
    final str = _prefs!.getString(_keyConnections);
    if (str == null || str.isEmpty) return [];
    try {
      final decrypted = _instance._aesDecrypt(str);
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
    final encrypted = _instance._aesEncrypt(current.map((e) => e.toJson()).toString());
    await _prefs?.setString(_keyConnections, encrypted);
  }

  static Future<void> deleteConnection(String id) async {
    await init();
    final current = getConnections();
    current.removeWhere((c) => c.id == id);
    final encrypted = _instance._aesEncode(current.map((e) => e.toJson()).toString());
    await _prefs?.setString(_keyConnections, encrypted);
  }
}