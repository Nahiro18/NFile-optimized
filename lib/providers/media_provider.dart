import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:device_info_plus/device_info_plus.dart';
import '../services/preferences_service.dart';
import '../models/custom_shortcut_model.dart';
import '../models/file_item_model.dart';

enum MediaSortOrder {
  newest,
  oldest,
  dateWise,
  newestGrouped,
  oldestGrouped,
  sizeLargest,
  sizeSmallest,
}

/// Cache LRU para thumbnails con límite de tamaño
class ThumbnailCache {
  static final LinkedHashMap<String, Uint8List?> _cache = LinkedHashMap<String, Uint8List?>();
  static final Map<String, Future<Uint8List?>> _pending = {};
  static String? _cacheDir;
  static int _currentCacheSizeBytes = 0; // Cumulative in-memory cache size in bytes
  
  static const int MAX_CACHE_SIZE = 100; // Max 100 thumbnails in memory
  static const int MAX_CACHE_SIZE_BYTES = 50 * 1024 * 1024; // Max 50MB in memory
  
  static Future<void> init() async {
    if (_cacheDir != null) return;

    try {
      final dir = await getTemporaryDirectory();
      final folder = Directory('${dir.path}/nfile_thumbnails');

      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      _cacheDir = folder.path;
      debugPrint('[ThumbnailCache] Initialized at: $_cacheDir');
    } catch (e) {
      debugPrint('[ThumbnailCache] Init error: $e');
    }
  }

  /// Evicts the oldest items if the cache exceeds count or size limits (LRU)
  static void _evictIfNeeded() {
    while (_cache.isNotEmpty && (_cache.length > MAX_CACHE_SIZE || _currentCacheSizeBytes > MAX_CACHE_SIZE_BYTES)) {
      final oldestKey = _cache.keys.first;
      final oldestVal = _cache.remove(oldestKey);
      if (oldestVal != null) {
        _currentCacheSizeBytes -= oldestVal.length;
      }
      debugPrint('[ThumbnailCache] Evicted (LRU): $oldestKey, remaining memory size: ${(_currentCacheSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
    }
  }

  /// Gets a thumbnail from the cache, promotes it if found, or generates it
  static Future<Uint8List?> get(AssetEntity asset) async {
    final key = asset.id;

    // In-memory cache hit (LRU: Promote key to end by removing and re-inserting)
    if (_cache.containsKey(key) && _cache[key] != null) {
      final value = _cache.remove(key);
      _cache[key] = value;
      return value;
    }

    // Check if there is already a pending load request
    if (_pending.containsKey(key)) {
      return _pending[key];
    }

    final completer = Completer<Uint8List?>();
    _pending[key] = completer.future;

    try {
      await init();

      // Try loading from disk cache
      if (_cacheDir != null) {
        final sanitizedKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final file = File('$_cacheDir/$sanitizedKey.thumb');

        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            _cache[key] = bytes;
            _currentCacheSizeBytes += bytes.length;
            _evictIfNeeded();
            _pending.remove(key);
            completer.complete(bytes);
            return bytes;
          }
        }
      }

      // Generate new thumbnail
      final data = await asset.thumbnailDataWithSize(const ThumbnailSize.square(300));

      if (data != null && data.isNotEmpty) {
        _cache[key] = data;
        _currentCacheSizeBytes += data.length;
        _evictIfNeeded();

        // Save to disk cache asynchronously
        if (_cacheDir != null) {
          final sanitizedKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
          final file = File('$_cacheDir/$sanitizedKey.thumb');
          await file.writeAsBytes(data, flush: true);
        }
      }

      _pending.remove(key);
      completer.complete(data);
      return data;
    } catch (e) {
      debugPrint('[ThumbnailCache] Error getting thumbnail: $e');
      _pending.remove(key);
      completer.complete(null);
      return null;
    }
  }

  /// Get from memory cache and promote if hit
  static Uint8List? getCached(String id) {
    if (_cache.containsKey(id) && _cache[id] != null) {
      final value = _cache.remove(id);
      _cache[id] = value;
      return value;
    }
    return null;
  }

  static bool hasCached(String id) => _cache.containsKey(id) && _cache[id] != null;

  static void clear() {
    _cache.clear();
    _pending.clear();
    _currentCacheSizeBytes = 0;
    if (_cacheDir != null) {
      try {
        Directory(_cacheDir!).deleteSync(recursive: true);
        debugPrint('[ThumbnailCache] Cleared all thumbnails');
      } catch (e) {
        debugPrint('[ThumbnailCache] Error clearing: $e');
      }
    }
  }
}

class MediaProvider extends ChangeNotifier {
  static const int _cacheVersion = 3;

  static final List<String> _inMemoryLogs = [];
  static List<String> get inMemoryLogs => _inMemoryLogs;

  static void clearInMemoryLogs() {
    _inMemoryLogs.clear();
  }

  static Future<void> writeLog(String message) async {
    debugPrint('[NFileLog] $message');
    try {
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      _inMemoryLogs.add('[$timestamp] $message');
      if (_inMemoryLogs.length > 500) {
        _inMemoryLogs.removeAt(0);
      }
    } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
  }

  MediaProvider() {
    final savedOrder = PreferencesService.getCategoryOrder();
    if (savedOrder != null && savedOrder.isNotEmpty) {
      _categoryOrder = savedOrder;
      bool orderUpdated = false;
      if (!_categoryOrder.contains('Apps')) {
        _categoryOrder.add('Apps');
        orderUpdated = true;
      }
      if (!_categoryOrder.contains('Recycle Bin')) {
        _categoryOrder.add('Recycle Bin');
        orderUpdated = true;
      }
      if (!_categoryOrder.contains('Settings')) {
        _categoryOrder.add('Settings');
        orderUpdated = true;
      }
      if (orderUpdated) {
        PreferencesService.saveCategoryOrder(_categoryOrder);
      }
    }
    final savedActive = PreferencesService.getActiveCategories();
    if (savedActive != null && savedActive.isNotEmpty) {
      _activeCategories = savedActive;
    }
    final savedCustom = PreferencesService.getCustomShortcuts();
    if (savedCustom != null) {
      _customShortcuts = savedCustom;
    }
    _customCategoryPaths = PreferencesService.getCustomCategoryPaths();
    _excludedDefaultPaths = PreferencesService.getExcludedDefaultPaths();
  }

  void reloadPreferences() {
    final savedOrder = PreferencesService.getCategoryOrder();
    if (savedOrder != null && savedOrder.isNotEmpty) {
      _categoryOrder = savedOrder;
      bool orderUpdated = false;
      if (!_categoryOrder.contains('Apps')) {
        _categoryOrder.add('Apps');
        orderUpdated = true;
      }
      if (!_categoryOrder.contains('Recycle Bin')) {
        _categoryOrder.add('Recycle Bin');
        orderUpdated = true;
      }
      if (!_categoryOrder.contains('Settings')) {
        _categoryOrder.add('Settings');
        orderUpdated = true;
      }
      if (orderUpdated) {
        PreferencesService.saveCategoryOrder(_categoryOrder);
      }
    }
    final savedActive = PreferencesService.getActiveCategories();
    if (savedActive != null && savedActive.isNotEmpty) {
      _activeCategories = savedActive;
    }
    final savedCustom = PreferencesService.getCustomShortcuts();
    if (savedCustom != null) {
      _customShortcuts = savedCustom;
    } else {
      _customShortcuts = [];
    }
    _customCategoryPaths = PreferencesService.getCustomCategoryPaths();
    _excludedDefaultPaths = PreferencesService.getExcludedDefaultPaths();
    notifyListeners();
  }

  List<AssetEntity> _images = [];
  List<AssetEntity> _videos = [];
  List<SongModel> _audios = [];

  Map<String, SongModel>? _audioPathMap;
  Map<String, AssetEntity>? _videoNameMap;

  Map<String, SongModel> get audioPathMap {
    if (_audioPathMap == null) {
      _audioPathMap = {
        for (final s in [..._audios, ..._fallbackAudios]) s.data: s,
      };
    }
    return _audioPathMap!;
  }

  Map<String, AssetEntity> get videoNameMap {
    if (_videoNameMap == null) {
      _videoNameMap = {};
      for (final v in _videos) {
        final titleLower = (v.title ?? '').toLowerCase();
        _videoNameMap![titleLower] = v;
        
        final extIndex = titleLower.lastIndexOf('.');
        if (extIndex != -1) {
          final base = titleLower.substring(0, extIndex);
          _videoNameMap![base] = v;
        }
        
        final mimeExt = v.mimeType?.split("/").last.toLowerCase();
        if (mimeExt != null) {
          _videoNameMap!['$titleLower.$mimeExt'] = v;
        }
      }
    }
    return _videoNameMap!;
  }

