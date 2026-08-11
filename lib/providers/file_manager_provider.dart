import 'dart:io';
import 'dart:async';
import '../core/events/app_event_bus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/file_item_model.dart';
import '../models/folder_tab_model.dart';
import '../models/file_filter_type.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import '../ui/screens/image_viewer_screen.dart';
import '../ui/screens/video_player/video_player_screen.dart';
import '../ui/screens/audio_player/audio_player_screen.dart';
import '../ui/screens/text_editor_screen.dart';
import '../ui/screens/document_viewer_screen.dart';
import '../ui/screens/archive_viewer_screen.dart';
import '../ui/screens/database_reader_screen.dart';
import '../services/archive_service.dart';
import '../services/apk_installer_service.dart';
import '../ui/widgets/extract_archive_dialog.dart';
import '../core/utils.dart';
import '../services/preferences_service.dart';
import '../services/app_manager_service.dart';
import '../models/custom_shortcut_model.dart';
import '../services/root_shizuku_service.dart';
import '../services/recycle_bin_service.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../ui/widgets/open_with_sheet.dart';
import '../ui/widgets/conflict_dialog.dart';
import '../ui/widgets/file_action_dialogs.dart';
import '../services/background_archive_service.dart';
import '../services/pin_service.dart';
import '../models/network_connection_model.dart';
import '../services/remote/remote_client.dart';
import '../services/remote/ftp_client.dart';
import '../services/remote/sftp_client.dart';
import '../services/remote/webdav_client.dart';
import '../services/remote/lan_client.dart';
import '../services/remote/saf_client.dart';
import 'media_provider.dart';
import '../core/isolate_utils.dart';
import 'dart:typed_data';

part 'preferences_mixin.dart';

enum FileSortType {
  nameAsc,
  nameDesc,
  dateNewest,
  dateOldest,
  sizeLargest,
  sizeSmallest,
  type,
}

class StorageVolume {
  final String name;
  final String path;
  final bool isInternal;
  int totalBytes;
  int usedBytes;

  StorageVolume({
    required this.name,
    required this.path,
    required this.isInternal,
    this.totalBytes = 0,
    this.usedBytes = 0,
  });
}

/// Calcula el tamaño de un directorio de forma asíncrona usando Isolates
Future<int> calculateDirectorySize(String path) async {
  return await calculateDirectorySizeAsync(path);
}

class FileManagerProvider extends ChangeNotifier with PreferencesMixin {
  int _activeTabIndex = 0;
  List<FolderTab> _tabs = [FolderTab(id: 'default', currentPath: '/storage/emulated/0')];

  int get activeTabIndex => _activeTabIndex;
  
  @override
  FolderTab get activeTab => _tabs[_activeTabIndex];
  
  @override
  List<FileItemModel> get currentFiles => activeTab.currentFiles;
  
  @override
  String get currentPath => activeTab.currentPath;
  
  @override
  List<FolderTab> get tabs => _tabs;

  FileManagerProvider() {
    _sortType = PreferencesService.getSortType();
    _isGridView = PreferencesService.getIsGridView();
    _iconScale = PreferencesService.getIconScale();
    _itemPaddingMultiplier = PreferencesService.getItemPaddingMultiplier();
    _showHiddenFiles = PreferencesService.getShowHiddenFiles();
    _showFloatingAddButton = PreferencesService.getShowFloatingAddButton();
    _defaultToBrowseScreen = PreferencesService.getDefaultToBrowseScreen();
    _showFolderFileCount = PreferencesService.getShowFolderFileCount();
    _showBottomActionBar = PreferencesService.getShowBottomActionBar();
    _showHomeBrowseNav = PreferencesService.getShowHomeBrowseNav();
    _hideNavLabels = PreferencesService.getHideNavLabels();
    _showMediaPreviews = PreferencesService.getShowMediaPreviews();
    _enableMultipleTabs = PreferencesService.getEnableMultipleTabs();
    _enableSplitScreen = PreferencesService.getEnableSplitScreen();
    _accentColorOption = PreferencesService.getAccentColor();
    _fontFamilyOption = PreferencesService.getFontFamily();
    _customFontPath = PreferencesService.getCustomFontPath();
    _folderIconOption = PreferencesService.getFolderIconStyle();
    _menuIconStyle = PreferencesService.getMenuIconStyle();
    _pinnedFolderShortcuts = PreferencesService.getPinnedFolderShortcuts();
    _hideNavigationBar = PreferencesService.getHideNavigationBar();
    skipOpenWithDialog = PreferencesService.getSkipOpenWithDialog();
    _showAddressBar = PreferencesService.getShowAddressBar();
    _amoledMode = PreferencesService.getAmoledMode();
    _showRecentFiles = PreferencesService.getShowRecentFiles();
    _enableFolderHighlight = PreferencesService.getEnableFolderHighlight();
    _folderSortTypes = PreferencesService.getFolderSortTypes();
    _enableDragDrop = PreferencesService.getEnableDragDrop();
    _showDragDropDialog = PreferencesService.getShowDragDropDialog();
    _use24HourFormat = PreferencesService.getUse24HourFormat();
    _hideTimeAndDate = PreferencesService.getHideTimeAndDate();
    _showFolderContentsCount = PreferencesService.getShowFolderContentsCount();
    _showFolderSizes = PreferencesService.getShowFolderSizes();
    _adaptiveMultiLineNames = PreferencesService.getAdaptiveMultiLineNames();
    _hideActionMenuButtons = PreferencesService.getHideActionMenuButtons();
    _trailingInfoType = PreferencesService.getTrailingInfoType();
    _activeAppIcon = PreferencesService.getActiveAppIcon();
    _hideActionText = PreferencesService.getHideActionText();
    _disableLeftBackGesture = PreferencesService.getDisableLeftBackGesture();
    _rememberLastFolder = PreferencesService.getRememberLastFolder();
    _useMaterialIcons = PreferencesService.getUseMaterialIcons();
    _exitOption = PreferencesService.getExitOption();

    // One-time migration: reset PDF (and other documents) default open action to 'native' if it was set to 'external'
    if (!PreferencesService.getPdfResetDone()) {
      const docExts = ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.epub', '.odt'];
      for (final ext in docExts) {
        if (PreferencesService.getDefaultOpenAction(ext) == 'external') {
          PreferencesService.saveDefaultOpenAction(ext, 'native');
        }
      }
      PreferencesService.savePdfResetDone();
    }

    // Synchronously load cached storage sizes and pre-populate internal storage volume
    // to prevent any visual delay, shimmer, or refreshing animation on app startup!
    _totalStorageBytes = PreferencesService.getCachedTotalStorage();
    _usedStorageBytes = PreferencesService.getCachedUsedStorage();

    if (_totalStorageBytes > 0) {
      _storageVolumes = [
        StorageVolume(
          name: 'Internal Storage',
          path: '/storage/emulated/0',
          isInternal: true,
          totalBytes: _totalStorageBytes,
          usedBytes: _usedStorageBytes,
        )
      ];
    } else {
      _storageVolumes = [];
    }
  }

