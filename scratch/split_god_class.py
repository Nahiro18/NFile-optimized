import os
import re

file_path = "/home/jos/Descargas/NFile-optimized/lib/providers/file_manager_provider.dart"
with open(file_path, "r") as f:
    lines = f.readlines()

# Let's find the boundaries.
# The preferences start right after `reloadPreferences()` at line 225.
# Let's just create a mixin for Preferences.
# We will identify the block of code by looking at the start and end keywords.

start_pref_idx = -1
end_pref_idx = -1

for i, line in enumerate(lines):
    if "List<CustomShortcutModel> _pinnedFolderShortcuts = [];" in line:
        start_pref_idx = i
        break

for i, line in enumerate(lines[start_pref_idx:]):
    if "Future<void> loadDirectory(" in line:
        end_pref_idx = start_pref_idx + i
        break

print(f"Pref boundaries: {start_pref_idx} to {end_pref_idx}")

if start_pref_idx != -1 and end_pref_idx != -1:
    pref_lines = lines[start_pref_idx:end_pref_idx]
    
    # Write the mixin
    mixin_path = "/home/jos/Descargas/NFile-optimized/lib/providers/preferences_mixin.dart"
    with open(mixin_path, "w") as f:
        f.write("import 'dart:io';\n")
        f.write("import 'dart:async';\n")
        f.write("import 'dart:typed_data';\n")
        f.write("import 'package:flutter/material.dart';\n")
        f.write("import 'package:flutter/services.dart';\n")
        f.write("import '../services/preferences_service.dart';\n")
        f.write("import '../services/app_manager_service.dart';\n")
        f.write("import '../models/custom_shortcut_model.dart';\n")
        f.write("import '../models/file_item_model.dart';\n")
        f.write("\n")
        f.write("mixin PreferencesMixin on ChangeNotifier {\n")
        
        # We need to add the fields initialized in constructor to the mixin.
        f.write("  FileSortType _sortType = FileSortType.nameAsc;\n")
        f.write("  bool _isGridView = false;\n")
        f.write("  double _iconScale = 1.0;\n")
        f.write("  double _itemPaddingMultiplier = 1.0;\n")
        f.write("  bool _showHiddenFiles = false;\n")
        f.write("  bool _showFloatingAddButton = true;\n")
        f.write("  bool _defaultToBrowseScreen = false;\n")
        f.write("  bool _showFolderFileCount = true;\n")
        f.write("  bool _showBottomActionBar = true;\n")
        f.write("  bool _showHomeBrowseNav = true;\n")
        f.write("  bool _hideNavLabels = false;\n")
        f.write("  bool _showMediaPreviews = true;\n")
        f.write("  bool _enableMultipleTabs = true;\n")
        f.write("  bool _enableSplitScreen = false;\n")
        f.write("  bool _hideNavigationBar = false;\n")
        f.write("  bool _skipOpenWithDialog = false;\n")
        f.write("  bool _showAddressBar = false;\n")
        f.write("  bool _amoledMode = false;\n")
        f.write("  bool _showRecentFiles = true;\n")
        f.write("  bool _enableFolderHighlight = true;\n")
        f.write("  bool _enableDragDrop = true;\n")
        f.write("  bool _showDragDropDialog = true;\n")
        f.write("  bool _use24HourFormat = true;\n")
        f.write("  bool _hideTimeAndDate = false;\n")
        f.write("  bool _showFolderContentsCount = true;\n")
        f.write("  bool _showFolderSizes = true;\n")
        f.write("  bool _adaptiveMultiLineNames = true;\n")
        f.write("  bool _hideActionMenuButtons = false;\n")
        f.write("  String _trailingInfoType = 'default';\n")
        f.write("  bool _hideActionText = false;\n")
        f.write("  bool _rememberLastFolder = false;\n")
        f.write("  bool _useMaterialIcons = false;\n")
        f.write("  String _exitOption = 'default';\n")
        
        # We also need currentFiles and activeTab required by setSortType etc.
        # This means PreferencesMixin depends on FileManagerProvider properties.
        # We can declare abstract getters for them.
        f.write("  String get currentPath;\n")
        f.write("  List<FileItemModel> get currentFiles;\n")
        f.write("  dynamic get activeTab;\n")
        f.write("  List<dynamic> get tabs;\n")
        f.write("  void sortList(List<FileItemModel> list, String path);\n")
        
        for line in pref_lines:
            if "_tabs" in line:
                line = line.replace("_tabs", "tabs")
            if "_sortList" in line:
                line = line.replace("_sortList", "sortList")
            f.write(line)
        f.write("}\n")

    # Update file_manager_provider.dart
    lines = lines[:start_pref_idx] + lines[end_pref_idx:]
    
    with open(file_path, "w") as f:
        # Add import for mixin
        for i, line in enumerate(lines):
            if line.startswith("class FileManagerProvider"):
                lines[i] = line.replace("class FileManagerProvider extends ChangeNotifier {", "import 'preferences_mixin.dart';\nclass FileManagerProvider extends ChangeNotifier with PreferencesMixin {")
                break
            
            # also inject abstract implementations for mixin
        for i, line in enumerate(lines):
            if "class FileManagerProvider" in line:
                # Add abstract implementations just after class declaration
                lines.insert(i + 1, "  @override\n  List<dynamic> get tabs => _tabs;\n")
                lines.insert(i + 2, "  @override\n  void sortList(List<FileItemModel> list, String path) => _sortList(list, path);\n")
                break
                
        f.writelines(lines)
    print("Preferences extracted to mixin successfully!")