  @override
  void notifyListeners() {
    _audioPathMap = null;
    _videoNameMap = null;
    super.notifyListeners();
  }

  List<FileSystemEntity> _documents = [];
  List<FileSystemEntity> _archives = [];
  List<FileSystemEntity> _downloads = [];
  List<FileSystemEntity> _apks = [];
  List<AssetEntity> _screenshots = [];
  List<FileSystemEntity> _customImages = [];
  List<FileSystemEntity> _customVideos = [];
  List<FileSystemEntity> _customScreenshots = [];
  // Fallback results are rebuilt on every launch and are never cached,
  // so stale cache entries can never be shown again as fake media.
  List<FileSystemEntity> _fallbackImages = [];
  List<FileSystemEntity> _fallbackVideos = [];
  List<SongModel> _fallbackAudios = [];
  List<FileSystemEntity> _fallbackScreenshots = [];
  Map<String, List<String>> _customCategoryPaths = {};
  Map<String, List<String>> get customCategoryPaths => _customCategoryPaths;
  Map<String, List<String>> _excludedDefaultPaths = {};
  Map<String, List<String>> get excludedDefaultPaths => _excludedDefaultPaths;
  List<FileItemModel> _recentFiles = [];
  List<CustomShortcutModel> _customShortcuts = [];
  List<AssetPathEntity> _imageAlbums = [];
  List<AssetPathEntity> _videoAlbums = [];

  List<AssetPathEntity> get imageAlbums => _imageAlbums;
  List<AssetPathEntity> get videoAlbums => _videoAlbums;

  List<String> _categoryOrder = [
    'Images',
    'Videos',
    'Audio',
    'Documents',
    'Archives',
    'Downloads',
    'APKs',
    'Screenshots',
    'Apps',
    'Recycle Bin',
    'Settings',
  ];

  List<String> _activeCategories = [
    'Images',
    'Videos',
    'Audio',
    'Documents',
    'Archives',
    'Downloads',
    'APKs',
    'Screenshots',
    'Recycle Bin',
  ];


  bool _isLoading = false;
  bool _isLoaded = false;
  bool _mediaLoadInProgress = false;
  MediaSortOrder _sortOrder = MediaSortOrder.newest;
  DateTime? _lastRefreshTime;

  String? _getItemPath(dynamic item) {
    if (item is FileSystemEntity) return item.path;
    if (item is AssetEntity) {
      final rel = item.relativePath;
      final title = item.title;
      if (rel != null && title != null) {
        final cleanRel = rel.endsWith('/') ? rel.substring(0, rel.length - 1) : rel;
        String folder = '';
        if (cleanRel.startsWith('/storage/emulated/0') || cleanRel.startsWith('/storage/')) {
          folder = cleanRel;
        } else if (cleanRel.startsWith('storage/emulated/0') || cleanRel.startsWith('storage/')) {
          folder = '/$cleanRel';
        } else {
          folder = '/storage/emulated/0/$cleanRel';
        }
        return p.join(folder, title);
      }
    }
    return null;
  }

  bool _isPathExcluded(String itemPath, List<String> excludedPaths) {
    for (final excl in excludedPaths) {
      if (itemPath == excl || p.isWithin(excl, itemPath)) {
        return true;
      }
    }
    return false;
  }

  List<dynamic> get images {
    final excluded = _excludedDefaultPaths['Images'] ?? [];
    final excludeGallery = excluded.contains('Device Gallery (Auto)');
    final seen = <String>{};
    final list = <dynamic>[];
    for (final item in [..._images, ..._customImages, ..._fallbackImages]) {
      final path = _getItemPath(item);
      if (path != null && !seen.add(path)) continue;
      if (item is AssetEntity && excludeGallery) continue;
      if (path != null && _isPathExcluded(path, excluded)) continue;
      list.add(item);
    }
    _sortDynamicList(list);
    return list;
  }

  List<dynamic> get videos {
    final excluded = _excludedDefaultPaths['Videos'] ?? [];
    final excludeGallery = excluded.contains('Device Gallery (Auto)');
    final seen = <String>{};
    final list = <dynamic>[];
    for (final item in [..._videos, ..._customVideos, ..._fallbackVideos]) {
      final path = _getItemPath(item);
      if (path != null && !seen.add(path)) continue;
      if (item is AssetEntity && excludeGallery) continue;
      if (path != null && _isPathExcluded(path, excluded)) continue;
      list.add(item);
    }
    _sortDynamicList(list);
    return list;
  }

  List<SongModel> get audios {
    final excluded = _excludedDefaultPaths['Audio'] ?? [];
    final excludeLibrary = excluded.contains('Device Audio Library (Auto)');
    final seen = <String>{};
    final list = <SongModel>[];
    for (final song in [..._audios, ..._fallbackAudios]) {
      final path = song.data;
      if (path.isNotEmpty && !seen.add(path)) continue;
      if (excludeLibrary && song.id < 900000) continue;
      if (_isPathExcluded(path, excluded)) continue;
      list.add(song);
    }
    return list;
  }

  List<FileSystemEntity> get documents {
    final excluded = _excludedDefaultPaths['Documents'] ?? [];
    final excludeAllScanned = excluded.contains('Internal Storage (All Folders Scanned)');
    return _documents.where((file) {
      final docPaths = _customCategoryPaths['Documents'] ?? [];
      final isCustom = docPaths.any((dir) => p.isWithin(dir, file.path));
      if (excludeAllScanned && !isCustom) return false;
      if (_isPathExcluded(file.path, excluded)) return false;
      return true;
    }).toList();
  }

  List<FileSystemEntity> get archives {
    final excluded = _excludedDefaultPaths['Archives'] ?? [];
    final excludeAllScanned = excluded.contains('Internal Storage (All Folders Scanned)');
    return _archives.where((file) {
      final archPaths = _customCategoryPaths['Archives'] ?? [];
      final isCustom = archPaths.any((dir) => p.isWithin(dir, file.path));
      if (excludeAllScanned && !isCustom) return false;
      if (_isPathExcluded(file.path, excluded)) return false;
      return true;
    }).toList();
  }

  List<FileSystemEntity> get downloads {
    final excluded = _excludedDefaultPaths['Downloads'] ?? [];
    return _downloads.where((file) {
      if (_isPathExcluded(file.path, excluded)) return false;
      return true;
    }).toList();
  }

  List<FileSystemEntity> get apks {
    final excluded = _excludedDefaultPaths['APKs'] ?? [];
    final excludeAllScanned = excluded.contains('Internal Storage (All Folders Scanned)');
    return _apks.where((file) {
      final apkPaths = _customCategoryPaths['APKs'] ?? [];
      final isCustom = apkPaths.any((dir) => p.isWithin(dir, file.path));
      if (excludeAllScanned && !isCustom) return false;
      if (_isPathExcluded(file.path, excluded)) return false;
      return true;
    }).toList();
  }

  List<dynamic> get screenshots {
    final excluded = _excludedDefaultPaths['Screenshots'] ?? [];
    final excludeGallery = excluded.contains('Device Gallery (Screenshots)');
    final seen = <String>{};
    final list = <dynamic>[];
    for (final item in [..._screenshots, ..._customScreenshots, ..._fallbackScreenshots]) {
      final path = _getItemPath(item);
      if (path != null && !seen.add(path)) continue;
      if (item is AssetEntity && excludeGallery) continue;
      if (path != null && _isPathExcluded(path, excluded)) continue;
      list.add(item);
    }
    _sortDynamicList(list);
    return list;
  }
  List<FileItemModel> get recentFiles => _recentFiles;

  void _sortDynamicList(List<dynamic> list) {
    int Function(dynamic, dynamic) compare;
    if (_sortOrder == MediaSortOrder.newest ||
        _sortOrder == MediaSortOrder.newestGrouped ||
        _sortOrder == MediaSortOrder.dateWise) {
      compare = (a, b) {
        final aTime = _getDateTime(a);
        final bTime = _getDateTime(b);
        return bTime.compareTo(aTime);
      };
    } else if (_sortOrder == MediaSortOrder.oldest ||
               _sortOrder == MediaSortOrder.oldestGrouped) {
      compare = (a, b) {
        final aTime = _getDateTime(a);
        final bTime = _getDateTime(b);
        return aTime.compareTo(bTime);
      };
    } else if (_sortOrder == MediaSortOrder.sizeLargest ||
               _sortOrder == MediaSortOrder.sizeSmallest) {
      final isSmallest = _sortOrder == MediaSortOrder.sizeSmallest;
      compare = (a, b) {
        final aSize = _getSize(a);
        final bSize = _getSize(b);
        return isSmallest ? aSize.compareTo(bSize) : bSize.compareTo(aSize);
      };
    } else {
      return;
    }
    list.sort(compare);
  }

