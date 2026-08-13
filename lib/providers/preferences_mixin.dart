part of 'file_manager_provider.dart';
mixin PreferencesMixin on ChangeNotifier {
  Future<void> loadDirectory(String path, {bool showLoading = false, bool clearCache = false});
  List<CustomShortcutModel> _pinnedFolderShortcuts = [];
  List<CustomShortcutModel> get pinnedFolderShortcuts => _pinnedFolderShortcuts;

  void addPinnedFolderShortcut(String path, String label) {
    if (_pinnedFolderShortcuts.any((e) => e.path == path)) return;
    final shortcut = CustomShortcutModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      path: path,
      isDirectory: true,
    );
    _pinnedFolderShortcuts.add(shortcut);
    PreferencesService.savePinnedFolderShortcuts(_pinnedFolderShortcuts);
    notifyListeners();
  }

  void removePinnedFolderShortcut(String id) {
    _pinnedFolderShortcuts.removeWhere((e) => e.id == id);
    PreferencesService.savePinnedFolderShortcuts(_pinnedFolderShortcuts);
    notifyListeners();
  }

  String _accentColorOption = 'blue';
  String get accentColorOption => _accentColorOption;

  void setAccentColorOption(String val) {
    if (_accentColorOption == val) return;
    _accentColorOption = val;
    PreferencesService.saveAccentColor(val);
    notifyListeners();
  }

  String _activeAppIcon = 'default';
  String get activeAppIcon => _activeAppIcon;

  Future<void> setActiveAppIcon(String val) async {
    if (_activeAppIcon == val) return;
    _activeAppIcon = val;
    await PreferencesService.saveActiveAppIcon(val);

    String alias = 'com.rubex.nfile.MainActivityDefault';
    if (val == 'logo1') {
      alias = 'com.rubex.nfile.MainActivityLogo1';
    } else if (val == 'logo2') {
      alias = 'com.rubex.nfile.MainActivityLogo2';
    } else if (val == 'logo3') {
      alias = 'com.rubex.nfile.MainActivityLogo3';
    } else if (val == 'logo4') {
      alias = 'com.rubex.nfile.MainActivityLogo4';
    }

    await AppManagerService.changeAppIcon(alias);
    notifyListeners();
  }

  String _fontFamilyOption = 'default';
  String get fontFamilyOption => _fontFamilyOption;

  void setFontFamilyOption(String val) {
    if (_fontFamilyOption == val) return;
    _fontFamilyOption = val;
    PreferencesService.saveFontFamily(val);
    notifyListeners();
  }

  String? _customFontPath;
  String? get customFontPath => _customFontPath;

  Future<bool> setCustomFontPath(String? path) async {
    if (path != null) {
      final file = File(path);
      if (!file.existsSync()) return false;
      _customFontPath = path;
      await PreferencesService.saveCustomFontPath(path);
      // Dynamically load the font for the running app
      try {
        final loader = FontLoader('CustomFont');
        final bytes = await file.readAsBytes();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
      } catch (e) {
        debugPrint('Error loading custom font: $e');
        return false;
      }
    } else {
      _customFontPath = null;
      await PreferencesService.saveCustomFontPath(null);
    }
    notifyListeners();
    return true;
  }

  bool _disableLeftBackGesture = false;
  bool get disableLeftBackGesture => _disableLeftBackGesture;

  void toggleDisableLeftBackGesture() {
    _disableLeftBackGesture = !_disableLeftBackGesture;
    PreferencesService.saveDisableLeftBackGesture(_disableLeftBackGesture);
    notifyListeners();
  }

  String _folderIconOption = 'broken';
  String get folderIconOption => _folderIconOption;

  void setFolderIconOption(String val) {
    if (_folderIconOption == val) return;
    _folderIconOption = val;
    PreferencesService.saveFolderIconStyle(val);
    notifyListeners();
  }

  String _menuIconStyle = 'hamburger';
  String get menuIconStyle => _menuIconStyle;

  void setMenuIconStyle(String val) {
    if (_menuIconStyle == val) return;
    _menuIconStyle = val;
    PreferencesService.saveMenuIconStyle(val);
    notifyListeners();
  }

  FileSortType _sortType = FileSortType.nameAsc;
  FileSortType get sortType => _sortType;

  Map<String, FileSortType> _folderSortTypes = {};
  Map<String, FileSortType> get folderSortTypes => _folderSortTypes;

  bool isFolderOverrideEnabled(String path) {
    return _folderSortTypes.containsKey(path);
  }

  void setFolderOverrideEnabled(String path, bool enabled) {
    if (enabled) {
      _folderSortTypes[path] = getSortTypeForPath(path);
    } else {
      _folderSortTypes.remove(path);
    }
    PreferencesService.saveFolderSortTypes(_folderSortTypes);
    
    if (tabs.isNotEmpty && currentPath == path) {
      final folders = currentFiles.where((e) => e.isDirectory).toList();
      final files = currentFiles.where((e) => !e.isDirectory).toList();
      sortList(folders, path);
      sortList(files, path);
      activeTab.currentFiles = [...folders, ...files];
    }
    notifyListeners();
  }

  FileSortType getSortTypeForPath(String path) {
    return _folderSortTypes[path] ?? _sortType;
  }

  void setSortType(FileSortType type) {
    final path = currentPath;
    final hasOverride = isFolderOverrideEnabled(path);
    
    if (hasOverride) {
      if (_folderSortTypes[path] == type) return;
      _folderSortTypes[path] = type;
      PreferencesService.saveFolderSortTypes(_folderSortTypes);
    } else {
      if (_sortType == type) return;
      _sortType = type;
      PreferencesService.saveSortType(_sortType);
    }
    
    if (tabs.isNotEmpty) {
      final folders = currentFiles.where((e) => e.isDirectory).toList();
      final files = currentFiles.where((e) => !e.isDirectory).toList();
      sortList(folders, path);
      sortList(files, path);
      activeTab.currentFiles = [...folders, ...files];
    }
    notifyListeners();
  }

  FileFilterType _filterType = FileFilterType.all;
  FileFilterType get filterType => _filterType;

  void setFilterType(FileFilterType type) {
    if (_filterType == type) return;
    _filterType = type;
    loadDirectory(currentPath, showLoading: false);
    notifyListeners();
  }

  bool _hideFoldersInFilter = false;
  bool get hideFoldersInFilter => _hideFoldersInFilter;

  void toggleHideFoldersInFilter() {
    _hideFoldersInFilter = !_hideFoldersInFilter;
    if (tabs.isNotEmpty) {
      loadDirectory(currentPath, showLoading: false);
    }
    notifyListeners();
  }

  static bool matchesFilterForType(String path, FileFilterType filter) {
    switch (filter) {
      case FileFilterType.all:
        return true;
      case FileFilterType.documents:
        final lower = path.toLowerCase();
        const docExts = ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.csv', '.odt', '.ods', '.odp', '.rtf', '.epub'];
        return docExts.any((ext) => lower.endsWith(ext)) || FileUtils.isTextOrCode(path);
      case FileFilterType.images:
        return FileUtils.isImage(path);
      case FileFilterType.audio:
        return FileUtils.isAudio(path);
      case FileFilterType.videos:
        return FileUtils.isVideo(path);
      case FileFilterType.archives:
        return FileUtils.isArchive(path);
    }
  }

  bool _matchesFilter(String path) {
    return matchesFilterForType(path, _filterType);
  }

  final Map<String, int> _folderMatchingFileCounts = {};

  Future<int> getMatchingFileCount(String folderPath, FileFilterType filter) async {
    final cacheKey = '$folderPath:${filter.name}';
    if (_folderMatchingFileCounts.containsKey(cacheKey)) {
      return _folderMatchingFileCounts[cacheKey]!;
    }

    int count = 0;
    try {
      final dir = Directory(folderPath);
      if (await dir.exists()) {
        final List<FileSystemEntity> entities = await dir.list().toList();
        for (var entity in entities) {
          if (entity is File) {
            if (matchesFilterForType(entity.path, filter)) {
              count++;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error counting matching files in $folderPath: $e');
    }

    _folderMatchingFileCounts[cacheKey] = count;
    return count;
  }

  String getFilterTypeName(FileFilterType filter, int count) {
    switch (filter) {
      case FileFilterType.all:
        return '';
      case FileFilterType.documents:
        return count == 1 ? 'document' : 'documents';
      case FileFilterType.images:
        return count == 1 ? 'image' : 'images';
      case FileFilterType.audio:
        return count == 1 ? 'audio' : 'audios';
      case FileFilterType.videos:
        return count == 1 ? 'video' : 'videos';
      case FileFilterType.archives:
        return count == 1 ? 'archive' : 'archives';
    }
  }

  bool _isGridView = false;
  bool get isGridView => _isGridView;

  void setGridView(bool value) {
    if (_isGridView == value) return;
    _isGridView = value;
    PreferencesService.saveIsGridView(_isGridView);
    notifyListeners();
  }

  void toggleViewMode() {
    _isGridView = !_isGridView;
    PreferencesService.saveIsGridView(_isGridView);
    notifyListeners();
  }

  double _iconScale = 1.0;
  double get iconScale => _iconScale;

  void setIconScale(double scale) {
    final clamped = scale.clamp(0.7, 1.5);
    if (_iconScale == clamped) return;
    _iconScale = clamped;
    PreferencesService.saveIconScale(_iconScale);
    notifyListeners();
  }

  double _itemPaddingMultiplier = 1.0;
  double get itemPaddingMultiplier => _itemPaddingMultiplier;

  void setItemPaddingMultiplier(double mult) {
    final clamped = mult.clamp(0.4, 2.0);
    if (_itemPaddingMultiplier == clamped) return;
    _itemPaddingMultiplier = clamped;
    PreferencesService.saveItemPaddingMultiplier(_itemPaddingMultiplier);
    notifyListeners();
  }

  void sortList(List<FileItemModel> items, String path) {
    final activeSort = getSortTypeForPath(path);
    switch (activeSort) {
      case FileSortType.nameAsc:
        items.sort((a, b) => FileUtils.compareNatural(a.name, b.name));
        break;
      case FileSortType.nameDesc:
        items.sort((a, b) => FileUtils.compareNatural(b.name, a.name));
        break;
      case FileSortType.dateNewest:
        items.sort((a, b) => b.modified.compareTo(a.modified));
        break;
      case FileSortType.dateOldest:
        items.sort((a, b) => a.modified.compareTo(b.modified));
        break;
      case FileSortType.sizeLargest:
        items.sort((a, b) => b.size.compareTo(a.size));
        break;
      case FileSortType.sizeSmallest:
        items.sort((a, b) => a.size.compareTo(b.size));
        break;
      case FileSortType.type:
        items.sort((a, b) {
          final extA = p.extension(a.name).toLowerCase();
          final extB = p.extension(b.name).toLowerCase();
          return extA.compareTo(extB);
        });
        break;
    }

    // Stable-sort pinned files/folders to the top of the list!
    if (items.isNotEmpty) {
      final pinned = <FileItemModel>[];
      final unpinned = <FileItemModel>[];
      for (final item in items) {
        if (PinService.isPinned(item.path)) {
          pinned.add(item);
        } else {
          unpinned.add(item);
        }
      }
      items.clear();
      items.addAll(pinned);
      items.addAll(unpinned);
    }
  }

  bool _showHiddenFiles = false;
  bool get showHiddenFiles => _showHiddenFiles;

  void toggleHiddenFiles() {
    _showHiddenFiles = !_showHiddenFiles;
    PreferencesService.saveShowHiddenFiles(_showHiddenFiles);
    notifyListeners();
    if (tabs.isNotEmpty && currentPath.isNotEmpty) {
      loadDirectory(currentPath, showLoading: false);
    }
  }

  bool _showFloatingAddButton = false;
  bool get showFloatingAddButton => _showFloatingAddButton;

  void toggleFloatingAddButton() {
    _showFloatingAddButton = !_showFloatingAddButton;
    PreferencesService.saveShowFloatingAddButton(_showFloatingAddButton);
    notifyListeners();
  }

  bool _defaultToBrowseScreen = false;
  bool get defaultToBrowseScreen => _defaultToBrowseScreen;

  void toggleDefaultToBrowseScreen() {
    _defaultToBrowseScreen = !_defaultToBrowseScreen;
    PreferencesService.saveDefaultToBrowseScreen(_defaultToBrowseScreen);
    notifyListeners();
  }

  bool _rememberLastFolder = false;
  bool get rememberLastFolder => _rememberLastFolder;

  void toggleRememberLastFolder() {
    _rememberLastFolder = !_rememberLastFolder;
    PreferencesService.saveRememberLastFolder(_rememberLastFolder);
    notifyListeners();
  }

  bool _useMaterialIcons = false;
  bool get useMaterialIcons => _useMaterialIcons;

  void setUseMaterialIcons(bool val) {
    if (_useMaterialIcons == val) return;
    _useMaterialIcons = val;
    PreferencesService.saveUseMaterialIcons(val);
    notifyListeners();
  }

  String _exitOption = 'confirm';
  String get exitOption => _exitOption;

  void setExitOption(String val) {
    if (_exitOption == val) return;
    _exitOption = val;
    PreferencesService.saveExitOption(val);
    notifyListeners();
  }

  bool _showFolderFileCount = false;
  bool get showFolderFileCount => _showFolderFileCount;

  void toggleFolderFileCount() {
    _showFolderFileCount = !_showFolderFileCount;
    PreferencesService.saveShowFolderFileCount(_showFolderFileCount);
    notifyListeners();
  }

  bool _use24HourFormat = false;
  bool get use24HourFormat => _use24HourFormat;

  void toggleUse24HourFormat() {
    _use24HourFormat = !_use24HourFormat;
    PreferencesService.saveUse24HourFormat(_use24HourFormat);
    notifyListeners();
  }

  bool _hideTimeAndDate = false;
  bool get hideTimeAndDate => _hideTimeAndDate;

  void toggleHideTimeAndDate() {
    _hideTimeAndDate = !_hideTimeAndDate;
    PreferencesService.saveHideTimeAndDate(_hideTimeAndDate);
    notifyListeners();
  }

  bool _showFolderContentsCount = false;
  bool get showFolderContentsCount => _showFolderContentsCount;

  void toggleFolderContentsCount() {
    _showFolderContentsCount = !_showFolderContentsCount;
    PreferencesService.saveShowFolderContentsCount(_showFolderContentsCount);
    notifyListeners();
  }

  bool _showFolderSizes = false;
  bool get showFolderSizes => _showFolderSizes;

  void toggleShowFolderSizes() {
    _showFolderSizes = !_showFolderSizes;
    PreferencesService.saveShowFolderSizes(_showFolderSizes);
    notifyListeners();
  }

  final Map<String, int> _folderItemCounts = {};

  Future<int> getFolderItemCount(String folderPath) async {
    if (_folderItemCounts.containsKey(folderPath)) {
      return _folderItemCounts[folderPath]!;
    }

    int count = 0;
    try {
      final dir = Directory(folderPath);
      if (await dir.exists()) {
        final entities = await dir.list().toList();
        final showHidden = _showHiddenFiles;
        for (var entity in entities) {
          final name = p.basename(entity.path);
          if (!showHidden && name.startsWith('.')) {
            continue;
          }
          count++;
        }
      }
    } catch (e) {
      debugPrint('Operation error: \$e');
    }

    _folderItemCounts[folderPath] = count;
    return count;
  }

  final Map<String, int> _folderSizes = {};

  Future<int> getFolderSize(String folderPath) async {
    if (_folderSizes.containsKey(folderPath)) {
      return _folderSizes[folderPath]!;
    }

    int totalSize = await calculateDirectorySize(folderPath);
    _folderSizes[folderPath] = totalSize;
    return totalSize;
  }

  void clearFolderItemCountsCache() {
    _folderItemCounts.clear();
    _folderSizes.clear();
  }

  bool _showBottomActionBar = false;
  bool get showBottomActionBar => _showBottomActionBar;

  void toggleBottomActionBar() {
    _showBottomActionBar = !_showBottomActionBar;
    PreferencesService.saveShowBottomActionBar(_showBottomActionBar);
    notifyListeners();
  }

  bool _showHomeBrowseNav = true;
  bool get showHomeBrowseNav => _showHomeBrowseNav;

  void toggleShowHomeBrowseNav() {
    _showHomeBrowseNav = !_showHomeBrowseNav;
    PreferencesService.saveShowHomeBrowseNav(_showHomeBrowseNav);
    notifyListeners();
  }

  bool _hideNavLabels = false;
  bool get hideNavLabels => _hideNavLabels;

  void toggleHideNavLabels() {
    _hideNavLabels = !_hideNavLabels;
    PreferencesService.saveHideNavLabels(_hideNavLabels);
    notifyListeners();
  }

  bool _hideNavigationBar = false;
  bool get hideNavigationBar => _hideNavigationBar;

  void toggleHideNavigationBar() {
    _hideNavigationBar = !_hideNavigationBar;
    PreferencesService.saveHideNavigationBar(_hideNavigationBar);
    if (_hideNavigationBar) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    }
    notifyListeners();
  }

  bool _isVideoPlayingFullscreen = false;
  bool get isVideoPlayingFullscreen => _isVideoPlayingFullscreen;

  void setVideoPlayingFullscreen(bool value) {
    if (_isVideoPlayingFullscreen == value) return;
    _isVideoPlayingFullscreen = value;
    notifyListeners();
  }

  bool _showMediaPreviews = true;
  bool get showMediaPreviews => _showMediaPreviews;

  void toggleMediaPreviews() {
    _showMediaPreviews = !_showMediaPreviews;
    PreferencesService.saveShowMediaPreviews(_showMediaPreviews);
    notifyListeners();
  }

  bool _skipOpenWithDialog = true;
  bool get skipOpenWithDialog => _skipOpenWithDialog;
  set skipOpenWithDialog(bool value) => _skipOpenWithDialog = value;

  void toggleSkipOpenWithDialog() {
    _skipOpenWithDialog = !_skipOpenWithDialog;
    PreferencesService.saveSkipOpenWithDialog(_skipOpenWithDialog);
    notifyListeners();
  }

  bool _showAddressBar = false;
  bool get showAddressBar => _showAddressBar;

  void toggleShowAddressBar() {
    _showAddressBar = !_showAddressBar;
    PreferencesService.saveShowAddressBar(_showAddressBar);
    notifyListeners();
  }

  bool _amoledMode = false;
  bool get amoledMode => _amoledMode;

  void toggleAmoledMode() {
    _amoledMode = !_amoledMode;
    PreferencesService.saveAmoledMode(_amoledMode);
    notifyListeners();
  }

  void setAmoledMode(bool val) {
    if (_amoledMode == val) return;
    _amoledMode = val;
    PreferencesService.saveAmoledMode(val);
    notifyListeners();
  }

  bool _showRecentFiles = false;
  bool get showRecentFiles => _showRecentFiles;

  void toggleShowRecentFiles() {
    _showRecentFiles = !_showRecentFiles;
    PreferencesService.saveShowRecentFiles(_showRecentFiles);
    notifyListeners();
  }

  bool _enableFolderHighlight = false;
  bool get enableFolderHighlight => _enableFolderHighlight;

  void toggleEnableFolderHighlight() {
    _enableFolderHighlight = !_enableFolderHighlight;
    PreferencesService.saveEnableFolderHighlight(_enableFolderHighlight);
    notifyListeners();
  }

  bool _adaptiveMultiLineNames = false;
  bool get adaptiveMultiLineNames => _adaptiveMultiLineNames;

  void toggleAdaptiveMultiLineNames() {
    _adaptiveMultiLineNames = !_adaptiveMultiLineNames;
    PreferencesService.saveAdaptiveMultiLineNames(_adaptiveMultiLineNames);
    notifyListeners();
  }

  bool _hideActionMenuButtons = false;
  bool get hideActionMenuButtons => _hideActionMenuButtons;

  void toggleHideActionMenuButtons() {
    _hideActionMenuButtons = !_hideActionMenuButtons;
    PreferencesService.saveHideActionMenuButtons(_hideActionMenuButtons);
    notifyListeners();
  }

  String _trailingInfoType = 'none';
  String get trailingInfoType => _trailingInfoType;

  void setTrailingInfoType(String val) {
    if (_trailingInfoType == val) return;
    _trailingInfoType = val;
    PreferencesService.saveTrailingInfoType(val);
    notifyListeners();
  }

  bool _hideActionText = false;
  bool get hideActionText => _hideActionText;

  void toggleHideActionText() {
    _hideActionText = !_hideActionText;
    PreferencesService.saveHideActionText(_hideActionText);
    notifyListeners();
  }

  bool _enableDragDrop = false;
  bool get enableDragDrop => _enableDragDrop;

  void toggleEnableDragDrop() {
    _enableDragDrop = !_enableDragDrop;
    PreferencesService.saveEnableDragDrop(_enableDragDrop);
    notifyListeners();
  }

  bool _showDragDropDialog = true;
  bool get showDragDropDialog => _showDragDropDialog;

  void toggleShowDragDropDialog() {
    _showDragDropDialog = !_showDragDropDialog;
    PreferencesService.saveShowDragDropDialog(_showDragDropDialog);
    notifyListeners();
  }

  bool _enableMultipleTabs = false;
  bool get enableMultipleTabs => _enableMultipleTabs;

  void toggleMultipleTabs() {
    _enableMultipleTabs = !_enableMultipleTabs;
    PreferencesService.saveEnableMultipleTabs(_enableMultipleTabs);
    if (!_enableMultipleTabs) {
      closeOtherTabs();
    }
    notifyListeners();
  }

  bool _enableSplitScreen = false;
  bool get enableSplitScreen => _enableSplitScreen;

  void toggleSplitScreen() {
    _enableSplitScreen = !_enableSplitScreen;
    PreferencesService.saveEnableSplitScreen(_enableSplitScreen);
    
    if (_enableSplitScreen) {
      if (tabs.length < 2) {
        final initialPath = _rootPath.isNotEmpty ? _rootPath : '/';
        final newTab = FolderTab(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          currentPath: initialPath,
        );
        tabs.add(newTab);
      }
      loadDirectoryForTab(0, tabs[0].currentPath, showLoading: false);
      loadDirectoryForTab(1, tabs[1].currentPath, showLoading: false);
    } else {
      if (_activeTabIndex >= tabs.length) {
        _activeTabIndex = 0;
      }
    }
    notifyListeners();
  }

  Future<void> loadDirectoryForTab(int tabIndex, String path, {bool showLoading = true, bool clearCache = false}) async {
    if (tabIndex >= 0 && tabIndex < tabs.length) {
      final oldIndex = _activeTabIndex;
      _activeTabIndex = tabIndex;
      await loadDirectory(path, showLoading: showLoading, clearCache: clearCache);
      _activeTabIndex = oldIndex;
    }
  }

  // --- Tab Management ---
  List<FolderTab> tabs = [FolderTab(id: 'default', currentPath: Platform.isAndroid ? '/storage/emulated/0' : '/')];
  int _activeTabIndex = 0;
  final Map<String, StreamSubscription<FileSystemEntity>?> _searchSubscriptions = {};
  final Map<String, int> _searchGenerations = {};


  int get activeTabIndex => _activeTabIndex;

  FolderTab get activeTab {
    if (tabs.isEmpty) {
      tabs = [FolderTab(id: 'default', currentPath: _rootPath.isNotEmpty ? _rootPath : '/')];
    }
    return tabs[_activeTabIndex];
  }

  void addTab(String path) {
    final newTab = FolderTab(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      currentPath: path,
    );
    tabs.add(newTab);
    _activeTabIndex = tabs.length - 1;
    _persistTabs();
    notifyListeners();
    loadDirectory(path);
  }

  void closeTab(int index) {
    if (tabs.length <= 1) return;
    final closedTab = tabs[index];
    cancelSearchForTab(closedTab.id);
    tabs.removeAt(index);
    if (_activeTabIndex >= tabs.length) {
      _activeTabIndex = tabs.length - 1;
    } else if (_activeTabIndex == index) {
      if (_activeTabIndex >= tabs.length) {
        _activeTabIndex = tabs.length - 1;
      }
    } else if (_activeTabIndex > index) {
      _activeTabIndex--;
    }
    _persistTabs();
    notifyListeners();
  }

  void closeOtherTabs() {
    if (tabs.length <= 1) return;
    final active = activeTab;
    for (final tab in tabs) {
      if (tab.id != active.id) {
        cancelSearchForTab(tab.id);
      }
    }
    tabs = [active];
    _activeTabIndex = 0;
    _persistTabs();
    notifyListeners();
  }

  void duplicateActiveTab() {
    if (tabs.isEmpty) return;
    final active = activeTab;
    final dup = FolderTab(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      currentPath: active.currentPath,
      currentFiles: List.from(active.currentFiles),
      isRestrictedMode: active.isRestrictedMode,
      needsPermission: active.needsPermission,
      useRootMode: active.useRootMode,
      useShizukuMode: active.useShizukuMode,
      isRootAvailable: active.isRootAvailable,
      scrollPositions: Map.from(active.scrollPositions),
      isPinned: active.isPinned,
    );
    tabs.add(dup);
    _activeTabIndex = tabs.length - 1;
    _persistTabs();
    notifyListeners();
  }

  void togglePinTab(int index) {
    if (index >= 0 && index < tabs.length) {
      tabs[index].isPinned = !tabs[index].isPinned;
      _persistTabs();
      notifyListeners();
    }
  }

  void duplicateTab(int index) {
    if (index >= 0 && index < tabs.length) {
      final tab = tabs[index];
      final dup = FolderTab(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        currentPath: tab.currentPath,
        currentFiles: List.from(tab.currentFiles),
        isRestrictedMode: tab.isRestrictedMode,
        needsPermission: tab.needsPermission,
        useRootMode: tab.useRootMode,
        useShizukuMode: tab.useShizukuMode,
        isRootAvailable: tab.isRootAvailable,
        scrollPositions: Map.from(tab.scrollPositions),
        isPinned: tab.isPinned,
      );
      tabs.insert(index + 1, dup);
      _activeTabIndex = index + 1;
      _persistTabs();
      notifyListeners();
    }
  }

  void setActiveTab(int index) {
    if (index >= 0 && index < tabs.length) {
      _activeTabIndex = index;
      _persistTabs();
      notifyListeners();
    }
  }

  void _persistTabs() {
    final list = tabs.map((t) => {
      'id': t.id,
      'currentPath': t.currentPath,
      'isPinned': t.isPinned,
    }).toList();
    PreferencesService.saveSavedTabs(list);
  }

  void executeSearchForTab(
    int tabIndex,
    String query,
    String filter,
    MediaProvider mediaProvider,
  ) {
    if (tabIndex < 0 || tabIndex >= tabs.length) return;
    final tab = tabs[tabIndex];

    // Cancel existing search for this tab
    _searchSubscriptions[tab.id]?.cancel();
    _searchSubscriptions[tab.id] = null;
    _searchGenerations[tab.id] = (_searchGenerations[tab.id] ?? 0) + 1;
    final generation = _searchGenerations[tab.id]!;

    tab.searchQuery = query.trim();
    tab.searchFilter = filter;
    tab.searchResults = [];

    if (tab.searchQuery.isEmpty) {
      tab.isSearching = false;
      notifyListeners();
      return;
    }

    tab.isSearching = true;
    notifyListeners();

    final qLower = tab.searchQuery.toLowerCase();
    // If the query is a bare extension like ".pdf" or ".py", match by extension
    final extMode = _isExtensionQuery(qLower);
    final extName = extMode ? qLower.substring(1) : '';

    final Set<String> seenPaths = {};
    final List<FileItemModel> pending = [];

    void flushPending() {
      if (generation != _searchGenerations[tab.id]) return;
      if (tabIndex < tabs.length && tabs[tabIndex].id == tab.id && pending.isNotEmpty) {
        tabs[tabIndex].searchResults = [...tabs[tabIndex].searchResults, ...pending];
        notifyListeners();
      }
      pending.clear();
    }

    bool matchesQuery(String name) {
      final lower = name.toLowerCase();
      if (lower.contains(qLower)) return true;
      if (extMode) {
        return p.extension(lower).replaceFirst('.', '') == extName;
      }
      return false;
    }

    // Resolve search scope: if starting search path is root or external storage, it's global
    final isGlobal = tab.currentPath == '/storage/emulated/0' ||
                     tab.currentPath == '/' ||
                     tab.currentPath.isEmpty;

    final rootPath = isGlobal
        ? (Platform.isAndroid ? '/storage/emulated/0' : tab.currentPath)
        : tab.currentPath;

    // 1. Instant check from MediaProvider indexes if matching filter
    if (filter == 'All' || filter == 'Docs') {
      final matchingDocs = <FileSystemEntity>[];
      for (final doc in mediaProvider.documents) {
        if (!isGlobal && !doc.path.startsWith(rootPath)) continue;
        final name = p.basename(doc.path);
        if (matchesQuery(name) && !seenPaths.contains(doc.path)) {
          seenPaths.add(doc.path);
          matchingDocs.add(doc);
        }
      }
      if (matchingDocs.isNotEmpty) {
        Future.wait(matchingDocs.map((doc) => FileItemModel.fromEntityAsync(doc))).then((resolvedDocs) {
          if (generation != _searchGenerations[tab.id]) return;
          if (tabIndex < tabs.length && tabs[tabIndex].id == tab.id) {
            pending.addAll(resolvedDocs);
            flushPending();
          }
        });
      }
    }

    if (filter == 'All' || filter == 'Audio') {
      for (final song in mediaProvider.audios) {
        final path = song.data;
        if (!isGlobal && !path.startsWith(rootPath)) continue;
        final name = p.basename(path);
        if (matchesQuery(name) && !seenPaths.contains(path)) {
          seenPaths.add(path);
          pending.add(FileItemModel(
            entity: File(path),
            name: song.title,
            path: path,
            isDirectory: false,
            size: song.size,
            modified: DateTime.fromMillisecondsSinceEpoch((song.dateModified ?? 0) * 1000),
          ));
        }
      }
      if (pending.isNotEmpty) flushPending();
    }

    // 2. Robust traversal across filesystem (per-directory error isolation)
    final rootDir = Directory(rootPath);
    if (!rootDir.existsSync()) {
      tab.isSearching = false;
      notifyListeners();
      return;
    }

    final isImage = (String name) {
      final ext = p.extension(name).toLowerCase();
      return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic', '.avif'].contains(ext);
    };

    final isVideo = (String name) {
      final ext = p.extension(name).toLowerCase();
      return ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.ts'].contains(ext);
    };

    final isAudio = (String name) {
      final ext = p.extension(name).toLowerCase();
      return ['.mp3', '.m4a', '.wav', '.flac', '.aac', '.ogg', '.opus', '.amr'].contains(ext);
    };

    final isDoc = (String name) {
      final ext = p.extension(name).toLowerCase();
      return ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.csv'].contains(ext);
    };

    bool matchFilter(String name, bool isDirEntity) {
      if (filter == 'All') return true;
      if (filter == 'Folders') return isDirEntity;
      if (filter == 'Images') return !isDirEntity && isImage(name);
      if (filter == 'Videos') return !isDirEntity && isVideo(name);
      if (filter == 'Audio') return !isDirEntity && isAudio(name);
      if (filter == 'Docs') {
        // Extension queries bypass the category whitelist so ".py", ".c", etc. are found
        if (extMode) return !isDirEntity;
        return !isDirEntity && isDoc(name);
      }
      return true;
    }

    const int maxResults = 500;
    const int flushThreshold = 100;

    Future<void> walk(Directory start) async {
      final queue = <Directory>[start];
      while (queue.isNotEmpty) {
        if (generation != _searchGenerations[tab.id]) return;
        final dir = queue.removeAt(0);
        List<FileSystemEntity> entities;
        try {
          entities = await dir.list(followLinks: false).toList();
        } catch (e) {
      // Error handled
          continue;
        }
        for (final entity in entities) {
          if (entity is Link) continue;
          final isDirEntity = entity is Directory;
          if (isDirEntity) queue.add(entity);
          final name = p.basename(entity.path);
          if (!matchesQuery(name) || !matchFilter(name, isDirEntity)) continue;
          if (!seenPaths.add(entity.path)) continue;
          pending.add(FileItemModel.fromEntity(entity));
          if (pending.length >= flushThreshold) {
            flushPending();
          }
          if (generation == _searchGenerations[tab.id] &&
              tabIndex < tabs.length &&
              tabs[tabIndex].searchResults.length >= maxResults) {
            return;
          }
        }
      }
    }

    walk(rootDir).then((_) {
      flushPending();
      if (generation != _searchGenerations[tab.id]) return;
      if (tabIndex < tabs.length && tabs[tabIndex].id == tab.id) {
        tabs[tabIndex].isSearching = false;
        notifyListeners();
      }
    });
  }

  bool _isExtensionQuery(String qLower) {
    if (!qLower.startsWith('.')) return false;
    final inner = qLower.substring(1);
    if (inner.isEmpty || inner.contains('.')) return false;
    return RegExp(r'^[a-z0-9]+$').hasMatch(inner);
  }

  void toggleSearchForTab(int index) {
    if (index >= 0 && index < tabs.length) {
      final tab = tabs[index];
      tab.isSearchActive = !tab.isSearchActive;
      if (!tab.isSearchActive) {
        deactivateSearchForTab(tab);
      }
      notifyListeners();
    }
  }

  void toggleSearchForActiveTab() {
    toggleSearchForTab(_activeTabIndex);
  }

  void deactivateSearchForTab(FolderTab tab) {
    cancelSearchForTab(tab.id);
    tab.isSearchActive = false;
    tab.searchQuery = '';
    tab.searchResults = [];
    tab.isSearching = false;
  }

  void cancelSearchForTab(String tabId) {
    _searchSubscriptions[tabId]?.cancel();
    _searchSubscriptions[tabId] = null;
  }

  // --- Active Tab Delegations ---
  List<FileItemModel> get currentFiles => activeTab.isSearchActive ? activeTab.searchResults : activeTab.currentFiles;
  String get currentPath => activeTab.currentPath;
  bool get isLoading => activeTab.isSearchActive ? activeTab.isSearching : activeTab.isLoading;
  bool get isRestrictedMode => activeTab.isRestrictedMode;
  bool get needsPermission => activeTab.needsPermission;
  bool get useRootMode => activeTab.useRootMode;
  bool get useShizukuMode => activeTab.useShizukuMode;
  bool get isRootAvailable => activeTab.isRootAvailable;
  Set<String> get selectedPaths => activeTab.selectedPaths;
  bool get isSelectionMode => selectedPaths.isNotEmpty;

  // --- Global Clipboard ---
  final List<String> _clipboardPaths = [];
  bool _isCut = false;
  String? _sourceArchiveForCut;
  List<String>? _internalSourcePathsForCut;
  String? get sourceArchiveForCut => _sourceArchiveForCut;
  List<String>? get internalSourcePathsForCut => _internalSourcePathsForCut;

  // Remote Clipboard support
  bool _isRemoteClipboard = false;
  final List<RemoteFileItem> _remoteClipboardItems = [];
  NetworkConnectionModel? _remoteClipboardConnection;

  bool get hasClipboard => _clipboardPaths.isNotEmpty || _isRemoteClipboard;
  List<String> get clipboardPaths => _clipboardPaths;
  bool get isCut => _isCut;
  set isCut(bool value) => _isCut = value;
  bool get isRemoteClipboard => _isRemoteClipboard;
  List<RemoteFileItem> get remoteClipboardItems => _remoteClipboardItems;
  NetworkConnectionModel? get remoteClipboardConnection => _remoteClipboardConnection;
  set remoteClipboardConnection(NetworkConnectionModel? value) => _remoteClipboardConnection = value;

  void setClipboard(List<String> paths, {required bool isCut, String? sourceArchive, List<String>? internalSourcePaths}) {
    _clipboardPaths.clear();
    _clipboardPaths.addAll(paths);
    _isRemoteClipboard = false;
    _remoteClipboardItems.clear();
    _remoteClipboardConnection = null;
    _isCut = isCut;
    _sourceArchiveForCut = sourceArchive;
    _internalSourcePathsForCut = internalSourcePaths;
    notifyListeners();
  }

  void setRemoteClipboard(List<RemoteFileItem> items, {required bool isCut, required NetworkConnectionModel connection}) {
    _clipboardPaths.clear();
    _isRemoteClipboard = true;
    _remoteClipboardItems.clear();
    _remoteClipboardItems.addAll(items);
    _remoteClipboardConnection = connection;
    _isCut = isCut;
    _sourceArchiveForCut = null;
    _internalSourcePathsForCut = null;
    notifyListeners();
  }

  void clearClipboard() {
    _clipboardPaths.clear();
    _isRemoteClipboard = false;
    _remoteClipboardItems.clear();
    _remoteClipboardConnection = null;
    _isCut = false;
    _sourceArchiveForCut = null;
    _internalSourcePathsForCut = null;
    notifyListeners();
  }

  final Set<String> _highlightedPaths = {};
  Set<String> get highlightedPaths => _highlightedPaths;

  final Set<String> _forceHighlightedPaths = {};
  Set<String> get forceHighlightedPaths => _forceHighlightedPaths;

  bool _shouldScrollToHighlight = false;
  bool get shouldScrollToHighlight => _shouldScrollToHighlight;
  set shouldScrollToHighlight(bool value) => _shouldScrollToHighlight = value;

  void resetScrollToHighlight() {
    _shouldScrollToHighlight = false;
  }

  Future<void> showFileInLocation(String filePath) async {
    final parentPath = p.dirname(filePath);
    await loadDirectory(parentPath);
    _highlightedPaths.clear();
    _highlightedPaths.add(filePath);
    _forceHighlightedPaths.clear();
    _forceHighlightedPaths.add(filePath);
    _shouldScrollToHighlight = true;
    notifyListeners();
    Timer(const Duration(milliseconds: 2000), () {
      _forceHighlightedPaths.remove(filePath);
      if (_highlightedPaths.remove(filePath)) {
        notifyListeners();
      }
    });
  }

  String _rootPath = '';
  String get rootPath => _rootPath;

  bool get canGoBack {
    final path = currentPath;
    if (path.isEmpty || _rootPath.isEmpty) return false;
    if (path == _rootPath || path == '/' || p.dirname(path) == path) {
      return false;
    }
    return true;
  }

  void saveScrollOffset(String path, double offset) {
    if (path.isNotEmpty) {
      activeTab.scrollPositions[path] = offset;
    }
  }

  double getSavedScrollOffset(String path) {
    return activeTab.scrollPositions[path] ?? 0.0;
  }

  List<StorageVolume> _storageVolumes = [];
  List<StorageVolume> get storageVolumes => _storageVolumes;

  int _totalStorageBytes = 0;
  int _usedStorageBytes = 0;
  int _rawTotalStorageBytes = 0;
  int _rawUsedStorageBytes = 0;

  int get totalStorageBytes => _totalStorageBytes;
  int get usedStorageBytes => _usedStorageBytes;
  int get rawTotalStorageBytes => _rawTotalStorageBytes;
  int get rawUsedStorageBytes => _rawUsedStorageBytes;
  double get storageUsedPercentage => _totalStorageBytes == 0 ? 0.0 : (_usedStorageBytes / _totalStorageBytes);
  double get rawStorageUsedPercentage => _rawTotalStorageBytes == 0 ? 0.0 : (_rawUsedStorageBytes / _rawTotalStorageBytes);

  Future<void> updateStorageSpace() async {
    final space = await RootShizukuService.getStorageSpace();
    if (space != null) {
      final rawTotal = space['totalBytes'] ?? 0;
      final rawUsed = space['usedBytes'] ?? 0;

      _rawTotalStorageBytes = rawTotal;
      _rawUsedStorageBytes = rawUsed;

      if (rawTotal > 0) {
        final double rawTotalGb = rawTotal / (1024 * 1024 * 1024);
        double marketingGb = rawTotalGb;

        if (rawTotalGb <= 8) {
          marketingGb = 8.0;
        } else if (rawTotalGb <= 16) {
          marketingGb = 16.0;
        } else if (rawTotalGb <= 32) {
          marketingGb = 32.0;
        } else if (rawTotalGb <= 64) {
          marketingGb = 64.0;
        } else if (rawTotalGb <= 128) {
          marketingGb = 128.0;
        } else if (rawTotalGb <= 256) {
          marketingGb = 256.0;
        } else if (rawTotalGb <= 512) {
          marketingGb = 512.0;
        } else if (rawTotalGb <= 1024) {
          marketingGb = 1024.0;
        } else if (rawTotalGb <= 2048) {
          marketingGb = 2048.0;
        } else {
          marketingGb = rawTotalGb.roundToDouble();
        }

        final int marketingTotalBytes = (marketingGb * 1024 * 1024 * 1024).toInt();
        final int systemReservedBytes = (marketingTotalBytes - rawTotal).toInt();
        final int adjustedUsedBytes = rawUsed + systemReservedBytes;

        _totalStorageBytes = marketingTotalBytes;
        _usedStorageBytes = adjustedUsedBytes;
        PreferencesService.saveCachedTotalStorage(marketingTotalBytes);
        PreferencesService.saveCachedUsedStorage(adjustedUsedBytes);
      } else {
        _totalStorageBytes = 0;
        _usedStorageBytes = 0;
      }

      // Query/calculate space for all volumes
      for (var vol in _storageVolumes) {
        if (vol.isInternal) {
          vol.totalBytes = _rawTotalStorageBytes;
          vol.usedBytes = _rawUsedStorageBytes;
        } else {
          final volSpace = await RootShizukuService.getStorageSpace(path: vol.path);
          if (volSpace != null) {
            vol.totalBytes = volSpace['totalBytes'] ?? 0;
            vol.usedBytes = volSpace['usedBytes'] ?? 0;
          }
        }
      }

      notifyListeners();
    }
  }

  void setRootPath(String path) {
    _rootPath = path;
    if (tabs.isNotEmpty) {
      activeTab.currentPath = path;
    }
    notifyListeners();
  }

  Future<void> _detectStorageVolumes() async {
    final volumes = <StorageVolume>[];
    if (Platform.isAndroid) {
      volumes.add(StorageVolume(name: 'Internal Storage', path: '/storage/emulated/0', isInternal: true));

      try {
        final extDirs = await getExternalStorageDirectories();
        if (extDirs != null) {
          for (final dir in extDirs) {
            final path = dir.path;
            if (path.contains('/Android/')) {
              final root = path.substring(0, path.indexOf('/Android/'));
              if (root != '/storage/emulated/0' && root != '/storage/emulated') {
                final name = root.contains('-') ? 'SD Card (${p.basename(root)})' : 'SD Card / USB';
                if (!volumes.any((v) => v.path == root)) {
                  volumes.add(StorageVolume(name: name, path: root, isInternal: false));
                }
              }
            }
          }
        }
      } catch (e) {
      debugPrint('Operation error: \$e');
    }

      try {
        final storageDir = Directory('/storage');
        if (storageDir.existsSync()) {
          final list = storageDir.listSync();
          for (final entity in list) {
            if (entity is Directory) {
              final base = p.basename(entity.path);
              if (base != 'emulated' && base != 'self' && base != 'enterprise') {
                if (!volumes.any((v) => v.path == entity.path)) {
                  final name = base.contains('-') ? 'SD Card ($base)' : 'SD Card / USB ($base)';
                  volumes.add(StorageVolume(name: name, path: entity.path, isInternal: false));
                }
              }
            }
          }
        }
      } catch (e) {
      debugPrint('Operation error: \$e');
    }
    } else {
      final dir = await getApplicationDocumentsDirectory();
      volumes.add(StorageVolume(name: 'Documents', path: dir.path, isInternal: true));
    }
    _storageVolumes = volumes;
    await updateStorageSpace();
  }

  Future<void> init() async {
    String initialPath = '/';
    if (Platform.isAndroid) {
      initialPath = '/storage/emulated/0';
      if (!Directory(initialPath).existsSync()) {
        final dir = await getExternalStorageDirectory();
        initialPath = dir?.path ?? '/';
      }
      _rootPath = initialPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      initialPath = dir.path;
      _rootPath = initialPath;
    }
    
    // Initialize primary default tab
    final savedTabsData = PreferencesService.getSavedTabs();
    if (savedTabsData.isNotEmpty) {
      final allTabs = savedTabsData.map((data) {
        return FolderTab(
          id: data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          currentPath: data['currentPath']?.toString() ?? initialPath,
          isPinned: data['isPinned'] ?? false,
        );
      }).toList();

      if (_rememberLastFolder) {
        tabs = allTabs;
      } else {
        // Keep only pinned tabs
        tabs = allTabs.where((t) => t.isPinned).toList();
      }

      if (tabs.isEmpty) {
        tabs = [
          FolderTab(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            currentPath: initialPath,
          )
        ];
      }

      if (_enableSplitScreen && tabs.length < 2) {
        while (tabs.length < 2) {
          tabs.add(FolderTab(
            id: (DateTime.now().millisecondsSinceEpoch + tabs.length).toString(),
            currentPath: initialPath,
          ));
        }
      }
      _activeTabIndex = 0;
    } else {
      tabs = [
        FolderTab(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          currentPath: initialPath,
        )
      ];
      if (_enableSplitScreen) {
        tabs.add(FolderTab(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          currentPath: initialPath,
        ));
      }
      _activeTabIndex = 0;
    }

    await _detectStorageVolumes();
    final path0 = tabs.isNotEmpty ? tabs[0].currentPath : initialPath;
    await loadDirectory(path0, showLoading: false);
    if (_enableSplitScreen) {
      final path1 = tabs.length > 1 ? tabs[1].currentPath : initialPath;
      await loadDirectoryForTab(1, path1, showLoading: false);
    }
  }

  bool isRestrictedPath(String path) {
    // Collapse double slashes to prevent bypasses, e.g. //data -> /data
    String normalized = path.replaceAll(RegExp(r'/+'), '/');
    if (path.startsWith('/') && !normalized.startsWith('/')) {
      normalized = '/$normalized';
    }

    // Normalize /sdcard and /mnt/sdcard to /storage/emulated/0
    if (normalized.startsWith('/sdcard')) {
      normalized = normalized.replaceFirst('/sdcard', '/storage/emulated/0');
    } else if (normalized.startsWith('/mnt/sdcard')) {
      normalized = normalized.replaceFirst('/mnt/sdcard', '/storage/emulated/0');
    }

    final lower = normalized.toLowerCase();
    if (lower.contains('/android/data') || lower.contains('/android/obb')) {
      return true;
    }
    // Only /data (excluding /data/media) is strictly restricted by default
    if (normalized == '/data' || (normalized.startsWith('/data/') && !normalized.startsWith('/data/media'))) {
      return true;
    }
    return false;
  }

  Future<void> enableRootMode() async {
    activeTab.useRootMode = true;
    activeTab.useShizukuMode = false;
    activeTab.needsPermission = false;
    notifyListeners();
    await loadDirectory(currentPath, showLoading: true);
  }

  Future<void> enableShizukuMode() async {
    final granted = await RootShizukuService.requestShizukuPermission();
    if (granted) {
      activeTab.useShizukuMode = true;
      activeTab.useRootMode = false;
      activeTab.needsPermission = false;
      notifyListeners();
      await loadDirectory(currentPath, showLoading: true);
    }
  }

}