  final ValueNotifier<FileOperationProgress?> progressNotifier = ValueNotifier<FileOperationProgress?>(null);
  bool _isOperationCancelled = false;

  void cancelOperation() {
    _isOperationCancelled = true;
  }

  void reloadPreferences() {
    _sortType = PreferencesService.getSortType();
    _isGridView = PreferencesService.getIsGridView();
    _iconScale = PreferencesService.getIconScale();
    _itemPaddingMultiplier = PreferencesService.getItemPaddingMultiplier();
    _showHiddenFiles = PreferencesService.getShowHiddenFiles();
    _showFloatingAddButton = PreferencesService.getShowFloatingAddButton();
    _defaultToBrowseScreen = PreferencesService.getDefaultToBrowseScreen();
    _showFolderFileCount = PreferencesService.getShowFolderFileCount();
    _showBottomActionBar = PreferencesService.getShowBottomActionBar();
    _showHomeBrowseNav = PreferencesService.getShowHomeBrowseNav();
    _hideNavLabels = PreferencesService.getHideNavLabels();
    _showMediaPreviews = PreferencesService.getShowMediaPreviews();
    _enableMultipleTabs = PreferencesService.getEnableMultipleTabs();
    _enableSplitScreen = PreferencesService.getEnableSplitScreen();
    _accentColorOption = PreferencesService.getAccentColor();
    _fontFamilyOption = PreferencesService.getFontFamily();
    _customFontPath = PreferencesService.getCustomFontPath();
    _folderIconOption = PreferencesService.getFolderIconStyle();
    _menuIconStyle = PreferencesService.getMenuIconStyle();
    _pinnedFolderShortcuts = PreferencesService.getPinnedFolderShortcuts();
    _hideNavigationBar = PreferencesService.getHideNavigationBar();
    skipOpenWithDialog = PreferencesService.getSkipOpenWithDialog();
    _showAddressBar = PreferencesService.getShowAddressBar();
    _amoledMode = PreferencesService.getAmoledMode();
    _showRecentFiles = PreferencesService.getShowRecentFiles();
    _enableFolderHighlight = PreferencesService.getEnableFolderHighlight();
    _folderSortTypes = PreferencesService.getFolderSortTypes();
    _enableDragDrop = PreferencesService.getEnableDragDrop();
    _showDragDropDialog = PreferencesService.getShowDragDropDialog();
    _use24HourFormat = PreferencesService.getUse24HourFormat();
    _hideTimeAndDate = PreferencesService.getHideTimeAndDate();
    _showFolderContentsCount = PreferencesService.getShowFolderContentsCount();
    _showFolderSizes = PreferencesService.getShowFolderSizes();
    _adaptiveMultiLineNames = PreferencesService.getAdaptiveMultiLineNames();
    _hideActionMenuButtons = PreferencesService.getHideActionMenuButtons();
    _trailingInfoType = PreferencesService.getTrailingInfoType();
    _activeAppIcon = PreferencesService.getActiveAppIcon();
    _hideActionText = PreferencesService.getHideActionText();
    _disableLeftBackGesture = PreferencesService.getDisableLeftBackGesture();
    _rememberLastFolder = PreferencesService.getRememberLastFolder();
    _useMaterialIcons = PreferencesService.getUseMaterialIcons();
    _exitOption = PreferencesService.getExitOption();
    notifyListeners();
  }