  DateTime _getDateTime(dynamic item) {
    if (item is AssetEntity) return item.createDateTime;
    if (item is FileSystemEntity) {
      try {
        return File(item.path).lastModifiedSync();
      } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _getSize(dynamic item) {
    if (item is AssetEntity) {
      return item.width * item.height;
    }
    if (item is FileSystemEntity) {
      try {
        return File(item.path).lengthSync();
      } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
    }
    return 0;
  }
  List<CustomShortcutModel> get customShortcuts => _customShortcuts;
  List<String> get categoryOrder => _categoryOrder;
  List<String> get activeCategories => _activeCategories;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  MediaSortOrder get sortOrder => _sortOrder;

  final OnAudioQuery _audioQuery = OnAudioQuery();

  void toggleCategory(String label) {
    if (_activeCategories.contains(label)) {
      if (_activeCategories.length > 1) {
        _activeCategories.remove(label);
      }
    } else {
      _activeCategories.add(label);
    }
    PreferencesService.saveActiveCategories(_activeCategories);
    _saveCache();
    notifyListeners();
  }

  void reorderCategory(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _categoryOrder.removeAt(oldIndex);
    _categoryOrder.insert(newIndex, item);
    PreferencesService.saveCategoryOrder(_categoryOrder);
    _saveCache();
    notifyListeners();
  }

  void addCustomShortcut(String path) {
    final label = p.basename(path);
    final id = 'custom_$path';
    if (_categoryOrder.contains(id)) return;

    final isDir = FileSystemEntity.isDirectorySync(path);
    final cs = CustomShortcutModel(id: id, label: label, path: path, isDirectory: isDir);
    _customShortcuts.add(cs);
    _categoryOrder.add(id);
    _activeCategories.add(id);

    PreferencesService.saveCustomShortcuts(_customShortcuts);
    PreferencesService.saveCategoryOrder(_categoryOrder);
    PreferencesService.saveActiveCategories(_activeCategories);
    _saveCache();
    notifyListeners();
  }

  void removeCustomShortcut(String id) {
    _customShortcuts.removeWhere((cs) => cs.id == id);
    _categoryOrder.remove(id);
    _activeCategories.remove(id);

    PreferencesService.saveCustomShortcuts(_customShortcuts);
    PreferencesService.saveCategoryOrder(_categoryOrder);
    PreferencesService.saveActiveCategories(_activeCategories);
    _saveCache();
    notifyListeners();
  }

  int getCategoryItemCount(String category) {
    if (_isLoaded) {
      switch (category) {
        case 'Images': return images.length;
        case 'Videos': return videos.length;
        case 'Audio': return audios.length;
        case 'Documents': return _documents.length;
        case 'Archives': return _archives.length;
        case 'Downloads': return _downloads.length;
        case 'APKs': return _apks.length;
        case 'Screenshots': return screenshots.length;
        case 'Apps': return 0;
        case 'Settings': return 0;
      }
    }
    return PreferencesService.getCategoryCount(category);
  }

  Map<String, dynamic> _assetToMap(AssetEntity asset) {
    return {
      'id': asset.id,
      'typeInt': asset.typeInt,
      'width': asset.width,
      'height': asset.height,
      'duration': asset.duration,
      'title': asset.title,
      'createDateSecond': asset.createDateSecond,
      'modifiedDateSecond': asset.modifiedDateSecond,
      'relativePath': asset.relativePath,
      'mimeType': asset.mimeType,
    };
  }

  AssetEntity _assetFromMap(Map<String, dynamic> map) {
    return AssetEntity(
      id: map['id'] as String,
      typeInt: map['typeInt'] as int,
      width: map['width'] as int,
      height: map['height'] as int,
      duration: map['duration'] as int? ?? 0,
      title: map['title'] as String?,
      createDateSecond: map['createDateSecond'] as int?,
      modifiedDateSecond: map['modifiedDateSecond'] as int?,
      relativePath: map['relativePath'] as String?,
      mimeType: map['mimeType'] as String?,
    );
  }

  Future<void> _loadFromDiskCache() async {
    try {
      final dir = await getTemporaryDirectory();
      final cacheFile = File('${dir.path}/media_meta_cache.json');
      if (await cacheFile.exists()) {
        final jsonStr = await cacheFile.readAsString();
        final map = (jsonDecode(jsonStr) as? Map<String, dynamic>) ?? {};

        if (map.containsKey('categoryOrder')) {
          _categoryOrder = List<String>.from(map['categoryOrder'] ?? _categoryOrder);
          if (!_categoryOrder.contains('Apps')) {
            _categoryOrder.add('Apps');
          }
          if (!_categoryOrder.contains('Recycle Bin')) {
            _categoryOrder.add('Recycle Bin');
          }
          if (!_categoryOrder.contains('Settings')) {
            _categoryOrder.add('Settings');
          }
        }
        if (map.containsKey('activeCategories')) {
          _activeCategories = List<String>.from(map['activeCategories'] ?? _activeCategories);
        }

        // Discard cached media from older versions (e.g. stale fallback junk).
        if (map['cacheVersion'] != _cacheVersion) {
          writeLog('Cache version mismatch (${map['cacheVersion']}), discarding cached media');
          return;
        }

        if (map.containsKey('images')) {
          final imgMaps = List<Map<String, dynamic>>.from(
            (map['images'] as? List)?.map((e) => Map<String, dynamic>.from(e as? Map)) ?? [],
          );
          final cachedImages = imgMaps.map((m) => _assetFromMap(m)).toList();
          if (cachedImages.isNotEmpty && _images.isEmpty) {
            _images = cachedImages;
          }
        }

        if (map.containsKey('videos')) {
          final vidMaps = List<Map<String, dynamic>>.from(
            (map['videos'] as? List)?.map((e) => Map<String, dynamic>.from(e as? Map)) ?? [],
          );
          final cachedVideos = vidMaps.map((m) => _assetFromMap(m)).toList();
          if (cachedVideos.isNotEmpty && _videos.isEmpty) {
            _videos = cachedVideos;
          }
        }

        if (map.containsKey('screenshots')) {
          final scMaps = List<Map<String, dynamic>>.from(
            (map['screenshots'] as? List)?.map((e) => Map<String, dynamic>.from(e as? Map)) ?? [],
          );
          final cachedScreenshots = scMaps.map((m) => _assetFromMap(m)).toList();
          if (cachedScreenshots.isNotEmpty && _screenshots.isEmpty) {
            _screenshots = cachedScreenshots;
          }
        }

        if (map.containsKey('audios')) {
          final audMaps = List<Map<String, dynamic>>.from(
            (map['audios'] as? List)?.map((e) => Map<String, dynamic>.from(e as? Map)) ?? [],
          );
          final cachedAudios = audMaps.map((m) => SongModel(m)).toList();
          if (cachedAudios.isNotEmpty && _audios.isEmpty) {
            _audios = cachedAudios;
          }
        }

        if (map.containsKey('customImages')) {
          final paths = List<String>.from(map['customImages'] ?? []);
          final cachedCI = paths.map((p) => File(p)).toList();
          if (cachedCI.isNotEmpty && _customImages.isEmpty) {
            _customImages = cachedCI;
          }
        }

        if (map.containsKey('customVideos')) {
          final paths = List<String>.from(map['customVideos'] ?? []);
          final cachedCV = paths.map((p) => File(p)).toList();
          if (cachedCV.isNotEmpty && _customVideos.isEmpty) {
            _customVideos = cachedCV;
          }
        }

        if (map.containsKey('customScreenshots')) {
          final paths = List<String>.from(map['customScreenshots'] ?? []);
          final cachedCS = paths.map((p) => File(p)).toList();
          if (cachedCS.isNotEmpty && _customScreenshots.isEmpty) {
            _customScreenshots = cachedCS;
          }
        }

        if (map.containsKey('documents')) {
          final docPaths = List<String>.from(map['documents'] ?? []);
          final cachedDocs = <FileSystemEntity>[];
          for (final p in docPaths) {
            final f = File(p);
            if (f.existsSync()) cachedDocs.add(f);
          }
          if (cachedDocs.isNotEmpty && _documents.isEmpty) {
            _documents = cachedDocs;
          }
        }

        if (map.containsKey('archives')) {
          final archPaths = List<String>.from(map['archives'] ?? []);
          final cachedArch = <FileSystemEntity>[];
          for (final p in archPaths) {
            final f = File(p);
            if (f.existsSync()) cachedArch.add(f);
          }
          if (cachedArch.isNotEmpty && _archives.isEmpty) {
            _archives = cachedArch;
          }
        }

        if (map.containsKey('downloads')) {
          final dlPaths = List<String>.from(map['downloads'] ?? []);
          final cachedDl = <FileSystemEntity>[];
          for (final p in dlPaths) {
            final f = File(p);
            if (f.existsSync()) cachedDl.add(f);
          }
          if (cachedDl.isNotEmpty && _downloads.isEmpty) {
            _downloads = cachedDl;
          }
        }

        if (map.containsKey('apks')) {
          final apkPaths = List<String>.from(map['apks'] ?? []);
          final cachedApks = <FileSystemEntity>[];
          for (final p in apkPaths) {
            final f = File(p);
            if (f.existsSync()) cachedApks.add(f);
          }
          if (cachedApks.isNotEmpty && _apks.isEmpty) {
            _apks = cachedApks;
          }
        }

        if (map.containsKey('recentFiles')) {
          final paths = List<Map<String, dynamic>>.from(
            (map['recentFiles'] as? List)?.map((e) => Map<String, dynamic>.from(e as? Map)) ?? [],
          );
          final cached = <FileItemModel>[];
          for (final entry in paths) {
            try {
              final path = entry['path'] as String?;
              if (path == null) continue;
              final f = File(path);
              if (!f.existsSync()) continue;
              cached.add(FileItemModel(
                entity: f,
                name: p.basename(path),
                path: path,
                isDirectory: false,
                size: (entry['size'] as num?)?.toInt() ?? 0,
                modified: DateTime.fromMillisecondsSinceEpoch(
                  (entry['modified'] as num?)?.toInt() ?? 0,
                ),
              ));
            } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
          }
          if (cached.isNotEmpty && _recentFiles.isEmpty) {
            _recentFiles = cached;
          }
        }
      }
    } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
  }

  Future<void> _saveCache() async {
    try {
      final dir = await getTemporaryDirectory();
      final cacheFile = File('${dir.path}/media_meta_cache.json');
      
      // Limitar cache a últimos 1000 items por categoría para evitar archivos gigantes
      final map = {
        'cacheVersion': _cacheVersion,
        'categoryOrder': _categoryOrder,
        'activeCategories': _activeCategories,
        'images': images.take(1000).map((a) => _assetToMap(a)).toList(),
        'videos': videos.take(500).map((a) => _assetToMap(a)).toList(),
        'screenshots': screenshots.take(500).map((a) => _assetToMap(a)).toList(),
        'audios': audios.take(1000).map((s) => s.getMap).toList(),
        'customImages': _customImages.take(500).map((e) => e.path).toList(),
        'customVideos': _customVideos.take(500).map((e) => e.path).toList(),
        'customScreenshots': _customScreenshots.take(500).map((e) => e.path).toList(),
        'documents': _documents.take(1000).map((e) => e.path).toList(),
        'archives': _archives.take(500).map((e) => e.path).toList(),
        'downloads': _downloads.take(500).map((e) => e.path).toList(),
        'apks': _apks.take(500).map((e) => e.path).toList(),
        'recentFiles': _recentFiles.take(30).map((e) => {
          'path': e.path,
          'size': e.size,
          'modified': e.modified.millisecondsSinceEpoch,
        }).toList(),
      };
      
      final jsonStr = jsonEncode(map);
      await cacheFile.writeAsString(jsonStr, flush: true);
      
      debugPrint('[MediaProvider] Cache saved successfully');
    } catch (e) {
      debugPrint('[MediaProvider] Error saving cache: $e');
    }
  }

  Future<void> refreshMediaBackground() async {
    final now = DateTime.now();
    if (_lastRefreshTime != null && now.difference(_lastRefreshTime!) < const Duration(minutes: 5)) {
      writeLog('Skipping refreshMediaBackground: last run was less than 5 minutes ago');
      return;
    }
    _lastRefreshTime = now;

    final futures = <Future<void>>[];
    
    bool isStorageGranted = false;
    try {
      isStorageGranted = await Permission.storage.isGranted || await Permission.manageExternalStorage.isGranted;
    } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
    
    PermissionState ps = PermissionState.denied;
    try {
      ps = await PhotoManager.requestPermissionExtend();
    } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }

    bool hasAudioPermission = false;
    try {
      hasAudioPermission = await _audioQuery.permissionsStatus();
    } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }

    if (ps.isAuth || isStorageGranted) {
      if (Platform.isAndroid) {
        try {
          final info = await DeviceInfoPlugin().androidInfo;
          if (info.version.sdkInt < 33) {
            PhotoManager.setIgnorePermissionCheck(true);
          }
        } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
      }
      futures.add(_loadImagesAndVideos());
    }
    if (hasAudioPermission || isStorageGranted) {
      futures.add(_loadAudios());
    }
    futures.add(_loadDocuments());
    futures.add(_loadArchivesDownloadsAndApks());

    await Future.wait(futures);
    await _scanCustomCategories();
    await _scanRecentFiles();
    await _saveCache();
    _applySort();
    
    PreferencesService.saveCategoryCount('Images', images.length);
    PreferencesService.saveCategoryCount('Videos', videos.length);
    PreferencesService.saveCategoryCount('Audio', audios.length);
    PreferencesService.saveCategoryCount('Documents', _documents.length);
    PreferencesService.saveCategoryCount('Archives', _archives.length);
    PreferencesService.saveCategoryCount('Downloads', _downloads.length);
    PreferencesService.saveCategoryCount('APKs', _apks.length);
    PreferencesService.saveCategoryCount('Screenshots', screenshots.length);

    notifyListeners();
  }