  Future<void> loadDirectory(String path, {bool showLoading = true, bool clearCache = false}) async {
    deactivateSearchForTab(activeTab);
    // Normalize legacy sdcard paths to canonical /storage/emulated/0
    String resolvedPath = path.replaceAll(RegExp(r'/+'), '/');
    if (resolvedPath.startsWith('/sdcard')) {
      resolvedPath = resolvedPath.replaceFirst('/sdcard', '/storage/emulated/0');
    } else if (resolvedPath.startsWith('/mnt/sdcard')) {
      resolvedPath = resolvedPath.replaceFirst('/mnt/sdcard', '/storage/emulated/0');
    }
    path = resolvedPath;

    if (clearCache) {
      clearFolderItemCountsCache();
    }
    if (currentPath != path) {
      highlightedPaths.clear();
    }
    if (_storageVolumes.isEmpty) {
      _detectStorageVolumes();
    }

    if (showLoading) {
      activeTab.isLoading = true;
      notifyListeners();
    }

    activeTab.isRestrictedMode = isRestrictedPath(path);

    if (activeTab.isRestrictedMode) {
      final status = await RootShizukuService.checkStatus();
      activeTab.isRootAvailable = status.isRootAvailable;
      if (status.isRootAvailable && (activeTab.useRootMode || !status.isShizukuAvailable)) {
        activeTab.useRootMode = true;
        activeTab.useShizukuMode = false;
        activeTab.needsPermission = false;
      } else if (status.isShizukuAvailable && status.shizukuPermissionGranted) {
        activeTab.useShizukuMode = true;
        activeTab.useRootMode = false;
        activeTab.needsPermission = false;
      } else {
        activeTab.needsPermission = true;
        activeTab.currentPath = path;
        activeTab.currentFiles = [];
        activeTab.isLoading = false;
        notifyListeners();
        return;
      }

      try {
        activeTab.currentPath = path;
        final items = await RootShizukuService.listFiles(path, useRoot: activeTab.useRootMode, showHiddenFiles: _showHiddenFiles);
        final folders = items.where((e) => e.isDirectory).toList();
        final files = items.where((e) => !e.isDirectory).toList();

        final filteredFiles = _filterType == FileFilterType.all
            ? files
            : files.where((e) => _matchesFilter(e.path)).toList();
        final filteredFolders = (_filterType != FileFilterType.all && _hideFoldersInFilter) ? <FileItemModel>[] : folders;

        sortList(filteredFolders, path);
        sortList(filteredFiles, path);
        activeTab.currentFiles = [...filteredFolders, ...filteredFiles];
      } catch (e) {
        debugPrint('Error loading restricted directory: $e');
        activeTab.currentFiles = [];
      }
      activeTab.isLoading = false;
      notifyListeners();
      return;
    }

    activeTab.needsPermission = false;
    activeTab.useRootMode = false;
    activeTab.useShizukuMode = false;

    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        activeTab.currentPath = path;
        final entities = await dir.list().toList();
        
        final folders = <FileItemModel>[];
        final files = <FileItemModel>[];

        final items = await Future.wait(entities.map((e) => FileItemModel.fromEntityAsync(e)));

        for (var item in items) {
          if (!_showHiddenFiles && item.isHidden) {
            continue;
          }
          if (item.isDirectory) {
            folders.add(item);
          } else {
            files.add(item);
          }
        }

        final filteredFiles = _filterType == FileFilterType.all
            ? files
            : files.where((e) => _matchesFilter(e.path)).toList();
        final filteredFolders = (_filterType != FileFilterType.all && _hideFoldersInFilter) ? <FileItemModel>[] : folders;

        sortList(filteredFolders, path);
        sortList(filteredFiles, path);

        activeTab.currentFiles = [...filteredFolders, ...filteredFiles];
      }
    } catch (e) {
      debugPrint('Error loading directory: $e. Fallback to restricted mode.');
      // Auto fallback to restricted mode
      activeTab.isRestrictedMode = true;
      final status = await RootShizukuService.checkStatus();
      activeTab.isRootAvailable = status.isRootAvailable;
      if (status.isRootAvailable && (activeTab.useRootMode || !status.isShizukuAvailable)) {
        activeTab.useRootMode = true;
        activeTab.useShizukuMode = false;
        activeTab.needsPermission = false;
      } else if (status.isShizukuAvailable && status.shizukuPermissionGranted) {
        activeTab.useShizukuMode = true;
        activeTab.useRootMode = false;
        activeTab.needsPermission = false;
      } else {
        activeTab.needsPermission = true;
        activeTab.currentPath = path;
        activeTab.currentFiles = [];
        activeTab.isLoading = false;
        notifyListeners();
        return;
      }

      try {
        activeTab.currentPath = path;
        final items = await RootShizukuService.listFiles(path, useRoot: activeTab.useRootMode, showHiddenFiles: _showHiddenFiles);
        final folders = items.where((e) => e.isDirectory).toList();
        final files = items.where((e) => !e.isDirectory).toList();

        final filteredFiles = _filterType == FileFilterType.all
            ? files
            : files.where((e) => _matchesFilter(e.path)).toList();
        final filteredFolders = (_filterType != FileFilterType.all && _hideFoldersInFilter) ? <FileItemModel>[] : folders;

        sortList(filteredFolders, path);
        sortList(filteredFiles, path);
        activeTab.currentFiles = [...filteredFolders, ...filteredFiles];
      } catch (err) {
        debugPrint('Error loading restricted directory fallback: $err');
        activeTab.currentFiles = [];
      }
    }

    activeTab.isLoading = false;
    _persistTabs();
    notifyListeners();
  }

  Future<bool> goBack() async {
    if (!canGoBack) return false;
    final exitedPath = currentPath;
    final parent = p.dirname(currentPath);
    await loadDirectory(parent, showLoading: false);
    highlightedPaths.clear();
    highlightedPaths.add(exitedPath);
    notifyListeners();
    Timer(const Duration(milliseconds: 2000), () {
      if (highlightedPaths.remove(exitedPath)) {
        notifyListeners();
      }
    });
    return true;
  }

  void toggleSelection(String path) {
    if (selectedPaths.contains(path)) {
      selectedPaths.remove(path);
    } else {
      selectedPaths.add(path);
    }
    notifyListeners();
  }

  void selectAll() {
    selectedPaths.clear();
    selectedPaths.addAll(currentFiles.map((f) => f.path));
    notifyListeners();
  }

  void clearSelection() {
    selectedPaths.clear();
    notifyListeners();
  }

  Future<void> togglePinPath(String path) async {
    await PinService.togglePin(path);
    final folders = currentFiles.where((e) => e.isDirectory).toList();
    final files = currentFiles.where((e) => !e.isDirectory).toList();
    sortList(folders, currentPath);
    sortList(files, currentPath);
    activeTab.currentFiles = [...folders, ...files];
    notifyListeners();
  }

  void refreshDirectoryView() {
    final folders = currentFiles.where((e) => e.isDirectory).toList();
    final files = currentFiles.where((e) => !e.isDirectory).toList();
    sortList(folders, currentPath);
    sortList(files, currentPath);
    activeTab.currentFiles = [...folders, ...files];
    notifyListeners();
  }

  void copyFile(String path) {
    setClipboard([path], isCut: false);
  }

  void cutFile(String path) {
    setClipboard([path], isCut: true);
  }

  void copySelected() {
    if (selectedPaths.isEmpty) return;
    setClipboard(selectedPaths.toList(), isCut: false);
    selectedPaths.clear();
    notifyListeners();
  }

  void cutSelected() {
    if (selectedPaths.isEmpty) return;
    setClipboard(selectedPaths.toList(), isCut: true);
    selectedPaths.clear();
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    if (selectedPaths.isEmpty) return;

    activeTab.isLoading = true;
    notifyListeners();

    try {
      if (RecycleBinService.isEnabled()) {
        for (final path in selectedPaths) {
          await RecycleBinService.moveToTrash(path, useRoot: useRootMode);
        }
      } else {
        for (final path in selectedPaths) {
          if (isRestrictedPath(path)) {
            await RootShizukuService.deleteItem(path, useRoot: useRootMode);
          } else {
            await deleteFileAsync(path);
          }
        }
      }
    } catch (e) {
      debugPrint('Error deleting selected files: $e');
    }

    selectedPaths.clear();
    activeTab.isLoading = false;
    await loadDirectory(currentPath, showLoading: false, clearCache: true);
  }

  Future<void> pasteFile(BuildContext context, {bool clearAfterPaste = true}) async {
    if (clipboardPaths.isEmpty && !isRemoteClipboard) return;

    if (isRemoteClipboard) {
      await _pasteFromRemoteToLocal(context, clearAfterPaste);
      return;
    }

    _isOperationCancelled = false;
    activeTab.isLoading = true;
    notifyListeners();

    final useRootMode = activeTab.useRootMode;
    if (isRestrictedPath(currentPath) || clipboardPaths.any((p) => isRestrictedPath(p))) {
      try {
        for (final srcPath in clipboardPaths) {
          final name = p.basename(srcPath);
          final destPath = p.join(currentPath, name);
          if (isCut) {
            await RootShizukuService.moveItem(srcPath, destPath, useRoot: useRootMode);
          } else {
            await RootShizukuService.copyItem(srcPath, destPath, useRoot: useRootMode);
          }
        }
        
        AppEventBus.instance.fire(FileOperationSuccessEvent(
          operationType: isCut ? 'move' : 'copy',
          message: isCut ? 'Moved items successfully' : 'Copied items successfully'
        ));
      } catch (e) {
        debugPrint('Error pasting inside restricted directory: $e');
        AppEventBus.instance.fire(FileOperationErrorEvent(
          operationType: isCut ? 'move' : 'copy',
          errorMessage: 'Failed to transfer: $e'
        ));
      }
      if (clearAfterPaste) {
        clearClipboard();
      }
      activeTab.isLoading = false;
      await loadDirectory(currentPath, showLoading: false, clearCache: true);
      notifyListeners();
      return;
    }

    try {
      // 1. Calculate total size and gather all files
      int totalBytes = 0;
      final List<Map<String, dynamic>> itemsToProcess = [];

      for (final srcPath in clipboardPaths) {
        final type = FileSystemEntity.typeSync(srcPath);
        final isSameFolder = p.dirname(srcPath) == currentPath;

        if (isSameFolder && isCut) {
          if (context.mounted) {
            await FileActionDialogs.showWarningDialog(
              context,
              title: 'Operation Cancelled',
              content: 'Cannot cut and paste a file into the same folder.',
            );
          }
          clearClipboard();
          activeTab.isLoading = false;
          notifyListeners();
          return;
        }

        if (type == FileSystemEntityType.file) {
          final file = File(srcPath);
          final size = file.lengthSync();
          totalBytes += size;
          
          String destPath = p.join(currentPath, p.basename(srcPath));
          if (isSameFolder && !isCut) {
            destPath = _getCopyUniquePath(destPath, false);
          }

          itemsToProcess.add({
            'source': file,
            'destPath': destPath,
            'size': size,
            'isDir': false,
          });
        } else if (type == FileSystemEntityType.directory) {
          final dir = Directory(srcPath);
          
          String topDestPath = p.join(currentPath, p.basename(srcPath));
          if (isSameFolder && !isCut) {
            topDestPath = _getCopyUniquePath(topDestPath, true);
          }

          itemsToProcess.add({
            'source': dir,
            'destPath': topDestPath,
            'size': 0,
            'isDir': true,
          });

          try {
            final entities = dir.listSync(recursive: true, followLinks: false);
            for (final entity in entities) {
              final relPath = p.relative(entity.path, from: srcPath);
              final destPath = p.join(topDestPath, relPath);
              
              if (entity is Directory) {
                itemsToProcess.add({
                  'source': entity,
                  'destPath': destPath,
                  'size': 0,
                  'isDir': true,
                });
              } else if (entity is File) {
                final size = entity.lengthSync();
                totalBytes += size;
                itemsToProcess.add({
                  'source': entity,
                  'destPath': destPath,
                  'size': size,
                  'isDir': false,
                });
              }
            }
          } catch (_) {}
        }
      }

      // 2. Initialize progress tracking variables
      int bytesProcessed = 0;
      final stopwatch = Stopwatch()..start();
      final totalFiles = itemsToProcess.length;

      progressNotifier.value = FileOperationProgress(
        totalFiles: totalFiles,
        currentFileIndex: 1,
        currentFileName: 'Starting...',
        percentage: 0.0,
        speedMBs: 0.0,
        eta: Duration.zero,
        totalBytes: totalBytes > 0 ? totalBytes : 1,
        bytesProcessed: 0,
      );

      ConflictResult? cachedResolution;
      final Set<String> skippedPaths = {};
      final List<String> finalTopLevelDestPaths = [];

      // 3. Process items sequentially
      for (int i = 0; i < itemsToProcess.length; i++) {
        if (_isOperationCancelled) {
          throw Exception('Cancelled');
        }

        final item = itemsToProcess[i];
        final source = item['source'];
        String destPath = item['destPath'];
        final int size = item['size'];
        final bool isDir = item['isDir'];

        final fileName = p.basename(source.path);

        // Check if this item is within a skipped directory tree
        bool isSkipped = false;
        for (final skipped in skippedPaths) {
          if (p.isWithin(skipped, destPath) || destPath == skipped) {
            isSkipped = true;
            break;
          }
        }

        if (isSkipped) {
          if (!isDir) {
            totalBytes -= size;
          }
          continue;
        }

        String finalDestPath = destPath;
        bool shouldProcess = true;

        // Check if there is a conflict
        final destExists = FileSystemEntity.typeSync(destPath) != FileSystemEntityType.notFound;
        if (destExists) {
          ConflictDialogResponse? response;
          ConflictResult? resolution = cachedResolution;

          if (resolution == null) {
            if (context.mounted) {
              response = await ConflictDialog.show(
                context,
                fileName: fileName,
                sourceFile: File(source.path),
                destFile: File(destPath),
              );

              if (response != null) {
                resolution = response.result;
                if (response.applyToAll &&
                    (resolution == ConflictResult.overwrite ||
                     resolution == ConflictResult.keepBoth ||
                     resolution == ConflictResult.skip)) {
                  cachedResolution = resolution;
                }
              } else {
                resolution = ConflictResult.cancel;
              }
            } else {
              resolution = ConflictResult.cancel;
            }
          }

          if (resolution == ConflictResult.cancel) {
            throw Exception('Cancelled');
          } else if (resolution == ConflictResult.skip) {
            shouldProcess = false;
            skippedPaths.add(destPath);
          } else if (resolution == ConflictResult.keepBoth) {
            finalDestPath = _getUniquePath(destPath, isDir);
            if (isDir) {
              _updateSubsequentDestPaths(itemsToProcess, i + 1, destPath, finalDestPath);
            }
          } else if (resolution == ConflictResult.rename) {
            final customName = response?.customName ?? fileName;
            finalDestPath = p.join(p.dirname(destPath), customName);
            finalDestPath = _getUniquePath(finalDestPath, isDir);
            if (isDir) {
              _updateSubsequentDestPaths(itemsToProcess, i + 1, destPath, finalDestPath);
            }
          } else if (resolution == ConflictResult.overwrite) {
            // Overwrite: we do nothing to the path. If it's a file, it will overwrite it.
            // If it's a folder, it will merge it.
          }
        }

        if (!shouldProcess) {
          if (!isDir) {
            totalBytes -= size;
          }
          continue;
        }

        final isTopLevel = clipboardPaths.contains(source.path);
        if (isTopLevel) {
          finalTopLevelDestPaths.add(finalDestPath);
        }

        double basePercent = totalBytes > 0 ? (bytesProcessed / totalBytes) : (i / totalFiles);
        progressNotifier.value = FileOperationProgress(
          totalFiles: totalFiles,
          currentFileIndex: i + 1,
          currentFileName: fileName,
          percentage: basePercent,
          speedMBs: stopwatch.elapsedMilliseconds > 0 
              ? (bytesProcessed / (1024 * 1024)) / (stopwatch.elapsed.inMilliseconds / 1000.0)
              : 0.0,
          eta: Duration.zero,
          totalBytes: totalBytes > 0 ? totalBytes : 1,
          bytesProcessed: bytesProcessed,
        );

        if (isDir) {
          final destDir = Directory(finalDestPath);
          if (!destDir.existsSync()) {
            await destDir.create(recursive: true);
          }
        } else {
          final parentDir = Directory(p.dirname(finalDestPath));
          if (!parentDir.existsSync()) {
            await parentDir.create(recursive: true);
          }

          final srcFile = source as File;
          final destFile = File(finalDestPath);

          if (isCut) {
            try {
              if (destFile.existsSync()) {
                await destFile.delete();
              }
              await srcFile.rename(finalDestPath);
              bytesProcessed += size;
            } catch (_) {
              await _copyFileWithProgress(
                srcFile,
                destFile,
                onChunkCopied: (chunkSize) {
                  bytesProcessed += chunkSize;
                  final elapsedSeconds = stopwatch.elapsed.inMilliseconds / 1000.0;
                  final speed = elapsedSeconds > 0 ? (bytesProcessed / (1024 * 1024)) / elapsedSeconds : 0.0;
                  final remainingBytes = totalBytes - bytesProcessed;
                  final etaSeconds = speed > 0 ? (remainingBytes / (1024 * 1024)) / speed : 0.0;

                  progressNotifier.value = FileOperationProgress(
                    totalFiles: totalFiles,
                    currentFileIndex: i + 1,
                    currentFileName: fileName,
                    percentage: totalBytes > 0 ? (bytesProcessed / totalBytes) : (i / totalFiles),
                    speedMBs: speed,
                    eta: Duration(seconds: etaSeconds.round()),
                    totalBytes: totalBytes > 0 ? totalBytes : 1,
                    bytesProcessed: bytesProcessed,
                  );
                },
              );
              await srcFile.delete();
            }
          } else {
            await _copyFileWithProgress(
              srcFile,
              destFile,
              onChunkCopied: (chunkSize) {
                bytesProcessed += chunkSize;
                final elapsedSeconds = stopwatch.elapsed.inMilliseconds / 1000.0;
                final speed = elapsedSeconds > 0 ? (bytesProcessed / (1024 * 1024)) / elapsedSeconds : 0.0;
                final remainingBytes = totalBytes - bytesProcessed;
                final etaSeconds = speed > 0 ? (remainingBytes / (1024 * 1024)) / speed : 0.0;

                progressNotifier.value = FileOperationProgress(
                  totalFiles: totalFiles,
                  currentFileIndex: i + 1,
                  currentFileName: fileName,
                  percentage: totalBytes > 0 ? (bytesProcessed / totalBytes) : (i / totalFiles),
                  speedMBs: speed,
                  eta: Duration(seconds: etaSeconds.round()),
                  totalBytes: totalBytes > 0 ? totalBytes : 1,
                  bytesProcessed: bytesProcessed,
                );
              },
            );
          }
        }
      }

      if (isCut) {
        for (final srcPath in clipboardPaths) {
          final type = FileSystemEntity.typeSync(srcPath);
          if (type == FileSystemEntityType.directory) {
            final dir = Directory(srcPath);
            if (dir.existsSync()) {
              await dir.delete(recursive: true);
            }
          }
        }
      }

      if (isCut && sourceArchiveForCut != null && internalSourcePathsForCut != null) {
        await ArchiveService.deleteItemsFromArchive(
          archivePath: sourceArchiveForCut!,
          internalPathsToDelete: internalSourcePathsForCut!,
        );
      }
      
      if (clearAfterPaste) {
        clearClipboard();
      }
      
      highlightedPaths.clear();
      highlightedPaths.addAll(finalTopLevelDestPaths);
      shouldScrollToHighlight = true;

      Timer(const Duration(milliseconds: 2000), () {
        bool changed = false;
        for (final path in finalTopLevelDestPaths) {
          if (highlightedPaths.remove(path)) {
            changed = true;
          }
        }
        if (changed) {
          notifyListeners();
        }
      });

    } catch (e) {
      debugPrint('Error pasting file: $e');
    } finally {
      progressNotifier.value = null;
      activeTab.isLoading = false;
      await loadDirectory(currentPath, showLoading: false, clearCache: true);
      notifyListeners();
    }
  }

  Future<void> _pasteFromRemoteToLocal(BuildContext context, bool clearAfterPaste) async {
    final conn = remoteClipboardConnection;
    if (conn == null) {
      activeTab.isLoading = false;
      notifyListeners();
      return;
    }

    RemoteClient? client;
    if (conn.type == 'FTP') {
      client = FtpRemoteClient(host: conn.host, port: conn.port, username: conn.username, password: conn.password);
    } else if (conn.type == 'SFTP') {
      client = SftpRemoteClient(host: conn.host, port: conn.port, username: conn.username, password: conn.password);
    } else if (conn.type == 'WebDav') {
      client = WebDavRemoteClient(
        host: conn.host,
        port: conn.port,
        username: conn.username,
        password: conn.password,
        protocol: conn.protocol,
        rootPath: conn.rootPath,
      );
    } else if (conn.type == 'LAN/SMB') {
      client = LanClient(host: conn.host, port: conn.port, username: conn.username, password: conn.password);
    } else if (conn.type == 'saf') {
      client = SafRemoteClient(rootUri: conn.rootPath);
    }

    if (client == null) {
      activeTab.isLoading = false;
      notifyListeners();
      return;
    }

    try {
      await client.connect();
    } catch (e) {
      debugPrint('Failed to connect to remote server for paste: $e');
      AppEventBus.instance.fire(FileOperationErrorEvent(
        operationType: 'remote_connect',
        errorMessage: 'Failed to connect to remote server: $e'
      ));
      activeTab.isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final totalFiles = remoteClipboardItems.length;
      progressNotifier.value = FileOperationProgress(
        totalFiles: totalFiles,
        currentFileIndex: 1,
        currentFileName: 'Connecting...',
        percentage: 0.0,
        speedMBs: 0.0,
        eta: Duration.zero,
        totalBytes: 1,
        bytesProcessed: 0,
      );

      final targetPath = currentPath;

      for (int i = 0; i < remoteClipboardItems.length; i++) {
        if (_isOperationCancelled) {
          throw Exception('Cancelled');
        }

        final remoteItem = remoteClipboardItems[i];
        final destPath = p.join(targetPath, remoteItem.name);

        progressNotifier.value = FileOperationProgress(
          totalFiles: totalFiles,
          currentFileIndex: i + 1,
          currentFileName: remoteItem.name,
          percentage: (i / totalFiles),
          speedMBs: 0.0,
          eta: Duration.zero,
          totalBytes: totalFiles,
          bytesProcessed: i,
        );

        if (remoteItem.isDirectory) {
          await _downloadRemoteDirectory(client, remoteItem.path, destPath);
        } else {
          await client.downloadFile(remoteItem.path, destPath, (prog) {
            progressNotifier.value = FileOperationProgress(
              totalFiles: totalFiles,
              currentFileIndex: i + 1,
              currentFileName: remoteItem.name,
              percentage: (i + prog) / totalFiles,
              speedMBs: 0.0,
              eta: Duration.zero,
              totalBytes: totalFiles,
              bytesProcessed: i,
            );
          });
        }

        if (isCut) {
          try {
            await client.delete(remoteItem.path, remoteItem.isDirectory);
          } catch (e) {
            debugPrint('Failed to delete remote item after cut: $e');
          }
        }
      }

      AppEventBus.instance.fire(FileOperationSuccessEvent(
        operationType: isCut ? 'move' : 'copy',
        message: isCut ? 'Moved items successfully' : 'Copied items successfully'
      ));
    } catch (e) {
      debugPrint('Error pasting from remote: $e');
      AppEventBus.instance.fire(FileOperationErrorEvent(
        operationType: isCut ? 'move' : 'copy',
        errorMessage: e.toString().contains('Cancelled') ? 'Operation Cancelled' : 'Transfer failed: $e'
      ));
    } finally {
      try {
        await client.disconnect();
      } catch (_) {}
      progressNotifier.value = null;
      if (clearAfterPaste) {
        clearClipboard();
      }
      activeTab.isLoading = false;
      await loadDirectory(currentPath, showLoading: false, clearCache: true);
      notifyListeners();
    }
  }

  Future<void> _downloadRemoteDirectory(RemoteClient client, String remoteDirPath, String localDirPath) async {
    final localDir = Directory(localDirPath);
    if (!localDir.existsSync()) {
      localDir.createSync(recursive: true);
    }

    final List<RemoteFileItem> remoteItems = await client.listDirectory(remoteDirPath);
    for (final item in remoteItems) {
      if (_isOperationCancelled) {
        throw Exception('Cancelled');
      }
      final destPath = p.join(localDirPath, item.name);
      if (item.isDirectory) {
        await _downloadRemoteDirectory(client, item.path, destPath);
      } else {
        await client.downloadFile(item.path, destPath, (prog) {});
      }
    }
  }

  String _getUniquePath(String destPath, bool isDir) {
    if (isDir) {
      if (!Directory(destPath).existsSync()) return destPath;
      int counter = 1;
      String parent = p.dirname(destPath);
      String base = p.basename(destPath);
      while (true) {
        final candidate = p.join(parent, '$base ($counter)');
        if (!Directory(candidate).existsSync()) {
          return candidate;
        }
        counter++;
      }
    } else {
      if (!File(destPath).existsSync()) return destPath;
      int counter = 1;
      String parent = p.dirname(destPath);
      String ext = p.extension(destPath);
      String base = p.basenameWithoutExtension(destPath);
      while (true) {
        final candidate = p.join(parent, '$base ($counter)$ext');
        if (!File(candidate).existsSync()) {
          return candidate;
        }
        counter++;
      }
    }
  }

  String _getCopyUniquePath(String destPath, bool isDir) {
    String parent = p.dirname(destPath);
    if (isDir) {
      String base = p.basename(destPath);
      String copyBase = '$base (copy)';
      if (!Directory(p.join(parent, copyBase)).existsSync()) {
        return p.join(parent, copyBase);
      }
      int counter = 1;
      while (true) {
        final candidate = p.join(parent, '$copyBase ($counter)');
        if (!Directory(candidate).existsSync()) {
          return candidate;
        }
        counter++;
      }
    } else {
      String ext = p.extension(destPath);
      String base = p.basenameWithoutExtension(destPath);
      String copyBase = '$base (copy)';
      if (!File(p.join(parent, '$copyBase$ext')).existsSync()) {
        return p.join(parent, '$copyBase$ext');
      }
      int counter = 1;
      while (true) {
        final candidate = p.join(parent, '$copyBase ($counter)$ext');
        if (!File(candidate).existsSync()) {
          return candidate;
        }
        counter++;
      }
    }
  }

  void _updateSubsequentDestPaths(List<Map<String, dynamic>> items, int startIndex, String oldParentPath, String newParentPath) {
    for (int j = startIndex; j < items.length; j++) {
      final subDest = items[j]['destPath'] as String;
      if (p.isWithin(oldParentPath, subDest) || subDest == oldParentPath) {
        final relativePart = p.relative(subDest, from: oldParentPath);
        items[j]['destPath'] = p.join(newParentPath, relativePart);
      }
    }
  }

  Future<void> _copyFileWithProgress(
    File source,
    File destination, {
    required Function(int chunkSize) onChunkCopied,
  }) async {
    final reader = source.openRead();
    final writer = destination.openWrite();

    try {
      await for (final chunk in reader) {
        if (_isOperationCancelled) {
          await writer.close();
          if (await destination.exists()) {
            await destination.delete();
          }
          throw Exception('Cancelled');
        }
        writer.add(chunk);
        onChunkCopied(chunk.length);
      }
    } finally {
      await writer.close();
    }
  }

  Future<void> deleteFile(String path) async {
    try {
      if (RecycleBinService.isEnabled()) {
        await RecycleBinService.moveToTrash(path, useRoot: useRootMode);
      } else {
        if (isRestrictedPath(path)) {
          await RootShizukuService.deleteItem(path, useRoot: useRootMode);
        } else {
          await deleteFileAsync(path);
        }
      }
      await loadDirectory(currentPath, showLoading: false, clearCache: true);
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  Future<void> renameFile(String oldPath, String newName) async {
    try {
      if (isRestrictedPath(oldPath)) {
        await RootShizukuService.renameItem(oldPath, newName, useRoot: useRootMode);
      } else {
        final newPath = p.join(p.dirname(oldPath), newName);
        final type = FileSystemEntity.typeSync(oldPath);
        if (type == FileSystemEntityType.directory) {
          await Directory(oldPath).rename(newPath);
        } else {
          await File(oldPath).rename(newPath);
        }
      }
      await loadDirectory(currentPath, showLoading: false, clearCache: true);
    } catch (e) {
      debugPrint('Error renaming file: $e');
    }
  }

  Future<String?> createFolder(String name) async {
    try {
      String finalName = name;
      final targetPath = p.join(currentPath, name);
      if (FileSystemEntity.typeSync(targetPath) != FileSystemEntityType.notFound) {
        final uniquePath = _getUniquePath(targetPath, true);
        finalName = p.basename(uniquePath);
      }
      if (isRestrictedPath(currentPath)) {
        await RootShizukuService.createFolder(currentPath, finalName, useRoot: useRootMode);
      } else {
        final newPath = p.join(currentPath, finalName);
        await Directory(newPath).create();
      }
      await loadDirectory(currentPath, showLoading: false, clearCache: true);
      return finalName;
    } catch (e) {
      debugPrint('Error creating folder: $e');
      return null;
    }
  }

  Future<String?> createFile(String name) async {
    try {
      String finalName = name;
      final targetPath = p.join(currentPath, name);
      if (FileSystemEntity.typeSync(targetPath) != FileSystemEntityType.notFound) {
        final uniquePath = _getUniquePath(targetPath, false);
        finalName = p.basename(uniquePath);
      }
      if (isRestrictedPath(currentPath)) {
        await RootShizukuService.createFile(currentPath, finalName, useRoot: useRootMode);
      } else {
        final newPath = p.join(currentPath, finalName);
        await File(newPath).create();
      }
      await loadDirectory(currentPath, showLoading: false, clearCache: true);
      return finalName;
    } catch (e) {
      debugPrint('Error creating file: $e');
      return null;
    }
  }

  Future<void> updateFileInList(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final stat = await file.stat();
        bool updated = false;
        for (var tab in _tabs) {
          final index = tab.currentFiles.indexWhere((item) => item.path == filePath);
          if (index != -1) {
            final oldItem = tab.currentFiles[index];
            tab.currentFiles[index] = FileItemModel(
              entity: oldItem.entity,
              name: oldItem.name,
              path: oldItem.path,
              isDirectory: oldItem.isDirectory,
              size: stat.size,
              modified: stat.modified,
            );
            updated = true;
          }
        }
        if (updated) {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error updating file in list: $e');
    }
  }

  Future<void> createArchive({
    required String archiveName,
    required String format,
    required int compressionLevel,
    String? password,
    int? splitSizeMB,
    required bool deleteSource,
    required bool separateArchives,
    List<String>? targetPaths,
    BuildContext? context,
  }) async {
    final paths = targetPaths ?? (selectedPaths.isNotEmpty ? selectedPaths.toList() : [currentPath]);

    // Check size limit for TAR.LZ4 and TAR.ZSTD
    if (format == 'tar.lz4' || format == 'tar.zst') {
      final totalSize = await _calculateTotalSize(paths);
      if (totalSize > 600 * 1024 * 1024) {
        if (context != null && context.mounted) {
          await FileActionDialogs.showWarningDialog(
            context,
            title: 'Compression Limit Exceeded',
            content: 'TAR.ZSTD and TAR.LZ4 formats are highly memory-intensive and optimized for files under 600MB. Please use the ZIP or TAR format for larger files.',
          );
        }
        selectedPaths.clear();
        notifyListeners();
        return;
      }
    }

    activeTab.isLoading = true;
    notifyListeners();

    if (context != null) {
      selectedPaths.clear();
      final destinationPath = p.join(currentPath, '$archiveName.$format');
      await BackgroundArchiveService.instance.startCompression(
        context: context,
        sourcePaths: paths,
        destinationPath: destinationPath,
        format: format,
        level: compressionLevel,
        deleteSource: deleteSource,
      );
    } else {
      try {
        await ArchiveService.createArchive(
          sourcePaths: paths,
          destinationDir: currentPath,
          archiveName: archiveName,
          format: format,
          compressionLevel: compressionLevel,
          password: password,
          splitSizeMB: splitSizeMB,
          deleteSource: deleteSource,
          separateArchives: separateArchives,
        );
      } catch (e) {
        debugPrint('Error creating archive: $e');
      }

      selectedPaths.clear();
      await loadDirectory(currentPath, showLoading: false, clearCache: true);
    }
  }

  Future<int> _calculateTotalSize(List<String> paths) async {
    int total = 0;
    for (final path in paths) {
      try {
        final type = FileSystemEntity.typeSync(path);
        if (type == FileSystemEntityType.file) {
          total += File(path).lengthSync();
        } else if (type == FileSystemEntityType.directory) {
          final dir = Directory(path);
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              total += entity.lengthSync();
            }
          }
        }
      } catch (e) {
        debugPrint('Error calculating size for $path: $e');
      }
    }
    return total;
  }

  Future<void> extractArchiveDirectly(BuildContext context, String path) async {
    final destDir = p.join(p.dirname(path), p.basenameWithoutExtension(path));
    final res = await ExtractArchiveDialog.show(context, archiveName: p.basename(path), defaultDestDir: destDir);
    if (res != null && context.mounted) {
      await BackgroundArchiveService.instance.startExtraction(
        context: context,
        archivePath: path,
        destinationDir: res.destinationDir,
        password: res.password,
      );
    }
  }

  bool hasNativeViewer(String path) {
    final mimeType = lookupMimeType(path) ?? '';
    final ext = p.extension(path).toLowerCase();
    const docExts = ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.epub', '.odt'];
    
    if (FileUtils.isArchive(path)) return true;
    if (mimeType.startsWith('image/')) return true;
    if (mimeType.startsWith('video/')) return true;
    if (mimeType.startsWith('audio/')) return true;
    if (FileUtils.isTextOrCode(path)) return true;
    if (const ['.db', '.sqlite', '.sqlite3', '.db3'].contains(ext)) return true;
    if (docExts.contains(ext)) return true;
    if (ApkInstallerService.isApk(path)) return true;
    // Fallback: any other file can be viewed as text/code in our built-in editor
    return true;
  }

  Future<void> openFileNatively(BuildContext context, String path) async {
    final mimeType = lookupMimeType(path) ?? '';
    final ext = p.extension(path).toLowerCase();
    const docExts = ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.epub', '.odt'];

    if (FileUtils.isArchive(path)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArchiveViewerScreen(archivePath: path),
        ),
      );
      return;
    }

    if (mimeType.startsWith('image/')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerScreen(imagePath: path)));
    } else if (mimeType.startsWith('video/')) {
      final folderVideoFiles = activeTab.currentFiles
          .where((f) => !f.isDirectory && (lookupMimeType(f.path)?.startsWith('video/') == true || FileUtils.isVideo(f.path)))
          .map((f) => f.path)
          .toList();
      int initialIndex = folderVideoFiles.indexOf(path);
      if (initialIndex == -1) initialIndex = 0;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            videoPath: path,
            playlist: folderVideoFiles.isNotEmpty ? folderVideoFiles : [path],
            initialIndex: initialIndex,
          ),
        ),
      );
    } else if (mimeType.startsWith('audio/')) {
      final folderAudioFiles = activeTab.currentFiles
          .where((f) => !f.isDirectory && (lookupMimeType(f.path)?.startsWith('audio/') == true))
          .toList();
      
      List<SongModel>? allSongs;
      int initialIndex = 0;

      if (folderAudioFiles.isNotEmpty && folderAudioFiles.any((f) => f.path == path)) {
        allSongs = [];
        for (int i = 0; i < folderAudioFiles.length; i++) {
          final file = folderAudioFiles[i];
          final songMap = {
            '_id': i,
            '_data': file.path,
            'title': p.basenameWithoutExtension(file.path),
            'artist': 'Unknown Artist',
            'album': 'Local Folder',
            'duration': 0,
            'size': file.size,
            'display_name': p.basename(file.path),
            'display_name_wo_ext': p.basenameWithoutExtension(file.path),
            'is_music': true,
          };
          allSongs.add(SongModel(songMap));
          if (file.path == path) {
            initialIndex = i;
          }
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AudioPlayerScreen(
            audioPath: path,
            title: p.basename(path),
            allSongs: allSongs,
            initialIndex: initialIndex,
          ),
        ),
      );
    } else if (FileUtils.isTextOrCode(path)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => TextEditorScreen(filePath: path)));
    } else if (const ['.db', '.sqlite', '.sqlite3', '.db3'].contains(ext)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DatabaseReaderScreen(filePath: path)));
    } else if (docExts.contains(ext)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentViewerScreen(filePath: path)));
    } else if (ApkInstallerService.isApk(path)) {
      await ApkInstallerService.installApk(context, path);
    } else {
      // Fallback for unrecognized files: Open in the built-in TextEditorScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TextEditorScreen(filePath: path),
        ),
      );
    }
  }

  Future<void> openFile(BuildContext context, String path, {bool showOpenWithPopup = false, bool forceOpenWith = false}) async {
    highlightedPaths.clear();
    highlightedPaths.add(path);
    notifyListeners();
    Timer(const Duration(milliseconds: 2000), () {
      if (highlightedPaths.remove(path)) {
        notifyListeners();
      }
    });

    final ext = p.extension(path).toLowerCase();
    
    String targetPath = path;
    if (isRestrictedPath(path) && !FileUtils.isTextOrCode(path)) {
      try {
        final tempDir = Directory('/storage/emulated/0/.nfile_temp');
        if (!tempDir.existsSync()) {
          tempDir.createSync(recursive: true);
        }
        final tempPath = p.join(tempDir.path, 'temp_restricted_${DateTime.now().millisecondsSinceEpoch}_${p.basename(path)}');
        await RootShizukuService.copyItem(path, tempPath, useRoot: activeTab.useRootMode);
        if (File(tempPath).existsSync()) {
          targetPath = tempPath;
        }
      } catch (e) {
        debugPrint('Error creating temporary copy for restricted file: $e');
      }
    }

    if (forceOpenWith) {
      await OpenFilex.open(targetPath);
      return;
    }

    // Universal default action check
    if (hasNativeViewer(targetPath)) {
      final defaultAction = PreferencesService.getDefaultOpenAction(ext);
      if (defaultAction == 'native') {
        await openFileNatively(context, targetPath);
        return;
      } else if (defaultAction == 'external') {
        await OpenFilex.open(targetPath);
        return;
      }
    }

    if (showOpenWithPopup && !skipOpenWithDialog && hasNativeViewer(targetPath)) {
      if (!context.mounted) return;
      
      final result = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => OpenWithSheet(
          fileName: p.basename(path),
          fileExtension: ext,
        ),
      );

      if (result == null) return;

      if (result.startsWith('always_')) {
        final selectedType = result.substring('always_'.length);
        await PreferencesService.saveDefaultOpenAction(ext, selectedType);
        if (selectedType == 'native') {
          await openFileNatively(context, targetPath);
        } else {
          await OpenFilex.open(targetPath);
        }
      } else if (result.startsWith('just_once_')) {
        final selectedType = result.substring('just_once_'.length);
        if (selectedType == 'native') {
          await openFileNatively(context, targetPath);
        } else {
          await OpenFilex.open(targetPath);
        }
      }
      return;
    }

    await openFileNatively(context, targetPath);
  }

  Future<void> moveItem(BuildContext context, String sourcePath, String destFolderPath, {bool showToast = true}) async {
    final name = p.basename(sourcePath);
    final destPath = p.join(destFolderPath, name);

    if (sourcePath == destPath || destFolderPath.startsWith(sourcePath + p.separator)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot move a folder inside itself or same location')),
      );
      return;
    }

    // Ensure destination parent directory exists recursively
    final destDir = Directory(destFolderPath);
    if (!destDir.existsSync()) {
      await destDir.create(recursive: true);
    }

    activeTab.isLoading = true;
    notifyListeners();

    try {
      final isDir = FileSystemEntity.isDirectorySync(sourcePath);
      if (isRestrictedPath(sourcePath) || isRestrictedPath(destFolderPath)) {
        await RootShizukuService.moveItem(sourcePath, destPath, useRoot: activeTab.useRootMode);
      } else {
        await moveFileAsync(sourcePath, destPath);
      }
      
      if (showToast) {
        AppEventBus.instance.fire(FileOperationSuccessEvent(
          operationType: 'move',
          message: 'Moved $name successfully'
        ));
      }
    } catch (e) {
      debugPrint('Error moving item: $e');
      if (showToast) {
        AppEventBus.instance.fire(FileOperationErrorEvent(
          operationType: 'move',
          errorMessage: 'Failed to move item: $e'
        ));
      }
    }

    await loadDirectory(currentPath, showLoading: false, clearCache: true);
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (var entity in source.list(recursive: false)) {
      if (entity is Directory) {
        final newDirectory = Directory(p.join(destination.absolute.path, p.basename(entity.path)));
        await newDirectory.create();
        await _copyDirectory(entity.absolute, newDirectory);
      } else if (entity is File) {
        await entity.copy(p.join(destination.path, p.basename(entity.path)));
      }
    }
  }

  Future<void> copyItem(BuildContext context, String sourcePath, String destFolderPath, {bool showToast = true}) async {
    final name = p.basename(sourcePath);
    final destPath = p.join(destFolderPath, name);

    if (sourcePath == destPath || destFolderPath.startsWith(sourcePath + p.separator)) {
      AppEventBus.instance.fire(FileOperationErrorEvent(
        operationType: 'copy',
        errorMessage: 'Cannot copy a folder inside itself or same location'
      ));
      return;
    }

    // Ensure destination parent directory exists recursively
    final destDir = Directory(destFolderPath);
    if (!destDir.existsSync()) {
      await destDir.create(recursive: true);
    }

    activeTab.isLoading = true;
    notifyListeners();

    try {
      final isDir = FileSystemEntity.isDirectorySync(sourcePath);
      if (isRestrictedPath(sourcePath) || isRestrictedPath(destFolderPath)) {
        await RootShizukuService.copyItem(sourcePath, destPath, useRoot: activeTab.useRootMode);
      } else {
        await copyFileAsync(sourcePath, destPath);
      }
      
      if (showToast) {
        AppEventBus.instance.fire(FileOperationSuccessEvent(
          operationType: 'copy',
          message: 'Copied $name successfully'
        ));
      }
    } catch (e) {
      debugPrint('Error copying item: $e');
      if (showToast) {
        AppEventBus.instance.fire(FileOperationErrorEvent(
          operationType: 'copy',
          errorMessage: 'Failed to copy item: $e'
        ));
      }
    }

    await loadDirectory(currentPath, showLoading: false, clearCache: true);
  }
}


class FileOperationProgress {
  final int totalFiles;
  final int currentFileIndex;
  final String currentFileName;
  final double percentage; // 0.0 to 1.0
  final double speedMBs; // MB/s
  final Duration eta;
  final int totalBytes;
  final int bytesProcessed;

  FileOperationProgress({
    required this.totalFiles,
    required this.currentFileIndex,
    required this.currentFileName,
    required this.percentage,
    required this.speedMBs,
    required this.eta,
    required this.totalBytes,
    required this.bytesProcessed,
  });
}