  Future<void> loadMedia({bool forceRefresh = false}) async {
    writeLog('loadMedia called (forceRefresh: $forceRefresh)');
    _lastRefreshTime = DateTime.now();
    if (_isLoading) {
      writeLog('loadMedia returning early because already loading');
      return;
    }
    if (_isLoaded && !forceRefresh) {
      writeLog('loadMedia returning early because already loaded');
      await _scanCustomCategories();
      _applySort();
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    // load cache
    await _loadFromDiskCache();

    // show cached data immediately if we have it
    final hasCachedData = _images.isNotEmpty ||
        _videos.isNotEmpty ||
        _audios.isNotEmpty ||
        _documents.isNotEmpty ||
        _archives.isNotEmpty ||
        _downloads.isNotEmpty ||
        _apks.isNotEmpty ||
        _screenshots.isNotEmpty;

    writeLog('Cached data found: $hasCachedData');

    if (hasCachedData) {
      _isLoading = false;
      _isLoaded = true;
      _applySort();
      notifyListeners();
    }

    bool isStorageGranted = false;
    try {
      isStorageGranted = await Permission.storage.isGranted || await Permission.manageExternalStorage.isGranted;
    } catch (e) {
      writeLog('Error checking permissions: $e');
    }

    writeLog('isStorageGranted status: $isStorageGranted (storage: ${await Permission.storage.isGranted}, manageExternalStorage: ${await Permission.manageExternalStorage.isGranted})');

    PermissionState ps = PermissionState.denied;
    bool hasAudioPermission = false;

    if (isStorageGranted) {
      ps = PermissionState.authorized;
      hasAudioPermission = true;
      if (Platform.isAndroid) {
        try {
          final info = await DeviceInfoPlugin().androidInfo;
          final sdk = info.version.sdkInt;
          if (sdk >= 33) {
            try {
              await Permission.audio.request();
            } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
          }
          PhotoManager.setIgnorePermissionCheck(true);
          try {
            await Permission.accessMediaLocation.request();
          } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
          try {
            final status = await PhotoManager.requestPermissionExtend();
            if (status.isAuth) {
              ps = status;
            }
          } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
        } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
      }
    } else {
      if (Platform.isAndroid) {
        try {
          final info = await DeviceInfoPlugin().androidInfo;
          final sdk = info.version.sdkInt;
          if (sdk < 33) {
            final storageStatus = await Permission.storage.request();
            if (storageStatus.isGranted) {
              isStorageGranted = true;
              ps = PermissionState.authorized;
              hasAudioPermission = true;
            }
            try {
              await Permission.accessMediaLocation.request();
            } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
            PhotoManager.setIgnorePermissionCheck(true);
            try {
              final status = await PhotoManager.requestPermissionExtend();
              if (status.isAuth) {
                ps = status;
              }
            } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
          } else {
            try {
              ps = await PhotoManager.requestPermissionExtend();
            } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }

            try {
              hasAudioPermission = await _audioQuery.permissionsStatus();
              if (!hasAudioPermission) {
                final status = await Permission.audio.request();
                hasAudioPermission = status.isGranted;
              }
            } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
          }
        } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
      } else {
        try {
          ps = await PhotoManager.requestPermissionExtend();
        } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
        hasAudioPermission = true;
      }
    }

    final futures = <Future<void>>[];
    if (ps.isAuth || isStorageGranted) {
      if (Platform.isAndroid) {
        try {
          final info = await DeviceInfoPlugin().androidInfo;
          final sdk = info.version.sdkInt;
          if (sdk < 33) {
            PhotoManager.setIgnorePermissionCheck(true);
          }
        } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
      }
      if (isStorageGranted && !ps.isAuth) {
        try {
          PhotoManager.setIgnorePermissionCheck(true);
        } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
      }
      try {
        PhotoManager.clearFileCache();
      } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
      futures.add(
        _loadImagesAndVideos().timeout(const Duration(seconds: 15), onTimeout: () {
          debugPrint('[MediaProvider] _loadImagesAndVideos timed out');
        })
      );
    }
    if (hasAudioPermission || isStorageGranted) {
      futures.add(
        _loadAudios().timeout(const Duration(seconds: 15), onTimeout: () {
          debugPrint('[MediaProvider] _loadAudios timed out');
        })
      );
    }
    futures.add(
      _loadDocuments().timeout(const Duration(seconds: 15), onTimeout: () {
        debugPrint('[MediaProvider] _loadDocuments timed out');
      })
    );
    futures.add(
      _loadArchivesDownloadsAndApks().timeout(const Duration(seconds: 15), onTimeout: () {
        debugPrint('[MediaProvider] _loadArchivesDownloadsAndApks timed out');
      })
    );

    try {
      writeLog('Starting Future.wait loaders...');
      await Future.wait(futures.map((f) => f.catchError((e) {
        writeLog('Loader future threw error: $e');
        return null;
      })));
      writeLog('Future.wait loaders completed. Images: ${images.length}, Videos: ${videos.length}, Audios: ${_audios.length}, Docs: ${_documents.length}');
      await _scanCustomCategories();

      // Fallback: if MediaStore (photo_manager / audio_query) left any category
      // empty, scan the filesystem in a single pass (like documents loading)
      // and fill only the missing categories.
      if (_images.isEmpty || _videos.isEmpty || _audios.isEmpty) {
        writeLog('MediaStore left categories empty, starting single-pass filesystem fallback scan...');
        await _scanMediaFallback();
      }

      // Scan recent files after all media is loaded so it can merge from providers
      await _scanRecentFiles().timeout(const Duration(seconds: 5), onTimeout: () {
        writeLog('_scanRecentFiles timed out');
      });

      await _saveCache();

      _applySort();

      PreferencesService.saveCategoryCount('Images', images.length);
      PreferencesService.saveCategoryCount('Videos', videos.length);
      PreferencesService.saveCategoryCount('Audio', audios.length);
      PreferencesService.saveCategoryCount('Documents', _documents.length);
      PreferencesService.saveCategoryCount('Archives', _archives.length);
      PreferencesService.saveCategoryCount('Downloads', _downloads.length);
      PreferencesService.saveCategoryCount('APKs', _apks.length);
      PreferencesService.saveCategoryCount('Screenshots', screenshots.length);
      writeLog('Finished loading media. Counts -> Images: ${images.length}, Videos: ${videos.length}, Audio: ${audios.length}, Docs: ${_documents.length}, Archives: ${_archives.length}, Downloads: ${_downloads.length}, APKs: ${_apks.length}, Screenshots: ${screenshots.length}');
    } catch (e) {
      writeLog('Error during loadMedia scanners: $e');
    } finally {
      writeLog('loadMedia finally block. _isLoaded = true');
      _isLoading = false;
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _loadImagesAndVideos() async {
    if (_mediaLoadInProgress) {
      writeLog('_loadImagesAndVideos skipped: already in progress');
      return;
    }
    _mediaLoadInProgress = true;
    writeLog('_loadImagesAndVideos started');
    try {
      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(onlyAll: false);
      writeLog('PhotoManager albums count: ${albums.length}');

      // Screenshots from screenshot-named albums (best effort, never fatal)
      List<AssetEntity> allScreenshots = [];
      try {
        final seenScreenshotIds = <String>{};
        for (final album in albums) {
          if (album.name.toLowerCase().contains('screenshot')) {
            await _paginateAlbumAssets(album, (assets) {
              for (final asset in assets) {
                if (seenScreenshotIds.add(asset.id)) {
                  allScreenshots.add(asset);
                }
              }
            });
          }
        }
      } catch (e) {
        writeLog('Screenshot albums fetch failed: $e');
      }

      // Main image/video list (best effort)
      final allMedia = <AssetEntity>[];
      try {
        if (albums.isNotEmpty) {
          final allAlbum = albums.firstWhere((a) => a.isAll, orElse: () => albums.first);
          if (allAlbum.isAll) {
            writeLog('Fetching all assets from combined isAll album: ${allAlbum.name}');
            await _paginateAlbumAssets(allAlbum, (assets) => allMedia.addAll(assets));
          } else {
            writeLog('No isAll album found (first is: ${allAlbum.name}), scanning all albums...');
            for (final album in albums) {
              try {
                await _paginateAlbumAssets(album, (assets) => allMedia.addAll(assets));
              } catch (e2) {
                writeLog('Album "${album.name}" fetch failed: $e2');
              }
            }
          }
        }
      } catch (e) {
        // On some Huawei devices the combined query can fail; fetch each album separately.
        writeLog('All-album fetch failed, trying per-album: $e');
        for (final album in albums) {
          try {
            await _paginateAlbumAssets(album, (assets) => allMedia.addAll(assets));
          } catch (e2) {
            writeLog('Album "${album.name}" fetch failed: $e2');
          }
        }
      }

      final seenIds = <String>{};
      final unique = <AssetEntity>[];
      for (final a in allMedia) {
        if (seenIds.add(a.id)) unique.add(a);
      }
      writeLog('PhotoManager fetched media: ${unique.length}');

      _images = unique.where((e) => e.type == AssetType.image).toList();
      _videos = unique.where((e) => e.type == AssetType.video).toList();
      if (allScreenshots.isEmpty) {
        _screenshots = _images.where((e) => (e.title ?? '').toLowerCase().contains('screenshot') || (e.relativePath ?? '').toLowerCase().contains('screenshot')).toList();
      } else {
        _screenshots = allScreenshots;
      }

      // Fetch distinct image albums (best effort)
      try {
        final imgAlbums = await PhotoManager.getAssetPathList(type: RequestType.image);
        final filteredImgAlbums = <AssetPathEntity>[];
        for (final album in imgAlbums) {
          try {
            if (await album.assetCountAsync > 0) {
              filteredImgAlbums.add(album);
            }
          } catch (e, stackTrace) {
      // Error handled
            filteredImgAlbums.add(album);
          }
        }
        _imageAlbums = filteredImgAlbums;
      } catch (e) {
        writeLog('Image album fetch failed: $e');
      }

      // Fetch distinct video albums (best effort)
      try {
        final vidAlbums = await PhotoManager.getAssetPathList(type: RequestType.video);
        final filteredVidAlbums = <AssetPathEntity>[];
        for (final album in vidAlbums) {
          try {
            if (await album.assetCountAsync > 0) {
              filteredVidAlbums.add(album);
            }
          } catch (e, stackTrace) {
      // Error handled
            filteredVidAlbums.add(album);
          }
        }
        _videoAlbums = filteredVidAlbums;
      } catch (e) {
        writeLog('Video album fetch failed: $e');
      }
    } catch (e) {
      writeLog('_loadImagesAndVideos failed with exception: $e');
    } finally {
      _mediaLoadInProgress = false;
    }
  }

  Future<void> _paginateAlbumAssets(
    AssetPathEntity album,
    void Function(List<AssetEntity> page) onPage,
  ) async {
    const pageSize = 500;
    var page = 0;
    while (true) {
      final assets = await album.getAssetListPaged(page: page, size: pageSize);
      if (assets.isEmpty) break;
      onPage(assets);
      if (assets.length < pageSize) break;
      page++;
    }
  }

  Future<void> _scanMediaFallback() async {
    _fallbackAudios.clear();
    try {
      final allImg = <String>[];
      final allVid = <String>[];
      final allAud = <String>[];

      void collect(String path) {
        final ext = p.extension(path).toLowerCase();
        if (_imageExts.contains(ext)) {
          allImg.add(path);
        } else if (_videoExts.contains(ext)) {
          allVid.add(path);
        } else if (_audioExts.contains(ext)) {
          allAud.add(path);
        }
      }

      // Single isolate pass over the whole storage, like documents scanning.
      try {
        final params = {'startPath': '/storage/emulated/0', 'filterType': 'all_media'};
        final paths = await compute(_isolateDirectoryScan, params);
        for (final path in paths) {
          collect(path);
        }
      } catch (e) {
        writeLog('Media fallback isolate failed, using per-dir scan: $e');
        final searchDirs = await _getUserSearchDirs();
        for (final dirPath in searchDirs) {
          await _scanDirectoryRecursively(dirPath, 'all_media', (file) => collect(file.path));
        }
      }

      writeLog('Media fallback scan -> Images: ${allImg.length}, Videos: ${allVid.length}, Audios: ${allAud.length}');

      final existingImgPaths = <String>{
        ..._images.map((a) => _getItemPath(a)).whereType<String>(),
        ..._customImages.map((f) => f.path),
      };
      final existingVidPaths = <String>{
        ..._videos.map((a) => _getItemPath(a)).whereType<String>(),
        ..._customVideos.map((f) => f.path),
      };
      final existingAudPaths = <String>{
        ..._audios.map((s) => s.data),
      };

      _fallbackImages = [
        for (final path in allImg)
          if (!existingImgPaths.contains(path)) File(path),
      ];
      _fallbackVideos = [
        for (final path in allVid)
          if (!existingVidPaths.contains(path)) File(path),
      ];

      int addedAudios = 0;
      for (int i = 0; i < allAud.length; i++) {
        final path = allAud[i];
        if (existingAudPaths.contains(path)) continue;
        try {
          final stat = File(path).statSync();
          _fallbackAudios.add(SongModel({
            '_id': 800000 + i,
            '_data': path,
            'title': p.basenameWithoutExtension(path),
            'artist': 'Unknown Artist',
            'album': 'Device Storage',
            'duration': 0,
            '_size': stat.size,
            '_display_name': p.basename(path),
            '_display_name_wo_ext': p.basenameWithoutExtension(path),
            'is_music': true,
          }));
          addedAudios++;
        } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
      }
      writeLog('Media fallback merge -> extra Images: ${_fallbackImages.length}, extra Videos: ${_fallbackVideos.length}, extra Audios: $addedAudios');

      _fallbackScreenshots = _fallbackImages
          .where((e) =>
              e.path.toLowerCase().contains('screenshot') ||
              p.basename(e.path).toLowerCase().contains('screenshot'))
          .toList();
    } catch (e) {
      writeLog('Media fallback scan failed: $e');
    }
  }

  Future<void> _loadAudios() async {
    try {
      bool isStorageGranted = false;
      try {
        isStorageGranted = await Permission.storage.isGranted || await Permission.manageExternalStorage.isGranted;
      } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }

      bool hasPerm = false;
      try {
        hasPerm = await _audioQuery.permissionsStatus();
      } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }

      if (!hasPerm && !isStorageGranted) {
        _audios = [];
        return;
      }
      _audios = await _audioQuery.querySongs(
        sortType: null,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      writeLog('_loadAudios succeeded with ${_audios.length} songs');
    } catch (e) {
      writeLog('_loadAudios failed with exception: $e');
      _audios = [];
    }
  }

  static const List<String> _docExtensions = [
    '.pdf',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.txt',
    '.csv',
    '.odt',
    '.ods',
    '.odp',
    '.rtf',
    '.epub',
  ];

  Future<List<String>> _getUserSearchDirs() async {
    final searchDirs = <String>[];
    try {
      final rootDir = Directory('/storage/emulated/0');
      if (await rootDir.exists()) {
        await for (final entity in rootDir.list(recursive: false)) {
          try {
            if (entity is Directory) {
              final name = p.basename(entity.path);
              if (name != 'Android' && !name.startsWith('.')) {
                searchDirs.add(entity.path);
              }
            }
          } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
        }
      }
    } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
    if (searchDirs.isEmpty) {
      searchDirs.addAll([
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Telegram',
        '/storage/emulated/0/WhatsApp',
        '/storage/emulated/0/WhatsApp/Media',
      ]);
    }
    return searchDirs;
  }

  static const List<String> _imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.heic', '.heif', '.svg', '.avif'];
  static const List<String> _videoExts = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.3gp', '.ts'];
  static const List<String> _audioExts = ['.mp3', '.wav', '.ogg', '.m4a', '.flac', '.aac', '.wma', '.amr', '.opus', '.mid'];
  static const Set<String> _junkDirNames = {
    'cache', 'caches', 'cacheddata', 'thumbnails', 'thumbnails_cache',
    'tmp', 'temp', 'web_cache', 'webcache', 'cachedimages', 'download_cache',
    'stickers', 'sticker', 'avatars', 'filters', 'emojis', 'effects',
    'gifs', 'gif cache', 'voices', 'voicenotes', 'voice notes', 'voicemessages',
    'voice messages', 'recorder', 'recordings', 'notification sounds',
    'system sounds', 'alarms', 'alarm sounds',
  };

  static bool _isJunkDirectory(String path) {
    final lower = path.toLowerCase();
    final segments = p.split(lower);
    for (final seg in segments) {
      if (_junkDirNames.contains(seg)) return true;
      if (seg.contains('sticker') ||
          seg.contains('cache') ||
          seg.contains('avatar') ||
          seg.contains('emoji') ||
          seg.contains('thumbnail') ||
          seg.contains('voice') ||
          seg.contains('sound') ||
          seg.contains('alarm') ||
          seg.contains('ringtone') ||
          seg.contains('notification') ||
          seg.contains('status') ||
          seg.contains('whatsapp audio') ||
          seg.contains('telegram')) {
        return true;
      }
    }
    return false;
  }

  static Future<List<String>> _isolateDirectoryScan(Map<String, dynamic> params) async {
    final startPath = params['startPath'] as String;
    final filterType = params['filterType'] as String;
    final docExts = (params['docExts'] as? List<String>) ?? [];
    final archExts = (params['archExts'] as? List<String>) ?? [];
    final apkExts = (params['apkExts'] as? List<String>) ?? [];

    final result = <String>[];
    final queue = <String>[startPath];

    bool shouldInclude(String path) {
      final ext = p.extension(path).toLowerCase();
      switch (filterType) {
        case 'doc': return docExts.contains(ext);
        case 'arch_and_apk': return archExts.contains(ext) || apkExts.contains(ext);
        case 'arch': return archExts.contains(ext);
        case 'apk': return apkExts.contains(ext);
        case 'image': return _imageExts.contains(ext);
        case 'video': return _videoExts.contains(ext);
        case 'audio': return _audioExts.contains(ext);
        case 'all_media': return _imageExts.contains(ext) || _videoExts.contains(ext) || _audioExts.contains(ext);
        default: return false;
      }
    }

    while (queue.isNotEmpty) {
      final currentPath = queue.removeAt(0);
      final dir = Directory(currentPath);
      try {
        final entities = dir.listSync(recursive: false, followLinks: false);

        // Standard Android behavior: Skip scanning directories that contain a .nomedia file
        bool hasNoMedia = false;
        for (final entity in entities) {
          if (entity is File && p.basename(entity.path).toLowerCase() == '.nomedia') {
            hasNoMedia = true;
            break;
          }
        }
        if (hasNoMedia) continue;

        for (final entity in entities) {
          try {
            if (entity is Directory) {
              final name = p.basename(entity.path);
              if (!name.startsWith('.') &&
                  name != 'Android' &&
                  !_isJunkDirectory(entity.path)) {
                queue.add(entity.path);
              }
            } else if (entity is File) {
              if (shouldInclude(entity.path)) {
                // Reject tiny cached junk files (icons, stickers, notification
                // sounds, placeholder clips) from the media fallback scan.
                if (filterType == 'all_media') {
                  try {
                    final size = entity.statSync().size;
                    final ext = p.extension(entity.path).toLowerCase();
                    if (_imageExts.contains(ext) && size < 3000) continue;
                    if (_videoExts.contains(ext) && size < 10240) continue;
                    if (_audioExts.contains(ext) && size < 102400) continue;
                  } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
                }
                result.add(entity.path);
              }
            }
          } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
        }
      } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
    }
    return result;
  }

  Future<void> _scanDirectoryRecursively(
    String startPath,
    String filterType,
    void Function(File file) onFound,
  ) async {
    List<String> resultPaths;
    final params = {
      'startPath': startPath,
      'filterType': filterType,
      'docExts': _docExtensions,
      'archExts': _archiveExtensions,
      'apkExts': _apkExtensions,
    };
    try {
      resultPaths = await compute(_isolateDirectoryScan, params);
    } catch (e) {
      debugPrint('[MediaProvider] Isolate compute failed, falling back to main-thread scan: $e');
      try {
        resultPaths = await _isolateDirectoryScan(params);
      } catch (err) {
        debugPrint('[MediaProvider] Main-thread scan fallback failed: $err');
        resultPaths = [];
      }
    }
    for (final path in resultPaths) {
      onFound(File(path));
    }
  }

  Future<void> _loadDocuments() async {
    try {
      final docs = <FileSystemEntity>[];
      final searchDirs = await _getUserSearchDirs();
      final excluded = _excludedDefaultPaths['Documents'] ?? [];

      for (final dirPath in searchDirs) {
        if (_isPathExcluded(dirPath, excluded)) continue;
        await _scanDirectoryRecursively(
          dirPath,
          'doc',
          (file) => docs.add(file),
        );
      }

      final docPaths = _customCategoryPaths['Documents'] ?? [];
      for (final dirPath in docPaths) {
        if (await Directory(dirPath).exists()) {
          await _scanDirectoryRecursively(
            dirPath,
            'doc',
            (file) {
              if (!docs.any((d) => d.path == file.path)) {
                docs.add(file);
              }
            },
          );
        }
      }

      _documents = docs;
    } catch (e) {
      debugPrint('[MediaProvider] Error in _loadDocuments: $e');
      _documents = [];
    }
  }

  static const List<String> _archiveExtensions = ['.zip', '.tar', '.gz', '.bz2', '.rar', '.7z'];
  static const List<String> _apkExtensions = ['.apk', '.xapk', '.apks', '.aab'];

  Future<void> _loadArchivesDownloadsAndApks() async {
    try {
      final arch = <FileSystemEntity>[];
      final dl = <FileSystemEntity>[];
      final apkList = <FileSystemEntity>[];

      // For downloads
      final dlDirs = ['/storage/emulated/0/Download', '/storage/emulated/0/Downloads'];
      final customDlPaths = _customCategoryPaths['Downloads'] ?? [];
      final allDlDirs = {...dlDirs, ...customDlPaths};
      final excludedDl = _excludedDefaultPaths['Downloads'] ?? [];
      for (final dirPath in allDlDirs) {
        if (_isPathExcluded(dirPath, excludedDl)) continue;
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          try {
            await for (final entity in dir.list(recursive: false)) {
              if (entity is File) {
                if (!dl.any((e) => e.path == entity.path)) {
                  dl.add(entity);
                }
              }
            }
          } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
        }
      }

      final searchDirs = await _getUserSearchDirs();
      final excludedArch = _excludedDefaultPaths['Archives'] ?? [];
      final excludedApk = _excludedDefaultPaths['APKs'] ?? [];

      for (final dirPath in searchDirs) {
        final isArchExcl = _isPathExcluded(dirPath, excludedArch);
        final isApkExcl = _isPathExcluded(dirPath, excludedApk);
        if (isArchExcl && isApkExcl) continue;

        await _scanDirectoryRecursively(
          dirPath,
          'arch_and_apk',
          (file) {
            final ext = p.extension(file.path).toLowerCase();
            if (_archiveExtensions.contains(ext) && !isArchExcl) {
              arch.add(file);
            } else if (_apkExtensions.contains(ext) && !isApkExcl) {
              apkList.add(file);
            }
          },
        );
      }

      final archPaths = _customCategoryPaths['Archives'] ?? [];
      for (final dirPath in archPaths) {
        if (await Directory(dirPath).exists()) {
          await _scanDirectoryRecursively(
            dirPath,
            'arch',
            (file) {
              if (!arch.any((d) => d.path == file.path)) {
                arch.add(file);
              }
            },
          );
        }
      }

      final apkPaths = _customCategoryPaths['APKs'] ?? [];
      for (final dirPath in apkPaths) {
        if (await Directory(dirPath).exists()) {
          await _scanDirectoryRecursively(
            dirPath,
            'apk',
            (file) {
              if (!apkList.any((d) => d.path == file.path)) {
                apkList.add(file);
              }
            },
          );
        }
      }

      _downloads = dl;
      _archives = arch;
      _apks = apkList;
    } catch (e) {
      debugPrint('[MediaProvider] Error in _loadArchivesDownloadsAndApks: $e');
      _downloads = [];
      _archives = [];
      _apks = [];
    }
  }

  Future<void> _scanCustomCategories() async {
    final imagePaths = _customCategoryPaths['Images'] ?? [];
    _customImages = await _scanCustomPaths(imagePaths, 'image');

    final videoPaths = _customCategoryPaths['Videos'] ?? [];
    _customVideos = await _scanCustomPaths(videoPaths, 'video');

    final screenshotPaths = _customCategoryPaths['Screenshots'] ?? [];
    _customScreenshots = await _scanCustomPaths(screenshotPaths, 'image');

    final audioPaths = _customCategoryPaths['Audio'] ?? [];
    final customAudFiles = await _scanCustomPaths(audioPaths, 'audio');
    _audios.removeWhere((song) => song.id >= 900000);
    final existingAudioPaths = _audios.map((s) => s.data).toSet();
    for (int i = 0; i < customAudFiles.length; i++) {
      final file = customAudFiles[i];
      if (!existingAudioPaths.contains(file.path)) {
        try {
          final stat = file.statSync();
          final songMap = {
            '_id': 900000 + i,
            '_data': file.path,
            'title': p.basenameWithoutExtension(file.path),
            'artist': 'Unknown Artist',
            'album': 'Custom Folder',
            'duration': 0,
            'size': stat.size,
            'display_name': p.basename(file.path),
            'display_name_wo_ext': p.basenameWithoutExtension(file.path),
            'is_music': true,
          };
          _audios.add(SongModel(songMap));
        } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
      }
    }

    // Documents custom path scan and merge
    final docPaths = _customCategoryPaths['Documents'] ?? [];
    final customDocs = await _scanCustomPaths(docPaths, 'doc');
    _documents.removeWhere((entity) {
      final isInCustomPath = docPaths.any((dir) => p.isWithin(dir, entity.path));
      if (isInCustomPath) {
        return !customDocs.any((f) => f.path == entity.path);
      }
      return false;
    });
    for (final doc in customDocs) {
      if (!_documents.any((d) => d.path == doc.path)) {
        _documents.add(doc);
      }
    }

    // Archives custom path scan and merge
    final archPaths = _customCategoryPaths['Archives'] ?? [];
    final customArch = await _scanCustomPaths(archPaths, 'arch');
    _archives.removeWhere((entity) {
      final isInCustomPath = archPaths.any((dir) => p.isWithin(dir, entity.path));
      if (isInCustomPath) {
        return !customArch.any((f) => f.path == entity.path);
      }
      return false;
    });
    for (final arc in customArch) {
      if (!_archives.any((a) => a.path == arc.path)) {
        _archives.add(arc);
      }
    }

    // APKs custom path scan and merge
    final apkPaths = _customCategoryPaths['APKs'] ?? [];
    final customApks = await _scanCustomPaths(apkPaths, 'apk');
    _apks.removeWhere((entity) {
      final isInCustomPath = apkPaths.any((dir) => p.isWithin(dir, entity.path));
      if (isInCustomPath) {
        return !customApks.any((f) => f.path == entity.path);
      }
      return false;
    });
    for (final apk in customApks) {
      if (!_apks.any((a) => a.path == apk.path)) {
        _apks.add(apk);
      }
    }

    // Downloads custom path scan and merge
    final customDlPaths = _customCategoryPaths['Downloads'] ?? [];
    final customDls = <File>[];
    for (final dirPath in customDlPaths) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        try {
          await for (final entity in dir.list(recursive: false)) {
            if (entity is File) {
              customDls.add(entity);
            }
          }
        } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
      }
    }
    _downloads.removeWhere((entity) {
      final isInCustomPath = customDlPaths.any((dir) => p.isWithin(dir, entity.path));
      if (isInCustomPath) {
        return !customDls.any((f) => f.path == entity.path);
      }
      return false;
    });
    for (final dl in customDls) {
      if (!_downloads.any((d) => d.path == dl.path)) {
        _downloads.add(dl);
      }
    }
  }

  Future<List<File>> _scanCustomPaths(List<String> paths, String filterType) async {
    final files = <File>[];
    for (final path in paths) {
      if (await Directory(path).exists()) {
        await _scanDirectoryRecursively(
          path,
          filterType,
          (file) => files.add(file),
        );
      }
    }
    return files;
  }

  void addCustomCategoryPath(String category, String path) {
    if (!_customCategoryPaths.containsKey(category)) {
      _customCategoryPaths[category] = [];
    }
    if (!_customCategoryPaths[category]!.contains(path)) {
      _customCategoryPaths[category]!.add(path);
      PreferencesService.saveCustomCategoryPaths(_customCategoryPaths);
      notifyListeners();
      loadMedia(forceRefresh: true);
    }
  }

  void removeCustomCategoryPath(String category, String path) {
    if (_customCategoryPaths.containsKey(category)) {
      _customCategoryPaths[category]!.remove(path);
      PreferencesService.saveCustomCategoryPaths(_customCategoryPaths);
      notifyListeners();
      loadMedia(forceRefresh: true);
    }
  }

  void excludeDefaultCategoryPath(String category, String path) {
    if (!_excludedDefaultPaths.containsKey(category)) {
      _excludedDefaultPaths[category] = [];
    }
    if (!_excludedDefaultPaths[category]!.contains(path)) {
      _excludedDefaultPaths[category]!.add(path);
      PreferencesService.saveExcludedDefaultPaths(_excludedDefaultPaths);
      notifyListeners();
      loadMedia(forceRefresh: true);
    }
  }

  void includeDefaultCategoryPath(String category, String path) {
    if (_excludedDefaultPaths.containsKey(category)) {
      if (_excludedDefaultPaths[category]!.remove(path)) {
        PreferencesService.saveExcludedDefaultPaths(_excludedDefaultPaths);
        notifyListeners();
        loadMedia(forceRefresh: true);
      }
    }
  }

  Future<void> _scanRecentFiles() async {
    final list = <FileSystemEntity>[];
    final seen = <String>{};

    final rootDir = Directory('/storage/emulated/0');
    if (await rootDir.exists()) {
      try {
        final List<String> pathsToScan = [];
        final rootEntities = await rootDir.list(recursive: false).toList();
        for (final entity in rootEntities) {
          if (entity is Directory) {
            final name = p.basename(entity.path);
            if (!name.startsWith('.') && name != 'Android') {
              pathsToScan.add(entity.path);
            }
          }
        }
        pathsToScan.addAll([
          '/storage/emulated/0/Android/media',
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Documents',
        ]);

        await Future.wait(pathsToScan.map((path) async {
          final dir = Directory(path);
          if (!await dir.exists()) return;
          try {
            final entities = await dir.list(recursive: false).toList();
            for (final entity in entities) {
              if (!seen.contains(entity.path)) {
                seen.add(entity.path);
                list.add(entity);
              }
              if (entity is Directory && !p.basename(entity.path).startsWith('.')) {
                try {
                  final sub = await entity.list(recursive: false).toList();
                  for (final s in sub) {
                    if (!seen.contains(s.path)) {
                      seen.add(s.path);
                      list.add(s);
                    }
                  }
                } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
              }
            }
          } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
        }));
      } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
    }

    void addFromList(List<FileSystemEntity> src) {
      for (final e in src) {
        if (!seen.contains(e.path)) {
          try {
            if (e is File && e.existsSync()) {
              seen.add(e.path);
              list.add(e);
            }
          } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
        }
      }
    }

    addFromList([..._downloads]);
    addFromList([..._documents]);
    addFromList([..._archives]);
    addFromList([..._apks]);

    for (final song in [..._audios, ..._fallbackAudios]) {
      final path = song.data;
      if (!seen.contains(path)) {
        seen.add(path);
        try {
          final f = File(path);
          if (await f.exists()) list.add(f);
        } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
      }
    }

    // Filter: remove parent dirs if a child also exists in the list
    final filteredList = <FileSystemEntity>[];
    for (final entity in list) {
      if (entity is Directory) {
        bool hasChild = list.any((o) => o.path != entity.path && p.isWithin(entity.path, o.path));
        if (hasChild) continue;
      }
      filteredList.add(entity);
    }

    final items = <FileItemModel>[];
    await Future.wait(filteredList.map((f) async {
      try {
        if (f is Directory) return;
        final name = p.basename(f.path);
        if (name.startsWith('.')) return;
        final stat = await f.stat();
        items.add(FileItemModel(
          entity: f,
          name: name,
          path: f.path,
          isDirectory: false,
          size: stat.size,
          modified: stat.modified,
        ));
      } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
    }));

    items.sort((a, b) => b.modified.compareTo(a.modified));
    _recentFiles = items.take(15).toList();
  }

  void setSortOrder(MediaSortOrder order) {
    _sortOrder = order;
    _applySort();
    notifyListeners();
  }

  void _applySort() {
    if (_sortOrder == MediaSortOrder.newest ||
        _sortOrder == MediaSortOrder.newestGrouped ||
        _sortOrder == MediaSortOrder.dateWise) {
      _images.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      _videos.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      _screenshots.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      _audios.sort(
          (a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
    } else if (_sortOrder == MediaSortOrder.oldest ||
               _sortOrder == MediaSortOrder.oldestGrouped) {
      _images.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
      _videos.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
      _screenshots.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
      _audios.sort(
          (a, b) => (a.dateAdded ?? 0).compareTo(b.dateAdded ?? 0));
    } else if (_sortOrder == MediaSortOrder.sizeLargest ||
               _sortOrder == MediaSortOrder.sizeSmallest) {
      final isSmallest = _sortOrder == MediaSortOrder.sizeSmallest;
      _images.sort((a, b) {
        final aRes = a.width * a.height;
        final bRes = b.width * b.height;
        return isSmallest ? aRes.compareTo(bRes) : bRes.compareTo(aRes);
      });
      _videos.sort((a, b) {
        final aRes = a.width * a.height;
        final bRes = b.width * b.height;
        return isSmallest ? aRes.compareTo(bRes) : bRes.compareTo(aRes);
      });
      _screenshots.sort((a, b) {
        final aRes = a.width * a.height;
        final bRes = b.width * b.height;
        return isSmallest ? aRes.compareTo(bRes) : bRes.compareTo(aRes);
      });
      _audios.sort((a, b) {
        final aSize = a.size;
        final bSize = b.size;
        return isSmallest ? aSize.compareTo(bSize) : bSize.compareTo(aSize);
      });
    }

    int fileSort(FileSystemEntity a, FileSystemEntity b) {
      try {
        final isSmallest = _sortOrder == MediaSortOrder.sizeSmallest;
        final isLargest = _sortOrder == MediaSortOrder.sizeLargest;

        if (isSmallest || isLargest) {
          final aSize = (a as File).lengthSync();
          final bSize = (b as File).lengthSync();
          return isSmallest ? aSize.compareTo(bSize) : bSize.compareTo(aSize);
        }

        final aTime = (a as File).lastModifiedSync();
        final bTime = (b as File).lastModifiedSync();
        return (_sortOrder == MediaSortOrder.oldest || _sortOrder == MediaSortOrder.oldestGrouped)
            ? aTime.compareTo(bTime)
            : bTime.compareTo(aTime);
      } catch (e, stackTrace) {
      // Error handled
        return 0;
      }
    }

    _documents.sort(fileSort);
    _archives.sort(fileSort);
    _downloads.sort(fileSort);
    _apks.sort(fileSort);
  }

  Future<void> deleteMediaItems({
    required List<String> filePaths,
    required List<String> assetIds,
  }) async {
    if (assetIds.isNotEmpty) {
      try {
        await PhotoManager.editor.deleteWithIds(assetIds);
      } catch (e) {
        debugPrint('Error deleting assets: $e');
      }
    }
    for (final path in filePaths) {
      try {
        final f = File(path);
        if (f.existsSync()) {
          f.deleteSync();
        }
      } catch (e, stackTrace) {
      // Log error silently
      // TODO: Add proper error logging
      }
    }

    // Local List Optimization - instant updates without full-disk scans
    if (assetIds.isNotEmpty) {
      _images.removeWhere((item) => assetIds.contains(item.id));
      _videos.removeWhere((item) => assetIds.contains(item.id));
      _screenshots.removeWhere((item) => assetIds.contains(item.id));
    }

    if (filePaths.isNotEmpty) {
      // In case any image/video matches by path/title
      _images.removeWhere((item) => filePaths.contains(item.title));
      _videos.removeWhere((item) => filePaths.contains(item.title));
      _screenshots.removeWhere((item) => filePaths.contains(item.title));

      _customImages.removeWhere((item) => filePaths.contains(item.path));
      _customVideos.removeWhere((item) => filePaths.contains(item.path));
      _customScreenshots.removeWhere((item) => filePaths.contains(item.path));

      _audios.removeWhere((item) => filePaths.contains(item.data));
      _documents.removeWhere((item) => filePaths.contains(item.path));
      _archives.removeWhere((item) => filePaths.contains(item.path));
      _downloads.removeWhere((item) => filePaths.contains(item.path));
      _apks.removeWhere((item) => filePaths.contains(item.path));
    }

    // Update Counts and Cache
    PreferencesService.saveCategoryCount('Images', images.length);
    PreferencesService.saveCategoryCount('Videos', videos.length);
    PreferencesService.saveCategoryCount('Audio', _audios.length);
    PreferencesService.saveCategoryCount('Documents', _documents.length);
    PreferencesService.saveCategoryCount('Archives', _archives.length);
    PreferencesService.saveCategoryCount('Downloads', _downloads.length);
    PreferencesService.saveCategoryCount('APKs', _apks.length);
    PreferencesService.saveCategoryCount('Screenshots', screenshots.length);

    await _saveCache();
    notifyListeners();
  }
}
